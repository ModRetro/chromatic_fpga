//
// File name          :usb_fifo.v
// Module name        :usb_fifo.v
// Created by         :GaoYun Semi
// Author             :winson(Winson)
// Created On         :2022-05-19 18:22 GuangZhou
// Last Modified      :
// Update Count       :2022-05-19 18:22
// Description        :
//                     
//                     
//----------------------------------------------------------------------
//===========================================
`define    EP3_IN_EN
`define    EP3_OUT_EN
`define     EP1_IN_BUF_ASIZE     4'd12
`define     EP2_IN_BUF_ASIZE     4'd12
`define     EP3_IN_BUF_ASIZE     4'd12
`define     EP4_IN_BUF_ASIZE     4'd12
`define     EP5_IN_BUF_ASIZE     4'd12
`define     EP6_IN_BUF_ASIZE     4'd12
`define     EP7_IN_BUF_ASIZE     4'd12
`define     EP8_IN_BUF_ASIZE     4'd12
`define     EP9_IN_BUF_ASIZE     4'd12
`define     EP10_IN_BUF_ASIZE    4'd12
`define     EP11_IN_BUF_ASIZE    4'd12
`define     EP12_IN_BUF_ASIZE    4'd12
`define     EP13_IN_BUF_ASIZE    4'd12
`define     EP14_IN_BUF_ASIZE    4'd12
`define     EP15_IN_BUF_ASIZE    4'd12
`define     EP1_OUT_BUF_ASIZE    4'd12
`define     EP2_OUT_BUF_ASIZE    4'd12
`define     EP3_OUT_BUF_ASIZE    4'd12
`define     EP4_OUT_BUF_ASIZE    4'd12
`define     EP5_OUT_BUF_ASIZE    4'd12
`define     EP6_OUT_BUF_ASIZE    4'd12
`define     EP7_OUT_BUF_ASIZE    4'd12
`define     EP8_OUT_BUF_ASIZE    4'd12
`define     EP9_OUT_BUF_ASIZE    4'd12
`define     EP10_OUT_BUF_ASIZE   4'd12
`define     EP11_OUT_BUF_ASIZE   4'd12
`define     EP12_OUT_BUF_ASIZE   4'd12
`define     EP13_OUT_BUF_ASIZE   4'd12
`define     EP14_OUT_BUF_ASIZE   4'd12
`define     EP15_OUT_BUF_ASIZE   4'd12
`define     EP1_OUT_BUF_AFULL    13'd2048
`define     EP2_OUT_BUF_AFULL    13'd2048
`define     EP3_OUT_BUF_AFULL    13'd2048
`define     EP4_OUT_BUF_AFULL    13'd2048
`define     EP5_OUT_BUF_AFULL    13'd2048
`define     EP6_OUT_BUF_AFULL    13'd2048
`define     EP7_OUT_BUF_AFULL    13'd2048
`define     EP8_OUT_BUF_AFULL    13'd2048
`define     EP9_OUT_BUF_AFULL    13'd2048
`define     EP10_OUT_BUF_AFULL   13'd2048
`define     EP11_OUT_BUF_AFULL   13'd2048
`define     EP12_OUT_BUF_AFULL   13'd2048
`define     EP13_OUT_BUF_AFULL   13'd2048
`define     EP14_OUT_BUF_AFULL   13'd2048
`define     EP15_OUT_BUF_AFULL   13'd2048
module usb_fifo
(
     input              i_clk         //clock
    ,input              i_reset       //reset
    ,input      [3:0]   i_usb_endpt   //
    ,input              i_usb_rxact   //
    ,input              i_usb_rxval   //
    ,input              i_usb_rxpktval//
    ,input      [7:0]   i_usb_rxdat   //
    ,output             o_usb_rxrdy   //
    ,input              i_usb_txact   //
    ,input              i_usb_txpop   //
    ,input              i_usb_txpktfin//
    ,output             o_usb_txcork  //
    ,output     [7:0]   o_usb_txdat   //
    ,output     [11:0]  o_usb_txlen   //
    //Endpoint 1
    `ifdef EP1_IN_EN
    ,input              i_ep1_tx_clk  //
    ,input      [11:0]  i_ep1_tx_max //
    ,input              i_ep1_tx_dval //
    ,input      [7:0]   i_ep1_tx_data //
    `endif
    `ifdef EP1_OUT_EN
    ,input              i_ep1_rx_clk  //
    ,input              i_ep1_rx_rdy  //
    ,output             o_ep1_rx_dval //
    ,output     [7:0]   o_ep1_rx_data //
    `endif
    //Endpoint 2
    `ifdef EP2_IN_EN
    ,input              i_ep2_tx_clk  //
    ,input      [11:0]  i_ep2_tx_max //
    ,input              i_ep2_tx_dval //
    ,input      [7:0]   i_ep2_tx_data //
    `endif
    `ifdef EP2_OUT_EN
    ,input              i_ep2_rx_clk  //
    ,input              i_ep2_rx_rdy  //
    ,output             o_ep2_rx_dval //
    ,output     [7:0]   o_ep2_rx_data //
    `endif
    //Endpoint 3
    `ifdef EP3_IN_EN
    ,input              i_ep3_tx_clk  //
    ,input      [11:0]  i_ep3_tx_max //
    ,input              i_ep3_tx_dval //
    ,input      [7:0]   i_ep3_tx_data //
    `endif
    `ifdef EP3_OUT_EN
    ,input              i_ep3_rx_clk  //
    ,input              i_ep3_rx_rdy  //
    ,output             o_ep3_rx_dval //
    ,output     [7:0]   o_ep3_rx_data //
    `endif
    //Endpoint 4
    `ifdef EP4_IN_EN
    ,input              i_ep4_tx_clk  //
    ,input      [11:0]  i_ep4_tx_max //
    ,input              i_ep4_tx_dval //
    ,input      [7:0]   i_ep4_tx_data //
    `endif
    `ifdef EP4_OUT_EN
    ,input              i_ep4_rx_clk  //
    ,input              i_ep4_rx_rdy  //
    ,output             o_ep4_rx_dval //
    ,output     [7:0]   o_ep4_rx_data //
    `endif
    //Endpoint 5
    `ifdef EP5_IN_EN
    ,input              i_ep5_tx_clk  //
    ,input      [11:0]  i_ep5_tx_max //
    ,input              i_ep5_tx_dval //
    ,input      [7:0]   i_ep5_tx_data //
    `endif
    `ifdef EP5_OUT_EN
    ,input              i_ep5_rx_clk  //
    ,input              i_ep5_rx_rdy  //
    ,output             o_ep5_rx_dval //
    ,output     [7:0]   o_ep5_rx_data //
    `endif
    //Endpoint 6
    `ifdef EP6_IN_EN
    ,input              i_ep6_tx_clk  //
    ,input      [11:0]  i_ep6_tx_max //
    ,input              i_ep6_tx_dval //
    ,input      [7:0]   i_ep6_tx_data //
    `endif
    `ifdef EP6_OUT_EN
    ,input              i_ep6_rx_clk  //
    ,input              i_ep6_rx_rdy  //
    ,output             o_ep6_rx_dval //
    ,output     [7:0]   o_ep6_rx_data //
    `endif
    //Endpoint 7
    `ifdef EP7_IN_EN
    ,input              i_ep7_tx_clk  //
    ,input      [11:0]  i_ep7_tx_max //
    ,input              i_ep7_tx_dval //
    ,input      [7:0]   i_ep7_tx_data //
    `endif
    `ifdef EP7_OUT_EN
    ,input              i_ep7_rx_clk  //
    ,input              i_ep7_rx_rdy  //
    ,output             o_ep7_rx_dval //
    ,output     [7:0]   o_ep7_rx_data //
    `endif
    //Endpoint 8
    `ifdef EP8_IN_EN
    ,input              i_ep8_tx_clk  //
    ,input      [11:0]  i_ep8_tx_max //
    ,input              i_ep8_tx_dval //
    ,input      [7:0]   i_ep8_tx_data //
    `endif
    `ifdef EP8_OUT_EN
    ,input              i_ep8_rx_clk  //
    ,input              i_ep8_rx_rdy  //
    ,output             o_ep8_rx_dval //
    ,output     [7:0]   o_ep8_rx_data //
    `endif
    //Endpoint 9
    `ifdef EP9_IN_EN
    ,input              i_ep9_tx_clk  //
    ,input      [11:0]  i_ep9_tx_max //
    ,input              i_ep9_tx_dval //
    ,input      [7:0]   i_ep9_tx_data //
    `endif
    `ifdef EP9_OUT_EN
    ,input              i_ep9_rx_clk  //
    ,input              i_ep9_rx_rdy  //
    ,output             o_ep9_rx_dval //
    ,output     [7:0]   o_ep9_rx_data //
    `endif
    //Endpoint 10
    `ifdef EP10_IN_EN
    ,input              i_ep10_tx_clk  //
    ,input      [11:0]  i_ep10_tx_max //
    ,input              i_ep10_tx_dval //
    ,input      [7:0]   i_ep10_tx_data //
    `endif
    `ifdef EP10_OUT_EN
    ,input              i_ep10_rx_clk  //
    ,input              i_ep10_rx_rdy  //
    ,output             o_ep10_rx_dval //
    ,output     [7:0]   o_ep10_rx_data //
    `endif
    //Endpoint 11
    `ifdef EP11_IN_EN
    ,input              i_ep11_tx_clk  //
    ,input      [11:0]  i_ep11_tx_max //
    ,input              i_ep11_tx_dval //
    ,input      [7:0]   i_ep11_tx_data //
    `endif
    `ifdef EP11_OUT_EN
    ,input              i_ep11_rx_clk  //
    ,input              i_ep11_rx_rdy  //
    ,output             o_ep11_rx_dval //
    ,output     [7:0]   o_ep11_rx_data //
    `endif
    //Endpoint 12
    `ifdef EP12_IN_EN
    ,input              i_ep12_tx_clk  //
    ,input      [11:0]  i_ep12_tx_max //
    ,input              i_ep12_tx_dval //
    ,input      [7:0]   i_ep12_tx_data //
    `endif
    `ifdef EP12_OUT_EN
    ,input              i_ep12_rx_clk  //
    ,input              i_ep12_rx_rdy  //
    ,output             o_ep12_rx_dval //
    ,output     [7:0]   o_ep12_rx_data //
    `endif
    //Endpoint 13
    `ifdef EP13_IN_EN
    ,input              i_ep13_tx_clk  //
    ,input      [11:0]  i_ep13_tx_max //
    ,input              i_ep13_tx_dval //
    ,input      [7:0]   i_ep13_tx_data //
    `endif
    `ifdef EP13_OUT_EN
    ,input              i_ep13_rx_clk  //
    ,input              i_ep13_rx_rdy  //
    ,output             o_ep13_rx_dval //
    ,output     [7:0]   o_ep13_rx_data //
    `endif
    //Endpoint 14
    `ifdef EP14_IN_EN
    ,input              i_ep14_tx_clk  //
    ,input      [11:0]  i_ep14_tx_max //
    ,input              i_ep14_tx_dval //
    ,input      [7:0]   i_ep14_tx_data //
    `endif
    `ifdef EP14_OUT_EN
    ,input              i_ep14_rx_clk  //
    ,input              i_ep14_rx_rdy  //
    ,output             o_ep14_rx_dval //
    ,output     [7:0]   o_ep14_rx_data //
    `endif
    //Endpoint 15
    `ifdef EP15_IN_EN
    ,input              i_ep15_tx_clk  //
    ,input      [11:0]  i_ep15_tx_max //
    ,input              i_ep15_tx_dval //
    ,input      [7:0]   i_ep15_tx_data //
    `endif
    `ifdef EP15_OUT_EN
    ,input              i_ep15_rx_clk  //
    ,input              i_ep15_rx_rdy  //
    ,output             o_ep15_rx_dval //
    ,output     [7:0]   o_ep15_rx_data //
    `endif

);



wire [15:1] usb_rxrdy ;
wire [15:1] usb_txcork;
wire [ 7:0] usb_txdat [15:1];
wire [11:0] usb_txlen [15:1];
wire [15:1] ep_clk    ;
wire [15:1] ep_rx_rdy ;
wire [15:1] ep_rx_dval;
reg  [ 3:0] s_endpt_sel;
reg         s_usb_txcork;
reg         s_usb_rxrdy ;
reg  [11:0] s_usb_txlen ;
`ifdef EP1_IN_EN
wire [ 7:0] ep1_txdat;
wire        ep1_txcork;
wire [`EP1_IN_BUF_ASIZE:0] ep1_txlen;
assign usb_txlen[1]  = (ep1_txlen >= i_ep1_tx_max) ? i_ep1_tx_max : ep1_txlen[11:0];
assign usb_txcork[1] = ep1_txcork;
assign usb_txdat[1]  = ep1_txdat;
`else
assign usb_txlen[1]  = 12'd0;
assign usb_txcork[1] = 1'b1;
assign usb_txdat[1]  = 8'd0;
`endif
`ifdef EP2_IN_EN
wire [ 7:0] ep2_txdat;
wire        ep2_txcork;
wire [`EP2_IN_BUF_ASIZE:0] ep2_txlen;
assign usb_txlen[2]  = (ep2_txlen >= i_ep2_tx_max) ? i_ep2_tx_max : ep2_txlen[11:0];
assign usb_txcork[2]  = ep2_txcork;
assign usb_txdat[2]   = ep2_txdat;
`else
assign usb_txlen[2]   = 12'd0;
assign usb_txcork[2]  = 1'b1;
assign usb_txdat[2]   = 8'd0;
`endif
`ifdef EP3_IN_EN
wire [ 7:0] ep3_txdat;
wire        ep3_txcork;
wire [`EP3_IN_BUF_ASIZE:0] ep3_txlen;
assign usb_txlen[3]  = (ep3_txlen >= i_ep3_tx_max) ? i_ep3_tx_max : ep3_txlen[11:0];
assign usb_txcork[3]  = ep3_txcork;
assign usb_txdat[3]   = ep3_txdat;
`else
assign usb_txlen[3]   = 12'd0;
assign usb_txcork[3]  = 1'b1;
assign usb_txdat[3]   = 8'd0;
`endif
`ifdef EP4_IN_EN
wire [ 7:0] ep4_txdat;
wire        ep4_txcork;
wire [`EP4_IN_BUF_ASIZE:0] ep4_txlen;
assign usb_txlen[4]  = (ep4_txlen >= i_ep4_tx_max) ? i_ep4_tx_max : ep4_txlen[11:0];
assign usb_txcork[4]  = ep4_txcork;
assign usb_txdat[4]   = ep4_txdat;
`else
assign usb_txlen[4]   = 12'd0;
assign usb_txcork[4]  = 1'b1;
assign usb_txdat[4]   = 8'd0;
`endif
`ifdef EP5_IN_EN
wire [ 7:0] ep5_txdat;
wire        ep5_txcork;
wire [`EP5_IN_BUF_ASIZE:0] ep5_txlen;
assign usb_txlen[5]  = (ep5_txlen >= i_ep5_tx_max) ? i_ep5_tx_max : ep5_txlen[11:0];
assign usb_txcork[5]  = ep5_txcork;
assign usb_txdat[5]   = ep5_txdat;
`else
assign usb_txlen[5]   = 12'd0;
assign usb_txcork[5]  = 1'b1;
assign usb_txdat[5]   = 8'd0;
`endif
`ifdef EP6_IN_EN
wire [ 7:0] ep6_txdat;
wire        ep6_txcork;
wire [`EP6_IN_BUF_ASIZE:0] ep6_txlen;
assign usb_txlen[6]  = (ep6_txlen >= i_ep6_tx_max) ? i_ep6_tx_max : ep6_txlen[11:0];
assign usb_txcork[6]  = ep6_txcork;
assign usb_txdat[6]   = ep6_txdat;
`else
assign usb_txlen[6]   = 12'd0;
assign usb_txcork[6]  = 1'b1;
assign usb_txdat[6]   = 8'd0;
`endif
`ifdef EP7_IN_EN
wire [ 7:0] ep7_txdat;
wire        ep7_txcork;
wire [`EP7_IN_BUF_ASIZE:0] ep7_txlen;
assign usb_txlen[7]  = (ep7_txlen >= i_ep7_tx_max) ? i_ep7_tx_max : ep7_txlen[11:0];
assign usb_txcork[7]  = ep7_txcork;
assign usb_txdat[7]   = ep7_txdat;
`else
assign usb_txlen[7]   = 12'd0;
assign usb_txcork[7]  = 1'b1;
assign usb_txdat[7]   = 8'd0;
`endif
`ifdef EP8_IN_EN
wire [ 7:0] ep8_txdat;
wire        ep8_txcork;
wire [`EP8_IN_BUF_ASIZE:0] ep8_txlen;
assign usb_txlen[8]  = (ep8_txlen >= i_ep8_tx_max) ? i_ep8_tx_max : ep8_txlen[11:0];
assign usb_txcork[8]  = ep8_txcork;
assign usb_txdat[8]   = ep8_txdat;
`else
assign usb_txlen[8]   = 12'd0;
assign usb_txcork[8]  = 1'b1;
assign usb_txdat[8]   = 8'd0;
`endif
`ifdef EP9_IN_EN
wire [ 7:0] ep9_txdat;
wire        ep9_txcork;
wire [`EP9_IN_BUF_ASIZE:0] ep9_txlen;
assign usb_txlen[9]  = (ep9_txlen >= i_ep9_tx_max) ? i_ep9_tx_max : ep9_txlen[11:0];
assign usb_txcork[9]  = ep9_txcork;
assign usb_txdat[9]   = ep9_txdat;
`else
assign usb_txlen[9]   = 12'd0;
assign usb_txcork[9]  = 1'b1;
assign usb_txdat[9]   = 8'd0;
`endif
`ifdef EP10_IN_EN
wire [ 7:0] ep10_txdat;
wire        ep10_txcork;
wire [`EP10_IN_BUF_ASIZE:0] ep10_txlen;
assign usb_txlen[10]  = (ep10_txlen >= i_ep10_tx_max) ? i_ep10_tx_max : ep10_txlen[11:0];
assign usb_txcork[10] = ep10_txcork;
assign usb_txdat[10]  = ep10_txdat;
`else
assign usb_txlen[10]  = 12'd0;
assign usb_txcork[10] = 1'b1;
assign usb_txdat[10]  = 8'd0;
`endif
`ifdef EP11_IN_EN
wire [ 7:0] ep11_txdat;
wire        ep11_txcork;
wire [`EP11_IN_BUF_ASIZE:0] ep11_txlen;
assign usb_txlen[11]  = (ep11_txlen >= i_ep11_tx_max) ? i_ep11_tx_max : ep11_txlen[11:0];
assign usb_txcork[11] = ep11_txcork;
assign usb_txdat[11]  = ep11_txdat;
`else
assign usb_txlen[11]  = 12'd0;
assign usb_txcork[11] = 1'b1;
assign usb_txdat[11]  = 8'd0;
`endif
`ifdef EP12_IN_EN
wire [ 7:0] ep12_txdat;
wire        ep12_txcork;
wire [`EP12_IN_BUF_ASIZE:0] ep12_txlen;
assign usb_txlen[12]  = (ep12_txlen >= i_ep12_tx_max) ? i_ep12_tx_max : ep12_txlen[11:0];
assign usb_txcork[12] = ep12_txcork;
assign usb_txdat[12]  = ep12_txdat;
`else
assign usb_txlen[12]  = 12'd0;
assign usb_txcork[12] = 1'b1;
assign usb_txdat[12]  = 8'd0;
`endif
`ifdef EP13_IN_EN
wire [ 7:0] ep13_txdat;
wire        ep13_txcork;
wire [`EP13_IN_BUF_ASIZE:0] ep13_txlen;
assign usb_txlen[13]  = (ep13_txlen >= i_ep13_tx_max) ? i_ep13_tx_max : ep13_txlen[11:0];
assign usb_txcork[13] = ep13_txcork;
assign usb_txdat[13]  = ep13_txdat;
`else
assign usb_txlen[13]  = 12'd0;
assign usb_txcork[13] = 1'b1;
assign usb_txdat[13]  = 8'd0;
`endif
`ifdef EP14_IN_EN
wire [ 7:0] ep14_txdat;
wire        ep14_txcork;
wire [`EP14_IN_BUF_ASIZE:0] ep14_txlen;
assign usb_txlen[14]  = (ep14_txlen >= i_ep14_tx_max) ? i_ep14_tx_max : ep14_txlen[11:0];
assign usb_txcork[14] = ep14_txcork;
assign usb_txdat[14]  = ep14_txdat;
`else
assign usb_txlen[14]  = 12'd0;
assign usb_txcork[14] = 1'b1;
assign usb_txdat[14]  = 8'd0;
`endif
`ifdef EP15_IN_EN
wire [ 7:0] ep15_txdat;
wire        ep15_txcork;
wire [`EP15_IN_BUF_ASIZE:0] ep15_txlen;
assign usb_txlen[15]  = (ep15_txlen >= i_ep15_tx_max) ? i_ep15_tx_max : ep15_txlen[11:0];
assign usb_txcork[15] = ep15_txcork;
assign usb_txdat[15]  = ep15_txdat;
`else
assign usb_txlen[15]  = 12'd0;
assign usb_txcork[15] = 1'b1;
assign usb_txdat[15]  = 8'd0;
`endif
`ifdef EP1_OUT_EN
wire ep1_rx_rdy;
assign usb_rxrdy[1]   = ep1_rx_rdy;
`else
assign usb_rxrdy[1]   = 1'b1;
`endif
`ifdef EP2_OUT_EN
wire ep2_rx_rdy;
assign usb_rxrdy[2]   = ep2_rx_rdy;
`else
assign usb_rxrdy[2]   = 1'b1;
`endif
`ifdef EP3_OUT_EN
wire ep3_rx_rdy;
assign usb_rxrdy[3]   = ep3_rx_rdy;
`else
assign usb_rxrdy[3]   = 1'b0;
`endif
`ifdef EP4_OUT_EN
wire ep4_rx_rdy;
assign usb_rxrdy[4]   = ep4_rx_rdy;
`else
assign usb_rxrdy[4]   = 1'b0;
`endif
`ifdef EP5_OUT_EN
wire ep5_rx_rdy;
assign usb_rxrdy[5]   = ep5_rx_rdy;
`else
assign usb_rxrdy[5]   = 1'b0;
`endif
`ifdef EP6_OUT_EN
wire ep6_rx_rdy;
assign usb_rxrdy[6]   = ep6_rx_rdy;
`else
assign usb_rxrdy[6]   = 1'b0;
`endif
`ifdef EP7_OUT_EN
wire ep7_rx_rdy;
assign usb_rxrdy[7]   = ep7_rx_rdy;
`else
assign usb_rxrdy[7]   = 1'b0;
`endif
`ifdef EP8_OUT_EN
wire ep8_rx_rdy;
assign usb_rxrdy[8]   = ep8_rx_rdy;
`else
assign usb_rxrdy[8]   = 1'b0;
`endif
`ifdef EP9_OUT_EN
wire ep9_rx_rdy;
assign usb_rxrdy[9]   = ep9_rx_rdy;
`else
assign usb_rxrdy[9]  = 1'b0;
`endif
`ifdef EP10_OUT_EN
wire ep10_rx_rdy;
assign usb_rxrdy[10]  = ep10_rx_rdy;
`else
assign usb_rxrdy[10]  = 1'b0;
`endif
`ifdef EP11_OUT_EN
wire ep11_rx_rdy;
assign usb_rxrdy[11]  = ep11_rx_rdy;
`else
assign usb_rxrdy[11]  = 1'b0;
`endif
`ifdef EP12_OUT_EN
wire ep12_rx_rdy;
assign usb_rxrdy[12]  = ep12_rx_rdy;
`else
assign usb_rxrdy[12]  = 1'b0;
`endif
`ifdef EP13_OUT_EN
wire ep13_rx_rdy;
assign usb_rxrdy[13]  = ep13_rx_rdy;
`else
assign usb_rxrdy[13]  = 1'b0;
`endif
`ifdef EP14_OUT_EN
wire ep14_rx_rdy;
assign usb_rxrdy[14]  = ep14_rx_rdy;
`else
assign usb_rxrdy[14]  = 1'b0;
`endif
`ifdef EP15_OUT_EN
wire ep15_rx_rdy;
assign usb_rxrdy[15]  = ep15_rx_rdy;
`else
assign usb_rxrdy[15]  = 1'b0;
`endif
always @(posedge i_clk or posedge i_reset) begin
    if (i_reset) begin
        s_endpt_sel <= 4'd0;
    end
    else begin
        s_endpt_sel <= i_usb_endpt;
    end
end

always @(posedge i_clk or posedge i_reset) begin
    if (i_reset) begin
        s_usb_txcork <= 1'b0;
        s_usb_rxrdy  <= 1'b0;
        s_usb_txlen  <= 12'd32;
    end
    else begin
        if (i_usb_endpt == 4'd0) begin
            s_usb_txcork <= 1'b0;
            s_usb_rxrdy  <= 1'b1;
            s_usb_txlen  <= 12'd0;
        end
        else begin
            s_usb_txcork <= usb_txcork[i_usb_endpt];
            s_usb_rxrdy  <= usb_rxrdy[i_usb_endpt];
            if (!i_usb_txact) begin
                s_usb_txlen <= usb_txlen[i_usb_endpt];
            end
        end
    end
end



`ifdef EP1_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (1               )
        ,.P_DSIZE    (8               )
        ,.P_ASIZE    (`EP1_IN_BUF_ASIZE)
    )usb_tx_buf_ep1
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_txact   (i_usb_txact   )//
        ,.i_usb_txpop   (i_usb_txpop   )//
        ,.i_usb_txpktfin(i_usb_txpktfin)//
        ,.o_usb_txdat   (ep1_txdat     )//
        ,.o_usb_txcork  (ep1_txcork    )//
        ,.o_usb_txlen   (ep1_txlen     )//
        ,.i_ep_clk      (i_ep1_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep1_tx_dval )//
        ,.i_ep_tx_data  (i_ep1_tx_data )//
    );
`endif
`ifdef EP1_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (1  )
        ,.P_AFULL    (`EP1_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP1_OUT_BUF_ASIZE)
    )usb_rx_buf_ep1
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep1_rx_rdy    )//
        ,.i_ep_clk      (i_ep1_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep1_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep1_rx_dval )//
        ,.o_ep_rx_data  (o_ep1_rx_data )//
    );
`endif
`ifdef EP2_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (2  )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP2_IN_BUF_ASIZE)
    )usb_tx_buf_ep2
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_txact   (i_usb_txact   )//
        ,.i_usb_txpop   (i_usb_txpop   )//
        ,.i_usb_txpktfin(i_usb_txpktfin)//
        ,.o_usb_txdat   (ep2_txdat     )//
        ,.o_usb_txcork  (ep2_txcork    )//
        ,.o_usb_txlen   (ep2_txlen     )//
        ,.i_ep_clk      (i_ep2_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep2_tx_dval )//
        ,.i_ep_tx_data  (i_ep2_tx_data )//
    );
`endif
`ifdef EP2_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (2  )
        ,.P_AFULL    (`EP2_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP2_OUT_BUF_ASIZE)
    )usb_rx_buf_ep2
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep2_rx_rdy    )//
        ,.i_ep_clk      (i_ep2_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep2_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep2_rx_dval )//
        ,.o_ep_rx_data  (o_ep2_rx_data )//
    );
`endif

`ifdef EP3_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (3  )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP3_IN_BUF_ASIZE)
    )usb_tx_buf_ep3
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_txact   (i_usb_txact   )//
        ,.i_usb_txpop   (i_usb_txpop   )//
        ,.i_usb_txpktfin(i_usb_txpktfin)//
        ,.o_usb_txdat   (ep3_txdat     )//
        ,.o_usb_txcork  (ep3_txcork    )//
        ,.o_usb_txlen   (ep3_txlen     )//
        ,.i_ep_clk      (i_ep3_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep3_tx_dval )//
        ,.i_ep_tx_data  (i_ep3_tx_data )//
    );
`endif
`ifdef EP3_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (3  )
        ,.P_AFULL    (`EP3_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP3_OUT_BUF_ASIZE)
    )usb_rx_buf_ep3
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep3_rx_rdy    )//
        ,.i_ep_clk      (i_ep3_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep3_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep3_rx_dval )//
        ,.o_ep_rx_data  (o_ep3_rx_data )//
    );
`endif

`ifdef EP4_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (4  )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP4_IN_BUF_ASIZE)
    )usb_tx_buf_ep4
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_txact   (i_usb_txact   )//
        ,.i_usb_txpop   (i_usb_txpop   )//
        ,.i_usb_txpktfin(i_usb_txpktfin)//
        ,.o_usb_txdat   (ep4_txdat     )//
        ,.o_usb_txcork  (ep4_txcork    )//
        ,.o_usb_txlen   (ep4_txlen     )//
        ,.i_ep_clk      (i_ep4_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep4_tx_dval )//
        ,.i_ep_tx_data  (i_ep4_tx_data )//
    );
`endif
`ifdef EP4_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (4  )
        ,.P_AFULL    (`EP4_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP4_OUT_BUF_ASIZE)
    )usb_rx_buf_ep4
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep4_rx_rdy    )//
        ,.i_ep_clk      (i_ep4_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep4_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep4_rx_dval )//
        ,.o_ep_rx_data  (o_ep4_rx_data )//
    );
`endif

`ifdef EP5_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (5  )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP5_IN_BUF_ASIZE)
    )usb_tx_buf_ep5
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_txact   (i_usb_txact   )//
        ,.i_usb_txpop   (i_usb_txpop   )//
        ,.i_usb_txpktfin(i_usb_txpktfin)//
        ,.o_usb_txdat   (ep5_txdat     )//
        ,.o_usb_txcork  (ep5_txcork    )//
        ,.o_usb_txlen   (ep5_txlen     )//
        ,.i_ep_clk      (i_ep5_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep5_tx_dval )//
        ,.i_ep_tx_data  (i_ep5_tx_data )//
    );
`endif
`ifdef EP5_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (5  )
        ,.P_AFULL    (`EP5_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP5_OUT_BUF_ASIZE)
    )usb_rx_buf_ep5
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep5_rx_rdy    )//
        ,.i_ep_clk      (i_ep5_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep5_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep5_rx_dval )//
        ,.o_ep_rx_data  (o_ep5_rx_data )//
    );
`endif
`ifdef EP6_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (6  )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP6_IN_BUF_ASIZE)
    )usb_tx_buf_ep6
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_txact   (i_usb_txact   )//
        ,.i_usb_txpop   (i_usb_txpop   )//
        ,.i_usb_txpktfin(i_usb_txpktfin)//
        ,.o_usb_txdat   (ep6_txdat     )//
        ,.o_usb_txcork  (ep6_txcork    )//
        ,.o_usb_txlen   (ep6_txlen     )//
        ,.i_ep_clk      (i_ep6_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep6_tx_dval )//
        ,.i_ep_tx_data  (i_ep6_tx_data )//
    );
`endif
`ifdef EP6_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (6  )
        ,.P_AFULL    (`EP6_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP6_OUT_BUF_ASIZE)
    )usb_rx_buf_ep6
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep6_rx_rdy    )//
        ,.i_ep_clk      (i_ep6_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep6_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep6_rx_dval )//
        ,.o_ep_rx_data  (o_ep6_rx_data )//
    );
