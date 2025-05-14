/*
 * Avalon memory-mapped peripheral that generates VGA
 *
 * 
 * Columbia University
 *
 * Register map:
 * 
 * Byte Offset  7 ... 0   Meaning
 *        0    |  Red  |  Red component of background color (0-255)
 *        1    | Green |  Green component
 *        2    | Blue  |  Blue component
 */

module fpga_intf(
    input logic        clk,
    input logic        reset,
    input logic [7:0]  writedata,
    input logic        write,
    input              chipselect,
    input logic [2:0]  address,
    output logic [7:0] VGA_R, VGA_G, VGA_B,
    output logic       VGA_CLK, VGA_HS, VGA_VS,
                       VGA_BLANK_n,
    output logic       VGA_SYNC_n
);

    logic [10:0] hcount;
    logic [9:0]  vcount;

    logic [7:0] background_r, background_g, background_b;

    // Falling tile control
    logic [9:0] tile_y;
    logic [3:0] tile_column;
    logic [23:0] frame_counter; // For ~60Hz timing
    int tile_width;
    int tile_x_start;
    int tile_x_end;
    vga_counters counters(.clk50(clk), .*);

    always_ff @(posedge clk) begin
        if (reset) begin
            background_r <= 8'h0;
            background_g <= 8'h0;
            background_b <= 8'h80;
            tile_y       <= 0;
            tile_column  <= 4'd4;       // Tile above key 4
            frame_counter <= 0;
        end else begin
            if (chipselect && write) begin
                case (address)
                    3'h0 : background_r <= writedata;
                    3'h1 : background_g <= writedata;
                    3'h2 : background_b <= writedata;
                endcase
            end

            // Simulate 60 FPS
            frame_counter <= frame_counter + 1;
            if (frame_counter >= 833_333) begin // 50MHz / 60 ≈ 833,333
                frame_counter <= 0;
                tile_y <= tile_y + 1;
                if (tile_y > 480) tile_y <= 0;
            end
        end
    end

    always_comb begin
    {VGA_R, VGA_G, VGA_B} = {background_r, background_g, background_b};

    if (VGA_BLANK_n) begin
        int key_top    = 360;
        int key_bottom = 480;
        int border     = 2;

        // ---------- WHITE KEYS WITH OUTLINES ----------
        if (vcount >= key_top && vcount < key_bottom) begin
            // Each key is 42 px wide, starting at x = 5
            if (hcount >=   5 && hcount <  47) begin  // Key 0
                if ((hcount -   5 < border) || (47 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >=  47 && hcount <  89) begin  // Key 1
                if ((hcount -  47 < border) || (89 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >=  89 && hcount < 131) begin  // Key 2
                if ((hcount -  89 < border) || (131 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 131 && hcount < 173) begin  // Key 3
                if ((hcount - 131 < border) || (173 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 173 && hcount < 215) begin  // Key 4
                if ((hcount - 173 < border) || (215 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 215 && hcount < 257) begin  // Key 5
                if ((hcount - 215 < border) || (257 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 257 && hcount < 299) begin  // Key 6
                if ((hcount - 257 < border) || (299 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 299 && hcount < 341) begin  // Key 7
                if ((hcount - 299 < border) || (341 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 341 && hcount < 383) begin  // Key 8
                if ((hcount - 341 < border) || (383 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 383 && hcount < 425) begin  // Key 9
                if ((hcount - 383 < border) || (425 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 425 && hcount < 467) begin  // Key 10
                if ((hcount - 425 < border) || (467 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 467 && hcount < 509) begin  // Key 11
                if ((hcount - 467 < border) || (509 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 509 && hcount < 551) begin  // Key 12
                if ((hcount - 509 < border) || (551 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 551 && hcount < 593) begin  // Key 13
                if ((hcount - 551 < border) || (593 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end else if (hcount >= 593 && hcount < 635) begin  // Key 14
                if ((hcount - 593 < border) || (635 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                else  {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};
            end
        end

        // ---------- BLACK KEYS ----------
        if (vcount >= key_top && vcount < key_top + 60) begin
            if ((hcount >=  26 && hcount <  64) ||  // C#1
                (hcount >=  68 && hcount <  106) ||  // D#1

                (hcount >= 152 && hcount < 190) ||  // F#1
                (hcount >= 194 && hcount < 232) ||  // G#1
                (hcount >= 236 && hcount < 274) ||  // A#1

                (hcount >= 320 && hcount < 358) ||  // C#2
                (hcount >= 362 && hcount < 400) ||  // D#2

                (hcount >= 446 && hcount < 484) ||  // F#2
                (hcount >= 488 && hcount < 520) ||  // G#2
                (hcount >= 530 && hcount < 568))    // A#2
                {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
    end
 end

            // -------- Falling tile --------
            tile_width = 42;
            tile_x_start = 5 + tile_column * tile_width;
            tile_x_end = tile_x_start + tile_width;
            if (vcount >= tile_y && vcount < tile_y + 120) begin // tile height = 20 px
                if (hcount >= tile_x_start && hcount < tile_x_end) begin
                    {VGA_R, VGA_G, VGA_B} = {8'h00, 8'hFF, 8'hFF}; // Cyan tile
                end
            end
        end
endmodule


module vga_counters(
 input logic 	     clk50, reset,
 output logic [10:0] hcount,  // hcount[10:1] is pixel column
 output logic [9:0]  vcount,  // vcount[9:0] is pixel row
 output logic 	     VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n);

/*
 * 640 X 480 VGA timing for a 50 MHz clock: one pixel every other cycle
 * 
 * HCOUNT 1599 0             1279       1599 0
 *             _______________              ________
 * ___________|    Video      |____________|  Video
 * 
 * 
 * |SYNC| BP |<-- HACTIVE -->|FP|SYNC| BP |<-- HACTIVE
 *       _______________________      _____________
 * |____|       VGA_HS          |____|
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
     else  	         hcount <= hcount + 11'd 1;

   assign endOfLine = hcount == HTOTAL - 1;
       
   logic endOfField;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          vcount <= 0;
     else if (endOfLine)
       if (endOfField)   vcount <= 0;
       else              vcount <= vcount + 10'd 1;

   assign endOfField = vcount == VTOTAL - 1;

   // Horizontal sync: from 0x520 to 0x5DF (0x57F)
   // 101 0010 0000 to 101 1101 1111
   assign VGA_HS = !( (hcount[10:8] == 3'b101) &
		      !(hcount[7:5] == 3'b111));
   assign VGA_VS = !( vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2);

   assign VGA_SYNC_n = 1'b0; // For putting sync on the green signal; unused
   
   // Horizontal active: 0 to 1279     Vertical active: 0 to 479
   // 101 0000 0000  1280	       01 1110 0000  480
   // 110 0011 1111  1599	       10 0000 1100  524
   assign VGA_BLANK_n = !( hcount[10] & (hcount[9] | hcount[8]) ) &
			!( vcount[9] | (vcount[8:5] == 4'b1111) );

   /* VGA_CLK is 25 MHz
    *             __    __    __
    * clk50    __|  |__|  |__|
    *        
    *             _____       __
    * hcount[0]__|     |_____|
    */
   assign VGA_CLK = hcount[0]; // 25 MHz clock: rising edge sensitive
   
endmodule
