
`timescale 1ns / 1ps

module trng_8bit (
    input  wire        clk,
    input  wire        rst_n,
    output reg [7:0]   rnd_data,   // 8位随机数输出
    output reg         rnd_valid   // 输出有效标志（每8个时钟周期有效一次）
);

    // 环形振荡器参数
    localparam RO_LENGTH = 5;
    
    // 环形振荡器连线
    wire [RO_LENGTH-1 : 0] ro_chain;
    reg ro_sample;
    
    // 构建环形振荡器
    generate
        genvar i;
        for (i = 0; i < RO_LENGTH-1; i = i + 1) begin : ro_stages
            assign ro_chain[i+1] = ~ro_chain[i];
        end
    endgenerate
    assign ro_chain[0] = ~ro_chain[RO_LENGTH-1];
    
    // 采样时钟分频（约 200MHz / 65536 ≈ 3.05kHz 采样率）
    reg [7:0] sample_cnt;
    wire sample_trigger;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            sample_cnt <= 17'd0;
        else
            sample_cnt <= sample_cnt + 1'b1;
    end
    assign sample_trigger = (sample_cnt == 16'd0);
    
    // 采样振荡器输出（亚稳态采样，产生随机性）
    always @(posedge sample_trigger or negedge rst_n) begin
        if(!rst_n)
            ro_sample <= 1'b0;
        else
            ro_sample <= ro_chain[RO_LENGTH-1];
    end
    
    // 后处理：异或相邻采样值，消除偏差
    reg [1:0] history;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            history <= 2'b00;
        end
        else if(sample_trigger) begin
            history <= {history[0], ro_sample};
        end
    end
    
    // 8位移位寄存器，生成8位随机数
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            shift_reg <= 8'd0;
            bit_cnt <= 3'd0;
            rnd_data <= 8'd0;
            rnd_valid <= 1'b0;
        end
        else begin
            rnd_valid <= 1'b0;
            
            if(sample_trigger) begin
                // 每次采样得到一个随机位
                shift_reg <= {shift_reg[6:0], history[0] ^ history[1]};
                bit_cnt <= bit_cnt + 1;
                
                // 每收集8位，输出一个字节
                if(bit_cnt == 3'd7) begin
                    rnd_data <= {shift_reg[6:0], history[0] ^ history[1]};
                    rnd_valid <= 1'b1;
                    bit_cnt <= 3'd0;
                end
            end
        end
    end

endmodule
