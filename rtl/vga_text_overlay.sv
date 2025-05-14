module vga_text_overlay (
    input  wire        clk,
    input  wire [9:0]  vga_x,
    input  wire [9:0]  vga_y,

    input  wire [3:0]  song_index,
    input  wire [31:0] countdown_display,
    input  wire        show_countdown,
    input  wire [31:0] score_display,
    input  wire        show_score,

    output reg         draw_text,
    output reg  [7:0]  r,
    output reg  [7:0]  g,
    output reg  [7:0]  b
);

    // Screen dimensions
    localparam SCREEN_WIDTH  = 640;
    localparam SCREEN_HEIGHT = 480;

    // Regions (can be tuned)
    wire is_song_index_region = (vga_y >= 0 && vga_y < 16) && (vga_x >= 0 && vga_x < 80);
    wire is_countdown_region  = (vga_y >= 200 && vga_y < 280) && (vga_x >= 300 && vga_x < 340);
    wire is_score_region      = (vga_y >= 200 && vga_y < 280) && (vga_x >= 280 && vga_x < 400);

    reg [3:0] current_digit;

    always @(*) begin
        draw_text = 0;
        r = 0;
        g = 0;
        b = 0;

        // === SONG INDEX ===
        if (is_song_index_region) begin
            draw_text = 1;
            current_digit = song_index;

            r = 8'h00;
            g = 8'h80;
            b = 8'hFF;
        end

        // === COUNTDOWN (center) ===
        else if (show_countdown && is_countdown_region) begin
            draw_text = 1;
            current_digit = countdown_display[3:0];

            r = 8'hFF;
            g = 8'hFF;
            b = 8'h00;
        end

        // === SCORE (center) ===
        else if (show_score && is_score_region) begin
            draw_text = 1;
            current_digit = score_display % 10;

            r = 8'h00;
            g = 8'hFF;
            b = 8'h00;
        end
    end
endmodule
