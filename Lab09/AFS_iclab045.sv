//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2025/4
//		Version		: v1.0
//   	File Name   : AFS.sv
//   	Module Name : AFS
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module AFS(input clk, INF.AFS_inf inf);
import usertype::*;
    //==============================================//
    //              logic declaration               //
    // ============================================ //
    Action         action_reg;
    Strategy_Type  str_reg;
    Mode           mode_reg;
    logic[3:0]     month_reg;
    logic[4:0]     day_reg;
    logic[11:0]    stock_reg[0:3];
    logic[1:0]     stock_cnt;
    logic          stock_valid;
    logic[63:0]    dram_data_reg;
    logic          dram_r_pending;
    logic          dram_data_dirty;
    logic[7:0]     curent_dram_no;
    logic[7:0]     demand_dram_no;
    logic[9:0]     total_flower;
    logic[9:0]     demand_flower[0:3];
    logic[11:0]    dram_flower[0:3];
    logic[3:0]     dram_m;
    logic[4:0]     dram_d;
    logic          flag_date_warn;
    logic          flag_stock_warn;
    logic[0:3]     flag_overflow;
    enum logic[2:0] { 
        dram_idle,//000
        r_requset,//001
        r_tran,//010
        w_requset,//011
        w_tran,//100
        b_resp//101
    } dram_state, nxt_dram_state;
    enum logic[1:0] { 
        afs_idle,
        calc,
        wait_output
    } afs_state, nxt_afs_state;
    //==============================================//
    //                    design                    //
    // ============================================ //
    always_ff @(posedge clk) begin
        if(inf.sel_action_valid) action_reg <= inf.D.d_act;
    end
    always_ff @(posedge clk) begin
        if(inf.strategy_valid) str_reg <= inf.D.d_strategy;
    end
    always_ff @(posedge clk) begin
        if(inf.mode_valid) mode_reg <= inf.D.d_mode;
    end
    always_ff @(posedge clk) begin
        if(inf.date_valid) {month_reg, day_reg} <= inf.D.d_data_no;
    end
    always_ff @(posedge clk) begin
        if(inf.restock_valid)begin
            stock_reg[3] <= inf.D.d_stock;
            stock_reg[2] <= stock_reg[3];
            stock_reg[1] <= stock_reg[2];
            stock_reg[0] <= stock_reg[1];
        end
    end
    always_ff @(posedge clk or negedge inf.rst_n) begin
        if(!inf.rst_n) stock_cnt <= 2'b0;
        else if(inf.restock_valid) stock_cnt <= stock_cnt + 1'b1;
    end
    always_ff @(posedge clk or negedge inf.rst_n) begin
        if(!inf.rst_n) stock_valid <= 0;
        else if(inf.out_valid) stock_valid <= 0;
        else if(inf.restock_valid & &stock_cnt) stock_valid <= 1;
    end
    always_comb begin
        dram_flower[0] = dram_data_reg[63-:12];
        dram_flower[1] = dram_data_reg[51-:12];
        dram_flower[2] = dram_data_reg[31-:12];
        dram_flower[3] = dram_data_reg[19-:12];
        dram_m = dram_data_reg[35-: 4];
        dram_d = dram_data_reg[ 4-: 5];
    end
    always_ff @(posedge clk) begin
        if(~|action_reg)
            flag_stock_warn <= (dram_data_reg[63-:12] < demand_flower[0] ||
                                dram_data_reg[51-:12] < demand_flower[1] ||
                                dram_data_reg[31-:12] < demand_flower[2] ||
                                dram_data_reg[19-:12] < demand_flower[3] );
        else flag_stock_warn <= 0;
    end
    always_ff @(posedge clk) begin
        if(action_reg[0])begin
            flag_overflow[0] <= ~dram_data_reg[63-:12] < stock_reg[0];
            flag_overflow[1] <= ~dram_data_reg[51-:12] < stock_reg[1];
            flag_overflow[2] <= ~dram_data_reg[31-:12] < stock_reg[2];
            flag_overflow[3] <= ~dram_data_reg[19-:12] < stock_reg[3];
        end else flag_overflow <= 4'b0;
    end
    always_ff @(posedge clk) begin
        if(~action_reg[0])
            flag_date_warn <= (month_reg < dram_data_reg[35-:4] || (month_reg == dram_data_reg[35-:4] && day_reg < dram_data_reg[4-:5]));
        else flag_date_warn <= 0;
    end
    always_comb begin
        case (mode_reg)
            Event: total_flower = 10'd960;
            Group_Order: total_flower = 10'd480;
            default: total_flower = 10'd120;
        endcase
    end
    always_ff @(posedge clk) begin
        case (str_reg)
            Strategy_A: {demand_flower[0], demand_flower[1], demand_flower[2], demand_flower[3]} <= {total_flower, 10'b0, 10'b0, 10'b0};
            Strategy_B: {demand_flower[0], demand_flower[1], demand_flower[2], demand_flower[3]} <= {10'b0, total_flower, 10'b0, 10'b0};
            Strategy_C: {demand_flower[0], demand_flower[1], demand_flower[2], demand_flower[3]} <= {10'b0, 10'b0, total_flower, 10'b0};
            Strategy_D: {demand_flower[0], demand_flower[1], demand_flower[2], demand_flower[3]} <= {10'b0, 10'b0, 10'b0, total_flower};
            Strategy_E: {demand_flower[0], demand_flower[1], demand_flower[2], demand_flower[3]} <= {total_flower >> 1, total_flower >> 1, 10'b0, 10'b0};
            Strategy_F: {demand_flower[0], demand_flower[1], demand_flower[2], demand_flower[3]} <= {10'b0, 10'b0, total_flower >> 1, total_flower >> 1};
            Strategy_G: {demand_flower[0], demand_flower[1], demand_flower[2], demand_flower[3]} <= {total_flower >> 1, 10'b0, total_flower >> 1, 10'b0};
            default:    {demand_flower[0], demand_flower[1], demand_flower[2], demand_flower[3]} <= {4{total_flower >> 2}};
        endcase
    end
    //==============================================//
    //                   dram ctrl                  //
    // ============================================ //
    always_ff @(posedge clk or negedge inf.rst_n) begin //todo: redundant bit at MD
        if(!inf.rst_n) begin
            dram_data_reg[63:40] <= 24'b0;
            dram_data_reg[35:8]  <= 28'b0;
            dram_data_reg[4:0]   <= 5'b0;
        end
        else if(inf.out_valid) begin
            case (action_reg)
                Restock:begin
                        dram_data_reg[63-:12] <= (flag_overflow[0])? 12'd4095:dram_data_reg[63-:12] + stock_reg[0];
                        dram_data_reg[51-:12] <= (flag_overflow[1])? 12'd4095:dram_data_reg[51-:12] + stock_reg[1];
                        dram_data_reg[31-:12] <= (flag_overflow[2])? 12'd4095:dram_data_reg[31-:12] + stock_reg[2];
                        dram_data_reg[19-:12] <= (flag_overflow[3])? 12'd4095:dram_data_reg[19-:12] + stock_reg[3];
                        dram_data_reg[35-: 4] <= month_reg;
                        dram_data_reg[ 4-: 5] <= day_reg;
                end
                Purchase:begin
                        dram_data_reg[63-:12] <= dram_data_reg[63-:12] - demand_flower[0];
                        dram_data_reg[51-:12] <= dram_data_reg[51-:12] - demand_flower[1];
                        dram_data_reg[31-:12] <= dram_data_reg[31-:12] - demand_flower[2];
                        dram_data_reg[19-:12] <= dram_data_reg[19-:12] - demand_flower[3];
                end
                default: begin
                    dram_data_reg[63:40] <= dram_data_reg[63:40];
                    dram_data_reg[35:8]  <= dram_data_reg[35:8];
                    dram_data_reg[4:0]   <= dram_data_reg[4:0];
                end
            endcase
        end
        else if(inf.R_VALID) begin
            dram_data_reg[63:40] <= inf.R_DATA[63:40];
            dram_data_reg[35:8]  <= inf.R_DATA[35:8];
            dram_data_reg[4:0]   <= inf.R_DATA[4:0];
        end
    end
    always_ff @(posedge clk or negedge inf.rst_n) begin
        if(!inf.rst_n) dram_r_pending <= 0;
        else if(inf.data_no_valid) dram_r_pending <= 1;
        else if(inf.R_VALID) dram_r_pending <= 0;
    end
    always_ff @(posedge clk or negedge inf.rst_n) begin
        if(!inf.rst_n) dram_data_dirty <= 0;
        else if(inf.W_READY) dram_data_dirty <= 0;
        else if( action_reg[0] & stock_valid & ~dram_r_pending) dram_data_dirty <= 1;
        else if(~action_reg[1] & inf.complete) dram_data_dirty <= 1;
    end
    always_ff @(posedge clk or negedge inf.rst_n) begin
        if(!inf.rst_n) demand_dram_no <= 8'b0;
        else if(inf.data_no_valid) demand_dram_no <= inf.D.d_data_no[0];
    end
    always_ff @(posedge clk or negedge inf.rst_n) begin
        if(!inf.rst_n) curent_dram_no <= 8'b0;
        else if(inf.R_VALID) curent_dram_no <= demand_dram_no;
    end
    //==============================================//
    //                      FSM                     //
    // ============================================ //

    always_comb begin
        case (dram_state)
            dram_idle: nxt_dram_state = dram_data_dirty? w_requset:(inf.data_no_valid | dram_r_pending)? r_requset:dram_idle;
            r_requset: nxt_dram_state = r_tran;
            r_tran: nxt_dram_state = inf.R_VALID? dram_idle:r_tran;
            w_requset: nxt_dram_state = w_tran;
            w_tran: nxt_dram_state = inf.W_READY? b_resp:w_tran;
            b_resp: nxt_dram_state = inf.B_VALID? (inf.data_no_valid | dram_r_pending)? r_requset:dram_idle:b_resp;
            default: nxt_dram_state = dram_idle;
        endcase
    end
    always_ff @(posedge clk or negedge inf.rst_n) begin
        if(!inf.rst_n) dram_state <= dram_idle;
        else dram_state <= nxt_dram_state;
    end
    always_comb begin
        if(afs_state == wait_output)begin
            if(|flag_overflow) inf.warn_msg = Restock_Warn;
            else if(flag_date_warn) inf.warn_msg = Date_Warn;
            else if(flag_stock_warn) inf.warn_msg = Stock_Warn;
            else inf.warn_msg = No_Warn;
        end
        else inf.warn_msg = No_Warn;
    end
    assign inf.out_valid = afs_state == wait_output;
    assign inf.complete = inf.out_valid && inf.warn_msg == No_Warn;
    assign inf.R_READY = dram_state[1];
    assign inf.B_READY = dram_state[2];
    assign inf.W_DATA  = {dram_data_reg[63:40], 4'b0, dram_data_reg[35:8], 3'b0, dram_data_reg[4:0]};
    assign inf.AR_VALID  = dram_state == r_requset;
    assign inf.AW_VALID  = dram_state == w_requset;
    assign inf.W_VALID  = dram_state == w_tran;
    assign inf.AR_ADDR  = |dram_state? {9'h020, demand_dram_no, 3'b0}:{9'b0, demand_dram_no, 3'b0};
    assign inf.AW_ADDR  = |dram_state? {9'h020, curent_dram_no, 3'b0}:{9'b0, curent_dram_no, 3'b0};

    always_comb begin
        case (afs_state)
            afs_idle:begin
                if(action_reg[0])
                     nxt_afs_state = (stock_valid & ~dram_r_pending)? calc:afs_idle;
                else nxt_afs_state = (inf.R_VALID)? calc:afs_idle;
            end
            calc: nxt_afs_state = wait_output;
            wait_output: nxt_afs_state = afs_idle;
            default: nxt_afs_state = afs_idle;
        endcase
    end
    always_ff @(posedge clk or negedge inf.rst_n) begin
        if(!inf.rst_n) afs_state <= afs_idle;
        else afs_state <= nxt_afs_state;
    end
endmodule
