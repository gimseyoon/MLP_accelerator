`timescale 1ns / 1ps

module glbl_ctrl #(
    parameter MAX_NUMBER_PIC = 10
)(
    //system interface
    input   wire                        clk,
    input   wire                        rst_n,
    input   wire                        start_i,
    output  wire                        done_intr_o,
    output  wire                        done_led_o,

    //processing unit interface
    output  wire                        ctrl_en,
    output  wire                        state_done,  //start_i가 on일 때, ps가 바뀔 때, count시작 지점을 알려준다. - 이름: idle부터 다음 state로 넘어갈 때마다 1을 출력하니까.
    output  wire    [3:0]               done_pic_count,
    output  wire    [2:0]               ps,
    output  wire                        mac_en,    
    output  wire                        signal,
    
    //buffer address
    output  wire                        x_buf_en,
    output  wire                        w_buf_en,
    output  wire [12:0]                 x_addr,
    output  wire [9:0]                  w_addr,
    
    output  wire                        temp_en,
    output  wire                        temp_wen,
    output  wire [5:0]                  temp_buf_addr,
    
    output  wire                        y_en,
    output  wire                        y_wen,
    output  wire [9:0]                  y_buf_addr
    
);
    // Design your own logic!
    // It may contain FSM and driviing controller signals. 
    localparam IDLE = 3'b000, LAYER1 = 3'b001, LAYER2 = 3'b010, LAYER3 = 3'b011, LAYER4 = 3'b100, LAYER5 = 3'b101, DONE = 3'b110;
    localparam PU_DELAY = 3;
    
    reg mac_en_w;
    reg [2:0] present_state, next_state;
    reg [3:0] cnt_output;
    reg [6:0] cnt_state;
    wire [5:0] temp_buf_addr_w;
    wire [12:0] x_addr_w;
    wire [15:0] w_addr_w;
    reg done_intr_w, done_led_w, ctrl_en_w ,state_done_w;
    wire prcss_done, x_buf_en_w, w_buf_en_w, temp_en_w, temp_wen_w; //wen신호 뽑아주기.
    reg [PU_DELAY-1:0] mac_delay;
    
    assign x_buf_en = x_buf_en_w;
    assign w_buf_en = w_buf_en_w;
    assign x_addr = x_addr_w;
    assign w_addr = w_addr_w;
    assign temp_en = temp_en_w /*|| (ps!=1 && w_buf_en_w)*/;
    assign temp_wen = temp_wen_w;
    assign temp_buf_addr = temp_buf_addr_w;
    assign mac_en = mac_en_w;
    
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        mac_en_w <= 0; end
    else begin
        mac_en_w <= w_buf_en_w; end
end


addr_counter#(
    .INPUT_BIT(13), //max - 784
    .WEIGHT_BIT(10), //max - 784
    .TEMP_BIT(7),  //max - 64
    .Y_BIT(10),
    .COUNTER_BIT(10) //max - 784          
    ) dut(
        //제어 신호
        .clk(clk),
        .rst_n(rst_n),
        .prcss_en(ctrl_en_w), 
        .state_done(state_done),
        .mac_done(mac_delay[2]), //추가됨.
        .ps(present_state),
        .done_pic_count(cnt_output),
        .prcss_done(prcss_done),
        //읽기 전용으로 쓰는 버퍼.
        .x_buf_en(x_buf_en_w),
        .w_buf_en(w_buf_en_w),
        .x_buf_addr(x_addr_w),
        .w_buf_addr(w_addr_w),
        //읽고 써야 하는 버퍼. : en하고 wen이 동시에 들어와야 쓰기 가능.
        .temp_en(temp_en_w),
        .temp_wen(temp_wen_w),
        .temp_buf_addr(temp_buf_addr_w),
        .y_en(y_en),
        .y_wen(y_wen),
        .y_buf_addr(y_buf_addr),
        .signal(signal)
    );


always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        present_state <= IDLE; end
    else begin
        present_state <= next_state; end
end

//next state 정하기
reg start_w;
reg [1:0] prcss_done_w;
always@(posedge clk)begin
    if(!rst_n)begin
        start_w <= 0;
        prcss_done_w <= 0;
    end
    else begin
        start_w <= start_i;
        if(prcss_done) prcss_done_w <= prcss_done_w + 1;
    end
end

always@(*) begin
    case(present_state) 
        IDLE : begin
            if(start_w) next_state = LAYER1;
            else        next_state = IDLE;  
        end
        LAYER1 : begin
            if(prcss_done_w == 2)  next_state = LAYER2; 
            else           next_state = LAYER1; 
        end
        LAYER2 : begin
            if(prcss_done_w == 2) next_state = LAYER3; 
            else           next_state = LAYER2; 
        end
        LAYER3 : begin
            if(prcss_done_w == 2) next_state = LAYER4; 
            else           next_state = LAYER3; 
        end
        LAYER4 : begin
            if(prcss_done_w == 2) next_state = LAYER5; 
            else           next_state = LAYER4; 
        end
        LAYER5 : begin
            if(cnt_state == MAX_NUMBER_PIC*5 + 1)   next_state = DONE;
            else if(cnt_state == MAX_NUMBER_PIC*5) next_state = LAYER5; 
            else if(prcss_done_w == 2) next_state = LAYER1; 
            else           next_state = LAYER5; 
        end
        DONE : begin
            next_state = DONE;
        end
       default : begin
            next_state = IDLE; end
     endcase
end
    //mac delay신호를 준다.
    always@(posedge clk)begin
        if(!rst_n)begin
            mac_delay <= 0;
        end
        else begin
            if(present_state != next_state)begin 
                mac_delay <= 0; 
            end
            else begin
                mac_delay[0] <= prcss_done;
                mac_delay[1] <= mac_delay[0];
                mac_delay[2] <= mac_delay[1];
            end
        end
    end
    
    //현재 state 별 신호 결정.
     assign done_intr_o = done_intr_w;
     assign done_led_o = done_led_w;
     assign ps = present_state;
     assign done_pic_count = cnt_output;
     assign ctrl_en = ctrl_en_w;
     assign state_done = state_done_w;
     
     always@(posedge clk)begin
        if(!rst_n)begin
            cnt_output <= 0;
            done_intr_w <= 0; done_led_w <= 0;
            cnt_state <= 0;
            ctrl_en_w <= 0;
            state_done_w <= 0;
            prcss_done_w <= 0;
        end
        else begin
            case(present_state) 
                IDLE : begin
                    cnt_output <= 0;
                    done_intr_w <= 0; done_led_w <= 0;
                    ctrl_en_w <= 0;
                    if(start_w) begin
                        cnt_state = cnt_state + 1; state_done_w <= 1;
                        prcss_done_w <= 0;
                    end
                    else  begin 
                        cnt_state <= cnt_state; state_done_w <= 0;
                        //prcss_done_w <= prcss_done_w;
                    end
                end
                LAYER1 : begin 
                    cnt_output <= cnt_output;
                    done_intr_w <= 0; done_led_w <= 0;
                    ctrl_en_w <= 1;
                    if(prcss_done_w == 2) begin
                        cnt_state = cnt_state + 1; state_done_w <= 1;
                        prcss_done_w <= 0;
                    end
                    else  begin 
                        cnt_state <= cnt_state; state_done_w <= 0;
                        //prcss_done_w <= prcss_done_w;
                    end
                end
                LAYER2 : begin
                    cnt_output <= cnt_output;
                    done_intr_w <= 0; done_led_w <= 0;
                    ctrl_en_w <= 1;
                    if(prcss_done_w == 2) begin
                        cnt_state = cnt_state + 1; state_done_w <= 1;
                        prcss_done_w <= 0;
                    end
                    else  begin 
                        cnt_state <= cnt_state; state_done_w <= 0;
                        //prcss_done_w <= prcss_done_w;
                    end
                end
                LAYER3 : begin
                    cnt_output <= cnt_output;
                    done_intr_w <= 0; done_led_w <= 0;
                    ctrl_en_w <= 1;
                    if(prcss_done_w == 2) begin
                        cnt_state = cnt_state + 1; state_done_w <= 1;
                        prcss_done_w <= 0;
                    end
                    else  begin 
                        cnt_state <= cnt_state; state_done_w <= 0;
                        //prcss_done_w <= prcss_done_w;
                    end
                end
                LAYER4 : begin
                    cnt_output <= cnt_output;
                    done_intr_w <= 0; done_led_w <= 0;
                    ctrl_en_w <= 1;
                    if(prcss_done_w == 2) begin
                        cnt_state = cnt_state + 1; state_done_w <= 1;
                        prcss_done_w <= 0;
                    end
                    else  begin 
                        cnt_state <= cnt_state; state_done_w <= 0;
                        //prcss_done_w <= prcss_done_w;
                    end
                end
                LAYER5 : begin
                    if(prcss_done_w == 2)begin
                        cnt_output <= cnt_output + 1;
                        done_intr_w <= 0; done_led_w <= 0;
                        cnt_state = cnt_state + 1;
                        ctrl_en_w <= 1;
                        state_done_w <= 1;
                        prcss_done_w <= 0;
                    end
                    else begin
                        cnt_output <= cnt_output;
                        done_intr_w <= 0; done_led_w <= 0;
                        cnt_state <= cnt_state;
                        ctrl_en_w <= 1;
                        state_done_w <= 0;
                        //prcss_done_w <= 0;
                    end
                end
                DONE : begin
                    cnt_output <= 0;
                    done_intr_w <= 1; done_led_w <= 1;
                    cnt_state <= 0;
                    ctrl_en_w <= 0;
                    state_done_w <= 0;
                    prcss_done_w <= 0;
                end
                default : begin
                    cnt_output <= 0;
                    done_intr_w <= 0; done_led_w <= 0;
                    cnt_state <= 0;
                    ctrl_en_w <= 0;
                    state_done_w <= 0;
                    prcss_done_w <= 0;
                end
         endcase
        end
     end

    
endmodule
