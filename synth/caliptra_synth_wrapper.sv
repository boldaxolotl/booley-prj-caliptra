// SPDX-License-Identifier: Apache-2.0
// Generated flat-port ASIC synthesis boundary for Caliptra.
`include "config_defines.svh"
module caliptra_synth_wrapper
    import kv_defines_pkg::*;
    import pv_defines_pkg::*;
    import soc_ifc_pkg::*;
    import lc_ctrl_state_pkg::*;
    import lc_ctrl_reg_pkg::*;
    import lc_ctrl_pkg::*;
    import caliptra_prim_mubi_pkg::*;
`ifdef CALIPTRA_INTERNAL_TRNG
    import entropy_src_pkg::*;
    import csrng_pkg::*;
`endif
    import el2_pkg::*;
    import axi_pkg::*;
    import abr_params_pkg::*;
    #(
    `include "el2_param.vh"
    )
    (
    input logic                        clk,
    input logic                        cptra_pwrgood,
    input logic                        cptra_rst_b,
    input logic [255:0]                              cptra_obf_key,
    input logic [`CLP_CSR_HMAC_KEY_DWORDS-1:0][31:0] cptra_csr_hmac_key,
    input logic                                      cptra_obf_field_entropy_vld,
    input logic [`CLP_OBF_FE_DWORDS-1 :0][31:0]      cptra_obf_field_entropy,
    input logic                                      cptra_obf_uds_seed_vld,
    input logic [`CLP_OBF_UDS_DWORDS-1:0][31:0]      cptra_obf_uds_seed,
    input logic                        jtag_tck,
    input logic                        jtag_tms,
    input logic                        jtag_tdi,
    input logic                        jtag_trst_n,
    output logic                       jtag_tdo,
    output logic                       jtag_tdoEn,
    output logic mbox_sram_cs,
    output logic mbox_sram_we,
    output logic [CPTRA_MBOX_ADDR_W-1:0] mbox_sram_addr,
    output logic [CPTRA_MBOX_DATA_AND_ECC_W-1:0] mbox_sram_wdata,
    input  logic [CPTRA_MBOX_DATA_AND_ECC_W-1:0] mbox_sram_rdata,
    output logic imem_cs,
    output logic [`CALIPTRA_IMEM_ADDR_WIDTH-1:0] imem_addr,
    input  logic [`CALIPTRA_IMEM_DATA_WIDTH-1:0] imem_rdata,
    output logic                       ready_for_fuses,
    output logic                       ready_for_mb_processing,
    output logic                       ready_for_runtime,
    output logic                       mailbox_data_avail,
    output logic                       mailbox_flow_done,
    input  logic                       recovery_data_avail,
    input  logic                       recovery_image_activated,
    input logic                        BootFSM_BrkPoint,
    output logic             cptra_error_fatal,
    output logic             cptra_error_non_fatal,
    output logic             etrng0_req,
    output logic             etrng1_req,
    input  logic [3:0]       itrng0_data,
    input  logic             itrng0_valid,
    input  logic [3:0]       itrng1_data,
    input  logic             itrng1_valid,
    input  logic             itrng1_en,
    input logic [63:0] strap_ss_caliptra_base_addr,
    input logic [63:0] strap_ss_mci_base_addr,
    input logic [63:0] strap_ss_recovery_ifc_base_addr,
    input logic [63:0] strap_ss_external_staging_area_base_addr,
    input logic [63:0] strap_ss_otp_fc_base_addr,
    input logic [63:0] strap_ss_uds_seed_base_addr,
    input logic [63:0] strap_ss_key_release_base_addr,
    input logic [15:0] strap_ss_key_release_key_size,
    input logic [31:0] strap_ss_prod_debug_unlock_auth_pk_hash_reg_bank_offset,
    input logic [31:0] strap_ss_num_of_prod_debug_unlock_auth_pk_hashes,
    input logic [31:0] strap_ss_caliptra_dma_axi_user,
    input logic [31:0] strap_ss_strap_generic_0,
    input logic [31:0] strap_ss_strap_generic_1,
    input logic [31:0] strap_ss_strap_generic_2,
    input logic [31:0] strap_ss_strap_generic_3,
    input logic        ss_debug_intent,
    input logic        ss_ocp_lock_en,
    output logic        ss_dbg_manuf_enable,
    output logic [63:0] ss_soc_dbg_unlock_level,
    output logic [127:0] ss_generic_fw_exec_ctrl,
    input logic  [63:0]                generic_input_wires,
    output logic [63:0]                generic_output_wires,
    output logic [31:0]         trace_rv_i_insn_ip,
    output logic [31:0]         trace_rv_i_address_ip,
    output logic                trace_rv_i_valid_ip,
    output logic                trace_rv_i_exception_ip,
    output logic [4:0]          trace_rv_i_ecause_ip,
    output logic                trace_rv_i_interrupt_ip,
    output logic [31:0]         trace_rv_i_tval_ip,
    input security_state_t             security_state,
    input logic                        scan_mode,
    input logic [(`CALIPTRA_SLAVE_ADDR_WIDTH(`CALIPTRA_SLAVE_SEL_SOC_IFC))-1:0] s_axi_awaddr,
    input logic [$bits(axi_burst_e)-1:0] s_axi_awburst,
    input logic [2:0] s_axi_awsize,
    input logic [7:0] s_axi_awlen,
    input logic [(`CALIPTRA_AXI_USER_WIDTH)-1:0] s_axi_awuser,
    input logic [(`CALIPTRA_AXI_ID_WIDTH)-1:0] s_axi_awid,
    input logic s_axi_awlock,
    input logic [3:0] s_axi_awcache,
    input logic [2:0] s_axi_awprot,
    input logic [3:0] s_axi_awqos,
    input logic [3:0] s_axi_awregion,
    input logic s_axi_awvalid,
    output logic s_axi_awready,
    input logic [(`CALIPTRA_AXI_DATA_WIDTH)-1:0] s_axi_wdata,
    input logic [(`CALIPTRA_AXI_DATA_WIDTH)/8-1:0] s_axi_wstrb,
    input logic [(`CALIPTRA_AXI_USER_WIDTH)-1:0] s_axi_wuser,
    input logic s_axi_wvalid,
    output logic s_axi_wready,
    input logic s_axi_wlast,
    output logic [$bits(axi_resp_e)-1:0] s_axi_bresp,
    output logic [(`CALIPTRA_AXI_ID_WIDTH)-1:0] s_axi_bid,
    output logic [(`CALIPTRA_AXI_USER_WIDTH)-1:0] s_axi_buser,
    output logic s_axi_bvalid,
    input logic s_axi_bready,
    input logic [(`CALIPTRA_SLAVE_ADDR_WIDTH(`CALIPTRA_SLAVE_SEL_SOC_IFC))-1:0] s_axi_araddr,
    input logic [$bits(axi_burst_e)-1:0] s_axi_arburst,
    input logic [2:0] s_axi_arsize,
    input logic [7:0] s_axi_arlen,
    input logic [(`CALIPTRA_AXI_USER_WIDTH)-1:0] s_axi_aruser,
    input logic [(`CALIPTRA_AXI_ID_WIDTH)-1:0] s_axi_arid,
    input logic s_axi_arlock,
    input logic [3:0] s_axi_arcache,
    input logic [2:0] s_axi_arprot,
    input logic [3:0] s_axi_arqos,
    input logic [3:0] s_axi_arregion,
    input logic s_axi_arvalid,
    output logic s_axi_arready,
    output logic [(`CALIPTRA_AXI_DATA_WIDTH)-1:0] s_axi_rdata,
    output logic [$bits(axi_resp_e)-1:0] s_axi_rresp,
    output logic [(`CALIPTRA_AXI_ID_WIDTH)-1:0] s_axi_rid,
    output logic [(`CALIPTRA_AXI_USER_WIDTH)-1:0] s_axi_ruser,
    output logic s_axi_rlast,
    output logic s_axi_rvalid,
    input logic s_axi_rready,
    output logic [(`CALIPTRA_AXI_DMA_ADDR_WIDTH)-1:0] m_axi_awaddr,
    output logic [$bits(axi_burst_e)-1:0] m_axi_awburst,
    output logic [2:0] m_axi_awsize,
    output logic [7:0] m_axi_awlen,
    output logic [(CPTRA_AXI_DMA_USER_WIDTH)-1:0] m_axi_awuser,
    output logic [(CPTRA_AXI_DMA_ID_WIDTH)-1:0] m_axi_awid,
    output logic m_axi_awlock,
    output logic [3:0] m_axi_awcache,
    output logic [2:0] m_axi_awprot,
    output logic [3:0] m_axi_awqos,
    output logic [3:0] m_axi_awregion,
    output logic m_axi_awvalid,
    input logic m_axi_awready,
    output logic [(CPTRA_AXI_DMA_DATA_WIDTH)-1:0] m_axi_wdata,
    output logic [(CPTRA_AXI_DMA_DATA_WIDTH)/8-1:0] m_axi_wstrb,
    output logic [(CPTRA_AXI_DMA_USER_WIDTH)-1:0] m_axi_wuser,
    output logic m_axi_wvalid,
    input logic m_axi_wready,
    output logic m_axi_wlast,
    input logic [$bits(axi_resp_e)-1:0] m_axi_bresp,
    input logic [(CPTRA_AXI_DMA_ID_WIDTH)-1:0] m_axi_bid,
    input logic [(CPTRA_AXI_DMA_USER_WIDTH)-1:0] m_axi_buser,
    input logic m_axi_bvalid,
    output logic m_axi_bready,
    output logic [(`CALIPTRA_AXI_DMA_ADDR_WIDTH)-1:0] m_axi_araddr,
    output logic [$bits(axi_burst_e)-1:0] m_axi_arburst,
    output logic [2:0] m_axi_arsize,
    output logic [7:0] m_axi_arlen,
    output logic [(CPTRA_AXI_DMA_USER_WIDTH)-1:0] m_axi_aruser,
    output logic [(CPTRA_AXI_DMA_ID_WIDTH)-1:0] m_axi_arid,
    output logic m_axi_arlock,
    output logic [3:0] m_axi_arcache,
    output logic [2:0] m_axi_arprot,
    output logic [3:0] m_axi_arqos,
    output logic [3:0] m_axi_arregion,
    output logic m_axi_arvalid,
    input logic m_axi_arready,
    input logic [(CPTRA_AXI_DMA_DATA_WIDTH)-1:0] m_axi_rdata,
    input logic [$bits(axi_resp_e)-1:0] m_axi_rresp,
    input logic [(CPTRA_AXI_DMA_ID_WIDTH)-1:0] m_axi_rid,
    input logic [(CPTRA_AXI_DMA_USER_WIDTH)-1:0] m_axi_ruser,
    input logic m_axi_rlast,
    input logic m_axi_rvalid,
    output logic m_axi_rready,
    output logic el2_clk,
    output logic [pt.ICCM_NUM_BANKS-1:0] el2_iccm_clken,
    output logic [pt.ICCM_NUM_BANKS-1:0] el2_iccm_wren_bank,
    output logic [pt.ICCM_NUM_BANKS-1:0][pt.ICCM_BITS-1:pt.ICCM_BANK_INDEX_LO] el2_iccm_addr_bank,
    output logic [pt.ICCM_NUM_BANKS-1:0][                                31:0] el2_iccm_bank_wr_data,
    output logic [pt.ICCM_NUM_BANKS-1:0][               pt.ICCM_ECC_WIDTH-1:0] el2_iccm_bank_wr_ecc,
    input logic [pt.ICCM_NUM_BANKS-1:0][                                31:0] el2_iccm_bank_dout,
    input logic [pt.ICCM_NUM_BANKS-1:0][               pt.ICCM_ECC_WIDTH-1:0] el2_iccm_bank_ecc,
    output logic [pt.DCCM_NUM_BANKS-1:0] el2_dccm_clken,
    output logic [pt.DCCM_NUM_BANKS-1:0] el2_dccm_wren_bank,
    output logic [pt.DCCM_NUM_BANKS-1:0][pt.DCCM_BITS-1:(pt.DCCM_BANK_BITS+2)] el2_dccm_addr_bank,
    output logic [pt.DCCM_NUM_BANKS-1:0][              pt.DCCM_DATA_WIDTH-1:0] el2_dccm_wr_data_bank,
    output logic [pt.DCCM_NUM_BANKS-1:0][               pt.DCCM_ECC_WIDTH-1:0] el2_dccm_wr_ecc_bank,
    input logic [pt.DCCM_NUM_BANKS-1:0][              pt.DCCM_DATA_WIDTH-1:0] el2_dccm_bank_dout,
    input logic [pt.DCCM_NUM_BANKS-1:0][               pt.DCCM_ECC_WIDTH-1:0] el2_dccm_bank_ecc,
    output logic abr_w1_mem_we_i,
    output logic [ABR_MEM_W1_ADDR_W-1:0] abr_w1_mem_waddr_i,
    output logic [ABR_MEM_W1_DATA_W-1:0] abr_w1_mem_wdata_i,
    output logic abr_w1_mem_re_i,
    output logic [ABR_MEM_W1_ADDR_W-1:0] abr_w1_mem_raddr_i,
    input logic [ABR_MEM_W1_DATA_W-1:0] abr_w1_mem_rdata_o,
    output logic abr_mem_inst0_bank0_we_i,
    output logic [ABR_MEM_INST0_ADDR_W-1:0] abr_mem_inst0_bank0_waddr_i,
    output logic [ABR_MEM_INST0_DATA_W-1:0] abr_mem_inst0_bank0_wdata_i,
    output logic abr_mem_inst0_bank0_re_i,
    output logic [ABR_MEM_INST0_ADDR_W-1:0] abr_mem_inst0_bank0_raddr_i,
    input logic [ABR_MEM_INST0_DATA_W-1:0] abr_mem_inst0_bank0_rdata_o,
    output logic abr_mem_inst0_bank1_we_i,
    output logic [ABR_MEM_INST0_ADDR_W-1:0] abr_mem_inst0_bank1_waddr_i,
    output logic [ABR_MEM_INST0_DATA_W-1:0] abr_mem_inst0_bank1_wdata_i,
    output logic abr_mem_inst0_bank1_re_i,
    output logic [ABR_MEM_INST0_ADDR_W-1:0] abr_mem_inst0_bank1_raddr_i,
    input logic [ABR_MEM_INST0_DATA_W-1:0] abr_mem_inst0_bank1_rdata_o,
    output logic abr_mem_inst1_we_i,
    output logic [ABR_MEM_INST1_ADDR_W-1:0] abr_mem_inst1_waddr_i,
    output logic [ABR_MEM_INST1_DATA_W-1:0] abr_mem_inst1_wdata_i,
    output logic abr_mem_inst1_re_i,
    output logic [ABR_MEM_INST1_ADDR_W-1:0] abr_mem_inst1_raddr_i,
    input logic [ABR_MEM_INST1_DATA_W-1:0] abr_mem_inst1_rdata_o,
    output logic abr_mem_inst2_we_i,
    output logic [ABR_MEM_INST2_ADDR_W-1:0] abr_mem_inst2_waddr_i,
    output logic [ABR_MEM_INST2_DATA_W-1:0] abr_mem_inst2_wdata_i,
    output logic abr_mem_inst2_re_i,
    output logic [ABR_MEM_INST2_ADDR_W-1:0] abr_mem_inst2_raddr_i,
    input logic [ABR_MEM_INST2_DATA_W-1:0] abr_mem_inst2_rdata_o,
    output logic abr_mem_inst0_bank0_masked_we_i,
    output logic [ABR_MEM_INST0_ADDR_W-1:0] abr_mem_inst0_bank0_masked_waddr_i,
    output logic [ABR_MEM_INST0_DATA_W-1:0] abr_mem_inst0_bank0_masked_wdata_i,
    output logic abr_mem_inst0_bank0_masked_re_i,
    output logic [ABR_MEM_INST0_ADDR_W-1:0] abr_mem_inst0_bank0_masked_raddr_i,
    input logic [ABR_MEM_INST0_DATA_W-1:0] abr_mem_inst0_bank0_masked_rdata_o,
    output logic abr_mem_inst0_bank1_masked_we_i,
    output logic [ABR_MEM_INST0_ADDR_W-1:0] abr_mem_inst0_bank1_masked_waddr_i,
    output logic [ABR_MEM_INST0_DATA_W-1:0] abr_mem_inst0_bank1_masked_wdata_i,
    output logic abr_mem_inst0_bank1_masked_re_i,
    output logic [ABR_MEM_INST0_ADDR_W-1:0] abr_mem_inst0_bank1_masked_raddr_i,
    input logic [ABR_MEM_INST0_DATA_W-1:0] abr_mem_inst0_bank1_masked_rdata_o,
    output logic abr_mem_inst1_masked_we_i,
    output logic [ABR_MEM_INST1_ADDR_W-1:0] abr_mem_inst1_masked_waddr_i,
    output logic [ABR_MEM_INST1_DATA_W-1:0] abr_mem_inst1_masked_wdata_i,
    output logic abr_mem_inst1_masked_re_i,
    output logic [ABR_MEM_INST1_ADDR_W-1:0] abr_mem_inst1_masked_raddr_i,
    input logic [ABR_MEM_INST1_DATA_W-1:0] abr_mem_inst1_masked_rdata_o,
    output logic abr_mem_inst2_masked_we_i,
    output logic [ABR_MEM_INST2_ADDR_W-1:0] abr_mem_inst2_masked_waddr_i,
    output logic [ABR_MEM_INST2_DATA_W-1:0] abr_mem_inst2_masked_wdata_i,
    output logic abr_mem_inst2_masked_re_i,
    output logic [ABR_MEM_INST2_ADDR_W-1:0] abr_mem_inst2_masked_raddr_i,
    input logic [ABR_MEM_INST2_DATA_W-1:0] abr_mem_inst2_masked_rdata_o,
    output logic abr_sk_mem_bank0_we_i,
    output logic [SK_MEM_BANK_ADDR_W-1:0] abr_sk_mem_bank0_waddr_i,
    output logic [SK_MEM_BANK_DATA_W-1:0] abr_sk_mem_bank0_wdata_i,
    output logic abr_sk_mem_bank0_re_i,
    output logic [SK_MEM_BANK_ADDR_W-1:0] abr_sk_mem_bank0_raddr_i,
    input logic [SK_MEM_BANK_DATA_W-1:0] abr_sk_mem_bank0_rdata_o,
    output logic abr_sk_mem_bank1_we_i,
    output logic [SK_MEM_BANK_ADDR_W-1:0] abr_sk_mem_bank1_waddr_i,
    output logic [SK_MEM_BANK_DATA_W-1:0] abr_sk_mem_bank1_wdata_i,
    output logic abr_sk_mem_bank1_re_i,
    output logic [SK_MEM_BANK_ADDR_W-1:0] abr_sk_mem_bank1_raddr_i,
    input logic [SK_MEM_BANK_DATA_W-1:0] abr_sk_mem_bank1_rdata_o,
    output logic abr_sig_z_mem_we_i,
    output logic [SIG_Z_MEM_ADDR_W-1:0] abr_sig_z_mem_waddr_i,
    output logic [SIG_Z_MEM_DATA_W-1:0] abr_sig_z_mem_wdata_i,
    output logic [SIG_Z_MEM_WSTROBE_W-1:0] abr_sig_z_mem_wstrobe_i,
    output logic abr_sig_z_mem_re_i,
    output logic [SIG_Z_MEM_ADDR_W-1:0] abr_sig_z_mem_raddr_i,
    input logic [SIG_Z_MEM_DATA_W-1:0] abr_sig_z_mem_rdata_o,
    output logic abr_pk_mem_we_i,
    output logic [PK_MEM_ADDR_W-1:0] abr_pk_mem_waddr_i,
    output logic [PK_MEM_DATA_W-1:0] abr_pk_mem_wdata_i,
    output logic [PK_MEM_WSTROBE_W-1:0] abr_pk_mem_wstrobe_i,
    output logic abr_pk_mem_re_i,
    output logic [PK_MEM_ADDR_W-1:0] abr_pk_mem_raddr_i,
    input logic [PK_MEM_DATA_W-1:0] abr_pk_mem_rdata_o
);

axi_if #(.AW(`CALIPTRA_SLAVE_ADDR_WIDTH(`CALIPTRA_SLAVE_SEL_SOC_IFC)), .DW(`CALIPTRA_AXI_DATA_WIDTH), .IW(`CALIPTRA_AXI_ID_WIDTH), .UW(`CALIPTRA_AXI_USER_WIDTH)) s_axi_if (.clk(clk), .rst_n(cptra_rst_b));
axi_if #(.AW(`CALIPTRA_AXI_DMA_ADDR_WIDTH), .DW(CPTRA_AXI_DMA_DATA_WIDTH), .IW(CPTRA_AXI_DMA_ID_WIDTH), .UW(CPTRA_AXI_DMA_USER_WIDTH)) m_axi_if (.clk(clk), .rst_n(cptra_rst_b));
el2_mem_if #(.pt(pt)) el2_mem_export ();
abr_mem_if abr_memory_export ();
assign s_axi_if.awaddr = s_axi_awaddr;
assign s_axi_if.awburst = s_axi_awburst;
assign s_axi_if.awsize = s_axi_awsize;
assign s_axi_if.awlen = s_axi_awlen;
assign s_axi_if.awuser = s_axi_awuser;
assign s_axi_if.awid = s_axi_awid;
assign s_axi_if.awlock = s_axi_awlock;
assign s_axi_if.awcache = s_axi_awcache;
assign s_axi_if.awprot = s_axi_awprot;
assign s_axi_if.awqos = s_axi_awqos;
assign s_axi_if.awregion = s_axi_awregion;
assign s_axi_if.awvalid = s_axi_awvalid;
assign s_axi_awready = s_axi_if.awready;
assign s_axi_if.wdata = s_axi_wdata;
assign s_axi_if.wstrb = s_axi_wstrb;
assign s_axi_if.wuser = s_axi_wuser;
assign s_axi_if.wvalid = s_axi_wvalid;
assign s_axi_wready = s_axi_if.wready;
assign s_axi_if.wlast = s_axi_wlast;
assign s_axi_bresp = s_axi_if.bresp;
assign s_axi_bid = s_axi_if.bid;
assign s_axi_buser = s_axi_if.buser;
assign s_axi_bvalid = s_axi_if.bvalid;
assign s_axi_if.bready = s_axi_bready;
assign s_axi_if.araddr = s_axi_araddr;
assign s_axi_if.arburst = s_axi_arburst;
assign s_axi_if.arsize = s_axi_arsize;
assign s_axi_if.arlen = s_axi_arlen;
assign s_axi_if.aruser = s_axi_aruser;
assign s_axi_if.arid = s_axi_arid;
assign s_axi_if.arlock = s_axi_arlock;
assign s_axi_if.arcache = s_axi_arcache;
assign s_axi_if.arprot = s_axi_arprot;
assign s_axi_if.arqos = s_axi_arqos;
assign s_axi_if.arregion = s_axi_arregion;
assign s_axi_if.arvalid = s_axi_arvalid;
assign s_axi_arready = s_axi_if.arready;
assign s_axi_rdata = s_axi_if.rdata;
assign s_axi_rresp = s_axi_if.rresp;
assign s_axi_rid = s_axi_if.rid;
assign s_axi_ruser = s_axi_if.ruser;
assign s_axi_rlast = s_axi_if.rlast;
assign s_axi_rvalid = s_axi_if.rvalid;
assign s_axi_if.rready = s_axi_rready;
assign m_axi_awaddr = m_axi_if.awaddr;
assign m_axi_awburst = m_axi_if.awburst;
assign m_axi_awsize = m_axi_if.awsize;
assign m_axi_awlen = m_axi_if.awlen;
assign m_axi_awuser = m_axi_if.awuser;
assign m_axi_awid = m_axi_if.awid;
assign m_axi_awlock = m_axi_if.awlock;
assign m_axi_awcache = m_axi_if.awcache;
assign m_axi_awprot = m_axi_if.awprot;
assign m_axi_awqos = m_axi_if.awqos;
assign m_axi_awregion = m_axi_if.awregion;
assign m_axi_awvalid = m_axi_if.awvalid;
assign m_axi_if.awready = m_axi_awready;
assign m_axi_wdata = m_axi_if.wdata;
assign m_axi_wstrb = m_axi_if.wstrb;
assign m_axi_wuser = m_axi_if.wuser;
assign m_axi_wvalid = m_axi_if.wvalid;
assign m_axi_if.wready = m_axi_wready;
assign m_axi_wlast = m_axi_if.wlast;
assign m_axi_if.bresp = m_axi_bresp;
assign m_axi_if.bid = m_axi_bid;
assign m_axi_if.buser = m_axi_buser;
assign m_axi_if.bvalid = m_axi_bvalid;
assign m_axi_bready = m_axi_if.bready;
assign m_axi_araddr = m_axi_if.araddr;
assign m_axi_arburst = m_axi_if.arburst;
assign m_axi_arsize = m_axi_if.arsize;
assign m_axi_arlen = m_axi_if.arlen;
assign m_axi_aruser = m_axi_if.aruser;
assign m_axi_arid = m_axi_if.arid;
assign m_axi_arlock = m_axi_if.arlock;
assign m_axi_arcache = m_axi_if.arcache;
assign m_axi_arprot = m_axi_if.arprot;
assign m_axi_arqos = m_axi_if.arqos;
assign m_axi_arregion = m_axi_if.arregion;
assign m_axi_arvalid = m_axi_if.arvalid;
assign m_axi_if.arready = m_axi_arready;
assign m_axi_if.rdata = m_axi_rdata;
assign m_axi_if.rresp = m_axi_rresp;
assign m_axi_if.rid = m_axi_rid;
assign m_axi_if.ruser = m_axi_ruser;
assign m_axi_if.rlast = m_axi_rlast;
assign m_axi_if.rvalid = m_axi_rvalid;
assign m_axi_rready = m_axi_if.rready;
assign el2_clk = el2_mem_export.clk;
assign el2_iccm_clken = el2_mem_export.iccm_clken;
assign el2_iccm_wren_bank = el2_mem_export.iccm_wren_bank;
assign el2_iccm_addr_bank = el2_mem_export.iccm_addr_bank;
assign el2_iccm_bank_wr_data = el2_mem_export.iccm_bank_wr_data;
assign el2_iccm_bank_wr_ecc = el2_mem_export.iccm_bank_wr_ecc;
assign el2_mem_export.iccm_bank_dout = el2_iccm_bank_dout;
assign el2_mem_export.iccm_bank_ecc = el2_iccm_bank_ecc;
assign el2_dccm_clken = el2_mem_export.dccm_clken;
assign el2_dccm_wren_bank = el2_mem_export.dccm_wren_bank;
assign el2_dccm_addr_bank = el2_mem_export.dccm_addr_bank;
assign el2_dccm_wr_data_bank = el2_mem_export.dccm_wr_data_bank;
assign el2_dccm_wr_ecc_bank = el2_mem_export.dccm_wr_ecc_bank;
assign el2_mem_export.dccm_bank_dout = el2_dccm_bank_dout;
assign el2_mem_export.dccm_bank_ecc = el2_dccm_bank_ecc;
assign abr_w1_mem_we_i = abr_memory_export.w1_mem_we_i;
assign abr_w1_mem_waddr_i = abr_memory_export.w1_mem_waddr_i;
assign abr_w1_mem_wdata_i = abr_memory_export.w1_mem_wdata_i;
assign abr_w1_mem_re_i = abr_memory_export.w1_mem_re_i;
assign abr_w1_mem_raddr_i = abr_memory_export.w1_mem_raddr_i;
assign abr_memory_export.w1_mem_rdata_o = abr_w1_mem_rdata_o;
assign abr_mem_inst0_bank0_we_i = abr_memory_export.mem_inst0_bank0_we_i;
assign abr_mem_inst0_bank0_waddr_i = abr_memory_export.mem_inst0_bank0_waddr_i;
assign abr_mem_inst0_bank0_wdata_i = abr_memory_export.mem_inst0_bank0_wdata_i;
assign abr_mem_inst0_bank0_re_i = abr_memory_export.mem_inst0_bank0_re_i;
assign abr_mem_inst0_bank0_raddr_i = abr_memory_export.mem_inst0_bank0_raddr_i;
assign abr_memory_export.mem_inst0_bank0_rdata_o = abr_mem_inst0_bank0_rdata_o;
assign abr_mem_inst0_bank1_we_i = abr_memory_export.mem_inst0_bank1_we_i;
assign abr_mem_inst0_bank1_waddr_i = abr_memory_export.mem_inst0_bank1_waddr_i;
assign abr_mem_inst0_bank1_wdata_i = abr_memory_export.mem_inst0_bank1_wdata_i;
assign abr_mem_inst0_bank1_re_i = abr_memory_export.mem_inst0_bank1_re_i;
assign abr_mem_inst0_bank1_raddr_i = abr_memory_export.mem_inst0_bank1_raddr_i;
assign abr_memory_export.mem_inst0_bank1_rdata_o = abr_mem_inst0_bank1_rdata_o;
assign abr_mem_inst1_we_i = abr_memory_export.mem_inst1_we_i;
assign abr_mem_inst1_waddr_i = abr_memory_export.mem_inst1_waddr_i;
assign abr_mem_inst1_wdata_i = abr_memory_export.mem_inst1_wdata_i;
assign abr_mem_inst1_re_i = abr_memory_export.mem_inst1_re_i;
assign abr_mem_inst1_raddr_i = abr_memory_export.mem_inst1_raddr_i;
assign abr_memory_export.mem_inst1_rdata_o = abr_mem_inst1_rdata_o;
assign abr_mem_inst2_we_i = abr_memory_export.mem_inst2_we_i;
assign abr_mem_inst2_waddr_i = abr_memory_export.mem_inst2_waddr_i;
assign abr_mem_inst2_wdata_i = abr_memory_export.mem_inst2_wdata_i;
assign abr_mem_inst2_re_i = abr_memory_export.mem_inst2_re_i;
assign abr_mem_inst2_raddr_i = abr_memory_export.mem_inst2_raddr_i;
assign abr_memory_export.mem_inst2_rdata_o = abr_mem_inst2_rdata_o;
assign abr_mem_inst0_bank0_masked_we_i = abr_memory_export.mem_inst0_bank0_masked_we_i;
assign abr_mem_inst0_bank0_masked_waddr_i = abr_memory_export.mem_inst0_bank0_masked_waddr_i;
assign abr_mem_inst0_bank0_masked_wdata_i = abr_memory_export.mem_inst0_bank0_masked_wdata_i;
assign abr_mem_inst0_bank0_masked_re_i = abr_memory_export.mem_inst0_bank0_masked_re_i;
assign abr_mem_inst0_bank0_masked_raddr_i = abr_memory_export.mem_inst0_bank0_masked_raddr_i;
assign abr_memory_export.mem_inst0_bank0_masked_rdata_o = abr_mem_inst0_bank0_masked_rdata_o;
assign abr_mem_inst0_bank1_masked_we_i = abr_memory_export.mem_inst0_bank1_masked_we_i;
assign abr_mem_inst0_bank1_masked_waddr_i = abr_memory_export.mem_inst0_bank1_masked_waddr_i;
assign abr_mem_inst0_bank1_masked_wdata_i = abr_memory_export.mem_inst0_bank1_masked_wdata_i;
assign abr_mem_inst0_bank1_masked_re_i = abr_memory_export.mem_inst0_bank1_masked_re_i;
assign abr_mem_inst0_bank1_masked_raddr_i = abr_memory_export.mem_inst0_bank1_masked_raddr_i;
assign abr_memory_export.mem_inst0_bank1_masked_rdata_o = abr_mem_inst0_bank1_masked_rdata_o;
assign abr_mem_inst1_masked_we_i = abr_memory_export.mem_inst1_masked_we_i;
assign abr_mem_inst1_masked_waddr_i = abr_memory_export.mem_inst1_masked_waddr_i;
assign abr_mem_inst1_masked_wdata_i = abr_memory_export.mem_inst1_masked_wdata_i;
assign abr_mem_inst1_masked_re_i = abr_memory_export.mem_inst1_masked_re_i;
assign abr_mem_inst1_masked_raddr_i = abr_memory_export.mem_inst1_masked_raddr_i;
assign abr_memory_export.mem_inst1_masked_rdata_o = abr_mem_inst1_masked_rdata_o;
assign abr_mem_inst2_masked_we_i = abr_memory_export.mem_inst2_masked_we_i;
assign abr_mem_inst2_masked_waddr_i = abr_memory_export.mem_inst2_masked_waddr_i;
assign abr_mem_inst2_masked_wdata_i = abr_memory_export.mem_inst2_masked_wdata_i;
assign abr_mem_inst2_masked_re_i = abr_memory_export.mem_inst2_masked_re_i;
assign abr_mem_inst2_masked_raddr_i = abr_memory_export.mem_inst2_masked_raddr_i;
assign abr_memory_export.mem_inst2_masked_rdata_o = abr_mem_inst2_masked_rdata_o;
assign abr_sk_mem_bank0_we_i = abr_memory_export.sk_mem_bank0_we_i;
assign abr_sk_mem_bank0_waddr_i = abr_memory_export.sk_mem_bank0_waddr_i;
assign abr_sk_mem_bank0_wdata_i = abr_memory_export.sk_mem_bank0_wdata_i;
assign abr_sk_mem_bank0_re_i = abr_memory_export.sk_mem_bank0_re_i;
assign abr_sk_mem_bank0_raddr_i = abr_memory_export.sk_mem_bank0_raddr_i;
assign abr_memory_export.sk_mem_bank0_rdata_o = abr_sk_mem_bank0_rdata_o;
assign abr_sk_mem_bank1_we_i = abr_memory_export.sk_mem_bank1_we_i;
assign abr_sk_mem_bank1_waddr_i = abr_memory_export.sk_mem_bank1_waddr_i;
assign abr_sk_mem_bank1_wdata_i = abr_memory_export.sk_mem_bank1_wdata_i;
assign abr_sk_mem_bank1_re_i = abr_memory_export.sk_mem_bank1_re_i;
assign abr_sk_mem_bank1_raddr_i = abr_memory_export.sk_mem_bank1_raddr_i;
assign abr_memory_export.sk_mem_bank1_rdata_o = abr_sk_mem_bank1_rdata_o;
assign abr_sig_z_mem_we_i = abr_memory_export.sig_z_mem_we_i;
assign abr_sig_z_mem_waddr_i = abr_memory_export.sig_z_mem_waddr_i;
assign abr_sig_z_mem_wdata_i = abr_memory_export.sig_z_mem_wdata_i;
assign abr_sig_z_mem_wstrobe_i = abr_memory_export.sig_z_mem_wstrobe_i;
assign abr_sig_z_mem_re_i = abr_memory_export.sig_z_mem_re_i;
assign abr_sig_z_mem_raddr_i = abr_memory_export.sig_z_mem_raddr_i;
assign abr_memory_export.sig_z_mem_rdata_o = abr_sig_z_mem_rdata_o;
assign abr_pk_mem_we_i = abr_memory_export.pk_mem_we_i;
assign abr_pk_mem_waddr_i = abr_memory_export.pk_mem_waddr_i;
assign abr_pk_mem_wdata_i = abr_memory_export.pk_mem_wdata_i;
assign abr_pk_mem_wstrobe_i = abr_memory_export.pk_mem_wstrobe_i;
assign abr_pk_mem_re_i = abr_memory_export.pk_mem_re_i;
assign abr_pk_mem_raddr_i = abr_memory_export.pk_mem_raddr_i;
assign abr_memory_export.pk_mem_rdata_o = abr_pk_mem_rdata_o;

caliptra_top #(.pt(pt)) dut (
    .s_axi_w_if(s_axi_if.w_sub),
    .s_axi_r_if(s_axi_if.r_sub),
    .m_axi_w_if(m_axi_if.w_mgr),
    .m_axi_r_if(m_axi_if.r_mgr),
    .el2_mem_export(el2_mem_export.veer_sram_src),
    .abr_memory_export(abr_memory_export.req),
    .clk(clk),
    .cptra_pwrgood(cptra_pwrgood),
    .cptra_rst_b(cptra_rst_b),
    .cptra_obf_key(cptra_obf_key),
    .cptra_csr_hmac_key(cptra_csr_hmac_key),
    .cptra_obf_field_entropy_vld(cptra_obf_field_entropy_vld),
    .cptra_obf_field_entropy(cptra_obf_field_entropy),
    .cptra_obf_uds_seed_vld(cptra_obf_uds_seed_vld),
    .cptra_obf_uds_seed(cptra_obf_uds_seed),
    .jtag_tck(jtag_tck),
    .jtag_tms(jtag_tms),
    .jtag_tdi(jtag_tdi),
    .jtag_trst_n(jtag_trst_n),
    .jtag_tdo(jtag_tdo),
    .jtag_tdoEn(jtag_tdoEn),
    .mbox_sram_cs(mbox_sram_cs),
    .mbox_sram_we(mbox_sram_we),
    .mbox_sram_addr(mbox_sram_addr),
    .mbox_sram_wdata(mbox_sram_wdata),
    .mbox_sram_rdata(mbox_sram_rdata),
    .imem_cs(imem_cs),
    .imem_addr(imem_addr),
    .imem_rdata(imem_rdata),
    .ready_for_fuses(ready_for_fuses),
    .ready_for_mb_processing(ready_for_mb_processing),
    .ready_for_runtime(ready_for_runtime),
    .mailbox_data_avail(mailbox_data_avail),
    .mailbox_flow_done(mailbox_flow_done),
    .recovery_data_avail(recovery_data_avail),
    .recovery_image_activated(recovery_image_activated),
    .BootFSM_BrkPoint(BootFSM_BrkPoint),
    .cptra_error_fatal(cptra_error_fatal),
    .cptra_error_non_fatal(cptra_error_non_fatal),
    .etrng0_req(etrng0_req),
    .etrng1_req(etrng1_req),
    .itrng0_data(itrng0_data),
    .itrng0_valid(itrng0_valid),
    .itrng1_data(itrng1_data),
    .itrng1_valid(itrng1_valid),
    .itrng1_en(itrng1_en),
    .strap_ss_caliptra_base_addr(strap_ss_caliptra_base_addr),
    .strap_ss_mci_base_addr(strap_ss_mci_base_addr),
    .strap_ss_recovery_ifc_base_addr(strap_ss_recovery_ifc_base_addr),
    .strap_ss_external_staging_area_base_addr(strap_ss_external_staging_area_base_addr),
    .strap_ss_otp_fc_base_addr(strap_ss_otp_fc_base_addr),
    .strap_ss_uds_seed_base_addr(strap_ss_uds_seed_base_addr),
    .strap_ss_key_release_base_addr(strap_ss_key_release_base_addr),
    .strap_ss_key_release_key_size(strap_ss_key_release_key_size),
    .strap_ss_prod_debug_unlock_auth_pk_hash_reg_bank_offset(strap_ss_prod_debug_unlock_auth_pk_hash_reg_bank_offset),
    .strap_ss_num_of_prod_debug_unlock_auth_pk_hashes(strap_ss_num_of_prod_debug_unlock_auth_pk_hashes),
    .strap_ss_caliptra_dma_axi_user(strap_ss_caliptra_dma_axi_user),
    .strap_ss_strap_generic_0(strap_ss_strap_generic_0),
    .strap_ss_strap_generic_1(strap_ss_strap_generic_1),
    .strap_ss_strap_generic_2(strap_ss_strap_generic_2),
    .strap_ss_strap_generic_3(strap_ss_strap_generic_3),
    .ss_debug_intent(ss_debug_intent),
    .ss_ocp_lock_en(ss_ocp_lock_en),
    .ss_dbg_manuf_enable(ss_dbg_manuf_enable),
    .ss_soc_dbg_unlock_level(ss_soc_dbg_unlock_level),
    .ss_generic_fw_exec_ctrl(ss_generic_fw_exec_ctrl),
    .generic_input_wires(generic_input_wires),
    .generic_output_wires(generic_output_wires),
    .trace_rv_i_insn_ip(trace_rv_i_insn_ip),
    .trace_rv_i_address_ip(trace_rv_i_address_ip),
    .trace_rv_i_valid_ip(trace_rv_i_valid_ip),
    .trace_rv_i_exception_ip(trace_rv_i_exception_ip),
    .trace_rv_i_ecause_ip(trace_rv_i_ecause_ip),
    .trace_rv_i_interrupt_ip(trace_rv_i_interrupt_ip),
    .trace_rv_i_tval_ip(trace_rv_i_tval_ip),
    .security_state(security_state),
    .scan_mode(scan_mode)
);
endmodule
