`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 一个简单的正向FFT模块，变换点数为16384
// 0~8191对应频率：0~正截止频率
//8192~16383对应频率：负截止频率~0Mhz
//f=addr*fs/N=addr*50_000_000/CIC抽取系数/16384(正频率部分)
//输入 -> 处理 -> 显示(写入）
//
//////////////////////////////////////////////////////////////////////////////////
module fft_full_magni(
    input                   sys_clk,            // 系统时钟（50MH
    input                   sys_rstn,           // 系统复位（低有效）
    
    input [47:0]            s_axis_fft_data,    // 输入数据（16位实信号） 
    input                   s_axis_fft_valid,   // 输入数据有效标志    
    
    output                  m_axis_fftmagni_valid,  // 输出数据有效标志  
    output [15:0]           m_axis_fftmagni_data,   // 输出数据（16位模长）
    output [15:0]           m_axis_fftmagni_addr,   // 输出数据地址
    
    output                  event_frame_started,            // FFT帧开始标志  
    output                  event_tlast_missing,            // TLAST丢失错误 
    output                  event_data_in_channel_halt);    // 输入通道暂停指示
    
    
    
    wire  aclk = sys_clk;
    wire  aresetn = sys_rstn;
    
    // fft数据接口
    wire [15:0]             m_axis_fft_addr;        // 频率点地址  
    reg [16*19-1:0]         m_axis_fft_addr_reg;    //注意CORDIC的时延                
    wire                    m_axis_fft_valid;       // 输出数据有效标志                     
    wire [79:0]             m_axis_fft_data;        //傅里叶变换数据
    
    // cordic接口
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
    // 系统接口
    .aclk(aclk),                                                // input wire aclk
    .aresetn(aresetn),                                          // input wire aresetn
    
    // 配置接口（{7'b0,1'b1(正FFT)}）
    .s_axis_config_tdata(8'h01),                                // input wire [7 : 0] s_axis_config_tdata
    .s_axis_config_tvalid(1'b1),                                // input wire s_axis_config_tvalid
    .s_axis_config_tready(),                                    // output wire s_axis_config_tready
    
    // 数据输入接口（48位：22位I路 + 22位Q路 ）
    .s_axis_data_tdata(s_axis_fft_data),          
    .s_axis_data_tvalid(s_axis_fft_valid),                     
    .s_axis_data_tready(),                                     
    .s_axis_data_tlast(1'b1),                                  
    
    // 数据输出接口（80位：3位空置37位实部 + 3位空置37位虚部）
    .m_axis_data_tdata(m_axis_fft_data),                        // output wire [63 : 0] m_axis_data_tdata
    .m_axis_data_tuser(m_axis_fft_addr),                        // output wire [15 : 0] m_axis_data_tuser
    .m_axis_data_tvalid(m_axis_fft_valid),                      // output wire m_axis_data_tvalid
    .m_axis_data_tlast(),
    .m_axis_data_tready(1'b1),                                 // output wire m_axis_data_tlast
    
    // 状态事件输出
    //输入开始拉高一时钟
    .event_frame_started(event_frame_started),                  // output wire event_frame_started
    //输入结束拉高一时钟
    .event_tlast_missing(),                  // output wire event_tlast_missing
    //输入时没有数据的每个时钟周期内都会被拉高
    .event_data_in_channel_halt(),          // output wire event_data_in_channel_halt
    .event_tlast_unexpected()                                   // output wire event_tlast_unexpected
    );
    
    //复数频域输出取模
    fft_cordic m_fft_cordic (
    .aclk(aclk),                                        // input wire aclk
    .aresetn(aresetn),                                  // input wire aresetn
    .s_axis_cartesian_tvalid(m_axis_fft_valid),         // input wire s_axis_cartesian_tvalid
    .s_axis_cartesian_tdata(m_axis_fft_data),           // input wire [63 : 0] s_axis_cartesian_tdata
    .m_axis_dout_tvalid(m_axis_cordic_tvalid),          // output wire m_axis_dout_tvalid
    .m_axis_dout_tdata(m_axis_cordic_tdata)             // output wire [31 : 0] m_axis_dout_tdata
    );
endmodule
