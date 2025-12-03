// chords.v
// Generate a 3-note chord using three sine_reader instances.
// Each voice has its own step_size and enable; outputs are summed and attenuated.

module chords(
    input clk,
    input reset,

    input generate_next,   // 1-cycle strobe at audio sample rate

    // per-voice control from frequency_rom or scheduler
    input [19:0] step_size0,
    input [19:0] step_size1,
    input [19:0] step_size2,

    input enable0,
    input enable1,
    input enable2,

    output [15:0] sample,  // mixed chord sample (signed)
    output sample_ready    // goes high when sample is valid
);

    // voice 0
    wire v0_ready;
    wire [15:0] v0_sample;
    sine_reader SINE0(
        .clk(clk),
        .reset(reset),
        .step_size(step_size0),
        .generate_next(generate_next & enable0),
        .sample_ready(v0_ready),
        .sample(v0_sample)
    );

    // voice 1
    wire v1_ready;
    wire [15:0] v1_sample;
    sine_reader SINE1(
        .clk(clk),
        .reset(reset),
        .step_size(step_size1),
        .generate_next(generate_next & enable1),
        .sample_ready(v1_ready),
        .sample(v1_sample)
    );

    // voice 2
    wire v2_ready;
    wire [15:0] v2_sample;
    sine_reader SINE2(
        .clk(clk),
        .reset(reset),
        .step_size(step_size2),
        .generate_next(generate_next & enable2),
        .sample_ready(v2_ready),
        .sample(v2_sample)
    );

    // treat missing voices as zero when disabled
    wire signed [15:0] v0 = enable0 ? v0_sample : 16'sd0;
    wire signed [15:0] v1 = enable1 ? v1_sample : 16'sd0;
    wire signed [15:0] v2 = enable2 ? v2_sample : 16'sd0;

    // sum with attenuation to avoid clipping
    // divide each voice by 2 (>>1) before summing:
    // max ~ 3 * (2^15 / 2) = 49152, still high; so we also divide the sum by 2.
    wire signed [17:0] sum_wide =
        ($signed(v0) >>> 1) +
        ($signed(v1) >>> 1) +
        ($signed(v2) >>> 1);

    wire signed [15:0] mixed = sum_wide[17:2];  // extra shift for headroom

    assign sample = mixed;

    // sample_ready: any enabled voice that was asked to generate
    assign sample_ready =
        (generate_next & enable0 & v0_ready) |
        (generate_next & enable1 & v1_ready) |
        (generate_next & enable2 & v2_ready);

endmodule
