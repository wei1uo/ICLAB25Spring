module HF(
    // Input signals
    input [24:0] symbol_freq,
    // Output signals
    output reg [19:0] out_encoded
);

//================================================================
//    Wire & Registers 
//================================================================
// Declare the wire/reg you would use in your circuit
// remember 
// wire for port connection and cont. assignment
// reg for proc. assignment

//================================================================
//    DESIGN
//================================================================

wire[3:0] a_encoded, b_encoded, c_encoded, d_encoded, e_encoded;
wire[2:0] a_valid, b_valid, c_valid, d_valid, e_valid;

rearrange a(
    .encoded(a_encoded),
    .valid(a_valid),
    .output_coded(out_encoded[19:16])
);
rearrange b(
    .encoded(b_encoded),
    .valid(b_valid),
    .output_coded(out_encoded[15:12])
);
rearrange c(
    .encoded(c_encoded),
    .valid(c_valid),
    .output_coded(out_encoded[11:8])
);
rearrange d(
    .encoded(d_encoded),
    .valid(d_valid),
    .output_coded(out_encoded[7:4])
);
rearrange e(
    .encoded(e_encoded),
    .valid(e_valid),
    .output_coded(out_encoded[3:0])
);

//================================================================
//    PHASE 1
//================================================================

wire[5:0] sorted_0_p1;
wire[4:0] sorted_1_p1, sorted_2_p1, sorted_3_p1;
wire[2:0] a0, a1, a2, a3, a4;

sort s(
    .unsort(symbol_freq),
    .sorted({sorted_0_p1, sorted_1_p1, sorted_2_p1, sorted_3_p1}),
    .index({a0, a1, a2, a3, a4})
);

