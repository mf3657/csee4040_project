module piano_tiles_game_hw (
    input  wire        clk,
    input  wire        reset,

    // Avalon-MM Slave Interface
    input  wire        avs_write,
    input  wire        avs_read,
    input  wire [3:0]  avs_address,
    input  wire [63:0] avs_writedata,
    output reg  [31:0] avs_readdata,

    // VGA output
    output reg  [7:0]  tile_note,
    output reg  [7:0]  tile_velocity,
    output reg  [15:0] tile_duration,
    output reg  [31:0] tile_timestamp,
    output reg         tile_ready,

    // User input
    output reg  [7:0]  user_note,
    output reg  [7:0]  user_velocity,
    output reg  [31:0] user_timestamp,
    output reg         user_input_ready
);

    // --- Internal Game State ---
    reg [31:0] game_timer_us;

    reg [7:0]  current_note;
    reg [7:0]  current_velocity;
    reg [15:0] current_duration;
    reg [31:0] current_timestamp;
    reg [31:0] tile_spawn_timestamp;

    reg tile_active;
    reg tile_cleared;

    reg [31:0] score;

    reg        key_held;
    reg [31:0] key_press_time;
    reg [31:0] key_release_time;

    wire [31:0] required_duration_us = current_duration * 1000;
    wire [31:0] held_duration_us = key_release_time - key_press_time;

    localparam TOLERANCE_US = 100_000; // ±100ms

    // --- Main Game Logic ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // Reset all game state
            game_timer_us <= 0;
            tile_active <= 0;
            tile_cleared <= 0;
            tile_ready <= 0;
            score <= 0;
            key_held <= 0;
        end else begin
            // Game timer ticks every clock (assumes 100us resolution)
            game_timer_us <= game_timer_us + 100;

            // --- TILE ARRIVAL (Simulated by software write) ---
            if (avs_write && avs_address == 4'h0) begin
                current_note      <= avs_writedata[63:56];
                current_velocity  <= avs_writedata[55:48];
                current_duration  <= avs_writedata[47:32];
                current_timestamp <= avs_writedata[31:0];

                tile_note      <= avs_writedata[63:56];
                tile_velocity  <= avs_writedata[55:48];
                tile_duration  <= avs_writedata[47:32];
                tile_timestamp <= avs_writedata[31:0];
                tile_spawn_timestamp <= game_timer_us;

                tile_active <= 1;
                tile_cleared <= 0;
                tile_ready <= 1;
            end else begin
                tile_ready <= 0;
            end

            // --- USER INPUT (key press) ---
            if (avs_write && avs_address == 4'h1) begin
                user_note <= avs_writedata[63:56];
                user_velocity <= avs_writedata[55:48];
                user_timestamp <= avs_writedata[31:0];
                user_input_ready <= 1;

                if (tile_active && !tile_cleared &&
                    (avs_writedata[63:56] == current_note) &&
                    (game_timer_us >= current_timestamp - TOLERANCE_US) &&
                    (game_timer_us <= current_timestamp + TOLERANCE_US)) begin

                    score <= score + 1; // hit = +1
                    tile_cleared <= 1;

                    key_held <= 1;
                    key_press_time <= game_timer_us;
                end
            end else begin
                user_input_ready <= 0;
            end

            // --- KEY RELEASE (simulate via special command) ---
            if (avs_write && avs_address == 4'h2) begin
                key_release_time <= game_timer_us;

                if (key_held) begin
                    key_held <= 0;

                    if (held_duration_us >= (required_duration_us - 100_000)) begin
                        score <= score + 5; // held long enough = +5
                    end
                end
            end

            // --- MISS CHECK ---
            if (tile_active && !tile_cleared && (game_timer_us > current_timestamp + TOLERANCE_US)) begin
                tile_cleared <= 1; // too late
            end
        end
    end

endmodule
