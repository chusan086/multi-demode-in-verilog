`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AM������Ϊ+-4VʱĿǰ���λ��ѡ����Կ���һλ����̫���ܳ�����
//////////////////////////////////////////////////////////////////////////////////


module am_demode(
    input                   sys_clk,        // ϵͳʱ�ӣ�50MHz�� 
    input                   sys_rstn,       // ϵͳ��λ������Ч��
    input                   am_en,          // ģ��ʹ���ź�
       
    input [15:0]            magni,          // IQ���ģ�����(���ƣ�
    
    output reg [13:0]       demode_out      // ��������14λ�޷�������       
    );
    // �ڲ�ʱ���븴λ�ź�
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
