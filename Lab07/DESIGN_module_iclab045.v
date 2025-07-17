module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
    seed_in,
    out_idle,
    out_valid,
    seed_out,

    clk1_handshake_flag1,
    clk1_handshake_flag2,
    clk1_handshake_flag3,
    clk1_handshake_flag4
);

input clk;
input rst_n;
input in_valid;
input [31:0] seed_in;
input out_idle;
output reg out_valid;
output reg [31:0] seed_out;

// You can change the input / output of the custom flag ports
input clk1_handshake_flag1;
input clk1_handshake_flag2;
output clk1_handshake_flag3;
output clk1_handshake_flag4;

// =========================================== //
//                    Design
// =========================================== //

reg  in_valid_reg;
reg [31:0] seed_in_reg;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) in_valid_reg <= 1'b0;
    else in_valid_reg <= in_valid;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) seed_in_reg <= 32'b0;
    else seed_in_reg <= (in_valid & out_idle)? seed_in:seed_in_reg;
end
always @(*) begin
    out_valid = in_valid_reg;
    seed_out = seed_in_reg;
end

endmodule

module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    fifo_full,
    seed,
    out_valid,
    rand_num,
    busy,

    handshake_clk2_flag1,
    handshake_clk2_flag2,
    handshake_clk2_flag3,
    handshake_clk2_flag4,

    clk2_fifo_flag1,
    clk2_fifo_flag2,
    clk2_fifo_flag3,
    clk2_fifo_flag4
);

input clk;
input rst_n;
input in_valid;
input fifo_full;
input [31:0] seed;
output out_valid;
output [31:0] rand_num;
output busy;

// You can change the input / output of the custom flag ports
input handshake_clk2_flag1;
input handshake_clk2_flag2;
output handshake_clk2_flag3;
output handshake_clk2_flag4;

input clk2_fifo_flag1;
input clk2_fifo_flag2;
output clk2_fifo_flag3;
output clk2_fifo_flag4;

// =========================================== //
//                    Design
// =========================================== //

parameter a = 13;
parameter b = 17;
parameter c =  5;
reg state;
reg [8:0]  cnt;
reg [31:0] x;
wire[31:0] x1, x2, x3;

assign busy = 1'b0;
assign rand_num = x3;
assign out_valid = state & ~fifo_full;
assign x1 = |cnt? x ^ (x << a):seed^(seed<<a);
assign x2 = x1 ^ (x1 >> b);
assign x3 = x2 ^ (x2 << c);

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) x <= 32'b0;
    else if(&cnt[7:0] & ~fifo_full) x <= 32'b0;
    else x <= (fifo_full)? x:x3;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) state <= 1'b0;
    else if(handshake_clk2_flag1) state <= 1'b1;
    else if(&cnt[7:0] & ~fifo_full) state <= 1'b0;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) cnt <= 9'b1_0000_0000;
    else if(~state & handshake_clk2_flag1) cnt <= 9'b0;
    else if(~cnt[8] & ~fifo_full) cnt <= cnt + 1'b1;
end
endmodule

module CLK_3_MODULE (
    clk,
    rst_n,
    fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    rand_num,

    fifo_clk3_flag1,
    fifo_clk3_flag2,
    fifo_clk3_flag3,
    fifo_clk3_flag4
);

input clk;
input rst_n;
input fifo_empty;
input [31:0] fifo_rdata;
output fifo_rinc;
output reg out_valid;
output reg [31:0] rand_num;

// You can change the input / output of the custom flag ports
input fifo_clk3_flag1;
input fifo_clk3_flag2;
output fifo_clk3_flag3;
output fifo_clk3_flag4;

// =========================================== //
//                    Design
// =========================================== //

reg fifo_empty_reg;

assign fifo_rinc = ~fifo_empty;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        out_valid <=  1'b0;
        fifo_empty_reg <= 1'b1;
        // rand_num  <= 32'b0;
    end else begin
        out_valid <= ~fifo_empty_reg;
        fifo_empty_reg <= fifo_empty;
    end
end
always @(*) begin
    rand_num = out_valid? fifo_rdata:32'b0;
end

endmodule