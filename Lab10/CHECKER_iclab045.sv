/*
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
NYCU Institute of Electronic
2025 Spring IC Design Laboratory 
Lab10: SystemVerilog Coverage & Assertion
File Name   : CHECKER.sv
Module Name : CHECKER
Release version : v1.0 (Release Date: May-2025)
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
*/

`include "Usertype.sv"
module Checker(input clk, INF.CHECKER inf);
import usertype::*;

// integer fp_w;

// initial begin
// fp_w = $fopen("out_valid.txt", "w");
// end

/**
 * This section contains the definition of the class and the instantiation of the object.
 *  * 
 * The always_ff blocks update the object based on the values of valid signals.
 * When valid signal is true, the corresponding property is updated with the value of inf.D
 */

// class Strategy_and_mode;
//     Strategy_Type f_type;
//     Mode f_mode;
// endclass

// Strategy_and_mode fm_info = new();

logic [2:0] sta;
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) sta <= 0;
    else if(inf.strategy_valid) sta <= inf.D.d_strategy[0];
end

// COVERAGE:
// 1. Each case of Strategy_Type should be select at least 100 times.
// 2. Each case of Mode should be select at least 100 times.
// 3. Create a cross bin for the SPEC1 and SPEC2. Each combination should be selected at least 100
// times. (Strategy_A,B,C,D,E,F,G,H) x (Single, Group_Order, Event)
covergroup cg_123 @(posedge clk iff inf.mode_valid);
    option.at_least = 100;
    strategy: coverpoint sta;
    mode: coverpoint inf.D.d_mode[0] {
        bins mod[] = {[0:3]};
        ignore_bins ign[] = {2};
    }
    cross strategy, mode;
endgroup

// 4. Output signal inf.warn_msg should be"No_Warn","Date_Warn","Stock_Warn","Restock_Warn",
// each at least 10 times. (Sample the value when inf.out_valid is high)
covergroup cg_4 @(posedge clk iff inf.out_valid);
    option.at_least = 10;
    coverpoint inf.warn_msg {
        bins err[] = {[0:3]};
    }
endgroup

// 5. Create the transitions bin for the inf.D.act[0] signal from [Purchase:Check_Valid_Date] to
// [Purchase:Check_Valid_Date]. Each transition should be hit at least 300 times. (sample the value
// at posedge clk iff inf.sel_action_valid)
covergroup cg_5 @(posedge clk iff inf.sel_action_valid);
    option.at_least = 300;
    coverpoint inf.D.d_act[0] {
        bins transition[] = ([0:2] => [0:2]);
    }
endgroup

// 6. Create a covergroup for flower of restock action with auto_bin_max = 32, and each bin have to
// hit at least one time.
covergroup cg_6 @(posedge clk iff inf.restock_valid);
    option.auto_bin_max = 32;
    coverpoint inf.D.d_stock[0];
endgroup

cg_123 cg123 = new();
cg_4 cg4 = new();
cg_5 cg5 = new();
cg_6 cg6 = new();

final begin
  $display("[CHECKER] Spec123 Coverage: %0.2f%%", cg123.get_coverage());
  $display("[CHECKER] Spec4 Coverage: %0.2f%%", cg4.get_coverage());
  $display("[CHECKER] Spec5 Coverage: %0.2f%%", cg5.get_coverage());
  $display("[CHECKER] Spec6 Coverage: %0.2f%%", cg6.get_coverage());
end

// ASSERTION:
// 1. All outputs signals (including AFS.sv) should be zero after reset.
property spec_1;
    @(negedge inf.rst_n) 1 |-> @(posedge inf.rst_n)
    (inf.out_valid === 0 && inf.warn_msg === 0 && inf.complete === 0 &&
    inf.AR_VALID === 0 && inf.AR_ADDR === 0 && inf.R_READY === 0 &&
    inf.AW_VALID === 0 && inf.AW_ADDR === 0 && inf.W_VALID === 0 &&
    inf.W_DATA === 64'b0 && inf.B_READY === 0);
endproperty
assert property (spec_1) else display_assert("1");

// 2. Latency should be less than 1000 cycles for each operation.
property spec_2;
    @(posedge clk)
    (inf.data_no_valid === 1) |-> ##[1:1000] inf.out_valid; //todo: restock incorrect
endproperty
assert property (spec_2) else display_assert("2");

// 3. If action is completed (complete=1), warn_msg should be 2'b0 (No_Warn).
property spec_3;
    @(negedge clk)
    inf.complete |-> inf.warn_msg === 2'b0;
endproperty
assert property (spec_3) else display_assert("3");

// 4. Next input valid will be valid 1-4 cycles after previous input valid fall.
property spec_4_1;
    @(posedge clk)
    inf.sel_action_valid && inf.D.d_act[0] == Purchase |-> ##[1:4] inf.strategy_valid ##[1:4] inf.mode_valid ##[1:4] inf.date_valid ##[1:4] inf.data_no_valid;
endproperty
property spec_4_2;
    @(posedge clk)
    inf.sel_action_valid && inf.D.d_act[0] == Restock |-> ##[1:4] inf.date_valid ##[1:4] inf.data_no_valid ##[1:4] inf.restock_valid ##[1:4] inf.restock_valid ##[1:4] inf.restock_valid ##[1:4] inf.restock_valid;
endproperty
property spec_4_3;
    @(posedge clk)
    inf.sel_action_valid && inf.D.d_act[0] == Check_Valid_Date |-> ##[1:4] inf.date_valid ##[1:4] inf.data_no_valid;
endproperty
assert property (spec_4_1) else display_assert("4");
assert property (spec_4_2) else display_assert("4");
assert property (spec_4_3) else display_assert("4");

// 5. All input valid signals won't overlap with each other.
property spec_5_1;
    @(posedge clk)
    inf.sel_action_valid |-> !(inf.strategy_valid || inf.mode_valid || inf.date_valid || inf.data_no_valid || inf.restock_valid);
endproperty
property spec_5_2;
    @(posedge clk)
    inf.strategy_valid |-> !(inf.sel_action_valid || inf.mode_valid || inf.date_valid || inf.data_no_valid || inf.restock_valid);
endproperty
property spec_5_3;
    @(posedge clk)
    inf.mode_valid |-> !(inf.sel_action_valid || inf.strategy_valid || inf.date_valid || inf.data_no_valid || inf.restock_valid);
endproperty
property spec_5_4;
    @(posedge clk)
    inf.date_valid |-> !(inf.sel_action_valid || inf.strategy_valid || inf.mode_valid || inf.data_no_valid || inf.restock_valid);
endproperty
property spec_5_5;
    @(posedge clk)
    inf.data_no_valid |-> !(inf.sel_action_valid || inf.strategy_valid || inf.mode_valid || inf.date_valid || inf.restock_valid);
endproperty
property spec_5_6;
    @(posedge clk)
    inf.restock_valid |-> !(inf.sel_action_valid || inf.strategy_valid || inf.mode_valid || inf.date_valid || inf.data_no_valid);
endproperty
assert property (spec_5_1) else display_assert("5");
assert property (spec_5_2) else display_assert("5");
assert property (spec_5_3) else display_assert("5");
assert property (spec_5_4) else display_assert("5");
assert property (spec_5_5) else display_assert("5");
assert property (spec_5_6) else display_assert("5");

// 6. Out_valid can only be high for exactly one cycle.
property spec_6;
    @(posedge clk)
    $rose(inf.out_valid) |=> !inf.out_valid;
endproperty
assert property (spec_6) else display_assert("6");

// 7. Next operation will be valid 1-4 cycles after out_valid fall.
property spec_7;
    @(posedge clk)
    $past(inf.out_valid, 1) && !inf.out_valid |-> ##[0:3] inf.sel_action_valid;
endproperty
assert property (spec_7) else display_assert("7");

// 8. Input date from pattern should adhere to the real calendar. 2/29, 3/0, 4/31, 13/1 are illegal.
property spec_8_1;
    @(posedge clk)
    inf.date_valid |-> inf.D.d_date[0].M inside {[1:12]};
endproperty
property spec_8_2;
    @(posedge clk)
    inf.date_valid && (inf.D.d_date[0].M === 1 || 
    inf.D.d_date[0].M === 3 || inf.D.d_date[0].M === 5 || 
    inf.D.d_date[0].M === 7 || inf.D.d_date[0].M === 8 || 
    inf.D.d_date[0].M === 10 || inf.D.d_date[0].M === 12) |-> inf.D.d_date[0].D inside {[1:31]};
endproperty
property spec_8_3;
    @(posedge clk)
    inf.date_valid && (inf.D.d_date[0].M === 4 || 
    inf.D.d_date[0].M === 6 || inf.D.d_date[0].M === 9 || 
    inf.D.d_date[0].M === 11) |-> inf.D.d_date[0].D inside {[1:30]};
endproperty
property spec_8_4;
    @(posedge clk)
    inf.date_valid && (inf.D.d_date[0].M === 2) |-> inf.D.d_date[0].D inside {[1:28]};
endproperty
assert property (spec_8_1) else display_assert("8");
assert property (spec_8_2) else display_assert("8");
assert property (spec_8_3) else display_assert("8");
assert property (spec_8_4) else display_assert("8");

// 9. The AR_VALID signal should not overlap with the AW_VALID signal.
property spec_9;
    @(posedge clk)
    inf.AR_VALID |-> !inf.AW_VALID;
endproperty
assert property (spec_9) else display_assert("9");

task display_assert;
    input string msg;
    begin
        $display("================================================");
        $display("            Assertion %s is violated", msg);
        $display("================================================");
        $fatal;
    end
endtask
endmodule
