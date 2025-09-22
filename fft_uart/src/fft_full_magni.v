`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// һ���򵥵�����FFTģ�飬�任����Ϊ16384
// 0~8191��ӦƵ�ʣ�0~����ֹƵ��
//8192~16383��ӦƵ�ʣ�����ֹƵ��~0Mhz
//f=addr*fs/N=addr*50_000_000/CIC��ȡϵ��/16384(��Ƶ�ʲ���)
//���� -> ���� -> ��ʾ(д�룩
//
//////////////////////////////////////////////////////////////////////////////////
module fft_full_magni(
    input                   sys_clk,            // ϵͳʱ�ӣ�50MH
    input                   sys_rstn,           // ϵͳ��λ������Ч��
    
    input [47:0]            s_axis_fft_data,    // �������ݣ�16λʵ�źţ� 
    input                   s_axis_fft_valid,   // ����������Ч��־    
    
    output                  m_axis_fftmagni_valid,  // ���������Ч��־  
    output [15:0]           m_axis_fftmagni_data,   // ������ݣ�16λģ����
    output [15:0]           m_axis_fftmagni_addr,   // ������ݵ�ַ
    
    output                  event_frame_started,            // FFT֡��ʼ��־  
    output                  event_tlast_missing,            // TLAST��ʧ���� 
    output                  event_data_in_channel_halt);    // ����ͨ����ָͣʾ
    
    
    
    wire  aclk = sys_clk;
    wire  aresetn = sys_rstn;
    
    // fft���ݽӿ�
    wire [15:0]             m_axis_fft_addr;        // Ƶ�ʵ��ַ  
    reg [16*19-1:0]         m_axis_fft_addr_reg;    //ע��CORDIC��ʱ��                
    wire                    m_axis_fft_valid;       // ���������Ч��־                     
    wire [79:0]             m_axis_fft_data;        //����Ҷ�任����
    
    // cordic�ӿ�
    wire                    m_axis_cordic_tvalid;
    wire [31:0]             m_axis_cordic_tdata;
    assign m_axis_fftmagni_valid = m_axis_cordic_tvalid;
    assign m_axis_fftmagni_data = m_axis_cordic_tdata[15:0];
    assign m_axis_fftmagni_addr = m_axis_fft_addr_reg[16*19-1:16*18];                    
    
    always @(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            m_axis_fft_addr_reg <= 'b0;
        end else begin
            m_axis_fft_addr_reg <= {m_axis_fft_addr_reg[16*18-1:0],m_axis_fft_addr};
        end
    end
    
    
    fft_full m_xfft_full (
    // ϵͳ�ӿ�
    .aclk(aclk),                                                // input wire aclk
    .aresetn(aresetn),                                          // input wire aresetn
    
    // ���ýӿڣ�{7'b0,1'b1(��FFT)}��
    .s_axis_config_tdata(8'h01),                                // input wire [7 : 0] s_axis_config_tdata
    .s_axis_config_tvalid(1'b1),                                // input wire s_axis_config_tvalid
    .s_axis_config_tready(),                                    // output wire s_axis_config_tready
    
    // ��������ӿڣ�48λ��22λI· + 22λQ· ��
    .s_axis_data_tdata(s_axis_fft_data),          
    .s_axis_data_tvalid(s_axis_fft_valid),                     
    .s_axis_data_tready(),                                     
    .s_axis_data_tlast(1'b1),                                  
    
    // ��������ӿڣ�80λ��3λ����37λʵ�� + 3λ����37λ�鲿��
    .m_axis_data_tdata(m_axis_fft_data),                        // output wire [63 : 0] m_axis_data_tdata
    .m_axis_data_tuser(m_axis_fft_addr),                        // output wire [15 : 0] m_axis_data_tuser
    .m_axis_data_tvalid(m_axis_fft_valid),                      // output wire m_axis_data_tvalid
    .m_axis_data_tlast(),
    .m_axis_data_tready(1'b1),                                 // output wire m_axis_data_tlast
    
    // ״̬�¼����
    //���뿪ʼ����һʱ��
    .event_frame_started(event_frame_started),                  // output wire event_frame_started
    //�����������һʱ��
    .event_tlast_missing(),                  // output wire event_tlast_missing
    //����ʱû�����ݵ�ÿ��ʱ�������ڶ��ᱻ����
    .event_data_in_channel_halt(),          // output wire event_data_in_channel_halt
    .event_tlast_unexpected()                                   // output wire event_tlast_unexpected
    );
    
    //����Ƶ�����ȡģ
    fft_cordic m_fft_cordic (
    .aclk(aclk),                                        // input wire aclk
    .aresetn(aresetn),                                  // input wire aresetn
    .s_axis_cartesian_tvalid(m_axis_fft_valid),         // input wire s_axis_cartesian_tvalid
    .s_axis_cartesian_tdata(m_axis_fft_data),           // input wire [63 : 0] s_axis_cartesian_tdata
    .m_axis_dout_tvalid(m_axis_cordic_tvalid),          // output wire m_axis_dout_tvalid
    .m_axis_dout_tdata(m_axis_cordic_tdata)             // output wire [31 : 0] m_axis_dout_tdata
    );
endmodule
