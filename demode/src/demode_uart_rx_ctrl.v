`timescale 1ns / 1ps
// UART���ݰ���װ����ģ��
// 1. ����״̬������byte_cnt���Ͷ��ֽ�
// 2. ��ʱ����������Ϊs_uart_ctrl_valid�ǵ��������壬
//      s_uart_ctrl_ready�������ֻ������ģ�������ʱ������ִ��
// ���ݰ���ʽʾ����
// +--------+--------+--------+--------+--------+--------+--------+--------++--------++--------+ 
// | 0x28   | 0x2A   | type   | modu   | freq1  | freq2  | freq3  | freq4   | 0x2A   | 0x29   | 
// +--------+--------+--------+--------+--------+--------+--------+--------++--------++--------+ 
// | ��ͷ1  | ��ͷ2  |�ź����|������Ϣ |Ƶ��1   |Ƶ��2   | Ƶ��3  | Ƶ��4  |  ��β1  | ��β2   |
// +--------+--------+--------+--------+--------+--------+--------+--------++--------++--------+ 
module demode_uart_rx_ctrl(
    input               sys_clk,
    input               sys_rstn,               //ϵͳʱ�ӣ���λ
    
    output reg [31:0]   m_uart_freq,       // �����ź��ز�Ƶ��    
    (* mark_debug = "true" *)output reg [7:0]    m_uart_type,       // �����ź����
    (* mark_debug = "true" *)output reg [7:0]    m_uart_modu,       // ���ܵ����źŵ��ƶȣ�����Ƶ��ָ��
    (* mark_debug = "true" *)output reg          m_uart_valid,      // ������Ч��־           
   
    input              rx                     
    );
    //�ڲ��źŹ淶
    wire                aclk = sys_clk;
    wire                rstn = sys_rstn;
    
    reg [15:0]          uart_ctrl_addr_r,uart_ctrl_data_r;
    reg                 uart_ctrl_xsk_r;
    
    // ״̬������
    reg [3:0]           cur_sta;
    reg [3:0]           nex_sta;
    reg                 uart_error;
    reg                 byte_done;  //״̬��ɣ�rx_data�����Ѳɼ���
    reg                 packet_done;
    
    //���ݽӿ�
    reg [3:0]           byte_cnt;   //�������ݼ����� 
    reg [3:0]           head_cnt;
    reg [3:0]           foot_cnt;   //
    reg [7:0]           data_reg[5:0];   
    
    // txģ��ӿ�
    wire [7:0]           rx_data;
    wire                 rx_busy;
    
    //״̬����
    localparam IDLE = 'd0;      // ����״̬     
    localparam HEAD = 'd1;      // ��ͷ����
    localparam WAIT = 'd2;      // �ȴ�������        
    localparam RECE = 'd3;      // �������ݶ�   
    localparam FOOT = 'd4;      // ��β����
    
    // Э�鳣������
    localparam HEADER_BYTE1   = 8'h28;   // ��ͷ��һ���ֽ� '('
    localparam HEADER_BYTE2   = 8'h2A;   // ��ͷ�ڶ����ֽ� '*'
    localparam FOOTER_BYTE1   = 8'h2A;   // ��β��һ���ֽ� '*'
    localparam FOOTER_BYTE2   = 8'h29;   // ��β�ڶ����ֽ� ')'    
    
    always @(posedge aclk or negedge rstn) begin
        if(!rstn)m_uart_valid <= 'b0;
        else if(cur_sta == IDLE) m_uart_valid <= 1'b1;
        else m_uart_valid <= 'b0;
    end
    
    always @(posedge aclk or negedge rstn) begin
        if(!rstn)cur_sta <= IDLE;
        else cur_sta <= nex_sta;
    end
    
    always @(*) begin
        case(cur_sta)
            IDLE : begin
                if(rx_busy)nex_sta = WAIT;
                else nex_sta = IDLE;
            end 
            WAIT : begin
                if(uart_error)nex_sta = IDLE;
                else begin
                    if(!rx_busy)begin
                        if(head_cnt < 'd2)nex_sta = HEAD;
                        else if(byte_cnt < 'd6)nex_sta = RECE;
                        else if(foot_cnt < 'd2)nex_sta = FOOT;
                        else nex_sta = IDLE;    //debug��ʱ��ע�⣡����
                    end else nex_sta = WAIT;
                end
            end
            HEAD : begin
                if(uart_error)nex_sta = IDLE;
                else begin
                    if(rx_busy)nex_sta = WAIT;
                    else nex_sta = HEAD;
                end
            end 
            RECE : begin
                if(uart_error)nex_sta = IDLE;
                else begin
                    if(rx_busy)nex_sta = WAIT;
                    else nex_sta = RECE;
                end
            end
            FOOT : begin
                if(uart_error)nex_sta = IDLE;
                else if(packet_done)nex_sta = IDLE;
                else begin
                    if(rx_busy)nex_sta = WAIT;
                    else nex_sta = FOOT;
                end
            end
        endcase
    end
    
    always @(posedge aclk or negedge rstn) begin
        if(!rstn) begin
            m_uart_freq <= 'b0;
            m_uart_type <= 'b0;
            m_uart_modu <= 'b0;
            byte_cnt <= 'b0;
            head_cnt <= 'b0;
            foot_cnt <= 'b0;
            uart_error <= 'b0;
            byte_done <= 'b0;
            packet_done <= 'b0; 
            data_reg[0] <= 'b0;
            data_reg[1] <= 'b0;
            data_reg[2] <= 'b0;
            data_reg[3] <= 'b0;
            data_reg[4] <= 'b0;
        end else begin
            case(cur_sta)
            IDLE : begin
                byte_cnt <= 'b0;
                head_cnt <= 'b0;
                foot_cnt <= 'b0;
                uart_error <= 'b0;
                byte_done <= 'b0; 
                packet_done <= 'b0;
                data_reg[0] <= 'b0;
                data_reg[1] <= 'b0;
                data_reg[2] <= 'b0;
                data_reg[3] <= 'b0;
                data_reg[4] <= 'b0;
            end 
            WAIT : begin
                byte_done <= 'b0;
            end
            HEAD : begin
                if(!byte_done)begin
                    byte_done <= 1'b1;
                    head_cnt <= head_cnt + 1'b1;
                    case(head_cnt)
                        'd0 : if(rx_data != HEADER_BYTE1)uart_error <= 1'b1;
                        'd1 : if(rx_data != HEADER_BYTE2)uart_error <= 1'b1;
                    endcase  
                end  
            end 
            RECE : begin
                if(!byte_done)begin
                    byte_done <= 1'b1;
                    byte_cnt <= byte_cnt + 1'b1;
                    data_reg[byte_cnt] <= rx_data;  
                end
            end
            FOOT : begin
                if(!byte_done)begin
                    byte_done <= 1'b1;
                    foot_cnt <= foot_cnt + 1'b1;
                    case(foot_cnt)
                        'd0 : if(rx_data != FOOTER_BYTE1)uart_error <= 1'b1;
                        'd1 : begin
                            if(rx_data != FOOTER_BYTE2)uart_error <= 1'b1;
                            else begin
                                packet_done <= 1'b1;
                                m_uart_type <= data_reg[0];
                                m_uart_modu <= data_reg[1];
                                m_uart_freq <= {data_reg[2],data_reg[3],data_reg[4],data_reg[5]};
                            end
                        end
                    endcase  
                end
            end
            endcase
        end
    end
    
    uart_rx m_uart_rx (                                     
	.clk(aclk),                          // ʱ���ź�����
	.rstn(rstn),                         // ��λ�źţ��͵�ƽ��Ч��
						
	.m_rx_data(rx_data),		
	.m_rx_busy(rx_busy),
	
	.rx(rx)
	);
endmodule

