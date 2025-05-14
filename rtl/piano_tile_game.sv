// // module piano_tiles_game_hw (
// //     input  wire        clk,
// //     input  wire        reset,

// //     // Avalon-MM Slave Interface
// //     input  wire        avs_write,
// //     input  wire        avs_read,
// //     input  wire [3:0]  avs_address,
// //     input  wire [63:0] avs_writedata,
// //     output reg  [31:0] avs_readdata,

// //     // VGA input/output
// //     input  wire [9:0]  vga_x,
// //     input  wire [9:0]  vga_y,
// //     output wire [7:0]  vga_r,
// //     output wire [7:0]  vga_g,
// //     output wire [7:0]  vga_b,

// //     // VGA overlay control outputs
// //     output reg  [31:0] countdown_display,
// //     output reg  [31:0] score_display,
// //     output reg         show_countdown,
// //     output reg         show_score,

// //     // Physical control inputs
// //     input  wire        key5,
// //     input  wire        key6,
// //     input  wire        key7,
// //     input  wire        song_loaded_done,

// //     // Song selection
// //     output reg  [3:0]  song_index,
// //     output reg         load_song_trigger,

// //     // Game state output
// //     output reg         game_started_hw
// // );

// //     // ----------------------
// //     // Internal state
// //     // ----------------------
// //     reg [31:0] game_timer_us;
// //     reg [31:0] countdown_timer_us;
// //     reg [31:0] score_display_timer_us;

// //     reg [7:0]  tile_note;
// //     reg [15:0] tile_duration;
// //     reg [31:0] tile_timestamp;
// //     reg        tile_ready;

// //     reg [7:0]  user_note;
// //     reg [7:0]  user_velocity;
// //     reg [31:0] user_timestamp;
// //     reg        user_input_ready;

// //     reg game_started;
// //     reg [31:0] score;

// //     localparam COUNTDOWN_US     = 5_000_000;
// //     localparam SCORE_DISPLAY_US = 5_000_000;

// //     // FSM state
// //     typedef enum logic [2:0] {
// //         STATE_MENU,
// //         STATE_LOADING,
// //         STATE_COUNTDOWN,
// //         STATE_PLAYING,
// //         STATE_SHOW_SCORE
// //     } GameState;

// //     GameState state;

// //     // Button edge detection
// //     reg key5_prev, key6_prev, key7_prev;
// //     wire key5_rise = key5 && !key5_prev;
// //     wire key6_rise = key6 && !key6_prev;
// //     wire key7_rise = key7 && !key7_prev;

// //     // ----------------------
// //     // Tile logic
// //     // ----------------------
// //     localparam MAX_TILES = 32;
// //     wire [7:0]  tiles_note     [MAX_TILES-1:0];
// //     wire [31:0] tiles_timestamp[MAX_TILES-1:0];
// //     wire        tiles_active   [MAX_TILES-1:0];

// //     tile_buffer #(.MAX_TILES(MAX_TILES)) tile_fifo (
// //         .clk(clk),
// //         .reset(reset),
// //         .new_tile_valid(tile_ready),
// //         .new_tile_note(tile_note),
// //         .new_tile_timestamp(tile_timestamp),
// //         .game_timer_us(game_timer_us),
// //         .tiles_note(tiles_note),
// //         .tiles_timestamp(tiles_timestamp),
// //         .tiles_active(tiles_active)
// //     );

// //     // ----------------------
// //     // VGA: Base tile rendering
// //     // ----------------------
// //     wire [7:0] renderer_r, renderer_g, renderer_b;

// //     vga_render #(.MAX_TILES(MAX_TILES)) renderer (
// //         .clk(clk),
// //         .vga_x(vga_x),
// //         .vga_y(vga_y),
// //         .game_timer_us(game_timer_us),
// //         .tiles_note(tiles_note),
// //         .tiles_timestamp(tiles_timestamp),
// //         .tiles_active(tiles_active),
// //         .user_note(user_note),
// //         .user_input_ready(user_input_ready),
// //         .vga_r(renderer_r),
// //         .vga_g(renderer_g),
// //         .vga_b(renderer_b)
// //     );

// //     // ----------------------
// //     // VGA Overlay: Song, Countdown, Score
// //     // ----------------------
// //     wire overlay_draw;
// //     wire [7:0] overlay_r, overlay_g, overlay_b;

