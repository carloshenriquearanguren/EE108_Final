module wave_display (
    input clk,
    input reset,
    input [10:0] x,  // [0..1279]
    input [9:0]  y,  // [0..1023]
    input valid,
    input vsync,
    input [7:0] read_value,
    input read_index,
    //for awd
    input [3:0] w,
    input [3:0] h,
    output wire [8:0] read_address,
    output wire valid_pixel,
    output wire wave_display_idle,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);

    // Region gating (2nd & 3rd quarters, top half), 2-pixel-wide X by dropping x[0]
    wire quarter2 = (x[9:8] == 2'b01); // 2nd quarter
    wire quarter3 = (x[9:8]== 2'b10); // 3rd quarter
    wire top_half = (y[9]== 1'b0); // MSB of y is 0 => top half
    wire bottom_half = (y[9] == 1'b1); //MSB of y is 1 => bottom half
    wire invalid_bit = 0;//(x <= 11'b00100000011 & x >= 11'b00100000001) | (x <= 11'b10000000011 & x >= 11'b10000000001);
    wire quarter4 = (x[9:8] == 2'b11);
    wire quarter1 = (x[9:8] == 2'b00);
    reg in_window;
    always @(*) begin
        case(h)
            4'b0001: in_window = valid & top_half & (quarter1) & ~invalid_bit;
            4'b0010: in_window = valid & top_half & (quarter1 | quarter2) & ~invalid_bit;
            4'b0100: in_window = valid & top_half & (quarter1| quarter2 | quarter3) & ~invalid_bit;
            4'b1000: in_window = valid & top_half & (quarter1 | quarter2| quarter3 | quarter4) & ~invalid_bit;
            default: in_window = valid & top_half & (quarter1) & ~invalid_bit;
        endcase
    end
    //wire in_window = valid & top_half & (quarter2 | quarter3) & ~invalid_bit;

    // X -> RAM address mapping (9 bits): {read_index, mid_bit, x[7:1]}
    // mid_bit = 0 in 2nd quarter, 1 in 3rd quarter
    
    wire mid_bit = x[8] & quarter3;//quarter3; // 0 for Q2, 1 for Q3
    wire [6:0] addr_low = x[7:1]; // drop LSB x[0] for 2-pixel width
    wire [8:0] addr_next = {read_index, mid_bit, addr_low};
    assign read_address = addr_next;

    // 800x480 amplitude fix: scale 0..255 to ~0..239 (multiply by 15/16)
    // read_value_adjusted = read_value/2 + 32 
    reg [7:0] read_value_adjusted;
    always @(*) begin
        case (w)
            4'b0001: read_value_adjusted = (read_value >> 1) + 8'd32;
            4'b0010: read_value_adjusted = (read_value >> 2) + 8'd32;
            4'b0100: read_value_adjusted = (read_value >> 3) + 8'd32;
            4'b1000: read_value_adjusted = read_value;
            default: read_value_adjusted = read_value;
        endcase 
    end
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

    // Generate wave_display_idle signal during vsync (vertical blanking)
    // This allows wave_capture to safely switch buffers between frames
    assign wave_display_idle = vsync;

endmodule

