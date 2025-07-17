//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2021 Final Project: Customized ISA Processor 
//   Author              : Hsi-Hao Huang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CPU.v
//   Module Name : CPU.v
//   Release version : V1.0 (Release Date: 2021-May)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CPU(

				clk,
			  rst_n,
  
		   IO_stall,

         awid_m_inf,
       awaddr_m_inf,
       awsize_m_inf,
      awburst_m_inf,
        awlen_m_inf,
      awvalid_m_inf,
      awready_m_inf,
                    
        wdata_m_inf,
        wlast_m_inf,
       wvalid_m_inf,
       wready_m_inf,
                    
          bid_m_inf,
        bresp_m_inf,
       bvalid_m_inf,
       bready_m_inf,
                    
         arid_m_inf,
       araddr_m_inf,
        arlen_m_inf,
       arsize_m_inf,
      arburst_m_inf,
      arvalid_m_inf,
                    
      arready_m_inf, 
          rid_m_inf,
        rdata_m_inf,
        rresp_m_inf,
        rlast_m_inf,
       rvalid_m_inf,
       rready_m_inf 

);
// Input port
input  wire clk, rst_n;
// Output port
output reg  IO_stall;

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 16, DRAM_NUMBER=2, WRIT_NUMBER=1;

// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
  your AXI-4 interface could be designed as convertor in submodule(which used reg for output signal),
  therefore I declared output of AXI as wire in CPU
*/



// axi write address channel 
output  wire [WRIT_NUMBER * ID_WIDTH-1:0]        awid_m_inf;
output  wire [WRIT_NUMBER * ADDR_WIDTH-1:0]    awaddr_m_inf;
output  wire [WRIT_NUMBER * 3 -1:0]            awsize_m_inf;
output  wire [WRIT_NUMBER * 2 -1:0]           awburst_m_inf;
output  wire [WRIT_NUMBER * 7 -1:0]             awlen_m_inf;
output  wire [WRIT_NUMBER-1:0]                awvalid_m_inf;
input   wire [WRIT_NUMBER-1:0]                awready_m_inf;
// axi write data channel 
output  wire [WRIT_NUMBER * DATA_WIDTH-1:0]     wdata_m_inf;
output  wire [WRIT_NUMBER-1:0]                  wlast_m_inf;
output  wire [WRIT_NUMBER-1:0]                 wvalid_m_inf;
input   wire [WRIT_NUMBER-1:0]                 wready_m_inf;
// axi write response channel
input   wire [WRIT_NUMBER * ID_WIDTH-1:0]         bid_m_inf;
input   wire [WRIT_NUMBER * 2 -1:0]             bresp_m_inf;
input   wire [WRIT_NUMBER-1:0]             	   bvalid_m_inf;
output  wire [WRIT_NUMBER-1:0]                 bready_m_inf;
// -----------------------------
// axi read address channel 
output  wire [DRAM_NUMBER * ID_WIDTH-1:0]       arid_m_inf;
output  wire [DRAM_NUMBER * ADDR_WIDTH-1:0]   araddr_m_inf;
output  wire [DRAM_NUMBER * 7 -1:0]            arlen_m_inf;
output  wire [DRAM_NUMBER * 3 -1:0]           arsize_m_inf;
output  wire [DRAM_NUMBER * 2 -1:0]          arburst_m_inf;
output  wire [DRAM_NUMBER-1:0]               arvalid_m_inf;
input   wire [DRAM_NUMBER-1:0]               arready_m_inf;
// -----------------------------
// axi read data channel 
input   wire [DRAM_NUMBER * ID_WIDTH-1:0]         rid_m_inf;
input   wire [DRAM_NUMBER * DATA_WIDTH-1:0]     rdata_m_inf;
input   wire [DRAM_NUMBER * 2 -1:0]             rresp_m_inf;
input   wire [DRAM_NUMBER-1:0]                  rlast_m_inf;
input   wire [DRAM_NUMBER-1:0]                 rvalid_m_inf;
output  wire [DRAM_NUMBER-1:0]                 rready_m_inf;
// -----------------------------

//
//
// 
/* Register in each core:
  There are sixteen registers in your CPU. You should not change the name of those registers.
  TA will check the value in each register when your core is not busy.
  If you change the name of registers below, you must get the fail in this lab.
*/

reg signed [15:0] core_r0 , core_r1 , core_r2 , core_r3 ;
reg signed [15:0] core_r4 , core_r5 , core_r6 , core_r7 ;
reg signed [15:0] core_r8 , core_r9 , core_r10, core_r11;
reg signed [15:0] core_r12, core_r13, core_r14, core_r15;


//###########################################
//
// Wrtie down your design below
//
//###########################################

parameter STATE_FET = 0;
parameter STATE_DEC = 1;
parameter STATE_EXE = 2;
parameter STATE_MEM = 3;
parameter STATE_WB  = 4;

