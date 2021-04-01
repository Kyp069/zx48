`timescale 1ns / 1ps

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 09:00:25 2018-07-20 by Miguel Angel Rodriguez Jodar
//    (c)2014-2020 ZXUNO association.
//    ZXUNO official repository: http://svn.zxuno.com/svn/zxuno
//    Username: guest   Password: zxuno
//    Github repository for this core: https://github.com/mcleod-ideafix/zxuno_spectrum_core
//
//    ZXUNO Spectrum core is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    ZXUNO Spectrum core is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with the ZXUNO Spectrum core.  If not, see <https://www.gnu.org/licenses/>.
//
//    Any distributed copy of this file must keep this notice intact.
//    Port to suport ZXDOS+ megadrive joystick
//
//    *** clk should be higher than 14Mhz
//			 With 14Mhz only joystick 1 working all buttons
//			 Tesed at 16,6Mhz and working all buttons in both joystick
//
module joydecoder (
//-------------------------------------------
  input wire clk,
  input wire joy_data,
  output wire joy_clk,
  output wire joy_load_n,
  input wire reset,
//-----------------------------------------
	input wire hsync_n_s,

	output wire [11:0] joy1_o, // -- MXYZ SACB RLDU  Negative Logic
	output wire [11:0] joy2_o  // -- MXYZ SACB RLDU  Negative Logic
  );
  
   // ODDR2: Output Double Data Rate Output Register with Set, Reset
   //        and Clock Enable.
   //        Spartan-6
   // Xilinx HDL Language Template, version 14.7

   ODDR2 #(
      .DDR_ALIGNMENT("NONE"), // Sets output alignment to "NONE", "C0" or "C1" 
      .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
      .SRTYPE("SYNC") // Specifies "SYNC" or "ASYNC" set/reset
   ) ODDR2_inst (
      .Q(joy_clk),   // 1-bit DDR output data
      .C0(clk),   // 1-bit clock input
      .C1(!clk),   // 1-bit clock input
      .CE(!reset), // 1-bit clock enable input
      .D0(1'b1), // 1-bit data input (associated with C0)
      .D1(1'b0), // 1-bit data input (associated with C1)
      .R(1'b0),   // 1-bit reset input
      .S(1'b0)    // 1-bit set input
   );
   // End of ODDR2_inst instantiation

	reg [3:0] hsaux = 4'b0000;
	wire hsref;

	//hs de referencia
	assign hsref = hsync_n_s; 
  
  //Gestion de Joystick
   reg [5:0] joy1  = 6'b111111, joy2  = 6'h111111;   // CB RLDU
   reg joy_renew = 1'b1;
   reg [4:0]joy_count = 5'd0;
   
   assign joy_load_n = joy_renew;

	//Lectura pins de joystick - a través de un shifter
	always @(posedge clk) 
	begin 
	  if (reset) begin
		 hsaux <= 4'b0;
		 joy_renew <= 1'b1;
	  end
	  else begin
			hsaux <= {hsaux[2:0], hsync_n_s};
		
		   if (joy_count == 5'd0) 
			  begin
				joy_renew <= 1'b0;
			  end 
			else 
			  begin
				joy_renew <= 1'b1;
           end
		
			//if (hsaux[2] && !hsaux[1]) begin
			//if (hsaux[1] && !hsaux[0]) begin
			if (hsaux[3] && !hsaux[2]) begin
				// reseteo al inicio del sincronismo horizontal hs, 
				// con un pequeño desplazamiento ya que la carga debe 
				// hacerse con el hs en valor bajo para las lecturas adicionales
				// En el momento de la carga es cuando se recogen 
				// los valores en el shifter aunque se lean posteriormente
				joy_count <= 5'd0;
		   end
			else begin
			  if (joy_count == 5'd18) 
				  begin
					joy_count <= 5'd0;
				  end
				else 
				  begin
					joy_count <= joy_count + 1'b1;
				  end      
			end
		end
   end
	//assign joy_renew = (joy_count == 5'd0) ? 1'b0: 1'b1 ;

   always @(posedge clk) begin
         case (joy_count)
            5'd4  : joy1[5]  <= joy_data;   //  1p fire2
            5'd5  : joy1[4]  <= joy_data;   //  1p fire1
            5'd6  : joy1[3]  <= joy_data;   //  1p right
            5'd7  : joy1[2]  <= joy_data;   //  1p left
            5'd8  : joy1[1]  <= joy_data;   //  1p down
            5'd9  : joy1[0]  <= joy_data;   //  1p up
            5'd12  : joy2[5]  <= joy_data;   //  2p fire2
            5'd13  : joy2[4]  <= joy_data;   //  2p fire1
            5'd14 : joy2[3]  <= joy_data;   //  2p right
            5'd15 : joy2[2]  <= joy_data;   //  2p left
            5'd16 : joy2[1]  <= joy_data;   //  2p down
            5'd17 : joy2[0]  <= joy_data;   //  2p up
         endcase              
   end
	
	//Logica joystick megadrive 6 botones o joystick pasivo
	// a partir de los pins leidos previamente
   sega_joystick_6b joystick_md
	(
		.clk( clk ),
		.joy_load( ~joy_renew ),
		.reset( reset ),
		.joy1_up_i(joy1[0]),
		.joy1_down_i(joy1[1]),
		.joy1_left_i(joy1[2]),
		.joy1_right_i(joy1[3]),
		.joy1_p6_i(joy1[4]),
		.joy1_p9_i(joy1[5]),
		.joy2_up_i(joy2[0]),
		.joy2_down_i(joy2[1]),
		.joy2_left_i(joy2[2]),
		.joy2_right_i(joy2[3]),
		.joy2_p6_i(joy2[4]),
		.joy2_p9_i(joy2[5]),
		.hsync_n_s(hsref),

		.joy1_o(joy1_o), // -- MXYZ SACB RLDU  Negative Logic
		.joy2_o(joy2_o)  // -- MXYZ SACB RLDU  Negative Logic
	);

endmodule

module sega_joystick_6b
(
	input wire clk,
	input wire joy_load,
	input wire reset,
	input wire joy1_up_i,
	input wire joy1_down_i,
	input wire joy1_left_i,
	input wire joy1_right_i,
	input wire joy1_p6_i,
	input wire joy1_p9_i,
	input wire joy2_up_i,
	input wire joy2_down_i,
	input wire joy2_left_i,
	input wire joy2_right_i,
	input wire joy2_p6_i,
	input wire joy2_p9_i,
	input wire hsync_n_s,

	output wire [11:0] joy1_o, // -- MXYZ SACB RLDU  Negative Logic
	output wire [11:0] joy2_o  // -- MXYZ SACB RLDU  Negative Logic
);
 
//----   Joystick read with sega 6 button support  ---------------------- 

	//FSM para cada mando
	sega_joystick_fsm fsm_joystick1
	(
		.clk(clk),
		.joy_load(joy_load),
		.reset(reset),
		.joy_up_i(joy1_up_i),
		.joy_down_i(joy1_down_i),
		.joy_left_i(joy1_left_i),
		.joy_right_i(joy1_right_i),
		.joy_p6_i(joy1_p6_i),
		.joy_p9_i(joy1_p9_i),
		.vga_hsref(hsync_n_s),
		.joy_o(joy1_o)  // -- MXYZ SACB RLDU  Negative Logic
	);

	sega_joystick_fsm fsm_joystick2
	(
		.clk(clk),
		.joy_load(joy_load),
		.reset(reset),
		.joy_up_i(joy2_up_i),
		.joy_down_i(joy2_down_i),
		.joy_left_i(joy2_left_i),
		.joy_right_i(joy2_right_i),
		.joy_p6_i(joy2_p6_i),
		.joy_p9_i(joy2_p9_i),
		.vga_hsref(hsync_n_s),
		.joy_o(joy2_o)  // -- MXYZ SACB RLDU  Negative Logic
	);

endmodule

//FSM para detectar mandos megadrive y pasivos
module sega_joystick_fsm
(
	input wire clk,
	input wire joy_load,
	input wire reset,
	input wire joy_up_i,
	input wire joy_down_i,
	input wire joy_left_i,
	input wire joy_right_i,
	input wire joy_p6_i,
	input wire joy_p9_i,
	input wire vga_hsref,

	output wire [11:0] joy_o  // -- MXYZ SACB RLDU  Negative Logic
);

   reg [11:0]joy_s = 12'b111111111111; 	
	reg hs_prev;
	reg [3:0] cont;
	reg saltarciclo = 1'b0;
	reg [1:0] joyl, joyr;
	
	wire lrbtzero;
	wire udlrbtzero;

	// Symbolic State declation
	localparam [4:0] s1= 4'd0,
			 s2= 4'd1,
			 s3= 4'd2,
			 s4= 4'd3,
			 s5= 4'd4,
			 s6= 4'd5,
			 s7= 4'd6,
			 s8= 4'd7,
			 s9= 4'd8;

// S1 - HS=1 - UDLRBC
// S2 - HS=0 - UD00AS
// S3 - HS=1 - UDLRBC
// S4 - HS=0 - UD00AS
// S5 - HS=1 - UDLRBC
// S6 - HS=0 - 0000AS
// S7 - HS=1 - ZXYM--
// S8 - HS=0 - ----AS

	// State declation
	reg [4:0] st_reg = s1, st_next;

	// Next State asign
	always @(posedge clk) 
	begin
	  if (reset) begin
	    st_reg <= s1;
	  end
	  else begin
		 st_reg <= st_next;
	  end
	end
	
	// Next State logic joystick 1
	//always @(vga_hsref or udlrbtzero or lrbtzero)
	// el hs de referencia válido es el del hs_prev, que es cuando se hizo la carga del shifter.
	always @(posedge joy_load) 
	begin
	  case (st_reg)
	    s1: if (hs_prev) begin //If high continue in state s1
				  st_next <= s1;
			  end
			  else begin
				  st_next <= s2;
			  end
	    s2: if (hs_prev) begin
				  if (udlrbtzero) begin // Detect S6 - HS=0 - 0000AS - go to S7
					 st_next <= s7;
				  end
				  else if (lrbtzero) begin // Detect S2/4 HS=0 - UD00AS - go to next state
					 st_next <= s3;
				  end
				  else begin //No S2/4/6 go to S1, for pasive joystics
					 st_next <= s1;
				  end
				end
				else 
					st_next <= s2;
	    s3:  if (hs_prev)
				  st_next <= s3;
				else
				  st_next <= s4;
	    s4: if (hs_prev)	begin
				  if (udlrbtzero)
					 st_next <= s7;
				  else
				  if (lrbtzero)
					 st_next <= s5;
				  else
					 st_next <= s1;
				end				  
				else
				  st_next <= s4;
	    s5:  if (hs_prev)
				  st_next <= s5;
				else
				  st_next <= s6;
	    s6: if (hs_prev) begin // Detect S6 - HS=0 - 0000AS - go to S7
				  if (udlrbtzero)
					 st_next <= s7;
				  else
					 st_next <= s1;
//				  if (lrbtzero)
//					 st_next <= s3;
//				  else
//					 st_next <= s1;
				end				  
				else
				  st_next <= s6;
	    s7: if (hs_prev)		// S7 - HS=1 - ZXYM--
				  st_next <= s7;
			  else
				  st_next <= s8;
	    s8: if (hs_prev) begin
				  st_next <= s1;
				end else
				  st_next <= s8;
	    default: st_next <= s1;
	  endcase
	end 

	// hs ref value always on the previous joyload
	always @(posedge joy_load) 
	begin
		if (reset) begin
			hs_prev <= 1'bX;
			//lrbtzero_reg <= 1'b0;
		end
		else begin
		   hs_prev <= vga_hsref;
			//lrbtzero_reg <= lrbtzero;
		end
	end
	//reg lrbtzero_reg = 1'b0;

	// Output logic joystick 1
	always @(negedge joy_load)
	begin
		if (reset) begin
			joy_s <= 12'b111111111111;
			cont <= 4'b0;
		end
		else begin
		  if (hs_prev == vga_hsref) begin //Omit read if hs changed
		      cont <= {cont[2:0], 1'b1};  //counter joyload cyles for omit first-second cycle after hs change
				// 1,3 and 5 Cycles
				//if ((st_reg == s1 /*|| st_reg == s3 || st_reg == s5*/) && cont[2] /*&& ciclobueno1*/) begin //Muy estable pero falla con mandos 3 botones
				if ((st_reg == s1 /*|| st_reg == s3 || st_reg == s5*/) && cont[2] /*&& ciclobueno1*/) begin 
					 //joy_s[3:0] <= {joy_right_i, joy_left_i, joy_down_i, joy_up_i}; //-- R, L, D, U
					 joy_s[3:0] <= {joyr[0] || joyr[1], joyl[0] || joyl[1], joy_down_i, joy_up_i}; //-- R, L, D, U
					 joy_s[5:4] <= {joy_p9_i, joy_p6_i}; //-- C, B
					 joyl <= {joyl[0], joy_left_i};  //to avoid lost ticks from even states
					 joyr <= {joyr[0], joy_right_i}; //to avoid lost ticks from even states 
				end
				// Cycle 2,4,6
				if ((st_reg == s2 || st_reg == s4 || st_reg == s6 || st_reg == s8 ) 
							/* cont[0] */ && lrbtzero ) begin 
					  joy_s[7:6] <= { joy_p9_i , joy_p6_i }; //-- Start, A   
				end				
				if (st_reg == s7 && cont[3] /*&& !udlrbtzero*/ ) begin// Cycle 7
					  joy_s[11:8] <= { joy_right_i, joy_left_i, joy_down_i, joy_up_i }; //-- Mode, X, Y e Z
				end
			end
			else
				cont <= 4'b0; //counter for joyload after hs changed
		end
	end

	assign lrbtzero = !joy_left_i && !joy_right_i; //LR=00 in cycle 2,4
	assign udlrbtzero = !joy_up_i && !joy_down_i && !joy_left_i && !joy_right_i; //UDLR=0000 in cycle 6
		
	assign joy_o = joy_s;

endmodule

