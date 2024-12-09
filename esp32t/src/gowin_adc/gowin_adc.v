//Copyright (C)2014-2023 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//GOWIN Version: V1.9.9 Beta-4
//Part Number: GW5A-EV25UG256CES
//Device: GW5A-25
//Device Version: A
//Created Time: Tue Oct 31 16:08:09 2023

module Gowin_ADC (adcrdy, adcvalue, mdrp_rdata, vsenctl, adcen, clk, drstn, adcreqi, adcmode, mdrp_clk, mdrp_wdata, mdrp_a_inc, mdrp_opcode);

output adcrdy;
output [13:0] adcvalue;
output [7:0] mdrp_rdata;
input [2:0] vsenctl;
input adcen;
input clk;
input drstn;
input adcreqi;
input adcmode;
input mdrp_clk;
input [7:0] mdrp_wdata;
input mdrp_a_inc;
input [1:0] mdrp_opcode;

ADC adc_inst (
    .ADCRDY(adcrdy),
    .ADCVALUE(adcvalue),
    .MDRP_RDATA(mdrp_rdata),
    .VSENCTL(vsenctl),
    .ADCEN(adcen),
    .CLK(clk),
    .DRSTN(drstn),
    .ADCREQI(adcreqi),
    .ADCMODE(adcmode),
    .MDRP_CLK(mdrp_clk),
    .MDRP_WDATA(mdrp_wdata),
    .MDRP_A_INC(mdrp_a_inc),
    .MDRP_OPCODE(mdrp_opcode)
);

defparam adc_inst.CLK_SEL = 1'b0;
defparam adc_inst.DIV_CTL = 2'd0;
defparam adc_inst.BUF_EN = 12'b010000001001;
defparam adc_inst.BUF_BK0_VREF_EN = 1'b0;
defparam adc_inst.BUF_BK1_VREF_EN = 1'b0;
defparam adc_inst.BUF_BK2_VREF_EN = 1'b0;
defparam adc_inst.BUF_BK3_VREF_EN = 1'b0;
defparam adc_inst.BUF_BK4_VREF_EN = 1'b0;
defparam adc_inst.BUF_BK5_VREF_EN = 1'b0;
defparam adc_inst.BUF_BK6_VREF_EN = 1'b0;
defparam adc_inst.BUF_BK7_VREF_EN = 1'b0;
defparam adc_inst.CSR_ADC_MODE = 1'b1;
defparam adc_inst.CSR_VSEN_CTRL = 3'd0;
defparam adc_inst.CSR_SAMPLE_CNT_SEL = 3'd4;
defparam adc_inst.CSR_RATE_CHANGE_CTRL = 3'd4;
defparam adc_inst.CSR_FSCAL = 10'd653;
defparam adc_inst.CSR_OFFSET = 12'd0;

endmodule //Gowin_ADC
