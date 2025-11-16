
# This is the constraints for the cubeflight circuit board.
# Clock
set_property -dict { PACKAGE_PIN E11    IOSTANDARD LVCMOS33 } [get_ports { clk_ext }]; # Clock
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk_ext }];

# CDC Constraints - Declare clock domains as asynchronous
set_clock_groups -asynchronous \
    -group [get_clocks clk_out_unbuf] \
    -group [get_clocks clk_out_unbuf_1]

# GPIO
set_property -dict { PACKAGE_PIN C3    IOSTANDARD LVCMOS33 } [get_ports { done }]; # GPIO 0
# set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { vga_green[0] }]; # GPIO 1
set_property -dict { PACKAGE_PIN D5    IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]; # GPIO 2
set_property -dict { PACKAGE_PIN C6    IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]; # GPIO 3
set_property -dict { PACKAGE_PIN C7    IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]; # GPIO 4
set_property -dict { PACKAGE_PIN D8    IOSTANDARD LVCMOS33 } [get_ports { sw[3] }]; # GPIO 5

# GPIO MCU
# set_property -dict { PACKAGE_PIN J16    IOSTANDARD LVCMOS33 } [get_ports { reset }]; # GPIO MCU 1
# set_property -dict { PACKAGE_PIN J15    IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]; # GPIO MCU 2
# set_property -dict { PACKAGE_PIN G16    IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]; # GPIO MCU 3
set_property -dict { PACKAGE_PIN D16    IOSTANDARD LVCMOS33 } [get_ports { reset }]; # GPIO MCU 4

# MCU SPI
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets spi_sclk_IBUF]; # Disable routing to a dedicated clock pin. Vivado thinks this is a global clock. It is not.
set_property -dict { PACKAGE_PIN H13    IOSTANDARD LVCMOS33 } [get_ports { spi_miso }]; # MCU SPI MISO
set_property -dict { PACKAGE_PIN H12    IOSTANDARD LVCMOS33 } [get_ports { spi_mosi }]; # MCU SPI MOSI
set_property -dict { PACKAGE_PIN H14    IOSTANDARD LVCMOS33 } [get_ports { spi_ssn }]; # MCU SPI SSN
set_property -dict { PACKAGE_PIN H16    IOSTANDARD LVCMOS33 } [get_ports { spi_sclk }]; # MCU SPI SCLK

# VGA
set_property -dict { PACKAGE_PIN T9   IOSTANDARD LVCMOS33 } [get_ports { vga_red[0] }]; # VGA blue[0]
set_property -dict { PACKAGE_PIN T8   IOSTANDARD LVCMOS33 } [get_ports { vga_red[1] }]; # VGA blue[1]
set_property -dict { PACKAGE_PIN T7   IOSTANDARD LVCMOS33 } [get_ports { vga_red[2] }]; # VGA blue[2]
set_property -dict { PACKAGE_PIN T5   IOSTANDARD LVCMOS33 } [get_ports { vga_red[3] }]; # VGA blue[3]


set_property -dict { PACKAGE_PIN T4   IOSTANDARD LVCMOS33 } [get_ports { vga_green[0] }]; # VGA green[0]
set_property -dict { PACKAGE_PIN T3   IOSTANDARD LVCMOS33 } [get_ports { vga_green[1] }]; # VGA green[1]
set_property -dict { PACKAGE_PIN T2   IOSTANDARD LVCMOS33 } [get_ports { vga_green[2] }]; # VGA green[2]
set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports { vga_green[3] }]; # VGA green[3]

set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33 } [get_ports { vga_blue[0] }]; # VGA red[0]
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { vga_blue[1] }]; # VGA red[1]
set_property -dict { PACKAGE_PIN T13   IOSTANDARD LVCMOS33 } [get_ports { vga_blue[2] }]; # VGA red[2]
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { vga_blue[3] }]; # VGA red[3]

set_property -dict { PACKAGE_PIN R15   IOSTANDARD LVCMOS33 } [get_ports { vga_hsync }]; # VGA hsync
set_property -dict { PACKAGE_PIN R13   IOSTANDARD LVCMOS33 } [get_ports { vga_vsync }]; # VGA vsync


