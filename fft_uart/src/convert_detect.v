`timescale 1ns / 1ps
// fft_detect的简化版，简单的找到大于阈值的频率点，
// 视作该点后的频谱有意义，作为下混频的参考频率输出
module convert_detect(
    input                   sys_clk,            // 系统时钟（50MH
    input                   sys_rstn,           // 系统复位（低有效）
    
    // RAM接口
    output reg[8:0]     s_fftmini_ram_addr,     // RAM读取地址
    input [15:0]        s_fftmini_ram_data,     // RAM输出数据
    
    // FFT控制接口
    output reg          fftmini_ctrl,       // FFT启动控制（持续高时，FFT正常接收信号）  
    input               fftmini_flag,       // FFT运行标志（高为输出写入RAM，低为其他）  
    
    output reg [15:0]   convert_freq_data,  //下混频对应地址             
    output reg          convert_freq_valid
    );
    //参数定义   
    localparam LARGE_THRESHOILD = 'd200; //大阈值，根据前级信号增益修改，检测离散谱
    
    //状态定义
    localparam FFT_IDLE = 'd0;      // 空闲状态，此时FFT工作      
    localparam FFT_WAIT = 'd1;      // 等待FFT写入RAM   
    localparam RAM_TRAV = 'd2;      // RAM扫描分析   
    
    //内部信号规范
    wire                aclk = sys_clk;
    wire                rstn = sys_rstn;
    
    //状态机控制信号
    reg [3:0]           nex_sta;
    reg [3:0]           cur_sta;
                            
    //状态机第一段
    always @(posedge aclk or negedge rstn) begin
        if(!rstn)cur_sta <= 'b0;
        else cur_sta <= nex_sta;
    end
    
    //状态机第二段
    always @(*) begin
        case(cur_sta)
            FFT_IDLE : begin    
                if(fftmini_flag) nex_sta = FFT_WAIT;
                else nex_sta = FFT_IDLE;
            end
            FFT_WAIT : begin
                if(!fftmini_flag) nex_sta = RAM_TRAV;
                else nex_sta = FFT_WAIT;
            end
            RAM_TRAV : begin
                if(s_fftmini_ram_addr == 'h1ff||s_fftmini_ram_data >= LARGE_THRESHOILD) nex_sta = FFT_IDLE;
                else nex_sta = RAM_TRAV;
            end
        endcase
    end
    
    //状态机第三段
    always @(posedge aclk or negedge rstn) begin
        if(!rstn) begin 
            s_fftmini_ram_addr <= 'b0;
            convert_freq_data <= 'b0;
            convert_freq_valid <= 'b0;
            fftmini_ctrl <= 'b0; 
        end else begin
            convert_freq_valid <= 'b0;
            case(cur_sta)
                FFT_IDLE : begin
                    // 启动FFT处理
                    fftmini_ctrl <= 1'b1;    
                end
                FFT_WAIT : begin
                    fftmini_ctrl <= 1'b0; 
                    s_fftmini_ram_addr <= 'b0;
                end
                RAM_TRAV : begin
                    s_fftmini_ram_addr <= s_fftmini_ram_addr + 1'b1;
                    if(s_fftmini_ram_data >= LARGE_THRESHOILD)begin
                        convert_freq_data <= s_fftmini_ram_addr;   
                        convert_freq_valid <= 1'b1;
                    end         
                end
            endcase
        end
    end
    
endmodule
    