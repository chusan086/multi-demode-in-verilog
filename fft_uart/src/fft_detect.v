`timescale 1ns / 1ps
// 读取RAM中的FFT数据实现扫频,提取特征点数据模块
// 1. RAM_TRAV状态（扫频）主要有三个同级判断算法
//      （1）小阈值计时器到上限时，检测小阈值计数器的值，并判决是否为2XSK信号
//      （2）在数据大于小阈值时更新小阈值计数器（连续谱）
//      （3）在数据大于大阈值时更新大阈值计数器和对应数据寄存器（离散谱）                 
// 2. UART_SEND状态主要功能是在s_uart_ctrl_ready为1时，
//      发送当前离散谱数据和对应频率m_uart_ctrl_addr/data，
//      s_uart_ctrl_valid只会置1一个时钟周期
// 3. ready_cnt延时计数器是因为s_uart_ctrl_valid是单周期脉冲，     
//      s_uart_ctrl_ready的下拉又会慢两拍，加入延时避免多次执行   
module fft_detect(
    input               sys_clk,sys_rstn,
    
    // RAM接口
    output reg[12:0]    s_ram_addr,     // RAM读取地址
    input [15:0]        s_ram_data,     // RAM输出数据
    
    // FFT控制接口
    output reg          fft_ctrl,       // FFT启动控制（持续高时，FFT正常接收信号）  
    input               fft_flag,       // FFT运行标志（高为输出写入RAM，低为其他）  
    
    //下混频交互接口
    output              m_sta_ram_trav,     // fft_detect在RAM_TRAV的标志位               
    input [6:0]         s_convert_config_step,// 下混频的频率步进量（对应频率转换看costas_fft）          
    
    // uart_ctrl控制接口
    output reg [15:0]   m_uart_ctrl_addr,       // 上报频点地址   
    output reg [15:0]   m_uart_ctrl_data,       // 上报频点幅值   
    output reg          m_uart_ctrl_valid,      // 数据有效标志   
    input               m_uart_ctrl_ready,      // 上位机接收就绪  
    output reg [7:0]    m_uart_ctrl_extra,      // 额外数据，[7:1]的下混频信息 [0]的XSK信息
    output reg          m_uart_ctrl_end         // 数据帧传输结束标志 
    ); 
    //参数定义   
    localparam REGISTERS_LENGTH = 'd50; //离散谱寄存器数量
    localparam SMALL_THRESHOILD = 'd30; //小阈值，根据噪声功率修改,检测XSK信号的连续谱
    localparam SMALL_THRES_NUMS = 'd20; //64个信号中出现大于小阈值的数量
    localparam LARGE_THRESHOILD = 'd150; //大阈值，根据前级信号增益修改，检测离散谱
    
    //状态定义
    localparam FFT_IDLE = 'd0;      // 空闲状态，此时FFT工作      
    localparam FFT_WAIT = 'd1;      // 等待FFT写入RAM   
    localparam RAM_TRAV = 'd2;      // RAM扫描分析   
    localparam UART_SEND = 'd3;     // UART数据帧发送  
    
    //内部信号规范
    wire                aclk = sys_clk;
    wire                rstn = sys_rstn;
    
    //状态机控制信号
    reg [3:0]           nex_sta;
    reg [3:0]           cur_sta;
    reg [1:0]           ready_cnt;      //ready拉低的延时计数器
    
    // 连续谱分析计数器
    reg [5:0]           time_cnt;           //64时钟计数器
    reg [5:0]           small_thres_cnt;    //小阈值计数器（64时钟重置）
    
    // 离散谱存储（大阈值）
    reg [15:0]          large_data_reg [REGISTERS_LENGTH-1:0];  // 离散谱幅值存储   
    reg [15:0]          large_addr_reg [REGISTERS_LENGTH-1:0];  // 离散谱地址存储   
    reg [7:0]           large_reg_cnt;                          // 有效离散谱计数   
    
    // uart_ctrl发送计数器
    reg [7:0]           uart_data_cnt;                              
    
    assign m_sta_ram_trav = (cur_sta == RAM_TRAV) ? 1'b1 : 1'b0;
    
    //状态机第一段
    always @(posedge aclk or negedge rstn) begin
        if(!rstn)cur_sta <= 'b0;
        else cur_sta <= nex_sta;
    end
    
    //状态机第二段
    always @(*) begin
        case(cur_sta)
            FFT_IDLE : begin    
                if(fft_flag) nex_sta = FFT_WAIT;
                else nex_sta = FFT_IDLE;
            end
            FFT_WAIT : begin
                if(!fft_flag) nex_sta = RAM_TRAV;
                else nex_sta = FFT_WAIT;
            end
            RAM_TRAV : begin
                if(s_ram_addr == 'h1fff) nex_sta = UART_SEND;
                //离散谱计数大于寄存器上限，视作信号过脏，舍弃该帧数据，重新fft
                else if(large_reg_cnt == REGISTERS_LENGTH) nex_sta = FFT_IDLE;
                else nex_sta = RAM_TRAV;
            end
            UART_SEND : begin
                if(uart_data_cnt == large_reg_cnt) nex_sta = FFT_IDLE;
                else nex_sta = UART_SEND;
            end
        endcase
    end
    
    //状态机第三段
    always @(posedge aclk or negedge rstn) begin
        if(!rstn) begin 
            fft_ctrl <= 1'b0;
            m_uart_ctrl_addr <= 'b0;
            m_uart_ctrl_data <= 'b0;         
            m_uart_ctrl_valid <= 1'b0;
            m_uart_ctrl_extra <= 'b0;  
            
            s_ram_addr <= 'b0;   
            m_uart_ctrl_end <= 'b0;      
            time_cnt <= 'b0;           
            small_thres_cnt <= 'b0;    
            large_reg_cnt <= 'b0;      
            uart_data_cnt <= 'b0; 
            ready_cnt <= 'b0;         
        end else begin
            fft_ctrl <= 1'b0;
            m_uart_ctrl_valid <= 1'b0;
            case(cur_sta)
                FFT_IDLE : begin
                    // 启动FFT处理
                    fft_ctrl <= 1'b1; 
                    m_uart_ctrl_end <= 1'b1;      
                end
                FFT_WAIT : begin
                    //某些参数的初始化
                    s_ram_addr <= 'b0;
                    time_cnt <= 'b0;
                    small_thres_cnt <= 'b0;
                    m_uart_ctrl_extra <= 'b0; 
                    m_uart_ctrl_end <= 'b0;
                    large_reg_cnt <= 'b0;
                    uart_data_cnt <= 'b0;
                    ready_cnt <= 'b0;
                end
                RAM_TRAV : begin
                    s_ram_addr <= s_ram_addr + 1'b1;  
                    time_cnt <= time_cnt + 1'b1;
                    m_uart_ctrl_extra[7:1] <= s_convert_config_step;
                    if(time_cnt == 6'h3f)begin    //time_cnt计数器为63时，检验small_thres_cnt小阈值数量
                        small_thres_cnt <= 'b0;                 //超过视作信号为2XSK信号
                        if(small_thres_cnt > SMALL_THRES_NUMS)
                            m_uart_ctrl_extra[0] <= 1'b1;
                    end
                    if(s_ram_data > SMALL_THRESHOILD)       //大于小阈值，small_thres_cnt加一
                        small_thres_cnt <= small_thres_cnt + 1'b1; 
                    if(s_ram_data > LARGE_THRESHOILD&&s_ram_addr >= 'd3)begin  //大于大阈值，离散谱存储更新
                        large_data_reg[large_reg_cnt] <= s_ram_data;
                        large_addr_reg[large_reg_cnt] <= {3'b0,s_ram_addr};
                        large_reg_cnt <= large_reg_cnt + 1'b1;
                    end             
                end
                UART_SEND : begin
                    if(ready_cnt == 2'b11)begin
                        if(m_uart_ctrl_ready)begin  //uart_ctrl就绪
                            ready_cnt <= 'b0;       // 延时计数器重置        
                            if(uart_data_cnt == large_reg_cnt)begin
                                m_uart_ctrl_end <= 1'b1;
                            end else begin
                                m_uart_ctrl_valid <= 1'b1;      //发送一个时钟的使能和数据
                                m_uart_ctrl_data <= large_data_reg[uart_data_cnt];
                                m_uart_ctrl_addr <= large_addr_reg[uart_data_cnt];
                                uart_data_cnt <= uart_data_cnt + 1'b1;
                            end
                        end
                    end else ready_cnt <= ready_cnt + 1;
                end 
            endcase
        end
    end

    
endmodule

