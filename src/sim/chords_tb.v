// chords_tb.v – self-checking testbench for chords.v

module chords_tb();

    reg clk, reset;
    reg new_sample_ready;
    reg [23:0] base_note_freq;
    reg base_note_active;
    wire signed [15:0] chords_sample;

    // DUT
    chords #(
        .FREQ_BITS(24),
        .PHASE_BITS(24)
    ) dut(
        .clk(clk),
        .reset(reset),
        .new_sample_ready(new_sample_ready),
        .base_note_freq(base_note_freq),
        .base_note_active(base_note_active),
        .chords_sample(chords_sample)
    );

    // clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    // simple abs function for signed 16-bit
    function integer abs16(input signed [15:0] v);
        begin
            abs16 = (v < 0) ? -v : v;
        end
    endfunction

    // drive one audio sample tick
    task step_sample;
        begin
            new_sample_ready = 1'b1;
            #10;
            new_sample_ready = 1'b0;
            #1000;           // gap between samples (arbitrary)
        end
    endtask

    integer i;
    integer nonzero_t1, nonzero_t2, nonzero_silence;
    integer max_abs_t1, max_abs_t2;

    initial begin
        // init
        reset = 1'b1;
        new_sample_ready = 1'b0;
        base_note_active = 1'b0;
        base_note_freq = 24'd0;

        nonzero_t1 = 0;
        nonzero_t2 = 0;
        nonzero_silence = 0;
        max_abs_t1 = 0;
        max_abs_t2 = 0;

        #50;
        reset = 1'b0;
        $display("[%0t] Reset deasserted.", $time);

        //------------------------------------------------------------------
        // TEST 1: medium-frequency chord, expect non-zero bounded samples
        //------------------------------------------------------------------
        base_note_freq = 24'd60000;
        base_note_active = 1'b1;
        $display("[%0t] TEST1: base_note_freq=%0d", $time, base_note_freq);

        for(i=0; i<300; i=i+1) begin
            step_sample();
            if(chords_sample != 16'sd0)
                nonzero_t1 = nonzero_t1 + 1;
            if(abs16(chords_sample) > max_abs_t1)
                max_abs_t1 = abs16(chords_sample);
        end

        //------------------------------------------------------------------
        // TEST 2: higher-frequency chord, also non-zero bounded samples
        //------------------------------------------------------------------
        base_note_freq = 24'd110000;
        $display("[%0t] TEST2: base_note_freq=%0d", $time, base_note_freq);

        for(i=0; i<300; i=i+1) begin
            step_sample();
            if(chords_sample != 16'sd0)
                nonzero_t2 = nonzero_t2 + 1;
            if(abs16(chords_sample) > max_abs_t2)
                max_abs_t2 = abs16(chords_sample);
        end

        //------------------------------------------------------------------
        // TEST 3: silence when inactive
        //------------------------------------------------------------------
        base_note_active = 1'b0;
        $display("[%0t] TEST3: base_note_active=0 (expect silence)", $time);

        for(i=0; i<100; i=i+1) begin
            step_sample();
            if(chords_sample != 16'sd0)
                nonzero_silence = nonzero_silence + 1;
        end

        //------------------------------------------------------------------
        // Checks
        //------------------------------------------------------------------
        if(nonzero_t1 == 0) begin
            $display("FAIL: TEST1 produced only zeros.");
            $finish;
        end
        if(nonzero_t2 == 0) begin
            $display("FAIL: TEST2 produced only zeros.");
            $finish;
        end
        if(nonzero_silence != 0) begin
            $display("FAIL: TEST3 silence check: saw %0d non-zero samples.", nonzero_silence);
            $finish;
        end

        // amplitude bounds: keep some headroom from 16-bit full scale
        if(max_abs_t1 > 32000 || max_abs_t2 > 32000) begin
            $display("FAIL: amplitude overflow: max_abs_t1=%0d max_abs_t2=%0d",
                     max_abs_t1,max_abs_t2);
            $finish;
        end

        $display("PASS: chords_tb – non-zero when active, zero when inactive, no clipping.");
        $finish;
    end

endmodule
