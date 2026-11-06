# ============================================
# 时钟输入
# ============================================
set_property PACKAGE_PIN R4 [get_ports clkp]
set_property PACKAGE_PIN T4 [get_ports clkn]
set_property IOSTANDARD DIFF_SSTL15 [get_ports clkp]
set_property IOSTANDARD DIFF_SSTL15 [get_ports clkn]

# ============================================
# 复位
# ============================================
set_property PACKAGE_PIN M17 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property PULLUP true [get_ports rst_n]

# ============================================
# 存储器控制信号
# ============================================
set_property PACKAGE_PIN K19 [get_ports EN]
set_property PACKAGE_PIN T21 [get_ports GN]
set_property PACKAGE_PIN H22 [get_ports WN]
set_property PACKAGE_PIN Y22 [get_ports UBN]
set_property PACKAGE_PIN Y21 [get_ports LBN]
set_property PACKAGE_PIN B21 [get_ports err_flg]

set_property IOSTANDARD LVCMOS33 [get_ports EN]
set_property IOSTANDARD LVCMOS33 [get_ports GN]
set_property IOSTANDARD LVCMOS33 [get_ports WN]
set_property IOSTANDARD LVCMOS33 [get_ports UBN]
set_property IOSTANDARD LVCMOS33 [get_ports LBN]
set_property IOSTANDARD LVCMOS33 [get_ports err_flg]

set_property SLEW FAST [get_ports EN]
set_property SLEW FAST [get_ports GN]
set_property SLEW FAST [get_ports WN]
set_property SLEW FAST [get_ports UBN]
set_property SLEW FAST [get_ports LBN]
set_property SLEW FAST [get_ports err_flg]

set_property DRIVE 16 [get_ports EN]
set_property DRIVE 16 [get_ports GN]
set_property DRIVE 16 [get_ports WN]
set_property DRIVE 16 [get_ports UBN]
set_property DRIVE 16 [get_ports LBN]
set_property DRIVE 16 [get_ports err_flg]

# ============================================
# 地址线 A[19:0]
# ============================================
set_property PACKAGE_PIN N18 [get_ports {A[0]}]
set_property PACKAGE_PIN N20 [get_ports {A[1]}]
set_property PACKAGE_PIN M20 [get_ports {A[2]}]
set_property PACKAGE_PIN M21 [get_ports {A[3]}]
set_property PACKAGE_PIN L21 [get_ports {A[4]}]
set_property PACKAGE_PIN H20 [get_ports {A[5]}]
set_property PACKAGE_PIN G20 [get_ports {A[6]}]
set_property PACKAGE_PIN G22 [get_ports {A[7]}]
set_property PACKAGE_PIN G21 [get_ports {A[8]}]
set_property PACKAGE_PIN D22 [get_ports {A[9]}]
set_property PACKAGE_PIN B13 [get_ports {A[10]}]
set_property PACKAGE_PIN D15 [get_ports {A[11]}]
set_property PACKAGE_PIN D14 [get_ports {A[12]}]
set_property PACKAGE_PIN E14 [get_ports {A[13]}]
set_property PACKAGE_PIN E13 [get_ports {A[14]}]
set_property PACKAGE_PIN U21 [get_ports {A[15]}]
set_property PACKAGE_PIN W22 [get_ports {A[16]}]
set_property PACKAGE_PIN W21 [get_ports {A[17]}]
set_property PACKAGE_PIN T20 [get_ports {A[18]}]
set_property PACKAGE_PIN N19 [get_ports {A[19]}]
set_property PACKAGE_PIN AA18 [get_ports {A[20]}]
set_property PACKAGE_PIN M15 [get_ports {A[21]}]

set_property IOSTANDARD LVCMOS33 [get_ports {A[*]}]
set_property SLEW FAST [get_ports {A[*]}]
set_property DRIVE 16 [get_ports {A[*]}]

# ============================================
# 数据线 DQ[15:0]
# ============================================
set_property PACKAGE_PIN K18 [get_ports {DQ[0]}]
set_property PACKAGE_PIN H18 [get_ports {DQ[1]}]
set_property PACKAGE_PIN H17 [get_ports {DQ[2]}]
set_property PACKAGE_PIN N22 [get_ports {DQ[3]}]
set_property PACKAGE_PIN M22 [get_ports {DQ[4]}]
set_property PACKAGE_PIN K22 [get_ports {DQ[5]}]
set_property PACKAGE_PIN K21 [get_ports {DQ[6]}]
set_property PACKAGE_PIN J22 [get_ports {DQ[7]}]
set_property PACKAGE_PIN F13 [get_ports {DQ[8]}]
set_property PACKAGE_PIN R18 [get_ports {DQ[9]}]
set_property PACKAGE_PIN V22 [get_ports {DQ[10]}]
set_property PACKAGE_PIN U22 [get_ports {DQ[11]}]
set_property PACKAGE_PIN Y19 [get_ports {DQ[12]}]
set_property PACKAGE_PIN Y18 [get_ports {DQ[13]}]
set_property PACKAGE_PIN W20 [get_ports {DQ[14]}]
set_property PACKAGE_PIN W19 [get_ports {DQ[15]}]

set_property IOSTANDARD LVCMOS33 [get_ports {DQ[*]}]
set_property SLEW FAST [get_ports {DQ[*]}]
set_property DRIVE 16 [get_ports {DQ[*]}]

# DQ下拉，避免浮空
set_property PULLDOWN true [get_ports {DQ[15]}]
set_property PULLDOWN true [get_ports {DQ[14]}]
set_property PULLDOWN true [get_ports {DQ[13]}]
set_property PULLDOWN true [get_ports {DQ[12]}]
set_property PULLDOWN true [get_ports {DQ[11]}]
set_property PULLDOWN true [get_ports {DQ[10]}]
set_property PULLDOWN true [get_ports {DQ[9]}]
set_property PULLDOWN true [get_ports {DQ[8]}]
set_property PULLDOWN true [get_ports {DQ[7]}]
set_property PULLDOWN true [get_ports {DQ[6]}]
set_property PULLDOWN true [get_ports {DQ[5]}]
set_property PULLDOWN true [get_ports {DQ[4]}]
set_property PULLDOWN true [get_ports {DQ[3]}]
set_property PULLDOWN true [get_ports {DQ[2]}]
set_property PULLDOWN true [get_ports {DQ[1]}]
set_property PULLDOWN true [get_ports {DQ[0]}]

# SPI接口
set_property PACKAGE_PIN N13 [get_ports spi_miso]
set_property PACKAGE_PIN N14 [get_ports spi_mosi]
set_property PACKAGE_PIN P14 [get_ports spi_sclk]
set_property PACKAGE_PIN P15 [get_ports spi_cs_n]

# 电压标准
set_property IOSTANDARD LVCMOS33 [get_ports spi_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports spi_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports spi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports spi_miso]

set_property DRIVE 8 [get_ports spi_miso]
set_property SLEW SLOW [get_ports spi_miso]
set_property PULLUP true [get_ports spi_mosi]
set_property PULLUP true [get_ports spi_sclk]
set_property PULLUP true [get_ports spi_cs_n]


# ============================================
# BITSTREAM配置
# ============================================
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]



