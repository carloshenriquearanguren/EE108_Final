module chords #(
    parameter FREQ_BITS=24,
    parameter PHASE_BITS=24
)(
    input wire clk,
    input wire reset,
    input wire new_sample_ready,
    input wire [FREQ_BITS-1:0] base_note_freq,
    input wire base_note_active,
    output wire signed [15:0] chords_sample
);

    // per-voice freq words (approx major triad)
    wire [FREQ_BITS-1:0] freq0=base_note_freq;
    wire [FREQ_BITS-1:0] freq1=base_note_freq+(base_note_freq>>2);
    wire [FREQ_BITS-1:0] freq2=base_note_freq+(base_note_freq>>1);

    wire [PHASE_BITS-1:0] freq0_ext={{(PHASE_BITS-FREQ_BITS){1'b0}},freq0};
    wire [PHASE_BITS-1:0] freq1_ext={{(PHASE_BITS-FREQ_BITS){1'b0}},freq1};
    wire [PHASE_BITS-1:0] freq2_ext={{(PHASE_BITS-FREQ_BITS){1'b0}},freq2};

    // phase accumulators
    wire [PHASE_BITS-1:0] phase0_q,phase1_q,phase2_q;
    reg  [PHASE_BITS-1:0] phase0_d,phase1_d,phase2_d;
    wire phase_en=new_sample_ready;

    always @* begin
        if(!base_note_active) begin
            phase0_d={PHASE_BITS{1'b0}};
            phase1_d={PHASE_BITS{1'b0}};
            phase2_d={PHASE_BITS{1'b0}};
        end else begin
            phase0_d=phase0_q+freq0_ext;
            phase1_d=phase1_q+freq1_ext;
            phase2_d=phase2_q+freq2_ext;
        end
    end

    dffre #(PHASE_BITS) phase0_reg(.clk(clk),.r(reset),.en(phase_en),.d(phase0_d),.q(phase0_q));
    dffre #(PHASE_BITS) phase1_reg(.clk(clk),.r(reset),.en(phase_en),.d(phase1_d),.q(phase1_q));
    dffre #(PHASE_BITS) phase2_reg(.clk(clk),.r(reset),.en(phase_en),.d(phase2_d),.q(phase2_q));

    // waveform = top 16 bits of phase
    wire signed [15:0] voice0=phase0_q[PHASE_BITS-1 -: 16];
    wire signed [15:0] voice1=phase1_q[PHASE_BITS-1 -: 16];
    wire signed [15:0] voice2=phase2_q[PHASE_BITS-1 -: 16];

    // mix voices with attenuation
    wire signed [17:0] mix_wide=($signed(voice0)>>>2)+($signed(voice1)>>>2)+($signed(voice2)>>>2);

    reg signed [15:0] mix_d;
    wire signed [15:0] mix_q;

    always @* begin
        if(!base_note_active) mix_d=16'sd0;
        else mix_d=mix_wide[15:0];
    end

    dffre #(16) mix_reg(.clk(clk),.r(reset),.en(new_sample_ready),.d(mix_d),.q(mix_q));

    assign chords_sample=mix_q;

endmodule
