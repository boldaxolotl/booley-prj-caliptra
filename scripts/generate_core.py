"""Generate the FuseSoC cores for Caliptra from the upstream VF filelists.

Writes two CAPI=2 cores under ``.booley_project/cores/``:

- ``caliptra_rtl.core`` (``local:caliptra:rtl:1``): the reusable design RTL
  and its include headers, from ``src/integration/config/caliptra_top.vf``.
  ``cores/caliptra_synth.core`` (hand-written) also depends on it.
- ``caliptra_booley.core`` (``local:caliptra:booley:1``): the Booley adapter
  with the ``sim_caliptra`` and ``lint_caliptra`` Verilator Targets. It adds
  the testbench files from ``caliptra_top_tb.vf`` that are not in the RTL
  list, the upstream ``caliptra_top_tb.vlt`` waivers, and the patched C++ TB
  main produced by ``generate_main.py``.

Rerun after an upstream filelist, include-directory, or ``.vlt`` change.
From the Caliptra checkout root:

    python3 .booley_project/scripts/generate_core.py

Requires PyYAML.
"""

from __future__ import annotations

from pathlib import Path

import yaml

# The Caliptra checkout: this file lives at <root>/.booley_project/scripts/.
ROOT = Path(__file__).resolve().parents[2]
COMMON_OUT = ROOT / ".booley_project/cores/caliptra_rtl.core"
ADAPTER_OUT = ROOT / ".booley_project/cores/caliptra_booley.core"


def resolve(line: str) -> str:
    """Expand the upstream filelist variables to checkout-relative paths.

    FuseSoC paths are relative to the core root, so ``${CALIPTRA_ROOT}/`` is
    dropped and the other variables get the values upstream uses for
    Verilator. Any variable left over is unknown and fails the run.
    """
    value = line.replace("${CALIPTRA_ROOT}/", "")
    value = value.replace("${CALIPTRA_PRIM_ROOT}/", "src/caliptra_prim_generic/")
    value = value.replace("${CALIPTRA_PRIM_MODULE_PREFIX}", "caliptra_prim_generic")
    value = value.replace("${CALIPTRA_AXI4PC_DIR}/", "src/integration/tb/")
    value = value.replace("${CALIPTRA_AXI4PC_DIR}", "src/integration/tb")
    if "${" in value:
        raise ValueError(value)
    return value


def read_filelist(name: str) -> tuple[list[str], list[str]]:
    """Return (source files, include dirs) from a ``.vf`` filelist.

    Sources are deduplicated in first-seen order and must exist. Any ``+``
    option other than ``+incdir+`` is unsupported and fails the run.
    """
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
    """Build a FuseSoC file entry; ``.svh``/``.vh`` become include files."""
    ext = Path(path).suffix
    file_type = "verilogSource" if ext == ".v" else "systemVerilogSource"
    entry: dict[str, object] = {"file_type": file_type}
    if ext in {".svh", ".vh"}:
        entry["is_include_file"] = True
    return {path: entry}


def main() -> None:
    rtl_sources, rtl_dirs = read_filelist("src/integration/config/caliptra_top.vf")
    sim_sources, sim_dirs = read_filelist("src/integration/config/caliptra_top_tb.vf")
    # The TB filelist repeats the RTL list; the adapter core keeps only the
    # TB-only files and pulls the RTL in through the rtl core dependency.
    tb_sources = [path for path in sim_sources if path not in rtl_sources]

    # Files in the include dirs that are not compiled as sources must still be
    # declared so FuseSoC copies them into the build tree for `include. This
    # deliberately sweeps whole directories, including stray .sv files.

    headers: list[str] = []
    for directory in dict.fromkeys(sim_dirs):
        for path in sorted((ROOT / directory).glob("*")):
            if path.suffix in {".svh", ".vh", ".h", ".svi", ".sv"}:
                relative = str(path.relative_to(ROOT))
                if relative not in sim_sources and relative not in headers:
                    headers.append(relative)
    # Headers under an RTL include dir belong to the RTL core; the rest
    # (TB-only include dirs) go to the adapter core.
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
                    {
                        path: {
                            "file_type": "systemVerilogSource",
                            "is_include_file": True,
                        }
                    }
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
            "tb": {
                "files": [source_entry(path) for path in tb_sources],
                "tags": ["tb"],
            },
            "tb_headers": {
                "files": [
                    {
                        path: {
                            "file_type": "systemVerilogSource",
                            "is_include_file": True,
                        }
                    }
                    for path in tb_headers
                ],
                "tags": ["tb"],
            },
            # caliptra_top_tb.vlt is itself a list of upstream .vlt waiver
            # files, one path per line.
            "vlt": {
                "files": [
                    {path: {"file_type": "vlt"}}
                    for path in dict.fromkeys(
                        resolve(line.strip())
                        for line in (
                            ROOT / "src/integration/config/caliptra_top_tb.vlt"
                        )
                        .read_text()
                        .splitlines()
                        if line.strip() and not line.lstrip().startswith("//")
                    )
                ],
            },
            # Patched Verilator main (see generate_main.py) plus the JTAG
            # DPI and TCP server C sources the upstream TB links in.
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
                    # Defines, timescale, and -Wno-* waivers mirror the
                    # upstream Verilator build in tools/scripts/Makefile.
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
                    # Defines, timescale, and -Wno-* waivers mirror the
                    # upstream Verilator build in tools/scripts/Makefile.
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

    # Omit tb_headers rather than emit an empty fileset when no TB-only
    # include dir contributes a header.
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


if __name__ == "__main__":
    main()
