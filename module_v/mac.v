`timescale 1ns / 1ps

module mac(
    input wire clk,
    input wire rstn,
    input wire enable,
    input wire clear,
    input wire signed [24:0] xin,
    input wire signed [17:0] win,
    output wire signed [26:0] dout
    );
    
reg signed [42:0] partial_sum;
wire signed [43:0] dsp_out;
    
always@(posedge clk or negedge rstn) begin
    if(!rstn || clear) begin
        partial_sum <= 0; end
    else if(enable) begin
        partial_sum <= $signed({dsp_out[43],dsp_out[41:0]}); end
    else begin
        partial_sum <= partial_sum; end
 end
           
    
xbip_dsp48_macro_0 dsp (
  .CLK(clk),    // input wire CLK
  .CE(enable),      // input wire CE
  .SCLR(clear),  // input wire SCLR
  .A(xin),        // input wire [24 : 0] A
  .B(win),        // input wire [17 : 0] B
  .C(partial_sum),        // input wire [42 : 0] C
  .P(dsp_out)        // output wire [43 : 0] P
);    
    
assign dout = dsp_out[42:16];
    
    
endmodule
