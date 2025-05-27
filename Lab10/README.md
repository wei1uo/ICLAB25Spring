3. sta x mode 100times(2400) -> purchase at least 2400
4. warn_msg 00_no(all) 01_dat(check or pur) 10_sto(purchase) 11_res(rest) x 10 times -> pur and res at least 10
5. {pur,res,che} x {pur,res,che} 300times : 1-1-2-1-3-2-2-3-3-(1) => 2701 total, 901 pur, 900 res & che 
6. auto bin max 32 restock amount -> restock at least 32 times

ta design ta pattern: p17 c7 r13
my pattern: p17 c7 r12

5 -> (900 900 900) (meanwhile 46)

purchase: 7(date warn) 8(no warn)
restock: 12
check valid: 7
