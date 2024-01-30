`include "../rtl/adpcm.v"

`timescale 1ns/100ps


module adpcm_tb;

reg [511:0] tb_msg;
`define write_msg(b) begin $write(b); tb_msg = b; end

	wire ack;
	reg req;
	wire signed [15:0] tx_pcm;
	reg [3:0] rx_adpcm;
	wire [3:0] tx_adpcm;
	reg signed [15:0] rx_pcm;
	reg sel_rx;
	reg enable;
	reg rstn, clk;

adpcm dut(
	. ack(ack), 
	. req(req), 
	. tx_pcm(tx_pcm), 
	. rx_adpcm(rx_adpcm), 
	. tx_adpcm(tx_adpcm), 
	. rx_pcm(rx_pcm), 
	. sel_rx(sel_rx), 
	. enable(enable), 
	. rstn(rstn), .clk(clk) 
);

/******************************************************************************************************************/

initial clk = 0;
always #4.46 clk = ~clk;

task init;
	rstn = 0;
	enable = 0;
	sel_rx = 0;
	rx_pcm = 0;
	rx_adpcm = 0;
	req = 0;
endtask

`define rise(s) begin s = 0; repeat(5) @(negedge clk); s = 1; end
`define fall(s) begin s = 1; repeat(5) @(negedge clk); s = 0; end

/******************************************************************************************************************/

`define len	50000
reg signed [15:0] pcm0[`len-1:0];
reg [3:0] adpcm0[`len-1:0];
reg signed [15:0] pcm1[`len-1:0];
reg [3:0] adpcm1[`len-1:0];
reg signed [15:0] pcm2[`len-1:0];
reg signed [31:0] i, j;

task cvsr_adpcm_tx;
	rx_pcm = pcm0[i];
	repeat(5) @(negedge clk);
	req = ~req;
	@(posedge ack);
	adpcm1[i] = tx_adpcm;
endtask

task cvsr_adpcm_rx;
	rx_adpcm = adpcm1[i];
	repeat(5) @(negedge clk);
	req = ~req;
	@(posedge ack);
	pcm2[i] = tx_pcm;
endtask

/******************************************************************************************************************/

integer fp, fp1;

`ifdef ENABLE_TRACE
`define adpcm_tx_trace "../data/adpcm_tx_trace_v.data"
`endif

task cvsr_pcm2adpcm;
	`write_msg("cvsr_pcm2adpcm start\n")
	sel_rx = 1'b0;
	`rise(enable)
`ifdef adpcm_tx_trace
	fp1 = $fopen(`adpcm_tx_trace, "w");
`endif
	for(i = 0; i < `len; i = i + 1) begin
		cvsr_adpcm_tx;
`ifdef adpcm_tx_trace
		$fwrite(fp1, "%6d	", dut.sigma);
		$fwrite(fp1, "%6d	", dut.step);
		$fwrite(fp1, "%6d	", dut.diff);
		$fwrite(fp1, "%6d	", dut.predict);
		$fwrite(fp1, "%6d	", dut.idx);
		$fwrite(fp1, "%6d	", dut.delta);
		$fwrite(fp1, "%6d	", dut.clamp_idx);
		$fwrite(fp1, "%6d\n", dut.nst_step);
`endif
	end
	$fclose(fp1);
	`fall(enable)	
	`write_msg("cvsr_pcm2adpcm end\n")
endtask

