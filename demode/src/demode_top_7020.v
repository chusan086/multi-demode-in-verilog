`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 需要调试来确认的参数有
//  1.iq_demode_top(IQ解调的顶层模块)
//!!  1)FIR滤波器的系数
//  2.demode_ctrl
//    1)FM信号的补偿位移系数（需要和32协调）
//    2)FSK的判决门限（可以参考补偿系数找到一个较为准确定值）  
//    3)ASK和PSK的判决门限（需要单独找）
//    4)FM信号的CIC系数（这个不太重要）
//    5)AM信号的CIC系数（这个不太重要）
//  目前可以作为参考的内容是
//
//////////////////////////////////////////////////////////////////////////////////

module demode_top_7020(
    input               sys_clk,sys_rstn,
    
    //输入数据借口
    input [11:0]        adc_data_in,
    output              adc_aclk,
    
    //解调后数据接口
    output[13:0]        dac_data_out2,
    output              dac_aclk2,
    output              dac_wr2,
    
    
    input               rx      
    );
    
    assign adc_aclk = sys_clk;
    assign dac_aclk2 = sys_clk;
    assign dac_wr2 = sys_clk;
    
    reg [11:0]          data_in_0;
    reg [15:0]          data_in;
    always @(posedge sys_clk or negedge sys_rstn)begin
        if(!sys_rstn)begin
            data_in_0 <= 'b0;
            data_in <= 'b0;
        end else begin
            data_in_0 <= adc_data_in + 12'h800;
            data_in <= {data_in_0,4'b0};
        end
    end
    
    multi_demode m_multi_demode( 
    .sys_clk(sys_clk),        // 系统时钟（50MHz） 
    .sys_rstn(sys_rstn),       // 系统复位（低有效）
    .demode_data_in(data_in),
    .demode_data_out(dac_data_out2),
    .rx(rx)
    );
    
endmodule
