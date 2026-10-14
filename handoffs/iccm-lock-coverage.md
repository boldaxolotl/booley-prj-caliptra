ICCM coverage from iccm_lock on sim_caliptra, including reset activity.

Simulation passed. Booley coverage report conversion failed with COV_POINT_LIMIT (uncompressed V2 point storage limit). The JSON handoff contains counts extracted from the retained native database with Booley's native-record parser; it is not a completed Booley coverage report.

The adapter generators now declare a reset-inclusive write_hook and invoke Booley's packaged coverage bridge under VM_COVERAGE. No upstream RTL or firmware changed.

Plain Doctor: 64 passed, 0 failures, 1 pre-existing warning about /work/.git/info/attributes. Deep verification (/booley-heal) is due following this adapter configuration change; it was not run during task work.
