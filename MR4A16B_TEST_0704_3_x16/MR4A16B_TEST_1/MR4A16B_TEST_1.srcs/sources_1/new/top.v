`timescale 1ns / 1ps

// top
module top(
    input rst_n,
    input clkp,
    input clkn, 
    output CMOS_SW,
    
    input  spi_sclk,
    input  spi_cs_n,
    input  spi_mosi,
    output spi_miso,
    
    (*mark_debug="true"*)inout [15:0] DQ,
    (*mark_debug="true"*)output EN,
    (*mark_debug="true"*)output WN,
    (*mark_debug="true"*)output GN,
    (*mark_debug="true"*)output UBN,
    (*mark_debug="true"*)output LBN,
    (*mark_debug="true"*)output [21:0] A,
    (*mark_debug="true"*)output reg err_flg
);

wire clk;
wire clk200m;
wire clk400m;
wire locked;

  clk_wiz_0 u_clk_wiz_0
   (
    .clk_200m(clk200m),     // output clk_200m
    .clk_400m(clk400m),     // output clk_400m
    .resetn(rst_n),       // input resetn
    .locked(locked),       // output locked
    .clk_in1_p(clkp),    // input clk_in1_p
    .clk_in1_n(clkn));    // input clk_in1_n

assign clk = clk200m;

//-----------------------------------------------------------------
// 配置数据
wire [ 7:0] chip_type      ;
wire [ 7:0] vio_din_sel     ;
wire [ 3:0] vio_TMODE       ;
wire [19:0] vio_addr_ini    ;
wire [20:0] vio_addr_num    ;
wire [15:0] vio_t_AVAV      ;
wire [15:0] vio_t_AVQV      ;
wire [15:0] vio_t_AV2DV     ;
wire [15:0] vio_t_EH2EL     ;
wire [15:0] vio_t_EL2EH     ;
wire [15:0] vio_t_WH2WL     ;
wire [15:0] vio_t_WL2WH     ;
wire [15:0] vio_t_GH2GL     ;
wire [15:0] vio_t_GL2GH     ;
wire [15:0] vio_t_UBH2UBL   ;
wire [15:0] vio_t_UBL2UBH   ;
wire [15:0] vio_t_LBH2LBL   ;
wire [15:0] vio_t_LBL2LBH   ;

wire [19:0] vio_addr_ini_w  ;
wire [20:0] vio_addr_num_w  ;
wire [15:0] vio_t_AVAV_w    ;
wire [15:0] vio_t_AVQV_w    ;
wire [15:0] vio_t_AV2DV_w   ;
wire [15:0] vio_t_EH2EL_w   ;
wire [15:0] vio_t_EL2EH_w   ;
wire [15:0] vio_t_WH2WL_w   ;
wire [15:0] vio_t_WL2WH_w   ;
wire [15:0] vio_t_GH2GL_w   ;
wire [15:0] vio_t_GL2GH_w   ;
wire [15:0] vio_t_UBH2UBL_w ;
wire [15:0] vio_t_UBL2UBH_w ;
wire [15:0] vio_t_LBH2LBL_w ;
wire [15:0] vio_t_LBL2LBH_w ;

wire [19:0] vio_addr_ini_r  ;
wire [20:0] vio_addr_num_r  ;
wire [15:0] vio_t_AVAV_r    ;
wire [15:0] vio_t_AVQV_r    ;
wire [15:0] vio_t_AV2DV_r   ;
wire [15:0] vio_t_EH2EL_r   ;
wire [15:0] vio_t_EL2EH_r   ;
wire [15:0] vio_t_WH2WL_r   ;
wire [15:0] vio_t_WL2WH_r   ;
wire [15:0] vio_t_GH2GL_r   ;
wire [15:0] vio_t_GL2GH_r   ;
wire [15:0] vio_t_UBH2UBL_r ;
wire [15:0] vio_t_UBL2UBH_r ;
wire [15:0] vio_t_LBH2LBL_r ;
wire [15:0] vio_t_LBL2LBH_r ;

// spi传递数据
wire        spi_start_test  ;
wire [7:0]  spi_chip_type;
wire [3:0]  spi_test_mode;
wire [7:0]  spi_data_pattern;
wire [21:0] spi_start_addr;
wire [22:0] spi_test_length;
wire [31:0] spi_loop_count;
wire [1:0]  spi_write_mode;
wire [1:0]  spi_read_mode;
wire [7:0]  spi_err_detail_print;
wire detail_enabled;
wire spi_period_has_one_w, spi_period_has_one_r;
wire spi_period_has_two_w, spi_period_has_two_r;
wire [15:0] spi_t_avav_w;
wire [15:0] spi_t_avqv_w;
wire [15:0] spi_t_av2dv_w;
wire [15:0] spi_t_eh2el_w;
wire [15:0] spi_t_el2eh_w;
wire [15:0] spi_t_wh2wl_w;
wire [15:0] spi_t_wl2wh_w;
wire [15:0] spi_t_gh2gl_w;
wire [15:0] spi_t_gl2gh_w;
wire [15:0] spi_t_ubh2ubl_w;
wire [15:0] spi_t_ubl2ubh_w;
wire [15:0] spi_t_lbh2lbl_w;
wire [15:0] spi_t_lbl2lbh_w;
wire [15:0] spi_t_avav_r;
wire [15:0] spi_t_avqv_r;
wire [15:0] spi_t_av2dv_r;
wire [15:0] spi_t_eh2el_r;
wire [15:0] spi_t_el2eh_r;
wire [15:0] spi_t_wh2wl_r;
wire [15:0] spi_t_wl2wh_r;
wire [15:0] spi_t_gh2gl_r;
wire [15:0] spi_t_gl2gh_r;
wire [15:0] spi_t_ubh2ubl_r;
wire [15:0] spi_t_ubl2ubh_r;
wire [15:0] spi_t_lbh2lbl_r;
wire [15:0] spi_t_lbl2lbh_r;

wire        rstn            ;
wire        vio_CMOS_SW     ;
reg [3:0]   vio_TMODE_D1    ;
reg [3:0]   vio_TMODE_D2    ;
reg         R_EN;
reg         R_WN;
reg         R_GN;
reg         R_UBN;
reg         R_LBN;
// Explicit output data and a single registered direction bit. Keep Z at
// the I/O boundary instead of using 16 conditional Z-valued data registers.
reg [15:0] dq_write_data;
// Prevent synthesis from re-extracting an address-dependent clock enable.
(* extract_enable = "no" *) reg dq_drive;
wire [15:0] R_DQ = dq_drive ? dq_write_data : 16'hzzzz;

(*mark_debug="true"*)wire [15:0] RD_DATA         ;
reg [15:0]  dout;
reg [15:0]  dout_d1;
reg [15:0]  dout_d2;
reg [15:0]  dout_ref;
reg [21:0] dout_ref_addr;
wire detail_stall;
reg [21:0] error_ref_addr_sample, error_current_addr_sample;
reg [15:0] error_data_snapshot;
reg [15:0] error_ref_sample, error_current_sample;
(* extract_enable="no" *) reg error_uses_reference;
wire [21:0] error_addr_snapshot = error_uses_reference ? error_ref_addr_sample : error_current_addr_sample;
wire [15:0] error_expected_snapshot = error_uses_reference ? error_ref_sample : error_current_sample;

(* extract_enable="no" *) reg [21:0] addr;
reg [21:0]  addr_d;                                 
(*mark_debug="true"*)reg [22:0]  addr_cnt;
reg [22:0]  addr_cnt_d;                                                        
// Separate synchronous copies place timer loads near the control, pin-release,
// and error/IO-assertion logic. Each copy executes the SAME update on the SAME
// edge, including pause/reset/start; this is replication, not a pipeline.
(* mark_debug="true", keep="true", dont_touch="true" *) reg [20:0] addr_hold_cnt;
(* keep="true", dont_touch="true" *) reg [20:0] hold_release_count;
(* keep="true", dont_touch="true" *) reg [20:0] hold_sample_count;
(*mark_debug="true"*)reg [31:0]  err_cnt; 

(*mark_debug="true"*)reg     keep ;
(*mark_debug="true"*)reg     flg  ; 

reg         rd_en           ;
reg         rd_en_d         ;
reg         rd_en_d2        ;

wire        start           ;// 连接spi_start_test信号，解析成功后开始测试（仅第一个循环出现）
reg         start_d1        ;
reg         start_d2        ;
reg         start_d3        ;
reg         start_d4        ;
reg         stop            ;

(*mark_debug="true"*)wire send_frame_ack;    // 从 spi_protocol 输出的发送完成确认
(*mark_debug="true"*)reg  frame_ack_latched; 

wire [31:0]  loop_count ;
(*mark_debug="true"*)reg  [31:0]  loop_idx ;
(*mark_debug="true"*)reg          loop_finish;           // 当前循环结束，等待发送确认
reg          loop_finish_d1;
(*mark_debug="true"*)reg          loop_done;           // 所有循环完成标志

//reg   next_loop_start;
// Emit this event with the loop update, avoiding a 32-bit change detector.
(*mark_debug="true"*)reg   next_loop_start_d1;
(*mark_debug="true"*)reg   next_loop_start_d2;
(*mark_debug="true"*)reg   next_loop_start_d3;


// The configuration decoder commits these thresholds together with the base
// parameters. No variable subtraction or increment precedes the runtime test.
wire [31:0] spi_last_loop_index;
wire [20:0] spi_last_test_address;
wire [20:0] spi_gn_release_w, spi_gn_release_r;
wire [20:0] spi_compare_early_w;
wire [20:0] spi_compare_early_r;
wire [20:0] spi_en_release_w;
wire [20:0] spi_en_release_r;
wire [20:0] spi_wn_release_w;
wire [20:0] spi_wn_release_r;
wire [20:0] spi_ub_release_w;
wire [20:0] spi_ub_release_r;
wire [20:0] spi_lb_release_w;
wire [20:0] spi_lb_release_r;
wire [15:0] spi_period_last_w, spi_period_last_r;
wire [15:0] spi_period_before_last_w, spi_period_before_last_r;
// Native FPGA carry chains are used only for the data increment, independently
// of its enable. The terminal decisions do not consume the increment result.
(* keep = "true" *) wire [22:0] addr_cnt_inc = addr_cnt + 23'd1;
(* keep = "true" *) wire [31:0] loop_idx_inc = loop_idx + 32'd1;
(* keep = "true" *) wire [31:0] err_cnt_inc = err_cnt + 32'd1;
// Compare each bank independently before selecting its one-bit result. KEEP
// prevents folding this back into a wide bank mux ahead of the comparator.
// Bound the equality logic to LUT groups; prevent Vivado from selecting
// a serial CARRY reduction on the high-fanout runtime control predicates.
wire hold_one_w_equal, hold_one_r_equal, hold_two_w_equal, hold_two_r_equal;
mram_equal_lut #(.WIDTH(22)) eq_hold_one_w(.a({1'b0,addr_hold_cnt}),.b({!spi_period_has_one_w,5'b0,spi_period_last_w}),.match(hold_one_w_equal));
mram_equal_lut #(.WIDTH(22)) eq_hold_one_r(.a({1'b0,addr_hold_cnt}),.b({!spi_period_has_one_r,5'b0,spi_period_last_r}),.match(hold_one_r_equal));
mram_equal_lut #(.WIDTH(22)) eq_hold_two_w(.a({1'b0,addr_hold_cnt}),.b({!spi_period_has_two_w,5'b0,spi_period_before_last_w}),.match(hold_two_w_equal));
mram_equal_lut #(.WIDTH(22)) eq_hold_two_r(.a({1'b0,addr_hold_cnt}),.b({!spi_period_has_two_r,5'b0,spi_period_before_last_r}),.match(hold_two_r_equal));
(* keep = "true" *) wire hold_one_w = hold_one_w_equal;
(* keep = "true" *) wire hold_one_r = hold_one_r_equal;
(* keep = "true" *) wire hold_two_w = hold_two_w_equal;
(* keep = "true" *) wire hold_two_r = hold_two_r_equal;
wire hold_before_one = rd_en_d2 ? hold_one_r : hold_one_w;
wire hold_before_two = rd_en_d2 ? hold_two_r : hold_two_w;
(* keep = "true" *) wire period_w_match;
mram_equal_lut eq_period_w(.a(addr_hold_cnt),.b({5'b0,spi_t_avav_w}),.match(period_w_match));
(* keep = "true" *) wire period_r_match;
mram_equal_lut eq_period_r(.a(addr_hold_cnt),.b({5'b0,spi_t_avav_r}),.match(period_r_match));
wire period_match = rd_en_d2 ? period_r_match : period_w_match;
(* keep = "true" *) wire early_w_match;
mram_equal_lut eq_early_w(.a(hold_sample_count),.b(spi_compare_early_w),.match(early_w_match));
(* keep = "true" *) wire early_r_match;
mram_equal_lut eq_early_r(.a(hold_sample_count),.b(spi_compare_early_r),.match(early_r_match));
wire early_match = rd_en_d2 ? early_r_match : early_w_match;
(* keep = "true" *) wire gn_release_w_match;
mram_equal_lut eq_gn_release_w(.a(hold_release_count),.b(spi_gn_release_w),.match(gn_release_w_match));
(* keep = "true" *) wire gn_release_r_match;
mram_equal_lut eq_gn_release_r(.a(hold_release_count),.b(spi_gn_release_r),.match(gn_release_r_match));
wire gn_release_match = rd_en_d2 ? gn_release_r_match : gn_release_w_match;
(* keep = "true" *) wire en_release_w_match;
mram_equal_lut eq_en_release_w(.a(hold_release_count),.b(spi_en_release_w),.match(en_release_w_match));
(* keep = "true" *) wire en_release_r_match;
mram_equal_lut eq_en_release_r(.a(hold_release_count),.b(spi_en_release_r),.match(en_release_r_match));
wire en_release_match = rd_en_d2 ? en_release_r_match : en_release_w_match;
(* keep = "true" *) wire wn_release_w_match;
mram_equal_lut eq_wn_release_w(.a(hold_release_count),.b(spi_wn_release_w),.match(wn_release_w_match));
(* keep = "true" *) wire wn_release_r_match;
mram_equal_lut eq_wn_release_r(.a(hold_release_count),.b(spi_wn_release_r),.match(wn_release_r_match));
wire wn_release_match = rd_en_d2 ? wn_release_r_match : wn_release_w_match;
(* keep = "true" *) wire ub_release_w_match;
mram_equal_lut eq_ub_release_w(.a(hold_release_count),.b(spi_ub_release_w),.match(ub_release_w_match));
(* keep = "true" *) wire ub_release_r_match;
mram_equal_lut eq_ub_release_r(.a(hold_release_count),.b(spi_ub_release_r),.match(ub_release_r_match));
wire ub_release_match = rd_en_d2 ? ub_release_r_match : ub_release_w_match;
(* keep = "true" *) wire lb_release_w_match;
mram_equal_lut eq_lb_release_w(.a(hold_release_count),.b(spi_lb_release_w),.match(lb_release_w_match));
(* keep = "true" *) wire lb_release_r_match;
mram_equal_lut eq_lb_release_r(.a(hold_release_count),.b(spi_lb_release_r),.match(lb_release_r_match));
wire lb_release_match = rd_en_d2 ? lb_release_r_match : lb_release_w_match;
wire late_match;
mram_equal_lut eq_late(.a(hold_sample_count),.b({5'b0,spi_t_avqv_r}),.match(late_match));
wire current_is_initial, current_equals_address, addr_count_equal;
mram_equal_lut #(.WIDTH(22)) eq_current_initial(.a(addr_d),.b({2'b0,vio_addr_ini}),.match(current_is_initial));
mram_equal_lut #(.WIDTH(22)) eq_current_address(.a(addr_d),.b(addr),.match(current_equals_address));
mram_equal_lut #(.WIDTH(23)) eq_count_length(.a(addr_cnt),.b({2'b0,vio_addr_num}),.match(addr_count_equal));
wire actual_equals_reference, actual_equals_current;
mram_equal_lut #(.WIDTH(16)) eq_actual_reference(.a(RD_DATA),.b(dout_ref),.match(actual_equals_reference));
mram_equal_lut #(.WIDTH(16)) eq_actual_current(.a(RD_DATA),.b(dout_d1),.match(actual_equals_current));
// Compare three address slices in parallel, then combine five one-bit
// results in one LUT. Include the two upper counter bits in the high slice
// so the original unsigned 23-bit-vs-21-bit relation is preserved.
(* keep = "true" *) wire [2:0] count_less_slice, count_equal_slice;
assign count_less_slice[0] = addr_cnt[6:0] < vio_addr_num[6:0];
assign count_equal_slice[0] = addr_cnt[6:0] == vio_addr_num[6:0];
assign count_less_slice[1] = addr_cnt[13:7] < vio_addr_num[13:7];
assign count_equal_slice[1] = addr_cnt[13:7] == vio_addr_num[13:7];
assign count_less_slice[2] = addr_cnt[22:14] < {2'b0,vio_addr_num[20:14]};
assign count_equal_slice[2] = addr_cnt[22:14] == {2'b0,vio_addr_num[20:14]};
wire addr_count_less = count_less_slice[2] ||
                      (count_equal_slice[2] && count_less_slice[1]) ||
                      (count_equal_slice[2] && count_equal_slice[1] && count_less_slice[0]);
// Bound equality reduction to small LUT groups instead of a wide carry
// reduction. Preserve the zero-length guard and the two upper counter bits.
(* keep = "true" *) wire [7:0] addr_last_group;
generate
    genvar addr_group;
    for (addr_group=0; addr_group<7; addr_group=addr_group+1) begin : addr_terminal_compare
        assign addr_last_group[addr_group] =
            (addr_cnt[addr_group*3 +: 3] == spi_last_test_address[addr_group*3 +: 3]);
    end
endgenerate
assign addr_last_group[7] = (addr_cnt[22:21] == 2'b0);
(* keep = "true" *) wire addr_last_low = &addr_last_group[3:0];
(* keep = "true" *) wire addr_last_high = &addr_last_group[7:4];
wire addr_is_last = (vio_addr_num != 21'd0) && addr_last_low && addr_last_high;
// Zero loop_count retains the original unsigned loop_count - 1 behavior.
wire loop_has_more = (loop_idx < spi_last_loop_index);

// ========== SPI协议模块实例化 ==========
spi_protocol u_spi_protocol (
    .clk(clk200m),
    .rst_n(rst_n),
    .spi_sclk(spi_sclk),
    .spi_cs_n(spi_cs_n),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    
    // 配置输出
    .chip_type(spi_chip_type),
    .test_mode(spi_test_mode),
    .data_pattern(spi_data_pattern),
    .start_addr(spi_start_addr),
    .test_length(spi_test_length),
    .loop_count(spi_loop_count),
    .last_loop_index(spi_last_loop_index),
    .last_test_address(spi_last_test_address),
    .gn_release_w(spi_gn_release_w),
    .gn_release_r(spi_gn_release_r),
    .compare_early_w(spi_compare_early_w),
    .compare_early_r(spi_compare_early_r),
    .en_release_w(spi_en_release_w),
    .en_release_r(spi_en_release_r),
    .wn_release_w(spi_wn_release_w),
    .wn_release_r(spi_wn_release_r),
    .ub_release_w(spi_ub_release_w),
    .ub_release_r(spi_ub_release_r),
    .lb_release_w(spi_lb_release_w),
    .lb_release_r(spi_lb_release_r),

    .period_last_w(spi_period_last_w),
    .period_before_last_w(spi_period_before_last_w),
    .period_last_r(spi_period_last_r),
    .period_before_last_r(spi_period_before_last_r),
    .write_mode(spi_write_mode),
    .read_mode(spi_read_mode),
    .err_detail_print(spi_err_detail_print),
    .detail_enabled(detail_enabled),
    .period_has_one_w(spi_period_has_one_w),
    .period_has_one_r(spi_period_has_one_r),
    .period_has_two_w(spi_period_has_two_w),
    .period_has_two_r(spi_period_has_two_r),
    .t_avav_w(spi_t_avav_w),
    .t_avqv_w(spi_t_avqv_w),
    .t_av2dv_w(spi_t_av2dv_w),
    .t_eh2el_w(spi_t_eh2el_w),
    .t_el2eh_w(spi_t_el2eh_w),
    .t_wh2wl_w(spi_t_wh2wl_w),
    .t_wl2wh_w(spi_t_wl2wh_w),
    .t_gh2gl_w(spi_t_gh2gl_w),
    .t_gl2gh_w(spi_t_gl2gh_w),
    .t_ubh2ubl_w(spi_t_ubh2ubl_w),
    .t_ubl2ubh_w(spi_t_ubl2ubh_w),
    .t_lbh2lbl_w(spi_t_lbh2lbl_w),
    .t_lbl2lbh_w(spi_t_lbl2lbh_w),   
    .t_avav_r(spi_t_avav_r),
    .t_avqv_r(spi_t_avqv_r),
    .t_av2dv_r(spi_t_av2dv_r),
    .t_eh2el_r(spi_t_eh2el_r),
    .t_el2eh_r(spi_t_el2eh_r),
    .t_wh2wl_r(spi_t_wh2wl_r),
    .t_wl2wh_r(spi_t_wl2wh_r),
    .t_gh2gl_r(spi_t_gh2gl_r),
    .t_gl2gh_r(spi_t_gl2gh_r),
    .t_ubh2ubl_r(spi_t_ubh2ubl_r),
    .t_ubl2ubh_r(spi_t_ubl2ubh_r),
    .t_lbh2lbl_r(spi_t_lbh2lbl_r),
    .t_lbl2lbh_r(spi_t_lbl2lbh_r),
    .start_test(spi_start_test),
    .tx_done_pulse(send_frame_ack),
    .detail_stall(detail_stall),
    
    // 给spi模块的参数
    .current_loop(loop_idx),
    .test_busy(flg),
    .error_cnt(err_cnt),
    .err_flag(err_flg),
    .error_addr(error_addr_snapshot),
    .error_data(error_data_snapshot),
    .expected_data(error_expected_snapshot),
    .test_complete(stop)// 测试完成信号
);


// ============================================================
// 将 SPI 输出连接到测试逻辑的 vio_ 信号
// ============================================================
assign chip_type  = spi_chip_type;
assign vio_TMODE = spi_test_mode;
assign vio_din_sel = spi_data_pattern;
assign vio_addr_ini = spi_start_addr;
assign vio_addr_num = spi_test_length;
assign loop_count = spi_loop_count;
assign vio_t_AVAV_w = spi_t_avav_w;
assign vio_t_AVQV_w = spi_t_avqv_w;
assign vio_t_AV2DV_w = spi_t_av2dv_w;
assign vio_t_EH2EL_w = spi_t_eh2el_w;
assign vio_t_EL2EH_w = spi_t_el2eh_w;
assign vio_t_WH2WL_w = spi_t_wh2wl_w;
assign vio_t_WL2WH_w = spi_t_wl2wh_w;
assign vio_t_GH2GL_w = spi_t_gh2gl_w;
assign vio_t_GL2GH_w = spi_t_gl2gh_w;
assign vio_t_UBH2UBL_w = spi_t_ubh2ubl_w;
assign vio_t_UBL2UBH_w = spi_t_ubl2ubh_w;
assign vio_t_LBH2LBL_w = spi_t_lbh2lbl_w;
assign vio_t_LBL2LBH_w = spi_t_lbl2lbh_w;
assign vio_t_AVAV_r = spi_t_avav_r;
assign vio_t_AVQV_r = spi_t_avqv_r;
assign vio_t_AV2DV_r = spi_t_av2dv_r;
assign vio_t_EH2EL_r = spi_t_eh2el_r;
assign vio_t_EL2EH_r = spi_t_el2eh_r;
assign vio_t_WH2WL_r = spi_t_wh2wl_r;
assign vio_t_WL2WH_r = spi_t_wl2wh_r;
assign vio_t_GH2GL_r = spi_t_gh2gl_r;
assign vio_t_GL2GH_r = spi_t_gl2gh_r;
assign vio_t_UBH2UBL_r = spi_t_ubh2ubl_r;
assign vio_t_UBL2UBH_r = spi_t_ubl2ubh_r;
assign vio_t_LBH2LBL_r = spi_t_lbh2lbl_r;
assign vio_t_LBL2LBH_r = spi_t_lbl2lbh_r;



// ========== TRNG模块 ==========
wire [7:0] trng_data;
wire trng_valid;

trng_8bit u_trng_8bit (
    .clk      (clk),        // 使用与测试逻辑相同的时钟 clk200m
    .rst_n    (rstn),       // 使用相同的复位信号
    .rnd_data (trng_data),
    .rnd_valid(trng_valid)
);
// TRNG数据寄存器（用于保持随机数）
reg [7:0] trng_data_reg;
reg trng_valid_reg;


//------------------------------------------------------------
// 延时
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        start_d1    <= 0        ;
        start_d2    <= 0        ;
        start_d3    <= 0        ;
        start_d4    <= 0        ;
        
//        next_loop_start <= 0    ;
//        next_loop_start_d1 <= 0 ;
        next_loop_start_d2 <= 0 ;
        next_loop_start_d3 <= 0 ;
        
        dout_d1     <= 16'h0    ;
        dout_d2     <= 16'h0    ;      
          
        addr_d      <= 20'h0    ;
        addr_cnt_d  <= 21'd0    ;
        rd_en_d     <= 1'b0;
        rd_en_d2    <= 1'b0;
        
        vio_TMODE_D1<= 4'd0     ;
        vio_TMODE_D2<= 4'd0     ;
        
        loop_finish_d1 <= 1'b0  ;
        
    end
    else begin
        start_d1    <= start    ;
        start_d2    <= start_d1 ;
        start_d3    <= start_d2 ;
        start_d4    <= start_d3 ;

//        next_loop_start_d1 <= next_loop_start ;
        next_loop_start_d2 <= next_loop_start_d1 ;
        next_loop_start_d3 <= next_loop_start_d2 ;
  
        if (!detail_stall) begin
        dout_d1     <= dout     ;
        dout_d2     <= dout_d1  ;
  
        addr_d      <= addr     ;
        addr_cnt_d  <= addr_cnt ;
        rd_en_d     <= rd_en;
        rd_en_d2    <= rd_en_d;
        
        end

        vio_TMODE_D1<= vio_TMODE;
        vio_TMODE_D2<= vio_TMODE_D1;
        
        loop_finish_d1 <= loop_finish;

    end
end

// ------------------------------------------------------------
// 循环控制状态机（含帧确认锁存）
// ------------------------------------------------------------
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        loop_idx          <= 32'd0;
        next_loop_start_d1 <= 1'b0;
        loop_done         <= 1'b0;
        loop_finish       <= 1'b0;
//        next_loop_start   <= 1'b0;
        frame_ack_latched <= 1'b0;
    end
    else if (start_d1 != start_d2) begin
        // 测试开始时复位所有循环状态
        loop_idx          <= 32'd0;
        next_loop_start_d1 <= (loop_idx != 32'd0);
        loop_done         <= 1'b0;
        loop_finish       <= 1'b0;
//        next_loop_start   <= 1'b0;
        frame_ack_latched <= 1'b0;
    end
    else begin
        next_loop_start_d1 <= 1'b0;
        // 默认清除 next_loop_start（保证单周期脉冲）
//        next_loop_start <= 1'b0;

        // ---------- 1. 锁存 send_frame_ack 脉冲 ----------
        if (send_frame_ack) begin
            frame_ack_latched <= 1'b1;
        end

        // ---------- 2. 检测循环结束条件（与原逻辑完全一致） ----------
        if (!detail_stall && flg && (addr_is_last) && (hold_before_one)) begin
            if (vio_TMODE == 4'd2 && rd_en_d) begin
                if (!loop_finish) loop_finish <= 1'b1;
            end
            else if (vio_TMODE != 4'd2) begin
                if (!loop_finish) loop_finish <= 1'b1;
            end
        end

        // ---------- 3. 响应确认与下一循环触发 ----------
        if (frame_ack_latched && loop_finish) begin
            frame_ack_latched <= 1'b0;     // 清除锁存
            loop_finish       <= 1'b0;     // 清除结束标志
//            next_loop_start   <= 1'b1;     // 产生启动脉冲

            if (loop_has_more) begin
                next_loop_start_d1 <= 1'b1;
                loop_idx <= loop_idx_inc;   // 进入下一循环
            end
            else begin
                loop_done <= 1'b1;          // 所有循环完成
            end
        end
    end
end


//----
// One-hot source masks put address retention on the data input instead of
// extracting a slow range-comparison-dependent CE. KEEP bounds each bit's final
// choice to three parallel AND terms and an OR (six LUT inputs).
(* keep="true" *) wire [21:0] address_sum = vio_addr_ini + addr_cnt;
(* keep="true" *) reg [2:0] address_source_mask;
always @* begin
    if (detail_stall)
        address_source_mask = 3'b100;
    else if (start_d1!=0 && start_d1!=start_d2)
        address_source_mask = 3'b001;
    else if (flg && (keep || addr_count_less))
        address_source_mask = 3'b010;
    else if (hold_before_one)
        address_source_mask = 3'b000;
    else
        address_source_mask = 3'b100;
end
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        addr <= 22'd0;
    else
        addr <= ({22{address_source_mask[0]}} & {2'b0,vio_addr_ini}) |
                ({22{address_source_mask[1]}} & address_sum) |
                ({22{address_source_mask[2]}} & addr);
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        addr_cnt <= 22'd0;
    else if(detail_stall)
        addr_cnt <= addr_cnt;
    else if(start_d1 != start_d2 || next_loop_start_d1)   // 增加 next_loop_start
        addr_cnt <= 22'd0;
    else if(keep && addr_is_last && hold_before_two)
        addr_cnt <= 22'd0;
    else if(addr_count_less && hold_before_two)
        addr_cnt <= addr_cnt_inc;
    else
        addr_cnt <= addr_cnt;
end


//---
// The two old load-one branches shared a period condition; combine their
// events so stall/start/period control does not form a serial priority chain.
wire hold_load_one = (next_loop_start_d2 && !next_loop_start_d3) ||
                     (start_d2 && !start_d3) || (addr_count_less && period_match);
(* keep="true" *) wire [20:0] addr_hold_cnt_inc = addr_hold_cnt + 21'd1;
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        addr_hold_cnt <= 21'd0;
    else if (!detail_stall) begin
        if (next_loop_start_d1)
            addr_hold_cnt <= 21'd0;
        else if (hold_load_one)
            addr_hold_cnt <= 21'd1;
        else if (period_match)
            addr_hold_cnt <= 21'd0;
        else if (|addr_hold_cnt)
            addr_hold_cnt <= addr_hold_cnt_inc;
        else
            addr_hold_cnt <= 21'd0;
    end
end

(* keep="true" *) wire [20:0] hold_release_count_inc = hold_release_count + 21'd1;
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        hold_release_count <= 21'd0;
    else if (!detail_stall) begin
        if (next_loop_start_d1)
            hold_release_count <= 21'd0;
        else if (hold_load_one)
            hold_release_count <= 21'd1;
        else if (period_match)
            hold_release_count <= 21'd0;
        else if (|hold_release_count)
            hold_release_count <= hold_release_count_inc;
        else
            hold_release_count <= 21'd0;
    end
end

(* keep="true" *) wire [20:0] hold_sample_count_inc = hold_sample_count + 21'd1;
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        hold_sample_count <= 21'd0;
    else if (!detail_stall) begin
        if (next_loop_start_d1)
            hold_sample_count <= 21'd0;
        else if (hold_load_one)
            hold_sample_count <= 21'd1;
        else if (period_match)
            hold_sample_count <= 21'd0;
        else if (|hold_sample_count)
            hold_sample_count <= hold_sample_count_inc;
        else
            hold_sample_count <= 21'd0;
    end
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        flg <= 1'b0;
    else if(detail_stall)
        flg <= flg;
    else if((start_d2 != 0 && start_d2 != start_d3) || next_loop_start_d1)   // 增加 next_loop_start
        flg <= 1'b1;
    else if(addr_count_equal && period_match)
        flg <= 1'b0;
    else
        flg <= flg;   
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        dout_ref <= 16'h0;
    else if(detail_stall)
        dout_ref <= dout_ref;
    else if(period_match)
        dout_ref <= dout_d1;
    else
        dout_ref <= dout_ref;
end

// Keep the reference word paired with the address present when that word was
// latched. The early compare uses the previous reference word, not necessarily
// the address currently on the pins. The late compare uses current addr_d.
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        dout_ref_addr <= 22'd0;
    else if (!detail_stall && period_match)
        dout_ref_addr <= addr_d;
end

// Sample both possible comparison operands on every running clock. The
// one-bit event selects the matching samples only after this edge. Error
// detection therefore drives neither a 54-bit snapshot CE nor a wide data mux.
// Backpressure freezes these samples before the mailbox consumes the event.
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        error_ref_addr_sample <= 22'd0;
        error_current_addr_sample <= 22'd0;
        error_data_snapshot <= 16'd0;
        error_ref_sample <= 16'd0;
        error_current_sample <= 16'd0;
    end else if (!detail_stall) begin
        error_ref_addr_sample <= dout_ref_addr;
        error_current_addr_sample <= addr_d;
        error_data_snapshot <= RD_DATA;
        error_ref_sample <= dout_ref;
        error_current_sample <= dout_d1;
    end
end
wire early_error = early_match && !current_is_initial && !actual_equals_reference;
wire late_error = late_match && !actual_equals_current;
// The selection is only consumed when err_flg is valid. Sample the early
// comparison independently of loop/start/late-error control; an early error
// wins when both comparisons fire, as in the original priority chain.
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        error_uses_reference <= 1'b0;
    else if (!detail_stall) begin
        if (early_error)
            error_uses_reference <= 1'b1;
        else
            error_uses_reference <= 1'b0;
    end
end
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        err_flg <= 1'b0;
    end else if (detail_enabled && (spi_start_test || start_d1!=start_d2 || next_loop_start_d1)) begin
        err_flg <= 1'b0;
    end else begin
        err_flg <= 1'b0;
        if (!detail_stall && flg && rd_en_d) begin
            if (early_error)
                err_flg <= 1'b1;
            else if (late_error)
                err_flg <= 1'b1;
        end
    end
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        err_cnt <= 32'd0;
    else if(start_d1 != start_d2 || next_loop_start_d1)  // 增加循环变化清零
        err_cnt <= 32'd0;
    else if(err_flg)
        err_cnt <= err_cnt_inc;
end



always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        trng_data_reg <= 8'd0;
        trng_valid_reg <= 1'b0;
    end
    else if(detail_stall) begin
        trng_data_reg <= trng_data_reg;
        trng_valid_reg <= trng_valid_reg;
    end
    else if(trng_valid) begin
        trng_data_reg <= trng_data;
        trng_valid_reg <= 1'b1;
    end
    else begin
        trng_valid_reg <= 1'b0;
    end
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        dout <= 16'h0;
    else if(detail_stall)
        dout <= dout;
    else if((start_d1!=0 && start_d1!=start_d2) || next_loop_start_d1)
        case(vio_din_sel)
            8'd1:   dout <= 16'h0;
            8'd2:   dout <= 16'hFFFF;
            8'd3:   dout <= 16'h5A5A;
            8'd4:   dout <= 16'hA5A5;
            8'd5:   dout <= 16'h0;
            8'd6:   dout <= 16'hFFFF;
            8'd7:   dout <= 16'h5555;
            8'd8:   dout <= 16'hAAAA;
            8'd9:   dout <= {trng_data_reg, trng_data_reg};  // 8位扩展为16位
            default:dout <= 16'h0;
        endcase 
    else if(hold_before_one)
        case(vio_din_sel)
            8'd1:   dout <= addr_cnt[15:0];
            8'd2:   dout <= 16'hFFFF-addr_cnt[15:0];
            8'd3:   dout <= ~dout;
            8'd4:   dout <= ~dout;
            8'd9:   dout <= {trng_data_reg^addr_cnt[7:0], trng_data_reg^addr_cnt[7:0]};//根据地址变化
            default:dout <= dout;
        endcase
    else
        dout <= dout;
end


//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        R_EN <= 1'b1;
    else if(detail_stall)
        R_EN <= R_EN;
    else if(vio_t_EH2EL==0 && keep && !current_equals_address)
        R_EN <= 1'b0;
    else if(vio_t_EH2EL==0 && ((start_d2!=0 && start_d2!=start_d3) || (!current_equals_address && addr!=0)))
        R_EN <= 1'b0;
    else if(vio_t_EH2EL!=0 && hold_sample_count==vio_t_EH2EL)
        R_EN <= 1'b0;
    else if(en_release_match)
        R_EN <= 1'b1;
    else
        R_EN <= R_EN;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        R_WN <= 1'b1;
    else if(detail_stall)
        R_WN <= R_WN;
    else if(vio_t_WH2WL==0 && keep && !current_equals_address)
        R_WN <= 1'b0;
    else if(vio_t_WH2WL==0 && ((start_d2!=0 && start_d2!=start_d3) || (!current_equals_address && addr!=0)))
        R_WN <= 1'b0;
    else if(vio_t_WH2WL!=0 && hold_sample_count==vio_t_WH2WL)
        R_WN <= 1'b0;
    else if(wn_release_match)
        R_WN <= 1'b1;
    else
        R_WN <= R_WN;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        R_GN <= 1'b1;
    else if(detail_stall)
        R_GN <= R_GN;
    else if(vio_t_GH2GL==0 && keep && !current_equals_address)
        R_GN <= 1'b0;
    else if(vio_t_GH2GL==0 && ((start_d2!=0 && start_d2!=start_d3) || (!current_equals_address && addr!=0)))
        R_GN <= 1'b0;
    else if(vio_t_GH2GL!=0 && hold_sample_count==vio_t_GH2GL)
        R_GN <= 1'b0;
    else if(gn_release_match)
        R_GN <= 1'b1;
    else
        R_GN <= R_GN;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        R_UBN <= 1'b1;
    else if(detail_stall)
        R_UBN <= R_UBN;
    else if(vio_t_UBH2UBL==0 && keep && !current_equals_address)
        R_UBN <= 1'b0;
    else if(vio_t_UBH2UBL==0 && ((start_d2!=0 && start_d2!=start_d3) || (!current_equals_address && addr!=0)))
        R_UBN <= 1'b0;
    else if(vio_t_UBH2UBL!=0 && hold_sample_count==vio_t_UBH2UBL)
        R_UBN <= 1'b0;
    else if(ub_release_match)
        R_UBN <= 1'b1;
    else
        R_UBN <= R_UBN;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        R_LBN <= 1'b1;
    else if(detail_stall)
        R_LBN <= R_LBN;
    else if(vio_t_LBH2LBL==0 && keep && !current_equals_address)
        R_LBN <= 1'b0;
    else if(vio_t_LBH2LBL==0 && ((start_d2!=0 && start_d2!=start_d3) || (!current_equals_address && addr!=0)))
        R_LBN <= 1'b0;
    else if(vio_t_LBH2LBL!=0 && hold_sample_count==vio_t_LBH2LBL)
        R_LBN <= 1'b0;
    else if(lb_release_match)
        R_LBN <= 1'b1;
    else
        R_LBN <= R_LBN;
end

//---
// Combine the two original zero-delay write conditions before direction
// control. Writes take priority over the end-of-period zero-data update.
wire dq_write_event = (vio_t_AV2DV==16'd0 &&
    ((start_d2 && !start_d3) || (!current_equals_address && (keep || (|addr))))) ||
    (vio_t_AV2DV!=16'd0 && hold_sample_count==vio_t_AV2DV);
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        dq_write_data <= 16'd0;
    else if (!detail_stall && !rd_en_d) begin
        if (dq_write_event)
            dq_write_data <= dout;
        else if (period_match)
            dq_write_data <= 16'd0;
    end
end
always @(posedge clk or negedge rstn) begin
    if (!rstn)
        dq_drive <= 1'b1;
    else if (!detail_stall) begin
        // Preserve the original priority: read -> Z; write/period -> driven;
        // otherwise retain the preceding direction. Keep this decision on D.
        dq_drive <= !rd_en_d && (dq_write_event || period_match || dq_drive);
    end
end


//----------------------------------------------------------------
// 在 loop_finish 期间暂停地址访问
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        keep <= 1'b0;
    else if(detail_stall)
        keep <= keep;
    else if(start_d2 == 0 && start_d1 == 1) begin
        keep <= 1'b1;                      // 测试开始允许地址访问
    end
    else if(loop_done && period_match) begin
        keep <= 1'b0;                      // 全部循环完成停止
    end
    else if(loop_finish) begin
        keep <= 1'b0;                      // 等待发送完成帧，暂停
    end
    else if(!loop_done) begin
        keep <= 1'b1;                      // 非等待状态且未完成所有循环时允许地址访问
    end
    else begin
        keep <= keep;
    end
end


always @(posedge clk or negedge rstn) begin
    if(!rstn)
        rd_en <= 1'b0;
    else if(detail_stall)
        rd_en <= rd_en;
    else begin
        case(vio_TMODE)
            4'd0: begin  // 写
                rd_en <= 1'b0;
            end
            4'd1: begin  // 读
                rd_en <= 1'b1;
            end
            4'd2: begin  // 写读
                if(start_d2 == 0 && start_d1 == 1)
                    rd_en <= 1'b0;
                else if(addr_is_last && hold_before_two)
                    rd_en <= rd_en + 1;
                else
                    rd_en <= rd_en;
            end
            default: begin
                rd_en <= 1'b0;
            end
        endcase
    end
end



//----------------------------------------------------------------
// 生成stop信号 - 每次循环结束时通知SPI模块测试完成
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        stop <= 1'b0;
    else if(loop_finish && !loop_finish_d1) //loop_finish_rise
        stop <= 1'b1;
    else
        stop <= 1'b0;
end

//----------------------------------------------------------------
assign start = spi_start_test;// start 信号连接
assign rstn=rst_n && (!(vio_TMODE_D2!=vio_TMODE_D1));
//assign rstn = rst_n && locked;

assign EN = flg ? R_EN : 1'b1;
assign GN = flg ? R_GN : 1'b1;
assign WN = flg ? (rd_en_d2 ? 1'b1 : R_WN) : 1'b1;
assign UBN= flg ? R_UBN : 1'b1;
assign LBN= flg ? R_LBN : 1'b1;
assign A  = flg ? addr_d : 20'd0;
assign DQ = flg ? (rd_en_d2 ? 16'hz : R_DQ) : 16'hz;
assign RD_DATA = DQ;

assign CMOS_SW = vio_CMOS_SW;

assign vio_t_AVQV    = vio_t_AVQV_r   ;
assign vio_t_AV2DV   = vio_t_AV2DV_w  ;
assign vio_t_WH2WL   = vio_t_WH2WL_w  ;
assign vio_t_WL2WH   = vio_t_WL2WH_w  ;

assign vio_t_AVAV    = rd_en_d2 ? vio_t_AVAV_r    : vio_t_AVAV_w   ;
assign vio_t_EH2EL   = rd_en_d  ? vio_t_EH2EL_r   : vio_t_EH2EL_w  ;
assign vio_t_EL2EH   = rd_en_d2 ? vio_t_EL2EH_r   : vio_t_EL2EH_w  ;
assign vio_t_GH2GL   = rd_en_d  ? vio_t_GH2GL_r   : vio_t_GH2GL_w  ;
assign vio_t_GL2GH   = rd_en_d2 ? vio_t_GL2GH_r   : vio_t_GL2GH_w  ;
assign vio_t_UBH2UBL = rd_en_d  ? vio_t_UBH2UBL_r : vio_t_UBH2UBL_w;
assign vio_t_UBL2UBH = rd_en_d2 ? vio_t_UBL2UBH_r : vio_t_UBL2UBH_w;
assign vio_t_LBH2LBL = rd_en_d  ? vio_t_LBH2LBL_r : vio_t_LBH2LBL_w;
assign vio_t_LBL2LBH = rd_en_d2 ? vio_t_LBL2LBH_r : vio_t_LBL2LBH_w;


endmodule


// Equality in independent LUT groups instead of a wide serial carry chain.
// Used only for combinational predicates; adds no pipeline latency.
module mram_equal_lut #(parameter WIDTH=21)(
    input wire [WIDTH-1:0] a, b,
    output wire match
);
wire [23:0] a_padded = {{(24-WIDTH){1'b0}},a};
wire [23:0] b_padded = {{(24-WIDTH){1'b0}},b};
(* keep = "true" *) wire [7:0] equal_group;
generate
    genvar eq_group;
    for (eq_group=0; eq_group<8; eq_group=eq_group+1) begin : compare_group
        assign equal_group[eq_group] = a_padded[eq_group*3 +: 3] == b_padded[eq_group*3 +: 3];
    end
endgenerate
(* keep = "true" *) wire equal_low = &equal_group[3:0];
(* keep = "true" *) wire equal_high = &equal_group[7:4];
assign match = equal_low && equal_high;
endmodule
