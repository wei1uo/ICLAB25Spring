//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2025
//		Version		: v1.0
//   	File Name   : BCH_TOP.v
//   	Module Name : BCH_TOP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`include "Division_IP.v"
//synopsys translate_off
//synopsys translate_on

module BCH_TOP(
    // Input signals
    clk,
	rst_n,
	in_valid,
    in_syndrome, 
    // Output signals
    out_valid, 
	out_location
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid;
input [3:0] in_syndrome;

output reg out_valid;
output reg [3:0] out_location;

// ===============================================================
// Reg & Wire Declaration
// ===============================================================
reg[1:0] state, next_state;
parameter STATE_IDLE = 1;
parameter STATE_CALC = 2;
parameter STATE_OUTP = 3;

wire[3:0] b2e[0:15] = {4'd15, 4'd0, 4'd1, 4'd4, 4'd2, 4'd8, 4'd5, 4'd10, 4'd3, 4'd14, 4'd9, 4'd7, 4'd6, 4'd13, 4'd11, 4'd12};
wire[3:0] e2b[0:15] = {4'd1, 4'd2, 4'd4, 4'd8, 4'd3, 4'd6, 4'd12, 4'd11, 4'd5, 4'd10, 4'd7, 4'd14, 4'd15, 4'd13, 4'd9, 4'd0};
reg[27:0] omega_up;
reg[23:0] omega_dw;
reg[15:0] sigma_dw, q_reg;
reg[11:0] sigma_up;
wire[15:0] q;
wire fulfill;
wire[19:0]remainder;
reg root_negi[0:14];
reg[3:0] root_pter;
reg[1:0] cnt;
wire[11:0] unused;
function [3:0] mm15;
    input[3:0] mcand;
    input[3:0] multi;
    reg[4:0] product;
    begin
        product = mcand + multi;
        if(&mcand | &multi)
            mm15 = 4'hf;
        else if(&product[3:0])
            mm15 = 4'b0;
        else
            mm15 = product[3:0] + product[4];
    end
endfunction
function [15:0] MAC;
    input[15:0] opA;
    input[15:0] opB;
    input[11:0] opc; // guess: deg(c) will only be 2
    reg[3:0] a, b, c, d, e, f, g, h, cof0, cof1, cof2, cof3;
    begin
        a = opA[15:12];
        b = opA[11: 8];
        c = opA[ 7: 4];
        d = opA[ 3: 0];
        e = opB[15:12];
        f = opB[11: 8];
        g = opB[ 7: 4];
        h = opB[ 3: 0];
        cof3 = b2e[e2b[mm15(a,h)] ^ e2b[mm15(b,g)] ^ e2b[mm15(c,f)] ^ e2b[mm15(d,e)]];
        cof2 = b2e[e2b[mm15(b,h)] ^ e2b[mm15(c,g)] ^ e2b[mm15(d,f)] ^ e2b[opc[11:8]]];
        cof1 = b2e[e2b[mm15(c,h)] ^ e2b[mm15(d,g)] ^ e2b[opc[7:4]]];
        cof0 = b2e[e2b[mm15(d,h)] ^ e2b[opc[3:0]]];
        MAC = {cof3, cof2, cof1, cof0};
    end
endfunction
function is_root;
    input[15:0] poly;
    input[3:0] x;
    reg[3:0] cof0, cof1, cof2, cof3;
    begin
        cof3 = mm15(mm15(x,x),mm15(x,poly[15:12]));
        cof2 = mm15(mm15(x,x),poly[11:8]);
        cof1 = mm15(x,poly[7:4]);
        is_root = ~|(e2b[cof3] ^ e2b[cof2] ^ e2b[cof1] ^ e2b[poly[3:0]]);
    end
endfunction
// ===============================================================
// Design
// ===============================================================
Division_IP #(15) IP (.IN_Dividend(omega_up), .IN_Divisor({4'hf, omega_dw}), .OUT_Quotient({remainder, unused, q}));
always @(posedge clk) begin
    q_reg <= q;
end
always @(posedge clk) begin
    if(in_valid)
        omega_up <= 28'h0ff_ffff;
    else
        omega_up <= {4'hf, omega_dw};
end
always @(posedge clk) begin
    if(in_valid)begin
        omega_dw[ 3:0] <= in_syndrome;
        omega_dw[23:4] <= omega_dw[19:0];
    end else
        omega_dw <= {4'hf, remainder};
end
always @(posedge clk) begin
    if(in_valid)
        sigma_up <= 12'hff0;
    else
        sigma_up <= sigma_dw[11:0];
end
always @(posedge clk) begin
    if(in_valid)
        sigma_dw <= 16'hffff;
    else
        sigma_dw <= MAC(sigma_dw, q_reg, sigma_up);
end
assign fulfill = &omega_up[27:12];
always @(posedge clk) begin
    if(&next_state)
        cnt <= cnt + 1'b1;
    else
        cnt <= 3'b0;
end
generate
    for(genvar i = 0; i < 15; i = i + 1)begin
        always @(posedge clk) begin
            if(state == STATE_CALC)
                root_negi[i] <= is_root(sigma_dw, i);
            else if(root_pter == i)
                root_negi[i] <= 0;
        end
    end
endgenerate
always @(*) begin
    case (1'b1)
        root_negi[ 0]: root_pter = 4'd0;
        root_negi[ 1]: root_pter = 4'd1;
        root_negi[ 2]: root_pter = 4'd2;
        root_negi[ 3]: root_pter = 4'd3;
        root_negi[ 4]: root_pter = 4'd4;
        root_negi[ 5]: root_pter = 4'd5;
        root_negi[ 6]: root_pter = 4'd6;
        root_negi[ 7]: root_pter = 4'd7;
        root_negi[ 8]: root_pter = 4'd8;
        root_negi[ 9]: root_pter = 4'd9;
        root_negi[10]: root_pter = 4'd10;
        root_negi[11]: root_pter = 4'd11;
        root_negi[12]: root_pter = 4'd12;
        root_negi[13]: root_pter = 4'd13;
        root_negi[14]: root_pter = 4'd14;
        default: root_pter = 4'd15;
    endcase
end
// ===============================================================
// FSM
// ===============================================================
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        state <= STATE_IDLE;
    else
        state <= next_state;
end
always @(*) begin
    case (state)
        STATE_IDLE: next_state = (in_valid)? STATE_CALC:STATE_IDLE;
        STATE_CALC: next_state = (fulfill)? STATE_OUTP:STATE_CALC;
        STATE_OUTP: next_state = (&cnt)? STATE_IDLE:STATE_OUTP;
        default: next_state = STATE_IDLE;
    endcase
end
always @(*) begin
    out_valid = &state;
    out_location = out_valid? root_pter:4'b0;
end
endmodule
