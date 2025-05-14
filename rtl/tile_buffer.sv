module tile_buffer #(
    parameter MAX_TILES = 32
)(
    input  wire        clk,
    input  wire        reset,

    // Input from game logic
    input  wire        new_tile_valid,
    input  wire [7:0]  new_tile_note,
    input  wire [31:0] new_tile_timestamp,

    // Time from main clock
    input  wire [31:0] game_timer_us,

    // Outputs to vga_render (all tiles)
    output reg [7:0]   tiles_note     [MAX_TILES-1:0],
    output reg [31:0]  tiles_timestamp[MAX_TILES-1:0],
    output reg         tiles_active   [MAX_TILES-1:0]
);

    // Define tile struct
    typedef struct packed {
        logic        active;
        logic [7:0]  note;
        logic [31:0] timestamp;
    } Tile;

    // Tile buffer memory
    Tile tiles[MAX_TILES];

    integer i;

    // Insert + expire tiles
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < MAX_TILES; i = i + 1) begin
                tiles[i].active <= 0;
                tiles_note[i] <= 0;
                tiles_timestamp[i] <= 0;
                tiles_active[i] <= 0;
            end
        end else begin
            // Add new tile
            if (new_tile_valid) begin
                for (i = 0; i < MAX_TILES; i = i + 1) begin
                    if (!tiles[i].active) begin
                        tiles[i].note      <= new_tile_note;
                        tiles[i].timestamp <= new_tile_timestamp;
                        tiles[i].active    <= 1;
                        disable for;
                    end
                end
            end

            // Deactivate and mirror to outputs
            for (i = 0; i < MAX_TILES; i = i + 1) begin
                if (tiles[i].active && (game_timer_us > tiles[i].timestamp + 2_000_000)) begin
                    tiles[i].active <= 0;
                end

                // Drive VGA output arrays
                tiles_note[i]      <= tiles[i].note;
                tiles_timestamp[i] <= tiles[i].timestamp;
                tiles_active[i]    <= tiles[i].active;
            end
        end
    end

endmodule
