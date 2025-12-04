module music_player (
    input clk,
    input reset,
    input play_button,
    input next_button,
    input new_frame,
    output wire new_sample_generated,
    output wire [15:0] sample_out
);

    parameter BEAT_COUNT = 1000;

    // --- MCU ---
    wire play, reset_player, song_done;
    wire [1:0] current_song;
    mcu mcu_inst (
        .clk(clk), .reset(reset),
        .play_button(play_button), .next_button(next_button),
        .play(play), .reset_player(reset_player),
        .song(current_song), .song_done(song_done)
    );

    // --- Beat Generator ---
    wire beat, generate_next_sample;
    beat_generator #(.WIDTH(10), .STOP(BEAT_COUNT)) beat_gen (
        .clk(clk), .reset(reset),
        .en(generate_next_sample), .beat(beat)
    );

    // --- Song Reader (Polyphonic) ---
    wire [5:0] n0, n1, n2, d0, d1, d2;
    wire l0, l1, l2;
    
    song_reader reader (
        .clk(clk), .reset(reset | reset_player),
        .play(play), .song(current_song), .beat(beat), .song_done(song_done),
        .note0(n0), .duration0(d0), .load_note0(l0),
        .note1(n1), .duration1(d1), .load_note1(l1),
        .note2(n2), .duration2(d2), .load_note2(l2)
    );

    // --- Voices ---
    wire [15:0] s0, s1, s2; 
    wire r0, r1, r2;

    note_player v0 (.clk(clk), .reset(reset), .play_enable(play), .beat(beat),
        .note_to_load(n0), .duration_to_load(d0), .load_new_note(l0),
        .generate_next_sample(generate_next_sample), .sample_out(s0), .new_sample_ready(r0));

    note_player v1 (.clk(clk), .reset(reset), .play_enable(play), .beat(beat),
        .note_to_load(n1), .duration_to_load(d1), .load_new_note(l1),
        .generate_next_sample(generate_next_sample), .sample_out(s1), .new_sample_ready(r1));

    note_player v2 (.clk(clk), .reset(reset), .play_enable(play), .beat(beat),
        .note_to_load(n2), .duration_to_load(d2), .load_new_note(l2),
        .generate_next_sample(generate_next_sample), .sample_out(s2), .new_sample_ready(r2));

    // --- Mixer ---
    // (s0 + s1 + s2) / 4
    wire signed [15:0] ss0 = s0;
    wire signed [15:0] ss1 = s1;
    wire signed [15:0] ss2 = s2;
    wire signed [15:0] mixed = (ss0 >>> 2) + (ss1 >>> 2) + (ss2 >>> 2);

    wire [15:0] mixed_reg;
    dffr #(16) mix_ff (.clk(clk), .r(reset), .d(mixed), .q(mixed_reg));

    // --- Codec Interface ---
    wire gen_next_safe;
    dffr pipeline_ff (.clk(clk), .r(reset), .d(gen_next_safe), .q(new_sample_generated));
    assign gen_next_safe = generate_next_sample;

    codec_conditioner codec_cond (
        .clk(clk), .reset(reset),
        .new_sample_in(mixed_reg),
        .latch_new_sample_in(r0 | r1 | r2),
        .generate_next_sample(generate_next_sample),
        .new_frame(new_frame),
        .valid_sample(sample_out)
    );

endmodule
