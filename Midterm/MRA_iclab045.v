//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Si2 LAB @NYCU ED430
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2023 Fall
//   Midterm Proejct            : MRA  
//   Author                     : Lin-Hung, Lai
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : MRA.v
//   Module Name : MRA
//   Release version : V2.0 (Release Date: 2023-10)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module MRA #(parameter ID_WIDTH=4, DATA_WIDTH=128, ADDR_WIDTH=32)(
	// CHIP IO
	clk            	,	
	rst_n          	,	
	in_valid       	,	
	frame_id        ,	
	net_id         	,	  
	loc_x          	,	  
    loc_y         	,
	cost	 		,		
	busy         	,

    // AXI4 IO
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
	   rready_m_inf,
	
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
	   bready_m_inf 
);

// ===============================================================
//  					Input / Output 
// ===============================================================

// << CHIP io port with system >>
input 			  	clk,rst_n;
input 			   	in_valid;
input  [4:0] 		frame_id;
input  [3:0]       	net_id;     
input  [5:0]       	loc_x; 
input  [5:0]       	loc_y; 
output reg [13:0] 	cost;
output reg          busy;       
  
// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
       Your AXI-4 interface could be designed as a bridge in submodule,
	   therefore I declared output of AXI as wire.  
	   Ex: AXI4_interface AXI4_INF(...);
*/

// ------------------------
// <<<<< AXI READ >>>>>
// ------------------------
// (1)	axi read address channel 
output wire [ID_WIDTH-1:0]      arid_m_inf;
output wire [1:0]            arburst_m_inf;
output wire [2:0]             arsize_m_inf;
output wire [7:0]              arlen_m_inf;
output wire                  arvalid_m_inf;
input  wire                  arready_m_inf;
output wire [ADDR_WIDTH-1:0]  araddr_m_inf;
// ------------------------
// (2)	axi read data channel 
input  wire [ID_WIDTH-1:0]       rid_m_inf;
input  wire                   rvalid_m_inf;
output wire                   rready_m_inf;
input  wire [DATA_WIDTH-1:0]   rdata_m_inf;
input  wire                    rlast_m_inf;
input  wire [1:0]              rresp_m_inf;
// ------------------------
// <<<<< AXI WRITE >>>>>
// ------------------------
// (1) 	axi write address channel 
output wire [ID_WIDTH-1:0]      awid_m_inf;
output wire [1:0]            awburst_m_inf;
output wire [2:0]             awsize_m_inf;
output wire [7:0]              awlen_m_inf;
output wire                  awvalid_m_inf;
input  wire                  awready_m_inf;
output wire [ADDR_WIDTH-1:0]  awaddr_m_inf;
// -------------------------
// (2)	axi write data channel 
output wire                   wvalid_m_inf;
input  wire                   wready_m_inf;
output wire [DATA_WIDTH-1:0]   wdata_m_inf;
output wire                    wlast_m_inf;
// -------------------------
// (3)	axi write response channel 
input  wire  [ID_WIDTH-1:0]      bid_m_inf;
input  wire                   bvalid_m_inf;
output wire                   bready_m_inf;
input  wire  [1:0]             bresp_m_inf;
// -----------------------------
reg[3:0] state, nxt_state;
reg[2:0] r_state, r_nxt_state;
reg[4:0] frame_reg;
reg[3:0] netid_reg[0:14];
reg[5:0] loc_x_reg[0:29];
reg[5:0] loc_y_reg[0:29];
reg[1:0] route_map[0:63][0:63];
reg cnt_valid, flag;
reg[1:0] cnt_4;
reg[6:0] cnt_dram;
reg[5:0] prop_x, prop_y;
parameter STATE_IDLE = 0;
parameter STATE_REQ_MAP = 1;
parameter STATE_FETCH_MAP = 2;
parameter STATE_REQ_WGT = 8;
parameter STATE_FETCH_WGT = 9;
parameter STATE_PROPAGATE = 5;
parameter STATE_TRACE_R = 6;
parameter STATE_TRACE_W = 7;
parameter STATE_MAP_CLEAR = 3;
parameter STATE_MAP_INIT = 4;
parameter STATE_WB_REQ = 10;
parameter STATE_WB_DRAM = 11;
parameter STATE_WB_RESP = 12;

