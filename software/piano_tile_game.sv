module piano_tiles_game_hw (
    input  wire        clk,
    input  wire        reset,

    // Avalon-MM Slave Interface (Software writes to FPGA)
    input  wire        avs_write,
    input  wire        avs_read,
    input  wire [3:0]  avs_address,   // Address map
    input  wire [63:0] avs_writedata,
    output reg  [31:0] avs_readdata,

    // Outputs to VGA / Tile Engine
    output reg  [7:0]  tile_note,
    output reg  [7:0]  tile_velocity,
    output reg  [15:0] tile_duration,
    output reg  [31:0] tile_timestamp,
    output reg         tile_ready,

    // Outputs to Judge Engine
    output reg  [7:0]  user_note,
    output reg  [7:0]  user_velocity,
    output reg  [31:0] user_timestamp,
    output reg         user_input_ready
);

module piano_tiles_game_hw (
    ...
);

// Inputs from Avalon-MM writes
reg [7:0] tile_note, tile_velocity;
reg [15:0] tile_duration;
reg [31:0] tile_timestamp;

reg [7:0] user_note, user_velocity;
reg [31:0] user_timestamp;

// New internal registers
reg [31:0] tile_spawn_timestamp;
reg        tile_active; // 1 if the tile is currently falling
reg [31:0] game_timer_us; // game time in microseconds

reg [15:0] score;         // user score
reg [31:0] key_hold_start_time;  // when key was pressed
reg        key_is_being_held;    // 1 while key is held
reg        correct_note_detected; // 1 if correct note pressed
reg        tile_cleared;         // 1 if tile already judged

// Parameters
localparam TOLERANCE_US = 100_000; // ±100ms tolerance window

// Your always @(posedge clk) logic here
always @(posedge clk or posedge reset) begin
    if (reset) begin
        // reset all
    end else begin
        // 1. Game Timer increment
        game_timer_us <= game_timer_us + 100; // (if your clock is 10kHz = 100us per cycle, else adjust)

        // 2. New Song Packet Arrives
        if (tile_ready) begin
            tile_note <= incoming_note;
            tile_velocity <= incoming_velocity;
            tile_duration <= incoming_duration;
            tile_timestamp <= incoming_timestamp;
            tile_spawn_timestamp <= game_timer_us;
            tile_active <= 1;
            tile_cleared <= 0;
        end

        // 3. New User Input Arrives
        if (user_input_ready && !tile_cleared) begin
            if (tile_active) begin
                if ((user_note == tile_note) &&
                    (game_timer_us >= (tile_timestamp - TOLERANCE_US)) &&
                    (game_timer_us <= (tile_timestamp + TOLERANCE_US))) begin

                    correct_note_detected <= 1;
                    key_hold_start_time <= game_timer_us;
                    key_is_being_held <= 1;
                end
            end
        end

        // 4. Key Hold Logic
        if (key_is_being_held) begin
            if (user releases key) begin
                key_is_being_held <= 0;
                
                // How long did user hold?
                wire [31:0] held_duration_us = game_timer_us - key_hold_start_time;
                
                // Tile requires tile_duration milliseconds => convert to microseconds
                wire [31:0] required_duration_us = tile_duration * 1000;

                if (held_duration_us >= required_duration_us - 100_000) begin // Allow 100ms slack
                    score <= score + 1;
                end

                tile_cleared <= 1;
            end
        end

        // 5. Missed Tile (user didn't press)
        if (tile_active && (game_timer_us > (tile_timestamp + TOLERANCE_US)) && !tile_cleared) begin
            tile_cleared <= 1; // missed the note
        end
    end
end

endmodule

//has game logic adding a point if user clicked correct note and held
//send the midi song .bin to store it 
//send continously user input from keyboard
//compares the user input and midi .bin data to give points