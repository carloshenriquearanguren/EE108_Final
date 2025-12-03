// echo_tb.v - self-checking testbench for echo.v

`timescale 1ns/1ps

module echo_tb();

    localparam SAMPLE_WIDTH = 16;
    localparam ADDR_BITS    = 5;   // depth = 32

    reg clk, reset;
    reg new_sample_ready;
    reg signed [SAMPLE_WIDTH-1:0] in_sample;
    reg echo_enable;
    reg [ADDR_BITS-1:0] delay_samples;
    reg [2:0] atten_shift;
    wire signed [SAMPLE_WIDTH-1:0] out_sample;

    // DUT
    echo #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .ADDR_BITS(ADDR_BITS)
    ) dut (
        .clk(clk),
        .reset(reset),
        .new_sample_ready(new_sample_ready),
        .in_sample(in_sample),
        .echo_enable(echo_enable),
        .delay_samples(delay_samples),
        .atten_shift(atten_shift),
        .out_sample(out_sample)
    );

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // one audio-sample step
    task step_sample;
        begin
            new_sample_ready = 1'b1;
            #10;
            new_sample_ready = 1'b0;
            #100;   // idle between samples (arbitrary)
        end
    endtask

    integer i;
    integer errors;
    reg signed [SAMPLE_WIDTH-1:0] prev_in;
    reg saw_echo;

    // absolute value helper
    function integer abs16;
        input signed [SAMPLE_WIDTH-1:0] v;
        begin
            if (v < 0)
                abs16 = -v;
            else
                abs16 = v;
        end
    endfunction

    initial begin
        // init
        reset = 1'b1;
        new_sample_ready = 1'b0;
        in_sample = 0;
        echo_enable = 0;
        delay_samples = 0;
        atten_shift = 3'd2;   // divide by 4
        prev_in = 0;
        errors = 0;
        saw_echo = 0;

        #40;
        reset = 1'b0;
        $display("[%0t] Reset deasserted.", $time);

        //----------------------------------------------------------------------
        // TEST 1: echo disabled, passthrough with 1-sample latency
        //----------------------------------------------------------------------
        echo_enable = 0;
        delay_samples = 5;    // irrelevant when disabled
        $display("[%0t] TEST1: echo disabled (passthrough check).", $time);

        prev_in = 0;
        for (i = 0; i < 50; i = i + 1) begin
            // bounded sawtooth between about -8000 and +8000
            if (i < 25)
                in_sample = -16'sd8000 + i * 16'sd640;
            else
                in_sample =  16'sd8000 - (i-25) * 16'sd640;

            step_sample();

            if (i > 0) begin
                // passthrough check, 1-sample latency
                if (out_sample !== prev_in) begin
                    $display("FAIL TEST1 @%0t: out=%0d expected=%0d",
                             $time, out_sample, prev_in);
                    errors = errors + 1;
                end
                // ensure no clipping
                if (abs16(out_sample) > 32000) begin
                    $display("FAIL TEST1 @%0t: clipping out=%0d",
                             $time, out_sample);
                    errors = errors + 1;
                end
            end

            prev_in = in_sample;
        end

        //----------------------------------------------------------------------
        // TEST 2: echo enabled, impulse then zeros
        //----------------------------------------------------------------------
        echo_enable = 1;
        delay_samples = 4;
        atten_shift = 3'd2;   // wet = in / 4
        $display("[%0t] TEST2: echo enabled, delay=%0d shift=%0d.",
                 $time, delay_samples, atten_shift);

        saw_echo = 0;

        // impulse
        in_sample = 16'sd8000;
        step_sample();
        prev_in = in_sample;

        // next sample zero
        in_sample = 16'sd0;
        step_sample();
        prev_in = in_sample;

        // more zeros; expect an echo of 8000>>2 = 2000 at some point
        for (i = 0; i < 40; i = i + 1) begin
            in_sample = 16'sd0;
            step_sample();

            if (!saw_echo && out_sample == 16'sd2000) begin
                saw_echo = 1;
                $display("[%0t] TEST2: echo detected (out=%0d).",
                         $time, out_sample);
            end

            if (saw_echo && abs16(out_sample) > 32000) begin
                $display("FAIL TEST2 @%0t: clipping after echo out=%0d",
                         $time, out_sample);
                errors = errors + 1;
            end
        end

        if (!saw_echo) begin
            $display("FAIL TEST2: did not observe expected delayed echo.");
            errors = errors + 1;
        end

        //----------------------------------------------------------------------
        // TEST 3: echo disabled again, passthrough
        //----------------------------------------------------------------------
        echo_enable = 0;
        $display("[%0t] TEST3: echo disabled again (passthrough).", $time);

        prev_in = 0;
        for (i = 0; i < 30; i = i + 1) begin
            if (i < 5)
                in_sample = 16'sd4000;
            else
                in_sample = 16'sd0;

            step_sample();

            if (i > 0) begin
                if (out_sample !== prev_in) begin
                    $display("FAIL TEST3 @%0t: out=%0d expected=%0d",
                             $time, out_sample, prev_in);
                    errors = errors + 1;
                end
                if (abs16(out_sample) > 32000) begin
                    $display("FAIL TEST3 @%0t: clipping out=%0d",
                             $time, out_sample);
                    errors = errors + 1;
                end
            end

            prev_in = in_sample;
        end

        //----------------------------------------------------------------------
        // Final result
        //----------------------------------------------------------------------
        if (errors == 0)
            $display("PASS: echo_tb - passthrough and echo properties hold.");
        else
            $display("FAIL: echo_tb - %0d property violations detected.", errors);

        $finish;
    end

endmodule