// //     vga_text_overlay text_overlay (
// //         .clk(clk),
// //         .vga_x(vga_x),
// //         .vga_y(vga_y),
// //         .song_index(song_index),
// //         .countdown_display(countdown_display),
// //         .show_countdown(show_countdown),
// //         .score_display(score_display),
// //         .show_score(show_score),
// //         .draw_text(overlay_draw),
// //         .r(overlay_r),
// //         .g(overlay_g),
// //         .b(overlay_b)
// //     );

// //     assign vga_r = overlay_draw ? overlay_r : renderer_r;
// //     assign vga_g = overlay_draw ? overlay_g : renderer_g;
// //     assign vga_b = overlay_draw ? overlay_b : renderer_b;

// //     // ----------------------
// //     // Game FSM
// //     // ----------------------
// //     always @(posedge clk or posedge reset) begin
// //         if (reset) begin
// //             state <= STATE_MENU;
// //             song_index <= 0;
// //             load_song_trigger <= 0;
// //             countdown_timer_us <= 0;
// //             score_display_timer_us <= 0;
// //             game_timer_us <= 0;
// //             game_started <= 0;
// //             game_started_hw <= 0;
// //             score <= 0;

// //             tile_note <= 0;
// //             tile_timestamp <= 0;
// //             tile_duration <= 0;
// //             tile_ready <= 0;

// //             user_note <= 0;
// //             user_velocity <= 0;
// //             user_timestamp <= 0;
// //             user_input_ready <= 0;

// //             key5_prev <= 0;
// //             key6_prev <= 0;
// //             key7_prev <= 0;

// //             show_countdown <= 0;
// //             show_score <= 0;
// //             countdown_display <= 0;
// //             score_display <= 0;
// //         end else begin
// //             key5_prev <= key5;
// //             key6_prev <= key6;
// //             key7_prev <= key7;

// //             load_song_trigger <= 0;
// //             tile_ready <= 0;

// //             case (state)
// //                 STATE_MENU: begin
// //                     game_started_hw <= 0;
// //                     show_score <= 0;
// //                     show_countdown <= 0;

// //                     if (key5_rise && song_index > 0)
// //                         song_index <= song_index - 1;
// //                     else if (key7_rise && song_index < 15)
// //                         song_index <= song_index + 1;

// //                     if (key6_rise) begin
// //                         load_song_trigger <= 1;
// //                         state <= STATE_LOADING;
// //                     end
// //                 end

// //                 STATE_LOADING: begin
// //                     show_score <= 0;
// //                     show_countdown <= 0;

// //                     if (song_loaded_done) begin
// //                         countdown_timer_us <= 0;
// //                         state <= STATE_COUNTDOWN;
// //                     end
// //                 end

// //                 STATE_COUNTDOWN: begin
// //                     countdown_timer_us <= countdown_timer_us + 100;
// //                     show_countdown <= 1;
// //                     show_score <= 0;
// //                     countdown_display <= (COUNTDOWN_US - countdown_timer_us) / 1_000_000;

// //                     if (countdown_timer_us >= COUNTDOWN_US) begin
// //                         game_started <= 1;
// //                         game_started_hw <= 1;
// //                         state <= STATE_PLAYING;
// //                         show_countdown <= 0;
// //                     end
// //                 end

// //                 STATE_PLAYING: begin
// //                     game_timer_us <= game_timer_us + 100;
// //                     show_countdown <= 0;
// //                     show_score <= 0;

// //                     if (avs_write && avs_address == 4'h0) begin
// //                         tile_note      <= avs_writedata[63:56];
// //                         tile_duration  <= avs_writedata[47:32];
// //                         tile_timestamp <= avs_writedata[31:0];
// //                         tile_ready     <= 1;
// //                     end

// //                     if (avs_write && avs_address == 4'h1) begin
// //                         user_note        <= avs_writedata[63:56];
// //                         user_velocity    <= avs_writedata[55:48];
// //                         user_timestamp   <= avs_writedata[31:0];
// //                         user_input_ready <= 1;
// //                     end else begin
// //                         user_input_ready <= 0;
// //                     end

// //                     if (avs_write && avs_address == 4'hF) begin
// //                         state <= STATE_SHOW_SCORE;
// //                         score_display <= score;
// //                         score_display_timer_us <= 0;
// //                         game_started_hw <= 0;
// //                         show_score <= 1;
// //                     end
// //                 end