reg [127:0] map_update;
reg [127:0] dout_map_reg;
wire[127:0] dout_wgt,dout_map;
wire[127:0] din_wgt = (state == STATE_FETCH_WGT)? rdata_m_inf:128'b0; // useless mux but fix hold time
// wire[127:0] din_wgt = rdata_m_inf;
wire[127:0] din_map = (state == STATE_FETCH_MAP)? rdata_m_inf:map_update;
wire[6:0] a_wgt = (state == STATE_FETCH_WGT)? cnt_dram:{prop_y,prop_x[5]};
wire[6:0] a_map = (state == STATE_TRACE_R || state == STATE_TRACE_W)? {prop_y,prop_x[5]}: cnt_dram+(state == STATE_WB_DRAM);
wire web_wgt = state != STATE_FETCH_WGT;
wire web_map = state != STATE_FETCH_MAP && state != STATE_TRACE_W;
// ===============================================================
//  						   Design 
// ===============================================================
always @(posedge clk) begin
	if(in_valid) frame_reg <= frame_id;
end
always @(posedge clk) begin
	if(wvalid_m_inf) dout_map_reg <= dout_map_reg;
	else dout_map_reg <= dout_map;
end
always @(posedge clk) begin
	if(in_valid) netid_reg[0] <= net_id;
	else if(~|netid_reg[14]) netid_reg[0] <= 4'b0;
	else if(state == STATE_MAP_CLEAR) netid_reg[0] <= 4'b0;
end
always @(posedge clk) begin
	if(state == STATE_IDLE)begin
		for(integer i = 1; i < 15;i = i + 1)
			netid_reg[i] <= 4'b0; 
	end else if((in_valid && cnt_valid) | (!in_valid && ~|netid_reg[14]) | state == STATE_MAP_CLEAR)begin
		for(integer i = 1; i < 15;i = i + 1)
			netid_reg[i] <= netid_reg[i-1];
	end
end
always @(posedge clk) begin
	if(in_valid)begin
		loc_x_reg[0] <= loc_x;
		loc_y_reg[0] <= loc_y;
		loc_x_reg[1] <= loc_x_reg[0];
		loc_y_reg[1] <= loc_y_reg[0];
	end
end
always @(posedge clk) begin
	if(in_valid)begin
		for(integer i = 2; i < 30;i = i + 1)begin
			loc_x_reg[i] <= loc_x_reg[i-1];
			loc_y_reg[i] <= loc_y_reg[i-1];
		end
	end else if(~|netid_reg[14] | (state == STATE_MAP_CLEAR))begin
		for(integer i = 2; i < 30;i = i + 1)begin
			loc_x_reg[i] <= loc_x_reg[i-2];
			loc_y_reg[i] <= loc_y_reg[i-2];
		end
	end
end
always @(posedge clk) begin
	if(in_valid) flag <= 0;
	else if(state[0] & rlast_m_inf) flag <= 1; // change parameter may affect
end
always @(posedge clk) begin
	if(in_valid) cnt_valid <= ~cnt_valid;
	else cnt_valid <= 1;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) cnt_dram <= 7'b0;
	else if(rvalid_m_inf) cnt_dram <= cnt_dram + 1'b1;
	else if(wready_m_inf) cnt_dram <= cnt_dram + 1'b1;
end
always @(posedge clk) begin
	case (r_state)
		STATE_PROPAGATE:begin
			if(nxt_state == STATE_TRACE_R) cnt_4 <= ~cnt_4;
			else if(route_map[loc_y_reg[28]][loc_x_reg[28]][1] & ~flag) cnt_4 <= cnt_4;
			else cnt_4 <= cnt_4 + 1;
		end
		STATE_TRACE_W: cnt_4 <= cnt_4 + 1;
		STATE_TRACE_R: cnt_4 <= cnt_4;
		default: cnt_4 <= 2'd1;
	endcase
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)begin
		prop_x <= 6'b0;
		prop_y <= 6'b0;
	end else if(r_state == STATE_MAP_INIT)begin
		prop_x <= loc_x_reg[28];
		prop_y <= loc_y_reg[28];
	end else if(r_state == STATE_TRACE_W)begin //todo: try another condition
		if(~&prop_y & route_map[prop_y+1][prop_x][1] & ~(route_map[prop_y+1][prop_x][0]^cnt_4[1])) prop_y <= prop_y+1'b1;
		else if(|prop_y & route_map[prop_y-1][prop_x][1] & ~(route_map[prop_y-1][prop_x][0]^cnt_4[1])) prop_y <= prop_y-1'b1;
		else if(~&prop_x & route_map[prop_y][prop_x+1][1] & ~(route_map[prop_y][prop_x+1][0]^cnt_4[1])) prop_x <= prop_x+1'b1;
		else prop_x <= prop_x - 1'b1;
	end
