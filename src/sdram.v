//-------------------------------------------------------------------------------------------------
module sdram
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       power,
	output reg        ready,

	input  wire       rfsh,
	input  wire       rd,
	input  wire       wr,
	input  wire[15:0] d,
	output reg [15:0] q,
	input  wire[23:0] a,

	output wire       sdramCk,
	output wire       sdramCe,
	output reg        sdramCs,
	output reg        sdramWe,
	output reg        sdramRas,
	output reg        sdramCas,
	output reg [ 1:0] sdramDQM,
	inout  wire[15:0] sdramDQ,
	output reg [ 1:0] sdramBA,
	output reg [12:0] sdramA
);
//-------------------------------------------------------------------------------------------------
`include "sdram_cmd.v"
//-------------------------------------------------------------------------------------------------

reg rfsh1, rfsh2;
reg rd1, rd2;
reg wr1, wr2;

always @(negedge clock)
begin
	rfsh1 <= rfsh;
	rfsh2 <= !rfsh && rfsh1;

	rd1 <= rd;
	rd2 <= !rd && rd1;

	wr1 <= wr;
	wr2 <= !wr && wr1;
end

//-------------------------------------------------------------------------------------------------

localparam sINIT = 0;
localparam sIDLE = 1;
localparam sREAD = 2;
localparam sWRITE = 3;
localparam sREFRESH = 4;

reg counting;
reg[4:0] count;
reg[2:0] state;

always @(posedge clock)
if(!power) state <= sINIT;
else
begin
	NOP;												// default state is NOP
	if(counting) count <= count+5'd1; else count <= 5'd0;

	case(state)
	sINIT:
	begin
		counting <= 1'b1;

		case(count)
		 0: ready <= 1'b0;
		 8: PRECHARGE(1'b1);							//  8    PRECHARGE: all, tRP's minimum value is 20ns
		12: REFRESH;									// 11    REFRESH, tRFC's minimum value is 66ns
		20: REFRESH;									// 20    REFRESH, tRFC's minimum value is 66ns
		28: LMR(13'b000_1_00_010_0_000);				// 29    LDM: CL = 2, BT = seq, BL = 1, wait 2T
		31: begin ready <= 1'b1; state <= sIDLE; end
		endcase
	end
	sIDLE:
	begin
		counting <= 1'b0;

		if(rfsh2) begin REFRESH; state <= sREFRESH; end else
		if(wr2)   begin ACTIVE(a[23:22], a[21:9]); state <= sWRITE; end else
		if(rd2)   begin ACTIVE(a[23:22], a[21:9]); state <= sREAD; end
	end
	sREAD:
	begin
		counting <= 1'b1;

		case(count)
		0: READ(2'b00, 2'b00, a[8:0], 1'b1);
		2: begin q <= sdramDQ; state <= sIDLE; end
		endcase
	end
	sWRITE:
	begin
		counting <= 1'b1;

		case(count)
		0: WRITE(2'b00, 2'b00, a[8:0], 1'b1);
		2: state <= sIDLE;
		endcase
	end
	sREFRESH:
	begin
		counting <= 1'b1;

		case(count)
		2: state <= sIDLE;
		endcase
	end
	endcase
end

//-------------------------------------------------------------------------------------------------

ODDR2 oddr2
(
	.Q       (sdramCk), // 1-bit DDR output data
	.C0      ( clock ), // 1-bit clock input
	.C1      (~clock ), // 1-bit clock input
	.CE      (1'b1   ), // 1-bit clock enable input
	.D0      (1'b1   ), // 1-bit data input (associated with C0)
	.D1      (1'b0   ), // 1-bit data input (associated with C1)
	.R       (1'b0   ), // 1-bit reset input
	.S       (1'b0   )  // 1-bit set input
);

//-------------------------------------------------------------------------------------------------

assign sdramCe = 1'b1;
assign sdramDQ = sdramWe ? 16'bZ : d;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
