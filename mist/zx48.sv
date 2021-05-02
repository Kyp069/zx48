//-------------------------------------------------------------------------------------------------
module zx48
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock27,

	output wire       led,

	output wire[ 1:0] sync,
	output wire[17:0] rgb,

	input  wire       ear,

	output wire       dsgR,
	output wire       dsgL,

	output wire       sdramCk,
	output wire       sdramCe,
	output wire       sdramCs,
	output wire       sdramWe,
	output wire       sdramRas,
	output wire       sdramCas,
	output wire[ 1:0] sdramDQM,
	inout  wire[15:0] sdramDQ,
	output wire[ 1:0] sdramBA,
	output wire[12:0] sdramA,

	input  wire       cfgD0,
	input  wire       spiCk,
	input  wire       spiS2,
	input  wire       spiS3,
	input  wire       spiDi,
	output wire       spiDo
);
//-------------------------------------------------------------------------------------------------

clock Clock
(
	.inclk0 (clock27), // 27.000 MHz input
	.c0     (clock  ), // 56.000 MHz output
	.c1	    (clk_sdr), // 56.000 Mhz output -90º phase shift
	.locked (locked )  // 56.000 MHz output
);

reg[3:0] pw = 0;
wire power = pw[3];
always @(posedge clock) if(locked) if(!power) pw <= pw+1'd1;

reg[2:0] cc = 0;
always @(negedge clock) if(power) cc <= cc+1'd1;

wire ne14M = power & ~cc[0] & ~cc[1];
wire ne7M0 = power & ~cc[0] & ~cc[1] & ~cc[2];

//-------------------------------------------------------------------------------------------------

wire kstb = key_strobe;
wire make = ~key_pressed;
wire[7:0] code = key_code;

reg F5 = 1'b1;
reg F6 = 1'b1;

always @(posedge clock) if(kstb)
case(code)
	8'h03: F5 <= make;
	8'h0B: F6 <= make;
endcase

//-------------------------------------------------------------------------------------------------

wire reset = power & ready && F6 && ~status[0];
wire nmi = F5 && ~status[1];

wire[11:0] laudio;
wire[11:0] raudio;

wire[7:0] joy1 = { 2'b00, joystick_0[5:0] };
wire[7:0] joy2 = { 2'b00, joystick_1[5:0] };

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
	.cs     (spi_cs ),
	.ck     (spi_ck ),
	.miso   (spi_di ),
	.mosi   (spi_do ),
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

assign sdramCk = clk_sdr;
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

assign led = ~sd_busy;

assign sync = !scandoubler_disable ? { ovsync, ohsync } : { 1'b1, ~(hsync^vsync) };
assign rgb = !scandoubler_disable ? orgb : osdo;

//-------------------------------------------------------------------------------------------------

localparam CONF_STR = {
	"ZX48;;",
	"T0,Reset;",
	"T1,NMI;",
	"V,v1.0"
};

wire[31:0] status;
wire[ 7:0] key_code;

wire[31:0] sd_lba;
wire[ 1:0] sd_rd;
wire[ 1:0] sd_wr;
wire[ 8:0] sd_buff_addr;
wire[ 7:0] sd_buff_din;
wire[ 7:0] sd_buff_dout;
wire[ 1:0] img_mounted;
wire[31:0] img_size;

wire[31:0] joystick_0;
wire[31:0] joystick_1;

user_io #(.STRLEN(($size(CONF_STR)>>3))) userIo
( 
	.*,

	.conf_str    (CONF_STR  ),
	.clk_sys     (clock     ),
	.clk_sd      (clock     ),

	.SPI_CLK     (spiCk     ),
	.SPI_SS_IO   (cfgD0     ),
	.SPI_MISO    (spiDo     ),
	.SPI_MOSI    (spiDi     ),

	.joystick_0  (joystick_0),
	.joystick_1  (joystick_1),

	.status      (status    ),
	.scandoubler_disable(scandoubler_disable),

	.sd_conf(sd_conf),
	.sd_sdhc(sd_sdhc),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_ack_conf(sd_ack_conf),
	.sd_buff_addr(sd_buff_addr),
	.sd_din(sd_buff_din),
	.sd_din_strobe(),
	.sd_dout(sd_buff_dout),
	.sd_dout_strobe(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_size(img_size),

	.key_code    (key_code   ),
	.key_strobe  (key_strobe ),
	.key_pressed (key_pressed),
	.key_extended(           ),

	.conf_chr(),
	.conf_addr(),
	.ps2_kbd_clk(),
	.ps2_kbd_data(),
	.ps2_mouse_clk(),
	.ps2_mouse_data(),
	.mouse_x(),
	.mouse_y(),
	.mouse_z(),
	.mouse_idx(),
	.mouse_flags(),
	.mouse_strobe(),
	.serial_data(),
	.serial_strobe(),
	.joystick_2(),
	.joystick_3(),
	.joystick_4(),
	.joystick_analog_0(),
	.joystick_analog_1(),
	.buttons(),
	.switches(),
	.ypbpr(),
	.no_csync(),
	.core_mod(),
	.rtc()
);

wire[17:0] osdo;

osd OSD
(
	.clk_sys     (clock      ),
	.ce          (ne7M0      ),
	.SPI_SCK     (spiCk      ),
	.SPI_SS3     (spiS3      ),
	.SPI_DI      (spiDi      ),
	.rotate      (0          ),
	.R_in        (irgb[17:12]),
	.G_in        (irgb[11: 6]),
	.B_in        (irgb[ 5: 0]),
	.HSync       (hsync      ),
	.VSync       (vsync      ),
	.R_out       (osdo[17:12]),
	.G_out       (osdo[11: 6]),
	.B_out       (osdo[ 5: 0])
);

sd_card sdCard
(
	.clk_sys     (clock      ),
	.sd_lba      (sd_lba     ),
	.sd_rd       (sd_rd[0]   ),
	.sd_wr       (sd_wr[0]   ),
	.sd_ack      (sd_ack     ),
	.sd_ack_conf (sd_ack_conf),
	.sd_conf     (sd_conf    ),
	.sd_sdhc     (sd_sdhc    ),
	.img_mounted (img_mounted[0]),
	.img_size    (img_size    ),
	.sd_busy     (sd_busy     ),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_wr  (sd_buff_wr  ),
	.sd_buff_din (sd_buff_din ),
	.sd_buff_addr(sd_buff_addr),
	.allow_sdhc  (1           ),
	.sd_cs       (spi_cs      ),
	.sd_sck      (spi_ck      ),
	.sd_sdi      (spi_do      ),
	.sd_sdo      (spi_di      )
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
