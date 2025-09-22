`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: samp_reduce
// function: IQ Down-Conversion & Decimation
// Description: 
//   1. ����12λADC���ݣ�ͨ��DDS���ɱ����źŽ������ֻ�Ƶ
//   2. ʹ��CIC�˲������п�����˲��ͽ�����
//   3. ���48λ���ݣ�22λI· + 22λQ·��
//   4. ����UART���ýӿ�����DDSƵ�ʿ���
//   5. K = f0*(2^16)/50MHz
// ע�⣺
// 1. CIC�˲��������޸ĺ������µ������λ��
// 2. ����ź��Ѱ���4�����油��
// 3. ��������Ϊ12λ�з��������������Ϊ22λ�з���������������λ��չ��
//////////////////////////////////////////////////////////////////////////////////
module sample_reduce(
    input               sys_clk,            // ϵͳʱ�� (50MHz)              
    input               sys_rstn,           // ϵͳ��λ������Ч��         
    
    input [11:0]        s_adc_data_in,      // ADC�������ݣ�12λ�޷��ţ�  
    
    input [31:0]        s_convert_config_data,
    
    output [47:0]       m_sample_data,      // ������ݣ�48λ��22λI· + 22λQ· ��  
    output              m_sample_valid      // ���������Ч��־����������Ϊ��Ъ���壩          
    );
    wire  aclk = sys_clk;           // ������ʱ��    
    wire  aresetn = sys_rstn;       // ��λ�źţ�����Ч��
     
    
    // DDS������
    wire [31:0]         m_dds_data;              // DDS������ݣ�32λ��I/Q��12λ��     
    wire                m_dds_valid;             // DDS�����Ч��־   
    reg [3:0]           m_dds_valid_r;           // DDS��Ч�ź��ӳ���  
    
    // ��Ƶ�����
    wire [23:0]         I_mul_data;              // ��Ƶ���������     
    wire [23:0]         Q_mul_data;
    
    // CIC�˲����ӿ�                                                
    wire                I_cic_tready;            // CIC���������־   
    wire                Q_cic_tready;
    wire                I_sample_valid;         // CIC�����Ч
    wire                Q_sample_valid;
    wire [23:0]         I_sample_data;
    wire [23:0]         Q_sample_data;
    // �������ƴ�ӣ�����λ��չ�����ı����棩
    assign m_sample_data = {2'b0,I_sample_data[23],I_sample_data[20:0],2'b0,Q_sample_data[23],Q_sample_data[20:0]};
    // ������Ч�źŴ���
    assign m_sample_valid = I_sample_valid && Q_sample_valid;
    
    
    // DDS��Ч�ź��ӳٶ���    
    always @(posedge sys_clk or negedge sys_rstn)begin
        if(!sys_rstn)
            m_dds_valid_r <= 'b0;
        else 
            m_dds_valid_r <= {m_dds_valid_r[2:0],m_dds_valid};
    end
    			

    // DDS���ֱ���������
    fft_sample_down_dds m_fft_sample_down_dds (
    .aclk(aclk),                                  // input wire aclk
    .aresetn(aresetn),                            // input wire aresetn
    .s_axis_config_tvalid(1'b1),                  // input wire s_axis_config_tvalid
    .s_axis_config_tdata(s_convert_config_data),    // input wire [15 : 0] s_axis_config_tdata
    .m_axis_data_tvalid(m_dds_valid),                          // output wire m_axis_data_tvalid
    .m_axis_data_tdata(m_dds_data)         // output wire [15 : 0] m_axis_data_tdata
    );
    
    // I·��Ƶ����12λ�˷���
    fft_sample_down_mult I_fft_sample_down_mult (
    .CLK(aclk),                     // input wire CLK
    .A(m_dds_data[11:0]),      // input wire [11 : 0] A
    .B(s_adc_data_in),              // input wire [11 : 0] B
    .P(I_mul_data)                           // output wire [23 : 0] P
    );
    
    // Q·��Ƶ����12λ�˷���
    fft_sample_down_mult Q_fft_sample_down_mult (
    .CLK(aclk),                     // input wire CLK
    .A(m_dds_data[27:16]),          // input wire [11 : 0] A
    .B(s_adc_data_in),              // input wire [11 : 0] B
    .P(Q_mul_data)                           // output wire [23 : 0] P
    );
    
    
    //ÿ�ε���CIC����Ҫ�����������λ������
    // I·CIC�˲���
    fft_sample_down_cic I_fft_sample_down_cic (
    .aclk(aclk),                              // input wire aclk
    .aresetn(aresetn),                        // input wire aresetn
    .s_axis_data_tdata(I_mul_data),    // input wire [23 : 0] s_axis_data_tdata
    .s_axis_data_tvalid(m_dds_valid_r[3]&&I_cic_tready),        // input wire s_axis_data_tvalid
    .s_axis_data_tready(I_cic_tready),      // output wire s_axis_data_tready
    .m_axis_data_tdata(I_sample_data),    // output wire [23 : 0] m_axis_data_tdata
    .m_axis_data_tvalid(I_sample_valid)  // output wire m_axis_data_tvalid
    );
    
    // Q·CIC�˲���
    fft_sample_down_cic Q_fft_sample_down_cic (
    .aclk(aclk),                              // input wire aclk
    .aresetn(aresetn),                        // input wire aresetn
    .s_axis_data_tdata(Q_mul_data),    // input wire [23 : 0] s_axis_data_tdata
    .s_axis_data_tvalid(m_dds_valid_r[3]&&Q_cic_tready),        // input wire s_axis_data_tvalid
    .s_axis_data_tready(Q_cic_tready),      // output wire s_axis_data_tready
    .m_axis_data_tdata(Q_sample_data),    // output wire [23 : 0] m_axis_data_tdata
    .m_axis_data_tvalid(Q_sample_valid)  // output wire m_axis_data_tvalid
    );
endmodule
