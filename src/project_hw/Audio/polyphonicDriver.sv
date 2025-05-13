//=================================================================================
// Polyphonic Module
//=================================================================================


module polyphonicDriver #(
    parameter SAMPLE_LEN = 48000,
    parameter NUM_VOICES = 8
)(
    input  logic        clk,
    input  logic        reset,

    // Avalon-MM interface
    input  logic [1:0]  address,
    input  logic        write,
    input  logic        chipselect,
    input  logic [31:0] writedata,

    // Audio interface
    input  logic        advance,
    output logic [23:0] leftSample,
    output logic [23:0] rightSample
);

    logic [7:0] note;
    logic cmd;

    //=====================================================
    // Sample Memories (sample1 = C3, sample2 = C4)
    //=====================================================
    logic [15:0] sample1_mem [0:SAMPLE_LEN-1];
    logic [15:0] sample2_mem [0:SAMPLE_LEN-1];
    logic [15:0] sample1_write_ptr, sample2_write_ptr;

    //=====================================================
    // Voice State
    //=====================================================
    typedef struct packed {
        logic        active;
        logic [7:0]  note;
        logic        sample_sel;
        logic [31:0] index;
        logic [31:0] step;
    } voice_t;

    voice_t voices[NUM_VOICES];
    logic signed [23:0] voice_out[NUM_VOICES];

    //=====================================================
    // Pitch Step Lookup
    //=====================================================
    function automatic logic [31:0] pitch_step(input int semitone);
        case (semitone)
            0:   return 32'h00010000;
            1:   return 32'h00010F3B;
            2:   return 32'h00011F5C;
            3:   return 32'h0001306F;
            4:   return 32'h00014289;
            5:   return 32'h000155B5;
            6:   return 32'h00016A09;
            7:   return 32'h00017F91;
            8:   return 32'h00019660;
            9:   return 32'h0001AE8A;
            10:  return 32'h0001C824;
            11:  return 32'h0001E3C3;
            default: return 32'h00010000;
        endcase
    endfunction

    logic signed [23:0] mix;
    int idx0;
    int idx1;
    int idx2;
    int idx3;
    int idx4;
    int idx5;
    int idx6;
    int idx7;

    logic [15:0] s0;
    logic [15:0] s1;
    logic [15:0] s2;
    logic [15:0] s3;
    logic [15:0] s4;
    logic [15:0] s5;
    logic [15:0] s6;
    logic [15:0] s7;

    //=====================================================
    // Command Handling
    //=====================================================
    always_ff @(posedge clk) begin
    if (reset) begin
        leftSample <= 24'd0;
        rightSample <= 24'd0;
        sample1_write_ptr <= 0;
        sample2_write_ptr <= 0;
        voices[0].active <= 0;
        voices[1].active <= 0;
        voices[2].active <= 0;
        voices[3].active <= 0;
        voices[4].active <= 0;
        voices[5].active <= 0;
        voices[6].active <= 0;
        voices[7].active <= 0;
    end else if (write && chipselect) begin
        case (address)
            2'd0: begin // Note Command
                note <= writedata[7:0];
                cmd  <= writedata[8];
                if (cmd) begin // Note On
                    if (!voices[0].active) begin
                        voices[0].active     <= 1;
                        voices[0].note       <= note;
                        voices[0].sample_sel <= (note < 60) ? 0 : 1;
                        voices[0].index      <= 0;
                        voices[0].step       <= pitch_step((note < 60) ? (note - 48) : (note - 60));
                    end else if (!voices[1].active) begin
                        voices[1].active     <= 1;
                        voices[1].note       <= note;
                        voices[1].sample_sel <= (note < 60) ? 0 : 1;
                        voices[1].index      <= 0;
                        voices[1].step       <= pitch_step((note < 60) ? (note - 48) : (note - 60));
                    end else if (!voices[2].active) begin
                        voices[2].active     <= 1;
                        voices[2].note       <= note;
                        voices[2].sample_sel <= (note < 60) ? 0 : 1;
                        voices[2].index      <= 0;
                        voices[2].step       <= pitch_step((note < 60) ? (note - 48) : (note - 60));
                    end else if (!voices[3].active) begin
                        voices[3].active     <= 1;
                        voices[3].note       <= note;
                        voices[3].sample_sel <= (note < 60) ? 0 : 1;
                        voices[3].index      <= 0;
                        voices[3].step       <= pitch_step((note < 60) ? (note - 48) : (note - 60));
                    end else if (!voices[4].active) begin
                        voices[4].active     <= 1;
                        voices[4].note       <= note;
                        voices[4].sample_sel <= (note < 60) ? 0 : 1;
                        voices[4].index      <= 0;
                        voices[4].step       <= pitch_step((note < 60) ? (note - 48) : (note - 60));
                    end else if (!voices[5].active) begin
                        voices[5].active     <= 1;
                        voices[5].note       <= note;
                        voices[5].sample_sel <= (note < 60) ? 0 : 1;
                        voices[5].index      <= 0;
                        voices[5].step       <= pitch_step((note < 60) ? (note - 48) : (note - 60));
                    end else if (!voices[6].active) begin
                        voices[6].active     <= 1;
                        voices[6].note       <= note;
                        voices[6].sample_sel <= (note < 60) ? 0 : 1;
                        voices[6].index      <= 0;
                        voices[6].step       <= pitch_step((note < 60) ? (note - 48) : (note - 60));
                    end else if (!voices[7].active) begin
                        voices[7].active     <= 1;
                        voices[7].note       <= note;
                        voices[7].sample_sel <= (note < 60) ? 0 : 1;
                        voices[7].index      <= 0;
                        voices[7].step       <= pitch_step((note < 60) ? (note - 48) : (note - 60));
                    end
                end else begin // Note Off
                    if (voices[0].active && voices[0].note == note) voices[0].active <= 0;
                    if (voices[1].active && voices[1].note == note) voices[1].active <= 0;
                    if (voices[2].active && voices[2].note == note) voices[2].active <= 0;
                    if (voices[3].active && voices[3].note == note) voices[3].active <= 0;
                    if (voices[4].active && voices[4].note == note) voices[4].active <= 0;
                    if (voices[5].active && voices[5].note == note) voices[5].active <= 0;
                    if (voices[6].active && voices[6].note == note) voices[6].active <= 0;
                    if (voices[7].active && voices[7].note == note) voices[7].active <= 0;
                end
            end
            2'd1: begin // Load Sample1
                sample1_mem[sample1_write_ptr] <= writedata[15:0];
                sample1_write_ptr <= sample1_write_ptr + 1;
            end
            2'd2: begin // Load Sample2
                sample2_mem[sample2_write_ptr] <= writedata[15:0];
                sample2_write_ptr <= sample2_write_ptr + 1;
            end
        endcase
    end
    //=====================================================
    // Voice Playback and Mixing
    //=====================================================
    else if (advance) begin
           
            mix = 24'sd0;
       // ---------------- Voice 0 ----------------
        if (voices[0].active) begin
            idx0 <= voices[0].index[31:16];
            if (idx0 >= SAMPLE_LEN) begin
                voices[0].active <= 1'b0;
                voice_out[0]     <= 24'sd0;
            end
            else begin
                s0              <= voices[0].sample_sel ? sample2_mem[idx0] : sample1_mem[idx0];
                voice_out[0]    <= {{8{s0[15]}}, s0};
                voices[0].index <= voices[0].index + voices[0].step;
            end
        end
        else begin
            voice_out[0] <= 24'sd0;
        end
        mix += voice_out[0];

        // ---------------- Voice 1 ----------------
        if (voices[1].active) begin
            idx1 <= voices[1].index[31:16];
            if (idx1 >= SAMPLE_LEN) begin
                voices[1].active <= 1'b0;
                voice_out[1]     <= 24'sd0;
            end
            else begin
                s1               <= voices[1].sample_sel ? sample2_mem[idx1] : sample1_mem[idx1];
                voice_out[1]    <= {{8{s1[15]}}, s1};
                voices[1].index <= voices[1].index + voices[1].step;
            end
        end
        else begin
            voice_out[1] <= 24'sd0;
        end
        mix += voice_out[1];

        // ---------------- Voice 2 ----------------
        if (voices[2].active) begin
            idx2 <= voices[2].index[31:16];
            if (idx2 >= SAMPLE_LEN) begin
                voices[2].active <= 1'b0;
                voice_out[2]     <= 24'sd0;
            end
            else begin
                s2               <= voices[2].sample_sel ? sample2_mem[idx2] : sample1_mem[idx2];
                voice_out[2]    <= {{8{s2[15]}}, s2};
                voices[2].index <= voices[2].index + voices[2].step;
            end
        end
        else begin
            voice_out[2] <= 24'sd0;
        end
        mix += voice_out[2];

        // ---------------- Voice 3 ----------------
        if (voices[3].active) begin
            idx3 <= voices[3].index[31:16];
            if (idx3 >= SAMPLE_LEN) begin
                voices[3].active <= 1'b0;
                voice_out[3]     <= 24'sd0;
            end
            else begin
                s3               <= voices[3].sample_sel ? sample2_mem[idx3] : sample1_mem[idx3];
                voice_out[3]    <= {{8{s3[15]}}, s3};
                voices[3].index <= voices[3].index + voices[3].step;
            end
        end
        else begin
            voice_out[3] <= 24'sd0;
        end
        mix += voice_out[3];

        // ---------------- Voice 4 ----------------
        if (voices[4].active) begin
            idx4 <= voices[4].index[31:16];
            if (idx4 >= SAMPLE_LEN) begin
                voices[4].active <= 1'b0;
                voice_out[4]     <= 24'sd0;
            end
            else begin
                s4               <= voices[4].sample_sel ? sample2_mem[idx4] : sample1_mem[idx4];
                voice_out[4]    <= {{8{s4[15]}}, s4};
                voices[4].index <= voices[4].index + voices[4].step;
            end
        end
        else begin
            voice_out[4] <= 24'sd0;
        end
        mix += voice_out[4];

        // ---------------- Voice 5 ----------------
        if (voices[5].active) begin
            idx5 <= voices[5].index[31:16];
            if (idx5 >= SAMPLE_LEN) begin
                voices[5].active <= 1'b0;
                voice_out[5]     <= 24'sd0;
            end
            else begin
                s5               <= voices[5].sample_sel ? sample2_mem[idx5] : sample1_mem[idx5];
                voice_out[5]    <= {{8{s5[15]}}, s5};
                voices[5].index <= voices[5].index + voices[5].step;
            end
        end
        else begin
            voice_out[5] <= 24'sd0;
        end
        mix += voice_out[5];

        // ---------------- Voice 6 ----------------
        if (voices[6].active) begin
            idx6 <= voices[6].index[31:16];
            if (idx6 >= SAMPLE_LEN) begin
                voices[6].active <= 1'b0;
                voice_out[6]     <= 24'sd0;
            end
            else begin
                s6               <= voices[6].sample_sel ? sample2_mem[idx6] : sample1_mem[idx6];
                voice_out[6]    <= {{8{s6[15]}}, s6};
                voices[6].index <= voices[6].index + voices[6].step;
            end
        end
        else begin
            voice_out[6] <= 24'sd0;
        end
        mix += voice_out[6];

        // ---------------- Voice 7 ----------------
        if (voices[7].active) begin
            idx7 <= voices[7].index[31:16];
            if (idx7 >= SAMPLE_LEN) begin
                voices[7].active <= 1'b0;
                voice_out[7]     <= 24'sd0;
            end
            else begin
                s7               <= voices[7].sample_sel ? sample2_mem[idx7] : sample1_mem[idx7];
                voice_out[7]    <= {{8{s7[15]}}, s7};
                voices[7].index <= voices[7].index + voices[7].step;
            end
        end
        else begin
            voice_out[7] <= 24'sd0;
        end
        mix += voice_out[7];

        // -----------------------------------------
        // Output mixed sample to left & right
        // -----------------------------------------
        leftSample  <= mix;
        rightSample <= mix;
    end
end
endmodule