
// `include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;
//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
parameter MAX_CYCLE=1000;
parameter PAT_NUM = 4200;
parameter RAND_SEED = 45;
integer total_latency, current_latency, cnt_purchase;
//================================================================
// wire & registers 
//================================================================
logic [7:0] golden_DRAM [((65536+8*256)-1):(65536+0)];  // 256 box
logic [11:0] temp_stock[0:3], temp_required[0:3];
logic [ 9:0] total_required;
logic [63:0] dram_read;
logic        out_of_stock;
Warn_Msg     golden_msg;
wire         golden_complete = golden_msg === No_Warn;
Data_Dir     dram_box, display_box;
wire[1:0]    act_seq[0:8] = {Purchase, Purchase, Restock, Purchase, Check_Valid_Date, Restock, Restock, Check_Valid_Date, Check_Valid_Date};
wire[1:0]    mod_seq[0:2] = {Single, Group_Order, Event};
//================================================================
// class random
//================================================================

/**
 * Class representing a random action.
 */
class random_act;
    randc Action act_id;
    constraint range{
        act_id inside{Purchase, Restock, Check_Valid_Date};
    }
    function new();
        this.srandom(RAND_SEED);
    endfunction
endclass

class random_order;
    randc Order_Info order_id;
    constraint range{
        order_id.Mode_O inside{Single, Group_Order, Event};
    }
    function new();
        this.srandom(RAND_SEED);
    endfunction
endclass

class random_date;
    randc Date date_id;
    constraint range{
        date_id.M inside{[1:12]};
       (date_id.M ==  1| date_id.M == 3 | date_id.M ==  5 | 
        date_id.M ==  7| date_id.M == 8 | date_id.M == 10 | 
        date_id.M == 12) -> !(date_id.D inside{0});
       (date_id.M ==  4| date_id.M == 6 | date_id.M ==  9 | 
        date_id.M == 11) -> !(date_id.D inside{0, 31});
       (date_id.M ==  2) -> !(date_id.D inside{0, [29:31]});
    }
    function new();
        this.srandom(RAND_SEED);
    endfunction
endclass

class random_stock;
    randc Stock stock_id;
    constraint range{
        stock_id inside{[0:4095]};
    }
    function new();
        this.srandom(RAND_SEED);
    endfunction
endclass

Data_No dram_no;
random_act act;
random_order order;
random_date date;
random_stock stock;
int cur_pat;
//================================================================
// initial
//================================================================

initial begin
    $readmemh(DRAM_p_r, golden_DRAM);
    dram_no = 0;
    act = new();
    order = new();
    cnt_purchase = 0;
    date = new();
    stock = new();
    task_rst;

    total_latency = 0;
    for(cur_pat = 0; cur_pat < PAT_NUM; cur_pat++)begin
        task_input;
        task_check_ans;
        $display(" \033[0;32mPass Pattern NO. %2d\033[m \033[0;34mLatency: %3d\033[m ", cur_pat, current_latency);
    end
    display_pass;
end

task task_rst;begin
    inf.rst_n = 0;
    inf.sel_action_valid = 0;
    inf.strategy_valid = 0;
    inf.mode_valid = 0;
    inf.date_valid = 0;
    inf.data_no_valid = 0;
    inf.restock_valid = 0;
    inf.D = 72'bx;
    #1 inf.rst_n = 1;
    // if(inf.out_valid !== 1'b0 || inf.warn_msg !== 2'b0 || inf.complete !== 1'b0)begin
    //     display_fail;
    //     $display("==================================================");
	// 	$display("             Signals should be reseted!           ");
	// 	$display("              out_valid =  %b", inf.out_valid);
	// 	$display("              complete  =  %b", inf.complete);
	// 	$display("              warn_msg  = %b", inf.warn_msg);
    //     $display("==================================================");
    //     $finish;
    // end
end endtask

