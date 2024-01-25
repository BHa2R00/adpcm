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

localparam PCM_MAX = 32767;
localparam PCM_MIN = -32768;

reg signed [15:0] sigma, step;
reg signed [15:0] diff, predict;
reg signed [7:0] idx;
reg [3:0] delta;
reg sign;
reg sel_rx_r;

wire signed [15:0] nst_predict = (sign ? (predict - sigma) : (predict + sigma));
wire signed [15:0] clamp_nst_predict = ((nst_predict > PCM_MAX) ? PCM_MAX : (nst_predict < PCM_MIN) ? PCM_MIN : nst_predict);
wire signed [7:0] index_sigma;
index_table u1(.index_sigma(index_sigma), .delta(delta));
wire signed [7:0] clamp_idx = ((idx < 0) ? 0 : (idx > 88) ? 88 : idx);
wire signed [15:0] nst_step;
step_table u2(.nst_step(nst_step), .idx(clamp_idx));

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
	if(!rstn) begin
		sigma <= 0;
		diff <= 0;
		step <= 0;
		predict <= 0;
	end
	else if(enable) begin
		case(nst)
			st_idle: if(!sel_rx_r) diff <= rx_pcm - predict;
			st_load: sigma <= (step >> 3);
			st_b3: begin
				if(!sel_rx_r) diff <= sign ? ~diff + 1 : diff;
			end
			st_b2: begin
				if(sel_rx_r) begin
					if(delta[2]) sigma <= sigma + step;
				end
				else begin
					if(diff >= step) begin
						sigma <= sigma + step;
						diff <= diff - step;
					end
					step <= step >> 1;
				end
			end
			st_b1: begin
				if(sel_rx_r) begin
					if(delta[1]) sigma <= sigma + (step >> 1);
				end
				else begin
					if(diff >= step) begin
						sigma <= sigma + step;
						diff <= diff - step;
					end
					step <= step >> 1;
				end
			end
			st_b0: begin
				if(sel_rx_r) begin
					if(delta[0]) sigma <= sigma + (step >> 2);
				end
				else begin
					if(diff >= step) begin
						sigma <= sigma + step;
					end
				end
			end
			st_update: begin
				predict <= clamp_nst_predict;
				step <= nst_step;
			end
			default: begin
				sigma <= sigma;
				diff <= diff;
				step <= step;
				predict <= predict;
			end
		endcase
	end
	else begin
		sigma <= 0;
		diff <= 0;
		step <= 0;
		predict <= 0;
	end
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
	if(!rstn) delta <= 0;
	else if(enable) begin
		case(nst)
			st_idle: if(sel_rx_r) delta <= rx_adpcm;
			st_load: if(!sel_rx_r) delta <= 0;
			st_b3: if(sel_rx_r) delta <= delta & 4'b0111;
			st_b2: begin
				if(!sel_rx_r) begin
					if(diff >= step) delta[2] <= 1'b1;
				end
			end
			st_b1: begin
				if(!sel_rx_r) begin
					if(diff >= step) delta[1] <= 1'b1;
				end
			end
			st_b0: begin
				if(!sel_rx_r) begin
					if(diff >= step) delta[0] <= 1'b1;
				end
			end
			st_update: if(!sel_rx_r) delta[3] <= sign;
			default: delta <= delta;
		endcase
	end
	else delta <= 0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) sign <= 0;
	else if(enable) begin
		case(nst)
			st_load: sign <= sel_rx_r ? delta[3] : (diff < 0);
			default: sign <= sign;
		endcase
	end
	else sign <= 0;
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