wire[1:0] a_group_p1 = (a4 == 3'd0)? 2'd3:
                       (a3 == 3'd0)? 2'd2:
                       (a2 == 3'd0)? 2'd1:
                                     2'd0;
wire[1:0] b_group_p1 = (a4 == 3'd1)? 2'd3:
                       (a3 == 3'd1)? 2'd2:
                       (a2 == 3'd1)? 2'd1:
                                     2'd0;
wire[1:0] c_group_p1 = (a4 == 3'd2)? 2'd3:
                       (a3 == 3'd2)? 2'd2:
                       (a2 == 3'd2)? 2'd1:
                                     2'd0;
wire[1:0] d_group_p1 = (a4 == 3'd3)? 2'd3:
                       (a3 == 3'd3)? 2'd2:
                       (a2 == 3'd3)? 2'd1:
                                     2'd0;
wire[1:0] e_group_p1 = (a4[2])? 2'd3:
                       (a3[2])? 2'd2:
                       (a2[2])? 2'd1:
                                2'd0;

assign a_encoded[0] = (a1 == 3'd0);
assign b_encoded[0] = (a1 == 3'd1);
assign c_encoded[0] = (a1 == 3'd2);
assign d_encoded[0] = (a1 == 3'd3);
assign e_encoded[0] = (a1 == 3'd4);

assign a_valid[0] = !a_group_p1;
assign b_valid[0] = !b_group_p1;
assign c_valid[0] = !c_group_p1;
assign d_valid[0] = !d_group_p1;
assign e_valid[0] = !e_group_p1;

//================================================================
//    PHASE 2
//================================================================

wire switch1_p2 = (sorted_0_p1 > sorted_1_p1);
wire switch2_p2 = (sorted_0_p1 > sorted_2_p1);
wire switch3_p2 = (sorted_0_p1 > sorted_3_p1);

wire[5:0] sorted_0_p2 = (switch2_p2)? (sorted_1_p1 + sorted_2_p1):(sorted_1_p1 + sorted_0_p1);
wire[5:0] sorted_1_p2 = switch3_p2? sorted_3_p1:
                        switch2_p2? sorted_0_p1:
                                    sorted_2_p1;
wire[5:0] sorted_2_p2 = switch3_p2? sorted_0_p1:sorted_3_p1;


wire[1:0] a_group_dest_p2 = switch3_p2? 2'd3:
                            switch2_p2? 2'd2:
                            switch1_p2? 2'd1:
                                        2'd0;
wire[1:0] b_group_dest_p2 = !switch1_p2;
wire[1:0] c_group_dest_p2 = switch2_p2? 2'd1:2'd2;
wire[1:0] d_group_dest_p2 = switch3_p2? 2'd2:2'd3;

wire[1:0] a_group_p2 = (a_group_p1 == 3'd0)? a_group_dest_p2:
                       (a_group_p1 == 3'd1)? b_group_dest_p2:
                       (a_group_p1 == 3'd2)? c_group_dest_p2:
                                             d_group_dest_p2;
wire[1:0] b_group_p2 = (b_group_p1 == 3'd0)? a_group_dest_p2:
                       (b_group_p1 == 3'd1)? b_group_dest_p2:
                       (b_group_p1 == 3'd2)? c_group_dest_p2:
                                             d_group_dest_p2;
wire[1:0] c_group_p2 = (c_group_p1 == 3'd0)? a_group_dest_p2:
                       (c_group_p1 == 3'd1)? b_group_dest_p2:
                       (c_group_p1 == 3'd2)? c_group_dest_p2:
                                             d_group_dest_p2;
wire[1:0] d_group_p2 = (d_group_p1 == 3'd0)? a_group_dest_p2:
                       (d_group_p1 == 3'd1)? b_group_dest_p2:
                       (d_group_p1 == 3'd2)? c_group_dest_p2:
                                             d_group_dest_p2;
wire[1:0] e_group_p2 = (e_group_p1 == 3'd0)? a_group_dest_p2:
                       (e_group_p1 == 3'd1)? b_group_dest_p2:
                       (e_group_p1 == 3'd2)? c_group_dest_p2:
                                             d_group_dest_p2;

assign a_encoded[1] = a_group_p2 == 2'd1;
assign b_encoded[1] = b_group_p2 == 2'd1;
assign c_encoded[1] = c_group_p2 == 2'd1;
assign d_encoded[1] = d_group_p2 == 2'd1;
assign e_encoded[1] = e_group_p2 == 2'd1;

assign a_valid[1] = !a_group_p2[1];
assign b_valid[1] = !b_group_p2[1];
assign c_valid[1] = !c_group_p2[1];
assign d_valid[1] = !d_group_p2[1];
assign e_valid[1] = !e_group_p2[1];

//================================================================
//    PHASE 3
//================================================================

wire switch1_p3 = (sorted_0_p2 > sorted_1_p2);
wire switch2_p3 = (sorted_0_p2 > sorted_2_p2);

wire[6:0] sorted_0_p3 = (switch2_p3)? (sorted_1_p2 + sorted_2_p2):(sorted_1_p2 + sorted_0_p2);
wire[5:0] sorted_1_p3 = switch2_p3? sorted_0_p2:sorted_2_p2;

wire[1:0] a_group_dest_p3 = switch2_p3? 2'd2:
                            switch1_p3? 2'd1:
                                        2'd0;
wire[1:0] b_group_dest_p3 = !switch1_p3;
wire[1:0] c_group_dest_p3 = switch2_p3? 2'd1:2'd2;

wire[1:0] a_group_p3 = (a_group_p2 == 3'd3)? c_group_dest_p3:
                       (a_group_p2 == 3'd2)? b_group_dest_p3:
                                             a_group_dest_p3;
wire[1:0] b_group_p3 = (b_group_p2 == 3'd3)? c_group_dest_p3:
                       (b_group_p2 == 3'd2)? b_group_dest_p3:
                                             a_group_dest_p3;
wire[1:0] c_group_p3 = (c_group_p2 == 3'd3)? c_group_dest_p3:
                       (c_group_p2 == 3'd2)? b_group_dest_p3:
                                             a_group_dest_p3;
wire[1:0] d_group_p3 = (d_group_p2 == 3'd3)? c_group_dest_p3:
                       (d_group_p2 == 3'd2)? b_group_dest_p3:
                                             a_group_dest_p3;
wire[1:0] e_group_p3 = (e_group_p2 == 3'd3)? c_group_dest_p3:
                       (e_group_p2 == 3'd2)? b_group_dest_p3:
                                             a_group_dest_p3;

assign a_encoded[2] = a_group_p3[0];
assign b_encoded[2] = b_group_p3[0];
assign c_encoded[2] = c_group_p3[0];
assign d_encoded[2] = d_group_p3[0];
assign e_encoded[2] = e_group_p3[0];

assign a_valid[2] = !a_group_p3[1];
assign b_valid[2] = !b_group_p3[1];
assign c_valid[2] = !c_group_p3[1];
assign d_valid[2] = !d_group_p3[1];
assign e_valid[2] = !e_group_p3[1];

//================================================================
//    PHASE 4
//================================================================

wire switch_p4 = (sorted_0_p3 > sorted_1_p3);

assign a_encoded[3] = (!a_group_p3[1] & switch_p4) | (a_group_p3[1] & !switch_p4);
assign b_encoded[3] = (!b_group_p3[1] & switch_p4) | (b_group_p3[1] & !switch_p4);
assign c_encoded[3] = (!c_group_p3[1] & switch_p4) | (c_group_p3[1] & !switch_p4);
assign d_encoded[3] = (!d_group_p3[1] & switch_p4) | (d_group_p3[1] & !switch_p4);
assign e_encoded[3] = (!e_group_p3[1] & switch_p4) | (e_group_p3[1] & !switch_p4);

endmodule

module sort (
    input [24:0] unsort,
    output [20:0] sorted,
    output [14:0] index
);
    wire[4:0] A00 = unsort[24:20];
    wire[4:0] A01 = unsort[19:15];
    wire[4:0] A02 = unsort[14:10];
    wire[4:0] A03 = unsort[9:5];
    wire[4:0] A04 = unsort[4:0];

    wire[4:0] A10;
    wire[4:0] A11, A21, A31;
    wire[4:0] A12, A22, A32, A42, A52;
    wire[4:0] A13, A23, A33, A43, A53, A63, A73;
    wire[4:0] A14, A24, A34, A44;
    wire[2:0] A10_;
    wire[2:0] A11_, A21_, A31_;
    wire[2:0] A12_, A22_, A32_, A42_, A52_;
    wire[2:0] A13_, A23_, A33_, A43_, A53_, A63_, A73_;
    wire[2:0] A14_, A24_, A34_, A44_;

    assign A10 = (A00 <= A11)? A00:A11;
    assign A11 = (A01 <= A12)? A01:A12;
    assign A21 = (A00 <= A11)? A11:A00;
    assign A31 = (A21 <= A32)? A21:A32;
    assign A12 = (A02 <= A13)? A02:A13;
    assign A22 = (A01 <= A12)? A12:A01;
    assign A32 = (A22 <= A33)? A22:A33;
    assign A42 = (A21 <= A32)? A32:A21;
    assign A52 = (A42 <= A53)? A42:A53;
    assign A13 = (A03 <= A04)? A03:A04;
    assign A23 = (A02 <= A13)? A13:A02;
    assign A33 = (A23 <= A14)? A23:A14;
    assign A43 = (A22 <= A33)? A33:A22;
    assign A53 = (A43 <= A24)? A43:A24;
    assign A63 = (A42 <= A53)? A53:A42;
    assign A73 = (A63 <= A34)? A63:A34;
    assign A14 = (A03 <= A04)? A04:A03;
    assign A24 = (A23 <= A14)? A14:A23;
    assign A34 = (A43 <= A24)? A24:A43;
    assign A44 = (A63 <= A34)? A34:A63;

    assign A10_ = (A00 <= A11)? 3'd0:A11_;
    assign A11_ = (A01 <= A12)? 3'd1:A12_;
    assign A21_ = (A00 <= A11)? A11_:3'd0;
    assign A31_ = (A21 <= A32)? A21_:A32_;
    assign A12_ = (A02 <= A13)? 3'd2:A13_;
    assign A22_ = (A01 <= A12)? A12_:3'd1;
    assign A32_ = (A22 <= A33)? A22_:A33_;
    assign A42_ = (A21 <= A32)? A32_:A21_;
    assign A52_ = (A42 <= A53)? A42_:A53_;
    assign A13_ = (A03 <= A04)? 3'd3:3'd4;
    assign A23_ = (A02 <= A13)? A13_:3'd2;
    assign A33_ = (A23 <= A14)? A23_:A14_;
    assign A43_ = (A22 <= A33)? A33_:A22_;
    assign A53_ = (A43 <= A24)? A43_:A24_;
    assign A63_ = (A42 <= A53)? A53_:A42_;
    assign A73_ = (A63 <= A34)? A63_:A34_;
    assign A14_ = (A03 <= A04)? 3'd4:3'd3;
    assign A24_ = (A23 <= A14)? A14_:A23_;
    assign A34_ = (A43 <= A24)? A24_:A43_;
    assign A44_ = (A63 <= A34)? A34_:A63_;

    wire[5:0] sum = A10 + A31;

    assign sorted = {sum, A52, A73, A44};
    assign index = {A10_, A31_, A52_, A73_, A44_};
endmodule

module rearrange (
    input[3:0] encoded,
    input[2:0] valid,
    output reg[3:0] output_coded
);
    always @(*) begin
        case (valid)
            3'b000: output_coded = {3'b000, encoded[3]};
            3'b001: output_coded = {2'b00, encoded[3], encoded[0]};
            3'b010: output_coded = {2'b00, encoded[3], encoded[1]};
            3'b100: output_coded = {2'b00, encoded[3:2]};
            3'b011: output_coded = {1'b0, encoded[3], encoded[1:0]};
            3'b101: output_coded = {1'b0, encoded[3:2], encoded[0]};
            3'b110: output_coded = {1'b0, encoded[3:1]};
            3'b111: output_coded = encoded;
            default: output_coded = 4'd0;
        endcase
    end
endmodule