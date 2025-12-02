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

    wire [5:0] note_q,next_note;
    wire [5:0] dur_q,next_dur;
    wire       done_q,next_done;

    wire [19:0] step_size;
    wire [15:0] chord_sample;

    frequency_rom FREQ(
        .clk(clk),
        .addr(note_q),
        .dout(step_size)
    );

    dff #(6) note_ff(.clk(clk),.d(next_note),.q(note_q));
    dff #(6) dur_ff (.clk(clk),.d(next_dur), .q(dur_q));
    dff #(1) done_ff(.clk(clk),.d(next_done),.q(done_q));

    // note is active while playing and duration nonzero
    wire note_active = play_enable && (dur_q!=6'd0) && (note_q!=6'd0);

    chords #(
        .FREQ_BITS(20),
        .PHASE_BITS(22)
    ) CHORDS(
        .clk(clk),
        .reset(reset),
        .new_sample_ready(generate_next_sample & play_enable),
        .base_note_freq(step_size),
        .base_note_active(note_active),
        .chords_sample(chord_sample)
    );

    reg [5:0] dur_c;
    reg [5:0] note_c;
    reg       done_c;

    always @(*) begin
        note_c = note_q;
        dur_c  = dur_q;
        done_c = 1'b0;

        if(load_new_note) begin
            note_c = note_to_load;
            dur_c  = duration_to_load;
        end else if(play_enable && beat && dur_q!=6'd0) begin
            dur_c = dur_q - 1'b1;
            if(dur_q==6'd1)
                done_c = 1'b1;
        end
    end

    assign next_note = note_c;
    assign next_dur  = dur_c;
    assign next_done = done_c;

    assign sample_out       = (note_q==6'd0) ? 16'd0 : chord_sample;
    assign new_sample_ready = generate_next_sample & play_enable;
    assign done_with_note   = done_q;

endmodule
