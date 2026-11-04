# Current SPI debug configuration only. Create the core before any port use.
# Old UART / intermediate-design reconnection history has been removed.
# Probe 1/4 observe registered DQ input/output data; no obsolete DQ_OBUF alias.
# Probe 18 observes the actual protocol MISO output, and dbg_hub uses 200 MHz.
create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 2048 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list u_clk_wiz_0/inst/clk_200m]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {loop_idx[0]} {loop_idx[1]} {loop_idx[2]} {loop_idx[3]} {loop_idx[4]} {loop_idx[5]} {loop_idx[6]} {loop_idx[7]} {loop_idx[8]} {loop_idx[9]} {loop_idx[10]} {loop_idx[11]} {loop_idx[12]} {loop_idx[13]} {loop_idx[14]} {loop_idx[15]} {loop_idx[16]} {loop_idx[17]} {loop_idx[18]} {loop_idx[19]} {loop_idx[20]} {loop_idx[21]} {loop_idx[22]} {loop_idx[23]} {loop_idx[24]} {loop_idx[25]} {loop_idx[26]} {loop_idx[27]} {loop_idx[28]} {loop_idx[29]} {loop_idx[30]} {loop_idx[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 16 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {dq_read_data[0]} {dq_read_data[1]} {dq_read_data[2]} {dq_read_data[3]} {dq_read_data[4]} {dq_read_data[5]} {dq_read_data[6]} {dq_read_data[7]} {dq_read_data[8]} {dq_read_data[9]} {dq_read_data[10]} {dq_read_data[11]} {dq_read_data[12]} {dq_read_data[13]} {dq_read_data[14]} {dq_read_data[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 22 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {A_OBUF[0]} {A_OBUF[1]} {A_OBUF[2]} {A_OBUF[3]} {A_OBUF[4]} {A_OBUF[5]} {A_OBUF[6]} {A_OBUF[7]} {A_OBUF[8]} {A_OBUF[9]} {A_OBUF[10]} {A_OBUF[11]} {A_OBUF[12]} {A_OBUF[13]} {A_OBUF[14]} {A_OBUF[15]} {A_OBUF[16]} {A_OBUF[17]} {A_OBUF[18]} {A_OBUF[19]} {A_OBUF[20]} {A_OBUF[21]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 23 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {addr_cnt[0]} {addr_cnt[1]} {addr_cnt[2]} {addr_cnt[3]} {addr_cnt[4]} {addr_cnt[5]} {addr_cnt[6]} {addr_cnt[7]} {addr_cnt[8]} {addr_cnt[9]} {addr_cnt[10]} {addr_cnt[11]} {addr_cnt[12]} {addr_cnt[13]} {addr_cnt[14]} {addr_cnt[15]} {addr_cnt[16]} {addr_cnt[17]} {addr_cnt[18]} {addr_cnt[19]} {addr_cnt[20]} {addr_cnt[21]} {addr_cnt[22]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 16 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {dq_write_data[0]} {dq_write_data[1]} {dq_write_data[2]} {dq_write_data[3]} {dq_write_data[4]} {dq_write_data[5]} {dq_write_data[6]} {dq_write_data[7]} {dq_write_data[8]} {dq_write_data[9]} {dq_write_data[10]} {dq_write_data[11]} {dq_write_data[12]} {dq_write_data[13]} {dq_write_data[14]} {dq_write_data[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 21 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {addr_hold_cnt[0]} {addr_hold_cnt[1]} {addr_hold_cnt[2]} {addr_hold_cnt[3]} {addr_hold_cnt[4]} {addr_hold_cnt[5]} {addr_hold_cnt[6]} {addr_hold_cnt[7]} {addr_hold_cnt[8]} {addr_hold_cnt[9]} {addr_hold_cnt[10]} {addr_hold_cnt[11]} {addr_hold_cnt[12]} {addr_hold_cnt[13]} {addr_hold_cnt[14]} {addr_hold_cnt[15]} {addr_hold_cnt[16]} {addr_hold_cnt[17]} {addr_hold_cnt[18]} {addr_hold_cnt[19]} {addr_hold_cnt[20]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 32 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {err_cnt[0]} {err_cnt[1]} {err_cnt[2]} {err_cnt[3]} {err_cnt[4]} {err_cnt[5]} {err_cnt[6]} {err_cnt[7]} {err_cnt[8]} {err_cnt[9]} {err_cnt[10]} {err_cnt[11]} {err_cnt[12]} {err_cnt[13]} {err_cnt[14]} {err_cnt[15]} {err_cnt[16]} {err_cnt[17]} {err_cnt[18]} {err_cnt[19]} {err_cnt[20]} {err_cnt[21]} {err_cnt[22]} {err_cnt[23]} {err_cnt[24]} {err_cnt[25]} {err_cnt[26]} {err_cnt[27]} {err_cnt[28]} {err_cnt[29]} {err_cnt[30]} {err_cnt[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list u_spi_protocol/u_spi_slave/cs_n]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list u_spi_protocol/u_spi_slave/data_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list EN_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list err_flg_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list flg]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list frame_ack_latched]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list GN_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list keep]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list LBN_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list loop_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list loop_finish]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list spi_miso_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list u_spi_protocol/u_spi_slave/mosi]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list next_loop_start_d1]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list next_loop_start_d2]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list next_loop_start_d3]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list u_spi_protocol/u_spi_slave/sclk]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list u_spi_protocol/send_stop_flag]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list u_spi_protocol/stop_cmd_match]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list u_spi_protocol/stop_test]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list u_spi_protocol/tx_done_pulse]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list u_spi_protocol/tx_sending]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list u_spi_protocol/tx_sending_d1]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list UBN_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list WN_OBUF]]
set_property C_CLK_INPUT_FREQ_HZ 200000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk]
