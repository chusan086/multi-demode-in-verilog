`timescale 1ns / 1ps
// UART数据包封装控制模块
// 1. 发送状态内依靠byte_cnt发送多字节
// 2. 延时计数器是因为s_uart_ctrl_valid是单周期脉冲，
//      s_uart_ctrl_ready的下拉又会慢两拍，加入延时避免多次执行
// 数据包格式示例：
// +--------+--------+--------+--------+--------+--------+--------+--------+--------+--------++--------++--------+  
// | 0x28   | 0x2A   | XSK(1b)| 0x41   | ADDR_H | ADDR_L | 0x44   | DATA_H | DATA_L | ...    || 0x2A   || 0x29   |  
// +--------+--------+--------+--------+--------+--------+--------+--------+--------+--------++--------++--------+  
// | 包头1  | 包头2  | 标志位 | 地址标识| 地址高8| 地址低8| 数据标识| 数据高8| 数据低8| ...    |  包尾1  | 包尾2  | 
// +--------+--------+--------+--------+--------+--------+--------+--------+--------+--------++--------++--------+  
module uart_ctrl(
    input               sys_clk,sys_rstn,       //系统时钟，复位
    
    input [15:0]        s_uart_ctrl_addr,       // 接收到的频点地址    
    input [15:0]        s_uart_ctrl_data,       // 接收到的频点幅值    
    input               s_uart_ctrl_valid,      // 数据有效标志      
    output reg          s_uart_ctrl_ready,      // 接收就绪信号      
    input               s_uart_ctrl_end,        // 数据帧结束标志     
    input [7:0]         s_uart_ctrl_extra,        // 2XSK信号标志     
    
    output              tx                     
    );
    //内部信号规范
    wire                aclk = sys_clk;
    wire                rstn = sys_rstn;
    
    reg [15:0]          uart_ctrl_addr_r,uart_ctrl_data_r;
    reg [7:0]           uart_ctrl_extra_r;
    
    // 状态机控制
    reg [3:0]           cur_sta;
    reg [3:0]           nex_sta;
    reg                 st_done;        //状态完成（发送类状态）
    reg [1:0]           tx_ready_cnt;   //ready拉低的延时计数器
    
    //发送字节计数器
    reg [3:0]           byte_cnt;       
    
    // tx模块接口
    reg [7:0]           tx_data;
    reg                 tx_valid;
    wire                tx_ready;
    
    //状态定义
    localparam IDLE = 'd0;      // 空闲状态     
    localparam STRAT = 'd1;     // 发送包头和第一段数据     
    localparam SEND = 'd2;      // 发送数据段   
    localparam WAIT = 'd3;      // 等待新数据    
    localparam END = 'd5;       // 发送包尾 
    
    // 协议常量定义
    localparam HEADER_BYTE1   = 8'h28;   // 包头第一个字节 '('
    localparam HEADER_BYTE2   = 8'h2A;   // 包头第二个字节 '*'
    localparam ADDR_TAG       = 8'h41;   // 地址标识符 'A'
    localparam DATA_TAG       = 8'h44;   // 数据标识符 'D'
    localparam FOOTER_BYTE1   = 8'h2A;   // 包尾第一个字节 '*'
    localparam FOOTER_BYTE2   = 8'h29;   // 包尾第二个字节 ')'    
    
    always @(posedge aclk or negedge rstn) begin
        if(!rstn)cur_sta <= 'b0;
        else cur_sta <= nex_sta;
    end
    
    always @(*) begin
        case(cur_sta)
            IDLE : begin
                if(s_uart_ctrl_valid) nex_sta = STRAT;
                else nex_sta = IDLE;
            end
            STRAT : begin
                if(st_done) nex_sta = WAIT;
                else nex_sta = STRAT;
            end
            WAIT : begin
                if(s_uart_ctrl_valid) nex_sta = SEND;
                else if(s_uart_ctrl_end) nex_sta = END;
                else nex_sta = WAIT;
            end
            SEND : begin
                if(st_done) nex_sta = WAIT;
                else nex_sta = SEND;
            end
            END : begin
                if(st_done) nex_sta = IDLE;
                else nex_sta = END;
            end
        endcase
    end
    
    always @(posedge aclk or negedge rstn) begin
        if(!rstn) begin 
            //复位
            s_uart_ctrl_ready <= 1'b0;
            st_done <= 1'b0; 
            tx_valid <= 1'b0; 
            tx_data <= 'b0; 
            uart_ctrl_addr_r <= 'b0;
            uart_ctrl_data_r <= 'b0;
            uart_ctrl_extra_r <= 'b0; 
            tx_ready_cnt <= 'b0;
        end else begin
            s_uart_ctrl_ready <= 1'b0;
            st_done <= 1'b0;
            tx_valid <= 1'b0;
            case(cur_sta)
            IDLE : begin
                byte_cnt <= 'b0;
                if(s_uart_ctrl_valid)begin
                    s_uart_ctrl_ready <= 1'b0;
                    uart_ctrl_addr_r <= s_uart_ctrl_addr;
                    uart_ctrl_data_r <= s_uart_ctrl_data;
                    uart_ctrl_extra_r <= s_uart_ctrl_extra; 
                end else 
                    s_uart_ctrl_ready <= 1'b1;
            end
            STRAT : begin
                if(tx_ready_cnt == 2'b11)begin  
                    if(tx_ready)begin   //tx就绪
                        tx_ready_cnt <= 'b0;// 延时计数器重置
                        if(byte_cnt == 'd9) begin   //跳出该状态
                            st_done <= 1'b1;
                        end
                        else begin      //使能信号一个时钟
                            tx_valid <= 1'b1;
                            byte_cnt <= byte_cnt + 1'b1;
                        end
                    end
                end else tx_ready_cnt <= tx_ready_cnt + 1;
                case(byte_cnt)
                'd0 : tx_data <= HEADER_BYTE1;
                'd1 : tx_data <= HEADER_BYTE2;
                'd2 : tx_data <= uart_ctrl_extra_r;
                'd3 : tx_data <= ADDR_TAG;    
                'd4 : tx_data <= uart_ctrl_addr_r[15:8];
                'd5 : tx_data <= uart_ctrl_addr_r[7:0];
                'd6 : tx_data <= DATA_TAG;    
                'd7 : tx_data <= uart_ctrl_data_r[15:8];
                'd8 : tx_data <= uart_ctrl_data_r[7:0];
                endcase
            end
            WAIT : begin    //等待上位机数据
                byte_cnt <= 'b0;
                if(s_uart_ctrl_valid)begin
                    s_uart_ctrl_ready <= 1'b0;
                    uart_ctrl_addr_r <= s_uart_ctrl_addr;
                    uart_ctrl_data_r <= s_uart_ctrl_data; 
                end else 
                    s_uart_ctrl_ready <= 1'b1;
            end
            SEND : begin    
                if(tx_ready_cnt == 2'b11)begin
                    if(tx_ready)begin
                        tx_ready_cnt <= 'b0;
                        if(byte_cnt == 'd6) begin
                            st_done <= 1'b1;
                        end
                        else begin
                            tx_valid <= 1'b1;
                            byte_cnt <= byte_cnt + 1'b1;
                        end
                    end
                end else tx_ready_cnt <= tx_ready_cnt + 1;
                case(byte_cnt)
                'd0 : tx_data <= ADDR_TAG;    
                'd1 : tx_data <= uart_ctrl_addr_r[15:8];
                'd2 : tx_data <= uart_ctrl_addr_r[7:0];
                'd3 : tx_data <= DATA_TAG;    
                'd4 : tx_data <= uart_ctrl_data_r[15:8];
                'd5 : tx_data <= uart_ctrl_data_r[7:0];
                endcase
            end
            END : begin
                if(tx_ready_cnt == 2'b11)begin
                    if(tx_ready)begin
                        tx_ready_cnt <= 'b0;
                        if(byte_cnt == 'd2) begin
                            st_done <= 1'b1;
                        end else begin
                            tx_valid <= 1'b1;
                            byte_cnt <= byte_cnt + 1'b1;
                        end
                    end
                end else tx_ready_cnt <= tx_ready_cnt + 1;
                case(byte_cnt)
                'd0 : tx_data <= FOOTER_BYTE1;
                'd1 : tx_data <= FOOTER_BYTE2;
                endcase
            end
            endcase
        end
    end
    
    uart_tx s_uart_tx (                                     
	.clk(aclk),                          // 时钟信号输入
	.rstn(rstn),                         // 复位信号（低电平有效）
						
	.s_tx_data(tx_data),		
	.s_tx_valid(tx_valid),
	.s_tx_ready(tx_ready),
	
	.tx(tx)
	);
endmodule
