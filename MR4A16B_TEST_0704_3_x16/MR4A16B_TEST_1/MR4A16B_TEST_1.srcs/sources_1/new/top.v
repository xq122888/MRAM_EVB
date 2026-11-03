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
reg [15:0]  R_DQ;

(*mark_debug="true"*)wire [15:0] RD_DATA         ;
reg [15:0]  dout;
reg [15:0]  dout_d1;
reg [15:0]  dout_d2;
reg [15:0]  dout_ref;

reg [21:0]  addr;                                   
reg [21:0]  addr_d;                                 
(*mark_debug="true"*)reg [22:0]  addr_cnt;
reg [22:0]  addr_cnt_d;                                                        
(*mark_debug="true"*)reg [20:0]  addr_hold_cnt;
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
reg [31:0] loop_idx_d1;
(*mark_debug="true"*)reg          loop_finish;           // 当前循环结束，等待发送确认
reg          loop_finish_d1;
(*mark_debug="true"*)reg          loop_done;           // 所有循环完成标志

//reg   next_loop_start;
(*mark_debug="true"*)wire  next_loop_start_d1 = (loop_idx != loop_idx_d1); 
(*mark_debug="true"*)reg   next_loop_start_d2;
(*mark_debug="true"*)reg   next_loop_start_d3;


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
    .write_mode(spi_write_mode),
    .read_mode(spi_read_mode),
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
    
    // 给spi模块的参数
    .current_loop(loop_idx),
    .test_busy(flg),
    .error_cnt(err_cnt),
    .err_flag(err_flg),
    .error_addr(addr_d),
    .error_data(RD_DATA),
    .expected_data(dout_ref),
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
        
        loop_idx_d1  <= 32'd0    ;
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

        loop_idx_d1       <= loop_idx;
//        next_loop_start_d1 <= next_loop_start ;
        next_loop_start_d2 <= next_loop_start_d1 ;
        next_loop_start_d3 <= next_loop_start_d2 ;
  
        dout_d1     <= dout     ;
        dout_d2     <= dout_d1  ;
  
        addr_d      <= addr     ;
        addr_cnt_d  <= addr_cnt ;
        rd_en_d     <= rd_en;
        rd_en_d2    <= rd_en_d;
        
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
        loop_done         <= 1'b0;
        loop_finish       <= 1'b0;
//        next_loop_start   <= 1'b0;
        frame_ack_latched <= 1'b0;
    end
    else if (start_d1 != start_d2) begin
        // 测试开始时复位所有循环状态
        loop_idx          <= 32'd0;
        loop_done         <= 1'b0;
        loop_finish       <= 1'b0;
//        next_loop_start   <= 1'b0;
        frame_ack_latched <= 1'b0;
    end
    else begin
        // 默认清除 next_loop_start（保证单周期脉冲）
//        next_loop_start <= 1'b0;

        // ---------- 1. 锁存 send_frame_ack 脉冲 ----------
        if (send_frame_ack) begin
            frame_ack_latched <= 1'b1;
        end

        // ---------- 2. 检测循环结束条件（与原逻辑完全一致） ----------
        if (flg && (addr_cnt == vio_addr_num - 1) && (addr_hold_cnt + 1 == vio_t_AVAV)) begin
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

            if (loop_idx < loop_count - 1) begin
                loop_idx <= loop_idx + 1;   // 进入下一循环
            end
            else begin
                loop_done <= 1'b1;          // 所有循环完成
            end
        end
    end
end


//----
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        addr <= 22'd0;
    else if(start_d1!=0 && start_d1!=start_d2)
        addr <= vio_addr_ini;
     else if(flg && keep)
        addr <= vio_addr_ini + addr_cnt;
    else if(flg && addr_cnt<vio_addr_num)
        addr <= vio_addr_ini + addr_cnt;
    else if(addr_hold_cnt+1==vio_t_AVAV)
        addr <= 22'd0;
    else
        addr <= addr;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        addr_cnt <= 22'd0;
    else if(start_d1 != start_d2 || next_loop_start_d1)   // 增加 next_loop_start
        addr_cnt <= 22'd0;
    else if(keep && addr_cnt + 1 == vio_addr_num && addr_hold_cnt + 2 == vio_t_AVAV)
        addr_cnt <= 22'd0;
    else if(addr_cnt < vio_addr_num && addr_hold_cnt + 2 == vio_t_AVAV)
        addr_cnt <= addr_cnt + 1;
    else
        addr_cnt <= addr_cnt;
end


//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        addr_hold_cnt <= 21'd0;
    else if(next_loop_start_d1)
        addr_hold_cnt <= 21'd0;
    else if((next_loop_start_d2 != 0 && next_loop_start_d2 != next_loop_start_d3) || (addr_cnt < vio_addr_num && addr_hold_cnt == vio_t_AVAV)) //next_loop start
        addr_hold_cnt <= 1;
    else if((start_d2 != 0 && start_d2 != start_d3) || (addr_cnt < vio_addr_num && addr_hold_cnt == vio_t_AVAV))//第一次start
        addr_hold_cnt <= 1;
    else if(addr_hold_cnt == vio_t_AVAV)
        addr_hold_cnt <= 21'd0;
    else if(addr_hold_cnt)
        addr_hold_cnt <= addr_hold_cnt + 1;
    else
        addr_hold_cnt <= 21'd0;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        flg <= 1'b0;
    else if((start_d2 != 0 && start_d2 != start_d3) || next_loop_start_d1)   // 增加 next_loop_start
        flg <= 1'b1;
    else if(addr_cnt == vio_addr_num && addr_hold_cnt == vio_t_AVAV)
        flg <= 1'b0;
    else
        flg <= flg;   
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        dout_ref <= 16'h0;
    else if(addr_hold_cnt==vio_t_AVAV)
        dout_ref <= dout_d1;
    else
        dout_ref <= dout_ref;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        err_flg <= 1'b0;
    else if(flg && rd_en_d && (addr_hold_cnt==vio_t_AVQV-vio_t_AVAV) && addr_d!=vio_addr_ini && RD_DATA!=dout_ref)
        err_flg <= 1'b1;
    else if(flg && rd_en_d && addr_hold_cnt==vio_t_AVQV && RD_DATA!=dout_d1)
        err_flg <= 1'b1;
    else
        err_flg <= 1'b0;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        err_cnt <= 32'd0;
    else if(start_d1 != start_d2 || next_loop_start_d1)  // 增加循环变化清零
        err_cnt <= 32'd0;
    else if(err_flg)
        err_cnt <= err_cnt + 1;
