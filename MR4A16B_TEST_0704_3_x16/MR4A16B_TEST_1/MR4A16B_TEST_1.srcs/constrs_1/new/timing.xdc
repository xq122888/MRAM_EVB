create_clock -period 5.000 -name clk200m -waveform {0.000 2.500} -add [get_pins u_clk_wiz_0/clk_200m]
#create_clock -period 2.500 -name clk400m -waveform {0.000 1.250} -add [get_pins u_clk_wiz_0/clk_400m]

#set_false_path -from [get_clocks clk200m] -to [get_clocks clk400m]

#set_max_delay -from [get_clocks clk400m] -to [get_clocks clk400m] 4.606

#create_pblock pblock_ila_core_inst
#resize_pblock [get_pblocks pblock_ila_core_inst] -add {SLICE_X0Y218:SLICE_X9Y248}
#resize_pblock [get_pblocks pblock_ila_core_inst] -add {RAMB18_X0Y88:RAMB18_X0Y97}
#resize_pblock [get_pblocks pblock_ila_core_inst] -add {RAMB36_X0Y44:RAMB36_X0Y48}

# Random test data now uses synchronous PRNG logic on clk200m.
# The old ring oscillator and its timing exceptions are no longer used.