// //                 STATE_SHOW_SCORE: begin
// //                     score_display_timer_us <= score_display_timer_us + 100;
// //                     show_score <= 1;
// //                     score_display <= score;

// //                     if (score_display_timer_us >= SCORE_DISPLAY_US) begin
// //                         state <= STATE_MENU;
// //                         game_timer_us <= 0;
// //                         score <= 0;
// //                         tile_ready <= 0;
// //                         show_score <= 0;
// //                         show_countdown <= 0;
// //                     end
// //                 end
// //             endcase
// //         end
// //     end
// // endmodule


// // has key detection lighting up virtual keyboard (have not tested)

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

//     // MIDI tracking
//     logic [127:0] active_notes;
//     logic [63:0]  midi_input_packet;
//     logic [2:0]   midi_byte_count;

//     // Parsed MIDI fields
//     logic [7:0] status, note, velocity;

//     // Falling tile
//     logic [9:0] tile_y;
//     logic [3:0] tile_column;
//     logic [23:0] frame_counter;
//     int tile_width, tile_x_start, tile_x_end;

//     // Instantiate VGA counters
//     vga_counters counters(.clk50(clk), .*);

//     // === SEQUENTIAL LOGIC ===
//     always_ff @(posedge clk) begin
//         if (reset) begin
//             background_r <= 8'h00;
//             background_g <= 8'h00;
//             background_b <= 8'h80;
//             tile_y <= 0;
//             tile_column <= 4'd4;
//             frame_counter <= 0;
//             midi_byte_count <= 0;
//             midi_input_packet <= 0;
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

//     // === COMBINATIONAL VGA DRAWING ===
//     always_comb begin
//         {VGA_R, VGA_G, VGA_B} = {background_r, background_g, background_b};

//         if (VGA_BLANK_n) begin
//             int key_top    = 360;
//             int key_bottom = 480;
//             int border     = 2;
//             int note_base  = 60;  // MIDI note for white key 0

//             // ---------- WHITE KEYS ----------
//             if (vcount >= key_top && vcount < key_bottom) begin
//                 for (int k = 0; k < 15; k++) begin
//                     int local_x_start = 5 + k * 42;
//                     int local_x_end   = local_x_start + 42;

//                     if (hcount >= local_x_start && hcount < local_x_end) begin
//                         if ((hcount - local_x_start < border) || (local_x_end - hcount <= border) ||
//                             (vcount - key_top < border) || (key_bottom - vcount <= border)) begin
//                             {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
//                         end else if (active_notes[note_base + k]) begin
//                             {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00}; // red
//                         end else begin
//                             {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF}; // white
//                         end
//                     end
//                 end
//             end

//             // ---------- BLACK KEYS ----------
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
//                     (hcount >= 530 && hcount < 568)) begin
//                     {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
//                 end
//             end

//             // ---------- FALLING TILE ----------
//             tile_width = 42;
//             tile_x_start = 5 + tile_column * tile_width;
//             tile_x_end = tile_x_start + tile_width;

//             if (vcount >= tile_y && vcount < tile_y + 120) begin
//                 if (hcount >= tile_x_start && hcount < tile_x_end) begin
//                     {VGA_R, VGA_G, VGA_B} = {8'h00, 8'hFF, 8'hFF}; // cyan
//                 end
//             end
//         end
//     end
// endmodule



// module vga_counters(
//  input logic     clk50, reset,
//  output logic [10:0] hcount,  // hcount[10:1] is pixel column
//  output logic [9:0]  vcount,  // vcount[9:0] is pixel row
//  output logic     VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n);

// /*
//  * 640 X 480 VGA timing for a 50 MHz clock: one pixel every other cycle
//  *
//  * HCOUNT 1599 0             1279       1599 0
//  *             _______________              ________
//  * ___________|    Video      |____________|  Video
//  *
//  *
//  * |SYNC| BP |<-- HACTIVE -->|FP|SYNC| BP |<-- HACTIVE
//  *       _______________________      _____________
//  * |____|       VGA_HS          |____|
//  */
//    // Parameters for hcount
//    parameter HACTIVE      = 11'd 1280,
//              HFRONT_PORCH = 11'd 32,
//              HSYNC        = 11'd 192,
//              HBACK_PORCH  = 11'd 96,  
//              HTOTAL       = HACTIVE + HFRONT_PORCH + HSYNC +
//                             HBACK_PORCH; // 1600
   
