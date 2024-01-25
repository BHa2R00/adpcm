#define NOB_IMPLEMENTATION
#include "./nob.h"
#include "./nob_vcs.h"

Nob_Proc build_c(){
	Nob_Cmd cmd = {0};
	nob_cmd_append(&cmd, "cc");
	nob_cmd_append(&cmd, "../src/adpcm_1.c");
	nob_cmd_append(&cmd, "-lm", "-O0");
	nob_cmd_append(&cmd, "-o", "../bin/adpcm");
	return nob_cmd_run_sync(cmd);
}

Nob_Proc run_c(){
	Nob_Cmd cmd = {0};
	nob_cmd_append(&cmd, "../bin/adpcm");
	return nob_cmd_run_sync(cmd);
}

Nob_Proc build_tb(){
	Nob_Cmd cmd = {0};
	nob_cmd_append_vcs(cmd);
	nob_cmd_append(&cmd, "../tb/adpcm_tb.sv");
	return nob_cmd_run_sync(cmd);
}

Nob_Proc run_tb(){
	Nob_Cmd cmd = {0};
	nob_cmd_append(&cmd, "./simv");
	return nob_cmd_run_sync(cmd);
}

int main(int argc, char** argv){
	NOB_GO_REBUILD_URSELF(argc, argv);
	Nob_Procs procs = {0};
	nob_da_append(&procs, build_c());
	nob_da_append(&procs, run_c());
	nob_da_append(&procs, build_tb());
	nob_da_append(&procs, run_tb());
	return 0;
}