task task_input;begin

    act.act_id = (cur_pat < 2700)? act_seq[cur_pat % 9]:Purchase;

    inf.sel_action_valid = 1;
    inf.D.d_act[0] = act.act_id;
    @(negedge clk);
    inf.sel_action_valid = 0;
    inf.D = 72'bx;
    // Purchase: Strategy Type -> Mode -> Today’s Date -> No. of data in DRAM.
    // Restock: Data Date -> No. of data in DRAM -> Restock amount of xxx
    // Check: Today’s Date -> No. of data in DRAM
    if(act.act_id == Purchase)begin

        order.order_id.Strategy_Type_O = cnt_purchase/100;
        order.order_id.Mode_O = mod_seq[cnt_purchase/800];
        cnt_purchase++;
        inf.strategy_valid = 1;
        inf.D.d_strategy[0] = order.order_id.Strategy_Type_O;
        @(negedge clk);
        inf.strategy_valid = 0;
        inf.D = 72'bx;

        inf.mode_valid = 1;
        inf.D.d_mode[0] = order.order_id.Mode_O;
        @(negedge clk);
        inf.mode_valid = 0;
        inf.D = 72'bx;
    end
    if(act.act_id == Purchase && cnt_purchase < 11)begin
        date.date_id.M = 12;
        date.date_id.D = 30;
        dram_no = 0;
    end else if(act.act_id == Purchase)begin
        date.date_id.M = 1;
        date.date_id.D = 1;
        dram_no = 0;
    end else begin
        date.date_id.M = cur_pat % 12 + 1;
        date.date_id.D = cur_pat % 28 + 1;
        dram_no = cur_pat % 255 + 1;
    end

    inf.date_valid = 1;
    inf.D.d_date[0] = {date.date_id.M, date.date_id.D};
    @(negedge clk);
    inf.date_valid = 0;
    inf.D = 72'bx;

    inf.data_no_valid = 1;
    inf.D.d_data_no[0] = dram_no;
    @(negedge clk);
    inf.data_no_valid = 0;
    inf.D = 72'bx;

    if(act.act_id == Restock)begin
        for(int i = 0; i < 4; i++)begin // temp[0:3] = {Rose, Lily, Carnation, Baby’s Breath.}

            stock.stock_id = cur_pat % 32 * 128;

            inf.restock_valid = 1;
            inf.D.d_stock[0] = stock.stock_id;
            temp_stock[i] = stock.stock_id;
            @(negedge clk);
            inf.restock_valid = 0;
            inf.D = 72'bx;
        end
    end
end endtask

