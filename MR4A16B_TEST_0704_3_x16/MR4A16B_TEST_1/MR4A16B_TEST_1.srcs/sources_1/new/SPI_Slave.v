
`timescale 1ns/1ps

module SPI_Slave
#(
	parameter	CLK_FREQUENCE	= 200_000_000		,	//system clk frequence
				SPI_FREQUENCE	= 5_000_000			,	//spi clk frequence
				DATA_WIDTH		= 8					,	//serial word length
				CPOL			= 0					,	//SPI mode selection (mode 0 default)
				CPHA			= 0					 	//CPOL = clock polarity, CPHA = clock phase
)
(
	input								clk			,	//system clk
	input								rst_n		,	//system reset
	input		[DATA_WIDTH-1:0]		data_in		,	//the data sent by miso
	(*mark_debug="true"*)input								sclk		,	//spi bus sclk
	(*mark_debug="true"*)input								cs_n		,	//spi bus slave select line
	(*mark_debug="true"*)input								mosi		,	//spi bus mosi input
	(*mark_debug="true"*)output								miso		,	//spi bus miso output
	(*mark_debug="true"*)output								data_valid	,	//the data received by mosi valid
	output	reg	[DATA_WIDTH-1:0]		data_out	,	//the data received by mosi,valid when data_valid is high
	
	// ====== 新增：SPI时钟边沿输出信号 ======
	output	wire						shift_en	,	//SPI时钟移位边沿（用于发送数据）
	output	wire						sampl_en		//SPI时钟采样边沿（用于接收数据）
);

localparam	SFIFT_NUM = log2(DATA_WIDTH);

reg	[DATA_WIDTH-1:0]		data_reg	;	//the register to latch the data_in,also the shift register
reg	[ SFIFT_NUM-1:0]		sampl_num	;	//the counter to count the number of sample
reg							sclk_a		;	//sclk register to capture the edge of sclk
reg							sclk_b		;	//sclk register to capture the edge of sclk
wire						sclk_posedge;	//posedge of sclk
wire						sclk_negedge;	//negedge of sclk
reg							cs_n_a		;	//cs_n register to capture the edge of cs_n
reg							cs_n_b		;	//cs_n register to capture the edge of cs_n
wire						cs_n_negedge;	//negedge of cs_n to latch the data
wire						shift_en_internal;	//the signal to enable shift register to generate mosi
wire						sampl_en_internal;	//the signal to sample the data from miso

//------------------------------------------
//to capture the edge of sclk
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		sclk_a <= CPOL;
		sclk_b <= CPOL;
	end else begin
		sclk_a <= sclk;
		sclk_b <= sclk_a;
	end
end

assign sclk_posedge = ~sclk_b & sclk_a;
assign sclk_negedge = ~sclk_a & sclk_b;

//------------------------------------------
//to capture the edge of cs_n
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		cs_n_a	<= 1'b1;
		cs_n_b	<= 1'b1;
	end else begin
		cs_n_a	<= cs_n		;
		cs_n_b	<= cs_n_a	;
	end
end

assign cs_n_negedge = ~cs_n_a & cs_n_b;

//------------------------------------------
//==============================================
//==============GENERATE BLOCKS=================
// 根据CPHA配置采样使能和移位使能
generate
	case (CPHA)
		0: begin
			assign sampl_en_internal = sclk_posedge;
			assign shift_en_internal = sclk_negedge;
		end
		1: begin
			assign sampl_en_internal = sclk_negedge;
			assign shift_en_internal = sclk_posedge;
		end
		default: begin
			assign sampl_en_internal = sclk_posedge;
			assign shift_en_internal = sclk_negedge;
		end
	endcase
endgenerate

// ====== 输出到外部 ======
assign sampl_en = sampl_en_internal;
assign shift_en = shift_en_internal;

//==================================================
//the register to latch the data_in
//also the shift register to generate the miso
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		data_reg <= 'd0;
	else if(cs_n_negedge)
		data_reg <= data_in;
	else if (!cs_n & shift_en_internal) 
		data_reg <= {data_reg[DATA_WIDTH-2:0], 1'b0};
	else
		data_reg <= data_reg;
end

//miso output MSB first
// 注意：如果需要外部控制MISO，可以将此输出改为高阻
// 但为了保持兼容性，保留原有输出
assign miso = !cs_n ? data_reg[DATA_WIDTH-1] : 1'd0;

//==================================================
//sample data from the mosi line
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		data_out <= 'd0;
	else if (!cs_n & sampl_en_internal) 
		data_out <= {data_out[DATA_WIDTH-2:0], mosi};
	else
		data_out <= data_out;
end

//the counter to count the number of sampled data bit
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		sampl_num <= 'd0;
	else if (cs_n)
		sampl_num <= 'd0;
	else if (!cs_n & sampl_en_internal) 
		if (sampl_num == DATA_WIDTH)
			sampl_num <= 'd1;
		else
			sampl_num <= sampl_num + 1'b1;
	else
		sampl_num <= sampl_num;
end

//the received data valid
assign data_valid = sampl_num == DATA_WIDTH;

//the function to get the width of data 
function integer log2(input integer v);
  begin
	log2=0;
	while(v>>log2) 
	  log2=log2+1;
  end
endfunction

endmodule