`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: samp_reduce
// function: IQ Down-Conversion & Decimation
// Description: 
//   1. 接收12位ADC数据，通过DDS生成本振信号进行数字混频
//   2. 使用CIC滤波器进行抗混叠滤波和降采样
//   3. 输出48位数据（22位I路 + 22位Q路）
//   4. 包含UART配置接口用于DDS频率控制
//   5. K = f0*(2^16)/50MHz
// 注意：
// 1. CIC滤波器参数修改后需重新调整输出位宽
// 2. 输出信号已包含4倍增益补偿
// 3. 输入数据为12位有符号数，输出数据为22位有符号数（保留符号位扩展）
//////////////////////////////////////////////////////////////////////////////////
module sample_reduce(
    input               sys_clk,            // 系统时钟 (50MHz)              
    input               sys_rstn,           // 系统复位（低有效）         
    
    input [11:0]        s_adc_data_in,      // ADC输入数据（12位无符号）  
    
    input [31:0]        s_convert_config_data,
    
    output [47:0]       m_sample_data,      // 输出数据（48位：22位I路 + 22位Q路 ）  
    output              m_sample_valid      // 输出数据有效标志（降采样后为间歇脉冲）          
    );
    wire  aclk = sys_clk;           // 主工作时钟    
    wire  aresetn = sys_rstn;       // 复位信号（低有效）
     
    
    // DDS控制器
    wire [31:0]         m_dds_data;              // DDS输出数据（32位，I/Q各12位）     
    wire                m_dds_valid;             // DDS输出有效标志   
    reg [3:0]           m_dds_valid_r;           // DDS有效信号延迟链  
    
    // 混频器输出
    wire [23:0]         I_mul_data;              // 混频器输出数据     
    wire [23:0]         Q_mul_data;
    
    // CIC滤波器接口                                                
    wire                I_cic_tready;            // CIC输入就绪标志   
    wire                Q_cic_tready;
    wire                I_sample_valid;         // CIC输出有效
    wire                Q_sample_valid;
    wire [23:0]         I_sample_data;
    wire [23:0]         Q_sample_data;
    // 输出数据拼接（符号位扩展处理，四倍增益）
    assign m_sample_data = {2'b0,I_sample_data[23],I_sample_data[20:0],2'b0,Q_sample_data[23],Q_sample_data[20:0]};
    // 数据有效信号传递
    assign m_sample_valid = I_sample_valid && Q_sample_valid;
    
    
    // DDS有效信号延迟对齐    
    always @(posedge sys_clk or negedge sys_rstn)begin
        if(!sys_rstn)
            m_dds_valid_r <= 'b0;
        else 
            m_dds_valid_r <= {m_dds_valid_r[2:0],m_dds_valid};
    end
    			

    // DDS数字本振生成器
    fft_sample_down_dds m_fft_sample_down_dds (
    .aclk(aclk),                                  // input wire aclk
    .aresetn(aresetn),                            // input wire aresetn
    .s_axis_config_tvalid(1'b1),                  // input wire s_axis_config_tvalid
    .s_axis_config_tdata(s_convert_config_data),    // input wire [15 : 0] s_axis_config_tdata
    .m_axis_data_tvalid(m_dds_valid),                          // output wire m_axis_data_tvalid
    .m_axis_data_tdata(m_dds_data)         // output wire [15 : 0] m_axis_data_tdata
    );
    
    // I路混频器（12位乘法）
    fft_sample_down_mult I_fft_sample_down_mult (
    .CLK(aclk),                     // input wire CLK
    .A(m_dds_data[11:0]),      // input wire [11 : 0] A
    .B(s_adc_data_in),              // input wire [11 : 0] B
    .P(I_mul_data)                           // output wire [23 : 0] P
    );
    
    // Q路混频器（12位乘法）
    fft_sample_down_mult Q_fft_sample_down_mult (
    .CLK(aclk),                     // input wire CLK
    .A(m_dds_data[27:16]),          // input wire [11 : 0] A
    .B(s_adc_data_in),              // input wire [11 : 0] B
    .P(Q_mul_data)                           // output wire [23 : 0] P
    );
    
    
    //每次调整CIC都需要重新设置输出位宽！！！
    // I路CIC滤波器
    fft_sample_down_cic I_fft_sample_down_cic (
    .aclk(aclk),                              // input wire aclk
    .aresetn(aresetn),                        // input wire aresetn
    .s_axis_data_tdata(I_mul_data),    // input wire [23 : 0] s_axis_data_tdata
    .s_axis_data_tvalid(m_dds_valid_r[3]&&I_cic_tready),        // input wire s_axis_data_tvalid
    .s_axis_data_tready(I_cic_tready),      // output wire s_axis_data_tready
    .m_axis_data_tdata(I_sample_data),    // output wire [23 : 0] m_axis_data_tdata
    .m_axis_data_tvalid(I_sample_valid)  // output wire m_axis_data_tvalid
    );
    
    // Q路CIC滤波器
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
