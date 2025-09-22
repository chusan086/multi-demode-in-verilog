`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 简单的判决模块
// 1.FM的判决与码速率，绝对频率无关（与频移键控系数无关），
//  与两个频率之间的差相关，
//  目前可以认为遵循FM的线性特性，随着频率差增大，
//  可以想办法调节补偿移位数让判决门限尽量稳定，
//  目前观测出在频差为5kHz时，上下限差大致为200（0，-200）
//////////////////////////////////////////////////////////////////////////////////
module judge_demode(
    input                   sys_clk,        // 系统时钟（50MHz） 
    input                   sys_rstn,       // 系统复位（低有效）
    
    input [13:0]            data_in,
    input                   judge_en,
    
    input [13:0]            up_judge_thre,
    input [13:0]            low_judge_thre,
    
    output [13:0]           data_out
    );
    //内部信号规范
    wire                aclk = sys_clk;
    wire                rstn = sys_rstn;
    
    //判决信号
    reg                 data_judge;
    
    
    //消抖信号
    reg [2:0]           shake_cnt; 
    reg                 data_judge_filter;
    
    assign data_out = data_judge_filter ? 14'h3fff : 14'h0;
    
    always @(posedge aclk or negedge rstn) begin
        if (!rstn||!judge_en) begin
            data_judge <= 'b0;
        end else begin
            if($signed(data_in > up_judge_thre))data_judge <= 1'b1;
            else if($signed(data_in < low_judge_thre))data_judge <= 1'b0;
            else data_judge <= data_judge;
        end
    end
    
    always @(posedge aclk or negedge rstn) begin
        if (!rstn||!judge_en) begin
            shake_cnt <= 'b0;
            data_judge_filter <= 'b0;
        end else begin
            if(data_judge_filter != data_judge && shake_cnt == 'd7)begin
                shake_cnt <= 'b0;
                data_judge_filter <= data_judge;
            end else if(data_judge_filter == data_judge)shake_cnt <= 'b0;
            else shake_cnt <= shake_cnt + 1'b1;
        end
    end
    
endmodule
