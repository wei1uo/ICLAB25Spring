//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2023/10
//		Version		: v1.0
//   	File Name   : Division_IP.v
//   	Module Name : Division_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module Division_IP #(parameter IP_WIDTH = 7) (
    // Input signals
    IN_Dividend, IN_Divisor,
    // Output signals
    OUT_Quotient
);

// ===============================================================
// Input & Output
// ===============================================================
input [IP_WIDTH[2:0]*4-1:0]  IN_Dividend;
input [IP_WIDTH[2:0]*4-1:0]  IN_Divisor;

output logic [IP_WIDTH[3]*20+IP_WIDTH[2:0]*4-1:0] OUT_Quotient;

// ===============================================================
// Wire & Reg
// ===============================================================

reg [3:0] q[0:6], unsort_q[0:6], div_x_q[0:6];
reg [3:0] remainder[0:7][0:6], divisor[0:6];
wire [27:0] extend_Dividend = {{(7-IP_WIDTH[2:0])<<2{1'b1}}, IN_Dividend};
wire [27:0] extend_Divisor  = {{(7-IP_WIDTH[2:0])<<2{1'b1}}, IN_Divisor};
wire[3:0] b2e[0:15] = {4'd15, 4'd0, 4'd1, 4'd4, 4'd2, 4'd8, 4'd5, 4'd10, 4'd3, 4'd14, 4'd9, 4'd7, 4'd6, 4'd13, 4'd11, 4'd12};
wire[3:0] e2b[0:15] = {4'd1, 4'd2, 4'd4, 4'd8, 4'd3, 4'd6, 4'd12, 4'd11, 4'd5, 4'd10, 4'd7, 4'd14, 4'd15, 4'd13, 4'd9, 4'd0};
genvar ii, jj;
integer i, j;
wire[2:0] msb_idx;
reg valid;
// ===============================================================
// Design
// ===============================================================
function logic[3:0] mm15;
    input[3:0] mcand;
    input[3:0] multi;
    reg[4:0] product;
    begin
        product = mcand + multi;
        if(&mcand)
            mm15 = 4'hf;
        else if(&product[3:0])
            mm15 = 4'b0;
        else
            mm15 = product[3:0] + product[4];
    end
endfunction
MSB msb_d(.Div(extend_Divisor), .deg(msb_idx));
generate
    for (ii = 0; ii < 7; ii = ii+ 1) begin
        assign remainder[0][ii] = extend_Dividend[(6-ii)*4 +: 4];
        assign divisor[ii] = extend_Divisor[(6-ii)*4 +: 4];
    end
endgenerate
always @(*) begin
    for(i = 0; i < 7; i = i + 1)begin
        valid = (i <= msb_idx) && (~&remainder[i][i]);
        unsort_q[i] = valid? remainder[i][i] - divisor[msb_idx] - (remainder[i][i] < divisor[msb_idx]):4'hf;
        for (j = 0; j < 7; j = j + 1)begin
            div_x_q[j] = ((j + msb_idx < 7) && ~&unsort_q[i] && ~&divisor[j + msb_idx])
                            ? mm15(unsort_q[i], divisor[j + msb_idx]) : 4'hf;
        end
        for (j = 0; j < 7 - i; j = j + 1)begin
            remainder[i+1][i+j] = b2e[e2b[remainder[i][i+j]]^e2b[div_x_q[j]]];
        end
        for (j = 0; j < i; j = j + 1)begin
            remainder[i+1][j] = remainder[i][j];
        end
    end
    for (i = 0; i < 7; i = i + 1)
            q[i] = 4'hf;
    for (i = 0; i < 7; i = i + 1) begin
            q[i-msb_idx+6] = unsort_q[i];
    end
end
always @(*) begin
    OUT_Quotient = {remainder[7][2], remainder[7][3], remainder[7][4],
   remainder[7][5], remainder[7][6], q[0], q[1], q[2], q[3], q[4], q[5], q[6]};
end
endmodule
module MSB (
    input [27:0] Div,
    output reg [2:0] deg
);
    always @(*) begin
        case (1'b0)
            (&Div[27:24]): deg = 3'd0;
            (&Div[23:20]): deg = 3'd1;
            (&Div[19:16]): deg = 3'd2;
            (&Div[15:12]): deg = 3'd3;
            (&Div[11: 8]): deg = 3'd4;
            (&Div[ 7: 4]): deg = 3'd5;
            default: deg = 3'd6;
        endcase
    end
endmodule