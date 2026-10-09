"""Generate the flat-port ASIC synthesis wrapper around ``caliptra_top``.

``caliptra_top`` exposes SystemVerilog interface ports (AXI subordinate and
manager, VeeR EL2 SRAM export, Adams Bridge memory export). Synthesis tools
need a plain port list at the boundary, so this script writes
``synth/caliptra_synth_wrapper.sv``: a module with the same scalar ports as
``caliptra_top`` plus one flat port per interface signal, which instantiates
the interfaces internally and wires them to ``caliptra_top``.

Inputs (all read from the Caliptra checkout):
  - src/integration/rtl/caliptra_top.sv               (module header and ports)
  - src/axi/rtl/axi_if.sv                             (AXI signals + modports)
  - src/riscv_core/veer_el2/rtl/lib/el2_mem_if.sv     (EL2 SRAM signals + modport)

The Adams Bridge memory signal list is hardcoded below (see ABR_MEMORIES).

Rerun after an upstream change to the ``caliptra_top`` ports or to any of the
interfaces above. From the Caliptra checkout root:

    python3 .booley_project/synth/generate_wrapper.py

Standard library only.
"""

from __future__ import annotations

import re
from pathlib import Path

# The Caliptra checkout: this file lives at <root>/.booley_project/synth/.
ROOT = Path(__file__).resolve().parents[2]
TOP_PATH = ROOT / "src/integration/rtl/caliptra_top.sv"
AXI_IF_PATH = ROOT / "src/axi/rtl/axi_if.sv"
EL2_MEM_IF_PATH = ROOT / "src/riscv_core/veer_el2/rtl/lib/el2_mem_if.sv"
OUTPUT_PATH = ROOT / ".booley_project/synth/caliptra_synth_wrapper.sv"

# Marks the end of the parameter list and the start of the port list in
# caliptra_top.sv. The leading "    (\n" is skipped to reach the first port.
PORT_LIST_START = "    (\n    input logic"
PORT_LIST_OPEN = "    (\n"

# Interface ports of caliptra_top; these are flattened, not copied verbatim.
INTERFACE_PORT_PATTERN = r"^(axi_if|el2_mem_if|abr_mem_if)\."

# Per AXI bus: (flat port prefix, modport kind, AW, DW, IW, UW). The width
# expressions replace the axi_if parameters in each signal's declared type
# and match the parameters used for the internal axi_if instances.
AXI_BUSES = [
    (
        "s_axi",
        "sub",
        "`CALIPTRA_SLAVE_ADDR_WIDTH(`CALIPTRA_SLAVE_SEL_SOC_IFC)",
        "`CALIPTRA_AXI_DATA_WIDTH",
        "`CALIPTRA_AXI_ID_WIDTH",
        "`CALIPTRA_AXI_USER_WIDTH",
    ),
    (
        "m_axi",
        "mgr",
        "`CALIPTRA_AXI_DMA_ADDR_WIDTH",
        "CPTRA_AXI_DMA_DATA_WIDTH",
        "CPTRA_AXI_DMA_ID_WIDTH",
        "CPTRA_AXI_DMA_USER_WIDTH",
    ),
]

# Adams Bridge memories exported through abr_mem_if:
# (memory name, abr_params_pkg width-parameter prefix, has byte-write strobe).
ABR_MEMORIES = [
    ("w1_mem", "ABR_MEM_W1", False),
    ("mem_inst0_bank0", "ABR_MEM_INST0", False),
    ("mem_inst0_bank1", "ABR_MEM_INST0", False),
    ("mem_inst1", "ABR_MEM_INST1", False),
    ("mem_inst2", "ABR_MEM_INST2", False),
    ("mem_inst0_bank0_masked", "ABR_MEM_INST0", False),
    ("mem_inst0_bank1_masked", "ABR_MEM_INST0", False),
    ("mem_inst1_masked", "ABR_MEM_INST1", False),
    ("mem_inst2_masked", "ABR_MEM_INST2", False),
    ("sk_mem_bank0", "SK_MEM_BANK", False),
    ("sk_mem_bank1", "SK_MEM_BANK", False),
    ("sig_z_mem", "SIG_Z_MEM", True),
    ("pk_mem", "PK_MEM", True),
]

