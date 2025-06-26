`timescale 1ns / 1ps
//전체구조 설명
// 출력포트와 내부변수  assign으로 연결.
// ps에 따라 각 카운터의 max_value 결정.
// 1차원 카운터를 만든다.

/*
   |- D2로 세기.               |-쓰기에 필요한 거는 1addr
1*784         784*64         1*64   mac:64
1*64          64*32          1*32   mac:64
1*32          32*32          1*32   mac:32
1*32          32*16          1*16   mac:32
1*16          16*10          1*10   mac:16
                  |- D1으로 세기.
buff에서 출력                 buff에 입력
|=============================>|-->
*/

module addr_counter#(
    parameter INPUT_BIT = 13, //max - 784
    parameter WEIGHT_BIT = 10, //max - 784
    parameter TEMP_BIT = 7,  //max - 64
    parameter Y_BIT = 10,
    parameter COUNTER_BIT = 10 //max - 784          
    )(
        //제어 신호
        input   wire                                    clk,
        input   wire                                    rst_n,
        input   wire                                    prcss_en, 
        input   wire                                    state_done,
        input   wire                                    mac_done, //추가됨.
        input   wire [2:0]                              ps, 
        input   wire [3:0]                              done_pic_count,
        output  wire                                    prcss_done,
        //읽기 전용으로 쓰는 버퍼.
        output  wire                                    x_buf_en,
        output  wire                                    w_buf_en,
        output  wire [INPUT_BIT-1:0]                    x_buf_addr,
        output  wire [WEIGHT_BIT-1:0]                   w_buf_addr,
        //읽고 써야 하는 버퍼. : en하고 wen이 동시에 들어와야 쓰기 가능.
        output  wire                                    temp_en,
        output  wire                                    temp_wen,
        output  wire [TEMP_BIT-1:0]                     temp_buf_addr,
        
        output  wire                                    y_en,
        output  wire                                    y_wen,
        output  wire [Y_BIT-1:0]                        y_buf_addr,
        output  wire                                    signal
    );
    
    //각 layer별 MAX값.
    localparam LAYER_1_ROW = 784;
    localparam LAYER_1_COLUMN = 64;
    
    localparam LAYER_2_ROW = 64;
    localparam LAYER_2_COLUMN = 32;
    
    localparam LAYER_3_ROW = 32;
    localparam LAYER_3_COLUMN = 32;
    
    localparam LAYER_4_ROW = 32;
    localparam LAYER_4_COLUMN = 16;
    
    localparam LAYER_5_ROW = 16;
    localparam LAYER_5_COLUMN = 10;
    
    localparam Y_ADDR = 4;
    localparam ONE_LAYER_MAX_Y_ADDR = 40;
    
    //각 변수 정의
    reg                     prcss_done_w, 
                            x_buf_en_w,
                            w_buf_en_w,
                            temp_en_w,
                            temp_wen_w, 
                            mac_done_w,
                            y_en_w,
                            y_wen_w;
    
    reg [COUNTER_BIT-1:0]        counter, counter_MAX, counter_delay;
    
    reg signal_w;
    assign signal = signal_w;
    
always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            signal_w <= 0; end
        else begin
                case(ps) 
                    1 : begin   
                            if(mac_done) begin
                                 signal_w <= 1; end
                            else begin
                                if(counter_delay == 62) begin
                                    signal_w <= 0; end
                                else begin
                                    signal_w <= signal_w; end
                            end
                        end
                        
                    2 : begin   
                            if(mac_done) begin
                                 signal_w <= 1; end
                            else begin
                                if(counter_delay == 30) begin
                                    signal_w <= 0; end
                                else begin
                                    signal_w <= signal_w; end
                            end
                        end
                      
                    3 : begin   
                            if(mac_done) begin
                                 signal_w <= 1; end
                            else begin
                                if(counter_delay == 30) begin
                                    signal_w <= 0; end
                                else begin
                                    signal_w <= signal_w; end
                            end
                        end
                      
                   4 : begin   
                            if(mac_done) begin
                                 signal_w <= 1; end
                            else begin
                                if(counter_delay == 14) begin
                                    signal_w <= 0; end
                                else begin
                                    signal_w <= signal_w; end
                            end
                        end
                      
                    5 : begin   
                            if(mac_done) begin
                                 signal_w <= 1; end
                            else begin
                                if(counter_delay == 8) begin
                                    signal_w <= 0; end
                                else begin
                                    signal_w <= signal_w; end
                            end
                        end
                   endcase
                   end
            
 end
      
                       
                        
                    
    
    // 출력포트와 내부변수  assign으로 연결.
    assign prcss_done = prcss_done_w;
    
    assign x_buf_en = (ps!=1) ? 0 : (mac_done_w) ? 0 : x_buf_en_w;
    assign w_buf_en = (ps==6) ? 0 : (mac_done_w) ? 0 : w_buf_en_w;
    assign x_buf_addr = (x_buf_en) ? counter_delay + LAYER_1_ROW * done_pic_count : 0;
    assign w_buf_addr = (w_buf_en) ? counter_delay : 0;
    
    assign temp_en = (ps==6) ? 0 : (mac_done_w) ? temp_en_w : 0 || (ps!=1 && w_buf_en_w);
    assign temp_wen = (ps==6) ? 0 : (mac_done_w) ? temp_wen_w : 0;
    assign temp_buf_addr = temp_en ? counter_delay : 0;
    
    assign y_en = (ps==5) ? ( (ps==6) ? 0 : (mac_done_w) ? y_en_w : 0 ): 0;
    assign y_wen = (ps==5) ? ( (ps==6) ? 0 : (mac_done_w) ? y_wen_w : 0 ): 0;
    assign y_buf_addr = (y_en) ? Y_ADDR * counter_delay + done_pic_count * ONE_LAYER_MAX_Y_ADDR : 0;
    
    // ps에 따라 각 카운터의 max_value 결정.
    always@(*)begin
        if(!rst_n)begin
            counter_MAX = LAYER_1_ROW;
        end
        else begin
            
            case(ps)
                0:begin
                    if(mac_done_w)begin counter_MAX = LAYER_1_COLUMN; end
                    else begin counter_MAX = LAYER_1_ROW; end
                end
                1:begin
                    if(mac_done_w)begin counter_MAX = LAYER_1_COLUMN; end
                    else begin counter_MAX = LAYER_1_ROW; end
                end
                2:begin
                    if(mac_done_w)begin counter_MAX = LAYER_2_COLUMN; end
                    else begin counter_MAX = LAYER_2_ROW; end
                end
                3:begin
                    if(mac_done_w)begin counter_MAX = LAYER_3_COLUMN; end
                    else begin counter_MAX = LAYER_3_ROW; end
                end
                4:begin
                    if(mac_done_w)begin counter_MAX = LAYER_4_COLUMN; end
                    else begin counter_MAX = LAYER_4_ROW; end
                end
                5:begin
                    if(mac_done_w)begin counter_MAX = LAYER_5_COLUMN; end
                    else begin counter_MAX = LAYER_5_ROW; end
                end
                6:begin
                    if(mac_done_w)begin counter_MAX = LAYER_5_COLUMN; end
                    else begin counter_MAX = LAYER_5_ROW; end
                end
                default:begin
                    if(mac_done_w)begin counter_MAX = LAYER_1_COLUMN; end
                    else begin counter_MAX = LAYER_1_ROW; end
                end
            endcase
            
        end
    end
    
    //필요한 입력 신호 유지 및 제어.
    reg state_done_w; //1이 들어오는 순간부터 count하기. + counter가 해당 값에 도달할 때까지, 신호유지.
    
    always@(posedge clk)begin
        if(!rst_n)begin
            state_done_w<=0;
        end
        else begin
            if(state_done)begin
                state_done_w <= 1;
            end
            else if(mac_done)begin
                state_done_w <= state_done_w;
            end
            else if(counter == counter_MAX)begin
                state_done_w <= 0;
            end
        end
    end
    
    always@(posedge clk)begin
        if(!rst_n)begin
            mac_done_w<=0;
        end
        else begin
            if(mac_done)begin
                mac_done_w <= 1;
            end
            else if(counter == counter_MAX)begin
                mac_done_w <= 0;
            end
        end
    end
    
    // 2차원 카운터를 만든다 1D를 세고, 1D에 의해 2를 세도록. ex) 1D가 10일 때마다 2D를 1개 센다.
    // + 각 제어 신호에 대한 출력을 결정한다.
    always@(posedge clk)begin
        if(!rst_n)begin
            prcss_done_w <= 0;
            x_buf_en_w <= 0;
            w_buf_en_w <= 0;
            temp_en_w <= 0;
            temp_wen_w <= 0;
            y_en_w <= 0;
            y_wen_w <= 0;
            counter <= 0;
            counter_delay <= 0;
        end
        else begin
            if(prcss_en && (state_done_w||mac_done_w))begin
                
                if(counter == counter_MAX)begin
                    prcss_done_w <= 0;
                    x_buf_en_w <= 0;
                    w_buf_en_w <= 0;
                    temp_en_w <= 0;
                    temp_wen_w <= 0;
                    y_en_w <= 0;
                    y_wen_w <= 0;
                    counter <= 0;
                    counter_delay <= counter;
                end
                else if(counter == counter_MAX-1)begin
                    prcss_done_w <= 1;
                    x_buf_en_w <= 1;
                    w_buf_en_w <= 1;
                    temp_en_w <= 1;
                    temp_wen_w <= 1;
                    y_en_w <= 1;
                    y_wen_w <= 1;
                    counter <= counter + 1;
                    counter_delay <= counter;
                end
                else begin
                    prcss_done_w <= 0;
                    x_buf_en_w <= 1;
                    w_buf_en_w <= 1;
                    temp_en_w <= 1;
                    temp_wen_w <= 1;
                    y_en_w <= 1;
                    y_wen_w <= 1;
                    counter <= counter + 1;
                    counter_delay <= counter;
                end
                
            end
            else begin
                prcss_done_w <= 0;
                x_buf_en_w <= 0;
                w_buf_en_w <= 0;
                temp_en_w <= 0;
                temp_wen_w <= 0;
                y_en_w <= 0;
                y_wen_w <= 0;
                counter <= 0;
                counter_delay <= counter;
            end
        end
        
    end
    
    
endmodule