task task_check_ans;begin
    golden_msg = No_Warn;
    for(int i = 0; i < 8; i++)
        dram_read[8*i+:8] = golden_DRAM[i+'h10000 + 8*dram_no];
    dram_box.D = dram_read[0+:8];
    dram_box.Baby_Breath = dram_read[8+:12];
    dram_box.Carnation = dram_read[20+:12];
    dram_box.M = dram_read[32+:8];
    dram_box.Lily = dram_read[40+:12];
    dram_box.Rose = dram_read[52+:12];
    display_box = dram_box;
    
    case (act.act_id)
        Purchase:begin
            total_required = 120 + 360*order.order_id.Mode_O[0] + 480*order.order_id.Mode_O[1];
            temp_required[0] = (order.order_id.Strategy_Type_O == 'd7)? total_required/4:(order.order_id.Strategy_Type_O == 'd6 || order.order_id.Strategy_Type_O == 'd4)? total_required/2: (order.order_id.Strategy_Type_O == 'd0)? total_required: 'd0;
            temp_required[1] = (order.order_id.Strategy_Type_O == 'd7)? total_required/4:(order.order_id.Strategy_Type_O == 'd4)? total_required/2: (order.order_id.Strategy_Type_O == 'd1)? total_required: 'd0;
            temp_required[2] = (order.order_id.Strategy_Type_O == 'd7)? total_required/4:(order.order_id.Strategy_Type_O == 'd6 || order.order_id.Strategy_Type_O == 'd5)? total_required/2: (order.order_id.Strategy_Type_O == 'd2)? total_required: 'd0;
            temp_required[3] = (order.order_id.Strategy_Type_O == 'd7)? total_required/4:(order.order_id.Strategy_Type_O == 'd5)? total_required/2: (order.order_id.Strategy_Type_O == 'd3)? total_required: 'd0;
            out_of_stock = (temp_required[0] > dram_box.Rose)||
                           (temp_required[1] > dram_box.Lily)||
                           (temp_required[2] > dram_box.Carnation)||
                           (temp_required[3] > dram_box.Baby_Breath);
            if(date.date_id.M < dram_box.M || (date.date_id.M == dram_box.M && date.date_id.D < dram_box.D))begin
                golden_msg = Date_Warn;
            end else if(out_of_stock)begin
                golden_msg = Stock_Warn;
            end else begin
                dram_box.Baby_Breath = dram_box.Baby_Breath - temp_required[3];
                dram_box.Carnation = dram_box.Carnation - temp_required[2];
                dram_box.Lily = dram_box.Lily - temp_required[1];
                dram_box.Rose = dram_box.Rose - temp_required[0];
            end
        end
        Restock:begin
            dram_box.D = date.date_id.D;
            dram_box.M = date.date_id.M;
            if(~dram_box.Baby_Breath < temp_stock[3])begin
                dram_box.Baby_Breath = 'hfff;
                golden_msg = Restock_Warn;
            end else 
                dram_box.Baby_Breath = dram_box.Baby_Breath + temp_stock[3];
            if(~dram_box.Carnation < temp_stock[2])begin
                dram_box.Carnation = 'hfff;
                golden_msg = Restock_Warn;
            end else 
                dram_box.Carnation = dram_box.Carnation + temp_stock[2];
            if(~dram_box.Lily < temp_stock[1])begin
                dram_box.Lily = 'hfff;
                golden_msg = Restock_Warn;
            end else 
                dram_box.Lily = dram_box.Lily + temp_stock[1];
            if(~dram_box.Rose < temp_stock[0])begin
                dram_box.Rose = 'hfff;
                golden_msg = Restock_Warn;
            end else 
                dram_box.Rose = dram_box.Rose + temp_stock[0];
        end
        Check_Valid_Date:begin
            if(date.date_id.M < dram_box.M || (date.date_id.M == dram_box.M && date.date_id.D < dram_box.D))begin
                golden_msg = Date_Warn;
            end
        end
    endcase

    dram_read[0+:8] = dram_box.D;
    dram_read[8+:12] = dram_box.Baby_Breath;
    dram_read[20+:12] = dram_box.Carnation;
    dram_read[32+:8] = dram_box.M;
    dram_read[40+:12] = dram_box.Lily;
    dram_read[52+:12] = dram_box.Rose;
    for(int i = 0; i < 8; i++)
        golden_DRAM[i+'h10000 + 8*dram_no] = dram_read[8*i+:8];

    current_latency = 0;
    while(inf.out_valid === 0)begin
        current_latency++;
        // if(current_latency >= MAX_CYCLE)begin
        //     display_fail;
        //     $display("==================================================");
        //     $display("             Latency should < 1000 !");
        //     $display("==================================================");
        //     $finish;
        // end
        @(negedge clk);
    end
    if(inf.complete !== golden_complete || inf.warn_msg !== golden_msg)begin
        display_fail;
        $display("==================================================");
		$display("          golden complete, msg = %b, %s", golden_complete, golden_msg.name());
		$display("            your complete, msg = %b, %s", inf.complete, inf.warn_msg.name());
        $display("==================================================");
		$display("                       dram.no = %d", dram_no);
		$display("                    Month, Day = %d, %d", display_box.M, display_box.D);
		$display("                    Rose, Lily = %d, %d", display_box.Rose, display_box.Lily);
		$display("        Carnation, Baby_Breath = %d, %d", display_box.Carnation, display_box.Baby_Breath);
        $display("==================================================");
        $finish;
    end
    @(negedge clk);
    total_latency = total_latency + current_latency;
end endtask

task display_fail;begin
    $display("==================================================");
	$display("                   Wrong Answer                   ");
end endtask

task display_pass;begin
	$display("==================================================");
	$display("                  Congratulations                 ");
	$display("              execution cycles = %7d", total_latency);
	$display("==================================================");
end endtask

endprogram