# Screen
# set_property -dict { PACKAGE_PIN C13   IOSTANDARD LVCMOS33 } [get_ports { screen_red[0] }]; # Screen red[0]
# set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { screen_red[1] }]; # Screen red[1]
# set_property -dict { PACKAGE_PIN C11   IOSTANDARD LVCMOS33 } [get_ports { screen_red[2] }]; # Screen red[2]
# set_property -dict { PACKAGE_PIN C9   IOSTANDARD LVCMOS33 } [get_ports { screen_red[3] }]; # Screen red[3]
# set_property -dict { PACKAGE_PIN C8   IOSTANDARD LVCMOS33 } [get_ports { screen_red[4] }]; # Screen red[4]

# set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS33 } [get_ports { screen_green[0] }]; # Screen green[0]
# set_property -dict { PACKAGE_PIN B15   IOSTANDARD LVCMOS33 } [get_ports { screen_green[1] }]; # Screen green[1]
# set_property -dict { PACKAGE_PIN B14   IOSTANDARD LVCMOS33 } [get_ports { screen_green[2] }]; # Screen green[2]
# set_property -dict { PACKAGE_PIN B12   IOSTANDARD LVCMOS33 } [get_ports { screen_green[3] }]; # Screen green[3]
# set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { screen_green[4] }]; # Screen green[4]
# set_property -dict { PACKAGE_PIN B10   IOSTANDARD LVCMOS33 } [get_ports { screen_green[5] }]; # Screen green[5]

# set_property -dict { PACKAGE_PIN B9   IOSTANDARD LVCMOS33 } [get_ports { screen_blue[0] }]; # Screen blue[0]
# set_property -dict { PACKAGE_PIN A15   IOSTANDARD LVCMOS33 } [get_ports { screen_blue[1] }]; # Screen blue[1]
# set_property -dict { PACKAGE_PIN A14   IOSTANDARD LVCMOS33 } [get_ports { screen_blue[2] }]; # Screen blue[2]
# set_property -dict { PACKAGE_PIN A13   IOSTANDARD LVCMOS33 } [get_ports { screen_blue[3] }]; # Screen blue[3]
# set_property -dict { PACKAGE_PIN A12   IOSTANDARD LVCMOS33 } [get_ports { screen_blue[4] }]; # Screen blue[4]

# set_property -dict { PACKAGE_PIN A10   IOSTANDARD LVCMOS33 } [get_ports { screen_clk }]; # Screen clk[0]
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { screen_enable }]; # Screen enable
# set_property -dict { PACKAGE_PIN A7   IOSTANDARD LVCMOS33 } [get_ports { screen_hsync }]; # Screen hsync
# set_property -dict { PACKAGE_PIN A5   IOSTANDARD LVCMOS33 } [get_ports { screen_vsync }]; # Screen vsync
# set_property -dict { PACKAGE_PIN A8   IOSTANDARD LVCMOS33 } [get_ports { screen_data_enable }]; # Data enable