parameter STATE_IDLE = 0;
parameter STATE_WAIT = 1;
parameter STATE_READ = 2;
//####################################################
//                     reg & wire
//####################################################

reg[2:0] state;
reg[2:0] nxt_state;
reg[1:0] state_I;
reg[1:0] nxt_state_I;

reg [10:0] cnt_PC;
reg  [6:0] cnt_read;
reg [15:0] inst;
reg  [3:0] I_cache_block_num;
wire       inst_hit = I_cache_block_num == cnt_PC[10:7];
reg       web, web_reg;
wire [6:0] a_Icache = (web)? cnt_PC[6:0]:cnt_read;
wire[15:0] do_Icache;
reg[15:0] di_Icache;

wire[2:0]  opcode = inst[15-:3];
wire       func = inst[0];
wire[3:0]  rs = inst[12-:4];
wire[3:0]  rt = inst[ 8-:4];
wire[3:0]  rd = inst[ 4-:4];
wire[4:0]  imme = inst[4:0];
reg[15:0] rs_data, rt_data, rd_data, sel_rs, sel_rt;
wire[15:0] mux_rt  = inst[14]? {{11{imme[4]}}, imme}:rt_data;
wire[15:0] mux_rs  = (~inst[14] & inst[13])? rd_data:rs_data;
wire[15:0] add_out = $signed(mux_rs) + $signed(mux_rt);
wire[15:0] sub_out = $signed(rs_data) - $signed(rt_data);
wire       slt_out = $signed(rs_data) < $signed(rt_data);
reg[15:0]  lw_reg;
reg        dummy_reg;

wire beq_true = state == STATE_DEC && opcode == 3'b100 && !(sel_rs ^ sel_rt);
wire jp_true = (do_Icache[15-:3] == 3'b101 && !rvalid_m_inf[1]) || (opcode == 3'b101 && rlast_m_inf[1]);
wire[10:0] jp_target = (do_Icache[15-:3] == 3'b101 && !rvalid_m_inf[1])? do_Icache[11:1]:inst[11:1];
//####################################################
//                      design
//####################################################
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) cnt_PC <= 11'h000;
  else if(beq_true) cnt_PC <= $signed(cnt_PC) + $signed(inst[4:0]);
  else if(nxt_state == STATE_DEC) cnt_PC <= jp_true? jp_target:cnt_PC + 1'd1;
end
always @(posedge clk) begin
  dummy_reg <= state == STATE_EXE;
end
//####################################################
//                       AXI4
//####################################################
assign arid_m_inf = 0;
assign arburst_m_inf = 4'h5;
assign arsize_m_inf = 6'h09;
assign arlen_m_inf = 14'b1111111_0000000;
assign araddr_m_inf[63:32] = {20'b1, cnt_PC[10:7], 8'b0};
assign araddr_m_inf[31: 0] = {20'b1, add_out[10:0], 1'b0};

assign arvalid_m_inf[1] = state_I == STATE_WAIT;
// assign rready_m_inf[1] = state_I == STATE_READ;
assign rready_m_inf[1] = 1;
assign arvalid_m_inf[0] = state == STATE_EXE && opcode == 3'b010;
assign rready_m_inf[0] = 1;

assign awid_m_inf = 0;
assign awaddr_m_inf = {20'b1, add_out[10:0], 1'b0};
assign awsize_m_inf = 3'b001;
assign awburst_m_inf = 2'b01;
assign awlen_m_inf = 7'b0;
assign awvalid_m_inf =  opcode == 3'b011 && (state == STATE_EXE | dummy_reg);
assign wdata_m_inf  = rt_data;
assign wlast_m_inf  = 1;
assign wvalid_m_inf = 1;
assign bready_m_inf = 1;
//####################################################
//                   GENERAL REG
//####################################################

always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r0 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 0) core_r0 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 0) core_r0 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r1 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 1) core_r1 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 1) core_r1 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r2 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 2) core_r2 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 2) core_r2 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r3 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 3) core_r3 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 3) core_r3 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r4 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 4) core_r4 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 4) core_r4 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r5 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 5) core_r5 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 5) core_r5 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r6 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 6) core_r6 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 6) core_r6 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r7 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 7) core_r7 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 7) core_r7 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r8 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 8) core_r8 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 8) core_r8 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r9 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 9) core_r9 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 9) core_r9 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r10 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 10) core_r10 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 10) core_r10 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r11 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 11) core_r11 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 11) core_r11 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r12 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 12) core_r12 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 12) core_r12 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r13 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 13) core_r13 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 13) core_r13 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r14 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 14) core_r14 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 14) core_r14 <= lw_reg;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) core_r15 <= 16'b0;
  else if(state == STATE_WB && ~inst[14] && rd == 15) core_r15 <= rd_data;
  else if(state == STATE_WB &&  inst[14] && rt == 15) core_r15 <= lw_reg;
