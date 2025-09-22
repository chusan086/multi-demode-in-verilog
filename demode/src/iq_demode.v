//=============================================================
// Module: iq_demod_top
// Function: IQ解调顶层模块，实现信号混频、极坐标转换和相位补偿
//接收16位有符号数据输入
//输出20位无符号辐角和有符号相位
//=============================================================
module iq_demod_top(
    input                   sys_clk,        // 系统时钟（50MHz） 
    input                   sys_rstn,       // 系统复位（低有效）
       
    input [15:0]            data_in,        // ADC输入数据（I路）
    
    //载波频率控制接口
    input [31:0]            cw_phase_increment,         //载波频率控制字(32位无符号数字）
    input                   cw_phase_increment_valid,   //载波频率控制字_有效位 
    // 基础频率控制字（时钟为50Mhz，计算公式：K = f0*(2^32)/50MHz）      
    
    output [15:0]           magni,phase,    // 解调后的相位幅度输出    
    output                  valid           // 数据有效标志       
    );
    wire aclk = sys_clk;                    //预留时钟修改余地
    wire rstn = sys_rstn;
    
    //dds输出
    wire            dds_valid;      // DDS数据有效标志
    wire [15:0]     cos_data;       // DDS输出的余弦和正弦信号         
    wire [15:0]     sin_data;
    
    //混频器输出
    wire [31:0]     I_data;         // I路混频结果
    wire [31:0]     Q_data;         // Q路混频结果
    
    //滤波器数据接口
    wire            s_axis_Idata_tready;
    wire            s_axis_Qfir_tready;
    wire            I_filtered_valid;   // I路滤波数据有效标志
    wire            Q_filtered_valid;   // Q路滤波数据有效标志  
    wire [31:0]     I_filtered;         // 滤波后的I路数据 
    wire [31:0]     Q_filtered;         // 滤波后的Q路数据 
    
    wire [31:0]     codic_data;         // CORDIC输出数据（高16位相位，低16位幅度）         
    wire            codic_data_valid;   // CORDIC数据有效标志
    
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
    .CLK(aclk),                 // 时钟输入   
    .A(cos_data),               // DDS余弦信号
    .B(data_in),                // ADC输入数据
    .CE(rstn),                  // 使能信号    
    .P(I_data)                  // I路乘积结果 
    );
    
    iq_demode_mult_0 Q_mult (
    .CLK(aclk),                 // 时钟输入    
    .A(sin_data),               // DDS正弦信号 
    .B(data_in),                // ADC输入数据 
    .CE(rstn),                 // 使能信号    
    .P(Q_data)                  // I路乘积结果  
    );
    
   
    iq_demode_fir_0 I_fir_compiler (
    .aclk(aclk),                            // 时钟输入              
    .aresetn(rstn),                         // 复位（低有效）           
    .s_axis_data_tvalid(s_axis_Ifir_tready&&s_axis_Qfir_tready),              // 输入数据有效（始终有效）     
    .s_axis_data_tready(s_axis_Ifir_tready),
    .s_axis_data_tdata(I_data),             // 输入I路数据             
    .m_axis_data_tvalid(I_filtered_valid),  // 输出数据有效          
    .m_axis_data_tdata(I_filtered)          // 滤波后的I路数据          
    );                                                
    
    iq_demode_fir_0 Q_fir_compiler (
    .aclk(aclk),                              // 时钟输入                       
    .aresetn(rstn),                         // 复位（低有效）              
    .s_axis_data_tvalid(s_axis_Ifir_tready&&s_axis_Qfir_tready),                // 输入数据有效（始终有效）                           
    .s_axis_data_tready(s_axis_Qfir_tready),
    .s_axis_data_tdata(Q_data),               // 输入Q路数据               
    .m_axis_data_tvalid(Q_filtered_valid),    // 输出数据有效               
    .m_axis_data_tdata(Q_filtered)            // 滤波后的Q路数据             
    );
    
    iq_demode_cordic_0 codic (
    .aclk(aclk),                                                    // 时钟输入                   
    .aresetn(rstn),                                                 // 复位（低有效）                
    .s_axis_cartesian_tvalid(1),   // 输入有效（I/Q路同时有效）            
    .s_axis_cartesian_tdata({I_filtered,Q_filtered}),               // 输入数据（I路高16位，Q路低16位）       
    .m_axis_dout_tvalid(codic_data_valid),                          // 输出数据有效                    
    .m_axis_dout_tdata(codic_data)                                  // 输出数据（相位高16位，幅度低16位）       
    );
    
    
endmodule


