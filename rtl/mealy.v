
`define enc_gray(x) (x^(x>>1))

`define two_phase_in(rstn, clk, req, req_d, req_x) \
reg req_d; \
always@(negedge rstn or posedge clk) begin \
	if(!rstn) req_d <= 1'b0; \
	else req_d <= req; \
end \
wire req_x = req_d ^ req; 

`define four_phase_in(rstn, clk, req, req_d, req_x, match) \
reg req_d; \
always@(negedge rstn or posedge clk) begin \
	if(!rstn) req_d <= 1'b0; \
	else req_d <= req; \
end \
wire req_x = {req_d, req} == match; 

`define four_phase_in_both(rstn, clk, req, req_d, req_01, req_10) \
reg req_d; \
always@(negedge rstn or posedge clk) begin \
	if(!rstn) req_d <= 1'b0; \
	else req_d <= req; \
end \
wire req_01 = {req_d, req} == 2'b01; \
wire req_10 = {req_d, req} == 2'b10; 

`define always_cst(rstn, clk, enable, cst, nst, st_rstn) \
always@(negedge rstn or posedge clk) begin \
	if(!rstn) cst <= st_rstn; \
	else if(enable) cst <= nst; \
end
