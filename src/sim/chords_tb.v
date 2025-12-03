`timescale 1ns/1ps

module chords_tb;

    reg clk, reset;
    reg play_enable;
    reg [5:0] note_to_load;
    reg [5:0] duration_to_load;
    reg load_new_note;
    reg beat;
    reg generate_next_sample;

    wire done_with_note;
    wire [15:0] sample_out;
    wire new_sample_ready;

    // note_player
    note_player dut(
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

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ------------------------------------------------------------
    // Golden chord model: same mapping (note, note+4, note+7)
    // and same mix: (s0>>>2 + s1>>>2 + s2>>>2)[15:0]
    // ------------------------------------------------------------
    wire [5:0] g_note0 = note_to_load;
    wire [6:0] g_tmp1  = note_to_load + 7'd4;
    wire [6:0] g_tmp2  = note_to_load + 7'd7;
    wire [5:0] g_note1 = (g_tmp1 > 7'd63) ? 6'd63 : g_tmp1[5:0];
    wire [5:0] g_note2 = (g_tmp2 > 7'd63) ? 6'd63 : g_tmp2[5:0];

    wire [19:0] g_step0, g_step1, g_step2;

    frequency_rom GFREQ0(.clk(clk), .addr(g_note0), .dout(g_step0));
    frequency_rom GFREQ1(.clk(clk), .addr(g_note1), .dout(g_step1));
    frequency_rom GFREQ2(.clk(clk), .addr(g_note2), .dout(g_step2));

    wire [15:0] g_s0_raw, g_s1_raw, g_s2_raw;
    wire        g_r0, g_r1, g_r2;

    sine_reader GSINE0(
        .clk(clk),
        .reset(reset),
        .step_size(g_step0),
        .generate_next(generate_next_sample & play_enable),
        .sample_ready(g_r0),
        .sample(g_s0_raw)
    );

    sine_reader GSINE1(
        .clk(clk),
        .reset(reset),
        .step_size(g_step1),
        .generate_next(generate_next_sample & play_enable),
        .sample_ready(g_r1),
        .sample(g_s1_raw)
    );

    sine_reader GSINE2(
        .clk(clk),
        .reset(reset),
        .step_size(g_step2),
        .generate_next(generate_next_sample & play_enable),
        .sample_ready(g_r2),
        .sample(g_s2_raw)
    );

    wire signed [15:0] g_s0 = g_s0_raw;
    wire signed [15:0] g_s1 = g_s1_raw;
    wire signed [15:0] g_s2 = g_s2_raw;

    wire signed [17:0] g_sum_wide =
        ($signed(g_s0) >>> 2) +
        ($signed(g_s1) >>> 2) +
        ($signed(g_s2) >>> 2);

    wire signed [15:0] golden_sample = (note_to_load == 6'd0) ? 16'sd0
                                                              : g_sum_wide[15:0];

    // ------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------
    task step_one_sample;
        begin
            generate_next_sample = 1'b1;
            #10;
            generate_next_sample = 1'b0;
            #10;    // wait one extra clock so outputs settle
        end
    endtask

    function integer abs16;
        input signed [15:0] v;
        begin
            if (v < 0)
                abs16 = -v;
            else
                abs16 = v;
        end
    endfunction

    integer i;
    integer errors;

    initial begin
        // init
        clk = 1'b0;
        reset = 1'b1;
        play_enable = 1'b0;
        note_to_load = 6'd0;
        duration_to_load = 6'd0;
        load_new_note = 1'b0;
        beat = 1'b0;                 // keep 0 so duration never decrements
        generate_next_sample = 1'b0;
        errors = 0;

        // release reset
        #40;
        reset = 1'b0;
        $display("[%0t] Reset deasserted.", $time);

        // ------------------------------------------------------------------
        // TEST: load one note, play for many samples, compare to golden
        // ------------------------------------------------------------------
        play_enable = 1'b1;
        note_to_load = 6'd20;        // some valid non-zero note
        duration_to_load = 6'd63;    // large so it won't time out
        load_new_note = 1'b1;
        #10 load_new_note = 1'b0;

        $display("[%0t] Loaded note %0d (expect major triad chord).",
                 $time, note_to_load);

        // Skip a couple of cycles for internal state to take effect
        #40;

        for (i = 0; i < 200; i = i + 1) begin
            step_one_sample();

            // Compare DUT output to golden chord sample
            if (sample_out !== golden_sample) begin
                $display("FAIL @%0t: sample_out=%0d golden=%0d",
                         $time, sample_out, golden_sample);
                errors = errors + 1;
            end

            // Also check we are not clipping badly
            if (abs16(sample_out) > 32000) begin
                $display("FAIL @%0t: clipping sample_out=%0d",
                         $time, sample_out);
                errors = errors + 1;
            end
        end

        // ------------------------------------------------------------------
        // Result
        // ------------------------------------------------------------------
        if (errors == 0)
            $display("PASS: chords_tb - chord output matches golden model.");
        else
            $display("FAIL: chords_tb - %0d mismatches detected.", errors);

        $finish;
    end

endmodule
