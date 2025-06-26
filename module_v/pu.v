`timescale 1ns / 1ps

module pu(
    input wire clk,
    input wire rstn,
    input wire enable,     
    input wire clear,     
    
    input wire signal,
    input wire [2:0] state,
    input wire [4:0] img_cnt, 
    
    input wire signed [24:0] data1,
    input wire signed [1279:0] data2,
    output wire signed [24:0] out1,     // store to temp_buffer
    output wire signed [31:0] out2      // store to y_buffer
    );
    
    
reg signed [24:0] out1_o;
reg signed [31:0] out2_o;
wire signed [26:0] mac_out [63:0];
reg signed [26:0] mac_buf [63:0];

assign out1 = out1_o;
assign out2 = out2_o;

genvar j;
generate 
for(j=0; j<64; j=j+1) begin          //mac_out[0], mac_out[1] ..... mac_out[63]
    mac my_mac(
    .clk(clk),
    .rstn(rstn),
    .enable(enable),
    .clear(clear),
    .xin(data1),
    .win(data2[20*j+17:20*j]),
    .dout(mac_out[63-j])
    ); end
endgenerate

integer i;
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        for(i=0;i<64;i=i+1) begin
            mac_buf[i] <= 0; end
    end
    else begin
        for(i=0;i<64;i=i+1) begin
            mac_buf[i] <= mac_out[i]; end
    end
end


reg [5:0] cnt;
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        out1_o <= 0;
        out2_o <= 0;
        cnt <= 0;  end
    else begin
        if(signal) begin
            cnt <= cnt+1;
            if(state == 1) begin
                if(mac_buf[cnt] > 0) begin              
                    out1_o <= (mac_buf[cnt][24:0]>>8);
                    out2_o <= 0; end
                else begin
                    out1_o <= 0;
                    out2_o <= 0; end
            end
            else if(state == 2 || state == 3 || state == 4) begin
                if(mac_buf[cnt] > 0) begin              
                    out1_o <= (mac_buf[cnt][24:0]);
                    out2_o <= 0; end
                else begin
                    out1_o <= 0;
                    out2_o <= 0; end
            end
            else begin
                if(mac_buf[cnt] >0) begin
                    out1_o <= 0;
                    out2_o <= {5'b0,mac_buf[cnt]}; end
                else begin
                    out1_o <= 0;
                    out2_o <= {5'b11111,mac_buf[cnt]}; end
            end
         end
         else begin
            out1_o <= 0;
            out2_o <= 0;
            cnt <= 0; end
    end
end
    
endmodule