//    // Parameters for vcount
//    parameter VACTIVE      = 10'd 480,
//              VFRONT_PORCH = 10'd 10,
//              VSYNC        = 10'd 2,
//              VBACK_PORCH  = 10'd 33,
//              VTOTAL       = VACTIVE + VFRONT_PORCH + VSYNC +
//                             VBACK_PORCH; // 525

//    logic endOfLine;
   
//    always_ff @(posedge clk50 or posedge reset)
//      if (reset)          hcount <= 0;
//      else if (endOfLine) hcount <= 0;
//      else           hcount <= hcount + 11'd 1;

//    assign endOfLine = hcount == HTOTAL - 1;
       
//    logic endOfField;
   
//    always_ff @(posedge clk50 or posedge reset)
//      if (reset)          vcount <= 0;
//      else if (endOfLine)
//        if (endOfField)   vcount <= 0;
//        else              vcount <= vcount + 10'd 1;

//    assign endOfField = vcount == VTOTAL - 1;

//    // Horizontal sync: from 0x520 to 0x5DF (0x57F)
//    // 101 0010 0000 to 101 1101 1111
//    assign VGA_HS = !( (hcount[10:8] == 3'b101) &
//      !(hcount[7:5] == 3'b111));
//    assign VGA_VS = !( vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2);

//    assign VGA_SYNC_n = 1'b0; // For putting sync on the green signal; unused
   
//    // Horizontal active: 0 to 1279     Vertical active: 0 to 479
//    // 101 0000 0000  1280       01 1110 0000  480
//    // 110 0011 1111  1599       10 0000 1100  524
//    assign VGA_BLANK_n = !( hcount[10] & (hcount[9] | hcount[8]) ) &
// !( vcount[9] | (vcount[8:5] == 4'b1111) );

//    /* VGA_CLK is 25 MHz
//     *             __    __    __
//     * clk50    __|  |__|  |__|
//     *        
//     *             _____       __
//     * hcount[0]__|     |_____|
//     */
//    assign VGA_CLK = hcount[0]; // 25 MHz clock: rising edge sensitive
   
