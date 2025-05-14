module vga_controller (
    input  wire        clk,       // 25 MHz pixel clock
    input  wire        reset,
    output wire        hs,        // horizontal sync
    output wire        vs,        // vertical sync
    output reg  [9:0]  x,         // current pixel x position
    output reg  [9:0]  y,         // current pixel y position
    output wire        blank      // high when inside visible area
);

    // VGA 640x480 @ 60Hz timing (25.175 MHz pixel clock)
    localparam H_VISIBLE   = 640;
    localparam H_FRONT_PORCH = 16;
    localparam H_SYNC_PULSE  = 96;
    localparam H_BACK_PORCH  = 48;
    localparam H_TOTAL     = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

    localparam V_VISIBLE   = 480;
    localparam V_FRONT_PORCH = 10;
    localparam V_SYNC_PULSE  = 2;
    localparam V_BACK_PORCH  = 33;
    localparam V_TOTAL     = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

    reg [9:0] h_count;
    reg [9:0] v_count;

    // Horizontal counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            h_count <= 0;
        else if (h_count == H_TOTAL - 1)
            h_count <= 0;
        else
            h_count <= h_count + 1;
    end

    // Vertical counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            v_count <= 0;
        else if (h_count == H_TOTAL - 1) begin
            if (v_count == V_TOTAL - 1)
                v_count <= 0;
            else
                v_count <= v_count + 1;
        end
    end

    // Current pixel coordinates
    always @(posedge clk) begin
        x <= (h_count < H_VISIBLE) ? h_count : 10'd0;
        y <= (v_count < V_VISIBLE) ? v_count : 10'd0;
    end

    // Horizontal sync pulse
    assign hs = ~(h_count >= H_VISIBLE + H_FRONT_PORCH &&
                  h_count <  H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE);

    // Vertical sync pulse
    assign vs = ~(v_count >= V_VISIBLE + V_FRONT_PORCH &&
                  v_count <  V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE);

    // Signal when inside visible screen area
    assign blank = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

endmodule
