// synopsys translate_off
`ifdef RTL
	`include "GATED_OR.v"
`else
	`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on

module SNN(
	// Input signals
	clk,
	rst_n,
	cg_en,
	in_valid,
	img,
	ker,
	weight,

	// Output signals
	out_valid,
	out_data
);

input clk;
input rst_n;
input in_valid;
input cg_en;
input [7:0] img;
input [7:0] ker;
input [7:0] weight;

output reg out_valid;
output reg [9:0] out_data;

//==============================================//
//                    CONV                      //
//==============================================//

reg[7:0] image[0:2][0:5];
reg[7:0] kernel[0:8];
reg[7:0] wgt[0:3];

reg[2:0] img_x;
reg[1:0] img_y;
reg[1:0] img_flag;

reg out_valid_conv;
reg[19:0] conv_data;
reg[7:0] mcand[0:8];
reg[15:0] product[0:8];

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) img_x <= 3'b0;
	else if(in_valid) img_x <= (img_x[2] & img_x[0])? 3'b0:img_x + 1'b1;
	else img_x <= img_x;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) img_y <= 2'b0;
	else if(img_x[2] & img_x[0]) img_y <= (img_y[1])? 2'b0:img_y + 1'b1;
	else img_y <= img_y;
end
wire sleep_img_flag = ~(img_y[1] & img_x[2] & img_x[0]);
wire clk_img_flag;
GATED_OR GATED_img_flag(.CLOCK(clk), .SLEEP_CTRL(sleep_img_flag & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_img_flag));
always @(posedge clk_img_flag or negedge rst_n) begin
	if(!rst_n) img_flag <= 2'b0;
	else if(img_y[1] & img_x[2] & img_x[0]) img_flag <= img_flag + 1'b1;
	else img_flag <= img_flag;
end
generate
	for(genvar j = 0; j < 3; j = j + 1)begin
		for(genvar i = 0; i < 6; i = i + 1)begin
			wire sleep_image = ~(j == img_y && i == img_x);
			wire clk_image;
			GATED_OR GATED_image(.CLOCK(clk), .SLEEP_CTRL(sleep_image & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_image));
			always @(posedge clk_image) begin
				if(j == img_y && i == img_x) image[j][i] <= img;
				else image[j][i] <= image[j][i];
			end
		end
	end
endgenerate
generate
	for(genvar i = 1; i < 6; i = i + 1)begin
		wire sleep_kernel = ~(~|img_flag && ~|img_y && i == img_x);
		wire clk_kernel;
		GATED_OR GATED_kernel(.CLOCK(clk), .SLEEP_CTRL(sleep_kernel & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_kernel));
		always @(posedge clk_kernel) begin
			if(~|img_flag && ~|img_y && i == img_x) kernel[i] <= ker;
			else kernel[i] <= kernel[i];
		end
	end
endgenerate
wire sleep_kernel_6 = ~(~|img_flag && img_y[0] && ~|img_x);
wire clk_kernel_6;
GATED_OR GATED_kernel_6(.CLOCK(clk), .SLEEP_CTRL(sleep_kernel_6 & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_kernel_6));
always @(posedge clk_kernel_6) begin
	if(~|img_flag && img_y[0] && ~|img_x) kernel[6] <= ker;
	else kernel[6] <= kernel[6];