# Fixed internal interface instances. The parameters must match AXI_BUSES.
INTERFACE_INSTANCES = (
    "axi_if #(.AW(`CALIPTRA_SLAVE_ADDR_WIDTH(`CALIPTRA_SLAVE_SEL_SOC_IFC)), "
    ".DW(`CALIPTRA_AXI_DATA_WIDTH), .IW(`CALIPTRA_AXI_ID_WIDTH), "
    ".UW(`CALIPTRA_AXI_USER_WIDTH)) s_axi_if (.clk(clk), .rst_n(cptra_rst_b));\n"
    "axi_if #(.AW(`CALIPTRA_AXI_DMA_ADDR_WIDTH), .DW(CPTRA_AXI_DMA_DATA_WIDTH), "
    ".IW(CPTRA_AXI_DMA_ID_WIDTH), .UW(CPTRA_AXI_DMA_USER_WIDTH)) m_axi_if "
    "(.clk(clk), .rst_n(cptra_rst_b));\n"
    "el2_mem_if #(.pt(pt)) el2_mem_export ();\n"
    "abr_mem_if abr_memory_export ();\n"
)


def strip_line_comments(text: str) -> str:
    """Remove ``//`` comments so commas inside them do not split ports."""
    return re.sub(r"//[^\n]*", "", text)


def split_top(top_text: str) -> tuple[str, list[str]]:
    """Split caliptra_top.sv into its module header and scalar port decls.

    Returns the text from ``module caliptra_top`` up to the port list (the
    header, including imports and parameters) and the list of non-interface
    port declarations, e.g. ``input logic clk``. Interface ports are dropped
    because they are flattened separately; any other port shape raises.
    """
    module_start = top_text.index("module caliptra_top")
    ports_start = top_text.index(PORT_LIST_START, module_start)
    ports_end = top_text.index("\n);", module_start)
    header = top_text[module_start:ports_start]
    port_text = top_text[ports_start + len(PORT_LIST_OPEN) : ports_end]

    port_decls = [
        part.strip()
        for part in strip_line_comments(port_text).split(",")
        if part.strip()
    ]
    scalar_ports = []
    for decl in port_decls:
        if re.match(r"^(input|output|inout)\s", decl):
            scalar_ports.append(decl)
        elif re.match(INTERFACE_PORT_PATTERN, decl):
            continue
        else:
            raise ValueError("unparsed top port " + decl)
    return header, scalar_ports


def parse_logic_decls(path: Path, begin: str, end: str) -> dict[str, str]:
    """Map each ``logic`` signal name to its type text (packed dimensions).

    Only the region between the first ``begin`` marker and the following
    ``end`` marker is scanned, e.g. an interface body up to its modports.
    ``logic [AW-1:0] araddr;`` yields ``{"araddr": "[AW-1:0]"}``.
    """
    text = path.read_text()
    region_start = text.index(begin)
    region = strip_line_comments(text[region_start : text.index(end, region_start)])
    return {
        match.group(2): match.group(1).strip()
        for match in re.finditer(r"\blogic\s+([^;]*?)\b(\w+)\s*;", region)
    }


def parse_modport(interface_text: str, modport_name: str) -> dict[str, str | None]:
    """Map each signal of a modport to its direction (``input``/``output``).

    A direction keyword applies to every following signal until the next
    keyword, as in SystemVerilog modport syntax.
    """
    body = re.search(
        r"modport\s+" + modport_name + r"\s*\((.*?)\);", interface_text, re.DOTALL
    ).group(1)
    body = strip_line_comments(body)
    directions: dict[str, str | None] = {}
    direction = None
    for token in body.split(","):
        item = token.strip()
        if not item:
            continue
        match = re.match(r"(input|output)\s+(\w+)", item)
        if match:
            direction, signal = match.groups()
        else:
            signal = item
        directions[signal] = direction
    return directions


class FlatPorts:
    """Accumulates flat wrapper ports and their ``assign`` statements."""

    def __init__(self) -> None:
        self.ports: list[str] = []
        self.assignments: list[str] = []

    def add(self, direction: str, packed_type: str, port: str, internal: str) -> None:
        """Add one flat port wired to an interface signal ``internal``.

        Inputs drive the interface signal; anything else is driven by it.
        An empty ``packed_type`` would leave a double space, which is removed.
        """
        self.ports.append(
            f"{direction} logic {packed_type} {port}".replace("logic  ", "logic ")
        )
        if direction == "input":
            self.assignments.append(f"assign {internal} = {port};")
        else:
            self.assignments.append(f"assign {port} = {internal};")


