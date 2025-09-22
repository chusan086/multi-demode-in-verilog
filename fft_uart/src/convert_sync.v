`timescale 1ns / 1ps
module convert_sync(
    input               sys_clk,
    input               sys_rstn,
    
    input [15:0]        convert_freq_data,  //大信号频率对应地址       
    input               convert_freq_valid,                  
    
    input               s_sta_ram_trav,         // fft_detect在RAM_TRAV的标志位
    
    output reg[31:0]    m_convert_config_data,  //下混频的频率控制字
    output reg[6:0]     m_convert_config_step     //下混频的频率步量           
    );
    
    //三个参数都是频率控制字！！！
    localparam FREQ_OFFST = 'd0;            //起始频率控制字偏移    
    //(0.25MHz)                  
    localparam FREQ_RESOL = 'd21_474_836;   //频率控制字分辨率
    //计算公式：K = f0*(2^32)/50MHz = addr*(2^22)
    localparam FREQ_COEFF = 'd22;            //频率控制字转换位移系数
    
    wire aclk = sys_clk;                    //预留时钟修改余地
    wire rstn = sys_rstn;
    
    //第一层接口
    reg[31:0]           m_dds_config_data_reg;     // 频率控制字暂存寄存器
    reg[6:0]            m_dds_freq_step_reg;       // 频率步进量暂存寄存器
    
    localparam IDLE = 'd0;                // 空闲状态               
    localparam CALC = 'd1;                // 计算状态 
    //第二层状态机控制信号
    reg [3:0]           nex_sta;
    reg [3:0]           cur_sta;
    
    //第二层接口
    reg [31:0]          freq_reg;                   //频率寄存器
    reg [31:0]          freq_compare_reg;           //比较寄存器
    reg [6:0]           freq_step_reg;              
    
    //两层单元遵循类似JK触发器的逻辑，
    //s_sta_ram_trav为0第一层锁定，s_sta_ram_trav为1第二层锁定
    //第一层赋值单元，在s_sta_ram_trav时向output传递计算结果
    always @(posedge sys_clk or negedge sys_rstn)begin
        if(!sys_rstn)begin
            m_convert_config_data <= 'b0;
            m_convert_config_step <= 'b0;
        end else if(s_sta_ram_trav) begin
            m_convert_config_data <= m_dds_config_data_reg;
            m_convert_config_step <= m_dds_freq_step_reg;
        end else begin
            m_convert_config_data <= m_convert_config_data;
            m_convert_config_step <= m_convert_config_step;
        end  
    end
    
    //第二层计算单元，在！s_sta_ram_trav工作，并向第一层传递计算结果
    //状态机第一段
    always @(posedge aclk or negedge rstn) begin
        if(!rstn)cur_sta <= 'b0;
        else cur_sta <= nex_sta;
    end
    
    //状态机第二段
    always @(*) begin
        case(cur_sta)
            IDLE : begin    
                if(!s_sta_ram_trav&&convert_freq_valid) nex_sta = CALC;
                else nex_sta = IDLE;
            end
            CALC : begin
                if(s_sta_ram_trav || freq_compare_reg > freq_reg) nex_sta = IDLE;
                else nex_sta = CALC;
            end
        endcase
    end
    
    always @(posedge sys_clk or negedge sys_rstn)begin
        if(!sys_rstn)begin
            freq_reg <= 'b0;
            freq_compare_reg <= 'b0;
            freq_step_reg <= 'b0;
            m_dds_config_data_reg <= 'b0;
            m_dds_freq_step_reg <= 'b0;
        end else begin
            case(cur_sta)
                IDLE : begin
                    if(!s_sta_ram_trav&&convert_freq_valid)begin
                        // 计算目标频率控制字（地址值左移22位，地址>=3时减去3的偏移）
                        if(convert_freq_data >= 3)
                            freq_reg <= (convert_freq_data - 3) << FREQ_COEFF;
                        else  freq_reg <= convert_freq_data << FREQ_COEFF;
                    end
                    //复位寄存器
                    freq_compare_reg <= FREQ_OFFST;    
                    freq_step_reg <= 'd0;        
                end 
                CALC : begin
                    if(!s_sta_ram_trav && freq_compare_reg > freq_reg) begin
                        // 保存比输入频率小的最大步进频率控制字
                        m_dds_config_data_reg <= freq_compare_reg - (FREQ_RESOL<<1);
                        m_dds_freq_step_reg <= freq_step_reg - 'd2;
                    end else begin
                        // 逐步增加频率直到超过目标值
                        freq_compare_reg <= freq_compare_reg + FREQ_RESOL;
                        freq_step_reg <= freq_step_reg + 'd1;
                    end
                end
            endcase
        end    
    end
endmodule
    