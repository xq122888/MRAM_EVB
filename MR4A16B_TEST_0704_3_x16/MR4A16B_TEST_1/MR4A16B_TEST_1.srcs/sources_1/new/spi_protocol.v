`timescale 1ns / 1ps

module spi_protocol #(
    parameter CLK_FREQUENCE = 200_000_000,
    parameter SPI_FREQUENCE = 5_000_000,
    parameter DATA_WIDTH = 8,
    parameter CPOL = 0,   
    parameter CPHA = 0    
)(
    input wire clk,
    input wire rst_n,
    
    // SPI接口 - Slave模式
    input wire spi_sclk, 
    input wire spi_cs_n,
    input wire spi_mosi, 
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
    output reg stop_test,
    output reg stop_cmd_match,
    output reg send_frame_ack,
    
    // 状态反馈输入
    input wire [31:0] current_loop,
    input wire test_busy,
    input wire test_done,
    input wire [31:0] error_cnt,
    input wire err_flag,
    input wire [21:0] error_addr,
    input wire [15:0] error_data,
    input wire [15:0] expected_data,
    
    // 测试完成信号（由top产生）
    input wire test_complete
);

// 帧定义
localparam FRAME_HEADER = 8'h55;
localparam FRAME_TAIL = 8'hAA;
localparam STOP_CMD = 8'hFF;

wire [DATA_WIDTH-1:0] spi_data_out;
wire spi_data_valid;
reg [7:0] spi_rx_data;
reg [DATA_WIDTH-1:0] spi_tx_data;

// ========== SPI_Slave信号 ==========
wire spi_shift_en;
wire spi_sampl_en;

// Slave实例
SPI_Slave #(
    .CLK_FREQUENCE(CLK_FREQUENCE),
    .SPI_FREQUENCE(SPI_FREQUENCE),
    .DATA_WIDTH(DATA_WIDTH),
    .CPOL(CPOL),
    .CPHA(CPHA)
) u_spi_slave (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(spi_tx_data),
    .sclk(spi_sclk),
    .cs_n(spi_cs_n),
    .mosi(spi_mosi),
    .miso(),
    .data_valid(spi_data_valid),
    .data_out(spi_data_out),
    .shift_en(spi_shift_en),
    .sampl_en(spi_sampl_en)
);

reg spi_data_valid_d1;
wire spi_data_valid_d2;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        spi_data_valid_d1 <= 0;
    else
        spi_data_valid_d1 <= spi_data_valid;
end
assign spi_data_valid_d2 = spi_data_valid && !spi_data_valid_d1;

// 接收状态机寄存器
reg [4:0] rx_state;
reg [7:0] calc_checksum;
reg [7:0] rx_checksum;
reg [7:0] chip_type_reg;
reg [3:0] t_mode_reg;
reg [7:0] din_sel_reg;
reg [31:0] addr_ini_reg;
reg [31:0] addr_num_reg;
reg [31:0] loop_cnt_reg;
reg [1:0] write_mode_reg;
reg [1:0] read_mode_reg;
reg [15:0] t_avav_reg;

reg [15:0] timeout_counter;
reg timeout_detected;
reg frame_processing;
reg [4:0] rx_byte_cnt;

// ========== 停止命令检测 ==========
reg [23:0] stop_cmd_buffer;      // 3字节缓冲区
reg stop_cmd_detected;
reg stop_cmd_sent;               // 停止帧已发送标志

// ============================================================
// 发送响应数据
// ============================================================
reg [7:0] tx_buf[0:31];
reg [4:0] tx_byte_cnt;
reg tx_sending;
reg [7:0] tx_shift_reg;
reg [3:0] tx_bit_cnt;
reg [4:0] tx_byte_ptr;
reg miso_out_pre;

reg send_complete_flag;
reg send_stop_flag;              // 停止命令响应标志

reg test_complete_d1;
wire test_complete_rise;

reg [31:0] send_loop_idx;
reg [31:0] send_total_cnt;
reg [31:0] send_err_cnt;
reg [1:0]  send_test_mode;
reg [7:0]  send_chip_type;
reg        send_err_flag;

// 边沿检测
reg rx_valid_d1;
reg rx_valid_d2;
reg tx_sending_d1;

// ============================================================
// 锁存接收数据
// ============================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        spi_rx_data <= 0;
    end
    else if(spi_data_valid) begin
        spi_rx_data <= spi_data_out;
    end
end

// ============================================================
// 接收状态机 + 停止命令检测（合并到同一个always块）
// ============================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rx_state <= 0;
        calc_checksum <= 0;
        rx_checksum <= 0;
        chip_type_reg <= 8'h80;
        t_mode_reg <= 0;
        din_sel_reg <= 0;
        addr_ini_reg <= 0;
        addr_num_reg <= 0;
        loop_cnt_reg <= 1;
        write_mode_reg <= 0;
        read_mode_reg <= 0;
        t_avav_reg <= 8;
          
        chip_type <= 8'h80;
        test_mode <= 0;
        data_pattern <= 0;
        start_addr <= 0;
        test_length <= 0;
        loop_count <= 1;
        
        write_mode <= 0;
        read_mode <= 0;
        t_avav_w <= 8;
        t_avqv_w <= 9;
        t_avav_r <= 8;
        t_avqv_r <= 9;
        t_av2dv_w <= 0;
        t_eh2el_w <= 2;
        t_el2eh_w <= 2;
        t_wh2wl_w <= 2;
        t_wl2wh_w <= 2;
        t_gh2gl_w <= 2;
        t_gl2gh_w <= 2;
        t_ubh2ubl_w <= 0;
        t_ubl2ubh_w <= t_avav_w+1;
        t_lbh2lbl_w <= 0;
        t_lbl2lbh_w <= t_avav_w+1;
        t_av2dv_r <= 0;
        t_eh2el_r <= 2;
        t_el2eh_r <= 2;
        t_wh2wl_r <= 2;
        t_wl2wh_r <= 2;
        t_gh2gl_r <= 2;
        t_gl2gh_r <= 2;
        t_ubh2ubl_r <= 0;
        t_ubl2ubh_r <= t_avav_r+1;
        t_lbh2lbl_r <= 0;
        t_lbl2lbh_r <= t_avav_r+1;
        
        rx_byte_cnt <= 0;
        start_test <= 0;
        stop_test <= 0;
        timeout_counter <= 0;
        timeout_detected <= 0;
        frame_processing <= 0;  
        send_frame_ack <= 0; 
        stop_cmd_match <= 0;
        stop_cmd_detected <= 0;
        stop_cmd_buffer <= 24'h000000;
        stop_cmd_sent <= 0;
    end
    else begin
        start_test <= 0;
        stop_test <= 0;
        
        // ========== 停止命令检测 ==========
        if(rx_valid_d1 && !rx_valid_d2) begin
            stop_cmd_buffer <= {stop_cmd_buffer[15:0], spi_rx_data};
            // 检测 55 FF AA
            if({stop_cmd_buffer[15:0], spi_rx_data} == 24'h55FFAA) begin
                stop_cmd_match <= 1'b1;
                stop_cmd_detected <= 1'b1;
                stop_test <= 1'b1;
                $display("[SPI] Stop command detected (55 FF AA) at time %t", $time);
            end
            else begin
                stop_cmd_match <= 1'b0;
            end
        end
        
        // ========== 停止命令检测标志清除（发送完成后） ==========
        if(send_stop_flag && !tx_sending && tx_sending_d1) begin
            stop_cmd_detected <= 1'b0;
        end
        
        // 超时检测
        if(rx_state != 0) begin
            timeout_counter <= timeout_counter + 1;
            if(timeout_counter > 16'd50000) begin
                timeout_detected <= 1;
                rx_state <= 0;
                timeout_counter <= 0;
                frame_processing <= 0;
                calc_checksum <= 0;
                stop_cmd_match <= 0;
            end
            else begin
                timeout_detected <= 0;
            end
        end
        else begin
            timeout_counter <= 0;
            timeout_detected <= 0;
        end

        if(spi_data_valid_d2 && !timeout_detected) begin
            timeout_counter <= 0;
            case(rx_state)
                0: begin
                    if(spi_rx_data == FRAME_HEADER && !frame_processing) begin
                        frame_processing <= 1;
                        rx_state <= 1;
                        calc_checksum <= 8'h00;
                        rx_byte_cnt <= 1;
                        stop_cmd_match <= 1'b0;
                    end
                    else begin
                        rx_state <= 0;
                    end
                end
                1: begin
                    chip_type_reg <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 2;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                2: begin
                    t_mode_reg <= spi_rx_data[3:0];
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 3;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                3: begin
                    din_sel_reg <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 4;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                4: begin
                    addr_ini_reg[7:0] <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 5;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                5: begin
                    addr_ini_reg[15:8] <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 6;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                6: begin
                    addr_ini_reg[21:16] <= spi_rx_data[3:0];
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 7;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                7: begin
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 8;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                8: begin
                    addr_num_reg[7:0] <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 9;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                9: begin
                    addr_num_reg[15:8] <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 10;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                10: begin
                    addr_num_reg[23:16] <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 11;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                11: begin
                    addr_num_reg[31:24] <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 12;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                12: begin
                    loop_cnt_reg[7:0] <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 13;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                13: begin
                    loop_cnt_reg[15:8] <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 14;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                14: begin
                    loop_cnt_reg[23:16] <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 15;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                15: begin
                    loop_cnt_reg[31:24] <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 16;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                16: begin
                    t_avav_reg[7:0] <= spi_rx_data;
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 17;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                17: begin
                    write_mode_reg <= spi_rx_data[1:0];
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 18;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                18: begin
                    read_mode_reg <= spi_rx_data[1:0];
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 19;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                19: begin
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 20;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                20: begin
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 21;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                end
                21: begin
                    calc_checksum <= calc_checksum + spi_rx_data;
                    rx_state <= 22;
                    rx_byte_cnt <= rx_byte_cnt + 1;
                    t_avav_w <= t_avav_reg;/////
                    t_avav_r <= t_avav_reg;/////
                end
                22: begin
                    rx_checksum <= spi_rx_data;
                    if(calc_checksum == spi_rx_data) begin
                        chip_type <= chip_type_reg;
                        test_mode <= t_mode_reg;
                        data_pattern <= din_sel_reg;
                        start_addr <= addr_ini_reg[21:0];
                        test_length <= addr_num_reg[20:0];
                        loop_count <= loop_cnt_reg;
                        write_mode <= write_mode_reg;
                        read_mode <= read_mode_reg;
                        t_avav_w <= t_avav_w;
                        t_avqv_w <= 9;//9
                        t_avav_r <= t_avav_w;
                        t_avqv_r <= 9;//9
                        
                        case(write_mode_reg)
                           2'b00: begin
                                t_av2dv_w <= 1;
                                t_eh2el_w <= 2; t_el2eh_w <= 1;
                                t_wh2wl_w <= 1; t_wl2wh_w <= 1;
                                t_gh2gl_w <= t_avav_reg + 1; t_gl2gh_w <= 0;
                                t_ubh2ubl_w <= 0; t_ubl2ubh_w <= t_avav_w + 1;
                                t_lbh2lbl_w <= 0; t_lbl2lbh_w <= t_avav_w + 1;
                            end
                           2'b01: begin
                                t_av2dv_w <= 1;
                                t_eh2el_w <= 0; t_el2eh_w <= 1;
                                t_wh2wl_w <= 1; t_wl2wh_w <= 2;
                                t_gh2gl_w <= t_avav_reg + 1; t_gl2gh_w <= 0;
                                t_ubh2ubl_w <= 0; t_ubl2ubh_w <= t_avav_w + 1;
                                t_lbh2lbl_w <= 0; t_lbl2lbh_w <= t_avav_w + 1;
                            end
                           2'b10: begin
                                t_av2dv_w <= 1;
                                t_eh2el_w <= 1; t_el2eh_w <= 1;
                                t_wh2wl_w <= 1; t_wl2wh_w <= 1;
                                t_gh2gl_w <= t_avav_reg + 1; t_gl2gh_w <= 0;
                                t_ubh2ubl_w <= 2; t_ubl2ubh_w <= 1;
                                t_lbh2lbl_w <= 2; t_lbl2lbh_w <= 1;
                            end
                           default: begin
                                t_av2dv_w <= 1;
                                t_eh2el_w <= 1; t_el2eh_w <= 2;
                                t_wh2wl_w <= 1; t_wl2wh_w <= 1;
                                t_gh2gl_w <= t_avav_reg + 1; t_gl2gh_w <= 0;
                                t_ubh2ubl_w <= 0; t_ubl2ubh_w <= t_avav_w + 1;
                                t_lbh2lbl_w <= 0; t_lbl2lbh_w <= t_avav_w + 1;
                            end  
                        endcase

                                           
                        case(read_mode_reg)
                         2'b00: begin
                                t_av2dv_r <= 3;
                                t_eh2el_r <= 0; t_el2eh_r <= t_avav_r;
                                t_wh2wl_r <= 0; t_wl2wh_r <= t_avav_r;//////
                                t_gh2gl_r <= 0; t_gl2gh_r <= t_avav_r;
                                t_ubh2ubl_r <= 0; t_ubl2ubh_r <= t_avav_r;
                                t_lbh2lbl_r <= 0; t_lbl2lbh_r <= t_avav_r;
                            end
                            2'b01: begin
                                t_av2dv_r <= 3;
                                t_eh2el_r <= 0; t_el2eh_r <= 0;
                                t_wh2wl_r <= 0; t_wl2wh_r <= t_avav_r + 1;
                                t_gh2gl_r <= 3; t_gl2gh_r <= 0;
                                t_ubh2ubl_r <= 0; t_ubl2ubh_r <= 0;
                                t_lbh2lbl_r <= 0; t_lbl2lbh_r <= 0;
                            end
                            default: begin
                                t_av2dv_r <= 3;
                                t_eh2el_r <= 0; t_el2eh_r <= t_avav_r;
                                t_wh2wl_r <= 0; t_wl2wh_r <= t_avav_r;
                                t_gh2gl_r <= 0; t_gl2gh_r <= t_avav_r;
                                t_ubh2ubl_r <= 0; t_ubl2ubh_r <= t_avav_r;
                                t_lbh2lbl_r <= 0; t_lbl2lbh_r <= t_avav_r;
                            end
                        endcase
                         if(chip_type == 8'b10000000 || chip_type == 8'b10000010) begin
                            t_ubh2ubl_w <= 0; t_ubl2ubh_w <=  t_avav_w + 1;
                            t_lbh2lbl_w <= 0; t_lbl2lbh_w <= t_avav_w + 1;
                        end  
                        if(chip_type == 8'b10000000 || chip_type == 8'b10000010) begin
                            t_ubh2ubl_r <= 0; t_ubl2ubh_r <= t_avav_r + 1;
                            t_lbh2lbl_r <= 0; t_lbl2lbh_r <= t_avav_r + 1;
                        end  
                    end
                    rx_state <= 23;
                    rx_byte_cnt <= rx_byte_cnt + 1;       
                end
                default: begin
                    rx_state <= 0;
                    frame_processing <= 0;
                    calc_checksum <= 0;
                    rx_byte_cnt <= 0;
                    stop_cmd_match <= 0;
                end
            endcase
        end
     
        if(rx_state == 23) begin
            if(spi_rx_data == FRAME_TAIL) begin
                start_test <= 1'b1;
                rx_state <= 0;
                frame_processing <= 0;
                calc_checksum <= 0;
            end
            else begin
                rx_state <= 0;
                frame_processing <= 0;
                calc_checksum <= 0;
            end
            rx_byte_cnt <= 0;
        end
    
    end
end

// ============================================================
// 发送响应数据
// ============================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        tx_byte_cnt <= 0;
        tx_sending <= 0;
        tx_shift_reg <= 8'h00;
        tx_bit_cnt <= 0;
        tx_byte_ptr <= 0;
        miso_out_pre <= 1'b0;
        
        send_complete_flag <= 0;
        send_stop_flag <= 0;
        send_frame_ack <= 0;
        
        send_loop_idx <= 0;
        send_total_cnt <= 0;
        send_err_cnt <= 0;
        send_test_mode <= 0;
        send_chip_type <= 0;
        send_err_flag <= 0;
        
        test_complete_d1 <= 0;
        rx_valid_d1 <= 0;
        rx_valid_d2 <= 0;
        tx_sending_d1 <= 0;
        stop_cmd_sent <= 0;
    end
    else begin
        test_complete_d1 <= test_complete;
        rx_valid_d1 <= spi_data_valid;
        rx_valid_d2 <= rx_valid_d1;
        tx_sending_d1 <= tx_sending;
        
        // ========== 触发发送请求（优先级：停止命令 > 测试完成） ==========
        if(!tx_sending) begin
            // 1. 停止命令触发（最高优先级）
            if(stop_cmd_detected && !stop_cmd_sent && !send_stop_flag) begin
                send_stop_flag <= 1;
                stop_cmd_sent <= 1;
                // 使用当前的错误计数和循环信息
                send_loop_idx <= current_loop;
                send_total_cnt <= test_length;
                send_test_mode <= test_mode;
                send_chip_type <= chip_type;
               if(test_mode == 2'd2)begin
                    send_err_cnt <= error_cnt; 
                    send_err_flag <= err_flag;
                    end
                else begin
                    send_err_cnt <=0;
                    send_err_flag <= 0;
                 end
          
            end
            // 2. 测试完成触发
            else if(test_complete && !test_complete_d1 && !send_complete_flag) begin
                send_complete_flag <= 1;
                send_loop_idx <= current_loop;
                send_total_cnt <= test_length;
                send_test_mode <= test_mode;
                send_chip_type <= chip_type;
                if(test_mode == 2'd2)begin
                    send_err_cnt <= error_cnt; 
                    send_err_flag <= err_flag;
                end
                else begin
                    send_err_cnt <=0;
                    send_err_flag <= 0;
                 end
            end
        end
        
        // ========== 构建发送帧 ==========
          if(!tx_sending && (send_complete_flag||send_stop_flag)) begin
            // 测试完成帧 / 停止响应帧
            if(test_mode == 2'b00 || test_mode == 2'b01) begin
                tx_buf[0] <= 8'h55;
                tx_buf[1] <= 8'hFF;
                tx_buf[2] <= send_loop_idx[7:0];
                tx_buf[3] <= send_loop_idx[15:8];
                tx_buf[4] <= send_loop_idx[23:16];
                tx_buf[5] <= send_loop_idx[31:24];
                tx_buf[6] <= send_total_cnt[7:0];
                tx_buf[7] <= send_total_cnt[15:8];
                tx_buf[8] <= send_total_cnt[23:16];  
                tx_buf[9] <= send_total_cnt[31:24];
                tx_buf[10] <= 8'hAA;
                tx_byte_cnt <= 11;
            end
            // 3. 先写后读循环完成帧: 55 11 FF ... AA
            else if(test_mode == 2'b10) begin
                tx_buf[0] <= 8'h55;
                tx_buf[1] <= 8'h11;
                tx_buf[2] <= 8'hFF;
                tx_buf[3] <= send_loop_idx[7:0];
                tx_buf[4] <= send_loop_idx[15:8];
                tx_buf[5] <= send_loop_idx[23:16];
                tx_buf[6] <= send_loop_idx[31:24];
                tx_buf[7] <= send_total_cnt[7:0];
                tx_buf[8] <= send_total_cnt[15:8];
                tx_buf[9] <= send_total_cnt[23:16];
                tx_buf[10] <= send_total_cnt[31:24];
                tx_buf[11] <= err_flag;
                tx_buf[12] <= send_err_cnt[7:0];
                tx_buf[13] <= send_err_cnt[15:8];
                tx_buf[14] <= send_err_cnt[23:16];
                tx_buf[15] <= send_err_cnt[31:24];
                tx_buf[16] <= 8'hAA;
                tx_byte_cnt <= 17;
            end   
            // 开始发送
            tx_sending <= 1;
            tx_byte_ptr <= 0;
            tx_bit_cnt <= 0;
            tx_shift_reg <= tx_buf[0];
        end
        
        // ========== 每个SPI时钟边沿发送1个bit ==========
        if(tx_sending && spi_shift_en && !spi_cs_n) begin
            miso_out_pre <= tx_shift_reg[6];
            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
            tx_bit_cnt <= tx_bit_cnt + 1;
            
            if(tx_bit_cnt == 7) begin
                tx_bit_cnt <= 0;
                if(tx_byte_ptr < tx_byte_cnt - 1) begin
                    tx_byte_ptr <= tx_byte_ptr + 1;
                    tx_shift_reg <= tx_buf[tx_byte_ptr + 1];
                end
                else begin
                    // 发送完成
                    tx_sending <= 0;
                    tx_shift_reg <= 8'h00;
                    miso_out_pre <= 1'b0;
                    
                    if(send_complete_flag) begin
                        send_complete_flag <= 0;
                    end
                    if(send_stop_flag) begin
                        send_stop_flag <= 0;
                    end
                end
            end
        end

        // ========== CS拉高时立即停止发送 ==========
        if(spi_cs_n) begin
            tx_sending <= 0;
            tx_bit_cnt <= 0;
            miso_out_pre <= 1'b0;
        end
        
        // ========== 发送完成标志 ==========
        if(!tx_sending && tx_sending_d1) begin
            send_frame_ack <= 1;
        end
        else if(tx_sending && !tx_sending_d1) begin
            send_frame_ack <= 0;
        end
    end
end

// ========== MISO输出 ==========
assign spi_miso = (!spi_cs_n && tx_sending) ? (spi_shift_en ? miso_out_pre : tx_shift_reg[7]) : 1'b0;
                  
endmodule