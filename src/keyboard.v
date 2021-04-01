//-------------------------------------------------------------------------------------------------
module keyboard
//-------------------------------------------------------------------------------------------------
(
	input  wire      clock,
	input  wire      ce,
	input  wire[1:0] ps2,
	output wire      f12,
	output wire      f11,
	output wire      f5,
	output wire[4:0] q,
	input  wire[7:0] a
);
//-------------------------------------------------------------------------------------------------

reg      ps2c;
reg      ps2n;
reg      ps2d;
reg[7:0] ps2f;

always @(posedge clock) if(ce)
begin
	ps2n <= 1'b0;
	ps2d <= ps2[1];
	ps2f <= { ps2[0], ps2f[7:1] };

	if(ps2f == 8'hFF)
	begin
		ps2c <= 1'b1;
	end
	else if(ps2f == 8'h00)
	begin
		ps2c <= 1'b0;
		if(ps2c) ps2n <= 1'b1;
	end
end

//-------------------------------------------------------------------------------------------------

reg parity;
reg received;

reg[8:0] data;
reg[3:0] count;
reg[7:0] scancode;

always @(posedge clock) if(ce)
begin
	received <= 1'b0;

	if(ps2n)
	begin
		if(count == 4'd0)
		begin
			parity <= 1'b0;
			if(!ps2d) count <= count+1'd1;
		end
		else
		begin
			if(count < 4'd10)
			begin
				data <= { ps2d, data[8:1] };
				count <= count+1'd1;
				parity <= parity ^ ps2d;
			end
			else if(ps2d)
			begin
				count <= 1'd0;
				if(parity)
				begin
					scancode <= data[7:0];
					received <= 1'b1;
				end
			end
			else count <= 1'd0;
		end
	end
end 

//-------------------------------------------------------------------------------------------------

reg pressed = 1'b0;

reg F5;  // nmi
reg F11; // boot
reg F12; // reset

reg alt;
reg del;
reg bs;

reg[4:0] key[7:0];

initial
begin
	F5 = 1'b1;
	F11 = 1'b1;
	F12 = 1'b1;

	alt = 1'b1;
	del = 1'b1;
	bs = 1'b1;

	key[0] = 5'b11111;
	key[1] = 5'b11111;
	key[2] = 5'b11111;
	key[3] = 5'b11111;
	key[4] = 5'b11111;
	key[5] = 5'b11111;
	key[6] = 5'b11111;
	key[7] = 5'b11111;
end

always @(posedge clock) if(ce)
if(received)
	if(scancode == 8'hF0) pressed <= 1'b1; // released
	else
	begin
		pressed <= 1'b0;

		case(scancode)
			8'h11: alt <= pressed; // right alt
			8'h71: del <= pressed; // right del

			8'h12: key[0][0] <= pressed; // CS - left shift
			8'h59: key[0][0] <= pressed; // CS - left shift
			8'h1A: key[0][1] <= pressed; // Z
			8'h22: key[0][2] <= pressed; // X
			8'h21: key[0][3] <= pressed; // C
			8'h2A: key[0][4] <= pressed; // V

			8'h1C: key[1][0] <= pressed; // A
			8'h1B: key[1][1] <= pressed; // S
			8'h23: key[1][2] <= pressed; // D
			8'h2B: key[1][3] <= pressed; // F
			8'h34: key[1][4] <= pressed; // G

			8'h15: key[2][0] <= pressed; // Q
			8'h1D: key[2][1] <= pressed; // W
			8'h24: key[2][2] <= pressed; // E
			8'h2D: key[2][3] <= pressed; // R
			8'h2C: key[2][4] <= pressed; // T

			8'h16: key[3][0] <= pressed; // 1
			8'h1E: key[3][1] <= pressed; // 2
			8'h26: key[3][2] <= pressed; // 3
			8'h25: key[3][3] <= pressed; // 4
			8'h2E: key[3][4] <= pressed; // 5

			8'h45: key[4][0] <= pressed; // 0
			8'h46: key[4][1] <= pressed; // 9
			8'h3E: key[4][2] <= pressed; // 8
			8'h3D: key[4][3] <= pressed; // 7
			8'h36: key[4][4] <= pressed; // 6

			8'h4D: key[5][0] <= pressed; // P
			8'h44: key[5][1] <= pressed; // O
			8'h43: key[5][2] <= pressed; // I
			8'h3C: key[5][3] <= pressed; // U
			8'h35: key[5][4] <= pressed; // Y

			8'h5A: key[6][0] <= pressed; // ENTER
			8'h4B: key[6][1] <= pressed; // L
			8'h42: key[6][2] <= pressed; // K
			8'h3B: key[6][3] <= pressed; // J
			8'h33: key[6][4] <= pressed; // H

			8'h29: key[7][0] <= pressed; // SPACE
			8'h14: key[7][1] <= pressed; // SS - right shift
			8'h3A: key[7][2] <= pressed; // M
			8'h31: key[7][3] <= pressed; // N
			8'h32: key[7][4] <= pressed; // B

			8'h54: { key[7][1], key[5][0] } <= { 2{pressed} }; // " (SS + P)
			8'h52: { key[7][1], key[5][1] } <= { 2{pressed} }; // ; (SS + P)
			8'h49: { key[7][1], key[7][2] } <= { 2{pressed} }; // . (SS + M)
			8'h41: { key[7][1], key[7][3] } <= { 2{pressed} }; // , (SS + N)
			8'h4A: { key[7][1], key[6][3] } <= { 2{pressed} }; // - (SS + J)
			8'h5B: { key[7][1], key[6][2] } <= { 2{pressed} }; // + (SS + K)
			8'h61: { key[7][1], key[0][1] } <= { 2{pressed} }; // : (SS + Z)
			8'h75: { key[0][0], key[4][3] } <= { 2{pressed} }; // up (CS + 7)
			8'h72: { key[0][0], key[4][4] } <= { 2{pressed} }; // down (CS + 6)
			8'h6B: { key[0][0], key[3][4] } <= { 2{pressed} }; // left (CS + 5)
			8'h74: { key[0][0], key[4][2] } <= { 2{pressed} }; // right (CS + 8)
			8'h76: { key[0][0], key[7][0] } <= { 2{pressed} }; // esc (CS + SPACE) - break

			8'h66: { key[0][0], key[4][0], bs } <= { 3{pressed} }; // backspace (CS + 0) - delete

			8'h03: F5  <= pressed;
			8'h78: F11 <= pressed;
			8'h07: F12 <= pressed;
		endcase
	end

//-------------------------------------------------------------------------------------------------

assign q =
{
	(a[0]|key[0][4])&(a[1]|key[1][4])&(a[2]|key[2][4])&(a[3]|key[3][4])&(a[4]|key[4][4])&(a[5]|key[5][4])&(a[6]|key[6][4])&(a[7]|key[7][4]),
	(a[0]|key[0][3])&(a[1]|key[1][3])&(a[2]|key[2][3])&(a[3]|key[3][3])&(a[4]|key[4][3])&(a[5]|key[5][3])&(a[6]|key[6][3])&(a[7]|key[7][3]),
	(a[0]|key[0][2])&(a[1]|key[1][2])&(a[2]|key[2][2])&(a[3]|key[3][2])&(a[4]|key[4][2])&(a[5]|key[5][2])&(a[6]|key[6][2])&(a[7]|key[7][2]),
	(a[0]|key[0][1])&(a[1]|key[1][1])&(a[2]|key[2][1])&(a[3]|key[3][1])&(a[4]|key[4][1])&(a[5]|key[5][1])&(a[6]|key[6][1])&(a[7]|key[7][1]),
	(a[0]|key[0][0])&(a[1]|key[1][0])&(a[2]|key[2][0])&(a[3]|key[3][0])&(a[4]|key[4][0])&(a[5]|key[5][0])&(a[6]|key[6][0])&(a[7]|key[7][0])
};

wire ctrl = key[7][1];

assign f5 = F5;
assign f11 = F11 && (ctrl|alt|bs);
assign f12 = F12 && (ctrl|alt|del);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
