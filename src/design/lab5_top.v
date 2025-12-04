module lab5_top(
    /*
    'define H_SYNC_PULSE 112
    'define H_BACK_PORCH 248
    'define H_FRONT_PORCH 48
    'define V_SYNC_PULSE 3
    'define V_BACK_PORCH 38
    'define V_FRONT_PORCH 1
    */ 	  

    // System Clock (125MHz)
    input sysclk,
    	 
    // ADAU_1761 interface
    output  AC_ADR0,            // I2C Address pin (DO NOT CHANGE)
    output  AC_ADR1,            // I2C Address pin (DO NOT CHANGE)
    
    output  AC_DOUT,            // I2S Signals
    input   AC_DIN,             // I2S Signals
    input   AC_BCLK,            // I2S Byte Clock
    input   AC_WCLK,            // I2S Channel Clock
    
    output  AC_MCLK,            // Master clock (48MHz)
    output  AC_SCK,             // I2C SCK
    inout   AC_SDA,             // I2C SDA 
    
    // LEDs
    output wire [3:0] led,
    output wire [2:0] leds_rgb_0,
    output wire [2:0] leds_rgb_1,

    input [2:0] btn,

    // *** NEW: on-board switches and extension button ***
    input [1:0] sw,       // sw[0]=echo enable, sw[1]=attenuation
    input       clkSel,   // BTNA_B from extension (delay step)

    /* 
    //VGA OUTPUT 
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B,
    output VGA_HS,
    output VGA_VS*/
  
    // HDMI output
    output TMDS_Clk_p,
    output TMDS_Clk_n,
    output [2:0] TMDS_Data_p,
    output [2:0] TMDS_Data_n
    
    // TODO: output LED0 onto something
  
);  

    wire reset, play_button, next_button;
    assign {reset, play_button, next_button} = btn;

    // Clock converter
    wire clk_100, display_clk, serial_clk;
    wire LED0;      // TODO: assign this to a real LED
 
    clk_wiz_0 U2 (
        .clk_out1(clk_100),     // 100 MHz
        .clk_out2(display_clk),	// 30 MHz
        .clk_out3(serial_clk),	// 150 Mhz
        .reset(reset),
        .locked(LED0),
        .clk_in1(sysclk)
    );

  
    // button_press_unit's WIDTH parameter is exposed here so that you can
    // reduce it in simulation.  Setting it to 1 effectively disables it.
    parameter BPU_WIDTH = 20;
    // The BEAT_COUNT is parameterized so you can reduce this in simulation.
    // If you reduce this to 100 your simulation will be 10x faster.
    parameter BEAT_COUNT = 1000;

   
    // These signals are for determining which color to display
    wire [11:0] x;  // [0..1279]
    wire [11:0] y;  // [0..1023] 
    
    // Color to display at the given x,y
    wire [31:0] pix_data;
    wire [3:0]  r, g, b;
    wire [7:0] r_1, g_1, b_1;
      
    wire [3:0] VGA_R;
    wire [3:0] VGA_G;
    wire [3:0] VGA_B;
    wire VGA_HS;
    wire VGA_VS;
 
//   
//  ****************************************************************************
//      Button processor units
//  ****************************************************************************
//  
    wire play;
    button_press_unit #(.WIDTH(BPU_WIDTH)) play_button_press_unit(
        .clk(clk_100),
        .reset(reset),
        .in(play_button),
        .out(play)
    );

    wire next;
    button_press_unit #(.WIDTH(BPU_WIDTH)) next_button_press_unit(
        .clk(clk_100),
        .reset(reset),
        .in(next_button),
        .out(next)
    );

    // *** NEW: debounced one-pulse from extension button for delay stepping ***
    wire echo_delay_step;
    button_press_unit #(.WIDTH(BPU_WIDTH)) echo_delay_button (
        .clk(clk_100),
        .reset(reset),
        .in(clkSel),
        .out(echo_delay_step)
    );
       
