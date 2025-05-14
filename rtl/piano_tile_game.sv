module piano_tiles_game_hw (
    input  wire        clk,
    input  wire        reset,

    // Avalon-MM Slave Interface
    input  wire        avs_write,
    input  wire        avs_read,
    input  wire [3:0]  avs_address,
    input  wire [63:0] avs_writedata,
    output reg  [31:0] avs_readdata,

    // VGA input/output
    input  wire [9:0]  vga_x,
    input  wire [9:0]  vga_y,
    output wire [7:0]  vga_r,
    output wire [7:0]  vga_g,
    output wire [7:0]  vga_b,

    // VGA overlay control outputs
    output reg  [31:0] countdown_display,
    output reg  [31:0] score_display,
    output reg         show_countdown,
    output reg         show_score,

    // Physical control inputs
    input  wire        key5,
    input  wire        key6,
    input  wire        key7,
    input  wire        song_loaded_done,

    // Song selection
    output reg  [3:0]  song_index,
    output reg         load_song_trigger,

    // Game state output
    output reg         game_started_hw
);

    // ----------------------
    // Internal state
    // ----------------------
    reg [31:0] game_timer_us;
    reg [31:0] countdown_timer_us;
    reg [31:0] score_display_timer_us;

    reg [7:0]  tile_note;
    reg [15:0] tile_duration;
    reg [31:0] tile_timestamp;
    reg        tile_ready;

    reg [7:0]  user_note;
    reg [7:0]  user_velocity;
    reg [31:0] user_timestamp;
    reg        user_input_ready;

    reg game_started;
    reg [31:0] score;

    localparam COUNTDOWN_US     = 5_000_000;
    localparam SCORE_DISPLAY_US = 5_000_000;

    // FSM state
    typedef enum logic [2:0] {
        STATE_MENU,
        STATE_LOADING,
        STATE_COUNTDOWN,
        STATE_PLAYING,
        STATE_SHOW_SCORE
    } GameState;

    GameState state;

    // Button edge detection
    reg key5_prev, key6_prev, key7_prev;
    wire key5_rise = key5 && !key5_prev;
    wire key6_rise = key6 && !key6_prev;
    wire key7_rise = key7 && !key7_prev;

    // ----------------------
    // Tile logic
    // ----------------------
    localparam MAX_TILES = 32;
    wire [7:0]  tiles_note     [MAX_TILES-1:0];
    wire [31:0] tiles_timestamp[MAX_TILES-1:0];
    wire        tiles_active   [MAX_TILES-1:0];

    tile_buffer #(.MAX_TILES(MAX_TILES)) tile_fifo (
        .clk(clk),
        .reset(reset),
        .new_tile_valid(tile_ready),
        .new_tile_note(tile_note),
        .new_tile_timestamp(tile_timestamp),
        .game_timer_us(game_timer_us),
        .tiles_note(tiles_note),
        .tiles_timestamp(tiles_timestamp),
        .tiles_active(tiles_active)
    );

    // ----------------------
    // VGA: Base tile rendering
    // ----------------------
    wire [7:0] renderer_r, renderer_g, renderer_b;

    vga_render #(.MAX_TILES(MAX_TILES)) renderer (
        .clk(clk),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .game_timer_us(game_timer_us),
        .tiles_note(tiles_note),
        .tiles_timestamp(tiles_timestamp),
        .tiles_active(tiles_active),
        .user_note(user_note),
        .user_input_ready(user_input_ready),
        .vga_r(renderer_r),
        .vga_g(renderer_g),
        .vga_b(renderer_b)
    );

    // ----------------------
    // VGA Overlay: Song, Countdown, Score
    // ----------------------
    wire overlay_draw;
    wire [7:0] overlay_r, overlay_g, overlay_b;

    vga_text_overlay text_overlay (
        .clk(clk),
        .vga_x(vga_x),
        .vga_y(vga_y),
        .song_index(song_index),
        .countdown_display(countdown_display),
        .show_countdown(show_countdown),
        .score_display(score_display),
        .show_score(show_score),
        .draw_text(overlay_draw),
        .r(overlay_r),
        .g(overlay_g),
        .b(overlay_b)
    );

    assign vga_r = overlay_draw ? overlay_r : renderer_r;
    assign vga_g = overlay_draw ? overlay_g : renderer_g;
    assign vga_b = overlay_draw ? overlay_b : renderer_b;

    // ----------------------
    // Game FSM
    // ----------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_MENU;
            song_index <= 0;
            load_song_trigger <= 0;
            countdown_timer_us <= 0;
            score_display_timer_us <= 0;
            game_timer_us <= 0;
            game_started <= 0;
            game_started_hw <= 0;
            score <= 0;

            tile_note <= 0;
            tile_timestamp <= 0;
            tile_duration <= 0;
            tile_ready <= 0;

            user_note <= 0;
            user_velocity <= 0;
            user_timestamp <= 0;
            user_input_ready <= 0;

            key5_prev <= 0;
            key6_prev <= 0;
            key7_prev <= 0;

            show_countdown <= 0;
            show_score <= 0;
            countdown_display <= 0;
            score_display <= 0;
        end else begin
            key5_prev <= key5;
            key6_prev <= key6;
            key7_prev <= key7;

            load_song_trigger <= 0;
            tile_ready <= 0;

            case (state)
                STATE_MENU: begin
                    game_started_hw <= 0;
                    show_score <= 0;
                    show_countdown <= 0;

                    if (key5_rise && song_index > 0)
                        song_index <= song_index - 1;
                    else if (key7_rise && song_index < 15)
                        song_index <= song_index + 1;

                    if (key6_rise) begin
                        load_song_trigger <= 1;
                        state <= STATE_LOADING;
                    end
                end

                STATE_LOADING: begin
                    show_score <= 0;
                    show_countdown <= 0;

                    if (song_loaded_done) begin
                        countdown_timer_us <= 0;
                        state <= STATE_COUNTDOWN;
                    end
                end

                STATE_COUNTDOWN: begin
                    countdown_timer_us <= countdown_timer_us + 100;
                    show_countdown <= 1;
                    show_score <= 0;
                    countdown_display <= (COUNTDOWN_US - countdown_timer_us) / 1_000_000;

                    if (countdown_timer_us >= COUNTDOWN_US) begin
                        game_started <= 1;
                        game_started_hw <= 1;
                        state <= STATE_PLAYING;
                        show_countdown <= 0;
                    end
                end

                STATE_PLAYING: begin
                    game_timer_us <= game_timer_us + 100;
                    show_countdown <= 0;
                    show_score <= 0;

                    if (avs_write && avs_address == 4'h0) begin
                        tile_note      <= avs_writedata[63:56];
                        tile_duration  <= avs_writedata[47:32];
                        tile_timestamp <= avs_writedata[31:0];
                        tile_ready     <= 1;
                    end

                    if (avs_write && avs_address == 4'h1) begin
                        user_note        <= avs_writedata[63:56];
                        user_velocity    <= avs_writedata[55:48];
                        user_timestamp   <= avs_writedata[31:0];
                        user_input_ready <= 1;
                    end else begin
                        user_input_ready <= 0;
                    end

                    if (avs_write && avs_address == 4'hF) begin
                        state <= STATE_SHOW_SCORE;
                        score_display <= score;
                        score_display_timer_us <= 0;
                        game_started_hw <= 0;
                        show_score <= 1;
                    end
                end

                STATE_SHOW_SCORE: begin
                    score_display_timer_us <= score_display_timer_us + 100;
                    show_score <= 1;
                    score_display <= score;

                    if (score_display_timer_us >= SCORE_DISPLAY_US) begin
                        state <= STATE_MENU;
                        game_timer_us <= 0;
                        score <= 0;
                        tile_ready <= 0;
                        show_score <= 0;
                        show_countdown <= 0;
                    end
                end
            endcase
        end
    end
endmodule


// has key detection lighting up virtual keyboard (have not tested)

// module fpga_intf(
//     input logic        clk,
//     input logic        reset,
//     input logic [7:0]  writedata,
//     input logic        write,
//     input              chipselect,
//     input logic [2:0]  address,
//     output logic [7:0] VGA_R, VGA_G, VGA_B,
//     output logic       VGA_CLK, VGA_HS, VGA_VS,
//                        VGA_BLANK_n,
//     output logic       VGA_SYNC_n
// );

//     logic [10:0] hcount;
//     logic [9:0]  vcount;
//     logic [7:0]  background_r, background_g, background_b;

//     // MIDI-related
//     logic [127:0] active_notes;
//     logic [63:0]  midi_input_packet;
//     logic [2:0]   midi_byte_count;
//     logic [7:0]   status, note, velocity;

//     // Falling tile control
//     logic [9:0] tile_y;
//     logic [3:0] tile_column;
//     logic [23:0] frame_counter;
//     int tile_width, tile_x_start, tile_x_end;

//     vga_counters counters(.clk50(clk), .*);

//     // === MAIN LOGIC ===
//     always_ff @(posedge clk) begin
//         if (reset) begin
//             background_r <= 8'h0;
//             background_g <= 8'h0;
//             background_b <= 8'h80;
//             tile_y       <= 0;
//             tile_column  <= 4'd4;
//             frame_counter <= 0;
//             midi_byte_count <= 0;
//             active_notes <= 128'd0;
//         end else begin
//             if (chipselect && write) begin
//                 case (address)
//                     3'h0: background_r <= writedata;
//                     3'h1: background_g <= writedata;
//                     3'h2: background_b <= writedata;
//                     3'h3: begin
//                         midi_input_packet <= {midi_input_packet[55:0], writedata};
//                         midi_byte_count <= midi_byte_count + 1;
//                         if (midi_byte_count == 7) begin
//                             status   <= midi_input_packet[39:32];
//                             note     <= midi_input_packet[31:24];
//                             velocity <= midi_input_packet[23:16];

//                             if ((midi_input_packet[39:32] & 8'hF0) == 8'h90 && midi_input_packet[23:16] > 0)
//                                 active_notes[midi_input_packet[31:24]] <= 1'b1;
//                             else if ((midi_input_packet[39:32] & 8'hF0) == 8'h80 || ((midi_input_packet[39:32] & 8'hF0) == 8'h90 && midi_input_packet[23:16] == 0))
//                                 active_notes[midi_input_packet[31:24]] <= 1'b0;

//                             midi_byte_count <= 0;
//                         end
//                     end
//                 endcase
//             end

//             frame_counter <= frame_counter + 1;
//             if (frame_counter >= 833_333) begin
//                 frame_counter <= 0;
//                 tile_y <= tile_y + 1;
//                 if (tile_y > 480) tile_y <= 0;
//             end
//         end
//     end

//     // === VGA DRAWING ===
//     always_comb begin
//         {VGA_R, VGA_G, VGA_B} = {background_r, background_g, background_b};

//         if (VGA_BLANK_n) begin
//             int key_top    = 360;
//             int key_bottom = 480;
//             int border     = 2;
//             int note_base  = 60;  // MIDI note for key 0

//             // --- Draw WHITE keys with MIDI RED highlight ---
//             if (vcount >= key_top && vcount < key_bottom) begin
//                 for (int k = 0; k < 15; k++) begin
//                     int x_start = 5 + k * 42;
//                     int x_end   = x_start + 42;

//                     if (hcount >= x_start && hcount < x_end) begin
//                         if ((hcount - x_start < border) || (x_end - hcount <= border) ||
//                             (vcount - key_top < border) || (key_bottom - vcount <= border))
//                             {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
//                         else if (active_notes[note_base + k])
//                             {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00}; // Red for active
//                         else
//                             {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF}; // White default
//                     end
//                 end
//             end

//             // --- Draw BLACK keys (unchanged) ---
//             if (vcount >= key_top && vcount < key_top + 60) begin
//                 if ((hcount >=  26 && hcount <  64) ||
//                     (hcount >=  68 && hcount < 106) ||
//                     (hcount >= 152 && hcount < 190) ||
//                     (hcount >= 194 && hcount < 232) ||
//                     (hcount >= 236 && hcount < 274) ||
//                     (hcount >= 320 && hcount < 358) ||
//                     (hcount >= 362 && hcount < 400) ||
//                     (hcount >= 446 && hcount < 484) ||
//                     (hcount >= 488 && hcount < 520) ||
//                     (hcount >= 530 && hcount < 568))
//                     {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
//             end

//             // --- Draw Falling Tile ---
//             tile_width = 42;
//             tile_x_start = 5 + tile_column * tile_width;
//             tile_x_end = tile_x_start + tile_width;

//             if (vcount >= tile_y && vcount < tile_y + 120) begin
//                 if (hcount >= tile_x_start && hcount < tile_x_end)
//                     {VGA_R, VGA_G, VGA_B} = {8'h00, 8'hFF, 8'hFF}; // Cyan tile
//             end
//         end
//     end
// endmodule
