`include "../rtl/adpcm_tables.v"

`define ADPCM_ALL
module adpcm(
	output ack, 
	output reg [2:0] cst, nst, 
	input req, 
	output reg signed [15:0] tx_pcm, 
	input [3:0] rx_adpcm, 
	output reg [3:0] tx_adpcm, 
	input signed [15:0] rx_pcm, 
	input sel_rx, 
	input enable, 
	input rstn, clk 
);

`define PCM_MAX 32767
`define PCM_MIN -32768

reg signed [15:0] sigma, step;
reg signed [15:0] diff, predict;
reg [6:0] idx;
reg [3:0] delta;
reg sign;
reg sel_rx_r;

wire signed [15:0] nst_predict = (sign ? (predict - sigma) : (predict + sigma));
wire signed [15:0] clamp_nst_predict = (`PCM_MAX < nst_predict) ? `PCM_MAX : (nst_predict < `PCM_MIN) ? `PCM_MIN : nst_predict;
wire [6:0] index_sigma;
index_table u1(.index_sigma(index_sigma), .delta(delta));
wire [6:0] clamp_idx = (idx[6] ? 0 : (idx > 88) ? 88 : idx);
wire [14:0] nst_step;
step_table u2(.nst_step(nst_step), .idx(clamp_idx));
wire [15:0] nst_sigma = sigma + step;
wire lt_diff_step = diff < step;

`ifndef GRAY
	`define GRAY(X) (X^(X>>1))
`endif
localparam [2:0]
	st_update	= `GRAY(6),
	st_b0		= `GRAY(5),
	st_b1		= `GRAY(4),
	st_b2		= `GRAY(3),
	st_b3		= `GRAY(2),
	st_load		= `GRAY(1),
	st_idle		= `GRAY(0);
reg req_d;
always@(negedge rstn or posedge clk) begin
	if(!rstn) req_d <= 0;
	else if(enable) req_d <= req;
	else req_d <= 0;
end
wire req_x = req_d ^ req;
always@(negedge rstn or posedge clk) begin
	if(!rstn) cst <= st_idle;
	else if(enable) cst <= nst;
	else cst <= st_idle;
end
always@(*) begin
	case(cst)
		st_idle: nst = req_x ? st_load : cst;
		st_load: nst = st_b3;
		st_b3: nst = st_b2;
		st_b2: nst = st_b1;
		st_b1: nst = st_b0;
		st_b0: nst = st_update;
		st_update: nst = st_idle;
		default: nst = st_idle;
	endcase
end
assign ack = cst == st_idle;

always@(negedge rstn or posedge clk) begin
	if(!rstn) sign <= 1'b0;
	else if(enable) begin
		case(nst)
			st_load: sign <= sel_rx_r ? delta[3] : (diff < 0);
			default: sign <= sign;
		endcase
	end
	else sign <= 1'b0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) idx <= 0;
	else if(enable) begin
		case(nst)
			st_load: if(sel_rx_r) idx <= idx + index_sigma;
			st_update: if(!sel_rx_r) idx <= idx + index_sigma;
			default: idx <= idx;
		endcase
	end
	else idx <= 0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) step <= 0;
	else if(enable) begin
		case(nst)
			st_b2, st_b1: step <= step >> 1;
			st_update: step <= {1'b0, nst_step};
			default: step <= step;
		endcase
	end
	else step <= 0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) predict <= 0;
	else if(enable) begin
		case(nst)
			st_update: predict <= clamp_nst_predict;
			default: predict <= predict;
		endcase
	end
	else predict <= 0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) delta <= 0;
	else if(enable) begin
		case(nst)
			st_idle: if(sel_rx_r) delta <= rx_adpcm;
			st_load: if(!sel_rx_r) delta <= 0;
			st_b3: if(sel_rx_r) delta <= delta & 4'b0111;
			st_b2: if(!sel_rx_r && !lt_diff_step) delta[2] <= 1'b1;
			st_b1: if(!sel_rx_r && !lt_diff_step) delta[1] <= 1'b1;
			st_b0: if(!sel_rx_r && !lt_diff_step) delta[0] <= 1'b1;
			st_update: if(!sel_rx_r) delta[3] <= sign;
			default: delta <= delta;
		endcase
	end
	else delta <= 0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) diff <= 0;
	else if(enable) begin
		if(!sel_rx_r) begin
			case(nst)
				st_idle: diff <= rx_pcm - predict;
				st_b3: diff <= sign ? (0 - diff) : diff;
				st_b2, st_b1: if(!lt_diff_step) diff <= diff - step;
				default: diff <= diff;
			endcase
		end
	end
	else diff <= 0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) sigma <= 0;
	else if(enable) begin
		if(sel_rx_r) begin
			case(nst)
				st_load: sigma <= step >> 3;
				st_b2: if(delta[2]) sigma <= nst_sigma;
				st_b1: if(delta[1]) sigma <= nst_sigma;
				st_b0: if(delta[0]) sigma <= nst_sigma;
				default: sigma <= sigma;
			endcase
		end
		else begin
			case(nst)
				st_load: sigma <= step >> 3;
				st_b2, st_b1, st_b0: if(!lt_diff_step) sigma <= nst_sigma;
				default: sigma <= sigma;
			endcase
		end
	end
	else sigma <= 0;
end

`ifdef ADPCM_RX_ONLY
always@(*) sel_rx_r = 1'b1;
`endif
`ifdef ADPCM_TX_ONLY
always@(*) sel_rx_r = 1'b0;
`endif
`ifdef ADPCM_ALL
always@(negedge rstn or posedge clk) begin
	if(!rstn) sel_rx_r <= 0;
	else if(enable) begin
		case(nst)
			st_idle: sel_rx_r <= sel_rx;
			default: sel_rx_r <= sel_rx_r;
		endcase
	end
	else sel_rx_r <= 0;
end
`endif

`ifdef ADPCM_RX_ONLY
always@(*) tx_adpcm = 0;
always@(negedge rstn or posedge clk) begin
	if(!rstn) tx_pcm <= 0;
	else if(enable) begin
		case(nst)
			st_idle: begin
				if(sel_rx_r) tx_pcm <= predict;
			end
			default: tx_pcm <= tx_pcm;
		endcase
	end
	else tx_pcm <= 0;
end
`endif
`ifdef ADPCM_TX_ONLY
always@(*) tx_pcm = 0;
always@(negedge rstn or posedge clk) begin
	if(!rstn) tx_adpcm <= 0;
	else if(enable) begin
		case(nst)
			st_idle: begin
				if(!sel_rx_r) tx_adpcm <= delta;
			end
			default: tx_adpcm <= tx_adpcm;
		endcase
	end
	else tx_adpcm <= 0;
end
`endif
`ifdef ADPCM_ALL
always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		tx_pcm <= 0;
		tx_adpcm <= 0;
	end
	else if(enable) begin
		case(nst)
			st_idle: begin
				if(sel_rx_r) tx_pcm <= predict;
				else tx_adpcm <= delta;
			end
			default: begin
				tx_pcm <= tx_pcm;
				tx_adpcm <= tx_adpcm;
			end
		endcase
	end
	else begin
		tx_pcm <= 0;
		tx_adpcm <= 0;
	end
end
`endif

endmodule
