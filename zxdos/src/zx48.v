//-------------------------------------------------------------------------------------------------
module zx48
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire[ 1:0] led,

	output wire[ 1:0] sync,
	output wire[17:0] rgb,

	input  wire       ear,

	output wire       dsgR,
	output wire       dsgL,

	inout  wire       keybCk,
	inout  wire       keybDQ,

	output wire       usdCs,
	output wire       usdCk,
	input  wire       usdMiso,
	output wire       usdMosi,

	output reg        fshCs,
	output wire       fshCk,
	input  wire       fshMiso,
	output wire       fshMosi,

	output wire       sdramCk,
	output wire       sdramCe,
	output wire       sdramCs,
	output wire       sdramWe,
	output wire       sdramRas,
	output wire       sdramCas,
	output wire[ 1:0] sdramDQM,
	inout  wire[15:0] sdramDQ,
	output wire[ 1:0] sdramBA,
	output wire[12:0] sdramA
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

wire reset = power & ready & F12 & (ctrl|alt|del);
wire nmi = F5;

wire[11:0] laudio;
wire[11:0] raudio;

wire[7:0] joy1 = 8'd0;
wire[7:0] joy2 = 8'd0;

wire[ 7:0] ramD;
wire[ 7:0] ramQ = sdrQ[7:0];
wire[17:0] ramA;

main Main
(
	.clock  (clock  ),
	.power  (power  ),
	.reset  (reset  ),
	.rfsh   (rfsh   ),
	.nmi    (nmi    ),
	.map    (map    ),
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
	.ramRd  (ramRd  ),
	.ramWr  (ramWr  ),
	.ramD   (ramD   ),
	.ramQ   (ramQ   ),
	.ramA   (ramA   )
);

//-------------------------------------------------------------------------------------------------

wire sdrRf = rfsh;
wire sdrRd = ramRd;
wire sdrWr = ramWr;

wire[15:0] sdrD = {2{ramD}};
wire[15:0] sdrQ;
wire[23:0] sdrA = { 6'd0, ramA };

sdram SDram
(
	.clock   (clock   ),
	.reset   (power   ),
	.ready   (ready   ),
	.refresh (sdrRf   ),
	.write   (sdrWr   ),
	.read    (sdrRd   ),
	.portD   (sdrD    ),
	.portQ   (sdrQ    ),
	.portA   (sdrA    ),
	.sdramCs (sdramCs ),
	.sdramRas(sdramRas),
	.sdramCas(sdramCas),
	.sdramWe (sdramWe ),
	.sdramDQM(sdramDQM),
	.sdramDQ (sdramDQ ),
	.sdramBA (sdramBA ),
	.sdramA  (sdramA  )
);

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

assign sdramCe = 1'b1;

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

reg[17:0] palette[0:15];
initial $readmemh("palette.hex", palette, 0);

wire[17:0] irgb = blank ? 1'd0 : palette[{ i, r, g, b }];
wire[17:0] orgb;

scandoubler #(.RGBW(18)) Scandoubler
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

multiboot #(.ADDR(24'h098000)) Multiboot
(
	.clock  (clockmb),
	.boot   (boot   )
);

//-------------------------------------------------------------------------------------------------

assign led = { usdCs, ~map };

assign sync = vga ? { ovsync, ohsync } : { 1'b1, ~(hsync^vsync) };
assign rgb = vga ? orgb : irgb;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
