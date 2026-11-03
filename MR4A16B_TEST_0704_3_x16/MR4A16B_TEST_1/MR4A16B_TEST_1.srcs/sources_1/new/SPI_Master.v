`timescale 1ns/1ps

module spi_master
#(
	parameter	CLK_FREQUENCE	= 200_000_000		,
	parameter	SPI_FREQUENCE	= 15_000_000		,
	parameter	DATA_WIDTH		= 8					,
	parameter	CPOL			= 0					,
	parameter	CPHA			= 0					 	
)
(
	(*mark_debug="true"*)input								clk			,
	(*mark_debug="true"*)input								rst_n		,
	(*mark_debug="true"*)input		[DATA_WIDTH-1:0]		data_in		,
	(*mark_debug="true"*)input								start		,
	(*mark_debug="true"*)input								miso		,
	
	// 三态输出
	(*mark_debug="true"*)output	wire							sclk		,
	(*mark_debug="true"*)output	wire							cs_n		,
	(*mark_debug="true"*)output	wire							mosi		,
	
	(*mark_debug="true"*)output	reg							finish		,
	(*mark_debug="true"*)output	reg [DATA_WIDTH-1:0]		data_out	 	
);

localparam	FREQUENCE_CNT	= CLK_FREQUENCE/SPI_FREQUENCE - 1	,
			SHIFT_WIDTH		= log2(DATA_WIDTH)					,
			CNT_WIDTH		= log2(FREQUENCE_CNT)				;

localparam	IDLE	=	3'b000	,
			LOAD	=	3'b001	,
			SHIFT	=	3'b010	,
			DONE	=	3'b100	;

(*mark_debug="true"*)reg		[2:0]				cstate		;
(*mark_debug="true"*)reg		[2:0]				nstate		;
reg							clk_cnt_en	;
reg							sclk_a		;
reg							sclk_b		;
wire						sclk_posedge;
wire						sclk_negedge;
wire						shift_en	;
wire						sampl_en	;

reg							sclk_reg	;
reg							cs_n_reg	;
reg							mosi_reg	;

// ========== 关键修改：增加总线释放控制 ==========
// 定义哪些状态需要驱动总线
wire bus_active = (cstate == LOAD) || (cstate == SHIFT);

// 三态输出：只有在LOAD和SHIFT状态才驱动总线
assign sclk = bus_active ? sclk_reg : 1'bz;
assign mosi = bus_active ? mosi_reg : 1'bz;
// CS_N也释放，让上位机可以控制
assign cs_n = bus_active ? cs_n_reg : 1'bz;

(*mark_debug="true"*)reg		[CNT_WIDTH-1:0]		clk_cnt		;
(*mark_debug="true"*)reg		[SHIFT_WIDTH-1:0]	shift_cnt	;
(*mark_debug="true"*)reg		[DATA_WIDTH-1:0]	data_reg	;

//---------- sclk计数器 ----------
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		clk_cnt <= 'd0;
	else if (clk_cnt_en) 
		if (clk_cnt == FREQUENCE_CNT) 
			clk_cnt <= 'd0;
		else
			clk_cnt <= clk_cnt + 1'b1;
	else
		clk_cnt <= 'd0;
end

//---------- sclk生成 ----------
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		sclk_reg <= CPOL;
	else if (clk_cnt_en) 
		if (clk_cnt == FREQUENCE_CNT)  	
			sclk_reg <= ~sclk_reg; 
		else 
			sclk_reg <= sclk_reg;
	else
		sclk_reg <= CPOL;
end

//---------- sclk边沿检测 ----------
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		sclk_a <= CPOL;
		sclk_b <= CPOL;
	end else if (clk_cnt_en) begin
		sclk_a <= sclk_reg;
		sclk_b <= sclk_a;
	end else begin
		sclk_a <= CPOL;
		sclk_b <= CPOL;
	end
end

assign sclk_posedge = ~sclk_b & sclk_a;
assign sclk_negedge = ~sclk_a & sclk_b;

//---------- CPHA选择 ----------
generate
	case (CPHA)
		0: assign sampl_en = sclk_posedge;
		1: assign sampl_en = sclk_negedge;
		default: assign sampl_en = sclk_posedge;
	endcase
endgenerate

generate
 	case (CPHA)
		0: assign shift_en = sclk_negedge;
 		1: assign shift_en = sclk_posedge;
		default: assign shift_en = sclk_posedge;
	endcase
endgenerate

//---------- FSM状态机 ----------
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		cstate <= IDLE;
	else 
		cstate <= nstate;
end

always @(*) begin
	case (cstate)
		IDLE	: nstate = start ? LOAD : IDLE;
		LOAD	: nstate = SHIFT;
		SHIFT	: nstate = (shift_cnt == DATA_WIDTH) ? DONE : SHIFT;
		DONE	: nstate = IDLE;
		default: nstate = IDLE;
	endcase
end

//---------- FSM输出控制 ----------
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		clk_cnt_en	<= 1'b0	;
		data_reg	<= 'd0	;
		cs_n_reg	<= 1'b1	;
		mosi_reg	<= 1'b0	;
		shift_cnt	<= 'd0	;
		finish 		<= 1'b0	;
	end else begin
		case (nstate)
			IDLE	: begin
				clk_cnt_en	<= 1'b0	;
				data_reg	<= 'd0	;
				cs_n_reg	<= 1'b1	;
				mosi_reg	<= 1'b0	;
				shift_cnt	<= 'd0	;
				finish 		<= 1'b0	;
			end
			LOAD	: begin
				clk_cnt_en	<= 1'b1		;
				data_reg	<= data_in	;
				cs_n_reg	<= 1'b0		;
				mosi_reg	<= data_in[DATA_WIDTH-1];
				shift_cnt	<= 'd0		;
				finish 		<= 1'b0		;
			end
			SHIFT	: begin
				if (shift_en) begin
					shift_cnt	<= shift_cnt + 1'b1 ;
					data_reg	<= {data_reg[DATA_WIDTH-2:0], 1'b0};
					mosi_reg	<= data_reg[DATA_WIDTH-2];
				end else begin
					shift_cnt	<= shift_cnt	;
					data_reg	<= data_reg		;
					mosi_reg	<= mosi_reg		;
				end
				clk_cnt_en	<= 1'b1	;
				cs_n_reg	<= 1'b0	;
				finish 		<= 1'b0	;
			end
			DONE	: begin
				clk_cnt_en	<= 1'b0	;
				data_reg	<= 'd0	;
				cs_n_reg	<= 1'b1	;
				mosi_reg	<= 1'b0	;
				finish 		<= 1'b1	;
			end
			default	: begin
				clk_cnt_en	<= 1'b0	;
				data_reg	<= 'd0	;
				cs_n_reg	<= 1'b1	;
				mosi_reg	<= 1'b0	;
				finish 		<= 1'b0	;
			end
		endcase
	end
end

//---------- 采样MISO数据 ----------
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) 
		data_out <= 'd0;
	else if (sampl_en && bus_active)  // 只在驱动总线时采样
		data_out <= {data_out[DATA_WIDTH-2:0], miso};
	else
		data_out <= data_out;
end

//---------- log2函数 ----------
function integer log2(input integer v);
  begin
	log2=0;
	while(v>>log2) 
	  log2=log2+1;
  end
endfunction

endmodule
