//
//  music_player module
//
//  Connects MCU, song_reader, note_player, beat_generator, echo, and codec_conditioner.
//

module music_player(
    // Standard system clock and reset
    input clk,
    input reset,

    // Our debounced and one-pulsed button inputs.
    input play_button,
    input next_button,

    // The raw new_frame signal from the ac97_if codec.
    input new_frame,

    // This output must go high for one cycle when a new sample is generated.
    output wire new_sample_generated,

    // Our final output sample to the codec. This needs to be synced to
    // new_frame.
    output wire [15:0] sample_out
);
    // The BEAT_COUNT is parameterized so you can reduce this in simulation.
    parameter BEAT_COUNT = 1000;

//
//  ****************************************************************************
//      Master Control Unit
//  ****************************************************************************
//
    wire play;
    wire reset_player;
    wire [1:0] current_song;
    wire song_done;

    mcu mcu(
        .clk(clk),
        .reset(reset),
        .play_button(play_button),
        .next_button(next_button),
        .play(play),
        .reset_player(reset_player),
        .song(current_song),
        .song_done(song_done)
    );

//
//  ****************************************************************************
//      Song Reader
//  ****************************************************************************
//
    wire [5:0] note_to_play;
    wire [5:0] duration_for_note;
    wire new_note;
    wire note_done;

    song_reader song_reader(
        .clk(clk),
        .reset(reset | reset_player),
        .play(play),
        .song(current_song),
        .song_done(song_done),
        .note(note_to_play),
        .duration(duration_for_note),
        .new_note(new_note),
        .note_done(note_done)
    );

//
//  ****************************************************************************
//      Note Player (now generating chords)
//  ****************************************************************************
//
    wire beat;
    wire generate_next_sample, generate_next_sample0;
    wire [15:0] note_sample, note_sample0;
    wire note_sample_ready, note_sample_ready0;

    // Pipeline registers to reduce critical path
    dffr pipeline_ff_gen_next_sample (
        .clk(clk),
        .r(reset),
        .d(generate_next_sample0),
        .q(generate_next_sample)
    );

    dffr #(.WIDTH(16)) pipeline_ff_note_sample (
        .clk(clk),
        .r(reset),
        .d(note_sample0),
        .q(note_sample)
    );

    dffr pipeline_ff_new_sample_ready (
        .clk(clk),
        .r(reset),
        .d(note_sample_ready0),
        .q(note_sample_ready)
    );

    note_player note_player(
        .clk(clk),
        .reset(reset),
        .play_enable(play),
        .note_to_load(note_to_play),
        .duration_to_load(duration_for_note),
        .load_new_note(new_note),
        .done_with_note(note_done),
        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(note_sample0),
        .new_sample_ready(note_sample_ready0)
    );

//
//  ****************************************************************************
//      Beat Generator
//  ****************************************************************************
//
    beat_generator #(.WIDTH(10), .STOP(BEAT_COUNT)) beat_generator(
        .clk(clk),
        .reset(reset),
        .en(generate_next_sample),
        .beat(beat)
    );

//
//  ****************************************************************************
//      Echo (post-effect on mixed audio)
//  ****************************************************************************
//
    wire signed [15:0] echo_in;
    wire signed [15:0] echo_out;

    // Cast pipeline note sample to signed for echo
    assign echo_in = note_sample;

    // For now: echo always enabled, fixed delay and attenuation.
    // Later you can replace these with switches/buttons or MCU outputs.
    wire        echo_enable    = 1'b1;
    wire [14:0] echo_delay     = 15'd4800; // ~100 ms at 48 kHz if buffer large
    wire [2:0]  echo_atten_sh  = 3'd1;     // /8 for wet signal

    echo #(
        .SAMPLE_WIDTH(16),
        .ADDR_BITS(15)          // 2^15 = 32768 samples
    ) echo_inst (
        .clk(clk),
        .reset(reset),
        .new_sample_ready(note_sample_ready),
        .in_sample(echo_in),
        .echo_enable(echo_enable),
        .delay_samples(echo_delay),
        .atten_shift(echo_atten_sh),
        .out_sample(echo_out)
    );

//
//  ****************************************************************************
//      Codec Conditioner
//  ****************************************************************************
//
    wire new_sample_generated0;
    wire [15:0] sample_out0;

    dffr pipeline_ff_nsg (
        .clk(clk),
        .r(reset),
        .d(new_sample_generated0),
        .q(new_sample_generated)
    );

    // If you want one more pipeline stage for sample_out, you can re-enable:
    // dffr #(.WIDTH(16)) pipeline_ff_sample_out (
    //     .clk(clk),
    //     .r(reset),
    //     .d(sample_out0),
    //     .q(sample_out)
    // );
    // For now, pass through directly:
    assign sample_out = sample_out0;

    assign new_sample_generated0 = generate_next_sample;

    codec_conditioner codec_conditioner(
        .clk(clk),
        .reset(reset),
        // FEED ECHO OUTPUT INTO CODEC, NOT RAW NOTE SAMPLE
        .new_sample_in(echo_out),
        .latch_new_sample_in(note_sample_ready),
        .generate_next_sample(generate_next_sample0),
        .new_frame(new_frame),
        .valid_sample(sample_out0)
    );

endmodule