# # SRAM A
# set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { srama_a0 }]; # SRAM B Address 0
# set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { srama_a1 }]; # SRAM B Address 1
# set_property -dict { PACKAGE_PIN P1   IOSTANDARD LVCMOS33 } [get_ports { srama_a2 }]; # SRAM B Address 2
# set_property -dict { PACKAGE_PIN P3   IOSTANDARD LVCMOS33 } [get_ports { srama_a3 }]; # SRAM B Address 3
# set_property -dict { PACKAGE_PIN P4   IOSTANDARD LVCMOS33 } [get_ports { srama_a4 }]; # SRAM B Address 4
# set_property -dict { PACKAGE_PIN P5   IOSTANDARD LVCMOS33 } [get_ports { srama_a5 }]; # SRAM B Address 5
# set_property -dict { PACKAGE_PIN P6   IOSTANDARD LVCMOS33 } [get_ports { srama_a6 }]; # SRAM B Address 6
# set_property -dict { PACKAGE_PIN P8   IOSTANDARD LVCMOS33 } [get_ports { srama_a7 }]; # SRAM B Address 7
# set_property -dict { PACKAGE_PIN R6   IOSTANDARD LVCMOS33 } [get_ports { srama_a8 }]; # SRAM B Address 8
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_a9 }]; # SRAM B Address 9
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_a10 }]; # SRAM B Address 10
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_a11 }]; # SRAM B Address 11
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_a12 }]; # SRAM B Address 12
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_a13 }]; # SRAM B Address 13
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_a14 }]; # SRAM B Address 14
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_a15 }]; # SRAM B Address 15
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_a16 }]; # SRAM B Address 16
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_a17 }]; # SRAM B Address 17
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_a18 }]; # SRAM B Address 18
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d0 }]; # SRAM B Data 0
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d1 }]; # SRAM B Data 1
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d2 }]; # SRAM B Data 2
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d3 }]; # SRAM B Data 3
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d4 }]; # SRAM B Data 4
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d5 }]; # SRAM B Data 5
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d6 }]; # SRAM B Data 6
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d7 }]; # SRAM B Data 7
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d8 }]; # SRAM B Data 8
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d9 }]; # SRAM B Data 9
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d10 }]; # SRAM B Data 10
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d11 }]; # SRAM B Data 11
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d12 }]; # SRAM B Data 12
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d13 }]; # SRAM B Data 13
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d14 }]; # SRAM B Data 14
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_d15 }]; # SRAM B Data 15
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_cen }]; # SRAM B chip enable
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_wen }]; # SRAM B write enable
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_oen }]; # SRAM B output enable
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_bhen }]; # SRAM B byte high enable
# set_property -dict { PACKAGE_PIN A9   IOSTANDARD LVCMOS33 } [get_ports { srama_blen }]; # SRAM B byte low enable