`endif
`ifdef EP7_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (7  )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP7_IN_BUF_ASIZE)
    )usb_tx_buf_ep7
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_txact   (i_usb_txact   )//
        ,.i_usb_txpop   (i_usb_txpop   )//
        ,.i_usb_txpktfin(i_usb_txpktfin)//
        ,.o_usb_txdat   (ep7_txdat     )//
        ,.o_usb_txcork  (ep7_txcork    )//
        ,.o_usb_txlen   (ep7_txlen     )//
        ,.i_ep_clk      (i_ep7_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep7_tx_dval )//
        ,.i_ep_tx_data  (i_ep7_tx_data )//
    );
`endif
`ifdef EP7_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (7  )
        ,.P_AFULL    (`EP7_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP7_OUT_BUF_ASIZE)
    )usb_rx_buf_ep7
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep7_rx_rdy    )//
        ,.i_ep_clk      (i_ep7_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep7_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep7_rx_dval )//
        ,.o_ep_rx_data  (o_ep7_rx_data )//
    );
`endif
`ifdef EP8_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (8  )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP8_IN_BUF_ASIZE)
    )usb_tx_buf_ep8
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_txact   (i_usb_txact   )//
        ,.i_usb_txpop   (i_usb_txpop   )//
        ,.i_usb_txpktfin(i_usb_txpktfin)//
        ,.o_usb_txdat   (ep8_txdat     )//
        ,.o_usb_txcork  (ep8_txcork    )//
        ,.o_usb_txlen   (ep8_txlen     )//
        ,.i_ep_clk      (i_ep8_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep8_tx_dval )//
        ,.i_ep_tx_data  (i_ep8_tx_data )//
    );
`endif
`ifdef EP8_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (8  )
        ,.P_AFULL    (`EP8_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP8_OUT_BUF_ASIZE)
    )usb_rx_buf_ep8
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep8_rx_rdy    )//
        ,.i_ep_clk      (i_ep8_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep8_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep8_rx_dval )//
        ,.o_ep_rx_data  (o_ep8_rx_data )//
    );
