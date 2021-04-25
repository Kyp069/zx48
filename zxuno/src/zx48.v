//-------------------------------------------------------------------------------------------------
module zx48
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire       led,

	output wire[ 1:0] stdn,
	output wire[ 1:0] sync,
	output wire[ 8:0] rgb,

	input  wire       ear,
	output wire       dsgR,
	output wire       dsgL,

	inout  wire       keybCk,
	inout  wire       keybDQ,

	input  wire[ 5:0] joys,

	output wire       usdCs,
	output wire       usdCk,
	input  wire       usdMiso,
	output wire       usdMosi,

	output reg        fshCs,
	output wire       fshCk,
	input  wire       fshMiso,
	output wire       fshMosi,

	output wire       sramWe,
	inout  wire[ 7:0] sramDQ,
	output wire[20:0] sramA
);
//-------------------------------------------------------------------------------------------------

clock Clock
(
	.i      (clock50), // 50.000 MHz input
	.o      (clock  )  // 56.000 MHz bufferd output
);

reg[7:0] pw;
wire power = pw[7];
always @(posedge clock) if(!power) pw <= pw+1'd1;

reg[3:0] cc;
always @(negedge clock) if(power) cc <= cc+1'd1;

wire ne14M = power & ~cc[0] & ~cc[1];
wire ne7M0 = power & ~cc[0] & ~cc[1] & ~cc[2];
wire pe3M5 = power & ~cc[0] & ~cc[1] & ~cc[2] &  cc[3];

//-------------------------------------------------------------------------------------------------

wire[7:0] code;

ps2 PS2
(
	.clock  (clock  ),
	.ce     (ne7M0  ),
	.ps2Ck  (keybCk ),
	.ps2DQ  (keybDQ ),
	.kstb   (kstb   ),
	.make   (make   ),
	.code   (code   )
);

reg F5 = 1'b1;
reg F11 = 1'b1;
reg F12 = 1'b1;
reg bs = 1'b1;
reg del = 1'b1;
reg alt = 1'b1;
reg ctrl = 1'b1;
reg scrlck = 1'b1;

always @(posedge clock) if(ne7M0)
if(kstb)
	case(code)
		8'h03: F5  <= make;
		8'h78: F11 <= make;
		8'h07: F12 <= make;
		8'h66: bs  <= make;
		8'h71: del <= make;
		8'h11: alt <= make;
		8'h14: ctrl <= make;
		8'h7E: scrlck <= make;
	endcase

//-------------------------------------------------------------------------------------------------

wire reset = power & F12 & (ctrl|alt|del);
wire nmi = F5;

wire[11:0] laudio;
wire[11:0] raudio;

wire[7:0] joy1 = { 2'd0, ~joys };
wire[7:0] joy2 = 8'd0;

wire[ 7:0] ramD;
wire[ 7:0] ramQ = sramDQ;
wire[17:0] ramA;

main Main
(
	.clock  (clock  ),
	.power  (power  ),
	.reset  (reset  ),
	.rfsh   (       ),
	.nmi    (nmi    ),
	.map    (       ),
	.blank  (blank  ),
	.hsync  (hsync  ),
	.vsync  (vsync  ),
	.r      (r      ),
	.g      (g      ),
	.b      (b      ),
	.i      (i      ),
	.ear    (~ear   ),
	.laudio (laudio ),
	.raudio (raudio ),
	.kstb   (kstb   ),
	.make   (make   ),
	.code   (code   ),
	.joy1   (joy1   ),
	.joy2   (joy2   ),
	.cs     (usdCs  ),
	.ck     (usdCk  ),
	.miso   (usdMiso),
	.mosi   (usdMosi),
	.ramRd  (       ),
	.ramWr  (ramWr  ),
	.ramD   (ramD   ),
	.ramQ   (ramQ   ),
	.ramA   (ramA   )
);

//-------------------------------------------------------------------------------------------------

assign sramWe = ramWr;
assign sramDQ = ramWr ? 8'bZ : ramD;
assign sramA = { 3'd0, ramA };

//-------------------------------------------------------------------------------------------------

dac #(.MSBI(11)) LDac
(
	.clock  (clock  ),
	.reset  (reset  ),
	.d      (laudio ),
	.q      (dsgL   )
);

dac #(.MSBI(11)) RDac
(
	.clock  (clock  ),
	.reset  (reset  ),
	.d      (raudio ),
	.q      (dsgR   )
);

//-------------------------------------------------------------------------------------------------

reg fshTx;
reg fshRx;

reg[7:0] fshD;
reg[7:0] fc;

always @(posedge clock) if(pe3M5)
if(!fc[7])
begin
	fc <= fc+1'd1;
	case(fc)
		 0: fshCs <= 1'b1;
		14: fshCs <= 1'b0;

//		 0: begin fshTx <= 1'b1; fshD <= 8'h13; end
//		 1: begin fshTx <= 1'b0; end

		16: begin fshTx <= 1'b1; fshD <= 8'h03; end
		17: begin fshTx <= 1'b0; end

		32: begin fshTx <= 1'b1; fshD <= 8'h00; end
		33: begin fshTx <= 1'b0; end

		48: begin fshTx <= 1'b1; fshD <= 8'h70; end
		49: begin fshTx <= 1'b0; end

		64: begin fshTx <= 1'b1; fshD <= 8'h4D; end
		65: begin fshTx <= 1'b0; end

		80: fshRx <= 1'b1;
		81: fshRx <= 1'b0;

		96: fshRx <= 1'b1;
		97: fshRx <= 1'b0;

		98: biosVga <= fshQ == 2'b10;
		99: fshCs <= 1'b1;
	endcase
end

wire[7:0] fshQ;

spi #(.QW(8)) Flash
(
	.clock  (clock  ),
	.ce     (ne7M0  ),
	.tx     (fshTx  ),
	.rx     (fshRx  ),
	.d      (fshD   ),
	.q      (fshQ   ),
	.ck     (fshCk  ),
	.miso   (fshMiso),
	.mosi   (fshMosi)
);

//-------------------------------------------------------------------------------------------------

reg biosVga;

reg vga;
reg scrlckd = 1'b1;

always @(posedge clock) if(ne7M0)
begin
	scrlckd <= scrlck;
	if(!fshCs) vga <= biosVga; else if(!scrlck && scrlckd) vga <= ~vga;
end

//-------------------------------------------------------------------------------------------------

wire[8:0] irgb = blank ? 9'd0 : { r,i&r,r, g,i&g,g, b,i&b,b };
wire[8:0] orgb;

scandoubler #(.RGBW(9)) Scandoubler
(
	.clock  (clock  ),
	.ice    (ne7M0  ),
	.ihs    (hsync  ),
	.ivs    (vsync  ),
	.irgb   (irgb   ),
	.oce    (ne14M  ),
	.ohs    (ohsync ),
	.ovs    (ovsync ),
	.orgb   (orgb   )
);

//-------------------------------------------------------------------------------------------------

reg cmb;
always @(posedge clock) if(ne14M) cmb <= ~cmb;

BUFG BufgMb(.I(cmb), .O(clockmb));

wire boot = F11 & (ctrl|alt|bs);

multiboot #(.ADDR(24'h058000)) Multiboot
(
	.clock  (clockmb),
	.boot   (boot   )
);

//-------------------------------------------------------------------------------------------------

assign led = ~usdCs;

assign stdn = 2'b01;
assign sync = vga ? { ovsync, ohsync } : { 1'b1, ~(hsync^vsync) };
assign rgb = vga ? orgb : irgb;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
