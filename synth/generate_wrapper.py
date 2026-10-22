import re
from pathlib import Path
root=Path(__file__).resolve().parents[2]
top=(root/'src/integration/rtl/caliptra_top.sv').read_text()
header=top[top.index('module caliptra_top'):top.index('    (\n    input logic',top.index('module caliptra_top'))]
porttext=top[top.index('    (\n    input logic',top.index('module caliptra_top'))+6:top.index('\n);',top.index('module caliptra_top'))]
porttext=re.sub(r'//[^\n]*','',porttext)
parts=[p.strip() for p in porttext.split(',') if p.strip()]
scalar=[]
for part in parts:
    if re.match(r'^(input|output|inout)\s',part): scalar.append(part)
    elif re.match(r'^(axi_if|el2_mem_if|abr_mem_if)\.',part): continue
    else: raise ValueError('unparsed top port '+part)

def parse_decls(path,begin,end):
    s=Path(path).read_text(); s=s[s.index(begin):s.index(end,s.index(begin))]
    s=re.sub(r'//[^\n]*','',s)
    return {m.group(2):m.group(1).strip() for m in re.finditer(r'\blogic\s+([^;]*?)\b(\w+)\s*;',s)}

def modport(text,name):
    body=re.search(r'modport\s+'+name+r'\s*\((.*?)\);',text,re.S).group(1)
    body=re.sub(r'//[^\n]*','',body)
    found={}; direction=None
    for token in body.split(','):
        tok=token.strip()
        if not tok: continue
        m=re.match(r'(input|output)\s+(\w+)',tok)
        if m: direction,n=m.groups()
        else: n=tok
        found[n]=direction
    return found

axi_path=root/'src/axi/rtl/axi_if.sv'; axi_text=axi_path.read_text()
axi_decls=parse_decls(axi_path,'interface axi_if','// Modport for read manager')
el2_path=root/'src/riscv_core/veer_el2/rtl/lib/el2_mem_if.sv'; el2_text=el2_path.read_text()
el2_decls=parse_decls(el2_path,'interface el2_mem_if','// MODPORTS')
flat=[]; assignments=[]; connections=[]
def add(direction,typ,name,internal):
    flat.append(f'{direction} logic {typ} {name}'.replace('logic  ','logic '))
    assignments.append(f'assign {internal} = {name};' if direction=='input' else f'assign {name} = {internal};')
for label,kind,aw,dw,iw,uw in [
 ('s_axi','sub','`CALIPTRA_SLAVE_ADDR_WIDTH(`CALIPTRA_SLAVE_SEL_SOC_IFC)','`CALIPTRA_AXI_DATA_WIDTH','`CALIPTRA_AXI_ID_WIDTH','`CALIPTRA_AXI_USER_WIDTH'),
 ('m_axi','mgr','`CALIPTRA_AXI_DMA_ADDR_WIDTH','CPTRA_AXI_DMA_DATA_WIDTH','CPTRA_AXI_DMA_ID_WIDTH','CPTRA_AXI_DMA_USER_WIDTH')]:
    dirs={**modport(axi_text,'w_'+kind),**modport(axi_text,'r_'+kind)}
    for sig,dir in dirs.items():
        typ=axi_decls[sig]
        for a,b in [('AW',aw),('DW',dw),('IW',iw),('UW',uw)]: typ=re.sub(r'\b'+a+r'\b','('+b+')',typ)
        add(dir,typ,label+'_'+sig,label+'_if.'+sig)
    connections += [f'.{label}_w_if({label}_if.w_{kind})',f'.{label}_r_if({label}_if.r_{kind})']

dirs=modport(el2_text,'veer_sram_src')
for sig,dir in dirs.items(): add(dir,el2_decls[sig],'el2_'+sig,'el2_mem_export.'+sig)
connections.append('.el2_mem_export(el2_mem_export.veer_sram_src)')
abr=[('w1_mem','ABR_MEM_W1',False),('mem_inst0_bank0','ABR_MEM_INST0',False),('mem_inst0_bank1','ABR_MEM_INST0',False),('mem_inst1','ABR_MEM_INST1',False),('mem_inst2','ABR_MEM_INST2',False),('mem_inst0_bank0_masked','ABR_MEM_INST0',False),('mem_inst0_bank1_masked','ABR_MEM_INST0',False),('mem_inst1_masked','ABR_MEM_INST1',False),('mem_inst2_masked','ABR_MEM_INST2',False),('sk_mem_bank0','SK_MEM_BANK',False),('sk_mem_bank1','SK_MEM_BANK',False),('sig_z_mem','SIG_Z_MEM',True),('pk_mem','PK_MEM',True)]
for sig,prefix,be in abr:
    for suffix,dimension,direction in [('we_i','', 'output'),('waddr_i',f'[{prefix}_ADDR_W-1:0]','output'),('wdata_i',f'[{prefix}_DATA_W-1:0]','output'),('wstrobe_i',f'[{prefix}_WSTROBE_W-1:0]','output'),('re_i','','output'),('raddr_i',f'[{prefix}_ADDR_W-1:0]','output'),('rdata_o',f'[{prefix}_DATA_W-1:0]','input')]:
        if suffix=='wstrobe_i' and not be: continue
        add(direction,dimension,'abr_'+sig+'_'+suffix,'abr_memory_export.'+sig+'_'+suffix)
connections.append('.abr_memory_export(abr_memory_export.req)')
for item in scalar:
    name=re.search(r'(\w+)\s*$',item).group(1)
    connections.append(f'.{name}({name})')
module_header=header.replace('module caliptra_top','module caliptra_synth_wrapper',1)
module_header=module_header[:module_header.index('    #(')]
module_header=module_header.replace('    import el2_pkg::*;', '    import el2_pkg::*;\n    import axi_pkg::*;\n    import abr_params_pkg::*;')
module_header+='    #(\n    `include \"el2_param.vh\"\n    )\n'
# Preserve the package imports but use the DUT's default CPU parameter record.
output='// SPDX-License-Identifier: Apache-2.0\n// Generated flat-port ASIC synthesis boundary for Caliptra.\n`include "config_defines.svh"\n'+module_header+'    (\n'+',\n'.join('    '+p for p in scalar+flat)+'\n);\n\n'
output+='axi_if #(.AW(`CALIPTRA_SLAVE_ADDR_WIDTH(`CALIPTRA_SLAVE_SEL_SOC_IFC)), .DW(`CALIPTRA_AXI_DATA_WIDTH), .IW(`CALIPTRA_AXI_ID_WIDTH), .UW(`CALIPTRA_AXI_USER_WIDTH)) s_axi_if (.clk(clk), .rst_n(cptra_rst_b));\n'
output+='axi_if #(.AW(`CALIPTRA_AXI_DMA_ADDR_WIDTH), .DW(CPTRA_AXI_DMA_DATA_WIDTH), .IW(CPTRA_AXI_DMA_ID_WIDTH), .UW(CPTRA_AXI_DMA_USER_WIDTH)) m_axi_if (.clk(clk), .rst_n(cptra_rst_b));\n'
output+='el2_mem_if #(.pt(pt)) el2_mem_export ();\nabr_mem_if abr_memory_export ();\n'
output+='\n'.join(assignments)+'\n\ncaliptra_top #(.pt(pt)) dut (\n'+',\n'.join('    '+c for c in connections)+'\n);\nendmodule\n'
(root/'.booley_project/synth/caliptra_synth_wrapper.sv').write_text(output)
print(f'{len(scalar)} scalar ports, {len(flat)} flattened interface ports, {len(output.splitlines())} wrapper lines')