# # SRAM B
# set_property -dict { PACKAGE_PIN K2   IOSTANDARD LVCMOS33 } [get_ports { sramb_a0 }]; # SRAM B Address 0
# set_property -dict { PACKAGE_PIN K3   IOSTANDARD LVCMOS33 } [get_ports { sramb_a1 }]; # SRAM B Address 1
# set_property -dict { PACKAGE_PIN K5   IOSTANDARD LVCMOS33 } [get_ports { sramb_a2 }]; # SRAM B Address 2
# set_property -dict { PACKAGE_PIN L3   IOSTANDARD LVCMOS33 } [get_ports { sramb_a3 }]; # SRAM B Address 3
# set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports { sramb_a4 }]; # SRAM B Address 4
# set_property -dict { PACKAGE_PIN A2   IOSTANDARD LVCMOS33 } [get_ports { sramb_a5 }]; # SRAM B Address 5
# set_property -dict { PACKAGE_PIN B1   IOSTANDARD LVCMOS33 } [get_ports { sramb_a6 }]; # SRAM B Address 6
# set_property -dict { PACKAGE_PIN B2   IOSTANDARD LVCMOS33 } [get_ports { sramb_a7 }]; # SRAM B Address 7
# set_property -dict { PACKAGE_PIN E2   IOSTANDARD LVCMOS33 } [get_ports { sramb_a8 }]; # SRAM B Address 8
# set_property -dict { PACKAGE_PIN E3   IOSTANDARD LVCMOS33 } [get_ports { sramb_a9 }]; # SRAM B Address 9
# set_property -dict { PACKAGE_PIN E5   IOSTANDARD LVCMOS33 } [get_ports { sramb_a10 }]; # SRAM B Address 10
# set_property -dict { PACKAGE_PIN E6   IOSTANDARD LVCMOS33 } [get_ports { sramb_a11 }]; # SRAM B Address 11
# set_property -dict { PACKAGE_PIN F2   IOSTANDARD LVCMOS33 } [get_ports { sramb_a12 }]; # SRAM B Address 12
# set_property -dict { PACKAGE_PIN F3   IOSTANDARD LVCMOS33 } [get_ports { sramb_a13 }]; # SRAM B Address 13
# set_property -dict { PACKAGE_PIN F4   IOSTANDARD LVCMOS33 } [get_ports { sramb_a14 }]; # SRAM B Address 14
# set_property -dict { PACKAGE_PIN F5   IOSTANDARD LVCMOS33 } [get_ports { sramb_a15 }]; # SRAM B Address 15
# set_property -dict { PACKAGE_PIN G1   IOSTANDARD LVCMOS33 } [get_ports { sramb_a16 }]; # SRAM B Address 16
# set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports { sramb_a17 }]; # SRAM B Address 17
# set_property -dict { PACKAGE_PIN G4   IOSTANDARD LVCMOS33 } [get_ports { sramb_a18 }]; # SRAM B Address 18
# set_property -dict { PACKAGE_PIN J5   IOSTANDARD LVCMOS33 } [get_ports { sramb_d0 }]; # SRAM B Data 0
# set_property -dict { PACKAGE_PIN J3   IOSTANDARD LVCMOS33 } [get_ports { sramb_d1 }]; # SRAM B Data 1
# set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports { sramb_d2 }]; # SRAM B Data 2
# set_property -dict { PACKAGE_PIN H5   IOSTANDARD LVCMOS33 } [get_ports { sramb_d3 }]; # SRAM B Data 3
# set_property -dict { PACKAGE_PIN H4   IOSTANDARD LVCMOS33 } [get_ports { sramb_d4 }]; # SRAM B Data 4
# set_property -dict { PACKAGE_PIN H3   IOSTANDARD LVCMOS33 } [get_ports { sramb_d5 }]; # SRAM B Data 5
# set_property -dict { PACKAGE_PIN H2   IOSTANDARD LVCMOS33 } [get_ports { sramb_d6 }]; # SRAM B Data 6
# set_property -dict { PACKAGE_PIN H1   IOSTANDARD LVCMOS33 } [get_ports { sramb_d7 }]; # SRAM B Data 7
# set_property -dict { PACKAGE_PIN E1   IOSTANDARD LVCMOS33 } [get_ports { sramb_d8 }]; # SRAM B Data 8
# set_property -dict { PACKAGE_PIN D6   IOSTANDARD LVCMOS33 } [get_ports { sramb_d9 }]; # SRAM B Data 9
# set_property -dict { PACKAGE_PIN D4   IOSTANDARD LVCMOS33 } [get_ports { sramb_d10 }]; # SRAM B Data 10
# set_property -dict { PACKAGE_PIN D3   IOSTANDARD LVCMOS33 } [get_ports { sramb_d11 }]; # SRAM B Data 11
# set_property -dict { PACKAGE_PIN D1   IOSTANDARD LVCMOS33 } [get_ports { sramb_d12 }]; # SRAM B Data 12
# set_property -dict { PACKAGE_PIN C2   IOSTANDARD LVCMOS33 } [get_ports { sramb_d13 }]; # SRAM B Data 13
# set_property -dict { PACKAGE_PIN C1   IOSTANDARD LVCMOS33 } [get_ports { sramb_d14 }]; # SRAM B Data 14
# set_property -dict { PACKAGE_PIN B7   IOSTANDARD LVCMOS33 } [get_ports { sramb_d15 }]; # SRAM B Data 15
# set_property -dict { PACKAGE_PIN K1   IOSTANDARD LVCMOS33 } [get_ports { sramb_cen }]; # SRAM B chip enable
# set_property -dict { PACKAGE_PIN G5   IOSTANDARD LVCMOS33 } [get_ports { sramb_wen }]; # SRAM B write enable
# set_property -dict { PACKAGE_PIN B4   IOSTANDARD LVCMOS33 } [get_ports { sramb_oen }]; # SRAM B output enable
# set_property -dict { PACKAGE_PIN B5   IOSTANDARD LVCMOS33 } [get_ports { sramb_bhen }]; # SRAM B byte high enable
# set_property -dict { PACKAGE_PIN B6   IOSTANDARD LVCMOS33 } [get_ports { sramb_blen }]; # SRAM B byte low enable