`endif
`ifdef EP9_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (9  )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP9_IN_BUF_ASIZE)
    )usb_tx_buf_ep9
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_txact   (i_usb_txact   )//
        ,.i_usb_txpop   (i_usb_txpop   )//
        ,.i_usb_txpktfin(i_usb_txpktfin)//
        ,.o_usb_txdat   (ep9_txdat     )//
        ,.o_usb_txcork  (ep9_txcork    )//
        ,.o_usb_txlen   (ep9_txlen     )//
        ,.i_ep_clk      (i_ep9_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep9_tx_dval )//
        ,.i_ep_tx_data  (i_ep9_tx_data )//
    );
`endif
`ifdef EP9_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (9  )
        ,.P_AFULL    (`EP9_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP9_OUT_BUF_ASIZE)
    )usb_rx_buf_ep9
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep9_rx_rdy    )//
        ,.i_ep_clk      (i_ep9_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep9_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep9_rx_dval )//
        ,.o_ep_rx_data  (o_ep9_rx_data )//
    );
`endif
`ifdef EP10_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (10 )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP10_IN_BUF_ASIZE)
    )usb_tx_buf_ep10
    (
         .i_clk         (i_clk          )//clock
        ,.i_reset       (i_reset        )//reset
        ,.i_usb_endpt   (s_endpt_sel    )//
        ,.i_usb_txact   (i_usb_txact    )//
        ,.i_usb_txpop   (i_usb_txpop    )//
        ,.i_usb_txpktfin(i_usb_txpktfin )//
        ,.o_usb_txdat   (ep10_txdat     )//
        ,.o_usb_txcork  (ep10_txcork    )//
        ,.o_usb_txlen   (ep10_txlen     )//
        ,.i_ep_clk      (i_ep10_tx_clk  )//
        ,.i_ep_tx_dval  (_ep10_tx_dval  )//
        ,.i_ep_tx_data  (_ep10_tx_data  )//
    );
`endif
`ifdef EP10_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (10  )
        ,.P_AFULL    (`EP10_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP10_OUT_BUF_ASIZE)
    )usb_rx_buf_ep10
    (
         .i_clk         (i_clk          )//clock
        ,.i_reset       (i_reset        )//reset
        ,.i_usb_endpt   (s_endpt_sel    )//
        ,.i_usb_rxact   (i_usb_rxact    )//
        ,.i_usb_rxval   (i_usb_rxval    )//
        ,.i_usb_rxpktval(i_usb_rxpktval )//
        ,.i_usb_rxdat   (i_usb_rxdat    )//
        ,.o_usb_rxrdy   (ep10_rx_rdy    )//
        ,.i_ep_clk      (i_ep10_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep10_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep10_rx_dval )//
        ,.o_ep_rx_data  (o_ep10_rx_data )//
    );
