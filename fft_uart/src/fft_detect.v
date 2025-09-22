`timescale 1ns / 1ps
// ��ȡRAM�е�FFT����ʵ��ɨƵ,��ȡ����������ģ��
// 1. RAM_TRAV״̬��ɨƵ����Ҫ������ͬ���ж��㷨
//      ��1��С��ֵ��ʱ��������ʱ�����С��ֵ��������ֵ�����о��Ƿ�Ϊ2XSK�ź�
//      ��2�������ݴ���С��ֵʱ����С��ֵ�������������ף�
//      ��3�������ݴ��ڴ���ֵʱ���´���ֵ�������Ͷ�Ӧ���ݼĴ�������ɢ�ף�                 
// 2. UART_SEND״̬��Ҫ��������s_uart_ctrl_readyΪ1ʱ��
//      ���͵�ǰ��ɢ�����ݺͶ�ӦƵ��m_uart_ctrl_addr/data��
//      s_uart_ctrl_validֻ����1һ��ʱ������
// 3. ready_cnt��ʱ����������Ϊs_uart_ctrl_valid�ǵ��������壬     
//      s_uart_ctrl_ready�������ֻ������ģ�������ʱ������ִ��   
module fft_detect(
    input               sys_clk,sys_rstn,
    
    // RAM�ӿ�
    output reg[12:0]    s_ram_addr,     // RAM��ȡ��ַ
    input [15:0]        s_ram_data,     // RAM�������
    
    // FFT���ƽӿ�
    output reg          fft_ctrl,       // FFT�������ƣ�������ʱ��FFT���������źţ�  
    input               fft_flag,       // FFT���б�־����Ϊ���д��RAM����Ϊ������  
    
    //�»�Ƶ�����ӿ�
    output              m_sta_ram_trav,     // fft_detect��RAM_TRAV�ı�־λ               
    input [6:0]         s_convert_config_step,// �»�Ƶ��Ƶ�ʲ���������ӦƵ��ת����costas_fft��          
    
    // uart_ctrl���ƽӿ�
    output reg [15:0]   m_uart_ctrl_addr,       // �ϱ�Ƶ���ַ   
    output reg [15:0]   m_uart_ctrl_data,       // �ϱ�Ƶ���ֵ   
    output reg          m_uart_ctrl_valid,      // ������Ч��־   
    input               m_uart_ctrl_ready,      // ��λ�����վ���  
    output reg [7:0]    m_uart_ctrl_extra,      // �������ݣ�[7:1]���»�Ƶ��Ϣ [0]��XSK��Ϣ
    output reg          m_uart_ctrl_end         // ����֡���������־ 
    ); 
    //��������   
    localparam REGISTERS_LENGTH = 'd50; //��ɢ�׼Ĵ�������
    localparam SMALL_THRESHOILD = 'd30; //С��ֵ���������������޸�,���XSK�źŵ�������
    localparam SMALL_THRES_NUMS = 'd20; //64���ź��г��ִ���С��ֵ������
    localparam LARGE_THRESHOILD = 'd150; //����ֵ������ǰ���ź������޸ģ������ɢ��
    
    //״̬����
    localparam FFT_IDLE = 'd0;      // ����״̬����ʱFFT����      
    localparam FFT_WAIT = 'd1;      // �ȴ�FFTд��RAM   
    localparam RAM_TRAV = 'd2;      // RAMɨ�����   
    localparam UART_SEND = 'd3;     // UART����֡����  
    
    //�ڲ��źŹ淶
    wire                aclk = sys_clk;
    wire                rstn = sys_rstn;
    
    //״̬�������ź�
    reg [3:0]           nex_sta;
    reg [3:0]           cur_sta;
    reg [1:0]           ready_cnt;      //ready���͵���ʱ������
    
    // �����׷���������
    reg [5:0]           time_cnt;           //64ʱ�Ӽ�����
    reg [5:0]           small_thres_cnt;    //С��ֵ��������64ʱ�����ã�
    
    // ��ɢ�״洢������ֵ��
    reg [15:0]          large_data_reg [REGISTERS_LENGTH-1:0];  // ��ɢ�׷�ֵ�洢   
    reg [15:0]          large_addr_reg [REGISTERS_LENGTH-1:0];  // ��ɢ�׵�ַ�洢   
    reg [7:0]           large_reg_cnt;                          // ��Ч��ɢ�׼���   
    
    // uart_ctrl���ͼ�����
    reg [7:0]           uart_data_cnt;                              
    
    assign m_sta_ram_trav = (cur_sta == RAM_TRAV) ? 1'b1 : 1'b0;
    
    //״̬����һ��
    always @(posedge aclk or negedge rstn) begin
        if(!rstn)cur_sta <= 'b0;
        else cur_sta <= nex_sta;
    end
    
    //״̬���ڶ���
    always @(*) begin
        case(cur_sta)
            FFT_IDLE : begin    
                if(fft_flag) nex_sta = FFT_WAIT;
                else nex_sta = FFT_IDLE;
            end
            FFT_WAIT : begin
                if(!fft_flag) nex_sta = RAM_TRAV;
                else nex_sta = FFT_WAIT;
            end
            RAM_TRAV : begin
                if(s_ram_addr == 'h1fff) nex_sta = UART_SEND;
                //��ɢ�׼������ڼĴ������ޣ������źŹ��࣬������֡���ݣ�����fft
                else if(large_reg_cnt == REGISTERS_LENGTH) nex_sta = FFT_IDLE;
                else nex_sta = RAM_TRAV;
            end
            UART_SEND : begin
                if(uart_data_cnt == large_reg_cnt) nex_sta = FFT_IDLE;
                else nex_sta = UART_SEND;
            end
        endcase
    end
    
    //״̬��������
    always @(posedge aclk or negedge rstn) begin
        if(!rstn) begin 
            fft_ctrl <= 1'b0;
            m_uart_ctrl_addr <= 'b0;
            m_uart_ctrl_data <= 'b0;         
            m_uart_ctrl_valid <= 1'b0;
            m_uart_ctrl_extra <= 'b0;  
            
            s_ram_addr <= 'b0;   
            m_uart_ctrl_end <= 'b0;      
            time_cnt <= 'b0;           
            small_thres_cnt <= 'b0;    
            large_reg_cnt <= 'b0;      
            uart_data_cnt <= 'b0; 
            ready_cnt <= 'b0;         
        end else begin
            fft_ctrl <= 1'b0;
            m_uart_ctrl_valid <= 1'b0;
            case(cur_sta)
                FFT_IDLE : begin
                    // ����FFT����
                    fft_ctrl <= 1'b1; 
                    m_uart_ctrl_end <= 1'b1;      
                end
                FFT_WAIT : begin
                    //ĳЩ�����ĳ�ʼ��
                    s_ram_addr <= 'b0;
                    time_cnt <= 'b0;
                    small_thres_cnt <= 'b0;
                    m_uart_ctrl_extra <= 'b0; 
                    m_uart_ctrl_end <= 'b0;
                    large_reg_cnt <= 'b0;
                    uart_data_cnt <= 'b0;
                    ready_cnt <= 'b0;
                end
                RAM_TRAV : begin
                    s_ram_addr <= s_ram_addr + 1'b1;  
                    time_cnt <= time_cnt + 1'b1;
                    m_uart_ctrl_extra[7:1] <= s_convert_config_step;
                    if(time_cnt == 6'h3f)begin    //time_cnt������Ϊ63ʱ������small_thres_cntС��ֵ����
                        small_thres_cnt <= 'b0;                 //���������ź�Ϊ2XSK�ź�
                        if(small_thres_cnt > SMALL_THRES_NUMS)
                            m_uart_ctrl_extra[0] <= 1'b1;
                    end
                    if(s_ram_data > SMALL_THRESHOILD)       //����С��ֵ��small_thres_cnt��һ
                        small_thres_cnt <= small_thres_cnt + 1'b1; 
                    if(s_ram_data > LARGE_THRESHOILD&&s_ram_addr >= 'd3)begin  //���ڴ���ֵ����ɢ�״洢����
                        large_data_reg[large_reg_cnt] <= s_ram_data;
                        large_addr_reg[large_reg_cnt] <= {3'b0,s_ram_addr};
                        large_reg_cnt <= large_reg_cnt + 1'b1;
                    end             
                end
                UART_SEND : begin
                    if(ready_cnt == 2'b11)begin
                        if(m_uart_ctrl_ready)begin  //uart_ctrl����
                            ready_cnt <= 'b0;       // ��ʱ����������        
                            if(uart_data_cnt == large_reg_cnt)begin
                                m_uart_ctrl_end <= 1'b1;
                            end else begin
                                m_uart_ctrl_valid <= 1'b1;      //����һ��ʱ�ӵ�ʹ�ܺ�����
                                m_uart_ctrl_data <= large_data_reg[uart_data_cnt];
                                m_uart_ctrl_addr <= large_addr_reg[uart_data_cnt];
                                uart_data_cnt <= uart_data_cnt + 1'b1;
                            end
                        end
                    end else ready_cnt <= ready_cnt + 1;
                end 
            endcase
        end
    end

    
endmodule

