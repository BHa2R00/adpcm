module adpcm(
	output ack, 
	output reg [2:0] cst, nst, 
	input req, 
	output reg signed [15:0] tx_pcm, 
	input [3:0] rx_adpcm, 
	output reg [3:0] tx_adpcm, 
	input signed [15:0] rx_pcm, 
	output reg signed [7:0] tx_idx, 
	input signed [7:0] rx_idx, 
	input sel_rx, 
	input enable, 
	input rstn, clk 
);

`define PCM_MAX 32767
`define PCM_MIN -32768

reg signed [15:0] sigma, step;
reg signed [15:0] diff, predict;
reg signed [7:0] idx;
reg [3:0] delta;
reg sign;
reg sel_tx;

wire signed [16:0] nst_predict = 
	sign ? ({predict[15],predict} - {sigma[15],sigma}) : 
	({predict[15],predict} + {sigma[15],sigma});
wire signed [15:0] clamp_nst_predict = 
	(`PCM_MAX < nst_predict) ? `PCM_MAX : 
	(nst_predict < `PCM_MIN) ? `PCM_MIN : 
	nst_predict[15:0];
`include "../rtl/adpcm_nst_idx.v"
wire [6:0] clamp_idx = ((idx < 0) ? 0 : (88 < idx) ? 88 : idx[6:0]);
`include "../rtl/adpcm_nst_step.v"
wire signed [15:0] nst_sigma = sigma + step;
wire lt_diff_step = diff < step;

`ifndef GRAY
	`define GRAY(X) (X^(X>>1))
`endif
localparam [2:0]
	st_step		= `GRAY(7),
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
end
wire req_x = req_d ^ req;
always@(negedge rstn or posedge clk) begin
	if(!rstn) cst <= st_idle;
	else if(enable) cst <= nst;
end
always@(*) begin
	case(cst)
		st_idle: nst = req_x ? st_load : cst;
		st_load: nst = st_b3;
		st_b3: nst = st_b2;
		st_b2: nst = st_b1;
		st_b1: nst = st_b0;
		st_b0: nst = st_update;
		st_update: nst = st_step;
		st_step: nst = st_idle;
		default: nst = st_idle;
	endcase
end
assign ack = cst == st_idle;

always@(negedge rstn or posedge clk) begin
	if(!rstn) sign <= 1'b0;
	else if(enable) begin
		case(nst)
			st_load: sign <= sel_tx ? (diff < 0) : delta[3];
			default: sign <= sign;
		endcase
	end
	else sign <= 1'b0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		idx <= 0;
		tx_idx <= 0;
	end
	else if(enable) begin
		case(nst)
			st_idle: idx <= rx_idx;
			st_load: if(!sel_tx) idx <= nst_idx;
			st_update: if(sel_tx) idx <= nst_idx;
			st_step: tx_idx <= idx;
			default: begin
				idx <= idx;
				tx_idx <= tx_idx;
			end
		endcase
	end
	else begin
		idx <= 0;
		tx_idx <= 0;
	end
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) step <= 0;
	else if(enable) begin
		case(nst)
			st_b2, st_b1: step <= step >> 1;
			st_step: step <= nst_step;
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
			st_idle: if(!sel_tx) delta <= rx_adpcm;
			st_load: if(sel_tx) delta <= 0;
			st_b3: if(!sel_tx) delta <= delta & 4'b0111; else delta <= {sign, 3'b000};
			st_b2: if(sel_tx && !lt_diff_step) delta[2] <= 1'b1;
			st_b1: if(sel_tx && !lt_diff_step) delta[1] <= 1'b1;
			st_b0: if(sel_tx && !lt_diff_step) delta[0] <= 1'b1;
			default: delta <= delta;
		endcase
	end
	else delta <= 0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) diff <= 0;
	else if(enable) begin
		if(sel_tx) begin
			case(nst)
				st_idle: diff <= rx_pcm - predict;
				st_b3: diff <= sign ? (-diff) : diff;
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
		if(sel_tx) begin
			case(nst)
				st_load: sigma <= step >> 3;
				st_b2, st_b1, st_b0: if(!lt_diff_step) sigma <= nst_sigma;
				default: sigma <= sigma;
			endcase
		end
		else begin
			case(nst)
				st_load: sigma <= step >> 3;
				st_b2: if(delta[2]) sigma <= nst_sigma;
				st_b1: if(delta[1]) sigma <= nst_sigma;
				st_b0: if(delta[0]) sigma <= nst_sigma;
				default: sigma <= sigma;
			endcase
		end
	end
	else sigma <= 0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) sel_tx <= 0;
	else if(enable) begin
		case(nst)
			st_idle: sel_tx <= ~sel_rx;
			default: sel_tx <= sel_tx;
		endcase
	end
	else sel_tx <= 0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		tx_pcm <= 0;
		tx_adpcm <= 0;
	end
	else if(enable) begin
		case(nst)
			st_step: begin
				if(sel_tx) tx_adpcm <= delta;
				else tx_pcm <= predict;
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

