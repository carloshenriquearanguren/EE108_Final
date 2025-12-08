## This file is a general .xdc for the PYNQ-Z2 board 
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

## Clock signal 125 MHz

set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { sysclk }]; #IO_L13P_T2_MRCC_35 Sch=sysclk
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { sysclk }];

##Switches
##for AWD
## Switches maps to SWA (sw[0]) to SWH (sw[7])
set_property PACKAGE_PIN V6 [get_ports {h[0]}];	#RPIO_14_R, connector Pin 8, FPGA Signal name RP_IO02				
	set_property IOSTANDARD LVCMOS33 [get_ports {h[0]}]
set_property PACKAGE_PIN Y6 [get_ports {h[1]}];	#RPIO_15_R, connector Pin 10, FPGA Signal name RP_IO10					
	set_property IOSTANDARD LVCMOS33 [get_ports {h[1]}]
set_property PACKAGE_PIN B19 [get_ports {h[2]}];	#RPIO_16_R, connector Pin 36, FPGA Signal name RP_IO20					
	set_property IOSTANDARD LVCMOS33 [get_ports {h[2]}]
set_property PACKAGE_PIN U7 [get_ports {h[3]}];	#RPIO_17_R, connector Pin 11, FPGA Signal name RP_IO03					
	set_property IOSTANDARD LVCMOS33 [get_ports {h[3]}]
set_property PACKAGE_PIN C20 [get_ports {w[0]}];	#RPIO_18_R, connector Pin 12, FPGA Signal name RP_IO18					
	set_property IOSTANDARD LVCMOS33 [get_ports {w[0]}]
set_property PACKAGE_PIN Y8 [get_ports {w[1]}];	#RPIO_19_R, connector Pin 35, FPGA Signal name RP_IO13					
	set_property IOSTANDARD LVCMOS33 [get_ports {w[1]}]
set_property PACKAGE_PIN A20 [get_ports {w[2]}];	#RPIO_20_R, connector Pin 38, FPGA Signal name RP_IO21					
	set_property IOSTANDARD LVCMOS33 [get_ports {w[2]}]
set_property PACKAGE_PIN W9 [get_ports {w[3]}];	#RPIO_26_R, connector Pin 37, FPGA Signal name RP_IO14					
	set_property IOSTANDARD LVCMOS33 [get_ports {w[3]}]

#set_property PACKAGE_PIN M20 [get_ports {enable}];   #Board SW0					
#	set_property IOSTANDARD LVCMOS33 [get_ports {enable}]

set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]; #IO_L7N_T1_AD2N_35 Sch=sw[0]
set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]; #IO_L7P_T1_AD2P_35 Sch=sw[1]

##RGB LEDs

set_property -dict { PACKAGE_PIN L15   IOSTANDARD LVCMOS33 } [get_ports { leds_rgb_0[0] }]; 
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { leds_rgb_0[1] }]; 
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { leds_rgb_0[2] }]; 
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { leds_rgb_1[0] }];
set_property -dict { PACKAGE_PIN L14   IOSTANDARD LVCMOS33 } [get_ports { leds_rgb_1[1] }]; 
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { leds_rgb_1[2] }]; 

##LEDs

set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; #IO_L6N_T0_VREF_34 Sch=led[0]
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; #IO_L6P_T0_34 Sch=led[1]
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; #IO_L21N_T3_DQS_AD14N_35 Sch=led[2]
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; #IO_L23P_T3_35 Sch=led[3]

##Buttons

set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { btn[0] }]; #IO_L4P_T0_35 Sch=btn[0]
set_property -dict { PACKAGE_PIN D20   IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]; #IO_L4N_T0_35 Sch=btn[1]
set_property -dict { PACKAGE_PIN L20   IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]; #IO_L9N_T1_DQS_AD3N_35 Sch=btn[2]
set_property -dict { PACKAGE_PIN L19   IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]; #IO_L9P_T1_DQS_AD3P_35 Sch=btn[3]

##Audio 

set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { AC_ADR0 }]; #IO_L8P_T1_AD10P_35 Sch=adr0
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { AC_ADR1 }]; #IO_L8N_T1_AD10N_35 Sch=adr1

set_property -dict { PACKAGE_PIN U5    IOSTANDARD LVCMOS33 } [get_ports { AC_MCLK }]; #IO_L19N_T3_VREF_13 Sch=au_mclk_r
set_property -dict { PACKAGE_PIN T9    IOSTANDARD LVCMOS33 } [get_ports { AC_SDA  }]; #IO_L12P_T1_MRCC_13 Sch=au_sda_r 
set_property -dict { PACKAGE_PIN U9    IOSTANDARD LVCMOS33 } [get_ports { AC_SCK  }]; #IO_L17P_T2_13 Sch= au_scl_r 
set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { AC_DOUT }]; #IO_L6N_T0_VREF_35 Sch=au_dout_r
set_property -dict { PACKAGE_PIN F17   IOSTANDARD LVCMOS33 } [get_ports { AC_DIN  }]; #IO_L16N_T2_35 Sch=au_din_r 
set_property -dict { PACKAGE_PIN T17   IOSTANDARD LVCMOS33 } [get_ports { AC_WCLK }]; #IO_L20P_T3_34 Sch=au_wclk_r
set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { AC_BCLK }]; #IO_L20N_T3_34 Sch=au_bclk_r

##HDMI Tx
set_property -dict {PACKAGE_PIN L17 IOSTANDARD TMDS_33} [get_ports TMDS_Clk_n]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD TMDS_33} [get_ports TMDS_Clk_p]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_n[0]}]
set_property -dict {PACKAGE_PIN K17 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_p[0]}]
set_property -dict {PACKAGE_PIN J19 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_n[1]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_p[1]}]
set_property -dict {PACKAGE_PIN H18 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_n[2]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD TMDS_33} [get_ports {TMDS_Data_p[2]}]

# Adapter card's button
set_property PACKAGE_PIN V7 [get_ports clkSel];	#RPIO_27_R, connector Pin 13, FPGA Signal name RP_IO04						
	set_property IOSTANDARD LVCMOS33 [get_ports clkSel]


set_false_path -from [get_cells -hier -regexp {adau1761_codec.*}]
