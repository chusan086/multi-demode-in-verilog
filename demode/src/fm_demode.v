`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 1.FM解调模块（相位解缠绕与微分还原）
//      功能：接收FM解调后的相位数据，通过相位解缠绕后
//      经过CIC滤波的抽取信号进行相位差分运算实现信号还原
// 2.差分运算会放大高频噪声，cic必不可缺
// 3.在当前CIC滤波器设计下（更换cic需要重新测试）
//      补偿移位数与log2（调制度）正相关
//      调制度为8移位数为5，调制度为4移位数为6(100kHz调制信号)
//      猜测：同时也与调制信号的log2（频率）相关（验证有关）
//      频率为50k移位数为5,频率为100k移位数为6(调制度为4)
//      (上述结论基于适应14位输出的结果）
//      (移位的示例已经不适用了）
// 4.在当前CIC滤波器设计下，调制度为2，调制频率100kHz
//      补偿移位数为3
//////////////////////////////////////////////////////////////////////////////////
module fm_demode(
    input                   sys_clk,        // 系统时钟（50MHz） 
    input                   sys_rstn,       // 系统复位（低有效）
    input                   fm_en,          // 模块使能信号
       
    input [15:0]            phase,          // IQ解调相位输出(缠绕）
    (* mark_debug = "true" *)input [3:0]             shift_num,      // 补偿移位数
    
    (* mark_debug = "true" *)output reg [13:0]       demode_out      // 解调输出（14位无符号数）               
    );
    localparam CIC_WIDTH = 48; 
    // 内部时钟与复位信号
    wire aclk = sys_clk;   
    wire rstn = sys_rstn;  
    
    // 相位解缠绕相关寄存器
    reg [31:0]      phase_0;        // 延时寄存器
    reg [31:0]      phase_1;
    reg [31:0]      phase_compen;   // 相位解缠输出
    reg [31:0]      phase_offset;   //相位偏置积累
    
    // CIC滤波器接口信号
    wire                        cic_ready;                  // cic就绪标志     
    wire [CIC_WIDTH-1:0]        phase_filter;          // 滤波器输出数据    
    wire                        phase_filter_valid;    // 输出有效标志     
    
    // 相位差分相关寄存器
    reg [CIC_WIDTH-1:0]         phase_filter_0;        // 延时寄存器
    reg [CIC_WIDTH-1:0]         phase_filter_1;
    (* mark_debug = "true" *)reg [CIC_WIDTH-1:0]         phase_filter_diff;     // 相位差分结果（有符号）
                         
    //=============================================================
    // 相位补偿逻辑,解缠
    //=============================================================    
    always @(posedge aclk or negedge rstn)begin
        if(!rstn)begin
            phase_0 <= 'b0;
            phase_1 <= 'b0;
            phase_offset <= 'b0;
        end else begin
            phase_0 <= $signed(phase);
            phase_1 <= phase_0;
            phase_compen <= phase_1 + phase_offset;
            if(($signed(phase_1 - phase_0 ) > $signed(32'h3000))) phase_offset <= $signed(phase_offset + 32'h4000);
            else if($signed(phase_0 - phase_1 ) > $signed(32'h3000)) phase_offset <= $signed(phase_offset - 32'h4000);
            else phase_offset <= phase_offset;
        end
    end
    
    // 相位差分计算逻辑
    always @(posedge aclk or negedge rstn) begin
        if (!rstn||!fm_en) begin
            phase_filter_0 <= 'd0;
            phase_filter_1 <= 'd0;
            phase_filter_diff <= 'd0;
        end else if(phase_filter_valid) begin
            phase_filter_0 <= phase_filter;          
            phase_filter_1 <= phase_filter_0;
            phase_filter_diff <= $signed((phase_filter_0 - phase_filter_1));   
        end
    end 
    
    // 输出格式化
    always @(posedge aclk or negedge rstn) begin
        if (!rstn||!fm_en) begin
            demode_out <= 'b0;
        end else begin
            demode_out <= {phase_filter_diff[CIC_WIDTH-1],phase_filter_diff[(25 - shift_num)-: 11],2'b0} + 14'h2000;
        end
    end
    
    
    fm_demode_cic m_fm_demode_cic (
    .aclk(aclk),                              // input wire aclk
    .aresetn(rstn),                        // input wire aresetn
    .s_axis_data_tdata(phase_compen),    // input wire [15 : 0] s_axis_data_tdata
    .s_axis_data_tvalid(cic_ready&&fm_en),  // input wire s_axis_data_tvalid
    .s_axis_data_tready(cic_ready),  // output wire s_axis_data_tready
    .m_axis_data_tdata(phase_filter),    // output wire [15 : 0] m_axis_data_tdata
    .m_axis_data_tvalid(phase_filter_valid)  // output wire m_axis_data_tvalid
    );
    
endmodule
