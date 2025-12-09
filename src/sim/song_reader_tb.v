`timescale 1ns / 1ps

module song_reader_tb();

    // Inputs
    reg clk;
    reg reset;
    reg play;
    reg [1:0] song;
    reg beat;
    reg backwards;
    reg fast_mode;

    // Outputs
    wire song_done;
    wire [5:0] note0, duration0; wire load_note0;
    wire [5:0] note1, duration1; wire load_note1;
    wire [5:0] note2, duration2; wire load_note2;

    // DUT
    song_reader dut (
        .clk(clk),
        .reset(reset),
        .play(play),
        .song(song),
        .beat(beat),
        .backwards(backwards),
        .fast_mode(fast_mode),
        .song_done(song_done),
        .note0(note0), .duration0(duration0), .load_note0(load_note0),
        .note1(note1), .duration1(duration1), .load_note1(load_note1),
        .note2(note2), .duration2(duration2), .load_note2(load_note2)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;    // 100 MHz
    end

    // Beat generator (we manually pulse beat in the test phases)
    task pulse_beat;
        begin
            beat = 1;
            @(negedge clk);
            beat = 0;
            @(negedge clk);
        end
    endtask

    // Monitor note loads
    always @(posedge clk) begin
        if (load_note0)
            $display("[%0t] V0: note=%0d dur=%0d  (backwards=%0d fast=%0d)",
                     $time, note0, duration0, backwards, fast_mode);
        if (load_note1)
            $display("[%0t] V1: note=%0d dur=%0d  (backwards=%0d fast=%0d)",
                     $time, note1, duration1, backwards, fast_mode);
        if (load_note2)
            $display("[%0t] V2: note=%0d dur=%0d  (backwards=%0d fast=%0d)",
                     $time, note2, duration2, backwards, fast_mode);
        if (song_done)
            $display("[%0t] song_done asserted (backwards=%0d fast=%0d)",
                     $time, backwards, fast_mode);
    end

    // Test sequence
    initial begin
        // Common init
        reset = 1;
        play  = 0;
        song  = 0;
        beat  = 0;
        backwards = 0;
        fast_mode = 0;

        repeat(5) @(negedge clk);
        reset = 0;
        repeat(5) @(negedge clk);

        //------------------------------------------------------------------
        // Phase 1: Song 0, forward, normal speed
        //------------------------------------------------------------------
        $display("=== Phase 1: forward, normal speed ===");
        play = 1;
        repeat(10) @(negedge clk);  // let FSM leave IDLE

        // Drive a fixed number of beats and watch notes
        repeat(60) pulse_beat;

        play = 0;
        repeat(10) @(negedge clk);

        //------------------------------------------------------------------
        // Phase 2: Song 0, backward, normal speed
        //------------------------------------------------------------------
        $display("=== Phase 2: backward, normal speed ===");
        reset = 1;
        repeat(4) @(negedge clk);
        reset = 0;
        repeat(4) @(negedge clk);

        backwards = 1;
        fast_mode = 0;
        play = 1;
        repeat(10) @(negedge clk);

        repeat(60) pulse_beat;

        play = 0;
        backwards = 0;  // clear for next phase
        repeat(10) @(negedge clk);

        //------------------------------------------------------------------
        // Phase 3: Song 0, forward, FAST (2x)
        //------------------------------------------------------------------
        $display("=== Phase 3: forward, FAST (2x) ===");
        reset = 1;
        repeat(4) @(negedge clk);
        reset = 0;
        repeat(4) @(negedge clk);

        backwards = 0;
        fast_mode = 1;
        play = 1;
        repeat(10) @(negedge clk);

        // With fast_mode=1, waits should complete in about half as many beats
        repeat(60) pulse_beat;

        $display("=== song_reader_tb complete ===");
        $stop;
    end

endmodule
