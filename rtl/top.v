module top (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,         // KEY[3]=reset, KEY[2]=select, KEY[1]=right, KEY[0]=left
    input  wire        song_loaded_done,

    input  wire        avs_write,
    input  wire        avs_read,
    input  wire [3:0]  avs_address,
    input  wire [63:0] avs_writedata,
    output wire [31:0] avs_readdata,

    // VGA output
    output wire [7:0]  VGA_R,
    output wire [7:0]  VGA_G,
    output wire [7:0]  VGA_B,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire        VGA_CLK,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N
);

    // === Clock and Reset ===
    wire clk = CLOCK_50;
    wire reset = ~KEY[3];

    // === VGA Timing ===
    wire [9:0] vga_x;
    wire [9:0] vga_y;
    wire       display_on;

    vga_controller vga_inst (
        .clk(clk),
        .reset(reset),
        .hs(VGA_HS),
        .vs(VGA_VS),
        .x(vga_x),
        .y(vga_y),
        .blank(display_on)
    );

    // === Color Output from Game Logic ===
    wire [7:0] vga_r, vga_g, vga_b;

    // === Game Module ===
    piano_tiles_game_hw game_inst (
        .clk(clk),
        .reset(reset),

        // Avalon-MM
        .avs_write(avs_write),
        .avs_read(avs_read),
        .avs_address(avs_address),
        .avs_writedata(avs_writedata),
        .avs_readdata(avs_readdata),

        // VGA
        .vga_x(vga_x),
        .vga_y(vga_y),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),

        // Display state
        .countdown_display(), // not routed
        .score_display(),     // not routed
        .show_countdown(),    // not routed
        .show_score(),        // not routed

        // Keys (mapped to FPGA buttons)
        .key5(~KEY[0]),       // KEY0 = left
        .key6(~KEY[2]),       // KEY2 = select
        .key7(~KEY[1]),       // KEY1 = right

        .song_loaded_done(song_loaded_done),
        .song_index(),        // not routed
        .load_song_trigger(), // not routed
        .game_started_hw()    // not routed
    );

    // === Output Color Control ===
    assign VGA_R = display_on ? vga_r : 8'd0;
    assign VGA_G = display_on ? vga_g : 8'd0;
    assign VGA_B = display_on ? vga_b : 8'd0;

    assign VGA_CLK = clk;
    assign VGA_BLANK_N = display_on;
    assign VGA_SYNC_N = 1'b0; // Not used
endmodule
