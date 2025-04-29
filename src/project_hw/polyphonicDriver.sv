// -----------------------------------------------------------------------------
// Poly‑voice wavetable driver for Cyclone‑V / MAX‑10 FPGA
// -----------------------------------------------------------------------------
// *  N simultaneous voices (parameterisable)
// *  Single shared BRAM that holds one or more root samples (16‑bit mono)
// *  16.16 fixed‑point phase accumulator per voice
// *  8‑bit unsigned gain per voice (velocity)
// *  32‑bit mix‑bus with simple soft‑clip before truncation to 24‑bit codec width
// *  Back‑compatible STORE state machine for loading PCM data over Avalon‑MM
// *  New VOICE_WRITE register on Avalon to set voice {active, step, gain}
// -----------------------------------------------------------------------------
// Control register map (chipselect asserted, write=1)
//   address == 0 : PCM sample store stream   (unchanged)
//   address == 1 : VOICE_WRITE  {WE[31],voice_id[30:27],active[26],step[25:10],gain[9:2]}
//                  Bits[1:0] reserved
// -----------------------------------------------------------------------------

module poly_driver_interface #(
    parameter MEM_DEPTH   = 48000,
    parameter NUM_VOICES  = 8               // 8‑voice polyphony
) (
    // -------------------------------------------------------------------------
    // System interface
    input  logic        clk,
    input  logic        reset,

    // Avalon‑MM interface
    input  logic [31:0] writedata,
    input  logic        write,
    input  logic        chipselect,
    input  logic        address,          // 0=PCM stream  1=VOICE_WRITE

    // Codec sampling interface
    input  logic        advance,          // 1‑>0 edge: time to generate next sample
    output logic [23:0] leftSample,
    output logic [23:0] rightSample
);

// -----------------------------------------------------------------------------
// Internal sample RAM (shared by all voices)
// -----------------------------------------------------------------------------
logic [15:0] mem_out;
logic [15:0] w_r_address;
logic        mem_we;

ram #(.MEM_DEPTH(MEM_DEPTH)) audio_ram (
    .clk   (clk),
    .we    (mem_we),
    .addr  (w_r_address),
    .d_in  (writedata[15:0]),
    .d_out (mem_out)
);

// -----------------------------------------------------------------------------
// Voice state registers
// -----------------------------------------------------------------------------
typedef struct packed {
    logic [31:0] phase;      // 16.16 accumulator
    logic [31:0] step;       // 16.16 rate
    logic  [7:0] gain;       // linear gain / velocity
    logic        active;     // 1 = sounding
} voice_t;

voice_t voices   [NUM_VOICES];
logic   [3:0] voice_write_id;    // from Avalon packet

// -----------------------------------------------------------------------------
// Avalon write decode
// -----------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if (reset) begin
        foreach (voices[v]) begin
            voices[v].active <= 1'b0;
            voices[v].step   <= 32'h0001_0000; // unison
            voices[v].gain   <= 8'd0;
            voices[v].phase  <= 32'd0;
        end
    end else if (write && chipselect && address==1'b1) begin // VOICE_WRITE word
        if (writedata[31]) begin // WE bit
            voice_write_id                 <= writedata[30:27];
            voices[writedata[30:27]].active<= writedata[26];
            voices[writedata[30:27]].step  <= {writedata[25:10], 10'b0}; // align to 16.16
            voices[writedata[30:27]].gain  <= writedata[9:2];
            if (writedata[26]) // note‑on → reset phase
                voices[writedata[30:27]].phase <= 32'd0;
        end
    end
end

// -----------------------------------------------------------------------------
// Original STORE state machine — unchanged except that sample writes occur only
// when address==0.
// -----------------------------------------------------------------------------
enum logic [2:0] {RST, WAIT_STORE, STORE, WAIT_READ} state;
logic [31:0] fract_index; // legacy pointer for load‑time; unused in poly render

always_ff @(posedge clk) begin
    if (reset) begin
        w_r_address <= 16'd0;
        state       <= RST;
        mem_we      <= 1'b0;
    end else case (state)
        RST: begin
            w_r_address <= 16'd0;
            mem_we      <= 1'b0;
            state       <= WAIT_STORE;
        end
        WAIT_STORE: begin
            if (write && chipselect && address==1'b0) begin
                mem_we <= 1'b1;
                state  <= STORE;
            end else mem_we <= 1'b0;
        end
        STORE: begin
            if (!write) begin // falling edge terminates one word
                w_r_address <= w_r_address + 16'd1;
                mem_we      <= 1'b0;
                if (w_r_address == MEM_DEPTH-1) begin
                    w_r_address <= 16'd0;
                    state       <= WAIT_READ;
                end else state <= WAIT_STORE;
            end
        end
        WAIT_READ: begin
            // idle until playback hardware uses RAM (poly voices below)
        end
    endcase
end

// -----------------------------------------------------------------------------
// Polyphonic render: read one voice per cycle while advance==0.
// We assume 50‑MHz sysclk → plenty cycles per audio sample.
// -----------------------------------------------------------------------------
logic [4:0] render_idx;      // counts voices being processed this sample
logic [31:0] mix_accum;      // 32‑bit signed accumulator
logic [15:0] sample_latch;

always_ff @(posedge clk) begin
    if (reset) begin
        render_idx  <= 0;
        mix_accum   <= 32'sd0;
    end else begin
        // When advance falls low → start a new output sample period
        if (advance == 1'b0 && render_idx == 0) begin
            mix_accum <= 32'sd0; // clear accumulator
        end

        // Process one voice per system clock when advance == 0
        if (advance == 1'b0 && render_idx < NUM_VOICES) begin
            voice_t v = voices[render_idx];
            if (v.active) begin
                // BRAM read – synchronous: address at t0, data at t1
                w_r_address <= v.phase[31:16];
                sample_latch <= mem_out; // previous cycle’s sample
                // Multiply by gain (simple shift‑multiply: gain/256)
                mix_accum <= mix_accum + ( $signed({1'b0,sample_latch}) * v.gain );
                // advance phase
                voices[render_idx].phase <= v.phase + v.step;
            end
            render_idx <= render_idx + 1'b1;
        end else if (render_idx == NUM_VOICES) begin
            render_idx <= 0; // done this audio frame
        end
    end
end

// -----------------------------------------------------------------------------
// Output clipping & formatting to 24‑bit
// mix_accum is 16‑bit sample × 8‑bit gain × up to NUM_VOICES.
// Use upper bits, soft‑clip by saturation.
// -----------------------------------------------------------------------------
logic signed [23:0] mixed24;

always_comb begin
    // crude saturation
    if (mix_accum > 24'sd8388607)      mixed24 = 24'sd8388607;
    else if (mix_accum < -24'sd8388608) mixed24 = -24'sd8388608;
    else                                mixed24 = mix_accum[23:0];
end

assign leftSample  = mixed24;
assign rightSample = mixed24;

endmodule

// ----------------------------------------------------------------------------
// Simple dual‑port RAM identical to original design
// ----------------------------------------------------------------------------
module ram #(parameter MEM_DEPTH = 8192) (
    input  logic        clk,
    input  logic        we,
    input  logic [15:0] addr,
    input  logic [15:0] d_in,
    output logic [15:0] d_out
);
    logic [15:0] mem [0:MEM_DEPTH-1];
    always_ff @(posedge clk) begin
        if (we) begin
            mem[addr] <= d_in;
            d_out     <= d_in;
        end else begin
            d_out     <= mem[addr];
        end
    end
endmodule
