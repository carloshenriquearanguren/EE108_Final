module note_player(
    input clk,
    input reset,
    input play_enable,
    input [5:0] note_to_load,
    input [5:0] duration_to_load,
    input load_new_note,
    output done_with_note,
    input beat,
    input generate_next_sample,
    output [15:0] sample_out,
    output new_sample_ready
);

    // note/duration/done registers (same as lab 4)
    wire [5:0] note_q, next_note;
    wire [5:0] dur_q,  next_dur;
    wire       done_q, next_done;

    dff #(6) note_ff(.clk(clk), .d(next_note), .q(note_q));
    dff #(6) dur_ff (.clk(clk), .d(next_dur),  .q(dur_q));
    dff #(1) done_ff(.clk(clk), .d(next_done), .q(done_q));

    reg [5:0] note_c;
    reg [5:0] dur_c;
    reg       done_c;

    always @(*) begin
        note_c = note_q;
        dur_c  = dur_q;
        done_c = 1'b0;

        // load new note + duration
        if (load_new_note) begin
            note_c = note_to_load;
            dur_c  = duration_to_load;
        end
        // countdown duration
        else if (play_enable && beat && dur_q != 6'd0) begin
            dur_c = dur_q - 6'd1;
            if (dur_q == 6'd1)
                done_c = 1'b1;  // pulse when counter hits zero
        end
    end

    assign next_note     = note_c;
    assign next_dur      = dur_c;
    assign next_done     = done_c;
    assign done_with_note = done_q;

    // -------------------------------------------------------------------------
    // Chord mapping: base, base+4, base+7 (clamped to valid range)
    // -------------------------------------------------------------------------
    wire [5:0] note0 = note_q;

    wire [6:0] tmp1 = note_q + 7'd4;
    wire [6:0] tmp2 = note_q + 7'd7;

    wire [5:0] note1 = (tmp1 > 7'd63) ? 6'd63 : tmp1[5:0];
    wire [5:0] note2 = (tmp2 > 7'd63) ? 6'd63 : tmp2[5:0];

    // three step_size values from frequency_rom
    wire [19:0] step0, step1, step2;

    frequency_rom FREQ0(
        .clk(clk),
        .addr(note0),
        .dout(step0)
    );

    frequency_rom FREQ1(
        .clk(clk),
        .addr(note1),
        .dout(step1)
    );

    frequency_rom FREQ2(
        .clk(clk),
        .addr(note2),
        .dout(step2)
    );

    // active while playing and duration nonzero
    wire voice_en = play_enable && (dur_q != 6'd0) && (note_q != 6'd0);

    // -------------------------------------------------------------------------
    // Three sine_reader oscillators (one per chord voice)
    // -------------------------------------------------------------------------
    wire v0_ready, v1_ready, v2_ready;
    wire [15:0] v0_sample, v1_sample, v2_sample;

    sine_reader SINE0(
        .clk(clk),
        .reset(reset),
        .step_size(step0),
        .generate_next(generate_next_sample & voice_en),
        .sample_ready(v0_ready),
        .sample(v0_sample)
    );

    sine_reader SINE1(
        .clk(clk),
        .reset(reset),
        .step_size(step1),
        .generate_next(generate_next_sample & voice_en),
        .sample_ready(v1_ready),
        .sample(v1_sample)
    );

    sine_reader SINE2(
        .clk(clk),
        .reset(reset),
        .step_size(step2),
        .generate_next(generate_next_sample & voice_en),
        .sample_ready(v2_ready),
        .sample(v2_sample)
    );

    // treat disabled voice as zero
    wire signed [15:0] s0 = voice_en ? v0_sample : 16'sd0;
    wire signed [15:0] s1 = voice_en ? v1_sample : 16'sd0;
    wire signed [15:0] s2 = voice_en ? v2_sample : 16'sd0;

    // -------------------------------------------------------------------------
    // Mix voices with stronger attenuation to avoid clipping/distortion
    // -------------------------------------------------------------------------
    // Each voice: >>3 (divide by 8), then summed:
    // max per voice ~ 4095, sum of 3 voices ~ 12285 << 32767
    wire signed [17:0] sum_wide =
        ($signed(s0) >>> 3) +
        ($signed(s1) >>> 3) +
        ($signed(s2) >>> 3);

    wire signed [15:0] mixed = sum_wide[15:0];

    assign sample_out = (note_q == 6'd0) ? 16'd0 : mixed;

    // new_sample_ready: reuse generate_next_sample (like original)
    assign new_sample_ready = generate_next_sample & play_enable;

endmodule