//   
//  ****************************************************************************
//      The music player
//  ****************************************************************************
//       
    wire new_frame, new_frame1;
    wire [15:0] codec_sample, flopped_sample;
    wire new_sample, flopped_new_sample;
    music_player #(.BEAT_COUNT(BEAT_COUNT)) music_player(
        .clk(clk_100),
        .reset(reset),
        .play_button(play),
        .next_button(next),
        .new_frame(new_frame1), 
        .sample_out(codec_sample),
        .new_sample_generated(new_sample)
    );
    dff #(.WIDTH(17)) sample_reg (
        .clk(clk_100),
        .d({new_sample, codec_sample}),
        .q({flopped_new_sample, flopped_sample})
    );
    dffr pipeline_ff_new_frame (.clk(clk_100), .r(reset), .d(new_frame), .q(new_frame1));

    // *** NEW: Echo effect controlled by sw[1:0] and clkSel ***

    // Dry input to echo is codec_sample from music_player
    wire signed [15:0] echo_in  = codec_sample;
    wire signed [15:0] echo_out;

    // SW0: echo enable
    wire echo_enable = sw[0];

    // SW1: attenuation level: 0 -> /2 (louder), 1 -> /4 (softer)
    reg [2:0] echo_atten_sh;
    always @(*) begin
        if (sw[1] == 1'b0)
            echo_atten_sh = 3'd1;   // 1/2
        else
            echo_atten_sh = 3'd2;   // 1/4
    end

    // Delay mode: 2-bit counter advanced by echo_delay_step (BTNA_B)
    reg [1:0] delay_mode;
    always @(posedge clk_100 or posedge reset) begin
        if (reset)
            delay_mode <= 2'b00;
        else if (echo_delay_step)
            delay_mode <= delay_mode + 2'b01;
    end

    // Map delay_mode to concrete delay lengths
    reg [14:0] echo_delay;
    always @(*) begin
        case (delay_mode)
            2'b00: echo_delay = 15'd2400;   // shortest ~50 ms
            2'b01: echo_delay = 15'd4800;   // ~100 ms
            2'b10: echo_delay = 15'd9600;   // ~200 ms
            2'b11: echo_delay = 15'd14400;  // ~300 ms
        endcase
    end

    echo #(
        .SAMPLE_WIDTH(16),
        .ADDR_BITS(15)
    ) echo_inst (
        .clk(clk_100),
        .reset(reset),
        .new_sample_ready(new_sample),
        .in_sample(echo_in),
        .echo_enable(echo_enable),
        .delay_samples(echo_delay),
        .atten_shift(echo_atten_sh),
        .out_sample(echo_out)
    );

//   
//  ****************************************************************************
//      Codec interface
//  ****************************************************************************
//  
    wire [23:0] hphone_r = 0;
    wire [23:0] line_in_l = 0;  
    wire [23:0] line_in_r =  0; 
	
    // Output the (dry) sample onto the LEDs for the fun of it.
    // You can change these to echo_out if you want to see echoed levels.
    assign leds_rgb_0 = codec_sample[15:13];
    assign leds_rgb_1 = codec_sample[11:9];
    assign led        = codec_sample[15:12];

    adau1761_codec adau1761_codec(
        .clk_100(clk_100),
        .reset(reset),
        .AC_ADR0(AC_ADR0),
        .AC_ADR1(AC_ADR1),
        .I2S_MISO(AC_DOUT),
        .I2S_MOSI(AC_DIN),
        .I2S_bclk(AC_BCLK),
        .I2S_LR(AC_WCLK),
        .AC_MCLK(AC_MCLK),
        .AC_SCK(AC_SCK),
        .AC_SDA(AC_SDA),
        // *** NEW: feed echoed audio to headphone left ***
        .hphone_l({echo_out, 8'h00}),   // was {codec_sample, 8'h00}
        .hphone_r(hphone_r),
        .line_in_l(line_in_l),
        .line_in_r(line_in_r),
        .new_sample(new_frame)
    );  
    
//   
//  ****************************************************************************
//      Display management
//  ****************************************************************************
//  
 
    //==========================================================================
    // Display management -> do not touch!
    //==========================================================================
	 
//	wire valid, de;
//    vga_generator vga_g (
//        .clk(clk_100),
//        .r(r), 
//        .g(g),
//        .b(b),
//        .color({r_1, g_1, b_1}),
//        .xpos(x),
//        .ypos(y),
//        .valid(valid),
//        .de(de),
//        .vsync(VGA_VS),
//        .hsync(VGA_HS)
//    );

    wire vde, hsync, vsync, blank;
    vga_controller_800x480_60 vga_control (
        .pixel_clk(display_clk),
        .rst(reset),
        .HS(hsync),
        .VS(vsync),
        .VDE(vde),
        .hcount(x),
        .vcount(y),
        .blank(blank)
    );
    
    
    
    
    wave_display_top wd_top (
		.clk (clk_100),
		.reset (reset),
		.new_sample (new_sample),
		.sample (flopped_sample),
        .x(x[10:0]),
        .y(y[9:0]),
        //.valid(valid),
		.valid(vde),
		.vsync(vsync),
		.r(r_1),
		.g(g_1),
		.b(b_1)
    );
    
    assign r = r_1[7:4];
    assign g = g_1[7:4];
    assign b = b_1[7:4];
    assign pix_data = {
                        8'b0, 
                        r[3], r[3], r[2], r[2], r[1], r[1], r[0], r[0],
                        g[3], g[3], g[2], g[2], g[1], g[1], g[0], g[0],
                        b[3], b[3], b[2], b[2], b[1], b[1], b[0], b[0]
                       }; 
                  
    hdmi_tx_0 U3 (
        .pix_clk(display_clk),
        .pix_clkx5(serial_clk),
        .pix_clk_locked(LED0),
        .rst(reset),
        .pix_data(pix_data),
        .hsync(hsync),
        .vsync(vsync),
        .vde(vde),
        .TMDS_CLK_P(TMDS_Clk_p),
        .TMDS_CLK_N(TMDS_Clk_n),
        .TMDS_DATA_P(TMDS_Data_p),
        .TMDS_DATA_N(TMDS_Data_n)
    );
   
endmodule
