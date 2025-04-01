// `include "cpu.v"

module cpu_top(
    input wire clk,
    input wire reset_n,
    output wire RW,

    output wire addr_0,
    output wire addr_1,
    output wire addr_2,
    output wire addr_3,
    output wire addr_4,
    output wire addr_5,
    output wire addr_6,
    output wire addr_7,
    output wire addr_8,
    output wire addr_9,
    output wire addr_10,
    output wire addr_11,
    output wire addr_12,
    output wire addr_13,
    output wire addr_14,
    output wire addr_15,

    inout wire data_0,
    inout wire data_1,
    inout wire data_2,
    inout wire data_3,
    inout wire data_4,
    inout wire data_5,
    inout wire data_6,
    inout wire data_7,

);
    wire clk_phy;
    wire reset_n_phy;
    wire rw_phy;

    wire addr_phy_0;
    wire addr_phy_1;
    wire addr_phy_2;
    wire addr_phy_3;
    wire addr_phy_4;
    wire addr_phy_5;
    wire addr_phy_6;
    wire addr_phy_7;
    wire addr_phy_8;
    wire addr_phy_9;
    wire addr_phy_10;
    wire addr_phy_11;
    wire addr_phy_12;
    wire addr_phy_13;
    wire addr_phy_14;
    wire addr_phy_15;

    wire data_in_phy_0;
    wire data_in_phy_1;
    wire data_in_phy_2;
    wire data_in_phy_3;
    wire data_in_phy_4;
    wire data_in_phy_5;
    wire data_in_phy_6;
    wire data_in_phy_7;

    wire data_out_phy_0;
    wire data_out_phy_1;
    wire data_out_phy_2;
    wire data_out_phy_3;
    wire data_out_phy_4;
    wire data_out_phy_5;
    wire data_out_phy_6;
    wire data_out_phy_7;
    // Instantiate CPU
    CPU cpu_inst (
        .clk(clk_phy),
        .reset_n(reset_n_phy),
        .RDY(1'b1),
        .SO(1'b0),
        .RW(rw_phy),
        .addr({addr_phy_15, addr_phy_14, addr_phy_13, addr_phy_12, addr_phy_11, addr_phy_10, addr_phy_9, addr_phy_8, addr_phy_7, addr_phy_6, addr_phy_5, addr_phy_4, addr_phy_3, addr_phy_2, addr_phy_1, addr_phy_0}),
        .data_in({data_in_phy_7, data_in_phy_6, data_in_phy_5, data_in_phy_4, data_in_phy_3, data_in_phy_2, data_in_phy_1, data_in_phy_0}),
        .data_out({data_out_phy_7, data_out_phy_6, data_out_phy_5, data_out_phy_4, data_out_phy_3, data_out_phy_2, data_out_phy_1, data_out_phy_0})
    );

// this will connect clk to core_clk similar to "assign clk_phy = clk;"
// and is needed so it gets connected to the actual pad
(* keep *) sg13g2_IOPadIn u_pad_clk (.pad(clk), .p2c(clk_phy));
(* keep *) sg13g2_IOPadIn u_pad_reset_n (.pad(reset_n), .p2c(reset_n_phy));


(* keep *) sg13g2_IOPadInOut4mA u_pad_data_0 (
    .pad    (data_0          ), //~
    .c2p    (data_in_phy_0   ), //i
    .c2p_en (rw_phy          ), //i
    .p2c    (data_out_phy_0  ) //o
);
(* keep *) sg13g2_IOPadInOut4mA u_pad_data_1 (
    .pad    (data_1          ), //~
    .c2p    (data_in_phy_1   ), //i
    .c2p_en (rw_phy          ), //i
    .p2c    (data_out_phy_1  )  //o
);
(* keep *) sg13g2_IOPadInOut4mA u_pad_data_2 (
    .pad    (data_2          ), //~
    .c2p    (data_in_phy_2   ), //i
    .c2p_en (rw_phy          ), //i
    .p2c    (data_out_phy_2  )  //o
);
(* keep *) sg13g2_IOPadInOut4mA u_pad_data_3 (
    .pad    (data_3          ), //~
    .c2p    (data_in_phy_3   ), //i
    .c2p_en (rw_phy          ), //i
    .p2c    (data_out_phy_3  )  //o
);
(* keep *) sg13g2_IOPadInOut4mA u_pad_data_4 (
    .pad    (data_4          ), //~
    .c2p    (data_in_phy_4   ), //i
    .c2p_en (rw_phy          ), //i
    .p2c    (data_out_phy_4  )  //o
);
(* keep *) sg13g2_IOPadInOut4mA u_pad_data_5 (
    .pad    (data_5          ), //~
    .c2p    (data_in_phy_5   ), //i
    .c2p_en (rw_phy          ), //i
    .p2c    (data_out_phy_5  )  //o
);
(* keep *) sg13g2_IOPadInOut4mA u_pad_data_6 (
    .pad    (data_6          ), //~
    .c2p    (data_in_phy_6   ), //i
    .c2p_en (rw_phy          ), //i
    .p2c    (data_out_phy_6  )  //o
);
(* keep *) sg13g2_IOPadInOut4mA u_pad_data_7 (
    .pad    (data_7          ), //~
    .c2p    (data_in_phy_7   ), //i
    .c2p_en (rw_phy          ), //i
    .p2c    (data_out_phy_7  )  //o
);

// (* keep *) sg13g2_IOPadOut4mA u_pad_addr (.pad(addr), .c2p(addr_phy)); // 16 bit bus
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_0 (.pad(addr_0), .c2p(addr_phy_0));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_1 (.pad(addr_1), .c2p(addr_phy_1));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_2 (.pad(addr_2), .c2p(addr_phy_2));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_3 (.pad(addr_3), .c2p(addr_phy_3));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_4 (.pad(addr_4), .c2p(addr_phy_4));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_5 (.pad(addr_5), .c2p(addr_phy_5));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_6 (.pad(addr_6), .c2p(addr_phy_6));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_7 (.pad(addr_7), .c2p(addr_phy_7));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_8 (.pad(addr_8), .c2p(addr_phy_8));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_9 (.pad(addr_9), .c2p(addr_phy_9));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_10 (.pad(addr_10), .c2p(addr_phy_10));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_11 (.pad(addr_11), .c2p(addr_phy_11));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_12 (.pad(addr_12), .c2p(addr_phy_12));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_13 (.pad(addr_13), .c2p(addr_phy_13));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_14 (.pad(addr_14), .c2p(addr_phy_14));
(* keep *) sg13g2_IOPadOut4mA u_pad_addr_15 (.pad(addr_15), .c2p(addr_phy_15));


(* keep *) sg13g2_IOPadOut4mA u_pad_rw (.pad(RW), .c2p(rw_phy));




(* keep *) sg13g2_IOPadIOVdd u_pad_vddpad_0 ();
(* keep *) sg13g2_IOPadIOVdd u_pad_vddpad_1 ();

(* keep *) sg13g2_IOPadVdd u_pad_vddcore_0 ();
(* keep *) sg13g2_IOPadVdd u_pad_vddcore_1 ();

(* keep *) sg13g2_IOPadIOVss u_pad_gndpad_0 ();
(* keep *) sg13g2_IOPadIOVss u_pad_gndpad_1 ();

(* keep *) sg13g2_IOPadVss u_pad_gndcore_0 ();
(* keep *) sg13g2_IOPadVss u_pad_gndcore_1 ();


endmodule
