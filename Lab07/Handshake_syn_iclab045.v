module Handshake_syn #(parameter WIDTH=32) (
    sclk,
    dclk,
    rst_n,
    sready,
    din,
    dbusy,
    sidle,
    dvalid,
    dout,

    clk1_handshake_flag1,
    clk1_handshake_flag2,
    clk1_handshake_flag3,
    clk1_handshake_flag4,

    handshake_clk2_flag1,
    handshake_clk2_flag2,
    handshake_clk2_flag3,
    handshake_clk2_flag4
);

input sclk, dclk;
input rst_n;
input sready;
input [WIDTH-1:0] din;
input dbusy;
output sidle;
output reg dvalid;
output reg [WIDTH-1:0] dout;

// You can change the input / output of the custom flag ports
input clk1_handshake_flag1;
input clk1_handshake_flag2;
output clk1_handshake_flag3;
output clk1_handshake_flag4;

output handshake_clk2_flag1;
input handshake_clk2_flag2;
output handshake_clk2_flag3;
output handshake_clk2_flag4;

// Remember:
//   Don't modify the signal name
reg sreq;
wire dreq;
reg dack;
wire sack;

// =========================================== //
//                  Reg / Wire
// =========================================== //

reg[WIDTH-1:0] s_data, d_data;

// =========================================== //
//                   Src Ctrl
// =========================================== //

always @(posedge sclk or negedge rst_n) begin
    if(!rst_n) s_data <= 32'b0;
    else s_data <= (sidle & sready)? din:s_data;
end
always @(posedge sclk or negedge rst_n) begin
    if(!rst_n) sreq <= 1'b0;
    else sreq <= (sready & sidle)? 1'b1:sreq & ~sack;
end
assign sidle = ~sreq & ~sack;

// =========================================== //
//                  Dest Ctrl
// =========================================== //

always @(posedge dclk or negedge rst_n) begin
    if(!rst_n) d_data <= 32'b0;
    else d_data <= (dack)? s_data:d_data;
end
always @(posedge dclk or negedge rst_n) begin
    if(!rst_n) dack <= 1'b0;
    // else dack <= ~dbusy & dreq;
    else dack <= dreq;
end
always @(posedge dclk or negedge rst_n) begin
    if(!rst_n) dvalid <= 1'b0;
    else dvalid <= dack & (dack ^ dreq);
end
always @(*) begin
    dout = d_data;
end
assign handshake_clk2_flag1 = dack;
NDFF_syn req(.D(sreq), .Q(dreq), .clk(dclk), .rst_n(rst_n));
NDFF_syn ack(.D(dack), .Q(sack), .clk(sclk), .rst_n(rst_n));

endmodule