`endif
`ifdef EP11_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (11 )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP11_IN_BUF_ASIZE)
    )usb_tx_buf_ep11
    (
         .i_clk         (i_clk          )//clock
        ,.i_reset       (i_reset        )//reset
        ,.i_usb_endpt   (s_endpt_sel    )//
        ,.i_usb_txact   (i_usb_txact    )//
        ,.i_usb_txpop   (i_usb_txpop    )//
        ,.i_usb_txpktfin(i_usb_txpktfin )//
        ,.o_usb_txdat   (ep11_txdat     )//
        ,.o_usb_txcork  (ep11_txcork    )//
        ,.o_usb_txlen   (ep11_txlen     )//
        ,.i_ep_clk      (i_ep11_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep11_tx_dval )//
        ,.i_ep_tx_data  (i_ep11_tx_data )//
    );
`endif
`ifdef EP11_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (11 )
        ,.P_AFULL    (`EP11_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP11_OUT_BUF_ASIZE)
    )usb_rx_buf_ep11
    (
         .i_clk         (i_clk          )//clock
        ,.i_reset       (i_reset        )//reset
        ,.i_usb_endpt   (s_endpt_sel    )//
        ,.i_usb_rxact   (i_usb_rxact    )//
        ,.i_usb_rxval   (i_usb_rxval    )//
        ,.i_usb_rxpktval(i_usb_rxpktval )//
        ,.i_usb_rxdat   (i_usb_rxdat    )//
        ,.o_usb_rxrdy   (ep11_rx_rdy    )//
        ,.i_ep_clk      (i_ep11_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep11_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep11_rx_dval )//
        ,.o_ep_rx_data  (o_ep11_rx_data )//
    );
`endif
`ifdef EP12_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (12 )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (10 )
        ,.P_ASIZE    (`EP12_IN_BUF_ASIZE)
    )usb_tx_buf_ep12
    (
         .i_clk         (i_clk          )//clock
        ,.i_reset       (i_reset        )//reset
        ,.i_usb_endpt   (s_endpt_sel    )//
        ,.i_usb_txact   (i_usb_txact    )//
        ,.i_usb_txpop   (i_usb_txpop    )//
        ,.i_usb_txpktfin(i_usb_txpktfin )//
        ,.o_usb_txdat   (ep12_txdat     )//
        ,.o_usb_txcork  (ep12_txcork    )//
        ,.o_usb_txlen   (ep12_txlen     )//
        ,.i_ep_clk      (i_ep12_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep12_tx_dval )//
        ,.i_ep_tx_data  (i_ep12_tx_data )//
    );