end
always @(*) begin
	map_update = dout_map;
	map_update[(prop_x[4:0]*4)+:4] = netid_reg[14];
end
always @(posedge clk) begin
	case (r_state)
		STATE_FETCH_MAP:begin
			for(integer j = 0; j < 64; j = j + 1)begin
				for(integer i = 0; i < 64; i = i + 1)begin
					if(~i[5]) route_map[j][i] <= route_map[j][{1'b1,i[4:0]}];
					else if(&j[5:0]) route_map[j][i] <= (|rdata_m_inf[4*i[4:0] +:4])? 2'd1:2'd0;
					else route_map[j][i] <= route_map[j+1][{1'b0,i[4:0]}];
				end
			end
		end
		STATE_MAP_INIT:begin
			route_map[loc_y_reg[29]][loc_x_reg[29]] <= 2'd2;
			route_map[loc_y_reg[28]][loc_x_reg[28]] <= 2'd0;
		end
		STATE_MAP_CLEAR:begin
			for(integer j = 0; j < 64; j = j + 1)
				for(integer i = 0; i < 64; i = i + 1)
					if(route_map[j][i][1]) route_map[j][i] <= 2'b0;
		end
		STATE_PROPAGATE:begin
			for(integer j = 0; j < 64; j = j + 1)begin
				for(integer i = 0; i < 64; i = i + 1)begin
					if(~|route_map[j][i] &
					 (( |j[5:0] & route_map[j-1][i][1]) |
					  (~&j[5:0] & route_map[j+1][i][1]) |
					  ( |i[5:0] & route_map[j][i-1][1]) |
					  (~&i[5:0] & route_map[j][i+1][1]))) route_map[j][i] <= {1'b1, cnt_4[1]};
				end
			end
		end
		STATE_TRACE_W: route_map[prop_y][prop_x] <= 2'd1;
	endcase
end
// ===============================================================
//  							FSM 
// ===============================================================
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) state <= STATE_IDLE;
	else state <= nxt_state;
end
always @(*) begin
	case (state)
		STATE_IDLE: nxt_state = (in_valid)? STATE_REQ_MAP:STATE_IDLE;
		STATE_REQ_MAP: nxt_state = (arready_m_inf)? STATE_FETCH_MAP:STATE_REQ_MAP;
		STATE_FETCH_MAP: nxt_state = (rlast_m_inf)? STATE_REQ_WGT:STATE_FETCH_MAP; 
		STATE_REQ_WGT: nxt_state = (arready_m_inf)? STATE_FETCH_WGT:STATE_REQ_WGT; 
		STATE_FETCH_WGT: nxt_state = (rlast_m_inf)? STATE_TRACE_R:STATE_FETCH_WGT;
		STATE_PROPAGATE: nxt_state = (route_map[loc_y_reg[28]][loc_x_reg[28]][1])? STATE_TRACE_R:STATE_PROPAGATE; //todo: can modify to [prop_x][prop_y]
		STATE_TRACE_R: nxt_state = STATE_TRACE_W;
		STATE_TRACE_W: nxt_state = (prop_x == loc_x_reg[29] && prop_y == loc_y_reg[29])? STATE_MAP_CLEAR:STATE_TRACE_R;
		STATE_MAP_CLEAR: nxt_state = STATE_MAP_INIT;
		STATE_MAP_INIT: nxt_state = (|netid_reg[14])? STATE_PROPAGATE:STATE_WB_REQ;
		STATE_WB_REQ: nxt_state = (awready_m_inf)? STATE_WB_DRAM:STATE_WB_REQ;
		STATE_WB_DRAM: nxt_state = (wlast_m_inf)? STATE_WB_RESP:STATE_WB_DRAM;
		STATE_WB_RESP: nxt_state = (bvalid_m_inf)? STATE_IDLE:STATE_WB_RESP;
		default: nxt_state = STATE_IDLE;
	endcase
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) r_state <= STATE_IDLE;
	else r_state <= r_nxt_state;
end
always @(*) begin
	case (r_state)
		STATE_IDLE: r_nxt_state = (in_valid)? STATE_REQ_MAP:STATE_IDLE;
		STATE_REQ_MAP: r_nxt_state = (arready_m_inf)? STATE_FETCH_MAP:STATE_REQ_MAP;
		STATE_FETCH_MAP: r_nxt_state = (rlast_m_inf)? STATE_MAP_INIT:STATE_FETCH_MAP; 
		STATE_PROPAGATE: r_nxt_state = (route_map[loc_y_reg[28]][loc_x_reg[28]][1] & (flag|rlast_m_inf))? STATE_TRACE_R:STATE_PROPAGATE;
		STATE_TRACE_R: r_nxt_state = STATE_TRACE_W;
		STATE_TRACE_W: r_nxt_state = (prop_x == loc_x_reg[29] && prop_y == loc_y_reg[29])? STATE_MAP_CLEAR:STATE_TRACE_R;
		STATE_MAP_CLEAR: r_nxt_state = STATE_MAP_INIT;
		STATE_MAP_INIT: r_nxt_state = (|netid_reg[14])? STATE_PROPAGATE:STATE_IDLE;
		default: r_nxt_state = STATE_IDLE;
	endcase
end
// ===============================================================
//  						   Memory 
// ===============================================================
mem128x128 mWGT (.A0(a_wgt[0]),.A1(a_wgt[1]),.A2(a_wgt[2]),.A3(a_wgt[3]),.A4(a_wgt[4]),.A5(a_wgt[5]),.A6(a_wgt[6]),
					.DO0(dout_wgt[0]),.DO1(dout_wgt[1]),.DO2(dout_wgt[2]),.DO3(dout_wgt[3]),.DO4(dout_wgt[4]),.DO5(dout_wgt[5]),.DO6(dout_wgt[6]),.DO7(dout_wgt[7]),
					.DO8(dout_wgt[8]),.DO9(dout_wgt[9]),.DO10(dout_wgt[10]),.DO11(dout_wgt[11]),.DO12(dout_wgt[12]),.DO13(dout_wgt[13]),.DO14(dout_wgt[14]),.DO15(dout_wgt[15]),
					.DO16(dout_wgt[16]),.DO17(dout_wgt[17]),.DO18(dout_wgt[18]),.DO19(dout_wgt[19]),.DO20(dout_wgt[20]),.DO21(dout_wgt[21]),.DO22(dout_wgt[22]),.DO23(dout_wgt[23]),
					.DO24(dout_wgt[24]),.DO25(dout_wgt[25]),.DO26(dout_wgt[26]),.DO27(dout_wgt[27]),.DO28(dout_wgt[28]),.DO29(dout_wgt[29]),.DO30(dout_wgt[30]),.DO31(dout_wgt[31]),
					.DO32(dout_wgt[32]),.DO33(dout_wgt[33]),.DO34(dout_wgt[34]),.DO35(dout_wgt[35]),.DO36(dout_wgt[36]),.DO37(dout_wgt[37]),.DO38(dout_wgt[38]),.DO39(dout_wgt[39]),
					.DO40(dout_wgt[40]),.DO41(dout_wgt[41]),.DO42(dout_wgt[42]),.DO43(dout_wgt[43]),.DO44(dout_wgt[44]),.DO45(dout_wgt[45]),.DO46(dout_wgt[46]),.DO47(dout_wgt[47]),
					.DO48(dout_wgt[48]),.DO49(dout_wgt[49]),.DO50(dout_wgt[50]),.DO51(dout_wgt[51]),.DO52(dout_wgt[52]),.DO53(dout_wgt[53]),.DO54(dout_wgt[54]),.DO55(dout_wgt[55]),
					.DO56(dout_wgt[56]),.DO57(dout_wgt[57]),.DO58(dout_wgt[58]),.DO59(dout_wgt[59]),.DO60(dout_wgt[60]),.DO61(dout_wgt[61]),.DO62(dout_wgt[62]),.DO63(dout_wgt[63]),
					.DO64(dout_wgt[64]),.DO65(dout_wgt[65]),.DO66(dout_wgt[66]),.DO67(dout_wgt[67]),.DO68(dout_wgt[68]),.DO69(dout_wgt[69]),.DO70(dout_wgt[70]),.DO71(dout_wgt[71]),
					.DO72(dout_wgt[72]),.DO73(dout_wgt[73]),.DO74(dout_wgt[74]),.DO75(dout_wgt[75]),.DO76(dout_wgt[76]),.DO77(dout_wgt[77]),.DO78(dout_wgt[78]),.DO79(dout_wgt[79]),
					.DO80(dout_wgt[80]),.DO81(dout_wgt[81]),.DO82(dout_wgt[82]),.DO83(dout_wgt[83]),.DO84(dout_wgt[84]),.DO85(dout_wgt[85]),.DO86(dout_wgt[86]),.DO87(dout_wgt[87]),
					.DO88(dout_wgt[88]),.DO89(dout_wgt[89]),.DO90(dout_wgt[90]),.DO91(dout_wgt[91]),.DO92(dout_wgt[92]),.DO93(dout_wgt[93]),.DO94(dout_wgt[94]),.DO95(dout_wgt[95]),
					.DO96(dout_wgt[96]),.DO97(dout_wgt[97]),.DO98(dout_wgt[98]),.DO99(dout_wgt[99]),.DO100(dout_wgt[100]),.DO101(dout_wgt[101]),.DO102(dout_wgt[102]),.DO103(dout_wgt[103]),
					.DO104(dout_wgt[104]),.DO105(dout_wgt[105]),.DO106(dout_wgt[106]),.DO107(dout_wgt[107]),.DO108(dout_wgt[108]),.DO109(dout_wgt[109]),.DO110(dout_wgt[110]),
					.DO111(dout_wgt[111]),.DO112(dout_wgt[112]),.DO113(dout_wgt[113]),.DO114(dout_wgt[114]),.DO115(dout_wgt[115]),.DO116(dout_wgt[116]),.DO117(dout_wgt[117]),
					.DO118(dout_wgt[118]),.DO119(dout_wgt[119]),.DO120(dout_wgt[120]),.DO121(dout_wgt[121]),.DO122(dout_wgt[122]),.DO123(dout_wgt[123]),.DO124(dout_wgt[124]),
					.DO125(dout_wgt[125]),.DO126(dout_wgt[126]),.DO127(dout_wgt[127]),.DI0(din_wgt[0]),.DI1(din_wgt[1]),.DI2(din_wgt[2]),.DI3(din_wgt[3]),.DI4(din_wgt[4]),.DI5(din_wgt[5]),
					.DI6(din_wgt[6]),.DI7(din_wgt[7]),.DI8(din_wgt[8]),.DI9(din_wgt[9]),.DI10(din_wgt[10]),.DI11(din_wgt[11]),.DI12(din_wgt[12]),.DI13(din_wgt[13]),.DI14(din_wgt[14]),
					.DI15(din_wgt[15]),.DI16(din_wgt[16]),.DI17(din_wgt[17]),.DI18(din_wgt[18]),.DI19(din_wgt[19]),.DI20(din_wgt[20]),.DI21(din_wgt[21]),.DI22(din_wgt[22]),
					.DI23(din_wgt[23]),.DI24(din_wgt[24]),.DI25(din_wgt[25]),.DI26(din_wgt[26]),.DI27(din_wgt[27]),.DI28(din_wgt[28]),.DI29(din_wgt[29]),.DI30(din_wgt[30]),
					.DI31(din_wgt[31]),.DI32(din_wgt[32]),.DI33(din_wgt[33]),.DI34(din_wgt[34]),.DI35(din_wgt[35]),.DI36(din_wgt[36]),.DI37(din_wgt[37]),.DI38(din_wgt[38]),
					.DI39(din_wgt[39]),.DI40(din_wgt[40]),.DI41(din_wgt[41]),.DI42(din_wgt[42]),.DI43(din_wgt[43]),.DI44(din_wgt[44]),.DI45(din_wgt[45]),.DI46(din_wgt[46]),
					.DI47(din_wgt[47]),.DI48(din_wgt[48]),.DI49(din_wgt[49]),.DI50(din_wgt[50]),.DI51(din_wgt[51]),.DI52(din_wgt[52]),.DI53(din_wgt[53]),.DI54(din_wgt[54]),
					.DI55(din_wgt[55]),.DI56(din_wgt[56]),.DI57(din_wgt[57]),.DI58(din_wgt[58]),.DI59(din_wgt[59]),.DI60(din_wgt[60]),.DI61(din_wgt[61]),.DI62(din_wgt[62]),
					.DI63(din_wgt[63]),.DI64(din_wgt[64]),.DI65(din_wgt[65]),.DI66(din_wgt[66]),.DI67(din_wgt[67]),.DI68(din_wgt[68]),.DI69(din_wgt[69]),.DI70(din_wgt[70]),
					.DI71(din_wgt[71]),.DI72(din_wgt[72]),.DI73(din_wgt[73]),.DI74(din_wgt[74]),.DI75(din_wgt[75]),.DI76(din_wgt[76]),.DI77(din_wgt[77]),.DI78(din_wgt[78]),
					.DI79(din_wgt[79]),.DI80(din_wgt[80]),.DI81(din_wgt[81]),.DI82(din_wgt[82]),.DI83(din_wgt[83]),.DI84(din_wgt[84]),.DI85(din_wgt[85]),.DI86(din_wgt[86]),
					.DI87(din_wgt[87]),.DI88(din_wgt[88]),.DI89(din_wgt[89]),.DI90(din_wgt[90]),.DI91(din_wgt[91]),.DI92(din_wgt[92]),.DI93(din_wgt[93]),.DI94(din_wgt[94]),
					.DI95(din_wgt[95]),.DI96(din_wgt[96]),.DI97(din_wgt[97]),.DI98(din_wgt[98]),.DI99(din_wgt[99]),.DI100(din_wgt[100]),.DI101(din_wgt[101]),.DI102(din_wgt[102]),
					.DI103(din_wgt[103]),.DI104(din_wgt[104]),.DI105(din_wgt[105]),.DI106(din_wgt[106]),.DI107(din_wgt[107]),.DI108(din_wgt[108]),.DI109(din_wgt[109]),
					.DI110(din_wgt[110]),.DI111(din_wgt[111]),.DI112(din_wgt[112]),.DI113(din_wgt[113]),.DI114(din_wgt[114]),.DI115(din_wgt[115]),.DI116(din_wgt[116]),
					.DI117(din_wgt[117]),.DI118(din_wgt[118]),.DI119(din_wgt[119]),.DI120(din_wgt[120]),.DI121(din_wgt[121]),.DI122(din_wgt[122]),.DI123(din_wgt[123]),
					.DI124(din_wgt[124]),.DI125(din_wgt[125]),.DI126(din_wgt[126]),.DI127(din_wgt[127]),		
					.CK(clk),.WEB(web_wgt),.OE(1'b1), .CS(1'b1));

mem128x128 mMAP (.A0(a_map[0]),.A1(a_map[1]),.A2(a_map[2]),.A3(a_map[3]),.A4(a_map[4]),.A5(a_map[5]),.A6(a_map[6]),
					.DO0(dout_map[0]),.DO1(dout_map[1]),.DO2(dout_map[2]),.DO3(dout_map[3]),.DO4(dout_map[4]),.DO5(dout_map[5]),.DO6(dout_map[6]),.DO7(dout_map[7]),
					.DO8(dout_map[8]),.DO9(dout_map[9]),.DO10(dout_map[10]),.DO11(dout_map[11]),.DO12(dout_map[12]),.DO13(dout_map[13]),.DO14(dout_map[14]),
					.DO15(dout_map[15]),.DO16(dout_map[16]),.DO17(dout_map[17]),.DO18(dout_map[18]),.DO19(dout_map[19]),.DO20(dout_map[20]),.DO21(dout_map[21]),
					.DO22(dout_map[22]),.DO23(dout_map[23]),.DO24(dout_map[24]),.DO25(dout_map[25]),.DO26(dout_map[26]),.DO27(dout_map[27]),.DO28(dout_map[28]),
					.DO29(dout_map[29]),.DO30(dout_map[30]),.DO31(dout_map[31]),.DO32(dout_map[32]),.DO33(dout_map[33]),.DO34(dout_map[34]),.DO35(dout_map[35]),
					.DO36(dout_map[36]),.DO37(dout_map[37]),.DO38(dout_map[38]),.DO39(dout_map[39]),.DO40(dout_map[40]),.DO41(dout_map[41]),.DO42(dout_map[42]),
					.DO43(dout_map[43]),.DO44(dout_map[44]),.DO45(dout_map[45]),.DO46(dout_map[46]),.DO47(dout_map[47]),.DO48(dout_map[48]),.DO49(dout_map[49]),
					.DO50(dout_map[50]),.DO51(dout_map[51]),.DO52(dout_map[52]),.DO53(dout_map[53]),.DO54(dout_map[54]),.DO55(dout_map[55]),.DO56(dout_map[56]),
					.DO57(dout_map[57]),.DO58(dout_map[58]),.DO59(dout_map[59]),.DO60(dout_map[60]),.DO61(dout_map[61]),.DO62(dout_map[62]),.DO63(dout_map[63]),
					.DO64(dout_map[64]),.DO65(dout_map[65]),.DO66(dout_map[66]),.DO67(dout_map[67]),.DO68(dout_map[68]),.DO69(dout_map[69]),.DO70(dout_map[70]),
					.DO71(dout_map[71]),.DO72(dout_map[72]),.DO73(dout_map[73]),.DO74(dout_map[74]),.DO75(dout_map[75]),.DO76(dout_map[76]),.DO77(dout_map[77]),
					.DO78(dout_map[78]),.DO79(dout_map[79]),.DO80(dout_map[80]),.DO81(dout_map[81]),.DO82(dout_map[82]),.DO83(dout_map[83]),.DO84(dout_map[84]),
					.DO85(dout_map[85]),.DO86(dout_map[86]),.DO87(dout_map[87]),.DO88(dout_map[88]),.DO89(dout_map[89]),.DO90(dout_map[90]),.DO91(dout_map[91]),
					.DO92(dout_map[92]),.DO93(dout_map[93]),.DO94(dout_map[94]),.DO95(dout_map[95]),.DO96(dout_map[96]),.DO97(dout_map[97]),.DO98(dout_map[98]),
					.DO99(dout_map[99]),.DO100(dout_map[100]),.DO101(dout_map[101]),.DO102(dout_map[102]),.DO103(dout_map[103]),.DO104(dout_map[104]),.DO105(dout_map[105]),
					.DO106(dout_map[106]),.DO107(dout_map[107]),.DO108(dout_map[108]),.DO109(dout_map[109]),.DO110(dout_map[110]),.DO111(dout_map[111]),.DO112(dout_map[112]),
					.DO113(dout_map[113]),.DO114(dout_map[114]),.DO115(dout_map[115]),.DO116(dout_map[116]),.DO117(dout_map[117]),.DO118(dout_map[118]),.DO119(dout_map[119]),
					.DO120(dout_map[120]),.DO121(dout_map[121]),.DO122(dout_map[122]),.DO123(dout_map[123]),.DO124(dout_map[124]),.DO125(dout_map[125]),.DO126(dout_map[126]),
					.DO127(dout_map[127]),.DI0(din_map[0]),.DI1(din_map[1]),.DI2(din_map[2]),.DI3(din_map[3]),.DI4(din_map[4]),.DI5(din_map[5]),.DI6(din_map[6]),.DI7(din_map[7]),
					.DI8(din_map[8]),.DI9(din_map[9]),.DI10(din_map[10]),.DI11(din_map[11]),.DI12(din_map[12]),.DI13(din_map[13]),.DI14(din_map[14]),.DI15(din_map[15]),
					.DI16(din_map[16]),.DI17(din_map[17]),.DI18(din_map[18]),.DI19(din_map[19]),.DI20(din_map[20]),.DI21(din_map[21]),.DI22(din_map[22]),.DI23(din_map[23]),
					.DI24(din_map[24]),.DI25(din_map[25]),.DI26(din_map[26]),.DI27(din_map[27]),.DI28(din_map[28]),.DI29(din_map[29]),.DI30(din_map[30]),.DI31(din_map[31]),
					.DI32(din_map[32]),.DI33(din_map[33]),.DI34(din_map[34]),.DI35(din_map[35]),.DI36(din_map[36]),.DI37(din_map[37]),.DI38(din_map[38]),.DI39(din_map[39]),
					.DI40(din_map[40]),.DI41(din_map[41]),.DI42(din_map[42]),.DI43(din_map[43]),.DI44(din_map[44]),.DI45(din_map[45]),.DI46(din_map[46]),.DI47(din_map[47]),
					.DI48(din_map[48]),.DI49(din_map[49]),.DI50(din_map[50]),.DI51(din_map[51]),.DI52(din_map[52]),.DI53(din_map[53]),.DI54(din_map[54]),.DI55(din_map[55]),
					.DI56(din_map[56]),.DI57(din_map[57]),.DI58(din_map[58]),.DI59(din_map[59]),.DI60(din_map[60]),.DI61(din_map[61]),.DI62(din_map[62]),.DI63(din_map[63]),
					.DI64(din_map[64]),.DI65(din_map[65]),.DI66(din_map[66]),.DI67(din_map[67]),.DI68(din_map[68]),.DI69(din_map[69]),.DI70(din_map[70]),.DI71(din_map[71]),
					.DI72(din_map[72]),.DI73(din_map[73]),.DI74(din_map[74]),.DI75(din_map[75]),.DI76(din_map[76]),.DI77(din_map[77]),.DI78(din_map[78]),.DI79(din_map[79]),
					.DI80(din_map[80]),.DI81(din_map[81]),.DI82(din_map[82]),.DI83(din_map[83]),.DI84(din_map[84]),.DI85(din_map[85]),.DI86(din_map[86]),.DI87(din_map[87]),
					.DI88(din_map[88]),.DI89(din_map[89]),.DI90(din_map[90]),.DI91(din_map[91]),.DI92(din_map[92]),.DI93(din_map[93]),.DI94(din_map[94]),.DI95(din_map[95]),
					.DI96(din_map[96]),.DI97(din_map[97]),.DI98(din_map[98]),.DI99(din_map[99]),.DI100(din_map[100]),.DI101(din_map[101]),.DI102(din_map[102]),.DI103(din_map[103]),
					.DI104(din_map[104]),.DI105(din_map[105]),.DI106(din_map[106]),.DI107(din_map[107]),.DI108(din_map[108]),.DI109(din_map[109]),.DI110(din_map[110]),.DI111(din_map[111]),
					.DI112(din_map[112]),.DI113(din_map[113]),.DI114(din_map[114]),.DI115(din_map[115]),.DI116(din_map[116]),.DI117(din_map[117]),.DI118(din_map[118]),.DI119(din_map[119]),
					.DI120(din_map[120]),.DI121(din_map[121]),.DI122(din_map[122]),.DI123(din_map[123]),.DI124(din_map[124]),.DI125(din_map[125]),.DI126(din_map[126]),.DI127(din_map[127]),
					.CK(clk),.WEB(web_map),.OE(1'b1), .CS(1'b1));
// ===============================================================
//  						    DRAM 
// ===============================================================
assign arid_m_inf = 4'b0;
assign arburst_m_inf = 2'b1;
assign arsize_m_inf = 3'd4;
assign arlen_m_inf = 8'd127;
assign arvalid_m_inf = state == STATE_REQ_MAP || state == STATE_REQ_WGT;// request read
assign araddr_m_inf = (20'h10000 << (state == STATE_REQ_WGT)) + {frame_reg, {11{1'b0}}};
assign rready_m_inf = state == STATE_FETCH_MAP || state == STATE_FETCH_WGT;// ready to receive
assign awid_m_inf = 4'b0;
assign awburst_m_inf = 2'b1;
assign awsize_m_inf = 3'd4;
assign awlen_m_inf = 8'd127;
assign awvalid_m_inf = state == STATE_WB_REQ;// request write
assign awaddr_m_inf = 20'h10000 + {frame_reg, {11{1'b0}}};
assign wvalid_m_inf = state == STATE_WB_DRAM;// write value valid
assign wdata_m_inf = (|cnt_dram)? dout_map:dout_map_reg;
assign wlast_m_inf = &cnt_dram;
assign bready_m_inf = state == STATE_WB_RESP;// ready to receive respond
// ===============================================================
//  						   OUTPUT 
// ===============================================================
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) cost <= 0;
	else if(state == STATE_TRACE_W && ~&dout_wgt[(prop_x[4:0]*4)+:4]) cost <= cost + dout_wgt[(prop_x[4:0]*4)+:4]; // todo: dont add 15 cost may fail demo
	else if(state == STATE_IDLE) cost <= 0;
end
// always @(posedge clk) begin
// 	if(state == STATE_TRACE_W && ~&dout_wgt[(prop_x[4:0]*4)+:4]) cost <= cost + dout_wgt[(prop_x[4:0]*4)+:4];
// 	else if(state == STATE_IDLE) cost <= 0;
// end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) busy <= 1'b0;
	else if(state == STATE_IDLE) busy <= 0;
	else if(state == STATE_FETCH_MAP) busy <= !in_valid;
	else if(state == STATE_REQ_MAP) busy <= !in_valid;
	else busy <= nxt_state != STATE_IDLE;
end
endmodule
