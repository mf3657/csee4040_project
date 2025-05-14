module piano_tiles_game_hw (
    input  wire        clk,
    input  wire        reset,

    // Avalon-MM Slave Interface
    input  wire        avs_write,
    input  wire        avs_read,
    input  wire [3:0]  avs_address,
    input  wire [63:0] avs_writedata,
    output reg  [31:0] avs_readdata,

    // VGA output for tile display
    output reg  [7:0]  tile_note,
    output reg  [7:0]  tile_velocity,
    output reg  [15:0] tile_duration,
    output reg  [31:0] tile_timestamp,
    output reg         tile_ready,

    // VGA output for countdown and score
    output reg  [31:0] countdown_display,
    output reg  [31:0] score_display,
    output reg         show_countdown,
    output reg         show_score,

    // User input tracking
    output reg  [7:0]  user_note,
    output reg  [7:0]  user_velocity,
    output reg  [31:0] user_timestamp,
    output reg         user_input_ready,

    // Physical control inputs mapped to DE1-SoC keys
    input  wire        key5,   // ← previous song
    input  wire        key6,   // ← start game
    input  wire        key7,   // ← next song
    input  wire        song_loaded_done,

    // Song selection interface
    output reg  [3:0]  song_index,
    output reg         load_song_trigger,

    // Game state signal
    output reg         game_started_hw
);

    // --- Internal State ---
    reg [31:0] game_timer_us;
    reg [31:0] countdown_timer_us;
    reg [31:0] score_display_timer_us;

    reg [7:0]  current_note;
    reg [7:0]  current_velocity;
    reg [15:0] current_duration;
    reg [31:0] current_timestamp;
    reg [31:0] tile_spawn_timestamp;

    reg tile_active;
    reg tile_cleared;
    reg key_held;
    reg [31:0] key_press_time;
    reg [31:0] key_release_time;
    reg [31:0] score;

    wire [31:0] required_duration_us = current_duration * 1000;
    wire [31:0] held_duration_us = key_release_time - key_press_time;

    localparam TOLERANCE_US     = 100_000;
    localparam COUNTDOWN_US     = 5_000_000;
    localparam SCORE_DISPLAY_US = 5_000_000;

    reg game_started;

    // --- FSM Definitions ---
    typedef enum logic [2:0] {
        STATE_MENU,
        STATE_LOADING,
        STATE_COUNTDOWN,
        STATE_PLAYING,
        STATE_SHOW_SCORE
    } GameState;

    GameState state;

    // Input edge detection
    reg key5_prev, key6_prev, key7_prev;
    wire key5_rise = key5 && !key5_prev;
    wire key6_rise = key6 && !key6_prev;
    wire key7_rise = key7 && !key7_prev;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all states and outputs
            state <= STATE_MENU;
            song_index <= 0;
            load_song_trigger <= 0;
            countdown_timer_us <= 0;
            score_display_timer_us <= 0;
            game_timer_us <= 0;
            game_started <= 0;
            game_started_hw <= 0;

            tile_note <= 0;
            tile_velocity <= 0;
            tile_duration <= 0;
            tile_timestamp <= 0;
            tile_ready <= 0;

            user_note <= 0;
            user_velocity <= 0;
            user_timestamp <= 0;
            user_input_ready <= 0;

            key_held <= 0;
            score <= 0;
            tile_active <= 0;
            tile_cleared <= 0;

            key5_prev <= 0;
            key6_prev <= 0;
            key7_prev <= 0;

            show_countdown <= 0;
            show_score <= 0;
            countdown_display <= 0;
            score_display <= 0;
        end else begin
            // Update edge detection state
            key5_prev <= key5;
            key6_prev <= key6;
            key7_prev <= key7;

            load_song_trigger <= 0; // default

            case (state)
                // -------------------------------
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

                // -------------------------------
                STATE_LOADING: begin
                    show_score <= 0;
                    show_countdown <= 0;

                    if (song_loaded_done) begin
                        countdown_timer_us <= 0;
                        state <= STATE_COUNTDOWN;
                    end
                end

                // -------------------------------
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

                // -------------------------------
                STATE_PLAYING: begin
                    game_timer_us <= game_timer_us + 100;
                    show_countdown <= 0;
                    show_score <= 0;

                    // End of song signal
                    if (avs_write && avs_address == 4'hF) begin
                        state <= STATE_SHOW_SCORE;
                        game_started_hw <= 0;
                        score_display_timer_us <= 0;
                        show_score <= 1;
                        score_display <= score;
                    end

                    // Tile arrival
                    if (avs_write && avs_address == 4'h0) begin
                        current_note      <= avs_writedata[63:56];
                        current_velocity  <= avs_writedata[55:48];
                        current_duration  <= avs_writedata[47:32];
                        current_timestamp <= avs_writedata[31:0];

                        tile_note         <= avs_writedata[63:56];
                        tile_velocity     <= avs_writedata[55:48];
                        tile_duration     <= avs_writedata[47:32];
                        tile_timestamp    <= avs_writedata[31:0];
                        tile_spawn_timestamp <= game_timer_us;

                        tile_active <= 1;
                        tile_cleared <= 0;
                        tile_ready <= 1;
                    end else begin
                        tile_ready <= 0;
                    end

                    // Key press
                    if (avs_write && avs_address == 4'h1) begin
                        user_note      <= avs_writedata[63:56];
                        user_velocity  <= avs_writedata[55:48];
                        user_timestamp <= avs_writedata[31:0];
                        user_input_ready <= 1;

                        if (tile_active && !tile_cleared &&
                            (avs_writedata[63:56] == current_note) &&
                            (game_timer_us >= current_timestamp - TOLERANCE_US) &&
                            (game_timer_us <= current_timestamp + TOLERANCE_US)) begin
                            score <= score + 1;
                            tile_cleared <= 1;
                            key_held <= 1;
                            key_press_time <= game_timer_us;
                        end
                    end else begin
                        user_input_ready <= 0;
                    end

                    // Key release
                    if (avs_write && avs_address == 4'h2) begin
                        key_release_time <= game_timer_us;
                        if (key_held) begin
                            key_held <= 0;
                            if (held_duration_us >= (required_duration_us - 100_000))
                                score <= score + 5;
                        end
                    end

                    // Tile miss check
                    if (tile_active && !tile_cleared &&
                        (game_timer_us > current_timestamp + TOLERANCE_US)) begin
                        tile_cleared <= 1;
                    end
                end

                // -------------------------------
                STATE_SHOW_SCORE: begin
                    score_display_timer_us <= score_display_timer_us + 100;
                    show_score <= 1;
                    score_display <= score;

                    if (score_display_timer_us >= SCORE_DISPLAY_US) begin
                        state <= STATE_MENU;
                        score <= 0;
                        game_timer_us <= 0;
                        countdown_timer_us <= 0;
                        tile_note <= 0;
                        tile_velocity <= 0;
                        tile_duration <= 0;
                        tile_timestamp <= 0;
                        tile_ready <= 0;
                        user_note <= 0;
                        user_velocity <= 0;
                        user_timestamp <= 0;
                        user_input_ready <= 0;
                        key_held <= 0;
                        tile_active <= 0;
                        tile_cleared <= 0;
                        game_started <= 0;
                        show_score <= 0;
                        show_countdown <= 0;
                    end
                end
            endcase
        end
    end
endmodule
