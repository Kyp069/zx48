// A video pipeline for ZXUNO ported from Mist. Just insert between the core video output and the VGA pins
// Provides an optional scandoubler

module zxuno_video
(
	// master clock
	// it should be 4x (or 2x) pixel clock for the scandoubler
	input        clk_sys,

	// scanlines (00-none 01-25% 10-50% 11-75%)
	input  [1:0] scanlines,

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	input        ce_divider,

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	input        scandoubler_disable,
	// disable csync without scandoubler
	input        no_csync,

	// video in
	input  [COLOR_DEPTH-1:0] R,
	input  [COLOR_DEPTH-1:0] G,
	input  [COLOR_DEPTH-1:0] B,

	input        HSync,
	input        VSync,

	// ZXUNO/ZXDOS video output signals
	output [5:0] VGA_R,
	output [5:0] VGA_G,
	output [5:0] VGA_B,
	output       VGA_VS,
	output       VGA_HS
);

parameter OSD_COLOR    = 3'd4;
parameter OSD_X_OFFSET = 10'd0;
parameter OSD_Y_OFFSET = 10'd0;
parameter SD_HCNT_WIDTH = 9;
parameter COLOR_DEPTH = 6; // 1-6
parameter OSD_AUTO_CE = 1'b1;
parameter SYNC_AND = 1'b0; // 0 - XOR, 1 - AND

wire [5:0] SD_R_O;
wire [5:0] SD_G_O;
wire [5:0] SD_B_O;
wire       SD_HS_O;
wire       SD_VS_O;

reg  [5:0] R_full;
reg  [5:0] G_full;
reg  [5:0] B_full;

always @(*) begin
	if (COLOR_DEPTH == 6) begin
		R_full = R;
		G_full = G;
		B_full = B;
	end else if (COLOR_DEPTH == 2) begin
		R_full = {3{R}};
		G_full = {3{G}};
		B_full = {3{B}};
	end else if (COLOR_DEPTH == 1) begin
		R_full = {6{R}};
		G_full = {6{G}};
		B_full = {6{B}};
	end else begin
		R_full = { R, R[COLOR_DEPTH-1 -:(6-COLOR_DEPTH)] };
		G_full = { G, G[COLOR_DEPTH-1 -:(6-COLOR_DEPTH)] };
		B_full = { B, B[COLOR_DEPTH-1 -:(6-COLOR_DEPTH)] };
	end
end

reg [1:0] i_div;
reg ce_x1, ce_x2;

reg last_hs_in;
always @(posedge clk_sys) begin
	last_hs_in <= HSync;
	if(last_hs_in & !HSync) begin
		i_div <= 2'b00;
	end else begin
		i_div <= i_div + 2'd1;
	end
end

always @(*) begin
	if (!ce_divider) begin
		ce_x1 = (i_div == 2'b01);
		ce_x2 = i_div[0];
	end else begin
		ce_x1 = i_div[0];
		ce_x2 = 1'b1;
	end
end

scandoubler #(SD_HCNT_WIDTH, COLOR_DEPTH) scandoubler
(
	.clk_sys    ( clk_sys    ),
	.scanlines  ( scanlines  ),
	.ce_x1      ( ce_x1      ),
	.ce_x2      ( ce_x2      ),
	.hs_in      ( HSync      ),
	.vs_in      ( VSync      ),
	.r_in       ( R          ),
	.g_in       ( G          ),
	.b_in       ( B          ),
	.hs_out     ( SD_HS_O    ),
	.vs_out     ( SD_VS_O    ),
	.r_out      ( SD_R_O     ),
	.g_out      ( SD_G_O     ),
	.b_out      ( SD_B_O     )
);

assign VGA_R = scandoubler_disable ? R_full : SD_R_O ;
assign VGA_G = scandoubler_disable ? G_full : SD_G_O;
assign VGA_B = scandoubler_disable ? B_full : SD_B_O ;

wire   cs = SYNC_AND ? (hs & vs) : ~(hs ^ vs);
wire   hs = scandoubler_disable ? HSync : SD_HS_O;
wire   vs = scandoubler_disable ? VSync : SD_VS_O;

// a vga->scart cable expects a composite sync signal on the VGA_HS output.
// and VCC on VGA_VS (to switch into rgb mode)
assign VGA_HS = scandoubler_disable ? cs : hs;
assign VGA_VS = scandoubler_disable ? 1'b1 : vs;

endmodule
