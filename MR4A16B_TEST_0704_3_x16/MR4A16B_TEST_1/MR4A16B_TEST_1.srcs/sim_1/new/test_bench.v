`timescale 1ns/1ps

module tb_SPI_Slave_Fix();

//===========================================================
// 参数定义
//===========================================================
parameter   CLK_FREQUENCE   = 200_000_000;      // 200MHz
parameter   SPI_FREQUENCE   = 5_000_000;         // 5MHz
parameter   DATA_WIDTH      = 8;
parameter   CPOL            = 0;
parameter   CPHA            = 0;

// 时钟周期
localparam  CLK_PERIOD      = 5;                 // 5ns (200MHz)
localparam  SPI_PERIOD      = 200;               // 200ns (5MHz)
localparam  SPI_HALF        = SPI_PERIOD / 2;    // 100ns

//===========================================================
// 测试信号
//===========================================================
reg                             clk;
reg                             rst_n;
reg     [7:0]                   data_in;
reg                             sclk;
reg                             cs_n;
reg                             mosi;
wire                            miso;
wire                            data_valid;
wire    [7:0]                   data_out;

// 测试数据
reg     [7:0]                   test_data [0:23];
integer                         i, errors;
reg     [7:0]                   expected_data;
reg     [7:0]                   miso_data [0:23];
reg     [7:0]                   rx_data [0:23];
reg     [7:0]                   sample_reg;

//===========================================================
// DUT例化
//===========================================================
SPI_Slave #(
    .CLK_FREQUENCE  (CLK_FREQUENCE),
    .SPI_FREQUENCE  (SPI_FREQUENCE),
    .DATA_WIDTH     (DATA_WIDTH),
    .CPOL           (CPOL),
    .CPHA           (CPHA)
) u_spi_slave (
    .clk        (clk),
    .rst_n      (rst_n),
    .data_in    (data_in),
    .sclk       (sclk),
    .cs_n       (cs_n),
    .mosi       (mosi),
    .miso       (miso),
    .data_valid (data_valid),
    .data_out   (data_out)
);

//===========================================================
// 时钟生成
//===========================================================
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

//===========================================================
// SPI波形生成任务 - 生成完整的SCLK波形
//===========================================================
task spi_transfer_byte;
    input   [7:0]   tx_data;
    output  [7:0]   rx_data;
    integer         bit_idx;
    begin
        // 发送8位数据 (MSB first)
        for (bit_idx = 7; bit_idx >= 0; bit_idx = bit_idx - 1) begin
            
            // === 阶段1: 设置MOSI数据 ===
            mosi = tx_data[bit_idx];
            
            // === 阶段2: 等待数据稳定 (半个SPI周期) ===
            #(SPI_HALF);
            
            // === 阶段3: SCLK上升沿 (Mode 0: 上升沿采样) ===
            sclk = 1;
            
            // 在上升沿采样MISO (Slave在上升沿输出数据)
            rx_data[bit_idx] = miso;
            
            // 等待半个周期
            #(SPI_HALF);
            
            // === 阶段4: SCLK下降沿 ===
            sclk = 0;
            
            // 等待半个周期 (让数据稳定)
            #(SPI_HALF);
        end
        
        // 字节结束后额外等待
        #(SPI_HALF);
    end
endtask

//===========================================================
// 发送完整帧任务
//===========================================================
task send_frame;
    input   integer num_bytes;
    integer idx;
    begin
        $display("\n[SPI Master] Starting frame transmission (%0d bytes)", num_bytes);
        
        // 1. CS_N拉低 (开始传输)
        cs_n = 0;
        #(SPI_PERIOD);  // 等待一个周期让Slave准备
        
        // 2. 逐个发送字节
        for (idx = 0; idx < num_bytes; idx = idx + 1) begin
            spi_transfer_byte(test_data[idx], miso_data[idx]);
            $display("  [%0t] Byte %2d: TX=0x%02X, RX(MISO)=0x%02X", 
                     $time, idx, test_data[idx], miso_data[idx]);
        end
        
        // 3. CS_N拉高 (结束传输)
        #(SPI_HALF);
        cs_n = 1;
        #(SPI_PERIOD);
        
        $display("[SPI Master] Frame transmission complete\n");
    end
endtask

//===========================================================
// 等待data_valid并记录数据
//===========================================================
task wait_for_data_valid;
    input integer timeout_cycles;
    input integer byte_idx;
    integer wait_cnt;
    begin
        wait_cnt = 0;
        while (data_valid == 1'b0) begin
            @(posedge clk);
            wait_cnt = wait_cnt + 1;
            if (wait_cnt > timeout_cycles) begin
                $display("  [ERROR] Timeout waiting for data_valid at byte %0d", byte_idx);
                return;
            end
        end
        // data_valid为高时，在下一个时钟沿锁存数据
        @(posedge clk);
        rx_data[byte_idx] = data_out;
        $display("  [%0t] Byte %2d: data_out=0x%02X, data_valid=1", 
                 $time, byte_idx, data_out);
    end
endtask

//===========================================================
// 初始化测试数据
//===========================================================
task init_test_data;
    begin
        test_data[0]  = 8'h55;
        test_data[1]  = 8'h83;
        test_data[2]  = 8'h02;
        test_data[3]  = 8'h03;
        test_data[4]  = 8'h00;
        test_data[5]  = 8'h00;
        test_data[6]  = 8'h00;
        test_data[7]  = 8'h00;
        test_data[8]  = 8'h00;
        test_data[9]  = 8'h00;
        test_data[10] = 8'h04;
        test_data[11] = 8'h00;
        test_data[12] = 8'h01;
        test_data[13] = 8'h00;
        test_data[14] = 8'h00;
        test_data[15] = 8'h00;
        test_data[16] = 8'h0A;
        test_data[17] = 8'h00;
        test_data[18] = 8'h00;
        test_data[19] = 8'h00;
        test_data[20] = 8'h00;
        test_data[21] = 8'h00;
        test_data[22] = 8'h97;
        test_data[23] = 8'hAA;
    end
endtask

//===========================================================
// 打印波形状态（调试用）
//===========================================================
task print_spi_state;
    begin
        $display("[%0t] SPI State: cs_n=%b, sclk=%b, mosi=%b, miso=%b", 
                 $time, cs_n, sclk, mosi, miso);
    end
endtask

//===========================================================
// 主测试流程
//===========================================================
initial begin
    // ===== 初始化 =====
    rst_n = 0;
    data_in = 8'hA5;
    sclk = 0;
    cs_n = 1;
    mosi = 0;
    errors = 0;
    
    // 初始化测试数据
    init_test_data();
    
    // ===== 复位 =====
    repeat (10) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);
    
    $display("============================================================");
    $display("SPI Slave Testbench");
    $display("============================================================");
    $display("System Clock: %d MHz (Period: %d ns)", CLK_FREQUENCE/1_000_000, CLK_PERIOD);
    $display("SPI Clock: %d MHz (Period: %d ns)", SPI_FREQUENCE/1_000_000, SPI_PERIOD);
    $display("SPI Mode: CPOL=%d, CPHA=%d", CPOL, CPHA);
    $display("Data Width: %d bits", DATA_WIDTH);
    $display("============================================================\n");
    
    //===========================================================
    // Test Case 1: 发送单个字节 0x55
    //===========================================================
    $display("Test Case 1: Single byte 0x55");
    $display("--------------------------------------------");
    
    cs_n = 0;
    #(SPI_PERIOD);
    
    // 发送0x55: 01010101
    mosi = 0; #(SPI_HALF); sclk = 1; #(SPI_HALF); sclk = 0; #(SPI_HALF);  // bit7=0
    mosi = 1; #(SPI_HALF); sclk = 1; #(SPI_HALF); sclk = 0; #(SPI_HALF);  // bit6=1
    mosi = 0; #(SPI_HALF); sclk = 1; #(SPI_HALF); sclk = 0; #(SPI_HALF);  // bit5=0
    mosi = 1; #(SPI_HALF); sclk = 1; #(SPI_HALF); sclk = 0; #(SPI_HALF);  // bit4=1
    mosi = 0; #(SPI_HALF); sclk = 1; #(SPI_HALF); sclk = 0; #(SPI_HALF);  // bit3=0
    mosi = 1; #(SPI_HALF); sclk = 1; #(SPI_HALF); sclk = 0; #(SPI_HALF);  // bit2=1
    mosi = 0; #(SPI_HALF); sclk = 1; #(SPI_HALF); sclk = 0; #(SPI_HALF);  // bit1=0
    mosi = 1; #(SPI_HALF); sclk = 1; #(SPI_HALF); sclk = 0; #(SPI_HALF);  // bit0=1
    
    #(SPI_HALF);
    cs_n = 1;
    #(SPI_PERIOD);
    
    // 等待data_valid
    wait_for_data_valid(100, 0);
    
    if (data_out == 8'h55) begin
        $display("[PASS] Received 0x%02X matches expected 0x55\n", data_out);
    end else begin
        $display("[FAIL] Received 0x%02X, Expected 0x55\n", data_out);
        errors = errors + 1;
    end
    
    //===========================================================
    // Test Case 2: 发送完整数据帧 (使用任务)
    //===========================================================
    $display("Test Case 2: Full data frame (24 bytes)");
    $display("--------------------------------------------");
    $display("Sending data:");
    for (i = 0; i < 24; i = i + 1) begin
        if (i % 8 == 0) $write("\n  ");
        $write("%02X ", test_data[i]);
    end
    $display("\n");
    
    // 发送完整帧
    send_frame(24);
    
    // 等待所有data_valid
    $display("Waiting for data_valid signals...");
    for (i = 0; i < 24; i = i + 1) begin
        wait_for_data_valid(200, i);
    end
    
    // 验证所有数据
    $display("\nVerification results:");
    $display("--------------------------------------------");
    for (i = 0; i < 24; i = i + 1) begin
        if (rx_data[i] == test_data[i]) begin
            $display("  Byte %2d: [PASS] TX=0x%02X, RX=0x%02X", i, test_data[i], rx_data[i]);
        end else begin
            $display("  Byte %2d: [FAIL] TX=0x%02X, RX=0x%02X", i, test_data[i], rx_data[i]);
            errors = errors + 1;
        end
    end
    
    //===========================================================
    // Test Case 3: 背靠背传输
    //===========================================================
    $display("\nTest Case 3: Back-to-back transfers (no idle time)");
    $display("--------------------------------------------");
    
    cs_n = 0;
    #(SPI_PERIOD);
    
    for (i = 0; i < 8; i = i + 1) begin
        spi_transfer_byte(i + 1, miso_data[i]);
    end
    
    #(SPI_HALF);
    cs_n = 1;
    #(SPI_PERIOD);
    
    for (i = 0; i < 8; i = i + 1) begin
        wait_for_data_valid(100, i + 24);
    end
    
    for (i = 0; i < 8; i = i + 1) begin
        if (rx_data[i + 24] == (i + 1)) begin
            $display("  Byte %2d: [PASS] TX=0x%02X, RX=0x%02X", i, i + 1, rx_data[i + 24]);
        end else begin
            $display("  Byte %2d: [FAIL] TX=0x%02X, RX=0x%02X", i, i + 1, rx_data[i + 24]);
            errors = errors + 1;
        end
    end
    
    //===========================================================
    // 测试总结
    //===========================================================
    $display("\n============================================================");
    $display("Test Summary");
    $display("============================================================");
    if (errors == 0) begin
        $display("[PASS] All tests passed! (%0d bytes verified)", 24 + 1 + 8);
    end else begin
        $display("[FAIL] %0d errors detected!", errors);
        $display("\nPossible issues:");
        $display("  1. SCLK edge detection in SPI_Slave.v (remove 'if (!cs_n)' condition)");
        $display("  2. MOSI sampling uses synchronized signal (mosi_sync1)");
        $display("  3. CS_N edge detection timing");
        $display("  4. XDC constraints (remove input_delay, use false_path)");
    end
    $display("============================================================");
    
    #(SPI_PERIOD * 10);
    $finish;
end

//===========================================================
// 监控信号变化（调试用）
//===========================================================
always @(posedge clk) begin
    if (data_valid) begin
        $display("[%0t] data_valid ASSERTED, data_out=0x%02X", $time, data_out);
    end
end

//===========================================================
// 波形导出
//===========================================================
initial begin
    $dumpfile("spi_slave_fix.vcd");
    $dumpvars(0, tb_SPI_Slave_Fix);
end

//===========================================================
// 检查SPI信号活动（如果长时间无活动则报错）
//===========================================================
initial begin
    #1000000;  // 等待1ms
    if ($time > 100000) begin
        $display("\n[WARNING] Simulation running for %0t without finishing", $time);
        $display("Check if SPI clock is generating correctly");
    end
end

endmodule