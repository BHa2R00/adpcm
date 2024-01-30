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

Nob_Proc run_print_verilog(){
	Nob_Cmd cmd = {0};
	nob_cmd_append(&cmd, "../bin/adpcm", "print_verilog");
	return nob_cmd_run_sync(cmd);
}

Nob_Proc run_c_test1(){
	Nob_Cmd cmd = {0};
	nob_cmd_append(&cmd, "../bin/adpcm", "test1");
	return nob_cmd_run_sync(cmd);
}

Nob_Proc run_c_test2_stage1(){
	Nob_Cmd cmd = {0};
	nob_cmd_append(&cmd, "../bin/adpcm", "test2_stage1");
	return nob_cmd_run_sync(cmd);
}

Nob_Proc run_c_test2_stage4(){
	Nob_Cmd cmd = {0};
	nob_cmd_append(&cmd, "../bin/adpcm", "test2_stage4");
	return nob_cmd_run_sync(cmd);
}

Nob_Proc build_tb_test1(){
	Nob_Cmd cmd = {0};
	nob_cmd_append_vcs(cmd);
	nob_cmd_append(&cmd, "+define+ENABLE_TRACE", "+define+ENABLE_TEST1", "../tb/adpcm_tb.sv");
	return nob_cmd_run_sync(cmd);
}

Nob_Proc build_tb_test2(){
	Nob_Cmd cmd = {0};
	nob_cmd_append_vcs(cmd);
	nob_cmd_append(&cmd, "+define+ENABLE_TEST2", "../tb/adpcm_tb.sv");
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
	nob_da_append(&procs, run_print_verilog());
	nob_da_append(&procs, run_c_test1());
	nob_da_append(&procs, build_tb_test1());
	nob_da_append(&procs, run_tb());
	nob_da_append(&procs, run_c_test2_stage1());
	nob_da_append(&procs, build_tb_test2());
	nob_da_append(&procs, run_tb());
	nob_da_append(&procs, run_c_test2_stage4());
	return 0;
}