`endif
`ifdef EP12_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (12 )
        ,.P_AFULL    (`EP12_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP12_OUT_BUF_ASIZE)
    )usb_rx_buf_ep12
    (
         .i_clk         (i_clk          )//clock
        ,.i_reset       (i_reset        )//reset
        ,.i_usb_endpt   (s_endpt_sel    )//
        ,.i_usb_rxact   (i_usb_rxact    )//
        ,.i_usb_rxval   (i_usb_rxval    )//
        ,.i_usb_rxpktval(i_usb_rxpktval )//
        ,.i_usb_rxdat   (i_usb_rxdat    )//
        ,.o_usb_rxrdy   (ep12_rx_rdy    )//
        ,.i_ep_clk      (i_ep12_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep12_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep12_rx_dval )//
        ,.o_ep_rx_data  (o_ep12_rx_data )//
    );
`endif
`ifdef EP13_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (13 )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP13_IN_BUF_ASIZE)
    )usb_tx_buf_ep13
    (
         .i_clk         (i_clk          )//clock
        ,.i_reset       (i_reset        )//reset
        ,.i_usb_endpt   (s_endpt_sel    )//
        ,.i_usb_txact   (i_usb_txact    )//
        ,.i_usb_txpop   (i_usb_txpop    )//
        ,.i_usb_txpktfin(i_usb_txpktfin )//
        ,.o_usb_txdat   (ep13_txdat     )//
        ,.o_usb_txcork  (ep13_txcork    )//
        ,.o_usb_txlen   (ep13_txlen     )//
        ,.i_ep_clk      (i_ep13_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep13_tx_dval )//
        ,.i_ep_tx_data  (i_ep13_tx_data )//
    );
`endif
`ifdef EP13_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (13 )
        ,.P_AFULL    (`EP13_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP13_OUT_BUF_ASIZE)
    )usb_rx_buf_ep13
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep13_rx_rdy    )//
        ,.i_ep_clk      (i_ep13_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep13_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep13_rx_dval )//
        ,.o_ep_rx_data  (o_ep13_rx_data )//
    );