end
//####################################################
//                     RS RT RD
//####################################################
always @(*) begin
  case (rs)
      4'd0:  sel_rs = core_r0;
      4'd1:  sel_rs = core_r1;
      4'd2:  sel_rs = core_r2;
      4'd3:  sel_rs = core_r3;
      4'd4:  sel_rs = core_r4;
      4'd5:  sel_rs = core_r5;
      4'd6:  sel_rs = core_r6;
      4'd7:  sel_rs = core_r7;
      4'd8:  sel_rs = core_r8;
      4'd9:  sel_rs = core_r9;
      4'd10: sel_rs = core_r10;
      4'd11: sel_rs = core_r11;
      4'd12: sel_rs = core_r12;
      4'd13: sel_rs = core_r13;
      4'd14: sel_rs = core_r14;
      4'd15: sel_rs = core_r15;
    endcase
end
always @(*) begin
  case (rt)
      4'd0:  sel_rt = core_r0;
      4'd1:  sel_rt = core_r1;
      4'd2:  sel_rt = core_r2;
      4'd3:  sel_rt = core_r3;
      4'd4:  sel_rt = core_r4;
      4'd5:  sel_rt = core_r5;
      4'd6:  sel_rt = core_r6;
      4'd7:  sel_rt = core_r7;
      4'd8:  sel_rt = core_r8;
      4'd9:  sel_rt = core_r9;
      4'd10: sel_rt = core_r10;
      4'd11: sel_rt = core_r11;
      4'd12: sel_rt = core_r12;
      4'd13: sel_rt = core_r13;
      4'd14: sel_rt = core_r14;
      4'd15: sel_rt = core_r15;
    endcase
end
always @(posedge clk) begin
  if(state == STATE_DEC) rs_data <= sel_rs;
  // else if(state == STATE_EXE && opcode == 3'b001 && func) rs_data <= rs_data >>> 1;
end
always @(posedge clk) begin
  if(state == STATE_DEC) rt_data <= sel_rt;
  // else if(state == STATE_EXE && opcode == 3'b001 && func) rt_data <= rt_data << 1;
end
always @(posedge clk) begin
  if(state == STATE_FET) rd_data <= 16'b0;
  else
    case ({opcode, func})
      4'b0001: rd_data <= sub_out;
      4'b0000: rd_data <= add_out;
      4'b0010: rd_data <= slt_out;
      4'b0011: rd_data <= $signed(rs_data) * $signed(rt_data);
    endcase
end
//####################################################
//                       MEM
//####################################################
always @(posedge clk) begin
  lw_reg <= rdata_m_inf[15:0];
end
always @(posedge clk) begin
  if(rvalid_m_inf[1]) cnt_read <= cnt_read + 1'b1;
  else cnt_read <= 7'h7f;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) web <= 1'b1;
  else web <= state_I != STATE_READ;
end
always @(posedge clk) begin
  web_reg <= web;
end
// assign web = state_I != STATE_READ;
always @(posedge clk) begin
  di_Icache <= rdata_m_inf[31:16];
end
always @(posedge clk) begin
  if(nxt_state == STATE_DEC && inst_hit) inst <= do_Icache;
  else if(state == STATE_FET && cnt_read == cnt_PC[6:0]) inst <= di_Icache;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) I_cache_block_num <= 4'hf;
  else if(rlast_m_inf[1]) I_cache_block_num <= cnt_PC[10:7];
end
mem_16x128 cache (.A0(a_Icache[0]),.A1(a_Icache[1]),.A2(a_Icache[2]),.A3(a_Icache[3]),.A4(a_Icache[4]),.A5(a_Icache[5]),.A6(a_Icache[6]),
                  .DO0(do_Icache[0]),.DO1(do_Icache[1]),.DO2(do_Icache[2]),.DO3(do_Icache[3]),.DO4(do_Icache[4]),.DO5(do_Icache[5]),.DO6(do_Icache[6]),
                  .DO7(do_Icache[7]),.DO8(do_Icache[8]),.DO9(do_Icache[9]),.DO10(do_Icache[10]),.DO11(do_Icache[11]),.DO12(do_Icache[12]),.DO13(do_Icache[13]),
                  .DO14(do_Icache[14]),.DO15(do_Icache[15]),.DI0(di_Icache[0]),.DI1(di_Icache[1]),.DI2(di_Icache[2]),.DI3(di_Icache[3]),.DI4(di_Icache[4]),
                  .DI5(di_Icache[5]),.DI6(di_Icache[6]),.DI7(di_Icache[7]),.DI8(di_Icache[8]),.DI9(di_Icache[9]),.DI10(di_Icache[10]),.DI11(di_Icache[11]),
                  .DI12(di_Icache[12]),.DI13(di_Icache[13]),.DI14(di_Icache[14]),.DI15(di_Icache[15]),.CK(clk),.WEB(web),.OE(1'b1), .CS(1'b1));

