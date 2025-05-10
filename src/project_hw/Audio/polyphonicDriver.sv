//=====================================================
// driver_interface_poly.sv - Polyphonic Sample Player
//=====================================================
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

    //=====================================================
    // Command Handling
    //=====================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            sample1_write_ptr <= 0;
            sample2_write_ptr <= 0;
            for (int i = 0; i < NUM_VOICES; i++) begin
                voices[i].active <= 0;
            end
        end else if (write && chipselect) begin
            case (address)
                2'd0: begin // Note Command
                    logic [7:0] note = writedata[7:0];
                    logic cmd = writedata[8];
                    if (cmd) begin // Note On
                        for (int i = 0; i < NUM_VOICES; i++) begin
                            if (!voices[i].active) begin
                                voices[i].active     <= 1;
                                voices[i].note       <= note;
                                voices[i].sample_sel <= (note < 60) ? 0 : 1;
                                voices[i].index      <= 0;
                                voices[i].step       <= pitch_step((note < 60) ? (note - 48) : (note - 60));
                                break;
                            end
                        end
                    end else begin // Note Off
                        for (int i = 0; i < NUM_VOICES; i++) begin
                            if (voices[i].active && voices[i].note == note) begin
                                voices[i].active <= 0;
                            end
                        end
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
    end

    //=====================================================
    // Voice Playback and Mixing
    //=====================================================
    always_ff @(posedge clk) begin
        if (reset) begin
            leftSample <= 24'd0;
            rightSample <= 24'd0;
        end else if (advance) begin
            logic signed [23:0] mix;
            mix = 24'sd0;
            for (int i = 0; i < NUM_VOICES; i++) begin
                if (voices[i].active) begin
                    int idx = voices[i].index[31:16];
                    if (idx >= SAMPLE_LEN) begin
                        voices[i].active <= 0;
                        voice_out[i] <= 24'sd0;
                    end else begin
                        logic [15:0] s = voices[i].sample_sel ? sample2_mem[idx] : sample1_mem[idx];
                        voice_out[i] <= {{8{s[15]}}, s};
                        voices[i].index <= voices[i].index + voices[i].step;
                    end
                end else begin
                    voice_out[i] <= 24'sd0;
                end
                mix += voice_out[i];
            end
            leftSample <= mix;
            rightSample <= mix;
        end
    end
endmodule
