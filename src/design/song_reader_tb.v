module song_reader_tb();

  reg clk, reset, play, note_done;
  reg [1:0] song;
  wire [5:0] note;
  wire [5:0] duration;
  wire song_done, new_note;

  song_reader dut(
    .clk(clk),
    .reset(reset),
    .play(play),
    .song(song),
    .song_done(song_done),
    .note(note),
    .duration(duration),
    .new_note(new_note),
    .note_done(note_done)
  );

  // Reference ROM
  reg  [6:0] ref_addr;
  wire [11:0] ref_data;
  song_rom ROM_REF(.clk(clk), .addr(ref_addr), .dout(ref_data));

  // clock and reset
  initial begin
    clk = 1'b0;
    reset = 1'b1;
    repeat (4) #5 clk = ~clk;
    reset = 1'b0;
    forever #5 clk = ~clk;
  end

  integer idx, errors;
  reg stop_now;

  initial begin
    // default
    play = 1'b0;
    note_done = 1'b0;
    song = 2'd1;
    idx = 0;
    errors = 0;
    stop_now = 0;
    ref_addr = 7'd0;

    // start
    @(negedge reset);
    @(posedge clk);
    play = 1'b1;

    // process notes 
    forever begin
      @(posedge new_note);

      ref_addr <= {song, idx[4:0]};
      @(posedge clk);
      @(posedge clk);

      // Check values
      if (note !== ref_data[11:6] || duration !== ref_data[5:0]) begin
        $display("[%0t] MISMATCH idx=%0d: DUT n=%0d d=%0d, REF n=%0d d=%0d",
                 $time, idx, note, duration, ref_data[11:6], ref_data[5:0]);
        errors = errors + 1;
      end else begin
        $display("[%0t] OK idx=%0d: note=%0d duration=%0d",
                 $time, idx, note, duration);
      end

      @(posedge clk);
      note_done = 1'b1;
      @(posedge clk);
      note_done = 1'b0;

      // Stop condition
      if (ref_data[5:0] == 6'd0 || idx == 31) begin
        // Wait a couple cycles for song_done
        repeat (2) @(posedge clk);
        if (!song_done) begin
          $display("[%0t] ERROR: expected song_done=1 at end", $time);
          errors = errors + 1;
        end else begin
          $display("[%0t] song_done asserted as expected", $time);
        end

        @(posedge clk);
        play = 1'b0;
        repeat (3) @(posedge clk);
        if (song_done) begin
          $display("[%0t] ERROR: song_done did not clear when play=0", $time);
          errors = errors + 1;
        end else begin
          $display("[%0t] song_done cleared after play=0", $time);
        end

        if (errors == 0) $display("All checks PASSED");
        else             $display("%0d error(s) found", errors);
        $finish;
      end

      idx = idx + 1;
    end
  end

endmodule