//####################################################
//                        FSM
//####################################################
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) state <= STATE_FET;
  else state <= nxt_state;
end
always @(*) begin
  case (state)
    STATE_FET: nxt_state = (web_reg && (inst_hit || rlast_m_inf[1]))? STATE_DEC:STATE_FET;
    STATE_DEC: nxt_state = (opcode == 3'b101)? STATE_FET:STATE_EXE;
    STATE_EXE:begin
      case (opcode)
        3'b100: nxt_state = STATE_FET;
        3'b010, 3'b011: nxt_state = STATE_MEM;
        default:begin
          // if(opcode == 3'b001 && func) nxt_state = (~|rs_data[15:1] | ~|rt_data[14:0])? STATE_WB:STATE_EXE;
          // else nxt_state = STATE_WB;
          nxt_state = STATE_WB;
        end
      endcase
    end
    STATE_MEM: nxt_state = (bvalid_m_inf | rvalid_m_inf[0])? (inst[13])?STATE_FET:STATE_WB:STATE_MEM;
    STATE_WB: nxt_state = STATE_FET;
    default: nxt_state = STATE_FET;
  endcase
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) state_I <= STATE_IDLE;
  else state_I <= nxt_state_I;
end
always @(*) begin
  case (state_I)
    STATE_IDLE: nxt_state_I = (state == STATE_FET && cnt_PC[10:7] != I_cache_block_num)? STATE_WAIT:STATE_IDLE;
    STATE_WAIT: nxt_state_I = arready_m_inf[1]? STATE_WAIT:STATE_READ;
    STATE_READ: nxt_state_I = rlast_m_inf[1]? STATE_IDLE:STATE_READ;
    default: nxt_state_I = STATE_IDLE;
  endcase
end

reg last_inst;
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) last_inst <= 0;
  else last_inst <= last_inst | &cnt_PC;
end
always @(posedge clk or negedge rst_n) begin
  if(!rst_n) IO_stall <= 1'b1;
  else IO_stall <= !((nxt_state == STATE_DEC && cnt_PC != 11'h000) || (last_inst && ~|cnt_PC && ~|state));
end

// always @(posedge clk) begin
//   if(state == STATE_DEC) display_instruction(inst);
// end

// task display_instruction;
//   input [15:0] instruction;
//   reg [2:0] opcode;
//   reg [3:0] rs, rt, rd;
//   reg [4:0] imm;
//   reg [12:0] jaddr;
//   reg func;
// begin
//   opcode = instruction[15:13];
//   $display("Instruction: %b", instruction);
//   case (opcode)
//     3'b000: begin
//       rs = instruction[12:9];
//       rt = instruction[8:5];
//       rd = instruction[4:1];
//       func = instruction[0];
//       if (func == 1'b0)
//         $display("ADD  r%d = r%d + r%d", rd, rs, rt);
//       else
//         $display("SUB  r%d = r%d - r%d", rd, rs, rt);
//     end
 
//     3'b001: begin
//       rs = instruction[12:9];
//       rt = instruction[8:5];
//       rd = instruction[4:1];
//       func = instruction[0];
//       if (func == 1'b0)
//         $display("SLT  r%d = (r%d < r%d) ? 1 : 0", rd, rs, rt);
//       else
//         $display("MUL  r%d = r%d * r%d (lower 16 bits)", rd, rs, rt);
//     end
 
//     3'b010: begin
//       rs = instruction[12:9];
//       rt = instruction[8:5];
//       imm = instruction[4:0];
//       $display("LOAD  r%d = DM[sign(r%d + %0d) * 2 + offset]", rt, rs, imm);
//     end
 
//     3'b011: begin
//       rs = instruction[12:9];
//       rt = instruction[8:5];
//       imm = instruction[4:0];
//       $display("STORE  DM[sign(r%d + %0d) * 2 + offset] = r%d", rs, imm, rt);
//     end
 
//     3'b100: begin
//       rs = instruction[12:9];
//       rt = instruction[8:5];
//       imm = instruction[4:0];
//       $display("BEQ  if (r%d == r%d) pc = pc + 1 + %0d", rs, rt, $signed(imm));
//     end
 
//     3'b101: begin
//       jaddr = instruction[12:0];
//       $display("JUMP  pc = %h", jaddr << 1); // 根據文件是0x1000~0x1fff，可能要左移補地址
//     end
 
//     default: begin
//       $display("UNKNOWN INSTRUCTION: %b", instruction);
//     end
//   endcase
// end
// endtask
endmodule