`endif
`ifdef EP14_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (14 )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP14_IN_BUF_ASIZE)
    )usb_tx_buf_ep14
    (
         .i_clk         (i_clk          )//clock
        ,.i_reset       (i_reset        )//reset
        ,.i_usb_endpt   (s_endpt_sel    )//
        ,.i_usb_txact   (i_usb_txact    )//
        ,.i_usb_txpop   (i_usb_txpop    )//
        ,.i_usb_txpktfin(i_usb_txpktfin )//
        ,.o_usb_txdat   (ep14_txdat     )//
        ,.o_usb_txcork  (ep14_txcork    )//
        ,.o_usb_txlen   (ep14_txlen     )//
        ,.i_ep_clk      (i_ep14_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep14_tx_dval )//
        ,.i_ep_tx_data  (i_ep14_tx_data )//
    );
`endif
`ifdef EP14_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (14 )
        ,.P_AFULL    (EP14_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (EP14_OUT_BUF_ASIZE)
    )usb_rx_buf_ep14
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep14_rx_rdy    )//
        ,.i_ep_clk      (i_ep14_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep14_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep14_rx_dval )//
        ,.o_ep_rx_data  (o_ep14_rx_data )//
    );
`endif
`ifdef EP15_IN_EN
    usb_tx_buf #(
         .P_ENDPOINT (15 )
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (`EP15_IN_BUF_ASIZE)
    )usb_tx_buf_ep15
    (
         .i_clk         (i_clk          )//clock
        ,.i_reset       (i_reset        )//reset
        ,.i_usb_endpt   (s_endpt_sel    )//
        ,.i_usb_txact   (i_usb_txact    )//
        ,.i_usb_txpop   (i_usb_txpop    )//
        ,.i_usb_txpktfin(i_usb_txpktfin )//
        ,.o_usb_txdat   (ep15_txdat     )//
        ,.o_usb_txcork  (ep15_txcork    )//
        ,.o_usb_txlen   (ep15_txlen     )//
        ,.i_ep_clk      (i_ep15_tx_clk  )//
        ,.i_ep_tx_dval  (i_ep15_tx_dval )//
        ,.i_ep_tx_data  (i_ep15_tx_data )//
    );
`endif
`ifdef EP15_OUT_EN
    usb_rx_buf #(
         .P_ENDPOINT (15 )
        ,.P_AFULL    (EP15_OUT_BUF_AFULL)
        ,.P_DSIZE    (8  )
        ,.P_ASIZE    (EP15_OUT_BUF_ASIZE)
    )usb_rx_buf_ep15
    (
         .i_clk         (i_clk         )//clock
        ,.i_reset       (i_reset       )//reset
        ,.i_usb_endpt   (s_endpt_sel   )//
        ,.i_usb_rxact   (i_usb_rxact   )//
        ,.i_usb_rxval   (i_usb_rxval   )//
        ,.i_usb_rxpktval(i_usb_rxpktval)//
        ,.i_usb_rxdat   (i_usb_rxdat   )//
        ,.o_usb_rxrdy   (ep15_rx_rdy    )//
        ,.i_ep_clk      (i_ep15_rx_clk  )//
        ,.i_ep_rx_rdy   (i_ep15_rx_rdy  )//
        ,.o_ep_rx_dval  (o_ep15_rx_dval )//
        ,.o_ep_rx_data  (o_ep15_rx_data )//
    );
`endif


assign o_usb_txcork = s_usb_txcork;
assign o_usb_rxrdy  = s_usb_rxrdy ;
assign o_usb_txlen  = s_usb_txlen ;
assign o_usb_txdat  = usb_txdat[i_usb_endpt];

endmodule



module usb_tx_buf #(
    parameter P_ENDPOINT = 1,
    parameter P_DSIZE    = 8,
    parameter P_ASIZE    = 9
)
(
    input                      i_clk         ,//clock
    input                      i_reset       ,//reset
    input      [3:0]           i_usb_endpt   ,//
    input                      i_usb_txact   ,//
    input                      i_usb_txpop   ,//
    input                      i_usb_txpktfin,//
    output     [P_DSIZE-1:0]   o_usb_txdat   ,//
    output                     o_usb_txcork  ,//
    output     [P_ASIZE:0]     o_usb_txlen   ,//
    input                      i_ep_clk      ,//
    input                      i_ep_tx_dval  ,//
    input      [P_DSIZE-1:0]   i_ep_tx_data   //
);
//==============================================================
//======cross fifo
    wire               pkt_fifo_wr;
    wire               pkt_fifo_wr_act;
    wire               pkt_fifo_wr_pktval;
    wire [P_DSIZE-1:0] pkt_fifo_wr_data;
    wire               pkt_fifo_rd;
    reg                pkt_fifo_rd_dval;
    wire [P_DSIZE-1:0] pkt_fifo_rd_data;
    wire [P_ASIZE  :0] pkt_fifo_wr_num;
    reg  [P_ASIZE  :0] pkt_fifo_wr_num_d0;
    wire               pkt_fifo_empty;
    wire               c_fifo_wr;
    wire [P_DSIZE-1:0] c_fifo_wr_data;
    reg                c_fifo_rd;
    reg                c_fifo_rd_dval;
    wire [P_DSIZE-1:0] c_fifo_rd_data;
    assign c_fifo_wr      = i_ep_tx_dval;
    assign c_fifo_wr_data = i_ep_tx_data;
    clk_cross_fifo #(
       .DSIZE (8  )
      ,.ASIZE (6  )
      ,.AEMPT (1  )
      ,.AFULL (32 )
    )clk_cross_fifo
    (
         .WrClock    (i_ep_clk      )
        ,.Reset      (i_reset       )
        ,.WrEn       (c_fifo_wr     )
        ,.Data       (c_fifo_wr_data)
        ,.AlmostFull (              )
        ,.Full       ()
        ,.RdClock    (i_clk         )
        ,.RPReset    (i_reset       )
        ,.RdEn       (c_fifo_rd     )
        ,.Q          (c_fifo_rd_data)
        ,.AlmostEmpty()
        ,.Empty      (c_fifo_empty  )
    );



    always@(posedge i_clk, posedge i_reset) begin
        if (i_reset) begin
            c_fifo_rd <= 1'b0;
        end
        else begin
            if (c_fifo_empty) begin
                c_fifo_rd <= 1'b0;
            end
            else begin
                c_fifo_rd <= 1'b1;
            end
        end
    end
    always@(posedge i_clk, posedge i_reset) begin
        if (i_reset) begin
            c_fifo_rd_dval <= 1'b0;
        end
        else begin
            c_fifo_rd_dval <= c_fifo_rd & (!c_fifo_empty);
        end
    end

