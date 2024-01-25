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

`define len	10000
`define test1_dat "../data/test1.dat"
`define cvsr_test1_dat "../data/cvsr_test1.dat"
`define cvsr_test1_plt "../work/cvsr_test1.plt"
integer fp;

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

`define adpcm2int(d) $signed(((d&8) ? (0 - (d&7)) : (d&7)))
reg signed [15:0] pcm0[`len-1:0];
reg [3:0] adpcm[`len-1:0];
reg signed [15:0] pcm1[`len-1:0];
reg [3:0] adpcm1[`len-1:0];
reg signed [15:0] pcm2[`len-1:0];
reg signed [31:0] i;

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

task cvsr_pcm2adpcm;
	`write_msg("cvsr_pcm2adpcm start\n")
	sel_rx = 1'b0;
	`rise(enable)
	for(i = 0; i < `len; i++) cvsr_adpcm_tx;
	`fall(enable)	
	`write_msg("cvsr_pcm2adpcm end\n")
endtask

task cvsr_adpcm2pcm;
	`write_msg("cvsr_adpcm2pcm start\n")
	sel_rx = 1'b1;
	`rise(enable)
	for(i = 0; i < `len; i++) cvsr_adpcm_rx;
	`fall(enable)
	`write_msg("cvsr_adpcm2pcm end\n")
endtask

task cvsr_test1;
	`write_msg("cvsr_test1 start\n")
	fp = $fopen(`test1_dat, "r");
	for(i = 0; i < `len; i++) $fscanf(fp, "%d	%d	%d	%d\n", i, pcm0[i], adpcm[i], pcm1[i]);
	$fclose(fp);
	cvsr_pcm2adpcm;
	cvsr_adpcm2pcm;
	fp = $fopen(`cvsr_test1_dat, "w");
	for(i = 0; i < `len; i++) begin
		$fwrite(fp, "%d	", i);
		$fwrite(fp, "%d	", pcm0[i]);
		$fwrite(fp, "%d	", `adpcm2int(adpcm[i]));
		$fwrite(fp, "%d	", `adpcm2int(adpcm1[i]));
		$fwrite(fp, "%d	", pcm1[i]);
		$fwrite(fp, "%d	", pcm2[i]);
		$fwrite(fp, "\n");
	end
	$fclose(fp);
	fp = $fopen(`cvsr_test1_plt, "w");
	$fwrite(fp, "set terminal x11\nplot \\\n");
	$fwrite(fp, "'%s' using 1:2 with lines title 'pcm0', \\\n", `cvsr_test1_dat);
	$fwrite(fp, "'%s' using 1:3 with lines title 'adpcm', \\\n", `cvsr_test1_dat);
	$fwrite(fp, "'%s' using 1:4 with lines title 'adpcm1', \\\n", `cvsr_test1_dat);
	$fwrite(fp, "'%s' using 1:5 with lines title 'pcm1', \\\n", `cvsr_test1_dat);
	$fwrite(fp, "'%s' using 1:6 with lines title 'pcm2'\n", `cvsr_test1_dat);
	$fclose(fp);
	$write("gnuplot cmd: load '%s'\n", `cvsr_test1_plt);
	`write_msg("cvsr_test1 end\n")
endtask

initial begin
	init;
	`rise(rstn)
	cvsr_test1;
	`fall(rstn)
	$finish;
end

initial begin
	$fsdbDumpfile("../work/adpcm_tb.fsdb");
	$fsdbDumpvars(0, adpcm_tb);
end

endmodule