endmodule


module adpcm_mono_byte(
	output full, 
	output reg [1:0] cst, nst, 
	input push, pop, 
	output reg [3:0] tx_adpcm, 
	input [7:0] rx_byte, 
	output reg [7:0] tx_byte, 
	input [3:0] rx_adpcm, 
	input sel_rx, 
	input enable, 
	input rstn, clk 
);

reg sel_tx;
reg [7:0] b;

`ifndef GRAY
	`define GRAY(X) (X^(X>>1))
`endif
localparam [1:0]
	st_3	= `GRAY(3),
	st_2	= `GRAY(2),
	st_1	= `GRAY(1),
	st_idle	= `GRAY(0);
reg push_d, pop_d;
always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		push_d <= 0;
		pop_d <= 0;
	end
	else if(enable) begin
		push_d <= push;
		pop_d <= pop;
	end
end
wire push_x = push_d ^ push;
wire pop_x = pop_d ^ pop;
always@(negedge rstn or posedge clk) begin
	if(!rstn) cst <= st_idle;
	else if(enable) cst <= nst;
end
always@(*) begin
	case(cst)
		st_idle: nst = push_x ? st_1 : cst;
		st_1: nst = sel_tx ? (push_x ? st_2 : cst) : st_2;
		st_2: nst = sel_tx ? st_3 : (pop_x ? st_3 : cst);
		st_3: nst = pop_x ? st_idle : cst;
		default: nst = st_idle;
	endcase
end
assign full = sel_tx ? (cst == st_3) : ((cst == st_1)|(cst == st_2));

always@(negedge rstn or posedge clk) begin
	if(!rstn) sel_tx <= 0;
	else if(enable) begin
		case(nst)
			st_idle: sel_tx <= ~sel_rx;
			default: sel_tx <= sel_tx;
		endcase
	end
	else sel_tx <= 0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) b <= 0;
	else if(enable) begin
		case(nst)
			st_1: begin
				if(sel_tx) b[3:0] <= rx_adpcm;
				else b <= rx_byte;
			end
			st_2: if(sel_tx) b[7:4] <= rx_adpcm;
			default: b <= b;
		endcase
	end
	else b <= 0;
end

always@(negedge rstn or posedge clk) begin
	if(!rstn) begin
		tx_byte <= 0;
		tx_adpcm <= 0;
	end
	else if(enable) begin
		case(nst)
			st_2: if(!sel_tx) tx_adpcm <= b[3:0];
			st_3: begin
				if(sel_tx) tx_byte <= b;
				else tx_adpcm <= b[7:4];
			end
			default: begin
				tx_byte <= tx_byte;
				tx_adpcm <= tx_adpcm;
			end
		endcase
	end
	else begin
		tx_byte <= 0;
		tx_adpcm <= 0;
	end
end

endmodule
