module echo #(
    parameter SAMPLE_WIDTH = 16,
    parameter ADDR_BITS    = 15      // 2^15 samples max delay
)(
    input  wire clk,
    input  wire reset,

    input  wire new_sample_ready,
    input  wire signed [SAMPLE_WIDTH-1:0] in_sample,

    input  wire echo_enable,
    input  wire [ADDR_BITS-1:0] delay_samples,
    input  wire [2:0] atten_shift,

    output wire signed [SAMPLE_WIDTH-1:0] out_sample
);

    localparam DEPTH = 1 << ADDR_BITS;

    // pointers and input pipeline
    wire [ADDR_BITS-1:0] wr_ptr_q, wr_ptr_d;
    wire [ADDR_BITS-1:0] rd_addr_q, rd_addr_d;
    wire signed [SAMPLE_WIDTH-1:0] in_q_q, in_q_d;
    wire signed [SAMPLE_WIDTH-1:0] out_q, out_d;

    wire en = new_sample_ready;

    // next-state logic for pointers and input register
    assign wr_ptr_d  = wr_ptr_q + 1'b1;
    assign rd_addr_d = wr_ptr_q - delay_samples;
    assign in_q_d    = in_sample;

    dffre #(ADDR_BITS) wr_ptr_ff (.clk(clk), .r(reset), .en(en), .d(wr_ptr_d),  .q(wr_ptr_q));
    dffre #(ADDR_BITS) rd_ff     (.clk(clk), .r(reset), .en(en), .d(rd_addr_d), .q(rd_addr_q));
    dffre #(SAMPLE_WIDTH) in_ff  (.clk(clk), .r(reset), .en(en), .d(in_q_d),    .q(in_q_q));
    dffre #(SAMPLE_WIDTH) out_ff (.clk(clk), .r(reset), .en(en), .d(out_d),     .q(out_q));

    // simple 1R/1W dual-port RAM model (sync read)
    reg signed [SAMPLE_WIDTH-1:0] ram [0:DEPTH-1];
    reg signed [SAMPLE_WIDTH-1:0] ram_q;

    always @(posedge clk) begin
        if (en) begin
            ram[wr_ptr_q] <= in_sample;
            ram_q         <= ram[rd_addr_q];
        end
    end

    // dry + wet mix
    wire signed [SAMPLE_WIDTH-1:0] wet_shifted = ram_q >>> atten_shift;

    wire signed [SAMPLE_WIDTH:0] dry_ext =
        {in_q_q[SAMPLE_WIDTH-1], in_q_q};  // sign-extend
    wire signed [SAMPLE_WIDTH:0] wet_ext =
        echo_enable ?
            {wet_shifted[SAMPLE_WIDTH-1], wet_shifted} :
            { (SAMPLE_WIDTH+1){1'b0} };

    wire signed [SAMPLE_WIDTH:0] mix_wide = dry_ext + wet_ext;

    // saturation using overflow detection on top two bits
    wire pos_ovf = (mix_wide[SAMPLE_WIDTH] == 1'b0) &&
                   (mix_wide[SAMPLE_WIDTH-1] == 1'b1);
    wire neg_ovf = (mix_wide[SAMPLE_WIDTH] == 1'b1) &&
                   (mix_wide[SAMPLE_WIDTH-1] == 1'b0);

    reg signed [SAMPLE_WIDTH-1:0] mix_sat;

    always @* begin
        if (pos_ovf)
            mix_sat = {1'b0, {(SAMPLE_WIDTH-1){1'b1}}}; // +32767
        else if (neg_ovf)
            mix_sat = {1'b1, {(SAMPLE_WIDTH-1){1'b0}}}; // -32768
        else
            mix_sat = mix_wide[SAMPLE_WIDTH-1:0];
    end

    assign out_d      = mix_sat;
    assign out_sample = out_q;

endmodule
