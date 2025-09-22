//////////////////////////////////////////////////////////////////////////////////
// fft_full的mini版，变换点数为1024
// 用于简单鉴定下混频频率的
// f=addr*fs/N=addr*50_000_000/1024(正频率部分)
//////////////////////////////////////////////////////////////////////////////////
module fft_mini_magni(
    input                   sys_clk,            // 系统时钟（50MH
    input                   sys_rstn,           // 系统复位（低有效）
    
    input [11:0]            s_adc_data,         // 输入数据（12位有符号） 
    input                   s_adc_valid,
    
    
    (* mark_debug = "true" *)output                  m_fftmini_magni_valid,  // 输出数据有效标志  
    (* mark_debug = "true" *)output [15:0]           m_fftmini_magni_data,   // 输出数据（16位模长）
    (* mark_debug = "true" *)output [15:0]           m_fftmini_magni_addr,   // 输出数据地址
    
    output                  fftmini_event_frame_started            // FFT帧开始标志  
    );    
    
    
    
    wire  aclk = sys_clk;
    wire  aresetn = sys_rstn;
    
    // fft数据接口
    wire [15:0]             m_axis_fft_addr;        // 频率点地址  
    reg [16*19-1:0]         m_axis_fft_addr_reg;    //注意CORDIC的时延                
    wire                    m_axis_fft_valid;       // 输出数据有效标志                     
    wire [47:0]             m_axis_fft_data;        //傅里叶变换数据
    
    // cordic接口
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
    // 系统接口
    .aclk(aclk),                                                // input wire aclk
    .aresetn(aresetn),                                          // input wire aresetn
    
    // 配置接口（{7'b0,1'b1(正FFT)}）
    .s_axis_config_tdata(8'h01),                                // input wire [7 : 0] s_axis_config_tdata
    .s_axis_config_tvalid(1'b1),                                // input wire s_axis_config_tvalid
    .s_axis_config_tready(),                                    // output wire s_axis_config_tready
    
    // 数据输入接口（32位：12位I路）
    .s_axis_data_tdata({4'b0,s_adc_data,16'b0}),          
    .s_axis_data_tvalid(s_adc_valid),                     
    .s_axis_data_tready(),                                     
    .s_axis_data_tlast(1'b1),                                  
    
    // 数据输出接口（48位：1位空置23位实部 + 1位空置23位虚部）
    .m_axis_data_tdata(m_axis_fft_data),                        // output wire [63 : 0] m_axis_data_tdata
    .m_axis_data_tuser(m_axis_fft_addr),                        // output wire [15 : 0] m_axis_data_tuser
    .m_axis_data_tvalid(m_axis_fft_valid),                      // output wire m_axis_data_tvalid
    .m_axis_data_tlast(),
    .m_axis_data_tready(1'b1),                                 // output wire m_axis_data_tlast
    
    // 状态事件输出
    //输入开始拉高一时钟
    .event_frame_started(event_frame_started),                  // output wire event_frame_started
    //输入结束拉高一时钟
    .event_tlast_missing(),                  // output wire event_tlast_missing
    //输入时没有数据的每个时钟周期内都会被拉高
    .event_data_in_channel_halt(),          // output wire event_data_in_channel_halt
    .event_tlast_unexpected()                                   // output wire event_tlast_unexpected
    );
    
    //复数频域输出取模
    fft_mini_cordic m_fft_mini_cordic (
    .aclk(aclk),                                        // input wire aclk
    .aresetn(aresetn),                                  // input wire aresetn
    .s_axis_cartesian_tvalid(m_axis_fft_valid),         // input wire s_axis_cartesian_tvalid
    .s_axis_cartesian_tdata(m_axis_fft_data),           // input wire [63 : 0] s_axis_cartesian_tdata
    .m_axis_dout_tvalid(m_axis_cordic_tvalid),          // output wire m_axis_dout_tvalid
    .m_axis_dout_tdata(m_axis_cordic_tdata)             // output wire [31 : 0] m_axis_dout_tdata
    );
endmodule