//==============================================================
//======usb packet crc check fifo
assign pkt_fifo_wr        = c_fifo_rd_dval;
assign pkt_fifo_wr_data   = c_fifo_rd_data;
assign pkt_fifo_rd_pktfin = i_usb_txpktfin&(i_usb_endpt==P_ENDPOINT);
assign pkt_fifo_rd_act    = i_usb_txact&(i_usb_endpt==P_ENDPOINT);
assign pkt_fifo_rd        = i_usb_txpop&(i_usb_endpt==P_ENDPOINT);
assign o_usb_txdat        = pkt_fifo_rd_data;
assign o_usb_txcork       = pkt_fifo_empty;
assign o_usb_txlen        = pkt_fifo_wr_num_d0;

    always@(posedge i_clk, posedge i_reset) begin
        if (i_reset) begin
            pkt_fifo_wr_num_d0 <= 1'b0;
        end
        else begin
            pkt_fifo_wr_num_d0 <= pkt_fifo_wr_num;
        end
    end

    sync_tx_pkt_fifo #(
         .DSIZE (P_DSIZE)
        ,.ASIZE (P_ASIZE)
    )sync_tx_pkt_fifo
    (
         .CLK   (i_clk              )
        ,.RSTn  (!i_reset           )
        ,.write (pkt_fifo_wr        )
        ,.iData (pkt_fifo_wr_data   )
        ,.pktfin(pkt_fifo_rd_pktfin )
        ,.txact (pkt_fifo_rd_act    )
        ,.read  (pkt_fifo_rd        )
        ,.oData (pkt_fifo_rd_data   )
        ,.wrnum (pkt_fifo_wr_num    )
        ,.full  (                   )
        ,.empty (pkt_fifo_empty     )
    );
endmodule


module usb_rx_buf #(
    parameter P_ENDPOINT = 1,
    parameter P_AFULL    = 400,
    parameter P_DSIZE    = 8,
    parameter P_ASIZE    = 9
)
(
    input                  i_clk         ,//clock
    input                  i_reset       ,//reset
    input  [3:0]           i_usb_endpt   ,//
    input                  i_usb_rxact   ,//
    input                  i_usb_rxpktval,//
    input                  i_usb_rxval   ,//
    input  [P_DSIZE-1:0]   i_usb_rxdat   ,//
    output                 o_usb_rxrdy   ,//
    input                  i_ep_clk      ,//
    input                  i_ep_rx_rdy   ,//
    output                 o_ep_rx_dval  ,//
    output [P_DSIZE-1:0]   o_ep_rx_data   //
);
    reg                pkt_fifo_wr;
    reg                pkt_fifo_wr_act;
    reg                pkt_fifo_wr_pktval;
    reg  [P_DSIZE-1:0] pkt_fifo_wr_data;
    reg                pkt_fifo_rd;
    reg                pkt_fifo_rd_dval;
    wire [P_DSIZE-1:0] pkt_fifo_rd_data;
    wire [P_ASIZE  :0] pkt_fifo_wr_num;
    wire               c_fifo_wr;
    wire [P_DSIZE-1:0] c_fifo_wr_data;
    wire               c_fifo_afull;
    reg                c_fifo_rd;
    reg                c_fifo_dval;
    wire [P_DSIZE-1:0] c_fifo_rd_data;

//==============================================================
//======usb rx
    always @(posedge i_clk or posedge i_reset) begin
        if (i_reset) begin
            pkt_fifo_wr <= 1'b0;
            pkt_fifo_wr_act <= 1'b0;
            pkt_fifo_wr_pktval <= 1'b0;
            pkt_fifo_wr_data <= 'd0;
        end
        else begin
            pkt_fifo_wr <= i_usb_rxval&(i_usb_endpt==P_ENDPOINT);
            pkt_fifo_wr_act <= i_usb_rxact&(i_usb_endpt==P_ENDPOINT);
            pkt_fifo_wr_pktval <= i_usb_rxpktval&(i_usb_endpt==P_ENDPOINT);
            pkt_fifo_wr_data <= i_usb_rxdat;
        end
    end
//==============================================================
//======usb packet crc check fifo
    sync_rx_pkt_fifo  #(
         .DSIZE (P_DSIZE )
        ,.ASIZE (P_ASIZE )
    )sync_rx_pkt_fifo
    (
         .CLK   (i_clk               )
        ,.RSTn  (!i_reset            )
        ,.write (pkt_fifo_wr         )
        ,.iData (pkt_fifo_wr_data    )
        ,.pktval(pkt_fifo_wr_pktval  )
        ,.rxact (pkt_fifo_wr_act     )
        ,.read  (pkt_fifo_rd         )
        ,.oData (pkt_fifo_rd_data    )
        ,.wrnum (pkt_fifo_wr_num     )
        ,.full  (                    )
        ,.empty (pkt_fifo_empty      )
    );
    always@(posedge i_clk, posedge i_reset) begin
        if (i_reset) begin
            pkt_fifo_rd <= 1'b0;
        end
        else begin
            if (pkt_fifo_empty||(c_fifo_afull)) begin
                pkt_fifo_rd <= 1'b0;
            end
            else begin
                pkt_fifo_rd <= 1'b1;
            end
        end
    end
    always@(posedge i_clk, posedge i_reset) begin
        if (i_reset) begin
            pkt_fifo_rd_dval <= 1'b0;
        end
        else begin
            pkt_fifo_rd_dval <= pkt_fifo_rd & (!pkt_fifo_empty);
        end
    end
