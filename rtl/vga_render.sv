module vga_render #(
    parameter MAX_TILES = 32
)(
    input  wire        clk,
    input  wire [9:0]  vga_x,
    input  wire [9:0]  vga_y,
    input  wire [31:0] game_timer_us,

    // Falling tiles info
    input  wire [7:0]   tiles_note     [MAX_TILES-1:0],
    input  wire [31:0]  tiles_timestamp[MAX_TILES-1:0],
    input  wire         tiles_active   [MAX_TILES-1:0],

    // User input (note from Launchkey)
    input  wire [7:0]   user_note,
    input  wire         user_input_ready,

    // VGA output
    output reg  [7:0]  vga_r,
    output reg  [7:0]  vga_g,
    output reg  [7:0]  vga_b
);

    // Constants
    localparam NOTE_MIN = 60;
    localparam NOTE_MAX = 84;
    localparam KEY_WIDTH = 25;
    localparam KEY_HEIGHT = 128;
    localparam SCREEN_BOTTOM = 480;
    localparam HIT_LINE_Y = SCREEN_BOTTOM - KEY_HEIGHT;
    localparam FALL_SPEED_PX_PER_MS = 0.3;
    localparam TILE_HEIGHT = 8;

    // Internal flags
    integer i;
    reg is_tile_pixel;
    reg is_key_pixel;
    reg user_is_hitting_this_key;

    always @(*) begin
        is_tile_pixel = 0;
        is_key_pixel = 0;
        user_is_hitting_this_key = 0;

        // Default background
        vga_r = 8'h00;
        vga_g = 8'h00;
        vga_b = 8'h00;

        // Falling tile detection loop
        for (i = 0; i < MAX_TILES; i = i + 1) begin
            if (tiles_active[i]) begin
                // Compute horizontal bounds
                if (tiles_note[i] >= NOTE_MIN && tiles_note[i] <= NOTE_MAX) begin
                    integer key_idx = tiles_note[i] - NOTE_MIN;
                    integer key_x_start = key_idx * KEY_WIDTH;
                    integer key_x_end = key_x_start + KEY_WIDTH;

                    // Vertical position of tile
                    integer elapsed_us = (game_timer_us > tiles_timestamp[i]) ? (game_timer_us - tiles_timestamp[i]) : 0;
                    integer tile_y_pos = (elapsed_us * FALL_SPEED_PX_PER_MS);

                    // Check if pixel is in tile rectangle
                    if (vga_x >= key_x_start && vga_x < key_x_end &&
                        vga_y >= tile_y_pos && vga_y < tile_y_pos + TILE_HEIGHT) begin
                        is_tile_pixel = 1;
                    end

                    // Draw key at bottom
                    if (vga_y >= HIT_LINE_Y && vga_y < SCREEN_BOTTOM &&
                        vga_x >= key_x_start && vga_x < key_x_end) begin
                        is_key_pixel = 1;
                        if (user_input_ready && user_note == tiles_note[i])
                            user_is_hitting_this_key = 1;
                    end
                end
            end
        end

        // Final pixel color decision
        if (is_tile_pixel) begin
            vga_r = 8'hFF;
            vga_g = 8'h55;
            vga_b = 8'h00;
        end else if (is_key_pixel) begin
            if (user_is_hitting_this_key) begin
                vga_r = 8'h00;
                vga_g = 8'hFF;
                vga_b = 8'h00;
            end else begin
                vga_r = 8'hDD;
                vga_g = 8'hDD;
                vga_b = 8'hDD;
            end
        end
    end
endmodule
