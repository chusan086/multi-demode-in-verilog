//////////////////////////////////////////////////////////////////////////////////
// Module Name: wave_detect
// function: Frequency Spectrum Analyzer
// Description: 
//   1. ����ʱ��������ݣ�����FFT���㲢�洢ģֵ��˫�˿�RAM
//   2. ���ݼ���㷨��ȡRAM���ݣ�ͨ��UART����Ƶ������
//////////////////////////////////////////////////////////////////////////////////
module wave_detect(
    input                   sys_clk,            // ϵͳʱ�ӣ�50MH
    input                   sys_rstn,           // ϵͳ��λ������Ч��
    
    input [47:0]            s_axis_detect_data,    // �������ݣ�16λʵ�źţ� 
    input                   s_axis_detect_valid,   // ����������Ч��־   
    
    output                  m_sta_ram_trav,         // fft_detect��RAM_TRAV�ı�־λ               
    (* mark_debug = "true" *)input [6:0]             s_convert_config_step,   // �»�Ƶ��Ƶ�ʲ���������ӦƵ��ת����costas_fft��          
    
    output                  tx
    );
    // FFTģֵ����ģ��ӿ�
    (* mark_debug = "true" *)wire [15:0]             m_axis_fftmagni_addr;
    (* mark_debug = "true" *)wire                    m_axis_fftmagni_valid;
    (* mark_debug = "true" *)wire [15:0]             m_axis_fftmagni_data;
    wire                    event_frame_started;      
    
    // RAM����ӿ�
    wire [12:0]             s_ram_addr;
    wire [15:0]             s_ram_data;
    
    
    wire                    fft_ctrl;
    
    // UART���ģ��ӿ�
    wire [15:0]             m_uart_ctrl_addr;       //����Ƶ���ַ
    wire [15:0]             m_uart_ctrl_data;       //����Ƶ���ֵ
    wire                    m_uart_ctrl_valid;      //������Ч��־�������壩   ��������    
    wire                    m_uart_ctrl_ready;      //���;�����־
    wire [7:0]              m_uart_ctrl_extra;        //2XSK��־�ź�    
    wire                    m_uart_ctrl_end;        //����֡������־
         
    fft_full_magni m_fft_full_magni(
    .sys_clk(sys_clk),
    .sys_rstn(sys_rstn),
    
    .s_axis_fft_data(s_axis_detect_data),
    .s_axis_fft_valid(s_axis_detect_valid&&fft_ctrl),
    
    .m_axis_fftmagni_addr(m_axis_fftmagni_addr),
    .m_axis_fftmagni_valid(m_axis_fftmagni_valid),
    .m_axis_fftmagni_data(m_axis_fftmagni_data),
    
    .event_frame_started(event_frame_started)
    );
    
    fft_ram m_fft_ram (
    .clka(sys_clk),    // input wire clka
    .ena(m_axis_fftmagni_valid),
    .wea(!m_axis_fftmagni_addr[13]),      // input wire [0 : 0] wea
    .addra(m_axis_fftmagni_addr[12:0]),  // input wire [12 : 0] addra
    .dina(m_axis_fftmagni_data),    // input wire [15 : 0] dina
    .clkb(sys_clk),    // input wire clkb
    .addrb(s_ram_addr),  // input wire [12 : 0] addrb
    .doutb(s_ram_data)  // output wire [15 : 0] doutb
    );
    
    fft_detect m_fft_detect(
    .sys_clk(sys_clk),
    .sys_rstn(sys_rstn),
    .s_ram_addr(s_ram_addr),
    .s_ram_data(s_ram_data),
    .fft_ctrl(fft_ctrl),
    .fft_flag(m_axis_fftmagni_valid),
    .m_sta_ram_trav(m_sta_ram_trav),       
    .s_convert_config_step(s_convert_config_step),
    .m_uart_ctrl_addr(m_uart_ctrl_addr),
    .m_uart_ctrl_data(m_uart_ctrl_data),
    .m_uart_ctrl_valid(m_uart_ctrl_valid),
    .m_uart_ctrl_ready(m_uart_ctrl_ready),
    .m_uart_ctrl_extra(m_uart_ctrl_extra),
    .m_uart_ctrl_end(m_uart_ctrl_end)
    ); 
    
    uart_ctrl m_uart_ctrl(
    .sys_clk(sys_clk),
    .sys_rstn(sys_rstn),
    .s_uart_ctrl_addr(m_uart_ctrl_addr),  
    .s_uart_ctrl_data(m_uart_ctrl_data),  
    .s_uart_ctrl_valid(m_uart_ctrl_valid), 
    .s_uart_ctrl_ready(m_uart_ctrl_ready), 
    .s_uart_ctrl_end(m_uart_ctrl_end),   
    .s_uart_ctrl_extra(m_uart_ctrl_extra),
    .tx(tx)                     
    );   
    
endmodule
