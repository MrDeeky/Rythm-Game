module background
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
        SW,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input   [9:0]   SW;
	input   [3:0]   KEY;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
    
    // Instansiate datapath
	// datapath d0(...);
		datapath d0(SW[6:0], CLOCK_50, KEY[0], enable, ld_x, ld_y, ld_c, X, Y, colour);
		
    // Instansiate FSM control
    // control c0(...);
		control c0(~KEY[3], KEY[0], ~KEY[1], CLOCK_50, enable, ld_x, ld_y, ld_c, writeEn);
endmodule

module datapath(data_in, clk, reset_n, enable, ld_x, ld_y, ld_c, X, Y, colour_out);
	input clk, reset_n, enable, ld_x, ld_y, ld_c;
	input [6:0] data_in;
	output [6:0] X, Y;
	output [2:0] colour_out;
	reg [6:0] x, y;
	reg [2:0] col;
	
	wire [1:0] c1, c2, c3;
	
	always @(posedge clk)
	begin
		if(!reset_n) // Reset ON
			begin
				x <= 8'b0;
				y <= 7'b0;
				col <= 3'b0;
			end
		else
			begin
				if(ld_x)
					x <= {1'b0, data_in};
				if(ld_y)
					y <= data_in;
				if(ld_c)
					if(y == 1101100) // Last Row
						if(x == 0000000)
							col <= 3'b001;
						else if(x == 0010011)
							col <= 3'b010;
						else if(x == 0100111)
							col <= 3'b100;
						else if(x == 0111011)
							col <= 3'b110;
					else
						col <= 3'b111;
			end
	end
	
	x_counter xc(clk, reset_n, enable, c1);
	row_counter rc(clk, reset_n, enable, c2);
	assign enable_y = (c2 == 7'b0000000) ? 1 : 0;
	y_counter yc(clk, reset_n, enable_y, c3);
	assign X = x + c1;
	assign Y = y + c3;
	assign colour_out = col;
endmodule

module x_counter(clk, reset_n, enable, q);
	input clk, reset_n, enable;
	output reg [6:0] q; // MAX = 84 (1010100) ;
	
	always @(posedge clk)
	begin
		if(reset_n == 1'b0)
			q <= 7'b0000000;
		else if(enable == 1'b1)
			begin
				if(q == 7'b1010100)
					q <= 7'b0000000;
				else
					q <= q + 1'b1;
			end
	end
endmodule

module y_counter(clk, reset_n, enable, q);
	input clk, reset_n, enable;
	output reg [6:0] q; //MAX = 120 (1111000);
	
	always @(posedge clk)
	begin
		if(reset_n == 1'b0)
			q <= 7'b0000000;
		else if(enable == 1'b1)
			begin
				if(q == 7'b1111000)
					q <= 7'b0000000;
				else
					q <= q + 1'b1;
			end
	end
endmodule

module row_counter(clk, reset_n, enable, q);
	input clk, reset_n, enable;
	output reg [6:0] q; //MAX = 84 (1010100)
	
	always @(posedge clk)
	begin
		if(reset_n == 1'b1)
			q <= 7'b1010100;
		else if(enable == 1'b0)
			begin
				if(q == 7'b0000000)
					q <= 7'b1010100;
				else
					q <= q - 1'b1;
			end
	end
endmodule

control(go, reset, load, clk, enable, ld_x, ld_y, ld_c, plot);
	input go, reset_n, load, clk;
	output reg enable, ld_x, ld_y, ld_c, plot;
	reg [2:0] current_state, next_state;
	reg c = 1'b0;
	
	wire [4:0] q;
	wire clk_1;
	
	localparam S_LOAD_X = 3'b000,
				  S_LOAD_X_WAIT = 3'b001,
				  S_LOAD_Y = 3'b010,
				  S_LOAD_Y_WAIT = 3'b011;
				  S_CYCLE_0 = 3'b100;
	
	rate_counter rc(clk, reset_n, 1'b1, q);
	assign clk_1 = (q == 5'b00000) ? 1 : 0;
	
	always @(*)
	begin
		case(current_state)
			S_LOAD_X: next_state = go ? S_LOAD_X_WAIT : S_LOAD_X;
			S_LOAD_X_WAIT: next_state = go ? S_LOAD_X_WAIT : S_LOAD_Y;
			S_LOAD_Y: next_state = load ? S_LOAD_Y_WAIT : S_LOAD_Y:
			S_LOAD_Y_WAIT: next_state = load ? S_LOAD_Y_WAIT : S_CYCLE_0;
			S_CYCLE_0: next_state = S_LOAD_X;
		default: next_state = S_LOAD_X;
		endcase
	end
	
	always @(*)
	begin
		ld_x = 1'b0;
		ld_y = 1'b0;
		ld_c = 1'b0;
		enable = 1'b0;
		plot = 1'b0;
		
		case(current_state)
			S_LOAD_X:
				begin
					ld_x = 1'b1;
				end
			S_LOAD_Y:
				begin
					ld_y = 1'b1;
				end
			S_CYCLE_0:
				begin
					ld_c = 1'b1;
					enable = 1'b1;
					plot = 1'b1;
				end
		endcase
	end
	
	always @(posedge clk_1)
	begin
		if(!reset_n)
			current_state <= S_LOAD_X;
		else
			current_state <= next_state;
	end
endmodule
