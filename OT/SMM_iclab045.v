//############################################################################
//   2025 ICLAB Spring Course
//   Sparse Matrix Multiplier (SMM)
//############################################################################

module SMM(
  // Input Port
  clk,
  rst_n,
  in_valid_size,
  in_size,
  in_valid_a,
  in_row_a,
  in_col_a,
  in_val_a,
  in_valid_b,
  in_row_b,
  in_col_b,
  in_val_b,
  // Output Port
  out_valid,
  out_row,
  out_col,
  out_val
);



//==============================================//
//                   PARAMETER                  //
//==============================================//



//==============================================//
//                   I/O PORTS                  //
//==============================================//
input             clk, rst_n, in_valid_size, in_valid_a, in_valid_b;
input             in_size;
input      [4:0]  in_row_a, in_col_a, in_row_b, in_col_b;
input      [3:0]  in_val_a, in_val_b;
output reg        out_valid;
output reg [4:0]  out_row, out_col;
output reg [8:0] out_val;


//==============================================//
//            reg & wire declaration            //
//==============================================//

reg[4:0]result_r[0:44];
reg[4:0]result_c[0:44];
reg[8:0]result_v[0:44];
reg[4:0]matrix_a_r[0:30], matrix_a_c[0:30], matrix_b_r[0:30], matrix_b_c[0:30];
reg[3:0]matrix_a_v[0:30], matrix_b_v[0:30];
reg[4:0]cnt_ma, cnt_mb, idx_ma, idx_mb, idx_mc_c, idx_mc_r;
reg[5:0]cnt_mc;
reg[8:0]matrix_c[0:31][0:31];
wire element_match = matrix_a_c[idx_ma] == matrix_b_r[idx_mb];

reg[2:0] state, nxt_state;
parameter STATE_IDLE = 0;
parameter STATE_INPT = 1;
parameter STATE_CALC = 2;
parameter STATE_COLLECT = 3;
parameter STATE_OUPT = 4;
//==============================================//
//                   Design                     //
//==============================================//
generate
  for(genvar i = 1; i < 31; i = i + 1)begin
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n)begin
        matrix_a_r[i] <= 5'b0;
        matrix_a_c[i] <= 5'b0;
        matrix_a_v[i] <= 5'b0;
      end
      else if(in_valid_a)begin
        matrix_a_r[i] <= matrix_a_r[i-1];
        matrix_a_c[i] <= matrix_a_c[i-1];
        matrix_a_v[i] <= matrix_a_v[i-1];
      end
    end
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n)begin
        matrix_b_r[i] <= 5'b0;
        matrix_b_c[i] <= 5'b0;
        matrix_b_v[i] <= 5'b0;
      end
      else if(in_valid_b)begin
        matrix_b_r[i] <= matrix_b_r[i-1];
        matrix_b_c[i] <= matrix_b_c[i-1];
        matrix_b_v[i] <= matrix_b_v[i-1];
      end
    end
  end
endgenerate
always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
    matrix_a_r[0] <= 5'b0;
    matrix_a_c[0] <= 5'b0;
    matrix_a_v[0] <= 5'b0;
  end
  else if(in_valid_a)begin
    matrix_a_r[0] <= in_row_a;
    matrix_a_c[0] <= in_col_a;
    matrix_a_v[0] <= in_val_a;
  end
