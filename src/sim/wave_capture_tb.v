module wave_capture_tb();
    reg clk;
    reg reset;
    reg new_sample_ready;
    reg [15:0] new_sample_in;
    reg wave_display_idle;

    wire [8:0] write_address;
    wire write_enable;
    wire [7:0] write_sample;
    wire read_index;

    reg [7:0] addr;
    wire [7:0] dout;

    wave_capture dut (
        .clk(clk),
        .reset(reset),
        .new_sample_ready(new_sample_ready),
        .new_sample_in(new_sample_in),
        .wave_display_idle(wave_display_idle),
        .write_address(write_address),
        .write_enable(write_enable),
        .write_sample(write_sample),
        .read_index(read_index)
    );

    fake_sample_ram ram (
        .clk(clk),
        .addr(addr),
        .dout(dout)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        reset = 1;
        new_sample_ready = 0;
        new_sample_in = 16'd0;
        wave_display_idle = 0;
        addr = 0;

        #20;
        reset = 0;

        // Send negative samples
        repeat (3) send_sample(16'hF000); 

        // Positive sample triggers zero crossing
        send_sample(16'h0100);

        // DUT should enter ACTIVE 
        repeat (10) send_sample($random);

        repeat (240) send_sample(16'h0200);

        // Enter WAIT state 
        #50;
        wave_display_idle = 1;  // simulate display done
        #20;
        wave_display_idle = 0;
    end

    task send_sample(input [15:0] val);
    begin
        @(posedge clk);
        new_sample_in = val;
        new_sample_ready = 1;
        @(posedge clk);
        new_sample_ready = 0;
    end
    endtask

endmodule
