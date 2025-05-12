/*
 * Avalon memory-mapped peripheral that generates VGA
 *
 * Stephen A. Edwards
 * Columbia University
 */

module vga_ball(input logic        clk,
                input logic        reset,
                input logic [7:0]  writedata,
                input logic        write,
                input              chipselect,
                input logic [2:0]  address,

                output logic [7:0] VGA_R, VGA_G, VGA_B,
                output logic       VGA_CLK, VGA_HS, VGA_VS,
                                     VGA_BLANK_n,
                output logic       VGA_SYNC_n);

   logic [10:0]   hcount;
   logic [9:0]    vcount;

   vga_counters counters(.clk50(clk), .*);

   // Keyboard parameters
   localparam int KEY_HEIGHT = 128;
   localparam int WHITE_WIDTH = 16;
   localparam int NUM_KEYS = 24;
   localparam int START_X = 128; // Centered horizontally (640 - 384)/2
   localparam int KEYBOARD_TOP = 480 - KEY_HEIGHT;

   // Color LUT (3-bit to RGB)
   function logic [23:0] color_lookup(input logic [2:0] color);
     case (color)
       3'b000: color_lookup = 24'h000000; // Black
       3'b001: color_lookup = 24'hFFFFFF; // White
       3'b010: color_lookup = 24'hADD8E6; // Light Blue
       3'b011: color_lookup = 24'h00008B; // Dark Blue
       3'b100: color_lookup = 24'h90EE90; // Light Green
       3'b101: color_lookup = 24'h006400; // Dark Green
       3'b110: color_lookup = 24'hFFA07A; // Light Red
       3'b111: color_lookup = 24'h8B0000; // Dark Red
       default: color_lookup = 24'h000000;
     endcase
   endfunction

   // Declare combinational vars
   logic [10:0] local_x;
   logic [4:0]  key_idx;
   logic [4:0]  divider_pos;
   logic [2:0]  color_code;
   logic        blank_active;

   assign local_x     = hcount - START_X;
   assign key_idx     = local_x / WHITE_WIDTH;
   assign divider_pos = local_x % 24;
   assign blank_active = VGA_BLANK_n;

   always @* begin
     if (!blank_active) begin
       {VGA_R, VGA_G, VGA_B} = 24'h000000;
     end else if (vcount >= KEYBOARD_TOP) begin
       if (divider_pos == 0)
         color_code = 3'b000; // black line
       else if (key_idx < NUM_KEYS)
         color_code = 3'b001; // white key
       else
         color_code = 3'b011; // background

       {VGA_R, VGA_G, VGA_B} = color_lookup(color_code);
     end else begin
       {VGA_R, VGA_G, VGA_B} = color_lookup(3'b011); // dark blue
     end
   end


endmodule

module vga_counters(
 input logic         clk50, reset,
 output logic [10:0] hcount,  // hcount[10:1] is pixel column
 output logic [9:0]  vcount,  // vcount[9:0] is pixel row
 output logic        VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n);

/*
 * 640 X 480 VGA timing for a 50 MHz clock: one pixel every other cycle
 */
   // Parameters for hcount
   parameter HACTIVE      = 11'd 1280,
             HFRONT_PORCH = 11'd 32,
             HSYNC        = 11'd 192,
             HBACK_PORCH  = 11'd 96,   
             HTOTAL       = HACTIVE + HFRONT_PORCH + HSYNC +
                            HBACK_PORCH; // 1600

   // Parameters for vcount
   parameter VACTIVE      = 10'd 480,
             VFRONT_PORCH = 10'd 10,
             VSYNC        = 10'd 2,
             VBACK_PORCH  = 10'd 33,
             VTOTAL       = VACTIVE + VFRONT_PORCH + VSYNC +
                            VBACK_PORCH; // 525

   logic endOfLine;

   always_ff @(posedge clk50 or posedge reset)
     if (reset)          hcount <= 0;
     else if (endOfLine) hcount <= 0;
     else                hcount <= hcount + 11'd 1;

   assign endOfLine = hcount == HTOTAL - 1;

   logic endOfField;

   always_ff @(posedge clk50 or posedge reset)
     if (reset)          vcount <= 0;
     else if (endOfLine)
       if (endOfField)   vcount <= 0;
       else              vcount <= vcount + 10'd 1;

   assign endOfField = vcount == VTOTAL - 1;

   assign VGA_HS = !( (hcount[10:8] == 3'b101) &
                      !(hcount[7:5] == 3'b111));
   assign VGA_VS = !( vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2);

   assign VGA_SYNC_n = 1'b0;

   assign VGA_BLANK_n = !( hcount[10] & (hcount[9] | hcount[8]) ) &
                        !( vcount[9] | (vcount[8:5] == 4'b1111) );

   assign VGA_CLK = hcount[0];

endmodule

