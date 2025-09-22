// uart的计数上限只有65535
module uart_rx #(
	parameter BUAD_RATE = 9600,			// 波特率参数
	parameter CLK_FRE = 50_000_000		// 时钟频率参数	
)(
	input              clk,                         // 时钟信号输入
	input              rstn,						   // 复位信号（低电平有效）		
	                           
										
	(* mark_debug = "true" *)output reg [7:0]   m_rx_data,				// 接收的数据输出
	(* mark_debug = "true" *)output reg         m_rx_busy,                   // 接收忙信号
	(* mark_debug = "true" *)input              rx
	);							

	
	(* mark_debug = "true" *)reg [3:0] state, next_state;			// 状态和下一状态寄存器
	(* mark_debug = "true" *)reg [15:0] clk_cnt;							// 时钟计数器
	
	// 每个比特的时钟周期数
	localparam CNT_MAX = CLK_FRE / BUAD_RATE;
	localparam IDLE = 4'b0000,				// 状态定义
	           START = 4'b0001,
	           BIT_0 = 4'b0010,
	           BIT_1 = 4'b0011,
	           BIT_2 = 4'b0100,
	           BIT_3 = 4'b0101,
	           BIT_4 = 4'b0110,
	           BIT_5 = 4'b0111,
	           BIT_6 = 4'b1000,
	           BIT_7 = 4'b1001,
	           STOP = 4'b1010;
	
	// 状态转移逻辑	
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			state <= IDLE;
		end else begin
			state <= next_state;
		end
	end
	
	// 下一状态计算逻辑
	always @(*) begin
		case (state)
			IDLE: next_state = (!rx) ? START : IDLE;
			START: next_state = (clk_cnt >= CNT_MAX - 1) ? BIT_0 : START;
			BIT_0: next_state = (clk_cnt >= CNT_MAX - 1) ? BIT_1 : BIT_0;
			BIT_1: next_state = (clk_cnt >= CNT_MAX - 1) ? BIT_2 : BIT_1;
			BIT_2: next_state = (clk_cnt >= CNT_MAX - 1) ? BIT_3 : BIT_2;
			BIT_3: next_state = (clk_cnt >= CNT_MAX - 1) ? BIT_4 : BIT_3;
			BIT_4: next_state = (clk_cnt >= CNT_MAX - 1) ? BIT_5 : BIT_4;
			BIT_5: next_state = (clk_cnt >= CNT_MAX - 1) ? BIT_6 : BIT_5;
			BIT_6: next_state = (clk_cnt >= CNT_MAX - 1) ? BIT_7 : BIT_6;
			BIT_7: next_state = (clk_cnt >= CNT_MAX - 1) ? STOP : BIT_7;
			STOP: next_state = (clk_cnt >= CNT_MAX >> 1) ? IDLE : STOP;
			default: next_state = IDLE;
		endcase
	end
	
	// 接收忙信号逻辑
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			m_rx_busy <= 1'b0;
		end else if (state == IDLE) begin
			m_rx_busy <= 1'b0;
		end else begin
			m_rx_busy <= 1'b1;
		end
	end
	
	
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			clk_cnt <= 0;
		end else if (clk_cnt >= CNT_MAX - 1 || state == IDLE) begin
			clk_cnt <= 0;
		end else begin
			clk_cnt <= clk_cnt + 1;
		end
	end
	
	// 数据接收逻辑
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			m_rx_data <= 8'd0;
		end else begin
			case (state)
				BIT_0: if (clk_cnt == CNT_MAX >> 1) m_rx_data[0] <= rx;
				BIT_1: if (clk_cnt == CNT_MAX >> 1) m_rx_data[1] <= rx;
				BIT_2: if (clk_cnt == CNT_MAX >> 1) m_rx_data[2] <= rx;
				BIT_3: if (clk_cnt == CNT_MAX >> 1) m_rx_data[3] <= rx;
				BIT_4: if (clk_cnt == CNT_MAX >> 1) m_rx_data[4] <= rx;
				BIT_5: if (clk_cnt == CNT_MAX >> 1) m_rx_data[5] <= rx;
				BIT_6: if (clk_cnt == CNT_MAX >> 1) m_rx_data[6] <= rx;
				BIT_7: if (clk_cnt == CNT_MAX >> 1) m_rx_data[7] <= rx;
				default: m_rx_data <= m_rx_data;     
			endcase                                
		end
	end
	
endmodule