end
always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
    matrix_b_r[0] <= 5'b0;
    matrix_b_c[0] <= 5'b0;
    matrix_b_v[0] <= 5'b0;
  end
  else if(in_valid_b)begin
    matrix_b_r[0] <= in_row_b;
    matrix_b_c[0] <= in_col_b;
    matrix_b_v[0] <= in_val_b;
  end
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) cnt_ma <= 5'b0;
  else if(in_valid_size) cnt_ma <= 5'b0;
  else if (in_valid_a) cnt_ma <= cnt_ma + 1'b1;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) cnt_mb <= 5'b0;
  else if(in_valid_size) cnt_mb <= 5'b0;
  else if (in_valid_b) cnt_mb <= cnt_mb + 1'b1;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) cnt_mc <= 6'b0;
  else if(in_valid_size) cnt_mc <= 6'b0;
  else if(state == STATE_COLLECT)begin
    if(|matrix_c[idx_mc_r][idx_mc_c])begin
      result_r[cnt_mc] <= idx_mc_r;
      result_c[cnt_mc] <= idx_mc_c;
      result_v[cnt_mc] <= matrix_c[idx_mc_r][idx_mc_c];
      cnt_mc <= cnt_mc + 1'b1;
    end
  end else if(state == STATE_OUPT) cnt_mc <= cnt_mc - 1'b1;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)begin
    idx_ma <= 5'b0;
    idx_mb <= 5'b0;
  end else if(in_valid_size)begin
    idx_ma <= 5'b0;
    idx_mb <= 5'b0;
  end else if(state == STATE_CALC)begin
    if(idx_mb == (cnt_mb - 1'b1)) idx_mb <= 5'b0;
    else idx_mb <= idx_mb + 1'b1;
    // if(idx_ma == (cnt_ma - 1'b1) && idx_mb == (cnt_mb - 1'b1)) idx_ma <= 5'b0;
    if(idx_mb == (cnt_mb - 1'b1)) idx_ma <= idx_ma + 1'b1;
  end
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n)begin
    idx_mc_c <= 5'b0;
    idx_mc_r <= 5'b0;
  end else if(in_valid_size)begin
    idx_mc_c <= 5'b0;
    idx_mc_r <= 5'b0;
  end else if(state == STATE_COLLECT)begin
    idx_mc_c <= idx_mc_c + 1'b1;
    if(&idx_mc_c) idx_mc_r <= idx_mc_r + 1'b1;
  end
end
generate
  for(genvar i = 0; i < 32; i = i + 1)begin
    for(genvar j = 0; j < 32; j = j + 1)begin
      always @(posedge clk or negedge rst_n) begin
        if(!rst_n) matrix_c[i][j] <= 9'b0;
        else if(in_valid_size) matrix_c[i][j] <= 9'b0;
        else if(state == STATE_CALC)begin
          if((i == matrix_a_r[idx_ma]) && (j == matrix_b_c[idx_mb]) && element_match)begin
            matrix_c[i][j] <= matrix_c[i][j] + (matrix_a_v[idx_ma] * matrix_b_v[idx_mb]);
          end
        end
      end
    end
  end
endgenerate
//==============================================//
//                     FSM                      //
//==============================================//
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) state <= STATE_IDLE;
  else state <= nxt_state;
end
always @(*) begin
  case (state)
    STATE_IDLE: nxt_state = (in_valid_a | in_valid_b)? STATE_INPT:STATE_IDLE;
    STATE_INPT: nxt_state = (in_valid_a | in_valid_b)? STATE_INPT:STATE_CALC;
    STATE_CALC: nxt_state = (idx_ma == (cnt_ma - 1'b1) && idx_mb == (cnt_mb - 1'b1))? STATE_COLLECT:STATE_CALC;
    STATE_COLLECT: nxt_state = (&idx_mc_r & &idx_mc_c)? STATE_OUPT:STATE_COLLECT;
    STATE_OUPT: nxt_state = (cnt_mc == 5'd1)? STATE_IDLE:STATE_OUPT;
    default: nxt_state = STATE_IDLE;
  endcase
end
//==============================================//
//                   OUTPUT                     //
//==============================================//
always @(*) begin
  out_valid = state == STATE_OUPT;
  out_row = (out_valid)? result_r[cnt_mc-1]:5'b0;
  out_col = (out_valid)? result_c[cnt_mc-1]:5'b0;
  out_val = (out_valid)? result_v[cnt_mc-1]:9'b0;
end

endmodule