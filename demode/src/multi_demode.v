`timescale 1ns / 1ps

module multi_demode(
    input                   sys_clk,        // ϵͳʱ�ӣ�50MHz�� 
    input                   sys_rstn,       // ϵͳ��λ������Ч��
    
    input [15:0]            demode_data_in,
    
    (* mark_debug = "true" *)output reg [13:0]       demode_data_out,
    
    input                   rx
    );
    localparam SHIFT_NUM_INIT = 'd0;
    
    localparam NOTHING  = 'd0;
    localparam WAVE_AM  = 'd1;
    localparam WAVE_ASK = 'd2;
    localparam WAVE_FM  = 'd3;
    localparam WAVE_FSK = 'd4;
    localparam WAVE_PSK = 'd5;
    
    localparam ASK_UP_THRE  = 'd100;
    localparam ASK_LOW_THRE = 'd100;
    localparam FSK_UP_THRE  = 'd0; 
    localparam FSK_LOW_THRE = -'d100;
    localparam PSK_UP_THRE  = 'd50; 
    localparam PSK_LOW_THRE = 'd100;
    
    //�ڲ��źŹ淶
    wire                aclk = sys_clk;
    wire                rstn = sys_rstn;
    
    // uart_rx_ctr�ӿ�
    wire [31:0]         m_uart_freq;        //uart���ܵ��ز���Ϣ��Ƶ�ʿ����֣�
    wire [7:0]          m_uart_type;        //uart���ܵ��ź�����
    wire [7:0]          m_uart_modu;        //uart���ܵ��ź���Ϣ�����ƶȻ���Ƶ����ָ����
    wire                m_uart_valid;       //uart���ܵ��ź���Ч
    
    // iq����ӿ�
    reg [31:0]          iq_phase_increment;
    reg                 iq_phase_increment_valid;
    wire [15:0]         phase,magni;
    wire                iq_demode_valid_out;
    
    // ר�ý���󼶽ӿ�
    reg                 fm_en;    //fm��λ���ģ��ʹ��
         //��FM,FSKʱ��Ч
    reg                 am_en;    //am��λ���ģ��ʹ��                                   
         //��AM,ASKʱ��Ч 
    reg                 pm_en;    //pm��˹�ػ�ģ��ʹ��                                   
         //��PSKʱ��Ч                               
    reg [3:0]           shift_num;
    reg [13:0]          up_judge_thre,low_judge_thre;
    
    wire [13:0]         am_demode_out;  
    wire [13:0]         ask_demode_out; 
    wire [13:0]         fm_demode_out;  
    wire [13:0]         fsk_demode_out; 
    wire [13:0]         psk_demode_out; 
    
    always @(posedge aclk or negedge rstn) begin
        if (!rstn) begin
            demode_data_out <= 'b0;
        end else begin
            if(m_uart_valid)
                case(m_uart_type)
                WAVE_AM  : demode_data_out <= am_demode_out;
                WAVE_ASK : demode_data_out <= ask_demode_out;
                WAVE_FM  : demode_data_out <= fm_demode_out;
                WAVE_FSK : demode_data_out <= fsk_demode_out;
                WAVE_PSK : demode_data_out <= psk_demode_out;
                default  : demode_data_out <= 'b0;
                endcase  
            else  demode_data_out <= 'b0;
        end
    end                              
                                  
    always @(posedge aclk or negedge rstn) begin
        if (!rstn) begin
            iq_phase_increment_valid <= 'b0;
            iq_phase_increment <= 'b0;
            fm_en <= 'b0;
            am_en <= 'b0;
            pm_en <= 'b0;
            shift_num <= 'b0;
            up_judge_thre <= 'b0;
            low_judge_thre <= 'b0;
        end else begin
            if(m_uart_valid)begin
                iq_phase_increment_valid <= 1'b1;
                iq_phase_increment <= m_uart_freq;
                shift_num <= SHIFT_NUM_INIT + m_uart_modu[7:4] + m_uart_modu[3:0];
                case(m_uart_type)
                WAVE_AM : begin
                    fm_en <= 1'b0;
                    am_en <= 1'b1;
                    pm_en <= 1'b0;
                    up_judge_thre <= 'b0; 
                    low_judge_thre <= 'b0;
                end
                WAVE_ASK : begin
                    fm_en <= 1'b0;
                    am_en <= 1'b1;
                    pm_en <= 1'b0;
                    up_judge_thre <= ASK_UP_THRE; 
                    low_judge_thre <= ASK_LOW_THRE;
                end
                WAVE_FM : begin
                    fm_en <= 1'b1;
                    am_en <= 1'b0;
                    pm_en <= 1'b0;
                    up_judge_thre <= 'b0; 
                    low_judge_thre <= 'b0;
                end
                WAVE_FSK : begin
                    fm_en <= 1'b1;
                    am_en <= 1'b0;
                    pm_en <= 1'b0;
                    up_judge_thre <= FSK_UP_THRE; 
                    low_judge_thre <= FSK_LOW_THRE;
                end
                WAVE_PSK : begin
                    fm_en <= 1'b0;
                    am_en <= 1'b0;
                    pm_en <= 1'b1;
                    up_judge_thre <= PSK_UP_THRE; 
                    low_judge_thre <= PSK_LOW_THRE;
                end
                default : begin
                    fm_en <= 1'b0;
                    am_en <= 1'b0;
                    pm_en <= 1'b0;
                    up_judge_thre <= 'b0; 
                    low_judge_thre <= 'b0;
                end
                endcase
            end 
        end
    end
    
    demode_uart_rx_ctrl m_demode_uart_rx_ctrl(
    .sys_clk(sys_clk),
    .sys_rstn(sys_rstn),               //ϵͳʱ�ӣ���λ
    .m_uart_freq(m_uart_freq),       // �����ź��ز�Ƶ��    
    .m_uart_type(m_uart_type),       // �����ź����
    .m_uart_modu(m_uart_modu),       // ���ܵ����źŵ��ƶȣ�����Ƶ��ָ��
    .m_uart_valid(m_uart_valid),      // ������Ч��־           
    .rx(rx)                     
    );
    
    iq_demod_top m_iq_demod_top (
    .sys_clk  (sys_clk),
    .sys_rstn (sys_rstn),
    .data_in  (demode_data_in),
    .cw_phase_increment(iq_phase_increment),      
    .cw_phase_increment_valid(iq_phase_increment_valid),
    .magni    (magni),
    .phase    (phase),
    .valid    (iq_demode_valid_out)
    );
    
    am_demode m_am_demode(
    .sys_clk(sys_clk),             // ϵͳʱ�ӣ�50MHz�� 
    .sys_rstn(sys_rstn),            // ϵͳ��λ������Ч��
    .am_en(am_en),
    
    .magni(magni),              // IQģ��������      
    .demode_out(am_demode_out)                 
    );
    
    fm_demode m_fm_demode(
    .sys_clk(sys_clk),             // ϵͳʱ�ӣ�50MHz�� 
    .sys_rstn(sys_rstn),            // ϵͳ��λ������Ч��
    .fm_en(fm_en),
    
    .phase(phase),              // IQ��λ������
    .shift_num(shift_num),       
   
    .demode_out(fm_demode_out)                 
    );
    
    judge_demode m_am_judge_demode(
    .sys_clk(sys_clk),        // ϵͳʱ�ӣ�50MHz�� 
    .sys_rstn(sys_rstn),       // ϵͳ��λ������Ч��
    
    .data_in(am_demode_out),
    .judge_en(am_en),
    
    .up_judge_thre(up_judge_thre),
    .low_judge_thre(low_judge_thre),
    
    .data_out(ask_demode_out)
    );
    
    judge_demode m_fm_judge_demode(
    .sys_clk(sys_clk),        // ϵͳʱ�ӣ�50MHz�� 
    .sys_rstn(sys_rstn),       // ϵͳ��λ������Ч��
    
    .data_in(fm_demode_out),
    .judge_en(fm_en),
    
    .up_judge_thre(up_judge_thre),
    .low_judge_thre(low_judge_thre),
    
    .data_out(fsk_demode_out)
    );
    
endmodule
