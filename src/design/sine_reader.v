module sine_reader(
    input clk,
    input reset,
    input [19:0] step_size,
    input generate_next,

    output sample_ready,
    output wire [15:0] sample
);

    //implementation goes here!
    wire clk_l;
    assign clk_l = clk;
    wire [21:0] phase, next_phase;
    wire [21:0] phase_inc = {2'b00, step_size};


    dff #(22) phase_ff (.clk(clk_l), .d(next_phase), .q(phase));

    assign next_phase =
        (reset)        ? 22'd0 :
        (generate_next ? (phase + phase_inc) : phase);

    
    wire [1:0] quad = phase[21:20];
    wire [9:0] raw_addr = phase[19:10];
    wire [9:0] mirror_addr = 10'd1023 - raw_addr;

    reg [9:0] rom_addr_c;
    always @(*) begin
        case (quad)
            2'b00: rom_addr_c = raw_addr;       // Quadrant 1 
            2'b01: rom_addr_c = mirror_addr;    // Quadrant 2 
            2'b10: rom_addr_c = raw_addr;       // Quadrant 3 
            2'b11: rom_addr_c = mirror_addr;    // Quadrant 4 
            default: rom_addr_c = raw_addr;
        endcase
    end

    //--------------------------------------------------
    wire [15:0] rom_data;
    sine_rom ROM (.clk(clk_l), .addr(rom_addr_c), .dout(rom_data));


    wire [1:0] quad_d, next_quad_d;
    assign next_quad_d = quad;
    dff #(2) quad_ff (.clk(clk_l), .d(next_quad_d), .q(quad_d));

    reg [15:0] signed_sample_c;
    always @(*) begin
        case (quad_d)
            2'b00, 2'b01: signed_sample_c =  rom_data; // + half
            2'b10, 2'b11: signed_sample_c = -rom_data; // - half
            default:       signed_sample_c =  rom_data;
        endcase
    end

    dff #(16) sample_ff (.clk(clk_l), .d(signed_sample_c), .q(sample));

    assign sample_ready = generate_next;

endmodule