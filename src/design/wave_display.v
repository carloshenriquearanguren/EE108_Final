module wave_display (
    input clk,
    input reset,
    input [10:0] x,  // [0..1279]
    input [9:0]  y,  // [0..1023]
    input valid,
    input [7:0] read_value,
    input read_index,
    output wire [8:0] read_address,
    output wire valid_pixel,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);

    // Region gating (2nd & 3rd quarters, top half), 2-pixel-wide X by dropping x[0]
    wire quarter2 = (x[9:8] == 2'b01); // 2nd quarter
    wire quarter3 = (x[9:8]== 2'b10); // 3rd quarter
    wire top_half = (y[9]== 1'b0); // MSB of y is 0 => top half
    wire invalid_bit = (x <= 11'b00100000011);
    wire in_window = valid & top_half & (quarter2 | quarter3) & ~invalid_bit;

    // X -> RAM address mapping (9 bits): {read_index, mid_bit, x[7:1]}
    // mid_bit = 0 in 2nd quarter, 1 in 3rd quarter
    
    wire mid_bit = quarter3; // 0 for Q2, 1 for Q3
    wire [6:0] addr_low = x[7:1]; // drop LSB x[0] for 2-pixel width
    wire [8:0] addr_next = {read_index, mid_bit, addr_low};
    assign read_address = addr_next;

    // 800x480 amplitude fix: scale 0..255 to ~0..239 (multiply by 15/16)
    // read_value_adjusted = read_value/2 + 32 
    wire [7:0] read_value_adjusted = (read_value >> 1) + 8'd32;

    // Handle 1-cycle RAM latency and avoid reusing the same sample twice:
    // latch a new RAM sample only when read_address changes.
    // Keep previous and current samples for vertical span check.

    wire [8:0] ra_last;
    wire [7:0] sample_prev, sample_curr;
    wire addr_change = (addr_next != ra_last);

    // ra_last 
    dffre #(9) ra_last_ff (
        .clk(clk),
        .r(reset),
        .en(addr_change),
        .d(addr_next),
        .q(ra_last)
    );

    // sample_prev 
    dffre #(8) sample_prev_ff (
        .clk(clk),
        .r(reset),
        .en(addr_change),
        .d(sample_curr),            
        .q(sample_prev)
    );
    // sample_curr
    dffre #(8) sample_curr_ff (
        .clk(clk),
        .r(reset),
        .en(addr_change),
        .d(read_value_adjusted),  
        .q(sample_curr)
    );

    // Y mapping: use y[8:1] to get 8-bit value in the top half, 2-pixel-high stroke
    // Pixel is on if y falls between the two adjacent samples
    
    wire [7:0] y8 = y[8:1];
    wire [7:0] lo = (sample_curr < sample_prev) ? sample_curr : sample_prev;
    wire [7:0] hi = (sample_curr < sample_prev) ? sample_prev : sample_curr;
    
    assign valid_pixel = in_window & (y8 >= lo) & (y8 <= hi);

    // White for waveform, black otherwise
    assign r = valid_pixel ? 8'hFF : 8'h00;
    assign g = valid_pixel ? 8'hFF : 8'h00;
    assign b = valid_pixel ? 8'hFF : 8'h00;


endmodule
