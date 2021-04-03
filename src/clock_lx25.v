//-------------------------------------------------------------------------------------------------
module clock
//-------------------------------------------------------------------------------------------------
(
	input  wire i50,   // 50.000 MHz
	output wire o56,   // 56.000 MHz
	output wire o16,   // 16.666 MHz
   output wire o50,   // 50.000 MHz	
	output wire locked
);
//-------------------------------------------------------------------------------------------------

IBUFG IBufg(.I(i50), .O(ci));

DCM_SP #
(
	.CLKIN_PERIOD          (20.000),
	.CLKFX_MULTIPLY        (28    ),
	.CLKFX_DIVIDE          (25    ),
	.CLKDV_DIVIDE          ( 2.000)
)
Dcm
(
	.RST                   (1'b0),
	.DSSEN                 (1'b0),
	.PSCLK                 (1'b0),
	.PSEN                  (1'b0),
	.PSINCDEC              (1'b0),
	.CLKIN                 (ci),
	.CLKFB                 (),
	.CLK0                  (),
	.CLK90                 (),
	.CLK180                (),
	.CLK270                (),
	.CLK2X                 (),
	.CLK2X180              (),
	.CLKFX                 (co),
	.CLKFX180              (),
	.CLKDV                 (),
	.PSDONE                (),
	.STATUS                (),
	.LOCKED                (locked)
);

BUFGCE_1 Bufgce(.I(co), .O(o56), .CE(locked));

// clock 16,66Mhz
reg ce_16m;
reg [1:0] div3 = 2'b0;

always @(posedge ci) begin
   if (div3 == 2'b10) begin
      div3 <= 2'b0;
      ce_16m <= 1'b1;
   end
   else begin
      div3 <= div3 +1'b1;
      ce_16m <= 1'b0;
   end
end

BUFG bufgO16(.I(ce_16m), .O(o16));
BUFG bufgO50(.I(ci), .O(o50));

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
