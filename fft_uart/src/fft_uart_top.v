`timescale 1ns / 1ps
//PA10��RX��PA9:TX
//�򵥵Ķ����װ
// (* mark_debug = "true" *)
// ��Ҫ������ȷ�ϵĲ�����
//  1.fft_convert��С����FFTȷ���ź�Ƶ�������пɱ��»�Ƶ�����32Ƶ�ʿ����֣�
//    1��convert_detect��ɨƵȷ���ź���ЧƵ����㣩
// ���� LARGE_THRESHOILD����Ҫ���ж��ź�Ƶ����㣩
//    2��convert_sync������ģ�飬ֻ����ĳ������״̬�����»�ƵƵ�ʣ����ģ����ע�ͣ�  
//      FREQ_OFFST����ʼƵ�ʣ�����ѡ��ΪƵ�����ޣ�
// ���� FREQ_RESOL���»�Ƶ��Ƶ�ʲ�������
//      FREQ_COEFF�����õ�����FFT������Ƶ�ʿ�����λ�������
//  2.sample_reduce���»�Ƶ��CIC��������     
// ����1��fft_sample_down_cic��Ӧ������Ϊ5������2�ӳ٣�12��ȡ��
//      ��CIC��Ӧ�ı��Ҫ��STM32���²�����  
//  3.wave_detect��������FFT���ݴ棬ɨƵ��UART���ݰ��������ģ�飩
//    1��fft_detect����С��ֵ��������ɢ��������ɨƵ���ͣ�    
//      REGISTERS_LENGTH����ɢ�׼Ĵ���������ҪSTM32ͬ���ģ�
//      SMALL_THRESHOILD��С��ֵ��ע��������ȡ�����е㣬����û���ˣ�
//      SMALL_THRES_NUMS��С��ֵ��������64�д��ڸ�ֵ�����������ף�
// ���� LARGE_THRESHOILD������ֵ������ǰ���ź������޸ģ������ɢ�ף�
//  
//
//
//
// 1.CIC�ĳ�ȡ����Ϊ12���޸ļǵø���ע�ͺ�32�˲���ϵ����
// 2.default�»�ƵƵ��Ϊ1MHz
// 3.ɨƵģ�鲿�ֲ�������
//      REGISTERS_LENGTH��ɢ�׼Ĵ�������50
//      SMALL_THRESHOILD��������ֵ30
//      LARGE_THRESHOILD��ɢ����ֵ150
//      SMALL_THRES_NUMS�������ж���ֵ��ÿ64����20

module fft_full_top(
    
    input               sys_clk,sys_rstn,
    
    //�������ݽ��
    (* mark_debug = "true" *)input [11:0]        adc_data_in,
    output              adc_aclk,
    
    output              tx
    );
    reg [11:0]          adc_data_in_reg;
    
    wire [31:0]         m_convert_config_data;
    wire [6:0]          m_convert_config_step;
        
    wire [47:0]         m_sample_data;
    wire                m_sample_valid;
    
    wire                s_sta_ram_trav;
    
    assign adc_aclk = sys_clk;
    always @(posedge sys_clk or negedge sys_rstn)begin
        if(!sys_rstn)
            adc_data_in_reg <= 'b0;
        else 
            adc_data_in_reg <= adc_data_in + 12'h800;
    end
    fft_convert m_fft_convert(
    .sys_clk(sys_clk),            // ϵͳʱ�ӣ�50MH
    .sys_rstn(sys_rstn),           // ϵͳ��λ������Ч��
    .s_adc_data(adc_data_in_reg),         // �������ݣ�12λ�з��ţ� 
    .s_sta_ram_trav(s_sta_ram_trav),
    .m_convert_config_data(m_convert_config_data),
    .m_convert_config_step(m_convert_config_step)
    );
    
    sample_reduce m_sample_reduce(
    .sys_clk(sys_clk),
    .sys_rstn(sys_rstn),
    .s_convert_config_data(m_convert_config_data),
    .s_adc_data_in(adc_data_in_reg),
    .m_sample_data(m_sample_data),
    .m_sample_valid(m_sample_valid)
    );
    
    wave_detect m_wave_detect(
    .sys_clk(sys_clk),                         // ϵͳʱ�ӣ�50MH
    .sys_rstn(sys_rstn),                     // ϵͳ��λ������Ч��
    .s_axis_detect_data(m_sample_data),      // �������ݣ�24λʵ�źţ� 
    .s_axis_detect_valid(m_sample_valid),  // ����������Ч��־
    .m_sta_ram_trav(s_sta_ram_trav),              
    .s_convert_config_step(m_convert_config_step),                 
    .tx(tx)
    );
    
/*    ila_0 m_ila_0 (
	.clk(sys_clk), // input wire clk


	.probe0(adc_data_in), // input wire [11:0]  probe0  
	.probe1(m_sample_data) // input wire [23:0]  probe1
    );*/
endmodule
