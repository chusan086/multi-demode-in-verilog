`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ��Ҫ������ȷ�ϵĲ�����
//  1.iq_demode_top(IQ����Ķ���ģ��)
//!!  1)FIR�˲�����ϵ��
//  2.demode_ctrl
//    1)FM�źŵĲ���λ��ϵ������Ҫ��32Э����
//    2)FSK���о����ޣ����Բο�����ϵ���ҵ�һ����Ϊ׼ȷ��ֵ��  
//    3)ASK��PSK���о����ޣ���Ҫ�����ң�
//    4)FM�źŵ�CICϵ���������̫��Ҫ��
//    5)AM�źŵ�CICϵ���������̫��Ҫ��
//  Ŀǰ������Ϊ�ο���������
//
//////////////////////////////////////////////////////////////////////////////////

module demode_top_7020(
    input               sys_clk,sys_rstn,
    
    //�������ݽ��
    input [11:0]        adc_data_in,
    output              adc_aclk,
    
    //��������ݽӿ�
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
    .sys_clk(sys_clk),        // ϵͳʱ�ӣ�50MHz�� 
    .sys_rstn(sys_rstn),       // ϵͳ��λ������Ч��
    .demode_data_in(data_in),
    .demode_data_out(dac_data_out2),
    .rx(rx)
    );
    
endmodule
