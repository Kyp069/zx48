//-------------------------------------------------------------------------------------------------
// ZX48: ZX Spectrum 48K implementation for ZX-Uno, ZX-Dos and ZX-Dos+ boards by Kyp
// https://github.com/Kyp069/zx48_xilinx
//-------------------------------------------------------------------------------------------------
// Z80 chip module implementation by Sorgelig
// https://github.com/sorgelig/ZX_Spectrum-128K_MIST
//-------------------------------------------------------------------------------------------------
// AY chip module implementation by Jotego
// https://github.com/jotego/jt49
//-------------------------------------------------------------------------------------------------
module zx48
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

`ifdef ZX1
	output wire       led,
`elsif ZX2
	output wire[ 1:0] led,
`elsif ZXD
	output wire[ 1:0] led,
`endif

`ifdef ZX1
	output wire[ 1:0] stdn,
	output wire[ 1:0] sync,
	output wire[ 8:0] rgb,
`elsif ZX2
	output wire[ 1:0] sync,
	output wire[17:0] rgb,
`elsif ZXD
	output wire[ 1:0] sync,
	output wire[17:0] rgb,
`endif

	input  wire       ear,
	output wire[ 1:0] audio,

	input  wire[ 1:0] keyb,
`ifdef ZX1
	input  wire[ 5:0] joys,
`elsif ZXD
   input  wire joyD,  //data
   output wire joyLd, //load
   output wire joyCk, //clock
   input  wire joySl, //select   
`endif

	output wire       usdCs,
	output wire       usdCk,
	input  wire       usdMiso,
	output wire       usdMosi,

`ifdef ZX1
	output wire       sramWe,
	inout  wire[ 7:0] sramDQ,
	output wire[20:0] sramA
`elsif ZX2
	output wire       sdramCk,
	output wire       sdramCe,
	output wire       sdramCs,
	output wire       sdramWe,
	output wire       sdramCas,
	output wire       sdramRas,
	output wire[ 1:0] sdramDQM,
	inout  wire[15:0] sdramDQ,
	output wire[ 1:0] sdramBA,
	output wire[12:0] sdramA
`elsif ZXD
	output wire       sramOe,
	output wire       sramWe,
	output wire       sramUb,
	output wire       sramLb,
	inout  wire[15:0] sramDQ,
	output wire[20:0] sramA
`endif
);
//-------------------------------------------------------------------------------------------------

`ifdef ZXD
clock Clock
(
	.i50    (clock50),
	.o56    (clock  ),
   .o16    (clock16),
	.locked (locked )
);
`else
clock Clock
(
	.i50    (clock50),
	.o56    (clock  ),
	.locked (locked )
);
`endif

reg[3:0] ce;
always @(negedge clock) if(locked) ce <= ce+1'd1;

wire ce7M0p = locked & ~ce[0] & ~ce[1] &  ce[2];
wire ce7M0n = locked & ~ce[0] & ~ce[1] & ~ce[2];

wire ce3M5p = locked & ~ce[0] & ~ce[1] & ~ce[2] &  ce[3];
wire ce3M5n = locked & ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3];

//-------------------------------------------------------------------------------------------------

reg mreqt23iorqtw3;
always @(posedge clock) if(cc3M5p) mreqt23iorqtw3 <= mreq & ioFE;

reg cpuck;
always @(posedge clock) if(ce7M0n) cpuck <= !(cpuck && contend);

wire contend = !(vduCn && cpuck && mreqt23iorqtw3 && ((!a[15] && a[14]) || !ioFE));

wire cc3M5p = ce3M5p & contend;
wire cc3M5n = ce3M5n & contend;

//-------------------------------------------------------------------------------------------------

reg[5:0] rs;
wire power = rs[5];
always @(posedge clock) if(cc3M5p) if(!power) rs <= rs+1'd1;

//-------------------------------------------------------------------------------------------------

wire reset = power & ready & keyF12;
wire nmi = keyF5;

