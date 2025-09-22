`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 1.FM���ģ�飨��λ�������΢�ֻ�ԭ��
//      ���ܣ�����FM��������λ���ݣ�ͨ����λ����ƺ�
//      ����CIC�˲��ĳ�ȡ�źŽ�����λ�������ʵ���źŻ�ԭ
// 2.��������Ŵ��Ƶ������cic�ز���ȱ
// 3.�ڵ�ǰCIC�˲�������£�����cic��Ҫ���²��ԣ�
//      ������λ����log2�����ƶȣ������
//      ���ƶ�Ϊ8��λ��Ϊ5�����ƶ�Ϊ4��λ��Ϊ6(100kHz�����ź�)
//      �²⣺ͬʱҲ������źŵ�log2��Ƶ�ʣ���أ���֤�йأ�
//      Ƶ��Ϊ50k��λ��Ϊ5,Ƶ��Ϊ100k��λ��Ϊ6(���ƶ�Ϊ4)
//      (�������ۻ�����Ӧ14λ����Ľ����
//      (��λ��ʾ���Ѿ��������ˣ�
// 4.�ڵ�ǰCIC�˲�������£����ƶ�Ϊ2������Ƶ��100kHz
//      ������λ��Ϊ3
//////////////////////////////////////////////////////////////////////////////////
module fm_demode(
    input                   sys_clk,        // ϵͳʱ�ӣ�50MHz�� 
    input                   sys_rstn,       // ϵͳ��λ������Ч��
    input                   fm_en,          // ģ��ʹ���ź�
       
    input [15:0]            phase,          // IQ�����λ���(���ƣ�
    (* mark_debug = "true" *)input [3:0]             shift_num,      // ������λ��
    
    (* mark_debug = "true" *)output reg [13:0]       demode_out      // ��������14λ�޷�������               
    );
    localparam CIC_WIDTH = 48; 
    // �ڲ�ʱ���븴λ�ź�
    wire aclk = sys_clk;   
    wire rstn = sys_rstn;  
    
    // ��λ�������ؼĴ���
    reg [31:0]      phase_0;        // ��ʱ�Ĵ���
    reg [31:0]      phase_1;
    reg [31:0]      phase_compen;   // ��λ������
    reg [31:0]      phase_offset;   //��λƫ�û���
    
    // CIC�˲����ӿ��ź�
    wire                        cic_ready;                  // cic������־     
    wire [CIC_WIDTH-1:0]        phase_filter;          // �˲����������    
    wire                        phase_filter_valid;    // �����Ч��־     
    
    // ��λ�����ؼĴ���
    reg [CIC_WIDTH-1:0]         phase_filter_0;        // ��ʱ�Ĵ���
    reg [CIC_WIDTH-1:0]         phase_filter_1;
    (* mark_debug = "true" *)reg [CIC_WIDTH-1:0]         phase_filter_diff;     // ��λ��ֽ�����з��ţ�
                         
    //=============================================================
    // ��λ�����߼�,���
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
    
    // ��λ��ּ����߼�
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
    
    // �����ʽ��
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