def flatten_axi(flat: FlatPorts, connections: list[str]) -> None:
    """Flatten the write and read modports of both AXI buses."""
    axi_text = AXI_IF_PATH.read_text()
    axi_types = parse_logic_decls(
        AXI_IF_PATH, "interface axi_if", "// Modport for read manager"
    )
    for prefix, kind, addr_w, data_w, id_w, user_w in AXI_BUSES:
        directions = {
            **parse_modport(axi_text, "w_" + kind),
            **parse_modport(axi_text, "r_" + kind),
        }
        width_params = [("AW", addr_w), ("DW", data_w), ("IW", id_w), ("UW", user_w)]
        for signal, direction in directions.items():
            # Substitute the concrete width expression for each axi_if parameter.
            packed_type = axi_types[signal]
            for param, value in width_params:
                packed_type = re.sub(
                    r"\b" + param + r"\b", "(" + value + ")", packed_type
                )
            flat.add(
                direction, packed_type, f"{prefix}_{signal}", f"{prefix}_if.{signal}"
            )
        connections += [
            f".{prefix}_w_if({prefix}_if.w_{kind})",
            f".{prefix}_r_if({prefix}_if.r_{kind})",
        ]


def flatten_el2_mem(flat: FlatPorts, connections: list[str]) -> None:
    """Flatten the VeeR EL2 SRAM export (``veer_sram_src`` modport)."""
    el2_types = parse_logic_decls(
        EL2_MEM_IF_PATH, "interface el2_mem_if", "// MODPORTS"
    )
    directions = parse_modport(EL2_MEM_IF_PATH.read_text(), "veer_sram_src")
    for signal, direction in directions.items():
        flat.add(
            direction, el2_types[signal], "el2_" + signal, "el2_mem_export." + signal
        )
    connections.append(".el2_mem_export(el2_mem_export.veer_sram_src)")


def flatten_abr_mem(flat: FlatPorts, connections: list[str]) -> None:
    """Flatten the Adams Bridge memory export (``req`` modport).

    The signal set is fixed per memory; widths come from abr_params_pkg.
    Directions are from the wrapper's point of view: requests leave Caliptra
    (outputs) and read data returns from the memory macro (input).
    """
    for memory, param_prefix, has_strobe in ABR_MEMORIES:
        signals = [
            ("we_i", "", "output"),
            ("waddr_i", f"[{param_prefix}_ADDR_W-1:0]", "output"),
            ("wdata_i", f"[{param_prefix}_DATA_W-1:0]", "output"),
            ("wstrobe_i", f"[{param_prefix}_WSTROBE_W-1:0]", "output"),
            ("re_i", "", "output"),
            ("raddr_i", f"[{param_prefix}_ADDR_W-1:0]", "output"),
            ("rdata_o", f"[{param_prefix}_DATA_W-1:0]", "input"),
        ]
        for suffix, packed_type, direction in signals:
            if suffix == "wstrobe_i" and not has_strobe:
                continue
            signal = f"{memory}_{suffix}"
            flat.add(
                direction, packed_type, "abr_" + signal, "abr_memory_export." + signal
            )
    connections.append(".abr_memory_export(abr_memory_export.req)")


def wrapper_header(top_header: str) -> str:
    """Turn caliptra_top's header into the wrapper's header.

    Keeps the package imports (adding the axi and abr packages the flat port
    widths need) but replaces the parameter list with the DUT's default CPU
    parameter record from ``el2_param.vh``.
    """
    header = top_header.replace(
        "module caliptra_top", "module caliptra_synth_wrapper", 1
    )
    header = header[: header.index("    #(")]
    header = header.replace(
        "    import el2_pkg::*;",
        "    import el2_pkg::*;\n    import axi_pkg::*;\n    import abr_params_pkg::*;",
    )
    return header + '    #(\n    `include "el2_param.vh"\n    )\n'


def main() -> None:
    top_header, scalar_ports = split_top(TOP_PATH.read_text())

    flat = FlatPorts()
    # Port connections of the caliptra_top instance, in emission order.
    connections: list[str] = []
    flatten_axi(flat, connections)
    flatten_el2_mem(flat, connections)
    flatten_abr_mem(flat, connections)
    for decl in scalar_ports:
        port_name = re.search(r"(\w+)\s*$", decl).group(1)
        connections.append(f".{port_name}({port_name})")

    port_list = ",\n".join("    " + port for port in scalar_ports + flat.ports)
    connection_list = ",\n".join("    " + conn for conn in connections)
    output = (
        "// SPDX-License-Identifier: Apache-2.0\n"
        "// Generated flat-port ASIC synthesis boundary for Caliptra.\n"
        '`include "config_defines.svh"\n'
        + wrapper_header(top_header)
        + "    (\n"
        + port_list
        + "\n);\n\n"
        + INTERFACE_INSTANCES
        + "\n".join(flat.assignments)
        + "\n\ncaliptra_top #(.pt(pt)) dut (\n"
        + connection_list
        + "\n);\nendmodule\n"
    )
    OUTPUT_PATH.write_text(output)
    print(
        f"{len(scalar_ports)} scalar ports, {len(flat.ports)} flattened interface ports, "
        f"{len(output.splitlines())} wrapper lines"
    )


if __name__ == "__main__":
    main()