// endmodule










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
    vga_counters counters(.clk50(clk), .*);

    logic [7:0] background_r, background_g, background_b;

    // ---------- Register Handling ----------
    logic [15:0] bpm;
    logic [63:0] midi_packet;
    logic [31:0] packet_high, packet_low;
    logic        midi_write;
    logic [24:0] active_keys; // active_keys[0] = note 0x60, ..., active_keys[24] = note 0x48


    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < TILE_COUNT; i++) tile_buffer[i].active <= 0;
            active_keys <= 25'd0;
        end else if (midi_write) begin
            note = midi_packet[63:56];
            velocity = midi_packet[55:48];
            col = note - 8'd60;

            // Update active_keys bitmap based on note and velocity
            if (note >= 8'h48 && note <= 8'h60) begin
                int index = 8'h60 - note;
                if ((midi_packet[63:60] == 4'h9) && (velocity > 0))
                    active_keys[index] <= 1'b1;
                else
                    active_keys[index] <= 1'b0;
            end

            for (i = 0; i < TILE_COUNT; i++) begin
                if (!tile_buffer[i].active) begin
                    tile_buffer[i].column     <= col;
                    tile_buffer[i].spawn_time <= time_ms;
                    tile_buffer[i].color      <= velocity;
                    tile_buffer[i].active     <= 1;
                    break;
                end
            end
        end
    end


    // ---------- Timer (ms) ----------
    logic [31:0] time_ms;
    logic [23:0] tick_counter;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            time_ms <= 0;
            tick_counter <= 0;
        end else begin
            tick_counter <= tick_counter + 1;
            if (tick_counter == 50000) begin // ~1 ms at 50 MHz
                time_ms <= time_ms + 1;
                tick_counter <= 0;
            end
        end
    end

    // ---------- Tile Storage ----------
    parameter TILE_COUNT = 8;
    typedef struct packed {
        logic [3:0] column;
        logic [31:0] spawn_time;
        logic [7:0] color;
        logic active;
    } tile_t;

    tile_t tile_buffer[TILE_COUNT];

    integer i;
    logic [7:0] note, velocity;
    logic [3:0] col;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < TILE_COUNT; i++) tile_buffer[i].active <= 0;
        end else if (midi_write) begin
            note = midi_packet[63:56];
            velocity = midi_packet[55:48];
            col = note - 8'd60;

            for (i = 0; i < TILE_COUNT; i++) begin
                if (!tile_buffer[i].active) begin
                    tile_buffer[i].column     <= col;
                    tile_buffer[i].spawn_time <= time_ms;
                    tile_buffer[i].color      <= velocity;
                    tile_buffer[i].active     <= 1;
                    break;
                end
            end
        end
    end

    // ---------- Falling tile speed (pixels/ms) ----------
    int speed;
    always_comb begin
        speed = 2 * bpm / 120;
    end
   
    // ---------- VGA Rendering ----------
    always_comb begin
        {VGA_R, VGA_G, VGA_B} = {background_r, background_g, background_b};

        if (VGA_BLANK_n) begin
            int key_top    = 360;
            int key_bottom = 480;
            int border     = 2;
            int x_start, x_end, y_real, y_start, y_end;
            // ---------- WHITE KEYS WITH OUTLINES ----------
            if (vcount >= key_top && vcount < key_bottom) begin
                if (hcount >=   5 && hcount <  47) begin
                    if ((hcount - 5 < border) || (47 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 47 && hcount < 89) begin
                    if ((hcount - 47 < border) || (89 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 89 && hcount < 131) begin
                    if ((hcount - 89 < border) || (131 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 131 && hcount < 173) begin
                    if ((hcount - 131 < border) || (173 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 173 && hcount < 215) begin
                    if ((hcount - 173 < border) || (215 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 215 && hcount < 257) begin
                    if ((hcount - 215 < border) || (257 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 257 && hcount < 299) begin
                    if ((hcount - 257 < border) || (299 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 299 && hcount < 341) begin
                    if ((hcount - 299 < border) || (341 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 341 && hcount < 383) begin
                    if ((hcount - 341 < border) || (383 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 383 && hcount < 425) begin
                    if ((hcount - 383 < border) || (425 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 425 && hcount < 467) begin
                    if ((hcount - 425 < border) || (467 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 467 && hcount < 509) begin
                    if ((hcount - 467 < border) || (509 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 509 && hcount < 551) begin
                    if ((hcount - 509 < border) || (551 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 551 && hcount < 593) begin
                    if ((hcount - 551 < border) || (593 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end else if (hcount >= 593 && hcount < 635) begin
                    if ((hcount - 593 < border) || (635 - hcount <= border) || (vcount - key_top < border) || (key_bottom - vcount <= border))
                        {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                    else begin
                        int key_index = (hcount - 5) / 42;
                        if (key_index >= 0 && key_index < 25 && active_keys[key_index])
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'h00, 8'h00};  // red if active
                        else
                            {VGA_R, VGA_G, VGA_B} = {8'hFF, 8'hFF, 8'hFF};  // white if inactive
                    end
                end
            end

            // ---------- BLACK KEYS ----------
            if (vcount >= key_top && vcount < key_top + 60) begin
                if ((hcount >=  26 && hcount <  64) ||  (hcount >=  68 && hcount <  106) ||
                    (hcount >= 152 && hcount < 190) || (hcount >= 194 && hcount < 232) ||
                    (hcount >= 236 && hcount < 274) || (hcount >= 320 && hcount < 358) ||
                    (hcount >= 362 && hcount < 400) || (hcount >= 446 && hcount < 484) ||
                    (hcount >= 488 && hcount < 526) || (hcount >= 530 && hcount < 568)) begin
                    {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
                end
            end

            // ---------- Falling Tiles ----------
            for (int t = 0; t < TILE_COUNT; t++) begin
                if (tile_buffer[t].active) begin
                    x_start = 5 + tile_buffer[t].column * 42;
                    x_end = x_start + 42;
                    y_real = (time_ms - tile_buffer[t].spawn_time) * speed;
                    y_start = int'(y_real);
                    y_end = y_start + 20;

                    if (vcount >= y_start && vcount < y_end &&
                        hcount >= x_start && hcount < x_end) begin
                        {VGA_R, VGA_G, VGA_B} = {tile_buffer[t].color, 8'h00, 8'hFF};
                    end
                end
            end
        end
    end

endmodule


module vga_counters(
 input logic     clk50, reset,
 output logic [10:0] hcount,  // hcount[10:1] is pixel column
 output logic [9:0]  vcount,  // vcount[9:0] is pixel row
 output logic     VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n);

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
     else           hcount <= hcount + 11'd 1;

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
   // 101 0000 0000  1280       01 1110 0000  480
   // 110 0011 1111  1599       10 0000 1100  524
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
