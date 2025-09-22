`timescale 1ns / 1ps
// fft_detect�ļ򻯰棬�򵥵��ҵ�������ֵ��Ƶ�ʵ㣬
// �����õ���Ƶ�������壬��Ϊ�»�Ƶ�Ĳο�Ƶ�����
module convert_detect(
    input                   sys_clk,            // ϵͳʱ�ӣ�50MH
    input                   sys_rstn,           // ϵͳ��λ������Ч��
    
    // RAM�ӿ�
    output reg[8:0]     s_fftmini_ram_addr,     // RAM��ȡ��ַ
    input [15:0]        s_fftmini_ram_data,     // RAM�������
    
    // FFT���ƽӿ�
    output reg          fftmini_ctrl,       // FFT�������ƣ�������ʱ��FFT���������źţ�  
    input               fftmini_flag,       // FFT���б�־����Ϊ���д��RAM����Ϊ������  
    
    output reg [15:0]   convert_freq_data,  //�»�Ƶ��Ӧ��ַ             
    output reg          convert_freq_valid
    );
    //��������   
    localparam LARGE_THRESHOILD = 'd200; //����ֵ������ǰ���ź������޸ģ������ɢ��
    
    //״̬����
    localparam FFT_IDLE = 'd0;      // ����״̬����ʱFFT����      
    localparam FFT_WAIT = 'd1;      // �ȴ�FFTд��RAM   
    localparam RAM_TRAV = 'd2;      // RAMɨ�����   
    
    //�ڲ��źŹ淶
    wire                aclk = sys_clk;
    wire                rstn = sys_rstn;
    
    //״̬�������ź�
    reg [3:0]           nex_sta;
    reg [3:0]           cur_sta;
                            
    //״̬����һ��
    always @(posedge aclk or negedge rstn) begin
        if(!rstn)cur_sta <= 'b0;
        else cur_sta <= nex_sta;
    end
    
    //״̬���ڶ���
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
    
    //״̬��������
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
                    // ����FFT����
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
    