//-------------------------------------------------------------------------------------------------
module memory
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       ce,

	input  wire       power,
	output wire       ready,

	input  wire       reset,
	input  wire       rfsh,
	input  wire       iorq,
	input  wire       mreq,
	input  wire       wr,
	input  wire       rd,
	input  wire       m1,
	input  wire[ 7:0] d,
	output wire[ 7:0] q,
	input  wire[15:0] a,

	input  wire       vduCe,
	output wire[ 7:0] vduQ,
	input  wire[12:0] vduA,

`ifdef ZX1
   output wire[1:0]  scndbl,   //configuración de bios de scandoubler 
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
   output wire[1:0]  scndbl,   //configuración de bios de scandoubler 
	output wire       sramOe,
	output wire       sramWe,
	output wire       sramUb,
	output wire       sramLb,
	inout  wire[15:0] sramDQ,
	output wire[20:0] sramA
`endif
);
//-------------------------------------------------------------------------------------------------

reg forcemap;
reg automap;
reg mapram;
reg m1on;
reg[3:0] mappage;

always @(posedge clock) if(ce)
if(!reset)
begin
	forcemap <= 1'b0;
	automap <= 1'b0;
	mappage <= 4'd0;
	mapram <= 1'b0;
	m1on <= 1'b0;
end
else
begin
	if(!iorq && !wr && a[7:0] == 8'hE3)
	begin
		forcemap <= d[7];
		mappage <= d[3:0];
		mapram <= d[6]|mapram;
	end

	if(!mreq && !m1)
	begin
		if(a == 16'h0000 || a == 16'h0008 || a == 16'h0038 || a == 16'h0066 || a == 16'h04C6 || a == 16'h0562)
			m1on <= 1'b1; // activate automapper after this cycle

		else if(a[15:3] == 13'h3FF)
			m1on <= 1'b0; // deactivate automapper after this cycle

		else if(a[15:8] == 8'h3D)
		begin
			m1on <= 1'b1; // activate automapper immediately
			automap <= 1'b1;
		end
	end

	if(m1) automap <= m1on;
end

wire map = forcemap || automap;
wire[3:0] page = !a[13] && mapram ? 4'd3 : mappage;

//-------------------------------------------------------------------------------------------------

wire[ 7:0] romQ;
wire[13:0] romA = a[13:0];

rom #(.KB(16), .FN("48.hex")) Rom
(
	.clock  (clock  ),
	.ce     (ce     ),
	.q      (romQ   ),
	.a      (romA   )
);

//-------------------------------------------------------------------------------------------------

wire[ 7:0] esxQ;
wire[12:0] esxA = a[12:0];

rom #(.KB(8), .FN("esxdos.hex")) Esx
(
	.clock  (clock  ),
	.ce     (ce     ),
	.q      (esxQ   ),
	.a      (esxA   )
);

//-------------------------------------------------------------------------------------------------

wire[12:0] dprA1 = { vduA[12:7], !rfsh && a[15:14] == 2'b01 ? a[6:0] : vduA[6:0] };

wire dprWe2 = !(!mreq && !wr && a[15:13] == 3'b010);
wire[12:0] dprA2 = a[12:0];

dprs #(.KB(8)) Dpr
(
	.clock  (clock  ),
	.ce1    (vduCe  ),
	.q1     (vduQ   ),
	.a1     (dprA1  ),
	.ce2    (ce     ),
	.we2    (dprWe2 ),
	.d2     (d      ),
	.a2     (dprA2  )
);

//-------------------------------------------------------------------------------------------------

`ifdef ZX1
assign ready = power;
assign sramWe = !(!mreq && !wr && (a[15] || a[14] || (a[13] && map)));
assign sramDQ = sramWe ? 8'hZZ : d;
assign sramA = power ? { 2'b00, a[15:14] == 2'b00 && map ? { 1'b1, page, a[12:0] } : { 2'b00, a } }
               : 21'h08FD5 ; //magic place where the scandoubler settings have been stored
assign q = a[15:13] == 3'b000 && map && !mapram ? esxQ : a[15:14] == 2'b00 && !map ? romQ : sramDQ;
reg [7:0] scandbl_setting;
always @(posedge clock) if (!power) scandbl_setting <= sramDQ;
assign scndbl = scandbl_setting[1:0];
`elsif ZX2
wire sdrWe = !(!mreq && !wr && (a[15] || a[14] || (a[13] && map)));
wire sdrRd = !(!mreq && !rd && (a[15] || a[14] || map));

wire[15:0] sdrD = { 8'h00, d };
wire[15:0] sdrQ;
wire[23:0] sdrA = { 6'h00, a[15:14] == 2'b00 && map ? { 1'b1, page, a[12:0] } : { 2'b00, a } };

sdram Ram
(
	.clock   (clock   ),
	.power   (power   ),
	.ready   (ready   ),
	.rfsh    (rfsh    ),
	.wr      (sdrWe   ),
	.rd      (sdrRd   ),
	.d       (sdrD    ),
	.q       (sdrQ    ),
	.a       (sdrA    ),
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
);
assign q = a[15:13] == 3'b000 && map && !mapram ? esxQ : a[15:14] == 2'b00 && !map ? romQ : sdrQ[7:0];
`elsif ZXD
assign ready = power;
assign sramOe = 1'b0;
assign sramUb = 1'b1;
assign sramLb = 1'b0;

assign sramWe = !(!mreq && !wr && (a[15] || a[14] || (a[13] && map)));
assign sramDQ = sramWe ? 16'hZZZZ : { 8'hFF, d };
assign sramA = power ? { 2'b00, a[15:14] == 2'b00 && map ? { 1'b1, page, a[12:0] } : { 2'b00, a } }
               : 21'h08FD5 ; //magic place where the scandoubler settings have been stored
assign q = a[15:13] == 3'b000 && map && !mapram ? esxQ : a[15:14] == 2'b00 && !map ? romQ : sramDQ[7:0];
reg [7:0] scandbl_setting;
always @(posedge clock) if (!power) scandbl_setting <= sramDQ[7:0];
assign scndbl = scandbl_setting[1:0];
`endif

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