`ifdef ENABLE_TRACE
`define adpcm_rx_trace "../data/adpcm_rx_trace_v.data"
`endif

task cvsr_adpcm2pcm;
	`write_msg("cvsr_adpcm2pcm start\n")
	sel_rx = 1'b1;
	`rise(enable)
`ifdef adpcm_rx_trace
	fp1 = $fopen(`adpcm_rx_trace, "w");
`endif
	for(i = 0; i < `len; i = i + 1) begin
		cvsr_adpcm_rx;
`ifdef adpcm_rx_trace
		$fwrite(fp1, "%6d	", dut.sigma);
		$fwrite(fp1, "%6d	", dut.step);
		$fwrite(fp1, "%6d	", dut.diff);
		$fwrite(fp1, "%6d	", dut.predict);
		$fwrite(fp1, "%6d	", dut.idx);
		$fwrite(fp1, "%6d	", dut.delta);
		$fwrite(fp1, "%6d	", dut.clamp_idx);
		$fwrite(fp1, "%6d\n", dut.nst_step);
`endif
	end
	$fclose(fp1);
	`fall(enable)
	`write_msg("cvsr_adpcm2pcm end\n")
endtask

/******************************************************************************************************************/

`define test1_dat "../data/test1.dat"
`define cvsr_test1_dat "../data/cvsr_test1.dat"
`define cvsr_test1_plt "../work/cvsr_test1.plt"

`define adpcm2int(d) $signed(((d&8) ? (0 - (d&7)) : (d&7)))

reg ok_cvsr_test1;
task check_cvsr_test1;
	ok_cvsr_test1 = 1'b1;
	for(i = 0; i < `len; i = i + 1) if(ok_cvsr_test1 && (adpcm0[i] != adpcm1[i])) ok_cvsr_test1 = 1'b0;
	if(ok_cvsr_test1) `write_msg("cvsr_test1 PASS\n")
endtask

task cvsr_test1;
	`write_msg("cvsr_test1 start\n")
	fp = $fopen(`test1_dat, "r");
	for(i = 0; i < `len; i = i + 1) $fscanf(fp, "%d	%d	%d	%d\n", i, pcm0[i], adpcm0[i], pcm1[i]);
	$fclose(fp);
	cvsr_pcm2adpcm;
	cvsr_adpcm2pcm;
	check_cvsr_test1;
	fp = $fopen(`cvsr_test1_dat, "w");
	for(i = 0; i < `len; i = i + 1) begin
		$fwrite(fp, "%d	", i);
		$fwrite(fp, "%d	", pcm0[i]);
		$fwrite(fp, "%d	", `adpcm2int(adpcm0[i]));
		$fwrite(fp, "%d	", `adpcm2int(adpcm1[i]));
		$fwrite(fp, "%d	", pcm1[i]);
		$fwrite(fp, "%d	", pcm2[i]);
		$fwrite(fp, "\n");
	end
	$fclose(fp);
	fp = $fopen(`cvsr_test1_plt, "w");
	$fwrite(fp, "set terminal x11\nplot \\\n");
	$fwrite(fp, "'%s' using 1:2 with lines title 'pcm', \\\n", `cvsr_test1_dat);
	$fwrite(fp, "'%s' using 1:3 with lines title 'adpcm c', \\\n", `cvsr_test1_dat);
	$fwrite(fp, "'%s' using 1:4 with lines title 'adpcm v', \\\n", `cvsr_test1_dat);
	$fwrite(fp, "'%s' using 1:5 with lines title 'pcm c', \\\n", `cvsr_test1_dat);
	$fwrite(fp, "'%s' using 1:6 with lines title 'pcm v'\n", `cvsr_test1_dat);
	$fclose(fp);
	$write("gnuplot cmd: load '%s'\n", `cvsr_test1_plt);
	`write_msg("cvsr_test1 end\n")
endtask

/******************************************************************************************************************/

`define test2_stage1_dat "../data/test2_stage1.dat"
`define test2_stage2_dat "../data/test2_stage2.dat"
`define test2_stage3_dat "../data/test2_stage3.dat"

task test2;
	`write_msg("test2 start\n")
	fp = $fopen(`test2_stage1_dat, "r");
	fp1 = $fopen(`test2_stage2_dat, "w");
	i = 0;
	sel_rx = 1'b0;
	`rise(enable)
	while(!$feof(fp)) begin
		$fscanf(fp, "%8d	%8d	%8d\n", pcm0[i], adpcm0[i], pcm1[i]);
		cvsr_adpcm_tx;
		$fwrite(fp1, "%8d\n", adpcm1[i]);
	end
	`fall(enable)
	$fclose(fp);
	$fclose(fp1);
	fp = $fopen(`test2_stage2_dat, "r");
	fp1 = $fopen(`test2_stage3_dat, "w");
	sel_rx = 1'b1;
	`rise(enable)
	while(!$feof(fp)) begin
		$fscanf(fp, "%8d\n", adpcm1[i]);
		cvsr_adpcm_rx;
		$fwrite(fp1, "%8d\n", pcm2[i]);
	end
	`fall(enable)
	$fclose(fp);
	$fclose(fp1);
	`write_msg("test2 end\n")
endtask


/******************************************************************************************************************/

initial begin
	init;
	`rise(rstn)
`ifdef ENABLE_TEST1
	cvsr_test1;
`endif
`ifdef ENABLE_TEST2
	test2;
`endif
	`fall(rstn)
	$finish;
end

`ifdef ENABLE_TEST1
initial begin
	$fsdbDumpfile("../work/adpcm_tb.fsdb");
	$fsdbDumpvars(0, adpcm_tb);
end
`endif

endmodule
