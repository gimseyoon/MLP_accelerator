`timescale 1ns / 1ps

module top_mlp #(
    parameter IN_IMG_NUM = 10,  //total images
	parameter X_BW = 25,   // In a input file, 1 row = 7 hex = 28 bit, but max value is 25 bit, so we use only 25 bit 
	parameter W_BW = 1280, // In weight files, 1 row = 320 hex = 1280 bit

	parameter X_DEPTH = 784*IN_IMG_NUM,
	parameter W1_DEPTH = 784,
	parameter W2_DEPTH = 64,
	parameter W3_DEPTH = 32,
	parameter W4_DEPTH = 32,
	parameter W5_DEPTH = 16,	
	
    parameter Y_BUF_DATA_WIDTH = 32,
	parameter Y_BUF_ADDR_WIDTH = 32,  				
    parameter Y_BUF_DEPTH = 10*IN_IMG_NUM * 4 			
)(
    // system interface
    input   wire                            clk,
    input   wire                            rst_n,
    input   wire                            start_i,
    output  wire                            done_intr_o,
    output  wire                            done_led_o,
    // output buffer interface
    output  wire                            y_buf_en,
    output  wire                            y_buf_wr_en,
    output  wire [Y_BUF_ADDR_WIDTH-1:0]     y_buf_addr,		
    output  wire [Y_BUF_DATA_WIDTH-1:0]     y_buf_data
);

    localparam X_BUF_INIT_FILE =  "C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/input_file/image_#10.txt";
    localparam W1_BUF_INIT_FILE =  "C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/weight/weight/weight1.txt";
    localparam W2_BUF_INIT_FILE =  "C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/weight/weight/weight2.txt";
    localparam W3_BUF_INIT_FILE =  "C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/weight/weight/weight3.txt";
    localparam W4_BUF_INIT_FILE =  "C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/weight/weight/weight4.txt";
    localparam W5_BUF_INIT_FILE =  "C:/Digital_Circuit_Design_Project_ZIP/seoultech_MLP_accelerator/weight/weight/weight5.txt";
    
wire x_en;
wire [12:0] x_addr;    
wire signed [X_BW-1:0] x_data;  

wire w_en;
wire [9:0] w_addr;

wire signed [W_BW-1:0] w1_data;
wire signed [W_BW-1:0] w2_data;
wire signed [W_BW-1:0] w3_data;
wire signed [W_BW-1:0] w4_data;
wire signed [W_BW-1:0] w5_data;

wire temp_en_w;
wire temp_wen_w;
wire [5:0] temp_addr_w;

wire signed [X_BW-1:0] temp_data;

wire signed [24:0] pu_out1;
wire signed [31:0] pu_out2;   

////////////////////////////////glbl_crtl
wire clear_w;
wire [3:0] done_pic_count_w;
wire [2:0] ps_w;
wire mac_en_w;
wire signal_w;
    
////////////////////////////////    
////////////x_buffer////////////
////////////////////////////////   
    
single_port_bram  #(
        .WIDTH(X_BW),
        .DEPTH(X_DEPTH),
        .INIT_FILE(X_BUF_INIT_FILE)
    ) x_buffer (
        .clk(clk),
        .en(x_en),
        .wen(),
        .addr(x_addr),
        .din(),
        .dout(x_data)
     );

////////////////////////////////    
////////////w1_buffer////////////
////////////////////////////////   
    
single_port_bram  #(
        .WIDTH(W_BW),
        .DEPTH(W1_DEPTH),
        .INIT_FILE(W1_BUF_INIT_FILE)
    ) w1_buffer (
        .clk(clk),
        .en(w_en&&(ps_w==3'b001)),
        .wen(),
        .addr(w_addr),
        .din(),
        .dout(w1_data)
     );    
    
////////////////////////////////    
////////////w2_buffer////////////
////////////////////////////////   
    
single_port_bram  #(
        .WIDTH(W_BW),
        .DEPTH(W2_DEPTH),
        .INIT_FILE(W2_BUF_INIT_FILE)
    ) w2_buffer (
        .clk(clk),
        .en(w_en&&(ps_w==3'b010)),
        .wen(),
        .addr(w_addr),
        .din(),
        .dout(w2_data)
     );       
    
////////////////////////////////    
////////////w3_buffer////////////
////////////////////////////////   
    
single_port_bram  #(
        .WIDTH(W_BW),
        .DEPTH(W3_DEPTH),
        .INIT_FILE(W3_BUF_INIT_FILE)
    ) w3_buffer (
        .clk(clk),
        .en(w_en&&(ps_w==3'b011)),
        .wen(),
        .addr(w_addr),
        .din(),
        .dout(w3_data)
     );       
    
////////////////////////////////    
////////////w4_buffer////////////
////////////////////////////////   
    
single_port_bram  #(
        .WIDTH(W_BW),
        .DEPTH(W4_DEPTH),
        .INIT_FILE(W4_BUF_INIT_FILE)
    ) w4_buffer (
        .clk(clk),
        .en(w_en&&(ps_w==3'b100)),
        .wen(),
        .addr(w_addr),
        .din(),
        .dout(w4_data)
     );       
    
////////////////////////////////    
////////////w5_buffer////////////
////////////////////////////////   
    
single_port_bram  #(
        .WIDTH(W_BW),
        .DEPTH(W5_DEPTH),
        .INIT_FILE(W5_BUF_INIT_FILE)
    ) w5_buffer (
        .clk(clk),
        .en(w_en&&(ps_w==3'b101)),
        .wen(),
        .addr(w_addr),
        .din(),
        .dout(w5_data)
     );       
    
///////////////////////////////// 
///////////temp_buffer///////////
////////////////////////////////   

    
single_port_bram  #(
        .WIDTH(X_BW),
        .DEPTH(W2_DEPTH),
        .INIT_FILE()
    ) temp_buffer (
        .clk(clk),
        .en(temp_en_w),
        .wen(temp_wen_w),
        .addr(temp_addr_w),
        .din(pu_out1),
        .dout(temp_data)
     );       
    
    
////////////////////////////////    
///////////glbl_ctrl////////////
////////////////////////////////    



    
glbl_ctrl #(
    .MAX_NUMBER_PIC(IN_IMG_NUM)
) mlp_ctrl (
.clk(clk),
.rst_n(rst_n),
.start_i(start_i),
.done_intr_o(done_intr_o),
.done_led_o(done_led_o),

.ctrl_en(),
.state_done(clear_w),  
.done_pic_count(done_pic_count_w),
.ps(ps_w),
.mac_en(mac_en_w),    
.signal(signal_w),
    
.x_buf_en(x_en),
.w_buf_en(w_en),
.x_addr(x_addr),
.w_addr(w_addr),
    
.temp_en(temp_en_w),
.temp_wen(temp_wen_w),
.temp_buf_addr(temp_addr_w),

.y_en(y_buf_en),
.y_wen(y_buf_wr_en),
.y_buf_addr(y_buf_addr)
);    
    
    
////////////////////////////////    
///////////////pu///////////////
////////////////////////////////     
wire signed [24:0] pu_in1;
wire signed [1279:0] pu_in2;

    
pu mlp_pu(
.clk(clk),
.rstn(rst_n),
.enable(mac_en_w),     
.clear(clear_w),     
.signal(signal_w),
.state(ps_w),
.img_cnt(), 
.data1(pu_in1),
.data2(pu_in2),
.out1(pu_out1),
.out2(pu_out2)
    );
    
///////////<<MUX 1>>/////////////    
/////////////pu_in1//////////////
////////////////////////////////    
   
 assign pu_in1 = (ps_w == 1) ? x_data : (ps_w == 0 || ps_w == 6) ? 0 : temp_data; 
   
///////////<<MUX 2>>/////////////    
/////////////pu_in2//////////////
////////////////////////////////     

assign pu_in2 = (ps_w == 1) ? w1_data : (ps_w == 2) ? w2_data : (ps_w == 3) ? w3_data : (ps_w == 4) ? w4_data : (ps_w == 5) ? w5_data : 0;
    

assign y_buf_data = pu_out2; 
    
endmodule