end



always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
        trng_data_reg <= 8'd0;
        trng_valid_reg <= 1'b0;
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
    else if(addr_hold_cnt==vio_t_AVAV-1)
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
    else if(vio_t_EH2EL==0 && keep && addr_d!=addr)
        R_EN <= 1'b0;
    else if(vio_t_EH2EL==0 && ((start_d2!=0 && start_d2!=start_d3) || (addr_d!=addr && addr!=0)))
        R_EN <= 1'b0;
    else if(vio_t_EH2EL!=0 && addr_hold_cnt==vio_t_EH2EL)
        R_EN <= 1'b0;
    else if(addr_hold_cnt==vio_t_AVAV-vio_t_EL2EH)
        R_EN <= 1'b1;
    else
        R_EN <= R_EN;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        R_WN <= 1'b1;
    else if(vio_t_WH2WL==0 && keep && addr_d!=addr)
        R_WN <= 1'b0;
    else if(vio_t_WH2WL==0 && ((start_d2!=0 && start_d2!=start_d3) || (addr_d!=addr && addr!=0)))
        R_WN <= 1'b0;
    else if(vio_t_WH2WL!=0 && addr_hold_cnt==vio_t_WH2WL)
        R_WN <= 1'b0;
    else if(addr_hold_cnt==vio_t_AVAV-vio_t_WL2WH)
        R_WN <= 1'b1;
    else
        R_WN <= R_WN;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        R_GN <= 1'b1;
    else if(vio_t_GH2GL==0 && keep && addr_d!=addr)
        R_GN <= 1'b0;
    else if(vio_t_GH2GL==0 && ((start_d2!=0 && start_d2!=start_d3) || (addr_d!=addr && addr!=0)))
        R_GN <= 1'b0;
    else if(vio_t_GH2GL!=0 && addr_hold_cnt==vio_t_GH2GL)
        R_GN <= 1'b0;
    else if(addr_hold_cnt==vio_t_AVAV-vio_t_GL2GH)
        R_GN <= 1'b1;
    else
        R_GN <= R_GN;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        R_UBN <= 1'b1;
    else if(vio_t_UBH2UBL==0 && keep && addr_d!=addr)
        R_UBN <= 1'b0;
    else if(vio_t_UBH2UBL==0 && ((start_d2!=0 && start_d2!=start_d3) || (addr_d!=addr && addr!=0)))
        R_UBN <= 1'b0;
    else if(vio_t_UBH2UBL!=0 && addr_hold_cnt==vio_t_UBH2UBL)
        R_UBN <= 1'b0;
    else if(addr_hold_cnt==vio_t_AVAV-vio_t_UBL2UBH)
        R_UBN <= 1'b1;
    else
        R_UBN <= R_UBN;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        R_LBN <= 1'b1;
    else if(vio_t_LBH2LBL==0 && keep && addr_d!=addr)
        R_LBN <= 1'b0;
    else if(vio_t_LBH2LBL==0 && ((start_d2!=0 && start_d2!=start_d3) || (addr_d!=addr && addr!=0)))
        R_LBN <= 1'b0;
    else if(vio_t_LBH2LBL!=0 && addr_hold_cnt==vio_t_LBH2LBL)
        R_LBN <= 1'b0;
    else if(addr_hold_cnt==vio_t_AVAV-vio_t_LBL2LBH)
        R_LBN <= 1'b1;
    else
        R_LBN <= R_LBN;
end

//---
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        R_DQ <= 16'h0;
    else if(rd_en_d)
        R_DQ <= 16'hz;
    else if(vio_t_AV2DV==0 && keep && addr_d!=addr)
        R_DQ <= dout;
    else if(vio_t_AV2DV==0 && ((start_d2!=0 && start_d2!=start_d3) || (addr_d!=addr && addr!=0)))
        R_DQ <= dout;
    else if(vio_t_AV2DV!=0 && addr_hold_cnt==vio_t_AV2DV)
        R_DQ <= dout;
    else if(addr_hold_cnt==vio_t_AVAV)
        R_DQ <= 16'h0;
    else
        R_DQ <= R_DQ;
end


//----------------------------------------------------------------
// 在 loop_finish 期间暂停地址访问
always @(posedge clk or negedge rstn) begin
    if(!rstn)
        keep <= 1'b0;
    else if(start_d2 == 0 && start_d1 == 1) begin
        keep <= 1'b1;                      // 测试开始允许地址访问
    end
    else if(loop_done && addr_hold_cnt == vio_t_AVAV) begin
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
                else if(addr_cnt + 1 == vio_addr_num && addr_hold_cnt + 2 == vio_t_AVAV)
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

