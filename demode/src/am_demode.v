`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AM在输入为+-4V时目前这个位宽选择可以空余一位，不太可能超出吧
//////////////////////////////////////////////////////////////////////////////////


module am_demode(
    input                   sys_clk,        // 系统时钟（50MHz） 
    input                   sys_rstn,       // 系统复位（低有效）
    input                   am_en,          // 模块使能信号
       
    input [15:0]            magni,          // IQ解调模长输出(缠绕）
    
    output reg [13:0]       demode_out      // 解调输出（14位无符号数）       
    );
    // 内部时钟与复位信号
    wire aclk = sys_clk;   
    wire rstn = sys_rstn;  
    
    wire            cic_ready;
    
    wire [15:0]     magni_filter;
    wire            magni_filter_valid;
    
    always @(posedge aclk or negedge rstn) begin
        if (!rstn||!am_en) begin
            demode_out <= 'b0;
        end else begin
            demode_out <= {magni_filter[9:0],4'b0};
        end
    end
    
    am_demode_cic m_am_demode_cic (
    .aclk(aclk),                              // input wire aclk
    .aresetn(rstn),                        // input wire aresetn
    .s_axis_data_tdata(magni),          // input wire [15 : 0] s_axis_data_tdata
    .s_axis_data_tvalid(cic_ready&&am_en),  // input wire s_axis_data_tvalid
    .s_axis_data_tready(cic_ready),  // output wire s_axis_data_tready
    .m_axis_data_tdata(magni_filter),    // output wire [15 : 0] m_axis_data_tdata
    .m_axis_data_tvalid(magni_filter_valid)  // output wire m_axis_data_tvalid
    );
    
endmodule
