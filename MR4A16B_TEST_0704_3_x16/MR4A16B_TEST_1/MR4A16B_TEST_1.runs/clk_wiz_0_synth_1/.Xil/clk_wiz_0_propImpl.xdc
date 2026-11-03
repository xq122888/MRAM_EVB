set_property SRC_FILE_INFO {cfile:e:/06_MramTestBoard/MRAM_Parallel_Test_35t/MR4A16B_TEST_0625-2/MR4A16B_TEST_1/MR4A16B_TEST_1.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0.xdc rfile:../../../MR4A16B_TEST_1.srcs/sources_1/ip/clk_wiz_0/clk_wiz_0.xdc id:1 order:EARLY scoped_inst:inst} [current_design]
current_instance inst
set_property src_info {type:SCOPED_XDC file:1 line:57 export:INPUT save:INPUT read:READ} [current_design]
set_input_jitter [get_clocks -of_objects [get_ports clk_in1_p]] 0.05
