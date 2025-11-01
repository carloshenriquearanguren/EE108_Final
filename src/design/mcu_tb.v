module mcu_tb();
    reg clk, reset, play_button, next_button, song_done;
    wire play, reset_player;
    wire [1:0] song;

    mcu dut(
        .clk(clk),
        .reset(reset),
        .play_button(play_button),
        .next_button(next_button),
        .play(play),
        .reset_player(reset_player),
        .song(song),
        .song_done(song_done)
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
        // Tests
    initial begin
        // Initialize inputs
        play_button = 0;
        next_button = 0;
        song_done   = 0;

        // Wait for reset to finish
        #20;

        // Press play button
        $display("=== Pressing play button ===");
        play_button = 1;
        #10;
        play_button = 0;
        #50;

        // Simulate song done
        $display("=== Song done ===");
        song_done = 1;
        #10;
        song_done = 0;
        #50;

        // Press next button
        $display("=== Pressing next button ===");
        next_button = 1;
        #10;
        next_button = 0;
        #50;

        // End simulation
        $display("=== Test complete ===");
        $stop;
    end


endmodule
