`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// �򵥵��о�ģ��
// 1.FM���о��������ʣ�����Ƶ���޹أ���Ƶ�Ƽ���ϵ���޹أ���
//  ������Ƶ��֮��Ĳ���أ�
//  Ŀǰ������Ϊ��ѭFM���������ԣ�����Ƶ�ʲ�����
//  ������취���ڲ�����λ�����о����޾����ȶ���
//  Ŀǰ�۲����Ƶ��Ϊ5kHzʱ�������޲����Ϊ200��0��-200��
//////////////////////////////////////////////////////////////////////////////////
module judge_demode(
    input                   sys_clk,        // ϵͳʱ�ӣ�50MHz�� 
    input                   sys_rstn,       // ϵͳ��λ������Ч��
    
    input [13:0]            data_in,
    input                   judge_en,
    
    input [13:0]            up_judge_thre,
    input [13:0]            low_judge_thre,
    
    output [13:0]           data_out
    );
    //�ڲ��źŹ淶
    wire                aclk = sys_clk;
    wire                rstn = sys_rstn;
    
    //�о��ź�
    reg                 data_judge;
    
    
    //�����ź�
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
