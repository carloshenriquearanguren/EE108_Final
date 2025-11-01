module sine_reader_tb();

    reg clk, reset, generate_next;
    reg [19:0] step_size;
    wire sample_ready;
    wire [15:0] sample;
    sine_reader reader(
        .clk(clk),
        .reset(reset),
        .step_size(step_size),
        .generate_next(generate_next),
        .sample_ready(sample_ready),
        .sample(sample)
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
        reset = 1'b1;
        generate_next = 1'b0;
        step_size = 20'd1024;  // 10.10 fixed-point step (medium frequency)

        // Hold reset high for a short time
        #100;
        reset = 1'b0;
        $display("[%0t] Reset deasserted.", $time);

        
        repeat (500) begin
            generate_next = 1'b1;
            #10;
            generate_next = 1'b0;
            #1000;   // wait between samples (~1 µs spacing)
        end

        // higher frequency 

        step_size = 20'd2048;
        repeat (500) begin
            generate_next = 1'b1;
            #10;
            generate_next = 1'b0;
            #1000;
        end

        $display("[%0t] Simulation complete.", $time);
        $finish;
    end

    always begin
        #10000; // every 10 µs
        $display("[%0t] sample=%0d", $time, sample);
    end

endmodule

