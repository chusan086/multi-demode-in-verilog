`timescale 1ns / 1ps
//PA10：RX；PA9:TX
//简单的顶层封装
// (* mark_debug = "true" *)
// 需要调试来确认的参数有
//  1.fft_convert（小点数FFT确定信号频率起点进行可变下混频，输出32频率控制字）
//    1）convert_detect（扫频确认信号有效频率起点）
// ！！ LARGE_THRESHOILD（主要是判断信号频率起点）
//    2）convert_sync（对齐模块，只有在某个特殊状态更新下混频频率，详见模块上注释）  
//      FREQ_OFFST（初始频率，可以选择为频率下限）
// ！！ FREQ_RESOL（下混频的频率步进量）
//      FREQ_COEFF（不用调，由FFT点数和频率控制字位宽决定）
//  2.sample_reduce（下混频并CIC降采样）     
// ！！1）fft_sample_down_cic响应（现在为5级联，2延迟，12抽取）
//      （CIC响应改变后要在STM32更新补偿表）  
//  3.wave_detect（集成了FFT，暂存，扫频和UART数据包的最核心模块）
//    1）fft_detect（大小阈值，区分离散和连续谱扫频发送）    
//      REGISTERS_LENGTH（离散谱寄存器数量，要STM32同步改）
//      SMALL_THRESHOILD（小阈值，注意连续谱取噪声中点，可能没用了）
//      SMALL_THRES_NUMS（小阈值计数器，64中大于该值视作有连续谱）
// ！！ LARGE_THRESHOILD（大阈值，根据前级信号增益修改，检测离散谱）
//  
//
//
//
// 1.CIC的抽取倍数为12（修改记得更新注释和32端补偿系数）
// 2.default下混频频率为1MHz
// 3.扫频模块部分参数如下
//      REGISTERS_LENGTH离散谱寄存器数量50
//      SMALL_THRESHOILD连续谱阈值30
//      LARGE_THRESHOILD离散谱阈值150
//      SMALL_THRES_NUMS连续谱判断阈值（每64个）20

module fft_full_top(
    
    input               sys_clk,sys_rstn,
    
    //输入数据借口
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
    .sys_clk(sys_clk),            // 系统时钟（50MH
    .sys_rstn(sys_rstn),           // 系统复位（低有效）
    .s_adc_data(adc_data_in_reg),         // 输入数据（12位有符号） 
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
    .sys_clk(sys_clk),                         // 系统时钟（50MH
    .sys_rstn(sys_rstn),                     // 系统复位（低有效）
    .s_axis_detect_data(m_sample_data),      // 输入数据（24位实信号） 
    .s_axis_detect_valid(m_sample_valid),  // 输入数据有效标志
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