reg mi = 1'b1;
always @(posedge clock) if(cc3M5p) mi <= vduI;

wire[ 7:0] d;
wire[ 7:0] q;
wire[15:0] a;

cpu Cpu
(
	.clock  (clock  ),
	.cep    (cc3M5p ),
	.cen    (cc3M5n ),
	.reset  (reset  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.m1     (m1     ),
	.nmi    (nmi    ),
	.mi     (mi     ),
	.d      (d      ),
	.q      (q      ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

reg mic;
reg speaker;
reg[2:0] border;

always @(posedge clock) if(ce7M0n) if(!ioFE && !wr) { speaker, mic, border } <= q[4:0];

//-------------------------------------------------------------------------------------------------

wire[ 7:0] memQ;
wire[ 7:0] vduQ;
wire[12:0] vduA;

memory Memory
(
	.clock  (clock  ),
	.ce     (cc3M5p ),
	.power  (power  ),
	.ready  (ready  ),
	.reset  (reset  ),
	.rfsh   (rfsh   ),
	.iorq   (iorq   ),
	.mreq   (mreq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.m1     (m1     ),
	.d      (q      ),
	.q      (memQ   ),
	.a      (a      ),
	.vduCe  (ce7M0n ),
	.vduQ   (vduQ   ),
	.vduA   (vduA   ),
`ifdef ZX1
	.sramWe  (sramWe  ),
	.sramDQ  (sramDQ  ),
	.sramA   (sramA   )
`elsif ZX2
	.sdramCk (sdramCk ),
	.sdramCe (sdramCe ),
	.sdramCs (sdramCs ),
	.sdramWe (sdramWe ),
	.sdramRas(sdramRas),
	.sdramCas(sdramCas),
	.sdramDQM(sdramDQM),
	.sdramDQ (sdramDQ ),
	.sdramBA (sdramBA ),
	.sdramA  (sdramA  )
`elsif ZXD
	.sramOe  (sramOe  ),
	.sramWe  (sramWe  ),
	.sramUb  (sramUb  ),
	.sramLb  (sramLb  ),
	.sramDQ  (sramDQ  ),
	.sramA   (sramA   )
`endif
);

//-------------------------------------------------------------------------------------------------

video Video
(
	.clock  (clock  ),
	.ce     (ce7M0n ),
	.border (border ),
	.blank  (blank  ),
	.hsync  (hsync  ),
	.vsync  (vsync  ),
	.r      (r      ),
	.g      (g      ),
	.b      (b      ),
	.i      (i      ),
	.cn     (vduCn  ),
	.rd     (vduRd  ),
	.bi     (vduI   ),
	.d      (vduQ   ),
	.a      (vduA   )
);

//-------------------------------------------------------------------------------------------------

wire[7:0] spdQ;

wire[7:0] psgA1;
wire[7:0] psgB1;
wire[7:0] psgC1;

wire[7:0] psgA2;
wire[7:0] psgB2;
wire[7:0] psgC2;

audio Audio
(
	.clock  (clock  ),
	.reset  (reset  ),
	.speaker(speaker),
	.mic    (mic    ),
	.ear    (ear    ),
	.spd    (spdQ   ),
	.a1     (psgA1  ),
	.b1     (psgB1  ),
	.c1     (psgC1  ),
	.a2     (psgA2  ),
	.b2     (psgB2  ),
	.c2     (psgC2  ),
	.audio  (audio  )
);

//-------------------------------------------------------------------------------------------------

wire[4:0] keyQ;
wire[7:0] keyA = a[15:8];

keyboard Keyboard
(
	.clock  (clock  ),
	.ce     (ce7M0p ),
	.ps2    (keyb   ),
	.f5     (keyF5  ),
	.f11    (keyF11 ),
	.f12    (keyF12 ),
	.q      (keyQ   ),
	.a      (keyA   )
);

//-------------------------------------------------------------------------------------------------

wire[7:0] usdQ;
wire[7:0] usdA = a[7:0];

usd uSD
(
	.clock  (clock  ),
	.cep    (ce7M0p ),
	.cen    (ce7M0n ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.d      (q      ),
	.q      (usdQ   ),
	.a      (usdA   ),
	.cs     (usdCs  ),
	.ck     (usdCk  ),
	.miso   (usdMiso),
	.mosi   (usdMosi)
);

//-------------------------------------------------------------------------------------------------

wire[7:4] spdA = a[7:4];

specdrum Specdrum
(
	.clock  (clock  ),
	.ce     (ce3M5p ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.d      (q      ),
	.q      (spdQ   ),
	.a      (spdA   )
);

//-------------------------------------------------------------------------------------------------

wire[ 7: 0] psgQ;
wire[15:14] psgAh = a[15:14];
wire[ 1: 1] psgAl = a[1];

turbosound Turbosound
(
	.clock  (clock  ),
	.ce     (ce3M5p ),
	.reset  (reset  ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.d      (q      ),
	.ah     (psgAh  ),
	.al     (psgAl  ),
	.q      (psgQ   ),
	.a1     (psgA1  ),
	.b1     (psgB1  ),
	.c1     (psgC1  ),
	.a2     (psgA2  ),
	.b2     (psgB2  ),
	.c2     (psgC2  )
);

//-------------------------------------------------------------------------------------------------

`ifdef ZX2
wire[5:0] joys = 6'b111111;
`elsif ZXD
//wire[5:0] joys = 6'b111111;
wire [11:0] joy1_aux; //lx25
wire [11:0] joy2_aux; //lx25
wire[ 5:0] joys;       //Core joystick

joydecoder joysticks (
   .clk(clock16),
   .joy_data(joyD),
   .joy_clk(joyCk),
   .joy_load_n(joyLd),
   .reset(~reset),
   .hsync_n_s(hsyncaux),
   .joy1_o(joy1_aux), // -- MXYZ SACB RLDU  Negative Logic
   .joy2_o(joy2_aux)  // -- MXYZ SACB RLDU  Negative Logic
);
assign joySl = hsyncaux;
assign joys = { joy1_aux[5:4], joy1_aux[0], joy1_aux[1], joy1_aux[2], joy1_aux[3] } ;
`endif

//-------------------------------------------------------------------------------------------------

wire io1F = !(!iorq && !a[5]);                     // kempston
wire ioEB = !(!iorq && a[7:0] == 8'hEB);           // usd
wire ioFE = !(!iorq && !a[0]);                     // ula
wire ioFFFD = !(!iorq && a[15] && a[14] && !a[1]); // psg

assign d
	= !mreq ? memQ
	: !io1F ? { 2'b00, ~joys }
	: !ioFE ? { 1'b1, ~ear|speaker, 1'b1, keyQ }
	: !ioEB ? usdQ
	: !ioFFFD ? psgQ
	: !iorq & vduRd ? vduQ
	: 8'hFF;

//-------------------------------------------------------------------------------------------------

`ifdef ZX1
assign led = ~usdCs;
`elsif ZX2
assign led = { 1'b1, usdCs };
`elsif ZXD
assign led = { 1'b1, usdCs };
`endif

//-------------------------------------------------------------------------------------------------
assign hsyncaux = ~(hsync^vsync);

`ifdef ZX1
assign stdn = 2'b01; // PAL
assign sync = { 1'b1, hsyncaux };
assign rgb = blank ? 9'd0 : { r,r&i,r, g,g&i,g, b,b&i,b };
`elsif ZX2
reg[17:0] palette[15:0];
initial $readmemh("palette.hex", palette, 0);
assign sync = { 1'b1, hsyncaux };
assign rgb = blank ? 18'd0 : palette[{ i, r, g, b }];
`elsif ZXD
reg[17:0] palette[15:0];
initial $readmemh("palette.hex", palette, 0);
assign sync = { 1'b1, hsyncaux };
assign rgb = blank ? 18'd0 : palette[{ i, r, g, b }];
`endif

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
