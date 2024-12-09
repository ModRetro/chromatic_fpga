//
// File name          :uart.v
// Module name        :uart.v
// Created by         :GaoYun Semi
// Author             :(Winson)
// Created On         :2020-11-05 14:26 GuangZhou
// Last Modified      :
// Update Count       :2020-11-05 14:26
// Description        :
//----------------------------------------------------------------------
//===========================================
module usb_uart_config 
(
    input              PHY_CLKOUT        ,// clock
    input              RESET_IN          ,// reset
    input              setup_active      ,
    input   [3:0]      endpt_sel         ,
    input              usb_rxval         ,
    input              usb_rxact         ,
    input   [7:0]      usb_rxdat         ,
    input              usb_txact         ,
    input              usb_txpop         ,
    output  [11:0]     usb_txdat_len_o   ,
    output  [7:0]      endpt0_dat_o      ,
    output             endpt0_send_o     ,
    output             uart1_en_o        ,
    output  [31:0]     uart1_BAUD_RATE_o ,
    output  [7:0]      uart1_PARITY_BIT_o,
    output  [7:0]      uart1_STOP_BIT_o  ,
    output  [7:0]      uart1_DATA_BITS_o,
    output  reg [15:0] s_ctl_sig

);

parameter ENDPT_UART_CONFIG =4'h0;
parameter ENDPT_UART1_DATA  =4'h1;
parameter ENDPT_UART2_DATA  =4'h2;
parameter ENDPT_UART3_DATA  =4'h3;
parameter ENDPT_I2C1        =4'h4;
parameter ENDPT_I2C2        =4'h5;
parameter ENDPT_I2C3        =4'h6;
parameter ENDPT_I2C4        =4'h7;
parameter ENDPT_PARALLEL20  =4'h8;


localparam  SET_LINE_CODING = 8'h20;
localparam  GET_LINE_CODING = 8'h21;
localparam  SET_CONTROL_LINE_STATE = 8'h22;

reg [7:0] stage;
reg [7:0] sub_stage;
reg [7:0] s_req_type;
reg [7:0] s_req_code;
reg [15:0]s_set_len;
reg [15:0]s_interface_num;
reg       s_uart1_en;

reg [31:0]s_dte1_rate;
reg [7:0] s_char1_format;
reg [7:0] s_parity1_type;
reg [7:0] s_data1_bits;
reg [7:0] s_char2_format;
reg [7:0] s_parity2_type;
reg [7:0] s_data2_bits;
reg [31:0]s_dte3_rate;
reg [7:0] s_char3_format;
reg [7:0] s_parity3_type;
reg [7:0] s_data3_bits;
reg [7:0] endpt0_dat;
reg       endpt0_send;

assign uart1_en_o=s_uart1_en;
assign uart1_BAUD_RATE_o=s_dte1_rate;
assign uart1_PARITY_BIT_o=s_parity1_type;
assign uart1_STOP_BIT_o=s_char1_format;
assign uart1_DATA_BITS_o=s_data1_bits;
assign endpt0_dat_o=endpt0_dat;
assign endpt0_send_o=endpt0_send;
assign usb_txdat_len_o=12'd7;

