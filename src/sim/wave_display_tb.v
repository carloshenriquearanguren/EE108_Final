`timescale 1ns/1ps

module wave_display_tb;
    // Clock/reset
    reg clk;
    reg reset;

    // VGA inputs to DUT
    reg  [10:0] x;
    reg  [9:0]  y;
    reg valid;

    // RAM/DUT connections
    wire [8:0]  read_address;
    wire valid_pixel;
    wire [7:0]  r, g, b;

    // Buffer select
    reg read_index;

    // RAM output (1-cycle latency)
    wire [7:0] read_value;

    // vsync signal for testbench
    reg vsync;
    wire wave_display_idle;

    // DUT
    wave_display dut (
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .valid(valid),
        .vsync(vsync),
        .read_value(read_value),
        .read_index(read_index),
        .read_address(read_address),
        .valid_pixel(valid_pixel),
        .wave_display_idle(wave_display_idle),
        .r(r), .g(g), .b(b)
    );

    // Fake display RAM with 1-cycle latency
    fake_display_ram ram (
        .clk(clk),
        .addr(read_address),
        .dout(read_value)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    integer on_count_top  = 0;
    integer on_count_bot  = 0;

    always @(posedge clk) begin
        if (valid && (y[9] == 1'b0) && valid_pixel) on_count_top = on_count_top + 1;
        if (valid && (y[9] == 1'b1) && valid_pixel) on_count_bot = on_count_bot + 1;

        if (valid && valid_pixel) begin
            if (!(r==8'hFF && g==8'hFF && b==8'hFF)) begin
                $display("%t RGB not white at x=%0d y=%0d", $time, x, y);
                $fatal;
            end
        end
    end

    // Tasks 
    task set_x_quarter;
        input [1:0] q;
        input [6:0] idx;
        input lsb;
    begin
        x[10:9] = q;        // 2nd=01, 3rd=10
        x[8] = 1'b0;     // don't care here
        x[7:1] = idx;      // drives address bits
        x[0] = lsb;      // 2-pixel width
    end
    endtask

    task set_y_from_8;
        input top;    // 1=top half, 0=bottom half
        input [7:0] y8;
    begin
        y[9] = ~top;      // top half => y[9]=0
        y[8:1] = y8;        // compare using y[8:1]
        y[0] = 1'b0;      // 2-pixel height
    end
    endtask

    task scan_line_top;
        input [7:0] y8;
        integer i;
    begin
        set_y_from_8(1'b1, y8);
        valid = 1'b1;

        for (i=0; i<128; i=i+1) begin
            set_x_quarter(2'b01, i[6:0], 1'b0); @(posedge clk);
            set_x_quarter(2'b01, i[6:0], 1'b1); @(posedge clk);
        end
        for (i=0; i<128; i=i+1) begin
            set_x_quarter(2'b10, i[6:0], 1'b0); @(posedge clk);
            set_x_quarter(2'b10, i[6:0], 1'b1); @(posedge clk);
        end

        valid = 1'b0;
        repeat (10) @(posedge clk);
    end
    endtask

    task scan_line_bottom;
        input [7:0] y8;
        integer i;
    begin
        set_y_from_8(1'b0, y8);
        valid = 1'b1;

        for (i=0; i<128; i=i+1) begin
            set_x_quarter(2'b01, i[6:0], 1'b0); @(posedge clk);
            set_x_quarter(2'b01, i[6:0], 1'b1); @(posedge clk);
        end
        for (i=0; i<128; i=i+1) begin
            set_x_quarter(2'b10, i[6:0], 1'b0); @(posedge clk);
            set_x_quarter(2'b10, i[6:0], 1'b1); @(posedge clk);
        end

        valid = 1'b0;
        repeat (10) @(posedge clk);
    end
    endtask

    // Stimulus
    initial begin
        $dumpfile("wave_display_tb.vcd");
        $dumpvars(0, wave_display_tb);

        reset = 1'b1;
        valid = 1'b0;
        x = 11'd0;
        y = 10'd0;
        read_index = 1'b0;
        vsync = 1'b0;

        repeat (5) @(posedge clk);
        reset = 1'b0;

        scan_line_top(8'd10);
        scan_line_top(8'd64);
        scan_line_top(8'd128);
        scan_line_top(8'd200);

        scan_line_bottom(8'd64);

        $display("Top-half ON pixels:    %0d", on_count_top);
        $display("Bottom-half ON pixels: %0d", on_count_bot);
        if (on_count_top == 0) begin
            $display("ERROR: No waveform pixels lit in top half.");
            $fatal;
        end
        if (on_count_bot != 0) begin
            $display("ERROR: Pixels lit in bottom half when they should be off.");
            $fatal;
        end

        $display("wave_display_tb PASSED");
        $finish;
    end
endmodule

// 512x8 ROM-like RAM with 1-cycle read latency
// Quarter 2 is rising, quarter 3 is falling (triangle)
// Present in both buffer halves w/ read_index bit

module fake_display_ram (
    input  wire        clk,
    input  wire [8:0]  addr,
    output reg  [7:0]  dout
);
    reg [7:0] mem [0:511];
    integer ri, mb, i;
    integer a;
    reg [7:0] val;

    initial begin
        for (ri = 0; ri < 2; ri = ri + 1) begin
            for (mb = 0; mb < 2; mb = mb + 1) begin
                for (i = 0; i < 128; i = i + 1) begin
                    a   = (ri<<8) | (mb<<7) | i;
                    val = (mb==0) ? (i<<1) : (8'd255 - (i<<1));
                    mem[a] = val;
                end
            end
        end
        dout = 8'd0;
    end

    always @(posedge clk) begin
        dout <= mem[addr]; // 1-cycle latency
    end
endmodule
