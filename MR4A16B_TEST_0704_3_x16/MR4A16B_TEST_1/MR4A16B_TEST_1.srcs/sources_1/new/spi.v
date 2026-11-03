`timescale 1ns / 1ps

module spi_protocol #(
    parameter CLK_FREQUENCE = 200_000_000,
    parameter SPI_FREQUENCE = 5_000_000,
    parameter DATA_WIDTH = 8,
    parameter CPOL = 0,   
    parameter CPHA = 0    
)(
    input  wire clk,
    input  wire rst_n,
    
    // SPI接口 - Slave模式
    input  wire spi_sclk, 
    input  wire spi_cs_n,
    input  wire spi_mosi, 
    output wire spi_miso,
    
    // 配置输出
    output reg [7:0]  chip_type,
    output reg [3:0]  test_mode,
    output reg [7:0]  data_pattern,
    output reg [21:0] start_addr,
    output reg [22:0] test_length,
    output reg [31:0] loop_count,
    output reg [1:0]  write_mode,
    output reg [1:0]  read_mode,
    output reg [7:0]  err_detail_print,
    
    // 时序参数输出
    //写
    output reg [15:0] t_avav_w,
    output reg [15:0] t_avqv_w,
    output reg [15:0] t_av2dv_w,
    output reg [15:0] t_eh2el_w,
    output reg [15:0] t_el2eh_w,
    output reg [15:0] t_wh2wl_w,
    output reg [15:0] t_wl2wh_w,
    output reg [15:0] t_gh2gl_w,
    output reg [15:0] t_gl2gh_w,
    output reg [15:0] t_ubh2ubl_w,
    output reg [15:0] t_ubl2ubh_w,
    output reg [15:0] t_lbh2lbl_w,
    output reg [15:0] t_lbl2lbh_w,
    //读
    output reg [15:0] t_avav_r,
    output reg [15:0] t_avqv_r,
    output reg [15:0] t_av2dv_r,
    output reg [15:0] t_eh2el_r,
    output reg [15:0] t_el2eh_r,
    output reg [15:0] t_wh2wl_r,
    output reg [15:0] t_wl2wh_r,
    output reg [15:0] t_gh2gl_r,
    output reg [15:0] t_gl2gh_r,
    output reg [15:0] t_ubh2ubl_r,
    output reg [15:0] t_ubl2ubh_r,
    output reg [15:0] t_lbh2lbl_r,
    output reg [15:0] t_lbl2lbh_r,
    
    // 控制信号
    output reg start_test,
    output reg start_test_d1,
    (*mark_debug="true"*)output reg stop_test,
    (*mark_debug="true"*)output reg stop_cmd_match,
    (*mark_debug="true"*)output reg tx_done_pulse,
    
    // 状态反馈输入
    input  wire [31:0] current_loop,
    input  wire test_busy,
    input  wire test_done,
    input  wire [31:0] error_cnt,
    input  wire err_flag,
    input  wire [21:0] error_addr,
    input  wire [15:0] error_data,
    input  wire [15:0] expected_data,
    
    // 测试完成信号（由top产生）
    input  wire test_complete
);

// ========== 帧定义 ==========
localparam FRAME_HEADER = 8'h55;
localparam FRAME_TAIL   = 8'hAA;
localparam STOP_CMD     = 8'hFF;

// ========== 内部信号线 ==========
wire [DATA_WIDTH-1:0] spi_data_out;
wire spi_data_valid;
wire spi_shift_en;
wire spi_sampl_en;

// ========== SPI_Slave 例化 ==========
SPI_Slave #(
    .CLK_FREQUENCE(CLK_FREQUENCE),
    .SPI_FREQUENCE(SPI_FREQUENCE),
    .DATA_WIDTH(DATA_WIDTH),
    .CPOL(CPOL),
    .CPHA(CPHA)
) u_spi_slave (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(8'h00), // 改为内部移位控制，数据端给默认值
    .sclk(spi_sclk),
    .cs_n(spi_cs_n),
    .mosi(spi_mosi),
    .miso(),         // MISO在外部自行组装控制
    .data_valid(spi_data_valid),
    .data_out(spi_data_out),
    .shift_en(spi_shift_en),
    .sampl_en(spi_sampl_en)
);




// =========================================================================
// 1. 边沿检测与同步信号提取 (独立模块)
// =========================================================================
reg spi_data_valid_d1;
reg rx_valid_d1, rx_valid_d2;
reg test_complete_d1;
(*mark_debug="true"*)reg tx_sending;
(*mark_debug="true"*)reg tx_sending_d1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        spi_data_valid_d1 <= 1'b0;
        rx_valid_d1       <= 1'b0;
        rx_valid_d2       <= 1'b0;
        test_complete_d1  <= 1'b0;
        tx_sending_d1     <= 1'b0;
        start_test_d1     <= 1'b0;
    end else begin
        spi_data_valid_d1 <= spi_data_valid;
        rx_valid_d1       <= spi_data_valid;
        rx_valid_d2       <= rx_valid_d1;
        test_complete_d1  <= test_complete;
        tx_sending_d1     <= tx_sending;
        start_test_d1     <= start_test;
    end
end

wire spi_data_valid_d2 = !spi_data_valid && spi_data_valid_d1;
wire test_complete_rise = test_complete && !test_complete_d1;


// =========================================================================
// 2. 接收数据锁存 (独立模块)
// =========================================================================
reg [7:0] spi_rx_data;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        spi_rx_data <= 8'h00;
    else if (spi_data_valid)
        spi_rx_data <= spi_data_out;
end

// =========================================================================
// 3. 超时检测模块 (已放宽超时至100ms: 20M个时钟周期)
// =========================================================================
reg [31:0] timeout_counter;
reg        timeout_detected;
reg [4:0]  rx_state; // 前向声明，用于判断是否在接收中

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timeout_counter  <= 32'd0;
        timeout_detected <= 1'b0;
    end else begin
        if (rx_state != 0 && !spi_data_valid_d2) begin
            timeout_counter <= timeout_counter + 1;
            if (timeout_counter > 32'd20_000_000) begin
                timeout_detected <= 1'b1;
            end
        end else begin
            timeout_counter  <= 32'd0;
            timeout_detected <= 1'b0;
        end
    end
end

// =========================================================================
// 4. 停止命令 (55 FF AA) 独立检测模块
// =========================================================================
reg [23:0] stop_cmd_buffer;
reg        stop_cmd_detected;
(*mark_debug="true"*)reg        send_stop_flag; // 用于下方的清除逻辑

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        stop_cmd_buffer   <= 24'h0;
        stop_cmd_match    <= 1'b0;
        stop_cmd_detected <= 1'b0;
        stop_test         <= 1'b0;
    end else begin
        // 脉冲信号清零
        stop_test <= 1'b0; 

        if (rx_valid_d1 && !rx_valid_d2) begin
            stop_cmd_buffer <= {stop_cmd_buffer[15:0], spi_rx_data};
            if ({stop_cmd_buffer[15:0], spi_rx_data} == 24'h55FFAA) begin
                stop_cmd_match    <= 1'b1;
                stop_cmd_detected <= 1'b1;
                stop_test         <= 1'b1; // 单周期脉冲
            end else begin
                stop_cmd_match    <= 1'b0;
            end
        end

        // 当停止命令的响应帧发送完毕后，清除检测标志
        if (send_stop_flag && !tx_sending && tx_sending_d1) begin
            stop_cmd_detected <= 1'b0;
        end
    end
end


// =========================================================================
// 5. RX 主状态机 (仅控制状态跳转、字节计数和校验和)
// =========================================================================
reg [4:0] rx_byte_cnt;
reg [7:0] calc_checksum;
reg       checksum_ok; // 【新增】：用于暂存校验结果

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_state      <= 5'd0;
        rx_byte_cnt   <= 5'd0;
        calc_checksum <= 8'd0;
        checksum_ok   <= 1'b0;
        start_test    <= 1'b0;
    end
    else begin
        if (timeout_detected) begin
            rx_state      <= 5'd0;
            rx_byte_cnt   <= 5'd0;
            calc_checksum <= 8'd0;
            checksum_ok   <= 1'b0;
        end
        else if (spi_data_valid_d2) begin
            case (rx_state)
                0: begin
                    start_test    <= 1'b0;
                    if (spi_rx_data == FRAME_HEADER) begin
                        rx_state      <= 5'd1;
                        calc_checksum <= 8'h00;
                        rx_byte_cnt   <= 5'd1;
                        checksum_ok   <= 1'b0;
                    end
                end
                
                // 1 到 21 均是累加 Checksum 并跳转
                1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21: begin
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state      <= rx_state + 1;
                    rx_byte_cnt   <= rx_byte_cnt + 1;
                end
                
                22: begin
                    if (calc_checksum == spi_rx_data)
                        checksum_ok <= 1'b1;
                    else
                        checksum_ok <= 1'b0;
                        
                    rx_state    <= 5'd23;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                
                23: begin
                    if (spi_rx_data == FRAME_TAIL && checksum_ok) begin
                        start_test <= 1'b1; // 单周期脉冲，测试正式启动
                    end
                    // 无论成功失败，恢复空闲态
                    rx_state      <= 5'd0;
                    calc_checksum <= 8'd0;
                    rx_byte_cnt   <= 5'd0;
                end
                
                default: begin
                    rx_state      <= 5'd0;
                    calc_checksum <= 8'd0;
                    rx_byte_cnt   <= 5'd0;
                end
            endcase
        end
        else begin
            case (rx_state)
                0: begin
                    start_test    <= 1'b0;
                  end
            endcase
         end
    end
end

// =========================================================================
// 6. RX 临时配置寄存器 (随状态机逐步锁存，解耦代码)
// =========================================================================
reg [7:0]  chip_type_reg;
reg [3:0]  t_mode_reg;
reg [7:0]  din_sel_reg;
reg [31:0] addr_ini_reg;
reg [31:0] addr_num_reg;
reg [31:0] loop_cnt_reg;
reg [1:0]  write_mode_reg;
reg [1:0]  read_mode_reg;
reg [15:0] t_avav_reg;
reg [7:0]  err_detail_print_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        chip_type_reg  <= 8'b10000000;
        t_mode_reg     <= 4'd0;
        din_sel_reg    <= 8'd0;
        addr_ini_reg   <= 32'd0;
        addr_num_reg   <= 32'd0;
        loop_cnt_reg   <= 32'd1;
        write_mode_reg <= 2'd0;
        read_mode_reg  <= 2'd0;
        t_avav_reg     <= 16'd8;
        err_detail_print_reg <= 8'd0;
    end else if (spi_data_valid_d2 && !timeout_detected) begin
        case (rx_state)
            1:  chip_type_reg          <= spi_rx_data;
            2:  t_mode_reg             <= spi_rx_data[3:0];
            3:  din_sel_reg            <= spi_rx_data;
            4:  addr_ini_reg[7:0]      <= spi_rx_data;
            5:  addr_ini_reg[15:8]     <= spi_rx_data;
            6:  addr_ini_reg[21:16]    <= spi_rx_data[3:0];
            8:  addr_num_reg[7:0]      <= spi_rx_data;
            9:  addr_num_reg[15:8]     <= spi_rx_data;
            10: addr_num_reg[23:16]    <= spi_rx_data;
            11: addr_num_reg[31:24]    <= spi_rx_data;
            12: loop_cnt_reg[7:0]      <= spi_rx_data;
            13: loop_cnt_reg[15:8]     <= spi_rx_data;
            14: loop_cnt_reg[23:16]    <= spi_rx_data;
            15: loop_cnt_reg[31:24]    <= spi_rx_data;
            16: t_avav_reg[7:0]        <= spi_rx_data;
            17: write_mode_reg         <= spi_rx_data[1:0];
            18: read_mode_reg          <= spi_rx_data[1:0];
            19: err_detail_print_reg  <= spi_rx_data;
            default: ; // 其他状态不需要锁存数据
        endcase
    end
end

// =========================================================================
// 7. 正式配置生效模块 (仅在Checksum验证成功时更新输出)
// =========================================================================
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        chip_type    <= 8'b10000000; 
		test_mode    <= 4'd0;
        data_pattern <= 8'd0;        
		start_addr   <= 22'd0;
        test_length  <= 23'd0;       
		loop_count   <= 32'd1;
        write_mode   <= 2'd0;        
		read_mode    <= 2'd0;
		err_detail_print <= 8'd0;
        // 写时序默认 50ns
        t_avav_w       <= 16'd10;       
		t_avqv_w       <= 16'd9;
        t_av2dv_w      <= 0; 
		t_eh2el_w <= 3; t_el2eh_w <= 3;
        t_wh2wl_w <= 1; t_wl2wh_w <= 2; 
		t_gh2gl_w <= 1; t_gl2gh_w <= 2;
        t_ubh2ubl_w <= 1; t_ubl2ubh_w <= 2; 
		t_lbh2lbl_w <= 1; t_lbl2lbh_w <= 2;
        // 读时序默认  50ns
        t_avav_r       <= 16'd10;       
		t_avqv_r       <= 16'd9;
        t_av2dv_r      <= 0; 
		t_eh2el_r <= 0; t_el2eh_r <= 10;
        t_wh2wl_r <= 0; t_wl2wh_r <= 10; 
		t_gh2gl_r <= 0; t_gl2gh_r <= 10;
        t_ubh2ubl_r <= 0; t_ubl2ubh_r <= 10; 
		t_lbh2lbl_r <= 0; t_lbl2lbh_r <= 10;
    end else if (spi_data_valid_d2 && rx_state == 22 && calc_checksum == spi_rx_data) begin
        // 校验成功，将临时寄存器的值赋给正式输出引脚
        chip_type       <= chip_type_reg;
        test_mode       <= t_mode_reg;
        data_pattern    <= din_sel_reg;
        start_addr      <= addr_ini_reg[21:0];
        test_length     <= addr_num_reg[22:0];
        loop_count       <= loop_cnt_reg;
        write_mode       <= write_mode_reg;
        read_mode        <= read_mode_reg;
        t_avav_w         <= t_avav_reg;
        t_avav_r         <= t_avav_reg;
        err_detail_print <= err_detail_print_reg;
        t_avqv_w         <= 16'd9;
        t_avqv_r         <= 16'd9;
 
        // ---------- 写模式时序参数解码 ----------
        case (write_mode_reg)
             2'b00: begin   // CEN GH
                t_av2dv_w <= 0;
                t_eh2el_w <= 1; t_el2eh_w <= 3; 
				t_wh2wl_w <= 0; t_wl2wh_w <= 2;
                t_gh2gl_w <= t_avav_reg; t_gl2gh_w <= 0;
                t_ubh2ubl_w <= 1; t_ubl2ubh_w <= 3;
                t_lbh2lbl_w <= 1; t_lbl2lbh_w <= 3;
            end
            2'b01: begin // WEN
                t_av2dv_w <= 0;
                t_eh2el_w <= 1; t_el2eh_w <= 1; 
				t_wh2wl_w <= 2; t_wl2wh_w <= 2;
                t_gh2gl_w <= t_avav_reg; t_gl2gh_w <= 0;
                t_ubh2ubl_w <= 0; t_ubl2ubh_w <= 2;
                t_lbh2lbl_w <= 0; t_lbl2lbh_w <= 2;
            end
            2'b10: begin  // BN
                t_av2dv_w <= 0;
                t_eh2el_w <= 1; t_el2eh_w <= 1; 
				t_wh2wl_w <= 1; t_wl2wh_w <= 1;
                t_gh2gl_w <= t_avav_reg; t_gl2gh_w <= 0;
                t_ubh2ubl_w <= 2; t_ubl2ubh_w <= 2;
                t_lbh2lbl_w <= 2; t_lbl2lbh_w <= 2;
            end
            default: begin
                t_avav_w  <= 16'd10;       
                t_avqv_w  <= 16'd9;
                t_av2dv_w <= 0;
                t_eh2el_w <= 1; t_el2eh_w <= 3; 
				t_wh2wl_w <= 0; t_wl2wh_w <= 2;
                t_gh2gl_w <= t_avav_reg; t_gl2gh_w <= 0;
                t_ubh2ubl_w <= 0; t_ubl2ubh_w <= 2;
                t_lbh2lbl_w <= 0; t_lbl2lbh_w <= 2;
            end
        endcase

        // ---------- 读模式时序参数解码 ----------
        case (read_mode_reg)
            2'b00: begin  // Read Cycle1
                t_av2dv_r <= 0;
                t_eh2el_r <= 0; t_el2eh_r <= t_avav_reg;
                t_wh2wl_r <= 0; t_wl2wh_r <= t_avav_reg;
                t_gh2gl_r <= 0; t_gl2gh_r <= t_avav_reg;
                t_ubh2ubl_r <= 0; t_ubl2ubh_r <= t_avav_reg;
                t_lbh2lbl_r <= 0; t_lbl2lbh_r <= t_avav_reg;
            end
            2'b01: begin  // Read Cycle2
                t_avqv_r  <= 9;
                t_av2dv_r <= 0;
                t_eh2el_r <= 1; t_el2eh_r <= 0; 
				t_wh2wl_r <= 0; t_wl2wh_r <= t_avav_reg + 1;
                t_gh2gl_r <= 2; t_gl2gh_r <= 0;
                t_ubh2ubl_r <= 1; t_ubl2ubh_r <= 0;
                t_lbh2lbl_r <= 1; t_lbl2lbh_r <= 0;
            end
            default: begin
                t_av2dv_r <= 0;
                t_eh2el_r <= 0; t_el2eh_r <= t_avav_reg; 
				t_wh2wl_r <= 0; t_wl2wh_r <= t_avav_reg;
                t_gh2gl_r <= 0; t_gl2gh_r <= t_avav_reg;
                t_ubh2ubl_r <= 0; t_ubl2ubh_r <= t_avav_reg;
                t_lbh2lbl_r <= 0; t_lbl2lbh_r <= t_avav_reg;
            end
        endcase

        // x8芯片复写(chip_type=0x80/0x82)
        if (chip_type_reg == 8'b10000000 || chip_type_reg == 8'b10000010) begin
            t_ubh2ubl_w <= 0; t_ubl2ubh_w <= t_avav_reg + 1;
            t_lbh2lbl_w <= 0; t_lbl2lbh_w <= t_avav_reg + 1;
            t_ubh2ubl_r <= 0; t_ubl2ubh_r <= t_avav_reg + 1;
            t_lbh2lbl_r <= 0; t_lbl2lbh_r <= t_avav_reg + 1;
        end
    end
end


// =========================================================================
// 8. TX 发送触发与缓冲区准备 （优化版：无多驱动，启动与移位分离）
// =========================================================================

// ---------- 8.1 边沿检测 ----------
reg        cs_n_d1;
wire       cs_n_neg;
wire       cs_n_pos;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cs_n_d1 <= 1'b1;
    else        cs_n_d1 <= spi_cs_n;
end
assign cs_n_neg = !spi_cs_n && cs_n_d1;
assign cs_n_pos = spi_cs_n && !cs_n_d1;

// ---------- 8.2 待发送事件锁存 ----------
reg        pending_test_complete;
reg        pending_stop;
reg        test_frame_acked;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pending_test_complete <= 1'b0;
    else if (test_complete_rise)
        pending_test_complete <= 1'b1;
    else if (test_frame_acked)
        pending_test_complete <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pending_stop <= 1'b0;
    else if (stop_cmd_detected)
        pending_stop <= 1'b1;
    else if (cs_n_neg)
        pending_stop <= 1'b0;
end

// ---------- 8.3 发送启动逻辑（只填充缓冲区，产生启动脉冲） ----------
reg        frame_sent_this_cs;
reg [7:0]  tx_buf [0:31];      // 发送缓冲区
reg [4:0]  tx_byte_cnt;        // 总字节数
reg        tx_start;           // 启动脉冲（仅在此块赋值）

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_byte_cnt <= 5'd0;
        frame_sent_this_cs <= 1'b0;
        tx_start <= 1'b0;
    end else begin
        tx_start <= 1'b0;   // 默认低

        if (cs_n_pos) begin
            frame_sent_this_cs <= 1'b0;
        end

        if (cs_n_neg) begin
            frame_sent_this_cs <= 1'b0;   // 新周期复位
            if (!tx_sending && !frame_sent_this_cs && pending_test_complete) begin
                // 填充缓冲区
                tx_buf[0] <= 8'h55;
                if (test_mode == 2'd2) begin
                    tx_buf[1]  <= 8'h11;
                    tx_buf[2]  <= 8'hFF;
                    tx_buf[3]  <= current_loop[7:0];
                    tx_buf[4]  <= current_loop[15:8];
                    tx_buf[5]  <= current_loop[23:16];
                    tx_buf[6]  <= current_loop[31:24];
                    tx_buf[7]  <= test_length[7:0];
                    tx_buf[8]  <= test_length[15:8];
                    tx_buf[9]  <= test_length[22:16];
                    tx_buf[10] <= 8'h00;
                    tx_buf[11] <= err_flag;
                    tx_buf[12] <= error_cnt[7:0];
                    tx_buf[13] <= error_cnt[15:8];
                    tx_buf[14] <= error_cnt[23:16];
                    tx_buf[15] <= error_cnt[31:24];
                    tx_buf[16] <= 8'hAA;
                    tx_byte_cnt <= 5'd17;
                end else begin
                    tx_buf[1]  <= 8'hFF;
                    tx_buf[2]  <= current_loop[7:0];
                    tx_buf[3]  <= current_loop[15:8];
                    tx_buf[4]  <= current_loop[23:16];
                    tx_buf[5]  <= current_loop[31:24];
                    tx_buf[6]  <= test_length[7:0];
                    tx_buf[7]  <= test_length[15:8];
                    tx_buf[8]  <= test_length[22:16];
                    tx_buf[9]  <= 8'h00;
                    tx_buf[10] <= 8'hAA;
                    tx_byte_cnt <= 5'd11;
                end
                tx_start          <= 1'b1;   // 启动脉冲
                frame_sent_this_cs <= 1'b1;
                // pending_test_complete 由 test_frame_acked 清除
            end
        end
    end
end

// ---------- 8.4 SPI 移位发送状态机（全权管理所有移位相关寄存器） ----------
reg [4:0]  tx_byte_ptr;
reg [2:0]  tx_bit_cnt;
reg [7:0]  tx_shift_reg;
// Retain the observation point used by the existing MRAM testbench.
wire       miso_out_pre = tx_shift_reg[7];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_sending      <= 1'b0;
        tx_byte_ptr     <= 5'd0;
        tx_bit_cnt      <= 3'd0;
        tx_shift_reg    <= 8'h00;
        tx_done_pulse   <= 1'b0;
        test_frame_acked <= 1'b0;
    end else begin
        tx_done_pulse   <= 1'b0;
        test_frame_acked <= 1'b0;

        // 检测启动脉冲，加载初值
        if (tx_start) begin
            tx_byte_ptr  <= 5'd0;
            tx_bit_cnt   <= 3'd0;
            tx_shift_reg <= tx_buf[0];    // 加载第一个字节
            tx_sending   <= 1'b1;
        end

        // SPI 移位发送
        if (tx_sending && spi_shift_en) begin
            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};

            if (tx_bit_cnt == 3'd7) begin
                tx_bit_cnt <= 3'd0;
                if (tx_byte_ptr < tx_byte_cnt - 1) begin
                    tx_byte_ptr  <= tx_byte_ptr + 1;
                    tx_shift_reg <= tx_buf[tx_byte_ptr + 1];
                end else begin
                    // 发送完成
                    tx_sending   <= 1'b0;
                    tx_shift_reg <= 8'h00;
                    tx_done_pulse <= 1'b1;
                    test_frame_acked <= 1'b1;
                end
            end else begin
                tx_bit_cnt <= tx_bit_cnt + 1;
            end
        end

        // CS 上升沿强制停止发送
        if (cs_n_pos && tx_sending) begin
            tx_sending   <= 1'b0;
            tx_bit_cnt   <= 3'd0;
            tx_shift_reg <= 8'h00;
        end
    end
end

// ---------- 8.5 MISO 引脚输出 ----------
// The shift register already holds the next MISO bit, including byte reloads.
// Do not mux it with a second register using the SCLK edge-detect pulse: that
// select and both data inputs change on the same clk edge at byte boundaries.
assign spi_miso = (!spi_cs_n && tx_sending) ? tx_shift_reg[7] : 1'b0;

endmodule