always @(posedge PHY_CLKOUT,posedge RESET_IN) begin
    if (RESET_IN) begin
        stage <= 8'd0;
        sub_stage <= 8'd0;
        s_req_type <= 8'd0;
        s_req_code <= 8'd0;
        s_ctl_sig <= 16'd0;
        s_set_len <= 16'd0;
        s_interface_num<= 16'd0;
        s_dte1_rate <= 32'd115200;
        s_char1_format <= 8'd0;
        s_parity1_type <= 8'd0;
        s_data1_bits <= 8'd8;
        endpt0_send <= 1'd0;
        endpt0_dat  <= 8'd0;
        s_uart1_en <= 1'b0;
    end
    else begin
        if (setup_active) begin
            if (usb_rxval) begin
                case (stage)
                    8'd0 : begin
                        s_req_type <= usb_rxdat;
                        stage <= stage + 8'd1;
                        sub_stage <= 8'd0;
                        endpt0_send <= 1'd0;
                    end
                    8'd1 : begin
                        s_req_code <= usb_rxdat;
                        stage <= stage + 8'd1;
                    end
                    8'd2 : begin
                        if (s_req_code == SET_CONTROL_LINE_STATE) begin
                            s_ctl_sig[7:0] <= usb_rxdat;
                        end
                        stage <= stage + 8'd1;
                    end
                    8'd3 : begin
                        if (s_req_code == SET_CONTROL_LINE_STATE) begin
                            s_ctl_sig[15:8] <= usb_rxdat;
                        end
                        stage <= stage + 8'd1;
                    end
                    8'd4 : begin
                        stage <= stage + 8'd1;
                        if (s_req_code == SET_LINE_CODING) begin
                            s_interface_num[7:0] <= usb_rxdat;
                        end
                        else if (s_req_code == SET_CONTROL_LINE_STATE) begin
                            s_interface_num[7:0] <= usb_rxdat;
                        end
                    end
                    8'd5 : begin
                        stage <= stage + 8'd1;
                        if (s_req_code == SET_LINE_CODING) begin
                            s_interface_num[15:8] <= usb_rxdat;
                        end
                        else if (s_req_code == SET_CONTROL_LINE_STATE) begin
                            s_interface_num[15:8] <= usb_rxdat;
                        end

                    end
                    8'd6 : begin
                        if (s_req_code == SET_LINE_CODING) begin
                            s_set_len[7:0] <= usb_rxdat;
                        end
                        else if (s_req_code == GET_LINE_CODING) begin
                            s_set_len[7:0] <= usb_rxdat;
                            if (s_interface_num == 16'd0) begin
                                endpt0_send <= 1'd1;
                            end
                        end
                        else if (s_req_code == SET_CONTROL_LINE_STATE) begin
                            if (s_interface_num == 16'd0) begin
                                s_uart1_en <= s_ctl_sig[0];
                            end
                        end
                        stage <= stage + 8'd1;
                    end
                    8'd7 : begin
                        if (s_req_code == SET_LINE_CODING) begin
                            s_set_len[15:8] <= usb_rxdat;
                        end
                        else if (s_req_code == GET_LINE_CODING) begin
                            s_set_len[15:8] <= usb_rxdat;
                            if (s_interface_num == 16'd0) begin
                                endpt0_send <= 1'd1;
                                endpt0_dat <= s_dte1_rate[7:0];
                            end
                        end
                        stage <= stage + 8'd1;
                        sub_stage <= 8'd0;
                    end
                    8'd8 : begin
                        stage <= stage;
                    end
                endcase
            end
        end
        else if (s_req_code == SET_LINE_CODING) begin
            stage <= 8'd0;
            if ((usb_rxact)&&(endpt_sel ==ENDPT_UART_CONFIG)) begin
                if (usb_rxval) begin
                    sub_stage <= sub_stage + 8'd1;
                    if(s_interface_num==0)begin
                        if (sub_stage <= 3) begin
                            s_dte1_rate <= {usb_rxdat,s_dte1_rate[31:8]};
                        end
                        else if (sub_stage == 4) begin
                            s_char1_format <= usb_rxdat;
                        end
                        else if (sub_stage == 5) begin
                            s_parity1_type <= usb_rxdat;
                        end
                        else if (sub_stage == 6) begin
                            s_data1_bits <= usb_rxdat;
                        end
                    end
                end
            end
        end
        else if (s_req_code == GET_LINE_CODING) begin
            stage <= 8'd0;
            if ((usb_txact)&&(endpt_sel ==ENDPT_UART_CONFIG)) begin
                if (endpt0_send == 1'b1) begin
                    if (usb_txpop) begin
                        sub_stage <= sub_stage + 8'd1;
                    end
                    if (s_req_code == GET_LINE_CODING) begin
                       /* if (sub_stage <= 0) begin //old controller version
                            endpt0_dat <= s_dte_rate[7:0];
                        end
                        else if (sub_stage == 1) begin
                            endpt0_dat <= s_dte_rate[15:8];
                        end
                        else if (sub_stage == 2) begin
                            endpt0_dat <= s_dte_rate[23:16];
                        end
                        else if (sub_stage == 3) begin
                            endpt0_dat <= s_dte_rate[31:24];
                        end
                        else if (sub_stage == 4) begin
                            endpt0_dat <= s_char_format;
                        end
                        else if (sub_stage == 5) begin
                            endpt0_dat <= s_parity_type;
                        end
                        else if (sub_stage == 6) begin
                            endpt0_dat <= s_data_bits;
                        end
                        else begin
                            endpt0_send <= 1'b0;
                        end*/
                        if (usb_txpop) begin// new controller version
                            if(s_interface_num==0)begin
                                if (sub_stage <= 0) begin
                                    endpt0_dat <= s_dte1_rate[15:8];
                                end
                                else if (sub_stage == 1) begin
                                    endpt0_dat <= s_dte1_rate[23:16];
                                end
                                else if (sub_stage == 2) begin
                                    endpt0_dat <= s_dte1_rate[31:24];
                                end
                                else if (sub_stage == 3) begin
                                    endpt0_dat <= s_char1_format;
                                end
                                else if (sub_stage == 4) begin
                                    endpt0_dat <= s_parity1_type;
                                end
                                else if (sub_stage == 5) begin
                                    endpt0_dat <= s_data1_bits;
                                end
                                else if (sub_stage == 6) begin
                                    endpt0_send <= 1'b0;
                                end
                                else begin
                                    endpt0_send <= 1'b0;
                                end
                            end
                        end
                    end
                end
            end
            else begin
                sub_stage <= 8'd0;
            end
        end
        else begin
             stage <= 8'd0;
             sub_stage <= 8'd0;
        end
    end
end

 
endmodule
