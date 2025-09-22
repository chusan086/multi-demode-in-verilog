`timescale 1ns / 1ps
// UART���ݰ���װ����ģ��
// 1. ����״̬������byte_cnt���Ͷ��ֽ�
// 2. ��ʱ����������Ϊs_uart_ctrl_valid�ǵ��������壬
//      s_uart_ctrl_ready�������ֻ������ģ�������ʱ������ִ��
// ���ݰ���ʽʾ����
// +--------+--------+--------+--------+--------+--------+--------+--------+--------+--------++--------++--------+  
// | 0x28   | 0x2A   | XSK(1b)| 0x41   | ADDR_H | ADDR_L | 0x44   | DATA_H | DATA_L | ...    || 0x2A   || 0x29   |  
// +--------+--------+--------+--------+--------+--------+--------+--------+--------+--------++--------++--------+  
// | ��ͷ1  | ��ͷ2  | ��־λ | ��ַ��ʶ| ��ַ��8| ��ַ��8| ���ݱ�ʶ| ���ݸ�8| ���ݵ�8| ...    |  ��β1  | ��β2  | 
// +--------+--------+--------+--------+--------+--------+--------+--------+--------+--------++--------++--------+  
module uart_ctrl(
    input               sys_clk,sys_rstn,       //ϵͳʱ�ӣ���λ
    
    input [15:0]        s_uart_ctrl_addr,       // ���յ���Ƶ���ַ    
    input [15:0]        s_uart_ctrl_data,       // ���յ���Ƶ���ֵ    
    input               s_uart_ctrl_valid,      // ������Ч��־      
    output reg          s_uart_ctrl_ready,      // ���վ����ź�      
    input               s_uart_ctrl_end,        // ����֡������־     
    input [7:0]         s_uart_ctrl_extra,        // 2XSK�źű�־     
    
    output              tx                     
    );
    //�ڲ��źŹ淶
    wire                aclk = sys_clk;
    wire                rstn = sys_rstn;
    
    reg [15:0]          uart_ctrl_addr_r,uart_ctrl_data_r;
    reg [7:0]           uart_ctrl_extra_r;
    
    // ״̬������
    reg [3:0]           cur_sta;
    reg [3:0]           nex_sta;
    reg                 st_done;        //״̬��ɣ�������״̬��
    reg [1:0]           tx_ready_cnt;   //ready���͵���ʱ������
    
    //�����ֽڼ�����
    reg [3:0]           byte_cnt;       
    
    // txģ��ӿ�
    reg [7:0]           tx_data;
    reg                 tx_valid;
    wire                tx_ready;
    
    //״̬����
    localparam IDLE = 'd0;      // ����״̬     
    localparam STRAT = 'd1;     // ���Ͱ�ͷ�͵�һ������     
    localparam SEND = 'd2;      // �������ݶ�   
    localparam WAIT = 'd3;      // �ȴ�������    
    localparam END = 'd5;       // ���Ͱ�β 
    
    // Э�鳣������
    localparam HEADER_BYTE1   = 8'h28;   // ��ͷ��һ���ֽ� '('
    localparam HEADER_BYTE2   = 8'h2A;   // ��ͷ�ڶ����ֽ� '*'
    localparam ADDR_TAG       = 8'h41;   // ��ַ��ʶ�� 'A'
    localparam DATA_TAG       = 8'h44;   // ���ݱ�ʶ�� 'D'
    localparam FOOTER_BYTE1   = 8'h2A;   // ��β��һ���ֽ� '*'
    localparam FOOTER_BYTE2   = 8'h29;   // ��β�ڶ����ֽ� ')'    
    
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
            //��λ
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
                    if(tx_ready)begin   //tx����
                        tx_ready_cnt <= 'b0;// ��ʱ����������
                        if(byte_cnt == 'd9) begin   //������״̬
                            st_done <= 1'b1;
                        end
                        else begin      //ʹ���ź�һ��ʱ��
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
            WAIT : begin    //�ȴ���λ������
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
	.clk(aclk),                          // ʱ���ź�����
	.rstn(rstn),                         // ��λ�źţ��͵�ƽ��Ч��
						
	.s_tx_data(tx_data),		
	.s_tx_valid(tx_valid),
	.s_tx_ready(tx_ready),
	
	.tx(tx)
	);
endmodule
