from __future__ import annotations

from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
COMMON_OUT = ROOT / ".booley_project/cores/caliptra_rtl.core"
ADAPTER_OUT = ROOT / ".booley_project/cores/caliptra_booley.core"


def resolve(line: str) -> str:
    value = line.replace("${CALIPTRA_ROOT}/", "")
    value = value.replace("${CALIPTRA_PRIM_ROOT}/", "src/caliptra_prim_generic/")
    value = value.replace("${CALIPTRA_PRIM_MODULE_PREFIX}", "caliptra_prim_generic")
    value = value.replace("${CALIPTRA_AXI4PC_DIR}/", "src/integration/tb/")
    value = value.replace("${CALIPTRA_AXI4PC_DIR}", "src/integration/tb")
    if "${" in value:
        raise ValueError(value)
    return value


def read_filelist(name: str) -> tuple[list[str], list[str]]:
    sources: list[str] = []
    dirs: list[str] = []
    for raw in (ROOT / name).read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith(("//", "#")):
            continue
        if line.startswith("+incdir+"):
            dirs.append(resolve(line.removeprefix("+incdir+")))
        elif line.startswith("+"):
            raise ValueError(line)
        else:
            path = resolve(line)
            if not (ROOT / path).is_file():
                raise FileNotFoundError(path)
            if path not in sources:
                sources.append(path)
    return sources, dirs


def source_entry(path: str) -> dict[str, dict[str, object]]:
    ext = Path(path).suffix
    file_type = "verilogSource" if ext == ".v" else "systemVerilogSource"
    entry: dict[str, object] = {"file_type": file_type}
    if ext in {".svh", ".vh"}:
        entry["is_include_file"] = True
    return {path: entry}


rtl_sources, rtl_dirs = read_filelist("src/integration/config/caliptra_top.vf")
sim_sources, sim_dirs = read_filelist("src/integration/config/caliptra_top_tb.vf")
tb_sources = [path for path in sim_sources if path not in rtl_sources]

headers: list[str] = []
for directory in dict.fromkeys(sim_dirs):
    for path in sorted((ROOT / directory).glob("*")):
        if path.suffix in {".svh", ".vh", ".h", ".svi", ".sv"}:
            relative = str(path.relative_to(ROOT))
            if relative not in sim_sources and relative not in headers:
                headers.append(relative)
rtl_headers = [
    path for path in headers if any(path.startswith(d + "/") for d in rtl_dirs)
]
tb_headers = [path for path in headers if path not in rtl_headers]

common_core = {
    "name": "local:caliptra:rtl:1",
    "description": "Caliptra reusable RTL generated from the upstream VF filelist",
    "filesets": {
        "rtl": {"files": [source_entry(path) for path in rtl_sources]},
        "rtl_headers": {
            "files": [
                {path: {"file_type": "systemVerilogSource", "is_include_file": True}}
                for path in rtl_headers
            ]
        },
    },
    "targets": {
        "default": {"filesets": ["rtl", "rtl_headers"]},
    },
}

