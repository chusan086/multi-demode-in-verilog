//////////////////////////////////////////////////////////////////////////////////
// Module Name: wave_detect
// function: Frequency Spectrum Analyzer
// Description: 
//   1. 接收时域采样数据，进行FFT计算并存储模值到双端口RAM
//   2. 根据检测算法读取RAM数据，通过UART发送频谱特征
//////////////////////////////////////////////////////////////////////////////////
module wave_detect(
    input                   sys_clk,            // 系统时钟（50MH
    input                   sys_rstn,           // 系统复位（低有效）
    
    input [47:0]            s_axis_detect_data,    // 输入数据（16位实信号） 
    input                   s_axis_detect_valid,   // 输入数据有效标志   
    
    output                  m_sta_ram_trav,         // fft_detect在RAM_TRAV的标志位               
    (* mark_debug = "true" *)input [6:0]             s_convert_config_step,   // 下混频的频率步进量（对应频率转换看costas_fft）          
    
    output                  tx
    );
    // FFT模值计算模块接口
    (* mark_debug = "true" *)wire [15:0]             m_axis_fftmagni_addr;
    (* mark_debug = "true" *)wire                    m_axis_fftmagni_valid;
    (* mark_debug = "true" *)wire [15:0]             m_axis_fftmagni_data;
    wire                    event_frame_started;      
    
    // RAM输出接口
    wire [12:0]             s_ram_addr;
    wire [15:0]             s_ram_data;
    
    
    wire                    fft_ctrl;
    
    // UART打包模块接口
    wire [15:0]             m_uart_ctrl_addr;       //特征频点地址
    wire [15:0]             m_uart_ctrl_data;       //特征频点幅值
    wire                    m_uart_ctrl_valid;      //数据有效标志（单脉冲）   采用握手    
    wire                    m_uart_ctrl_ready;      //发送就绪标志
    wire [7:0]              m_uart_ctrl_extra;        //2XSK标志信号    
    wire                    m_uart_ctrl_end;        //发送帧结束标志
         
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
