//-------------------------------------------------------------------------------------------------
module audio
//-------------------------------------------------------------------------------------------------
(
	input  wire      clock,
	input  wire      clock50,
   input  wire      reset,
	input  wire      speaker,
	input  wire      mic,
	input  wire      ear,
	input  wire[7:0] spd,
	input  wire[7:0] a1,
	input  wire[7:0] b1,
	input  wire[7:0] c1,
	input  wire[7:0] a2,
	input  wire[7:0] b2,
	input  wire[7:0] c2,
   output wire  i2s_bc,
   output wire  i2s_lc,
   output wire  i2s_dt,
	output wire[1:0] audio
);
//-------------------------------------------------------------------------------------------------

wire[2:0] sem = { speaker, ~ear, mic };

wire[7:0] ula
	= sem == 3'b000 ? 8'h00
	: sem == 3'b001 ? 8'h24
	: sem == 3'b010 ? 8'h40
	: sem == 3'b011 ? 8'h64
	: sem == 3'b100 ? 8'hB8
	: sem == 3'b101 ? 8'hC0
	: sem == 3'b110 ? 8'hF8
	:     /* 3'b111 */8'hFF;

//-------------------------------------------------------------------------------------------------

wire[9:0] ldacD = { 2'b00, ula } + { spd, 2'b00 } + { 2'b00, a1 } + { 2'b00, b1 } + { 2'b00, a2 } + { 2'b00, b2 };
wire[9:0] rdacD = { 2'b00, ula } + { spd, 2'b00 } + { 2'b00, b1 } + { 2'b00, c1 } + { 2'b00, b2 } + { 2'b00, c2 };

//-------------------------------------------------------------------------------------------------

dac #(.MSBI(9)) LDac
(
	.clock  (clock   ),
	.reset  (reset   ),
	.d      (ldacD   ),
	.q      (audio[0])
);

dac #(.MSBI(9)) RDac
(
	.clock  (clock   ),
	.reset  (reset   ),
	.d      (rdacD   ),
	.q      (audio[1])
);


//   signal zxn_audio_L_pre        : std_logic_vector(12 downto 0);
//   signal zxn_audio_R_pre        : std_logic_vector(12 downto 0);
   
// Instacia I2S audio
audio_top	i2s  
(
   .clk_50MHz (clock50),
   .dac_MCLK  (       ), //i2s_mclk_o,
   .dac_LRCK  (i2s_lc ), //i2s_lrclk_s,
   .dac_SCLK  (i2s_bc ), //i2s_bclk_s,
   .dac_SDIN  (i2s_dt ), //i2s_data_s,
   .L_data    ( { ldacD , 6'b000000 } ), // zxn_audio_L_pre & "000", --'0' & zxn_audio_L_pre & "00",
   .R_data    ( { rdacD , 6'b000000 } ) //zxn_audio_R_pre & "000"  --'0' & zxn_audio_R_pre & "00"	
); 


//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