//==============================================================
//======cross fifo
assign c_fifo_wr      = pkt_fifo_rd_dval;
assign c_fifo_wr_data = pkt_fifo_rd_data;
    clk_cross_fifo #(
       .DSIZE (8  )
      ,.ASIZE (6  )
      ,.AEMPT (1  )
      ,.AFULL (32 )
    )clk_cross_fifo
    (
         .WrClock    (i_clk         )
        ,.Reset      (i_reset       )
        ,.WrEn       (c_fifo_wr     )
        ,.Data       (c_fifo_wr_data)
        ,.AlmostFull (c_fifo_afull  )
        ,.Full       ()
        ,.RdClock    (i_ep_clk      )
        ,.RPReset    (i_reset       )
        ,.RdEn       (c_fifo_rd&i_ep_rx_rdy)
        ,.Q          (c_fifo_rd_data)
        ,.AlmostEmpty()
        ,.Empty      (c_fifo_empty  )
    );
    //dual_fifo_top dual_fifo_top(
    //    .WrClk      (i_clk          ), //input WrClk
    //    .WrReset    (i_reset        ), //input WrReset
    //    .RdReset    (i_reset        ), //input RdReset
    //    .WrEn       (c_fifo_wr      ), //input WrEn
    //    .Data       (c_fifo_wr_data ), //input [7:0] Data
    //    .RdClk      (i_ep_clk       ), //input RdClk
    //    .RdEn       (c_fifo_rd      ), //input RdEn
    //    .Almost_Full(c_fifo_afull   ), //output Almost_Full
    //    .Q          (c_fifo_rd_data ), //output [7:0] Q
    //    .Empty      (c_fifo_empty   ), //output Empty
    //    .Full       () //output Full
    //);
    always@(posedge i_ep_clk, posedge i_reset) begin
        if (i_reset) begin
            c_fifo_rd <= 1'b0;
        end
        else begin
            if (c_fifo_rd||c_fifo_empty||(!i_ep_rx_rdy)) begin
                c_fifo_rd <= 1'b0;
            end
            else begin
                c_fifo_rd <= 1'b1;
            end
        end
    end
    always@(posedge i_ep_clk, posedge i_reset) begin
        if (i_reset) begin
            c_fifo_dval <= 1'b0;
        end
        else begin
            if (c_fifo_rd & (!c_fifo_empty)) begin
                c_fifo_dval <= 1'b1;
            end
            //else if (!i_ep_rx_rdy) begin
            //    c_fifo_dval <= c_fifo_dval;
            //end
            else begin
                c_fifo_dval <= 1'b0;
            end
        end
    end
    assign o_usb_rxrdy  = pkt_fifo_wr_num < P_AFULL;
    assign o_ep_rx_dval = c_fifo_dval;
    assign o_ep_rx_data = c_fifo_rd_data;

endmodule

module clk_cross_fifo (
      Q,
      Full,
      Empty,
      AlmostEmpty,
      AlmostFull,
      Data,
      WrEn,
      WrClock,
      Reset,
      RdEn,
      RdClock,
      RPReset
      );
      parameter             DSIZE = 8;
      parameter             ASIZE = 6;
      parameter             AEMPT = 1;
      parameter             AFULL = 32;

      output  [DSIZE-1:0]   Q;
      output                Full;
      output                Empty;
      output                AlmostEmpty;
      output                AlmostFull;
      input   [DSIZE-1:0]   Data;
      input                 WrEn;
      input                 WrClock;
      input                 Reset;
      input                 RdEn;
      input                 RdClock;
      input                 RPReset;
  
      reg     [DSIZE-1:0]   Q;
      reg                   AlmostEmpty;
      reg                   AlmostFull;
      reg                   Full;
      reg                   Empty;
      reg       [ASIZE:0]   wptr;
      reg       [ASIZE:0]   rptr; 
      reg       [ASIZE:0]   wq2_rptr;
      reg       [ASIZE:0]   rq2_wptr; 
      reg       [ASIZE:0]   wq1_rptr;
      reg       [ASIZE:0]   rq1_wptr;
      reg       [ASIZE:0]   rbin;
      reg       [ASIZE:0]   wbin;

      reg       [DSIZE-1:0] mem[0:(1<<ASIZE)-1];

      wire      [ASIZE-1:0] waddr;
      wire      [ASIZE-1:0] raddr;
      wire      [ASIZE:0]   rgraynext;
      wire      [ASIZE:0]   rbinnext;
      wire      [ASIZE:0]   wgraynext;
      wire      [ASIZE:0]   wbinnext;
      wire                  rempty_val;
      wire                  wfull_val;
      wire      [ASIZE:0]   wcount_r;
      wire      [ASIZE:0]   rcnt_sub;
      wire      [ASIZE:0]   rcount_w;
      wire      [ASIZE:0]   wcnt_sub;    

      always@(posedge RdClock)
      begin
        if(RdEn)
          Q <= mem[raddr];
      end

      always@(posedge WrClock)
      begin
        if(WrEn && !Full)
          mem[waddr] <= Data;
      end

      always @(posedge WrClock or posedge Reset)
      begin
        if (Reset)
          {wq2_rptr,wq1_rptr} <= 0;
        else
          {wq2_rptr,wq1_rptr} <= {wq1_rptr,rptr};
      end

      always @(posedge RdClock or posedge RPReset)
      begin
        if (RPReset)
          {rq2_wptr,rq1_wptr} <= 0;
        else
          {rq2_wptr,rq1_wptr} <= {rq1_wptr,wptr};
      end

      always @(posedge RdClock or posedge RPReset)
      begin
        if (RPReset)
          {rbin, rptr} <= 0;
        else
          {rbin, rptr} <= {rbinnext, rgraynext};
      end

      assign raddr      = rbin[ASIZE-1:0];
      assign rbinnext   = rbin + (RdEn & ~Empty);
      assign rgraynext  = (rbinnext>>1) ^ rbinnext;
      assign rempty_val = (rgraynext == rq2_wptr);

      assign wcount_r   = gry2bin(rq2_wptr);
      assign rcnt_sub   = {(wcount_r[ASIZE] ^ rbinnext[ASIZE]), wcount_r[ASIZE-1:0]} - {1'b0, rbinnext[ASIZE-1:0]};
      assign arempty_val= rcnt_sub <= AEMPT;

      always @(posedge RdClock or posedge RPReset)
      begin
      if (RPReset)
        Empty <= 1'b1;
      else
        Empty <= rempty_val;
      end

      always @(posedge RdClock or posedge RPReset)
      begin
      if (RPReset)
        AlmostEmpty <= 1'b1;
      else
        AlmostEmpty <= arempty_val;
      end
 
      always @(posedge WrClock or posedge Reset)
      begin
        if (Reset)
          {wbin, wptr} <= 0;
        else
          {wbin, wptr} <= {wbinnext, wgraynext};
      end
   
      assign waddr      = wbin[ASIZE-1:0];
      assign wbinnext   = wbin + (WrEn & ~Full);
      assign wgraynext  = (wbinnext>>1) ^ wbinnext;
      assign wfull_val  = (wgraynext == {~wq2_rptr[ASIZE:ASIZE-1],
                                          wq2_rptr[ASIZE-2:0]});
  
      assign rcount_w   = gry2bin(wq2_rptr);
      assign wcnt_sub   = {(rcount_w[ASIZE] ^ wbinnext[ASIZE]), wbinnext[ASIZE-1:0]} - {1'b0, rcount_w[ASIZE-1:0]};
      assign awfull_val = wcnt_sub >= AFULL;

      always @(posedge WrClock or posedge Reset)
      begin
        if (Reset)
          Full <= 1'b0;
        else
          Full <= wfull_val;
      end

      always @(posedge WrClock or posedge Reset)
      begin
        if (Reset)
          AlmostFull <= 1'b0;
        else
          AlmostFull <= awfull_val;
      end

      function [ASIZE:0]gry2bin;
        input [ASIZE:0] gry_code;
        integer         i;
        begin
          gry2bin[ASIZE]=gry_code[ASIZE];    
          for(i=ASIZE-1;i>=0;i=i-1)        
            gry2bin[i]=gry2bin[i+1]^gry_code[i];
        end
      endfunction

endmodule
