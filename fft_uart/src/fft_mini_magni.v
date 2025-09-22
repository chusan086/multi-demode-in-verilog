//////////////////////////////////////////////////////////////////////////////////
// fft_full��mini�棬�任����Ϊ1024
// ���ڼ򵥼����»�ƵƵ�ʵ�
// f=addr*fs/N=addr*50_000_000/1024(��Ƶ�ʲ���)
//////////////////////////////////////////////////////////////////////////////////
module fft_mini_magni(
    input                   sys_clk,            // ϵͳʱ�ӣ�50MH
    input                   sys_rstn,           // ϵͳ��λ������Ч��
    
    input [11:0]            s_adc_data,         // �������ݣ�12λ�з��ţ� 
    input                   s_adc_valid,
    
    
    (* mark_debug = "true" *)output                  m_fftmini_magni_valid,  // ���������Ч��־  
    (* mark_debug = "true" *)output [15:0]           m_fftmini_magni_data,   // ������ݣ�16λģ����
    (* mark_debug = "true" *)output [15:0]           m_fftmini_magni_addr,   // ������ݵ�ַ
    
    output                  fftmini_event_frame_started            // FFT֡��ʼ��־  
    );    
    
    
    
    wire  aclk = sys_clk;
    wire  aresetn = sys_rstn;
    
    // fft���ݽӿ�
    wire [15:0]             m_axis_fft_addr;        // Ƶ�ʵ��ַ  
    reg [16*19-1:0]         m_axis_fft_addr_reg;    //ע��CORDIC��ʱ��                
    wire                    m_axis_fft_valid;       // ���������Ч��־                     
    wire [47:0]             m_axis_fft_data;        //����Ҷ�任����
    
    // cordic�ӿ�
    wire                    m_axis_cordic_tvalid;
    wire [31:0]             m_axis_cordic_tdata;
    
    assign m_fftmini_magni_valid = m_axis_cordic_tvalid;
    assign m_fftmini_magni_data = m_axis_cordic_tdata[15:0];
    assign m_fftmini_magni_addr = m_axis_fft_addr_reg[16*19-1:16*18];   
    assign fftmini_event_frame_started = event_frame_started;                  
    
    always @(posedge aclk or negedge aresetn)begin
        if(!aresetn)begin
            m_axis_fft_addr_reg <= 'b0;
        end else begin
            m_axis_fft_addr_reg <= {m_axis_fft_addr_reg[16*18-1:0],m_axis_fft_addr};
        end
    end
    
    
    fft_mini m_xfft_mini (
    // ϵͳ�ӿ�
    .aclk(aclk),                                                // input wire aclk
    .aresetn(aresetn),                                          // input wire aresetn
    
    // ���ýӿڣ�{7'b0,1'b1(��FFT)}��
    .s_axis_config_tdata(8'h01),                                // input wire [7 : 0] s_axis_config_tdata
    .s_axis_config_tvalid(1'b1),                                // input wire s_axis_config_tvalid
    .s_axis_config_tready(),                                    // output wire s_axis_config_tready
    
    // ��������ӿڣ�32λ��12λI·��
    .s_axis_data_tdata({4'b0,s_adc_data,16'b0}),          
    .s_axis_data_tvalid(s_adc_valid),                     
    .s_axis_data_tready(),                                     
    .s_axis_data_tlast(1'b1),                                  
    
    // ��������ӿڣ�48λ��1λ����23λʵ�� + 1λ����23λ�鲿��
    .m_axis_data_tdata(m_axis_fft_data),                        // output wire [63 : 0] m_axis_data_tdata
    .m_axis_data_tuser(m_axis_fft_addr),                        // output wire [15 : 0] m_axis_data_tuser
    .m_axis_data_tvalid(m_axis_fft_valid),                      // output wire m_axis_data_tvalid
    .m_axis_data_tlast(),
    .m_axis_data_tready(1'b1),                                 // output wire m_axis_data_tlast
    
    // ״̬�¼����
    //���뿪ʼ����һʱ��
    .event_frame_started(event_frame_started),                  // output wire event_frame_started
    //�����������һʱ��
    .event_tlast_missing(),                  // output wire event_tlast_missing
    //����ʱû�����ݵ�ÿ��ʱ�������ڶ��ᱻ����
    .event_data_in_channel_halt(),          // output wire event_data_in_channel_halt
    .event_tlast_unexpected()                                   // output wire event_tlast_unexpected
    );
    
    //����Ƶ�����ȡģ
    fft_mini_cordic m_fft_mini_cordic (
    .aclk(aclk),                                        // input wire aclk
    .aresetn(aresetn),                                  // input wire aresetn
    .s_axis_cartesian_tvalid(m_axis_fft_valid),         // input wire s_axis_cartesian_tvalid
    .s_axis_cartesian_tdata(m_axis_fft_data),           // input wire [63 : 0] s_axis_cartesian_tdata
    .m_axis_dout_tvalid(m_axis_cordic_tvalid),          // output wire m_axis_dout_tvalid
    .m_axis_dout_tdata(m_axis_cordic_tdata)             // output wire [31 : 0] m_axis_dout_tdata
    );
endmodule

