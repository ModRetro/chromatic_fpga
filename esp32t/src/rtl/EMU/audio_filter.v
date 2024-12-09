
module audio_filter
(
	input        reset,
	input        clk,

	input [15:0] core_l,
	input [15:0] core_r,

	output [15:0] filter_l,
	output [15:0] filter_r
);

localparam CLK_RATE = 16777000; // hclk

reg [31:0] flt_rate = 7056000;
reg [39:0] cx  = 4258969;
reg  [7:0] cx0 = 3;
reg  [7:0] cx1 = 3;
reg  [7:0] cx2 = 1;
reg [23:0] cy0 = 24'hA123C9;
reg [23:0] cy1 = 24'h5DBD9A;
reg [23:0] cy2 = 24'hE11EA9;

reg sample_ce;
reg [7:0] div = 0;
always @(posedge clk) begin
	div <= div + 1'd1;
	if(!div) begin
		div <= 2'd1;
	end

	sample_ce <= !div;
end

reg flt_ce;
reg [31:0] cnt = 0;
always @(posedge clk) begin
	flt_ce = 0;
	cnt = cnt + {flt_rate[30:0],1'b0};
	if(cnt >= CLK_RATE) begin
		cnt = cnt - CLK_RATE;
		flt_ce = 1;
	end
end

reg [15:0] cl,cr;
reg [15:0] cl1,cl2;
reg [15:0] cr1,cr2;
always @(posedge clk) begin
	cl1 <= core_l; cl2 <= cl1;
	if(cl2 == cl1) cl <= cl2;

	cr1 <= core_r; cr2 <= cr1;
	if(cr2 == cr1) cr <= cr2;
end

reg a_en1 = 0, a_en2 = 0;
reg  [1:0] dly1 = 0;
reg [14:0] dly2 = 0;
always @(posedge clk, posedge reset) begin
	if(reset) begin
		dly1 <= 0;
		dly2 <= 0;
		a_en1 <= 0;
		a_en2 <= 0;
	end
	else begin
		if(flt_ce) begin
			if(~&dly1) dly1 <= dly1 + 1'd1;
			else a_en1 <= 1;
		end

		if(sample_ce) begin
			if(!dly2[13]) dly2 <= dly2 + 1'd1;
			else a_en2 <= 1;
		end
	end
end

wire [15:0] acl, acr;
IIR_filter #(.use_params(0)) IIR_filter
(
	.clk(clk),
	.reset(reset),

	.ce(flt_ce & a_en1),
	.sample_ce(sample_ce),

	.cx(cx),
	.cx0(cx0),
	.cx1(cx1),
	.cx2(cx2),
	.cy0(cy0),
	.cy1(cy1),
	.cy2(cy2),

	.input_l(cl),
	.input_r(cr),
	.output_l(acl),
	.output_r(acr)
);

DC_blocker dcb_l
(
	.clk(clk),
	.ce(sample_ce),
	.sample_rate(0),
	.mute(~a_en2),
	.din(acl),
	.dout(filter_l)
);

DC_blocker dcb_r
(
	.clk(clk),
	.ce(sample_ce),
	.sample_rate(0),
	.mute(~a_en2),
	.din(acr),
	.dout(filter_r)
);

endmodule
