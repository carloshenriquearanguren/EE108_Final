module note_player_tb();

    reg clk, reset, play_enable, generate_next_sample;
    reg [5:0] note_to_load;
    reg [5:0] duration_to_load;
    reg load_new_note;
    wire done_with_note, new_sample_ready, beat;
    wire [15:0] sample_out;

    note_player np(
        .clk(clk),
        .reset(reset),

        .play_enable(play_enable),
        .note_to_load(note_to_load),
        .duration_to_load(duration_to_load),
        .load_new_note(load_new_note),
        .done_with_note(done_with_note),

        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(sample_out),
        .new_sample_ready(new_sample_ready)
    );

    beat_generator #(.WIDTH(17), .STOP(1500)) beat_generator(
        .clk(clk),
        .reset(reset),
        .en(1'b1),
        .beat(beat)
    );

    // Clock and reset
    initial begin
        clk = 1'b0;
        reset = 1'b1;
        repeat (4) #5 clk = ~clk;
        reset = 1'b0;
        forever #5 clk = ~clk;
    end

    // Tests
    initial begin
        play_enable       = 0;
        note_to_load      = 6'd0;
        duration_to_load  = 6'd0;
        load_new_note     = 0;
    
        #200;
        $display("[%0t] Reset complete, starting tests...", $time);
    
        // TEST 1: play a 3-beat note
        play_enable      = 1;
        note_to_load     = 6'd12;
        duration_to_load = 6'd3;
        load_new_note    = 1;
        #10 load_new_note = 0;
        $display("[%0t] Loaded note %0d for %0d beats", $time, note_to_load, duration_to_load);
    
        #60_000_000;
        if (done_with_note)
            $display("[%0t] DONE signal detected (note 1 complete)", $time);
    
        // TEST 2
        note_to_load     = 6'd18;
        duration_to_load = 6'd2;
        load_new_note    = 1;
        #10 load_new_note = 0;
        $display("[%0t] Loaded note %0d for %0d beats", $time, note_to_load, duration_to_load);
    
        #40_000_000;
        if (done_with_note)
            $display("[%0t] DONE signal detected (note 2 complete)", $time);
    
        $display("[%0t] All tests complete.", $time);
        $finish;
    end
    
endmodule


