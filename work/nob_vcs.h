#define nob_cmd_append_vcs(cmd) \
	nob_cmd_append(&cmd, "vcs", "-o", "./simv"); \
	nob_cmd_append(&cmd, "-j16", "-RI", "-full64"); \
	nob_cmd_append(&cmd, "-sverilog", "+v2k"); \
	nob_cmd_append(&cmd, "-debug_access+all", "-kdb", "+sdfverbos"); \
	nob_cmd_append(&cmd, "+define+vcs", "+maxdelays"); \
	nob_cmd_append(&cmd, "-timescale=1ns/100ps");
