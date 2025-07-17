/**************************************************************************/
// Copyright (c) 2025, OASIS Lab
// MODULE: STA
// FILE NAME: STA.v
// VERSRION: 1.0
// DATE: 2025/02/26
// AUTHOR: Yu-Hao Cheng, NYCU IEE
// DESCRIPTION: ICLAB 2025 Spring / LAB3 / STA
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/
module STA(
	//INPUT
	rst_n,
	clk,
	in_valid,
	delay,
	source,
	destination,
	//OUTPUT
	out_valid,
	worst_delay,
	path
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input				rst_n, clk, in_valid;
input		[3:0]	delay;
input		[3:0]	source;
input		[3:0]	destination;

output reg			out_valid;
output reg	[7:0]	worst_delay;
output reg	[3:0]	path;

//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------
integer i, j;
reg   adj_matrix[15:0][15:1];
reg[3:0]      indegree[15:1]; // 15:2
reg[3:0]   logic_delay[15:0];
reg            pending[15:0];
reg[7:0]     acc_delay[15:0];
reg[3:0] path_traverse[15:0];
reg[3:0] 		 child[15:1];
reg[3:0] tp_select;
reg[15:1] successor;

reg[1:0] state;
reg[1:0] next_state;

reg[4:0] read_count;
reg[3:0] path_count;
reg[3:0] pointer;

parameter STATE_IDLE = 2'd0;
parameter STATE_ACCU = 2'd1;
parameter STATE_TRAV = 2'd2;
parameter STATE_OUTP = 2'd3;

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------

always @(*) begin
	if(tp_select == 4'd1)
		successor = 15'b0;
	else begin
		for(i = 1; i < 16; i = i + 1)
			successor[i] = adj_matrix[tp_select][i];
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n)begin
		for(i = 0; i < 16; i = i + 1)
			for(j = 1; j < 16; j = j + 1)
				adj_matrix[i][j] <= 0;
	end
	else if(state == STATE_TRAV)begin
		for(i = 0; i < 16; i = i + 1)
			for(j = 1; j < 16; j = j + 1)
				adj_matrix[i][j] <= 0;
	end
	else if(in_valid)
		adj_matrix[source][destination] <= 1;
end
always @(posedge clk) begin
	if(in_valid && !read_count[4])
		logic_delay[read_count] <= delay;
end
always @(posedge clk) begin
	if(in_valid)begin
		for(i = 0; i < 16; i = i + 1)
			pending[i] <= 1;
	end else
		pending[tp_select] <= 0;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)begin
		for(i = 1; i < 16; i = i + 1)
			indegree[i] <= 4'b0;
	end else if(in_valid)
		indegree[destination] <= indegree[destination] + 1'b1;
	else begin
		for(i = 1; i < 16; i = i + 1)begin
			if(successor[i])
				indegree[i] <= indegree[i] - 1'b1;
		end
	end
end
always @(posedge clk) begin
	if(in_valid)
		acc_delay[0] <= logic_delay[0];
end
always @(posedge clk) begin
	if(in_valid)begin
		for(i = 1; i < 16; i = i + 1)
			acc_delay[i] <= 8'b0;
	end else begin
		for(i = 1; i < 16; i = i + 1)begin
			if(successor[i])begin
				if((acc_delay[i] < acc_delay[tp_select] + logic_delay[i]))begin
					acc_delay[i] <= acc_delay[tp_select] + logic_delay[i];
					child[i] <= tp_select;
				end
			end
		end
	end
end
always @(*) begin // find pending node which degree is 0
	if(pending[0])
		tp_select = 4'b0;
	else if(pending[2] && !indegree[2])
		tp_select = 4'd2;
	else if(pending[3] && !indegree[3])
		tp_select = 4'd3;
	else if(pending[4] && !indegree[4])
		tp_select = 4'd4;
	else if(pending[5] && !indegree[5])
		tp_select = 4'd5;
	else if(pending[6] && !indegree[6])
		tp_select = 4'd6;
	else if(pending[7] && !indegree[7])
		tp_select = 4'd7;
	else if(pending[8] && !indegree[8])
		tp_select = 4'd8;
	else if(pending[9] && !indegree[9])
		tp_select = 4'd9;
	else if(pending[10] && !indegree[10])
		tp_select = 4'd10;
	else if(pending[11] && !indegree[11])
		tp_select = 4'd11;
	else if(pending[12] && !indegree[12])
		tp_select = 4'd12;
	else if(pending[13] && !indegree[13])
		tp_select = 4'd13;
	else if(pending[14] && !indegree[14])
		tp_select = 4'd14;
	else if(pending[15] && !indegree[15])
		tp_select = 4'd15;
	else
		tp_select = 4'd1;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		read_count <= 5'b0;
	else if(in_valid)
		read_count <= read_count + 1'b1;
end
always @(posedge clk) begin
	if(!state[1])
		path_count <= 4'b0;
	else if(!state[0])
		path_count <= path_count + 1'b1;
	else
		path_count <= path_count - 1'b1;
end
always @(posedge clk) begin
	path_traverse[path_count + 1'b1] <= pointer;
	path_traverse[0] <= 4'd1;
end
always @(posedge clk) begin
	if(state[0])
		pointer <= child[1];
	else
		pointer <= child[pointer];
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)
		state <= STATE_IDLE;
	else
		state <= next_state;
end
always @(*) begin
	case (state)
		STATE_IDLE:
			next_state = (read_count == 5'd31)? STATE_ACCU:STATE_IDLE; 
		STATE_ACCU:
			next_state = (tp_select == 5'd1)? STATE_TRAV:STATE_ACCU;
		STATE_TRAV:
			next_state = (pointer)? STATE_TRAV:STATE_OUTP;
		STATE_OUTP:
			next_state = (path == 4'd1)? STATE_IDLE:STATE_OUTP;
		default: next_state = STATE_IDLE; 
	endcase
end

always @(*) begin
	out_valid = (state == STATE_OUTP);
end
always @(*) begin
	worst_delay = (out_valid & !path)? acc_delay[1]:8'b0;
end
always @(*) begin
	path = (out_valid)? path_traverse[path_count]:4'b0;
end
endmodule