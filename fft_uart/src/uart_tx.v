module uart_tx #(
	parameter BUAD_RATE = 9600,			// 波特率参数
	parameter CLK_FRE = 50_000_000		// 时钟频率参数	
)(                                     
	input clk,                          // 时钟信号输入
	input rstn,                         // 复位信号（低电平有效）
								
	
	input [7:0]    s_tx_data,
	input          s_tx_valid,                        // 发送数据信号
	output reg     s_tx_ready,
	
	output reg tx);

	
	reg [7:0] data_r;							// 发送数据寄存器
	reg [3:0] state, next_state;			// 状态和下一状态寄存器
	integer clk_cnt;                    // 时钟计数器
	
	localparam CNT_MAX = CLK_FRE / BUAD_RATE;
	localparam IDLE  = 'd0,
	           START = 'd1,
	           BIT_0 = 'd2,
	           BIT_1 = 'd3,
	           BIT_2 = 'd4,
	           BIT_3 = 'd5,
	           BIT_4 = 'd6,
	           BIT_5 = 'd7,
	           BIT_6 = 'd8,
	           BIT_7 = 'd9,
	           STOP  = 'd0,
	           WAIT  = 'd11;
							
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			state <= IDLE;
		end else begin
			state <= next_state;
		end
	end
	
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			data_r <= 'b0;
		end else if((state == IDLE)&&s_tx_valid) begin
			data_r <= s_tx_data;
		end
	end
	
	always @(*) begin
		case (state)
			IDLE: begin
				next_state = (s_tx_valid) ? WAIT : IDLE;
			end
			WAIT : next_state = (clk_cnt == CNT_MAX - 1) ? START : WAIT ;
			START: next_state = (clk_cnt == CNT_MAX - 1) ? BIT_0 : START;
			BIT_0: next_state = (clk_cnt == CNT_MAX - 1) ? BIT_1 : BIT_0;
			BIT_1: next_state = (clk_cnt == CNT_MAX - 1) ? BIT_2 : BIT_1;
			BIT_2: next_state = (clk_cnt == CNT_MAX - 1) ? BIT_3 : BIT_2;
			BIT_3: next_state = (clk_cnt == CNT_MAX - 1) ? BIT_4 : BIT_3;
			BIT_4: next_state = (clk_cnt == CNT_MAX - 1) ? BIT_5 : BIT_4;
			BIT_5: next_state = (clk_cnt == CNT_MAX - 1) ? BIT_6 : BIT_5;
			BIT_6: next_state = (clk_cnt == CNT_MAX - 1) ? BIT_7 : BIT_6;
			BIT_7: next_state = (clk_cnt == CNT_MAX - 1) ? STOP : BIT_7;
			STOP:  next_state = (clk_cnt == CNT_MAX - 1) ? IDLE : STOP;
			default: next_state = IDLE;
		endcase
	end
	
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			s_tx_ready <= 1'b1;
		end else if (state == IDLE) begin
			s_tx_ready <= 1'b1;
		end else begin
			s_tx_ready <= 1'b0;
		end
	end
	
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			clk_cnt <= 0;
		end else if (clk_cnt == CNT_MAX - 1 ||state == IDLE) begin
			clk_cnt <= 0;
		end else begin
			clk_cnt <= clk_cnt + 1;
		end
	end
	
	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			tx <= 1'b1;
		end else begin
			case (state)
			    WAIT : tx <= 1'b1;
				START: if (clk_cnt == 0) tx <= 1'b0;
				BIT_0: if (clk_cnt == 0) tx <= data_r[0];
				BIT_1: if (clk_cnt == 0) tx <= data_r[1];
				BIT_2: if (clk_cnt == 0) tx <= data_r[2];
				BIT_3: if (clk_cnt == 0) tx <= data_r[3];
				BIT_4: if (clk_cnt == 0) tx <= data_r[4];
				BIT_5: if (clk_cnt == 0) tx <= data_r[5];
				BIT_6: if (clk_cnt == 0) tx <= data_r[6];
				BIT_7: if (clk_cnt == 0) tx <= data_r[7];
				STOP:  if (clk_cnt == 0) tx <= 1'b1;
				default: tx <= 1'b1;     
			endcase                                
		end
	end
	
endmodule
	