end
wire sleep_kernel_7 = ~(~|img_flag && img_y[0] && img_x == 3'd1);
wire clk_kernel_7;
GATED_OR GATED_kernel_7(.CLOCK(clk), .SLEEP_CTRL(sleep_kernel_7 & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_kernel_7));
always @(posedge clk_kernel_7) begin
	if(~|img_flag && img_y[0] && img_x == 3'd1) kernel[7] <= ker;
	else kernel[7] <= kernel[7];
end
wire sleep_kernel_8 = ~(~|img_flag & img_y[0] & img_x[1] & ~img_x[0]);
wire clk_kernel_8;
GATED_OR GATED_kernel_8(.CLOCK(clk), .SLEEP_CTRL(sleep_kernel_8 & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_kernel_8));
always @(posedge clk_kernel_8) begin
	if(~|img_flag & img_y[0] & img_x[1] & ~img_x[0]) kernel[8] <= ker;
	else kernel[8] <= kernel[8];
end
generate
	for(genvar i = 1; i < 4; i = i + 1)begin
		wire sleep_wgt = ~(~|img_flag && ~|img_y && i == img_x);
		wire clk_wgt;
		GATED_OR GATED_wgt(.CLOCK(clk), .SLEEP_CTRL(sleep_wgt & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_wgt));
		always @(posedge clk_wgt) begin
			if(~|img_flag && ~|img_y && i == img_x) wgt[i] <= weight;
			else wgt[i] <= wgt[i];
		end
	end
endgenerate
wire sleep_zero = ~(~|img_flag && ~|img_y && ~|img_x);
wire clk_zero;
GATED_OR GATED_zero(.CLOCK(clk), .SLEEP_CTRL(sleep_zero & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_zero));
always @(posedge clk_zero) begin
	if(in_valid && ~|img_flag && ~|img_y && ~|img_x)begin
		kernel[0] <= ker;
		wgt[0] <= weight;
	end
end
wire sleep_conv = ~(img_x[2:1] && (img_flag[0] | img_y[1]));
wire clk_conv;
GATED_OR GATED_conv(.CLOCK(clk), .SLEEP_CTRL(sleep_conv & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_conv));
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid_conv <= 1'b0;
	else out_valid_conv <= (img_x[2:1] && (img_flag[0] | img_y[1]));
end
always @(*) begin
	if(img_x[2:1] && (img_flag[0] | img_y[1]))begin
		// mcand[0] = image[{img_y[0],~img_y[0]^img_y[1]}][img_x-2];
		// mcand[1] = image[{img_y[0],~img_y[0]^img_y[1]}][img_x-1];
		// mcand[2] = image[{img_y[0],~img_y[0]^img_y[1]}][img_x];
		// mcand[3] = image[{~img_y[0]^img_y[1],img_y[1]}][img_x-2];
		// mcand[4] = image[{~img_y[0]^img_y[1],img_y[1]}][img_x-1];
		// mcand[5] = image[{~img_y[0]^img_y[1],img_y[1]}][img_x];
		mcand[0] = image[(1+img_y)%3][img_x-2];
		mcand[1] = image[(1+img_y)%3][img_x-1];
		mcand[2] = image[(1+img_y)%3][img_x];
		mcand[3] = image[(2+img_y)%3][img_x-2];
		mcand[4] = image[(2+img_y)%3][img_x-1];
		mcand[5] = image[(2+img_y)%3][img_x];
		mcand[6] = image[img_y][img_x-2];
		mcand[7] = image[img_y][img_x-1];
		mcand[8] = img;
	end else begin
		for(integer i = 0; i < 9; i = i + 1) mcand[i] = 8'b0;
	end
end
always @(*) begin
	for(integer i = 0; i < 9; i = i + 1)
		product[i] = mcand[i] * kernel[i];
end
always @(posedge clk_conv) begin
	conv_data <= (product[0] + product[1] + product[2]) + (product[3] + product[4] + product[5]) + (product[6] + product[7] + product[8]);
end

//==============================================//
//                     Q1                       //
//==============================================//

wire[7:0]conv_q1 = conv_data / 12'd2295;

//==============================================//
//                     MP                       //
//==============================================//

reg[2:0] cnt_mp;
reg[7:0] max[0:1];
reg[7:0] compare;
reg[7:0] opA, opB;
reg out_valid_mp;

wire sleep_mp = ~out_valid_conv;
wire clk_mp;
GATED_OR GATED_mp(.CLOCK(clk), .SLEEP_CTRL(sleep_mp & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_mp));
always @(posedge clk_mp or negedge rst_n) begin
	if(!rst_n) cnt_mp <= 3'b0;
	else if(out_valid_conv) cnt_mp <= cnt_mp + 1'b1;
end
always @(posedge clk_mp) begin
	if(out_valid_conv)begin
		case (cnt_mp)
			3'd0: max[0] <= conv_q1;
			3'd1,3'd4,3'd5: max[0] <= compare;
			default:  max[0] <=  max[0];
		endcase
	end
end
always @(posedge clk_mp) begin
	if(out_valid_conv)begin
		case (cnt_mp)
			3'd2: max[1] <= conv_q1;
			3'd3,3'd6,3'd7: max[1] <= compare;
			default: max[1] <=  max[1];
		endcase
	end
end
always @(*) begin
	opA = conv_q1;
end
always @(*) begin
	if(cnt_mp[1]) opB = max[1];
	else opB = max[0];
end
always @(*) begin
	if(opA < opB) compare = opB;
	else compare = opA;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid_mp <= 1'b0;
	else out_valid_mp <= cnt_mp[2] & cnt_mp[0];
end

//==============================================//
//                     FC                       //
//==============================================//

reg cnt_fc;
reg[15:0] fc_data[0:1];
reg[15:0] product_fc[0:1];
reg [7:0] wgt_src[0:1];
reg [7:0] input_src;

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) cnt_fc <= 1'b0;
	else if(out_valid_mp) cnt_fc <= ~cnt_fc;
end
always @(*) begin
	if(cnt_fc)begin
		input_src  = max[1];
		wgt_src[0] = wgt[2];
		wgt_src[1] = wgt[3];
	end else  begin
		input_src  = max[0];
		wgt_src[0] = wgt[0];
		wgt_src[1] = wgt[1];
	end
end
always @(*) begin
	product_fc[0] = input_src * wgt_src[0];
	product_fc[1] = input_src * wgt_src[1];
end
wire sleep_fc_data = ~(out_valid_mp & ~cnt_fc);
wire clk_fc_data;
GATED_OR GATED_fc_data(.CLOCK(clk), .SLEEP_CTRL(sleep_fc_data & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_fc_data));
always @(posedge clk_fc_data) begin
	if(out_valid_mp & ~cnt_fc)begin
		fc_data[0] <= product_fc[0];
		fc_data[1] <= product_fc[1];
	end
end

//==============================================//
//                     Q2                       //
//==============================================//

wire[16:0]  sum[0:1];
wire[7:0] fc_q2[0:1];

assign sum[0] = fc_data[0] + product_fc[0];
assign sum[1] = fc_data[1] + product_fc[1];
assign fc_q2[0] = sum[0] / 9'd510;
assign fc_q2[1] = sum[1] / 9'd510;

//==============================================//
//                    L1 ACT                    //
//==============================================//

reg[1:0] cnt_L1;
reg[7:0] L1_data[0:3];
reg [9:0] out_data_reg;
reg [7:0] abs_add[0:1];

wire sleep_L1 = ~(out_valid_mp && cnt_fc);
wire clk_L1;
GATED_OR GATED_L1(.CLOCK(clk), .SLEEP_CTRL(sleep_L1 & cg_en), .RST_N(rst_n), .CLOCK_GATED(clk_L1));
always @(posedge clk_L1 or negedge rst_n) begin
	if(!rst_n) cnt_L1 <= 2'b0;
	else if(out_valid_mp & cnt_fc) cnt_L1 <= cnt_L1 + 1'b1;
end
always @(posedge clk_L1) begin
	if(out_valid_mp && cnt_fc && ~cnt_L1[0])begin
		L1_data[0] <= (cnt_L1[1])? abs_add[0]:fc_q2[0];
		L1_data[1] <= (cnt_L1[1])? abs_add[1]:fc_q2[1];
	end
end
always @(posedge clk_L1) begin
	if(out_valid_mp && cnt_fc && cnt_L1[0])begin
		L1_data[2] <= (cnt_L1[1])? abs_add[0]:fc_q2[0];
		L1_data[3] <= (cnt_L1[1])? abs_add[1]:fc_q2[1];
	end
end
always @(*) begin
	if(cnt_L1[0])begin
		abs_add[0] = (L1_data[2] < fc_q2[0])? fc_q2[0] - L1_data[2]:L1_data[2] - fc_q2[0];
		abs_add[1] = (L1_data[3] < fc_q2[1])? fc_q2[1] - L1_data[3]:L1_data[3] - fc_q2[1];
	end else begin
		abs_add[0] = (L1_data[0] < fc_q2[0])? fc_q2[0] - L1_data[0]:L1_data[0] - fc_q2[0];
		abs_add[1] = (L1_data[1] < fc_q2[1])? fc_q2[1] - L1_data[1]:L1_data[1] - fc_q2[1];
	end
end
always @(*) begin
	out_data_reg = (L1_data[0] + L1_data[1]) + (L1_data[2] + L1_data[3]);
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid <= 1'b0;
	else out_valid <= out_valid_mp && cnt_fc && cnt_L1 == 2'd3;
end
always @(*) begin
	if(out_valid && out_data_reg[9:4]) out_data = out_data_reg;
	else out_data = 10'b0;
end

endmodule