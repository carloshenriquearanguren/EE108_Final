module note_player(
    input clk,
    input reset,
    input play_enable,  // When high we play, when low we don't.
    input [5:0] note_to_load,  // The note to play
    input [5:0] duration_to_load,  // The duration of the note to play
    input load_new_note,  // Tells us when we have a new note to load
    output done_with_note,  // When we are done with the note this stays high.
    input beat,  // This is our 1/48th second beat
    input generate_next_sample,  // Tells us when the codec wants a new sample
    output [15:0] sample_out,  // Our sample output
    output new_sample_ready  // Tells the codec when we've got a sample
);

    // Implementation goes here!
    wire [5:0]  note_q, next_note;
    wire [5:0]  dur_q,  next_dur;
    wire        done_q, next_done;

    wire [19:0] step_size;
    wire [15:0] sine_sample;
    wire        sine_ready;
    
    frequency_rom FREQ (
        .clk(clk),
        .addr(note_q),
        .dout(step_size)
    );

    sine_reader SINE (
        .clk(clk),
        .reset(reset),
        .step_size(step_size),
        .generate_next(generate_next_sample & play_enable),
        .sample_ready(sine_ready),
        .sample(sine_sample)
    );
    dff #(6) note_ff (.clk(clk), .d(next_note), .q(note_q));
    dff #(6) dur_ff  (.clk(clk), .d(next_dur),  .q(dur_q));
    dff #(1) done_ff (.clk(clk), .d(next_done), .q(done_q));

    reg [5:0] dur_c;
    reg [5:0] note_c;
    reg       done_c;

    always @(*) begin
        // Defaults
        note_c = note_q;
        dur_c  = dur_q;
        done_c = 1'b0;

        // Load new note and duration
        if (load_new_note) begin
            note_c = note_to_load;
            dur_c  = duration_to_load;
        end
        // Countdown duration
        else if (play_enable && beat && dur_q != 6'd0) begin
            dur_c = dur_q - 1'b1;
            if (dur_q == 6'd1)
                done_c = 1'b1;   // pulse when counter hits zero
        end
    end

    assign next_note = note_c;
    assign next_dur  = dur_c;
    assign next_done = done_c;

    assign sample_out       = (note_q == 6'd0) ? 16'd0 : sine_sample;
    assign new_sample_ready = sine_ready;
    assign done_with_note   = done_q;

endmodule

