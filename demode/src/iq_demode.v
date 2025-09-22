//=============================================================
// Module: iq_demod_top
// Function: IQ�������ģ�飬ʵ���źŻ�Ƶ��������ת������λ����
//����16λ�з�����������
//���20λ�޷��ŷ��Ǻ��з�����λ
//=============================================================
module iq_demod_top(
    input                   sys_clk,        // ϵͳʱ�ӣ�50MHz�� 
    input                   sys_rstn,       // ϵͳ��λ������Ч��
       
    input [15:0]            data_in,        // ADC�������ݣ�I·��
    
    //�ز�Ƶ�ʿ��ƽӿ�
    input [31:0]            cw_phase_increment,         //�ز�Ƶ�ʿ�����(32λ�޷������֣�
    input                   cw_phase_increment_valid,   //�ز�Ƶ�ʿ�����_��Чλ 
    // ����Ƶ�ʿ����֣�ʱ��Ϊ50Mhz�����㹫ʽ��K = f0*(2^32)/50MHz��      
    
    output [15:0]           magni,phase,    // ��������λ�������    
    output                  valid           // ������Ч��־       
    );
    wire aclk = sys_clk;                    //Ԥ��ʱ���޸����
    wire rstn = sys_rstn;
    
    //dds���
    wire            dds_valid;      // DDS������Ч��־
    wire [15:0]     cos_data;       // DDS��������Һ������ź�         
    wire [15:0]     sin_data;
    
    //��Ƶ�����
    wire [31:0]     I_data;         // I·��Ƶ���
    wire [31:0]     Q_data;         // Q·��Ƶ���
    
    //�˲������ݽӿ�
    wire            s_axis_Idata_tready;
    wire            s_axis_Qfir_tready;
    wire            I_filtered_valid;   // I·�˲�������Ч��־
    wire            Q_filtered_valid;   // Q·�˲�������Ч��־  
    wire [31:0]     I_filtered;         // �˲����I·���� 
    wire [31:0]     Q_filtered;         // �˲����Q·���� 
    
    wire [31:0]     codic_data;         // CORDIC������ݣ���16λ��λ����16λ���ȣ�         
    wire            codic_data_valid;   // CORDIC������Ч��־
    
    assign phase = codic_data[31:16];
    assign magni = codic_data[15:0];
    assign valid = codic_data_valid;
    
    iq_demode_dds cw_complier (
    .aclk(aclk),                              // input wire aclk
    .aresetn(rstn),
    .m_axis_data_tvalid(dds_valid),  // output wire m_axis_data_tvalid
    .m_axis_data_tdata({cos_data,sin_data}),    // output wire [31 : 0] m_axis_data_tdata
    .s_axis_config_tvalid(cw_phase_increment_valid),  // input wire s_axis_config_tvalid
    .s_axis_config_tdata(cw_phase_increment [31:0])    // input wire [31 : 0] s_axis_config_tdata
    );
    
    iq_demode_mult_0 I_mult (
    .CLK(aclk),                 // ʱ������   
    .A(cos_data),               // DDS�����ź�
    .B(data_in),                // ADC��������
    .CE(rstn),                  // ʹ���ź�    
    .P(I_data)                  // I·�˻���� 
    );
    
    iq_demode_mult_0 Q_mult (
    .CLK(aclk),                 // ʱ������    
    .A(sin_data),               // DDS�����ź� 
    .B(data_in),                // ADC�������� 
    .CE(rstn),                 // ʹ���ź�    
    .P(Q_data)                  // I·�˻����  
    );
    
   
    iq_demode_fir_0 I_fir_compiler (
    .aclk(aclk),                            // ʱ������              
    .aresetn(rstn),                         // ��λ������Ч��           
    .s_axis_data_tvalid(s_axis_Ifir_tready&&s_axis_Qfir_tready),              // ����������Ч��ʼ����Ч��     
    .s_axis_data_tready(s_axis_Ifir_tready),
    .s_axis_data_tdata(I_data),             // ����I·����             
    .m_axis_data_tvalid(I_filtered_valid),  // ���������Ч          
    .m_axis_data_tdata(I_filtered)          // �˲����I·����          
    );                                                
    
    iq_demode_fir_0 Q_fir_compiler (
    .aclk(aclk),                              // ʱ������                       
    .aresetn(rstn),                         // ��λ������Ч��              
    .s_axis_data_tvalid(s_axis_Ifir_tready&&s_axis_Qfir_tready),                // ����������Ч��ʼ����Ч��                           
    .s_axis_data_tready(s_axis_Qfir_tready),
    .s_axis_data_tdata(Q_data),               // ����Q·����               
    .m_axis_data_tvalid(Q_filtered_valid),    // ���������Ч               
    .m_axis_data_tdata(Q_filtered)            // �˲����Q·����             
    );
    
    iq_demode_cordic_0 codic (
    .aclk(aclk),                                                    // ʱ������                   
    .aresetn(rstn),                                                 // ��λ������Ч��                
    .s_axis_cartesian_tvalid(1),   // ������Ч��I/Q·ͬʱ��Ч��            
    .s_axis_cartesian_tdata({I_filtered,Q_filtered}),               // �������ݣ�I·��16λ��Q·��16λ��       
    .m_axis_dout_tvalid(codic_data_valid),                          // ���������Ч                    
    .m_axis_dout_tdata(codic_data)                                  // ������ݣ���λ��16λ�����ȵ�16λ��       
    );
    
    
endmodule