adapter_core = {
    "name": "local:caliptra:booley:1",
    "description": "Caliptra RTL Booley adapter generated from upstream VF filelists",
    "filesets": {
        "design": {"depend": ["local:caliptra:rtl:1"]},
        "tb": {"files": [source_entry(path) for path in tb_sources], "tags": ["tb"]},
        "tb_headers": {
            "files": [
                {path: {"file_type": "systemVerilogSource", "is_include_file": True}}
                for path in tb_headers
            ],
            "tags": ["tb"],
        },
        "vlt": {
            "files": [
                {path: {"file_type": "vlt"}}
                for path in dict.fromkeys(
                    resolve(line.strip())
                    for line in (ROOT / "src/integration/config/caliptra_top_tb.vlt")
                    .read_text()
                    .splitlines()
                    if line.strip() and not line.lstrip().startswith("//")
                )
            ],
        },
        "tb_cpp": {
            "files": [
                {
                    ".booley_project/generated/test_caliptra_top_tb.cpp": {
                        "file_type": "cppSource"
                    }
                },
                {
                    "src/integration/test_suites/libs/jtagdpi/jtagdpi.c": {
                        "file_type": "cSource"
                    }
                },
                {
                    "src/integration/test_suites/libs/tcp_server/tcp_server.c": {
                        "file_type": "cSource"
                    }
                },
                {
                    "src/integration/test_suites/libs/jtagdpi/jtagdpi.h": {
                        "file_type": "cSource",
                        "is_include_file": True,
                    }
                },
                {
                    "src/integration/test_suites/libs/tcp_server/tcp_server.h": {
                        "file_type": "cSource",
                        "is_include_file": True,
                    }
                },
            ],
            "tags": ["tb"],
        },
    },
    "targets": {
        "sim_caliptra": {
            "flow": "sim",
            "flow_options": {
                "tool": "verilator",
                "booley": {"doctor": ["sim"]},
                "verilator_options": [
                    "+define+RV_OPENSOURCE",
                    "+define+CALIPTRA_INTERNAL_TRNG",
                    "+define+CALIPTRA_TOP_TB",
                    "+define+CALIPTRA_TOP=caliptra_top_tb",
                    "+define+RV_TOP=caliptra_top_tb.caliptra_top_dut.rvtop",
                    "--timing",
                    "--exe",
                    "--timescale",
                    "1ns/100ps",
                    "--autoflush",
                    "-Wno-WIDTH",
                    "-Wno-UNOPTFLAT",
                    "-Wno-LITENDIAN",
                    "-Wno-CMPCONST",
                    "-Wno-MULTIDRIVEN",
                    "-Wno-UNPACKED",
                    "-Wno-LATCH",
                    "-Wno-fatal",
                ],
            },
            "filesets": ["design", "tb", "tb_headers", "vlt", "tb_cpp"],
            "toplevel": "caliptra_top_tb",
        },
        "lint_caliptra": {
            "flow": "lint",
            "flow_options": {
                "tool": "verilator",
                "booley": {"doctor": ["lint"]},
                "verilator_options": [
                    "+define+RV_OPENSOURCE",
                    "+define+CALIPTRA_INTERNAL_TRNG",
                    "+define+CALIPTRA_TOP_TB",
                    "+define+CALIPTRA_TOP=caliptra_top_tb",
                    "+define+RV_TOP=caliptra_top_tb.caliptra_top_dut.rvtop",
                    "--timing",
                    "-Wno-WIDTH",
                    "-Wno-UNOPTFLAT",
                    "-Wno-LITENDIAN",
                    "-Wno-CMPCONST",
                    "-Wno-MULTIDRIVEN",
                    "-Wno-UNPACKED",
                    "-Wno-LATCH",
                    "-Wno-fatal",
                ],
            },
            "filesets": ["design", "tb", "tb_headers", "vlt"],
            "toplevel": "caliptra_top_tb",
        },
    },
}

if not tb_headers:
    del adapter_core["filesets"]["tb_headers"]
    adapter_core["targets"]["sim_caliptra"]["filesets"].remove("tb_headers")
    adapter_core["targets"]["lint_caliptra"]["filesets"].remove("tb_headers")

COMMON_OUT.parent.mkdir(parents=True, exist_ok=True)
COMMON_OUT.write_text("CAPI=2:\n" + yaml.safe_dump(common_core, sort_keys=False))
ADAPTER_OUT.write_text("CAPI=2:\n" + yaml.safe_dump(adapter_core, sort_keys=False))
print(
    f"{COMMON_OUT}: RTL {len(rtl_sources)}, headers {len(rtl_headers)}; "
    f"{ADAPTER_OUT}: TB {len(tb_sources)}, headers {len(tb_headers)}"
)
