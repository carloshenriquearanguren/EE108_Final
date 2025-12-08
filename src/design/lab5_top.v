module lab5_top(
    // System Clock (125MHz)
    input sysclk,
    
    // ADAU_1761 interface
    output  AC_ADR0,            // I2C Address pin (DO NOT CHANGE)
    output  AC_ADR1,            // I2C Address pin (DO NOT CHANGE)
    
    output  AC_DOUT,           // I2S Signals
    input   AC_DIN,            // I2S Signals
    input   AC_BCLK,           // I2S Byte Clock
    input   AC_WCLK,           // I2S Channel Clock
    
    output  AC_MCLK,            // Master clock (48MHz)
    output  AC_SCK,             // I2C SCK
    inout   AC_SDA,             // I2C SDA 
    
    // LEDs
    output wire [3:0] led,
    output wire [2:0] leds_rgb_0,
    output wire [2:0] leds_rgb_1,

    // Buttons: btn[0]=reset, btn[1]=play, btn[2]=next, btn[3]=reverse
    input [3:0] btn,

    // Echo control switches
    input [1:0] sw, // SW0 / SW1 for echo
    
    // HDMI output
    output TMDS_Clk_p,
    output TMDS_Clk_n,
    output [2:0] TMDS_Data_p,
    output [2:0] TMDS_Data_n,
    
    // for Advanced waveform display
    input [3:0] h,
    input [3:0] w,

    // btna_b on Pi adapter (fast mode toggle)
    input clkSel
);  

    wire reset, play_button, next_button, reverse_button;
    assign reset         = btn[0];
    assign play_button   = btn[1];
    assign next_button   = btn[2];
    assign reverse_button= btn[3];

    // Clock converter
    wire clk_100, display_clk, serial_clk;
    wire LED0;      // locked signal
    
    clk_wiz_0 U2 (
        .clk_out1(clk_100),     // 100 MHz
        .clk_out2(display_clk), // 30 MHz
        .clk_out3(serial_clk),  // 150 Mhz
        .reset(reset),
        .locked(LED0),
        .clk_in1(sysclk)
    );

    // button_press_unit's WIDTH parameter is exposed here so that you can
    // reduce it in simulation.  Setting it to 1 effectively disables it.
    parameter BPU_WIDTH = 20;
    // The BEAT_COUNT is parameterized so you can reduce this in simulation.
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
 
//   ****************************************************************************
//      Button processor units
//   ****************************************************************************
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

    wire reverse;
    button_press_unit #(.WIDTH(BPU_WIDTH)) reverse_button_press_unit(
        .clk(clk_100),
        .reset(reset),
        .in(reverse_button),
        .out(reverse)
    );

    // Fast mode toggle from btna_b (Pi adapter)
    wire fast_toggle;
    button_press_unit #(.WIDTH(BPU_WIDTH)) fast_button_press_unit(
        .clk(clk_100),
        .reset(reset),
        .in(clkSel),
        .out(fast_toggle)
    );
       
//   ****************************************************************************
//      The music player
//   ****************************************************************************
    wire new_frame, new_frame1;
    wire [15:0] codec_sample_raw, codec_sample, flopped_sample;
    wire new_sample, flopped_new_sample;
    
    music_player #(.BEAT_COUNT(BEAT_COUNT)) music_player(
        .clk(clk_100),
        .reset(reset),
        .play_button(play),
        .next_button(next),
        .reverse_button(reverse),
        .fast_button(fast_toggle),   // NEW
        .new_frame(new_frame1), 
        .sample_out(codec_sample_raw),
        .new_sample_generated(new_sample)
    );
    
    // Frame sync pipeline
    dffr pipeline_ff_new_frame (.clk(clk_100), .r(reset), .d(new_frame), .q(new_frame1));

//   ****************************************************************************
//      Echo Effect (SW0 / SW1)
//   ****************************************************************************
    // At 48 kHz: 100 ms ≈ 4800 samples, 300 ms ≈ 14400, 500 ms ≈ 24000.
    wire echo_enable;
    wire [14:0] delay_samples;
    wire [2:0]  atten_shift;

    // SW0 = ~300 ms, louder echo (÷2)
    // SW1 = ~500 ms, softer echo (÷4)
    assign echo_enable   = sw[0] | sw[1];
    assign delay_samples = sw[1] ? 15'd24000 :   // ~500 ms
                          (sw[0] ? 15'd14400 :  // ~300 ms
                                    15'd0);
    assign atten_shift   = sw[1] ? 3'd3 :        // ÷8
                          (sw[0] ? 3'd2 :        // ÷4
                                    3'd3);       // default (unused when echo_enable=0)

    echo #(
        .SAMPLE_WIDTH(16),
        .ADDR_BITS(15)
    ) echo_inst (
        .clk(clk_100),
        .reset(reset),
        .new_sample_ready(new_sample),
        .in_sample(codec_sample_raw),
        .echo_enable(echo_enable),
        .delay_samples(delay_samples),
        .atten_shift(atten_shift),
        .out_sample(codec_sample)
    );

    // Sample register for waveform display
    dff #(.WIDTH(17)) sample_reg (
        .clk(clk_100),
        .d({new_sample, codec_sample}),
        .q({flopped_new_sample, flopped_sample})
    );

//   ****************************************************************************
//      Codec interface
//   ****************************************************************************
    wire [23:0] hphone_r = 0;
    wire [23:0] line_in_l = 0;  
    wire [23:0] line_in_r = 0; 
    
    // Output the sample onto the LEDs for the fun of it.
    assign leds_rgb_0 = {sw[1], sw[0], 1'b0};      // show echo mode
    assign leds_rgb_1 = codec_sample[15:13];
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
        .hphone_l({codec_sample, 8'h00}),
        .hphone_r(hphone_r),
        .line_in_l(line_in_l),
        .line_in_r(line_in_r),
        .new_sample(new_frame)
    );  
    
//   ****************************************************************************
//      Display management
//   ****************************************************************************
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
        .clk(clk_100),
        .reset(reset),
        .new_sample(new_sample),
        .sample(flopped_sample),
        .x(x[10:0]),
        .y(y[9:0]),
        .valid(vde),
        .vsync(vsync),
        .r(r_1),
        .g(g_1),
        .b(b_1),
        .w(w),
        .h(h)
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
