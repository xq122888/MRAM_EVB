`timescale 1ns / 1ps

module spi_protocol #(
    parameter CLK_FREQUENCE = 200_000_000,
    parameter SPI_FREQUENCE = 5_000_000,
    parameter DATA_WIDTH = 8,
    parameter CPOL = 0,   
    parameter CPHA = 0,
    parameter DETAIL_FIFO_ADDR_BITS = 12
)(
    input  wire clk,
    input  wire rst_n,
    
    // SPI接口 - Slave模式
    input  wire spi_sclk, 
    input  wire spi_cs_n,
    input  wire spi_mosi, 
    output wire spi_miso,
    
    // 配置输出
    output wire configuration_commit,
    output reg [7:0]  chip_type,
    output reg [3:0]  test_mode,
    output reg [7:0]  data_pattern,
    output reg [21:0] start_addr,
    output reg [22:0] test_length,
    output reg [31:0] loop_count,
    // Decode terminal values at the same configuration commit as their bases.
    output reg [31:0] last_loop_index,
    output reg [20:0] last_test_address,
    output reg [15:0] period_last_w,
    output reg [15:0] period_before_last_w,
    output reg [15:0] period_last_r,
    output reg [15:0] period_before_last_r,
    // GN release uses the same delayed read/write bank for both operands.
    output reg [20:0] gn_release_w,
    output reg [20:0] gn_release_r,
    output reg [20:0] compare_early_w,
    output reg [20:0] compare_early_r,
    output reg [20:0] en_release_w,
    output reg [20:0] en_release_r,
    output reg [20:0] wn_release_w,
    output reg [20:0] wn_release_r,
    output reg [20:0] ub_release_w,
    output reg [20:0] ub_release_r,
    output reg [20:0] lb_release_w,
    output reg [20:0] lb_release_r,

    output reg [1:0]  write_mode,
    output reg [1:0]  read_mode,
    output reg [7:0]  err_detail_print,
    // Commit slow configuration predicates once, before test_start.
    output reg detail_enabled,
    output reg period_has_one_w, period_has_one_r,
    output reg period_has_two_w, period_has_two_r,
    
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
    output reg stop_test,
    output reg stop_cmd_match,
    output reg tx_done_pulse,
    // Nonblocking detail queue diagnostics; only summary frames ACK loops.
    output wire detail_stall,
    output wire detail_overflow,
    output wire [31:0] detail_dropped_count,
    input wire random_seed_ready,
    output reg start_waiting,
    
    // 状态反馈输入
    input  wire [31:0] current_loop,
    input  wire test_busy,
    input  wire test_done,
    input  wire [31:0] error_cnt,
    input  wire err_flag, // one-cycle compare event; payload inputs are snapshots
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
reg tx_sending;
reg tx_sending_d1;

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
reg        send_stop_flag; // 用于下方的清除逻辑

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
                    if (calc_checksum == spi_rx_data && pattern_configuration_supported)
                        checksum_ok <= 1'b1;
                    else
                        checksum_ok <= 1'b0;
                        
                    rx_state    <= 5'd23;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                
                23: begin
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
    end
end

// A random-mode request waits for one complete fresh TRNG seed. Non-random
// modes retain the original tail-to-start timing. Never use a constant fallback.
// March C is a new x16-only algorithm for the standalone write/read modes.
// Reject unsupported combinations atomically: no live configuration or start.
wire pattern_configuration_supported = (din_sel_reg!=8'd10) ||
    ((chip_type_reg!=8'h80 && chip_type_reg!=8'h82) && t_mode_reg<4'd2);
wire valid_start_request = spi_data_valid_d2 && !timeout_detected &&
    (rx_state==5'd23) && (spi_rx_data==FRAME_TAIL) && checksum_ok;
wire start_permitted = (data_pattern!=8'd9) || random_seed_ready;
wire starting_new_frame = spi_data_valid_d2 && (rx_state==0) &&
    (spi_rx_data==FRAME_HEADER);
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin start_test<=0;start_waiting<=0;end
    else begin
        start_test<=0;
        if(config_commit || timeout_detected || stop_test) start_waiting<=0;
        else if((valid_start_request || start_waiting) && start_permitted &&
                ((rx_state==0 && !starting_new_frame) || valid_start_request)) begin
            start_test<=1;start_waiting<=0;
        end else if(valid_start_request) start_waiting<=1;
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
// Register the configuration write enable. This separates checksum/state
// decode from the high-fanout enables of the base and predecoded registers.
// Temporary fields remain stable; the frame tail/start follows a full SPI byte
// later, so all parameters are committed before start_test is asserted.
// These are the same period/GL2GH values selected by the existing mode cases.
wire [15:0] commit_write_period = (write_mode_reg == 2'b11) ? 16'd10 : t_avav_reg;
// Read2 has a 40 ns minimum; write timing retains the requested period.
wire [15:0] commit_read_period = (read_mode_reg==2'b01 && t_avav_reg<16'd8) ? 16'd8 : t_avav_reg;
wire [15:0] commit_read_sample = (read_mode_reg==2'b01) ? 16'd9 : 16'd8;
// Exact post-mode offsets, including the 16-bit x8 period+1 wrap.
// These decode once per configuration, outside the running MRAM control paths.
wire [15:0] commit_en_offset_w = (write_mode_reg == 2'b00 || write_mode_reg == 2'b11) ? 16'd3 : 16'd2;
wire [15:0] commit_wn_offset = (write_mode_reg == 2'b01) ? 16'd3 : 16'd2;
wire [15:0] commit_bn_offset_w = (write_mode_reg == 2'b10) ? 16'd3 : 16'd2;
wire commit_x8 = (chip_type_reg == 8'h80) || (chip_type_reg == 8'h82);
wire [15:0] commit_x8_offset = t_avav_reg + 16'd1;
wire [15:0] commit_en_offset_r = (read_mode_reg == 2'b01) ? 16'd0 : commit_read_period;
wire [15:0] commit_x8_offset_r = commit_read_period + 16'd1;
wire [15:0] commit_bn_w = commit_x8 ? commit_x8_offset : commit_bn_offset_w;
wire [15:0] commit_bn_r = commit_x8 ? commit_x8_offset_r : commit_en_offset_r;
reg config_commit;
assign configuration_commit=config_commit;
reg report_with_errors;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) report_with_errors<=0;
    else if(config_commit) report_with_errors<=(t_mode_reg==4'd2 || din_sel_reg==8'd10);
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        config_commit <= 1'b0;
    else
        config_commit <= spi_data_valid_d2 && (rx_state == 5'd22) &&
                         (calc_checksum == spi_rx_data) && pattern_configuration_supported;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        chip_type    <= 8'b10000000; 
		test_mode    <= 4'd0;
        data_pattern <= 8'd0;        
		start_addr   <= 22'd0;
        test_length  <= 23'd0;       
		loop_count   <= 32'd1;
        last_loop_index <= 32'd0;
        last_test_address <= 21'h1fffff;
        period_last_w <= 16'd9;
        period_before_last_w <= 16'd8;
        period_last_r <= 16'd9;
        period_before_last_r <= 16'd8;
        gn_release_w <= 21'd10;
        gn_release_r <= 21'd0;
        compare_early_w <= 21'h1ffffe;
        compare_early_r <= 21'h1ffffe;
        en_release_w <= 21'd7;
        en_release_r <= 21'd0;
        wn_release_w <= 21'd8;
        wn_release_r <= 21'd8;
        ub_release_w <= 21'd8;
        ub_release_r <= 21'd0;
        lb_release_w <= 21'd8;
        lb_release_r <= 21'd0;

        write_mode   <= 2'd0;        
		read_mode    <= 2'd0;
		err_detail_print <= 8'd0;
        detail_enabled <= 1'b0;
        period_has_one_w <= 1'b1;
        period_has_one_r <= 1'b1;
        period_has_two_w <= 1'b1;
        period_has_two_r <= 1'b1;
        // 写时序默认 50ns
        t_avav_w       <= 16'd10;       
		t_avqv_w       <= 16'd9;
        t_av2dv_w      <= 0; 
		t_eh2el_w <= 1; t_el2eh_w <= 3;
        t_wh2wl_w <= 0; t_wl2wh_w <= 2;
		t_gh2gl_w <= 10; t_gl2gh_w <= 0;
        t_ubh2ubl_w <= 0; t_ubl2ubh_w <= 2;
		t_lbh2lbl_w <= 0; t_lbl2lbh_w <= 2;
        // 读时序默认  50ns
        t_avav_r       <= 16'd10;       
		t_avqv_r       <= 16'd8;
        t_av2dv_r      <= 0; 
		t_eh2el_r <= 0; t_el2eh_r <= 10;
        t_wh2wl_r <= 0; t_wl2wh_r <= 10; 
		t_gh2gl_r <= 0; t_gl2gh_r <= 10;
        t_ubh2ubl_r <= 0; t_ubl2ubh_r <= 10; 
		t_lbh2lbl_r <= 0; t_lbl2lbh_r <= 10;
    end else if (config_commit) begin
        // 校验成功，将临时寄存器的值赋给正式输出引脚
        chip_type       <= chip_type_reg;
        test_mode       <= t_mode_reg;
        data_pattern    <= din_sel_reg;
        start_addr      <= addr_ini_reg[21:0];
        test_length     <= addr_num_reg[22:0];
        loop_count       <= loop_cnt_reg;
        last_loop_index <= loop_cnt_reg - 32'd1;
        // top.v historically uses the low 21 bits of test_length.
        last_test_address <= addr_num_reg[20:0] - 21'd1;
        // GL2GH is zero for configured writes. For reads it is either zero
        // (mode 1) or the entire period (all other modes). Both operands use
        // rd_en_d2 in top.v. Reset values above preserve the initial 10-2/10-10.
        gn_release_w <= {5'b0,commit_write_period};
        gn_release_r <= (read_mode_reg == 2'b01) ? {5'b0,commit_read_period} : 21'd0;
        compare_early_w <= {5'b0,commit_read_sample} - {5'b0,commit_write_period};
        compare_early_r <= {5'b0,commit_read_sample} - {5'b0,commit_read_period};
        en_release_w <= {5'b0,commit_write_period} - {5'b0,commit_en_offset_w};
        en_release_r <= {5'b0,commit_read_period} - {5'b0,commit_en_offset_r};
        wn_release_w <= {5'b0,commit_write_period} - {5'b0,commit_wn_offset};
        wn_release_r <= {5'b0,commit_read_period} - {5'b0,commit_wn_offset};
        ub_release_w <= {5'b0,commit_write_period} - {5'b0,commit_bn_w};
        ub_release_r <= {5'b0,commit_read_period} - {5'b0,commit_bn_r};
        lb_release_w <= {5'b0,commit_write_period} - {5'b0,commit_bn_w};
        lb_release_r <= {5'b0,commit_read_period} - {5'b0,commit_bn_r};
        period_last_r <= commit_read_period - 16'd1;
        period_before_last_r <= commit_read_period - 16'd2;
        // Invalid write_mode uses the existing 10-cycle fallback below.
        period_last_w <= (write_mode_reg == 2'b11) ? 16'd9 : (t_avav_reg - 16'd1);
        period_before_last_w <= (write_mode_reg == 2'b11) ? 16'd8 : (t_avav_reg - 16'd2);
        write_mode       <= write_mode_reg;
        read_mode        <= read_mode_reg;
        t_avav_w         <= t_avav_reg;
        t_avav_r         <= commit_read_period;
        err_detail_print <= err_detail_print_reg;
        detail_enabled <= ((t_mode_reg == 4'd2) || (din_sel_reg==8'd10)) && (err_detail_print_reg == 8'd1);
        period_has_one_w <= (commit_write_period >= 16'd1);
        period_has_one_r <= (commit_read_period >= 16'd1);
        period_has_two_w <= (commit_write_period >= 16'd2);
        period_has_two_r <= (commit_read_period >= 16'd2);
        t_avqv_w         <= 16'd9;
        t_avqv_r         <= commit_read_sample;
 
        // ---------- 写模式时序参数解码 ----------
        case (write_mode_reg)
            2'b01: begin // WE-controlled: CE/BN at 0, WE at 1; release WE P-3.
                t_av2dv_w <= 0;
                t_eh2el_w <= 0; t_el2eh_w <= 2;
                t_wh2wl_w <= 1; t_wl2wh_w <= 3;
                t_gh2gl_w <= t_avav_reg; t_gl2gh_w <= 0;
                t_ubh2ubl_w <= 0; t_ubl2ubh_w <= 2;
                t_lbh2lbl_w <= 0; t_lbl2lbh_w <= 2;
            end
            2'b10: begin // Byte-controlled: CE/WE at 0, BN at 1; release BN P-3.
                t_av2dv_w <= 0;
                t_eh2el_w <= 0; t_el2eh_w <= 2;
                t_wh2wl_w <= 0; t_wl2wh_w <= 2;
                t_gh2gl_w <= t_avav_reg; t_gl2gh_w <= 0;
                t_ubh2ubl_w <= 1; t_ubl2ubh_w <= 3;
                t_lbh2lbl_w <= 1; t_lbl2lbh_w <= 3;
            end
            default: begin // CE-controlled, including the legacy invalid-mode fallback.
                if(write_mode_reg==2'b11) t_avav_w <= 16'd10;
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
            2'b01: begin // Read2: all enables fall at +5 ns, rise at period end.
                t_av2dv_r <= 0;
                t_eh2el_r <= 1; t_el2eh_r <= 0;
                t_wh2wl_r <= 0; t_wl2wh_r <= commit_read_period;
                t_gh2gl_r <= 1; t_gl2gh_r <= 0;
                t_ubh2ubl_r <= 1; t_ubl2ubh_r <= 0;
                t_lbh2lbl_r <= 1; t_lbl2lbh_r <= 0;
            end
            default: begin // Read1: address-controlled, all enables stay low.
                t_av2dv_r <= 0;
                t_eh2el_r <= 0; t_el2eh_r <= commit_read_period;
                t_wh2wl_r <= 0; t_wl2wh_r <= commit_read_period;
                t_gh2gl_r <= 0; t_gl2gh_r <= commit_read_period;
                t_ubh2ubl_r <= 0; t_ubl2ubh_r <= commit_read_period;
                t_lbh2lbl_r <= 0; t_lbl2lbh_r <= commit_read_period;
            end
        endcase

        // x8芯片复写(chip_type=0x80/0x82)
        if (chip_type_reg == 8'b10000000 || chip_type_reg == 8'b10000010) begin
            t_ubh2ubl_w <= 0; t_ubl2ubh_w <= t_avav_reg + 1;
            t_lbh2lbl_w <= 0; t_lbl2lbh_w <= t_avav_reg + 1;
            t_ubh2ubl_r <= 0; t_ubl2ubh_r <= commit_read_period + 1;
            t_lbh2lbl_r <= 0; t_lbl2lbh_r <= commit_read_period + 1;
        end
    end
end


// =========================================================================
// 8. TX 发送触发与缓冲区准备 （优化版：无多驱动，启动与移位分离）
// =========================================================================

// ---------- 8.1 边沿检测 ----------
// Only the first synchronizer flop samples the asynchronous CS input.
// Internal edge pulses use the second stage and its delayed copy.
(* ASYNC_REG = "TRUE" *) reg [1:0] cs_n_sync;
reg        cs_n_d1;
wire       cs_n_neg;
wire       cs_n_pos;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cs_n_sync <= 2'b11;
        cs_n_d1 <= 1'b1;
    end else begin
        cs_n_sync <= {cs_n_sync[0],spi_cs_n};
        cs_n_d1 <= cs_n_sync[1];
    end
end
assign cs_n_neg = !cs_n_sync[1] && cs_n_d1;
assign cs_n_pos = cs_n_sync[1] && !cs_n_d1;

// ---------- 8.2 待发送事件锁存 ----------
reg        pending_test_complete;
reg        pending_stop;
reg        test_frame_acked;
// A new start also flushes the old producer's short completion pipeline.
// With supported MRAM periods (>=7 clocks), no new compare/completion can
// legitimately reach this module inside this initialization window.
reg [3:0] report_start_guard;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) report_start_guard <= 4'd0;
    else report_start_guard <= {report_start_guard[2:0],(start_test || valid_start_request)};
end
// Isolate byte-completion/checksum decoding from the wide TX reset enables.
// config_commit already cancels the prior frame a full byte before start.
(* keep="true",max_fanout=32 *) reg report_restart;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) report_restart<=1'b0;
    else report_restart<=start_test || valid_start_request || (|report_start_guard);
end
reg        detail_frame_acked;
// The RAM holds the index/address/actual/expected payload (86 bits). One loop
// is drained before its summary ACK advances current_loop, so common header
// fields remain stable without duplicating them in every RAM entry.
wire detail_pending;
wire detail_fifo_nonempty;
wire [85:0] detail_record;
wire [31:0] detail_loop = current_loop;
wire [22:0] detail_total = test_length;
wire [31:0] detail_index = detail_record[85:54];
wire [21:0] detail_address = detail_record[53:32];
wire [15:0] detail_actual = detail_record[31:16];
wire [15:0] detail_expected = detail_record[15:0];
reg detail_fifo_clear;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) detail_fifo_clear<=1'b1;
    else detail_fifo_clear<=config_commit || report_restart || test_frame_acked;
end
wire [31:0] incoming_detail_index = error_cnt + 32'd1;
// Logging never exerts backpressure on the memory engine, even when full.
assign detail_stall = 1'b0;
mram_detail_fifo #(.ADDR_BITS(DETAIL_FIFO_ADDR_BITS)) u_detail_fifo(
    .clk(clk),.rst_n(rst_n),.clear(detail_fifo_clear),
    .push(detail_enabled && err_flag),
    .push_data({incoming_detail_index,error_addr,error_data,expected_data}),
    .pop(detail_frame_acked),.head_valid(detail_pending),.head_data(detail_record),
    .nonempty(detail_fifo_nonempty),.overflow(detail_overflow),
    .dropped_count(detail_dropped_count)
);


always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pending_test_complete <= 1'b0;
    else if (config_commit || report_restart)
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
// Fence the entire report launch before driving the wide TX register bank.
reg summary_ready;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) summary_ready<=0;
    else if(config_commit || report_restart || test_frame_acked) summary_ready<=0;
    else summary_ready<=pending_test_complete && !test_busy &&
        (!detail_enabled || (!err_flag && !detail_fifo_nonempty));
end
reg        frame_sent_this_cs;
reg [7:0]  tx_buf [0:31];      // 发送缓冲区
reg [4:0]  tx_byte_cnt;        // 总字节数
reg        tx_start;           // 启动脉冲（仅在此块赋值）
reg        tx_is_detail;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_byte_cnt <= 5'd0;
        frame_sent_this_cs <= 1'b0;
        tx_start <= 1'b0;
        tx_is_detail <= 1'b0;
    end else if (config_commit || report_restart) begin
        tx_start <= 1'b0;
        tx_byte_cnt <= 5'd0;
        tx_is_detail <= 1'b0;
        frame_sent_this_cs <= 1'b0;
    end else begin
        tx_start <= 1'b0;   // 默认低

        if (cs_n_pos) begin
            frame_sent_this_cs <= 1'b0;
        end

        if (cs_n_neg) begin
            frame_sent_this_cs <= 1'b0;   // 新周期复位
            if (!tx_sending && !frame_sent_this_cs && detail_enabled && detail_pending) begin
                tx_buf[0] <= 8'h55;
                tx_buf[1] <= 8'h19;
                tx_buf[2] <= 8'hFF;
                tx_buf[3] <= detail_loop[7:0];
                tx_buf[4] <= detail_loop[15:8];
                tx_buf[5] <= detail_loop[23:16];
                tx_buf[6] <= detail_loop[31:24];
                tx_buf[7] <= detail_total[7:0];
                tx_buf[8] <= detail_total[15:8];
                tx_buf[9] <= {1'b0,detail_total[22:16]};
                tx_buf[10] <= 8'h00;
                tx_buf[11] <= 8'h01;
                tx_buf[12] <= detail_index[7:0];
                tx_buf[13] <= detail_index[15:8];
                tx_buf[14] <= detail_index[23:16];
                tx_buf[15] <= detail_index[31:24];
                tx_buf[16] <= detail_address[7:0];
                tx_buf[17] <= detail_address[15:8];
                tx_buf[18] <= {2'b0,detail_address[21:16]};
                tx_buf[19] <= 8'h00;
                tx_buf[20] <= detail_actual[7:0];
                tx_buf[21] <= detail_actual[15:8];
                tx_buf[22] <= detail_expected[7:0];
                tx_buf[23] <= detail_expected[15:8];
                tx_buf[24] <= 8'hAA;
                tx_byte_cnt <= 5'd25;
                tx_is_detail <= 1'b1;
                tx_start <= 1'b1;
                frame_sent_this_cs <= 1'b1;
            // A loop-finish notification precedes the final compare pipeline
            // draining. Wait for the memory engine to be idle in either mode.
            end else if (!tx_sending && !frame_sent_this_cs && pending_test_complete && summary_ready) begin
                tx_is_detail <= 1'b0;
                // 填充缓冲区
                tx_buf[0] <= 8'h55;
                if (report_with_errors) begin
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
                    tx_buf[11] <= {7'b0, ((|error_cnt) || err_flag)};
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
// Keep the arithmetic five bits wide. Zero preserves the original unsigned
// 32-bit underflow case; valid frames still contain 11, 17 or 25 bytes.
wire tx_more_bytes = (tx_byte_cnt==5'd0) ||
                     (tx_byte_ptr < (tx_byte_cnt-5'd1));
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
        detail_frame_acked <= 1'b0;
    end else if (config_commit || report_restart) begin
        tx_sending <= 1'b0;
        tx_byte_ptr <= 5'd0;
        tx_bit_cnt <= 3'd0;
        tx_shift_reg <= 8'd0;
        tx_done_pulse <= 1'b0;
        test_frame_acked <= 1'b0;
        detail_frame_acked <= 1'b0;
    end else begin
        detail_frame_acked <= 1'b0;
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
                if (tx_more_bytes) begin
                    tx_byte_ptr  <= tx_byte_ptr + 1;
                    tx_shift_reg <= tx_buf[tx_byte_ptr + 1];
                end else begin
                    // 发送完成
                    tx_sending   <= 1'b0;
                    tx_shift_reg <= 8'h00;
                    if (tx_is_detail) begin
                        detail_frame_acked <= 1'b1;
                    end else begin
                        tx_done_pulse <= 1'b1;
                        test_frame_acked <= 1'b1;
                    end
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

// Single-clock, BRAM-compatible detail queue. The prefetched head remains part
// of fifo_count until a FULL SPI frame ACKs it; aborted polls cannot consume it.
module mram_detail_fifo #(parameter ADDR_BITS=12)(
    input wire clk,rst_n,clear,push,pop,
    input wire [85:0] push_data,
    output reg head_valid,
    output reg [85:0] head_data,
    output wire nonempty,
    (* dont_touch="true" *) output reg overflow,
    (* dont_touch="true" *) output reg [31:0] dropped_count
);
localparam integer DEPTH = 1 << ADDR_BITS;
localparam [ADDR_BITS:0] CAPACITY = {1'b1,{ADDR_BITS{1'b0}}};
(* ram_style="block" *) reg [85:0] records [0:DEPTH-1];
reg [ADDR_BITS-1:0] write_pointer,read_pointer;
reg [ADDR_BITS:0] fifo_count;
reg fetch_pending;
reg [85:0] ram_output;
// Reachable occupancy is 0..DEPTH, so the high bit is the full flag.
wire full = fifo_count[ADDR_BITS];
(* keep="true" *) wire [ADDR_BITS:0] count_increment=fifo_count+1'b1;
(* keep="true" *) wire [ADDR_BITS:0] count_decrement=fifo_count-1'b1;
(* keep="true" *) wire [ADDR_BITS-1:0] write_increment=write_pointer+1'b1;
(* keep="true" *) wire [ADDR_BITS-1:0] read_increment=read_pointer+1'b1;
(* keep="true" *) wire [31:0] dropped_increment=dropped_count+32'd1;
assign nonempty = (fifo_count!=0);
wire pop_ok = pop && head_valid;
wire push_ok = push && (!full || pop_ok);
wire fetch = nonempty && !head_valid && !fetch_pending;
// No reset on RAM or its read register: infer true synchronous block RAM.
always @(posedge clk) begin
    if(rst_n && !clear) begin
        if(push_ok) records[write_pointer]<=push_data;
        if(fetch) ram_output<=records[read_pointer];
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        write_pointer<=0;read_pointer<=0;fifo_count<=0;
        head_valid<=0;head_data<=0;fetch_pending<=0;
        overflow<=0;dropped_count<=0;
    end else if(clear) begin
        write_pointer<=0;read_pointer<=0;fifo_count<=0;
        head_valid<=0;fetch_pending<=0;overflow<=0;dropped_count<=0;
    end else begin
        if(push_ok) write_pointer<=write_increment;
        if(pop_ok) begin read_pointer<=read_increment;head_valid<=0;end
        case({push_ok,pop_ok})
            2'b10:fifo_count<=count_increment;
            2'b01:fifo_count<=count_decrement;
            default:;
        endcase
        if(fetch) fetch_pending<=1;
        if(fetch_pending) begin
            head_data<=ram_output;head_valid<=1;fetch_pending<=0;
        end
        if(push && !push_ok) begin overflow<=1;dropped_count<=dropped_increment;end
    end
end
endmodule
