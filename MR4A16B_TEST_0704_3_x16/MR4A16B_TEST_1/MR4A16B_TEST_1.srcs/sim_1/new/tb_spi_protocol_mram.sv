`timescale 1ns / 1ps

// ============================================================
// MRAM 
// ============================================================
module mram_model (
    inout [15:0] DQ,
    input EN,
    input WN,
    input GN,
    input UBN,
    input LBN,
    input [21:0] A
);

    reg [15:0] mem [0:4194303];  // -> 4M words
    reg [15:0] dq_out;
    reg dq_oe;
    reg [15:0] dq_reg;
    
    integer read_count;
    integer write_count;
    
    initial begin
        for(integer i = 0; i < 65536; i = i + 1) begin
            mem[i] = i[15:0];
        end
        dq_out = 16'h0;
        dq_oe = 1'b0;
        dq_reg = 16'h0;
        read_count = 0;
        write_count = 0;
        $display("[MRAM] Initialized at time %t", $time);
    end
    
    assign DQ = dq_oe ? dq_out : 16'hz;
    

    always @(negedge GN) begin
        if(EN == 1'b0 && WN == 1'b1) begin
            dq_out = mem[A];
            dq_oe = 1'b1;
            read_count = read_count + 1;
            $display("[MRAM] READ  [%0d] A=0x%05X -> DQ=0x%04X", 
                     read_count, A, dq_out);
        end
    end
    
    always @(posedge GN) begin
        if(EN == 1'b0 && WN == 1'b1) begin
            dq_oe = 1'b0;
        end
    end
    
    always @(posedge WN) begin
        if(EN == 1'b0 && GN == 1'b1) begin
            dq_reg = DQ;
            mem[A] = dq_reg;
            write_count = write_count + 1;
            $display("[MRAM] WRITE [%0d] A=0x%05X <- DQ=0x%04X", 
                     write_count, A, dq_reg);
        end
    end

endmodule


// ============================================================
// Testbench
module tb_spi_protocol_mram();

// ============================================================
localparam CLK_PERIOD = 5;        // 200MHz -> 5ns
localparam SPI_BIT_PERIOD = 200;  // 5MHz -> 200ns
localparam SPI_HALF = SPI_BIT_PERIOD / 2;

// ============================================================
reg clk;
reg rst_n;

reg spi_sclk;
reg spi_cs_n;
reg spi_mosi;
wire spi_miso;

// MRAM 
wire [15:0] DQ;
wire EN;
wire WN;
wire GN;
wire UBN;
wire LBN;
wire [21:0] A;

// ============================================================
top u_top (
    .rst_n(rst_n),
    .clkp(clk),
    .clkn(~clk),
    .spi_sclk(spi_sclk),
    .spi_cs_n(spi_cs_n),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .DQ(DQ),
    .EN(EN),
    .WN(WN),
    .GN(GN),
    .UBN(UBN),
    .LBN(LBN),
    .A(A)
);

// ============================================================
mram_model u_mram (
    .DQ(DQ),
    .EN(EN),
    .WN(WN),
    .GN(GN),
    .UBN(UBN),
    .LBN(LBN),
    .A(A)
);



// ============================================================
// top
wire [15:0]  R_DQ         = u_top.R_DQ;
wire [15:0] dout          = u_top.dout;
wire tb_start_d1          = u_top.start_d1;
wire tb_start_d2          = u_top.start_d2;
wire tb_start_d3          = u_top.start_d3;
wire tb_start             = u_top.start;
wire tb_stop              = u_top.stop;
wire tb_flg               = u_top.flg;
wire [31:0] tb_loop_idx   = u_top.loop_idx;
wire [20:0] tb_err_cnt    = u_top.err_cnt;

wire [22:0] tb_addr_cnt    = u_top.addr_cnt;
wire [21:0] tb_addr        = u_top.addr;
wire [21:0] tb_addr_d      = u_top.addr_d;
wire [22:0] tb_addr_hold_cnt = u_top.addr_hold_cnt;
wire        tb_rd_en       = u_top.rd_en;
wire        tb_rd_en_d     = u_top.rd_en_d;
wire        tb_rd_en_d2    = u_top.rd_en_d2;
wire        tb_keep        = u_top.keep;
//wire        tb_trng_valid        = u_top.trng_valid;

// ============================================================
// spi_protocol
wire [4:0]  spi_rx_state    = u_top.u_spi_protocol.rx_state;
wire        spi_data_valid  = u_top.u_spi_protocol.spi_data_valid;
wire        spi_spi_data_valid_d2   = u_top.u_spi_protocol.spi_data_valid_d2;
wire [7:0]  spi_data_out    = u_top.u_spi_protocol.spi_data_out;
wire        spi_start_test  = u_top.u_spi_protocol.start_test;
wire        spi_stop_test   = u_top.u_spi_protocol.stop_test;

wire        tb_loop_finish        = u_top.loop_finish;
wire        tb_frame_ack_latched   = u_top.frame_ack_latched ;
//wire        spi_send_frame_ack      = u_top.u_spi_protocol.send_frame_ack;
wire        spi_tx_sending          = u_top.u_spi_protocol.tx_sending;

// ===== 新增 TX 控制信号（基于 CS 下降沿触发） =====
wire        cs_n_d1               = u_top.u_spi_protocol.cs_n_d1;
wire        cs_n_neg              = u_top.u_spi_protocol.cs_n_neg;
wire        cs_n_pos              = u_top.u_spi_protocol.cs_n_pos;
wire        frame_sent_this_cs    = u_top.u_spi_protocol.frame_sent_this_cs;
wire        pending_test_complete = u_top.u_spi_protocol.pending_test_complete;
wire        pending_stop          = u_top.u_spi_protocol.pending_stop;
wire        tx_done_pulse         = u_top.u_spi_protocol.tx_done_pulse;
wire [4:0]  tx_byte_cnt           = u_top.u_spi_protocol.tx_byte_cnt;
wire [4:0]  tx_byte_ptr           = u_top.u_spi_protocol.tx_byte_ptr;
wire [2:0]  tx_bit_cnt            = u_top.u_spi_protocol.tx_bit_cnt;
wire [7:0]  tx_shift_reg          = u_top.u_spi_protocol.tx_shift_reg;
wire        miso_out_pre          = u_top.u_spi_protocol.miso_out_pre;

//wire        next_loop_start  = u_top.next_loop_start;
wire        next_loop_start_d1  = u_top.next_loop_start_d1;
wire        next_loop_start_d2  = u_top.next_loop_start_d2;
wire        next_loop_start_d3  = u_top.next_loop_start_d3;
//wire        spi_loop_idx_changed  = u_top.loop_idx_changed;

wire [31:0] spi_loop_count = u_top.u_spi_protocol.loop_count; // 注意模块内端口名是loop_count
wire [3:0]  spi_test_mode = u_top.u_spi_protocol.test_mode; // test_mode是spi_protocol的输出
wire [22:0] spi_test_length = u_top.u_spi_protocol.test_length;
wire [21:0] spi_start_addr = u_top.u_spi_protocol.start_addr;
wire [7:0]  spi_data_pattern = u_top.u_spi_protocol.data_pattern;
generate
    genvar idx;
    for(idx = 0; idx < 17; idx = idx + 1) begin : monitor_tx_buf
        wire [7:0] tx_buf_val = u_top.u_spi_protocol.tx_buf[idx];
    end
endgenerate


// ============================================================
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// ============================================================
initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
    #100;
    $display("[TB] Reset released at time %t", $time);
end

// ============================================================
task spi_send_bit;
    input bit_val;
    begin
        @(negedge clk);
        spi_mosi <= bit_val;
        spi_sclk <= 1'b1;  
        #(SPI_HALF);
        spi_sclk <= 1'b0;  
        #(SPI_HALF);
    end
endtask

task spi_send_byte;
    input [7:0] data;
    integer j;
    begin
        for(j = 7; j >= 0; j = j - 1) begin
            spi_send_bit(data[j]);
        end
    end
endtask

task spi_read_byte;
    output [7:0] data;
    integer j;
    begin
        data = 0;
        for(j = 7; j >= 0; j = j - 1) begin
            @(negedge clk);
            spi_sclk <= 1'b1;  
            #(SPI_HALF);
            data[j] = spi_miso;
            spi_sclk <= 1'b0; 
            #(SPI_HALF);
        end
    end
endtask

// ============================================================
// ·?????????
// ============================================================
task send_config_frame;
    input [7:0] chip_type;
    input [3:0] test_mode;
    input [7:0] data_pattern;
    input [21:0] start_addr;
    input [22:0] test_length;
    input [31:0] loop_count;
    input [15:0] t_avav;
    input [1:0] write_mode;
    input [1:0] read_mode;
    input [7:0] log_print;
    
    reg [7:0] frame [0:64];
    reg [7:0] checksum;
    integer k;
    begin
        // 构建帧
        frame[0]  = 8'h55;
        frame[1]  = chip_type;
        frame[2]  = {4'h0, test_mode};
        frame[3]  = data_pattern;
        frame[4]  = start_addr[7:0];
        frame[5]  = start_addr[15:8];
        frame[6]  = {2'h0, start_addr[21:16]};
        frame[7]  = 8'h00;
        frame[8]  = test_length[7:0];
        frame[9]  = test_length[15:8];
        frame[10] = {1'h0, test_length[22:16]};
        frame[11] = 8'h00;
        frame[12] = loop_count[7:0];
        frame[13] = loop_count[15:8];
        frame[14] = loop_count[23:16];
        frame[15] = loop_count[31:24];
        frame[16] = t_avav[7:0];
        frame[17] = {6'h0, write_mode};
        frame[18] = {6'h0, read_mode};
        frame[19] = log_print;
        frame[20] = 8'h00;
        frame[21] = 8'h00;
        frame[22] = 8'h00;
        frame[23] = 8'hAA;
        
        // 计算校验和 (字节1~21)
        checksum = 0;
        for(k = 1; k <= 21; k = k + 1) begin
            checksum = checksum + frame[k];
        end
        frame[22] = checksum;
        
        $display("\n");
        $display("========================================");
        $display("  SPI CONFIG FRAME");
        $display("========================================");
        $display("  CHIP_TYPE   : 0x%02X", frame[1]);
        $display("  TEST_MODE   : %d", test_mode);
        $display("  DATA_PATTERN: %d", data_pattern);
        $display("  START_ADDR  : 0x%05X", start_addr);
        $display("  TEST_LENGTH : %d", test_length);
        $display("  LOOP_COUNT  : %d", loop_count);
        $display("  T_AVAV      : %d", t_avav);
        $display("  CHECKSUM    : 0x%02X", checksum);
        $display("========================================\n");
        
        // ·?????
        spi_cs_n <= 1'b0;
        @(negedge clk);
        #100;
        
        for(k = 0; k < 24; k = k + 1) begin
            spi_send_byte(frame[k]);
        end
        
        @(negedge clk);
        #100;
        spi_cs_n <= 1'b1;
        #(SPI_BIT_PERIOD * 100); //200ns*750   模拟150us间隔
    end
endtask

// ============================================================
// ·????ò????????
// ============================================================
task send_simple_config;
    input [3:0] test_mode;
    input [7:0] data_pattern;
    input [22:0] test_length;
    input [31:0] loop_count;
    begin
        send_config_frame(
            8'h83,
            test_mode,
            data_pattern,
            22'h001000,
            test_length,
            loop_count,
            16'd7,
            2'b01,
            2'b01,
            8'h00
        );
    end
endtask

// ============================================================
// ·????????ü??
// ============================================================
task send_stop_command;
    begin
        $display("\n[SPI] Sending Stop Command: 55 FF AA");
        spi_cs_n <= 1'b0;
        @(negedge clk);
        #100;
        spi_send_byte(8'h55);
        spi_send_byte(8'hFF);
        spi_send_byte(8'hAA);
        @(negedge clk);
        #100;
        spi_cs_n <= 1'b1;
        #(SPI_BIT_PERIOD * 10);
    end
endtask

// ============================================================
task wait_for_test_complete;
    input integer timeout_us;
    integer timeout_cycles;
    integer i;
    reg done;
    begin
        timeout_cycles = timeout_us * 1000 / CLK_PERIOD;
        $display("[TB] Waiting for all loops complete (timeout: %d us)", timeout_us);
        done = 0;
        for(i = 0; i < timeout_cycles; i = i + 1) begin
            @(posedge clk);
            if(u_top.loop_done) begin
                $display("[TB] All loops completed at cycle %d", i);
                $display("    loop_idx = %d", u_top.loop_idx);
                done = 1;
                i = timeout_cycles;
            end
        end
        if(!done) begin
            $display("[TB] WARNING: Timeout waiting for all loops!");
        end
    end
endtask

// ============================================================
// ????SPI?ì??
// ============================================================
task wait_for_spi_response;
    reg [7:0] rx_byte;
    integer byte_cnt;
    integer timeout;
    integer max_wait;
    reg done;
    begin
        byte_cnt = 0;
        timeout = 0;
        max_wait = 50000;
        done = 0;
        $display("[SPI] Waiting for response...");
        
        while(timeout < max_wait && !done) begin
            @(negedge spi_cs_n);
            #(SPI_HALF/2);
            
            if(spi_cs_n == 1'b0) begin
                $display("[SPI] CS_N low detected, reading response...");
                
                while(spi_cs_n == 1'b0 && !done) begin
                    spi_read_byte(rx_byte);
                    $display("[SPI] Response[%d] = 0x%02X", byte_cnt, rx_byte);
                    byte_cnt = byte_cnt + 1;
                    
                    if(rx_byte == 8'hAA) begin
                        $display("[SPI] Frame tail detected");
                        done = 1;
                    end
                end
            end
            
            timeout = timeout + 1;
            #(SPI_BIT_PERIOD);
        end
        
        if(timeout >= max_wait) begin
            $display("[SPI] WARNING: Response timeout!");
        end
    end
endtask

// ============================================================
// 新增：发送 dummy 周期任务（支持无限循环）
// ============================================================
task send_dummy_cycles;
    input integer cycles;           // 周期数，-1 表示无限循环直到 loop_done
    input integer bytes_per_cycle;  // 每周期 dummy 字节数，默认 64
    integer i, j;
    begin
        if(cycles == -1) begin
            $display("[SPI] Starting infinite dummy cycles (until loop_done)");
            while(!u_top.loop_done) begin
                spi_cs_n <= 1'b0;
                @(negedge clk);
                #100;
                for(i = 0; i < bytes_per_cycle; i = i + 1) begin
                    spi_send_byte(8'hFF);
                end
                @(negedge clk);
                #100;
                spi_cs_n <= 1'b1;
                #(SPI_BIT_PERIOD * 100);  // 间隔
            end
            $display("[SPI] Dummy cycles stopped (all loops done)");
        end else begin
            // 有限次数循环保持原样
            $display("[SPI] Sending %0d dummy cycles, each %0d bytes", cycles, bytes_per_cycle);
            for(i = 0; i < cycles; i = i + 1) begin
                spi_cs_n <= 1'b0;
                @(negedge clk);
                #100;
                for(j = 0; j < bytes_per_cycle; j = j + 1) begin
                    spi_send_byte(8'hFF);
                end
                @(negedge clk);
                #100;
                spi_cs_n <= 1'b1;
                #(SPI_BIT_PERIOD * 5);
            end
        end
    end
endtask

// ============================================================
// 监控器
// ============================================================
reg [4:0] prev_rx_state;
reg prev_start_test;
reg prev_stop_test;
reg prev_test_complete;
reg [31:0] prev_loop_count;

always @(posedge clk) begin
    // rx_state监控
    if(spi_rx_state !== prev_rx_state) begin
        $display("[FSM] rx_state: %d -> %d", prev_rx_state, spi_rx_state);
        prev_rx_state = spi_rx_state;
    end
    
    // spi_data_valid监控
    if(spi_data_valid) begin
        $display("[SPI] data_valid=1, data_out=0x%02X, rx_state=%d", 
                 spi_data_out, spi_rx_state);
    end
    
    // start_test监控
    if(spi_start_test !== prev_start_test) begin
        if(spi_start_test) begin
            $display("*** [EVENT] START_TEST asserted");
            $display("    loop_count = %d", spi_loop_count);
            $display("    test_mode  = %d", spi_test_mode);
            $display("    test_length= %d", spi_test_length);
            $display("    start_addr = 0x%05X", spi_start_addr);
            $display("    data_pattern= %d", spi_data_pattern);
        end
        prev_start_test = spi_start_test;
    end
    
    // stop_test监控
    if(spi_stop_test !== prev_stop_test) begin
        if(spi_stop_test) begin
            $display("*** [EVENT] STOP_TEST asserted (stop command received)");
        end
        prev_stop_test = spi_stop_test;
    end
    
    // test_complete监控 (使用stop信号)
    if(tb_stop !== prev_test_complete) begin
        if(tb_stop) begin
            $display("*** [EVENT] TEST_COMPLETE asserted (loop done)");
            $display("    loop_idx = %d", tb_loop_idx);
        end
        prev_test_complete = tb_stop;
    end
    
    // loop_count变化监控
    if(spi_loop_count !== prev_loop_count) begin
        $display("[SPI] loop_count changed: %d -> %d", 
                 prev_loop_count, spi_loop_count);
        prev_loop_count = spi_loop_count;
    end
end

// ============================================================
// 错误检测监控
// ============================================================
always @(posedge clk) begin
    if(u_top.err_flg) begin
        $display("*** [ERROR] Detected at time %t", $time);
        $display("    Addr: 0x%05X, Expected: 0x%04X, Actual: 0x%04X", 
                 u_top.addr_d, u_top.dout_ref, u_top.RD_DATA);
    end
end

// ============================================================
// 测试完成监控
// ============================================================
always @(posedge clk) begin
    if(tb_stop) begin
        $display("*** [TEST] FINISHED at time %t", $time);
        $display("    Total Loops: %d", tb_loop_idx);
        $display("    Total Errors: %d", u_top.err_cnt);
    end
end

// ============================================================
// 主测试流程（已修改）
// ============================================================
initial begin
    spi_sclk = 0;
    spi_cs_n = 1;
    spi_mosi = 0;
    prev_rx_state = 0;
    prev_start_test = 0;
    prev_stop_test = 0;
    prev_test_complete = 0;
    prev_loop_count = 0;
    
    wait(rst_n == 1);
    #1000;
    
    $display("\n");
    $display("=========================================================");
    $display("           SPI PROTOCOL + MRAM TEST");
    $display("=========================================================\n");
    
//    // ============================================================
//    // TEST 1: 写测试 (单次)
//    // ============================================================
//    $display("\n>>> TEST 1: Write Test (test_mode=0) <<<");
//    send_simple_config(4'd0, 8'd1, 23'd16, 32'd3);
//    fork
//        send_dummy_cycles(-1, 64);   // 后台持续发送 dummy
//    join_none
//    wait_for_test_complete(1000);
//    disable fork;                    // 终止后台 dummy
//    #50000;
    
//    // ============================================================
//    // TEST 2: 读测试 (单次)
//    // ============================================================
//    $display("\n>>> TEST 2: Read Test (test_mode=1) <<<");
//    send_simple_config(4'd1, 8'd1, 23'd32, 32'd3);
//    fork
//        send_dummy_cycles(-1, 64);
//    join_none
//    wait_for_test_complete(1000);
//    disable fork;
//    #50000;
    
    // ============================================================
    // TEST 3: 先写后读测试 (循环2次)  -- 启用并修改
    // ============================================================
    $display("\n>>> TEST 3: Write-Read Test (test_mode=2, loop_count=2) <<<");
    send_config_frame(
        8'h83,
        4'd2,//mode
        8'd2,//din_sel
        21'h0020,//ini
        22'd100,//num
        32'd5,//loop
        16'd7,//avav
        2'b10,
        2'b01,
        8'h00
    );
    fork
        send_dummy_cycles(-1, 64);   // 后台无限发送 dummy
    join_none
    wait_for_test_complete(2000);
    disable fork;                    // 测试完成，停止 dummy
    #50000;
    
//    // ============================================================
//    // TEST 4: 写测试 (循环5次)
//    // ============================================================
//    $display("\n>>> TEST 4: Write Test (test_mode=0, loop_count=5) <<<");
//    send_simple_config(4'd0, 8'd1, 23'd8, 32'd5);
//    fork
//        send_dummy_cycles(-1, 64);
//    join_none
//    wait_for_test_complete(1000);
//    disable fork;
//    #50000;
    
    // ============================================================
    // 测试完成
    // ============================================================
    $display("\n");
    $display("=========================================================");
    $display("              ALL TESTS COMPLETED");
    $display("=========================================================");
    $display("  Final Errors: %d", u_top.err_cnt);
    $display("  MRAM Reads: %d, Writes: %d", 
             u_mram.read_count, u_mram.write_count);
    $display("=========================================================\n");
    
    #100000;
    $finish;
end

// ============================================================
// 超时保护
// ============================================================
initial begin
    #50000000;
    $display("ERROR: Simulation timeout!");
    $finish;
end

// ============================================================
// VCD Dump
// ============================================================
initial begin
    $dumpfile("tb_spi_protocol_mram.vcd");
    $dumpvars(0, tb_spi_protocol_mram);
end

endmodule
