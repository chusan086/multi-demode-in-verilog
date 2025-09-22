//////////////////////////////////////////////////////////////////////////////////
// Module Name: wave_detect
// function: Frequency Spectrum Analyzer
// Description: 
//   1. 接收时域采样数据，进行FFT计算并存储模值到双端口RAM
//   2. 根据检测算法读取RAM数据，确定下混频频率
//////////////////////////////////////////////////////////////////////////////////
module fft_convert(
    input                   sys_clk,            // 系统时钟（50MH
    input                   sys_rstn,           // 系统复位（低有效）
    
    input [11:0]            s_adc_data,         // 输入数据（12位有符号） 
    
    input                   s_sta_ram_trav,
    
    output [31:0]           m_convert_config_data,
    output [6:0]            m_convert_config_step
    );
    // FFT模值计算模块接口
    wire [15:0]             m_fftmini_magni_addr;
    wire                    m_fftmini_magni_valid;
    wire [15:0]             m_fftmini_magni_data;
    wire                    fftmini_event_frame_started;      
    
    // RAM输出接口
    wire [8:0]              s_fftmini_ram_addr;
    wire [15:0]             s_fftmini_ram_data;
    
    //
    wire                    fftmini_ctrl;
    wire [15:0]             convert_freq_data;
    wire                    convert_freq_valid;

    fft_mini_magni m_fft_mini_magni(
    .sys_clk(sys_clk),
    .sys_rstn(sys_rstn),
    
    .s_adc_data(s_adc_data),
    .s_adc_valid(fftmini_ctrl),
    
    .m_fftmini_magni_addr(m_fftmini_magni_addr),
    .m_fftmini_magni_valid(m_fftmini_magni_valid),
    .m_fftmini_magni_data(m_fftmini_magni_data),
    
    .fftmini_event_frame_started(fftmini_event_frame_started)
    );
    
    fft_mini_ram m_fft_mini_ram (
    .clka(sys_clk),    // input wire clka
    .ena(m_fftmini_magni_valid),
    .wea(!m_fftmini_magni_addr[9]),      // input wire [0 : 0] wea
    .addra(m_fftmini_magni_addr[8:0]),  // input wire [12 : 0] addra
    .dina(m_fftmini_magni_data),    // input wire [15 : 0] dina
    .clkb(sys_clk),    // input wire clkb
    .addrb(s_fftmini_ram_addr),  // input wire [12 : 0] addrb
    .doutb(s_fftmini_ram_data)  // output wire [15 : 0] doutb
    );
    
    convert_detect m_convert_detect(
    .sys_clk(sys_clk),
    .sys_rstn(sys_rstn),
    .s_fftmini_ram_addr(s_fftmini_ram_addr),
    .s_fftmini_ram_data(s_fftmini_ram_data),
    .fftmini_ctrl(fftmini_ctrl),
    .fftmini_flag(m_fftmini_magni_valid),
    .convert_freq_data(convert_freq_data),
    .convert_freq_valid(convert_freq_valid)
    ); 
    
    convert_sync m_convert_sync(
    .sys_clk(sys_clk),
    .sys_rstn(sys_rstn),
    .convert_freq_data(convert_freq_data),  //下混频对应地址       
    .convert_freq_valid(convert_freq_valid),                  
    .s_sta_ram_trav(s_sta_ram_trav),         // fft_detect在RAM_TRAV的标志位
    .m_convert_config_data(m_convert_config_data),  //下混频的频率控制字
    .m_convert_config_step(m_convert_config_step)     //下混频的频率步量           
    );
    
endmodule
