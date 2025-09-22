`timescale 1ns / 1ps
module convert_sync(
    input               sys_clk,
    input               sys_rstn,
    
    input [15:0]        convert_freq_data,  //���ź�Ƶ�ʶ�Ӧ��ַ       
    input               convert_freq_valid,                  
    
    input               s_sta_ram_trav,         // fft_detect��RAM_TRAV�ı�־λ
    
    output reg[31:0]    m_convert_config_data,  //�»�Ƶ��Ƶ�ʿ�����
    output reg[6:0]     m_convert_config_step     //�»�Ƶ��Ƶ�ʲ���           
    );
    
    //������������Ƶ�ʿ����֣�����
    localparam FREQ_OFFST = 'd0;            //��ʼƵ�ʿ�����ƫ��    
    //(0.25MHz)                  
    localparam FREQ_RESOL = 'd21_474_836;   //Ƶ�ʿ����ֱַ���
    //���㹫ʽ��K = f0*(2^32)/50MHz = addr*(2^22)
    localparam FREQ_COEFF = 'd22;            //Ƶ�ʿ�����ת��λ��ϵ��
    
    wire aclk = sys_clk;                    //Ԥ��ʱ���޸����
    wire rstn = sys_rstn;
    
    //��һ��ӿ�
    reg[31:0]           m_dds_config_data_reg;     // Ƶ�ʿ������ݴ�Ĵ���
    reg[6:0]            m_dds_freq_step_reg;       // Ƶ�ʲ������ݴ�Ĵ���
    
    localparam IDLE = 'd0;                // ����״̬               
    localparam CALC = 'd1;                // ����״̬ 
    //�ڶ���״̬�������ź�
    reg [3:0]           nex_sta;
    reg [3:0]           cur_sta;
    
    //�ڶ���ӿ�
    reg [31:0]          freq_reg;                   //Ƶ�ʼĴ���
    reg [31:0]          freq_compare_reg;           //�ȽϼĴ���
    reg [6:0]           freq_step_reg;              
    
    //���㵥Ԫ��ѭ����JK���������߼���
    //s_sta_ram_travΪ0��һ��������s_sta_ram_travΪ1�ڶ�������
    //��һ�㸳ֵ��Ԫ����s_sta_ram_travʱ��output���ݼ�����
    always @(posedge sys_clk or negedge sys_rstn)begin
        if(!sys_rstn)begin
            m_convert_config_data <= 'b0;
            m_convert_config_step <= 'b0;
        end else if(s_sta_ram_trav) begin
            m_convert_config_data <= m_dds_config_data_reg;
            m_convert_config_step <= m_dds_freq_step_reg;
        end else begin
            m_convert_config_data <= m_convert_config_data;
            m_convert_config_step <= m_convert_config_step;
        end  
    end
    
    //�ڶ�����㵥Ԫ���ڣ�s_sta_ram_trav�����������һ�㴫�ݼ�����
    //״̬����һ��
    always @(posedge aclk or negedge rstn) begin
        if(!rstn)cur_sta <= 'b0;
        else cur_sta <= nex_sta;
    end
    
    //״̬���ڶ���
    always @(*) begin
        case(cur_sta)
            IDLE : begin    
                if(!s_sta_ram_trav&&convert_freq_valid) nex_sta = CALC;
                else nex_sta = IDLE;
            end
            CALC : begin
                if(s_sta_ram_trav || freq_compare_reg > freq_reg) nex_sta = IDLE;
                else nex_sta = CALC;
            end
        endcase
    end
    
    always @(posedge sys_clk or negedge sys_rstn)begin
        if(!sys_rstn)begin
            freq_reg <= 'b0;
            freq_compare_reg <= 'b0;
            freq_step_reg <= 'b0;
            m_dds_config_data_reg <= 'b0;
            m_dds_freq_step_reg <= 'b0;
        end else begin
            case(cur_sta)
                IDLE : begin
                    if(!s_sta_ram_trav&&convert_freq_valid)begin
                        // ����Ŀ��Ƶ�ʿ����֣���ֵַ����22λ����ַ>=3ʱ��ȥ3��ƫ�ƣ�
                        if(convert_freq_data >= 3)
                            freq_reg <= (convert_freq_data - 3) << FREQ_COEFF;
                        else  freq_reg <= convert_freq_data << FREQ_COEFF;
                    end
                    //��λ�Ĵ���
                    freq_compare_reg <= FREQ_OFFST;    
                    freq_step_reg <= 'd0;        
                end 
                CALC : begin
                    if(!s_sta_ram_trav && freq_compare_reg > freq_reg) begin
                        // ���������Ƶ��С����󲽽�Ƶ�ʿ�����
                        m_dds_config_data_reg <= freq_compare_reg - (FREQ_RESOL<<1);
                        m_dds_freq_step_reg <= freq_step_reg - 'd2;
                    end else begin
                        // ������Ƶ��ֱ������Ŀ��ֵ
                        freq_compare_reg <= freq_compare_reg + FREQ_RESOL;
                        freq_step_reg <= freq_step_reg + 'd1;
                    end
                end
            endcase
        end    
    end
endmodule
    