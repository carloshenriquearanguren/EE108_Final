module wave_capture (
    input clk,
    input reset,
    input new_sample_ready,
    input [15:0] new_sample_in,
    input wave_display_idle,

    output wire [8:0] write_address,
    output wire write_enable,
    output wire [7:0] write_sample,
    output wire read_index
);
// Implement me!

    localparam ARMED   = 2'd0,
               ACTIVE  = 2'd1,
               WAIT    = 2'd2;

    wire [15:0] sample;
    wire [15:0] previous_sample;
    
    dffre #(16) sampleFF (
        .clk(clk),
        .r(reset),
        .en(new_sample_ready),
        .d(new_sample_in),
        .q(sample)
     );
     
     dffre #(16) previoussampleFF (
        .clk(clk),
        .r(reset),
        .en(new_sample_ready),
        .d(sample),
        .q(previous_sample)
     );
     
     wire crossing;
     assign crossing = (previous_sample[15] == 1) & (sample[15] == 0);
     
     reg next_read_index;
     
     dffr readindexFF (
        .clk(clk),
        .r(reset),
        .d(next_read_index),
        .q(read_index)
     ); 
     
     reg [7:0] next_counter;
     wire [7:0] counter; 
     
     dffre #(8) counterFF (
        .clk(clk),
        .r(reset),
        .en(new_sample_ready),
        .d(next_counter),
        .q(counter)
     );
     
     reg [1:0] next_state;
     wire [1:0] state; 
    
    dffr #(2) capturestateFF (
        .clk(clk),
        .r(reset),
        .d(next_state),
        .q(state)
     );
     
     always @(*) begin
        case (state) 
            ARMED: begin 
                if (crossing) begin
                    next_state = ACTIVE;
                    next_counter = 8'd0;           
                end else begin
                    next_state = ARMED;
                    next_counter = 8'd0;          
                end
                next_read_index = read_index;
            end
            ACTIVE: begin
                next_state = (counter == 8'd255) ? WAIT : ACTIVE;
                next_counter = counter + 1;
                next_read_index = read_index;
            end
            WAIT: begin
                if (wave_display_idle) begin
                    next_state = ARMED;
                    next_read_index = ~read_index;
                end else begin
                    next_state = WAIT;
                    next_read_index = read_index;
                end
                next_counter = 0;
            end
            default: begin
                next_state = ARMED;
                next_counter = 0;
                next_read_index = 0;
            end
         endcase
     end
         
     assign write_address = {~read_index, counter};
     assign write_enable = (state == ACTIVE) & new_sample_ready; 
     assign write_sample = {~sample[15], sample[14:8]};

endmodule
