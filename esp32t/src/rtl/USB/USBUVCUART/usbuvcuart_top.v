// usbuvc_top.v

`include "usb_video/usb_defs.v"
`include "usb_video/uvc_defs.v"

module usbuvcuart_top(
    input               CLK_24MHz,
    input               ERST,
    output              pClk,
    output              usblocked,
    input               hClk,
    input               hLineValid,
    input               hEnable,
    input               hFrameValid,
    input   [17:0]      hData,
    
    input   [7:0]       playerNum,

    output              UART_TXD   ,
    input               UART_RXD   ,
    output              E_UART_DTR   , // when UART_RTS = 0, UART This Device Ready to receive.
    output              E_UART_RTS   , // when UART_RTS = 0, UART This Device Ready to receive.
    input               UART_CTS   , // when UART_CTS = 0, UART Opposite Device Ready to receive.
    
    output  [7:0]       debugs,
    inout               usb_dxp_io,
    inout               usb_dxn_io,
    input               usb_rxdp_i,
    input               usb_rxdn_i,
    output              usb_pullup_en_o,
    inout               usb_term_dp_io,
    inout               usb_term_dn_io
);

    wire [7:0] PHY_DATAOUT;
    wire       PHY_TXVALID;
    wire [1:0] PHY_XCVRSELECT;
    wire [7:0] PHY_DATAIN;
    wire [1:0] PHY_LINESTATE;
    wire [1:0] PHY_OPMODE;

    wire        ep_usb_rxrdy;
    wire        ep_usb_txcork;
    wire [11:0] ep_usb_txlen;
    wire [7:0]  ep_usb_txdat;

    wire [7:0]  usb_txdat;
    wire        usb_txval;
    wire        usb_txpop;
    wire        usb_txact;
    wire        usb_txpktfin;
    wire [7:0]  usb_rxdat;
    wire        usb_rxact;
    wire        usb_rxval;
    reg  [7:0]  rst_cnt;
    wire [3:0]  endpt_sel;
    wire        setup_active;
    wire        setup_val;
    wire [7:0]  setup_data;
    wire        fclk_480M;
    wire        fclk_960M;

    wire [9:0]  DESCROM_RADDR       ;
    wire [7:0]  DESCROM_RDAT        ;
    wire [9:0]  DESC_DEV_ADDR       ;
    wire [7:0]  DESC_DEV_LEN        ;
    wire [9:0]  DESC_QUAL_ADDR      ;
    wire [7:0]  DESC_QUAL_LEN       ;
    wire [9:0]  DESC_FSCFG_ADDR     ;
    wire [7:0]  DESC_FSCFG_LEN      ;
    wire [9:0]  DESC_HSCFG_ADDR     ;
    wire [7:0]  DESC_HSCFG_LEN      ;
    wire [9:0]  DESC_OSCFG_ADDR     ;
    wire [9:0]  DESC_STRLANG_ADDR   ;
    wire [9:0]  DESC_STRVENDOR_ADDR ;
    wire [7:0]  DESC_STRVENDOR_LEN  ;
    wire [9:0]  DESC_STRPRODUCT_ADDR;
    wire [7:0]  DESC_STRPRODUCT_LEN ;
    wire [9:0]  DESC_STRSERIAL_ADDR ;
    wire [7:0]  DESC_STRSERIAL_LEN  ;
    wire        DESCROM_HAVE_STRINGS;
    wire        RESET_IN;
    
    wire pll_locked;
    Gowin_PLL_UVC u_Gowin_PLL_USB(
        .reset(ERST),
        .clkout0(fclk_960M), //output clkout0
        .clkout1(pClk), //output clkout1
        .lock(pll_locked),
        .clkin(CLK_24MHz) //input clkin
    );

    assign usblocked = pll_locked;
    wire        RESET_N = pll_locked&~ERST;

    //==============================================================
    //======Reset
    assign RESET_IN = ~RESET_N;//rst_cnt<32;
    always@(posedge pClk, negedge RESET_N) begin
        if (!RESET_N) begin
            rst_cnt <= 8'd0;
        end
        else if (rst_cnt <= 32) begin
            rst_cnt <= rst_cnt + 8'd1;
        end
    end

    reg [7:0] dect;
    always@(posedge pClk, negedge RESET_N) begin
        if (!RESET_N) begin
             dect <= 'd0;
        end
        else begin
            if (PHY_TXVALID) begin
                dect <= 'd0;
            end
            else begin
                dect <= dect + 1'd1;
            end
        end
    end

    //==============================================================
    //======UVC pFrame Data

    wire [11:0] uvc_txlen;
    wire [7:0] frame_data;
    reg [7:0] pUvcPacketData;

    assign usb_txdat = (endpt_sel == 4'd0) ? endpt0_dat[7:0] :
                       (endpt_sel == 4'd2) ? pUvcPacketData  :
                       ep_usb_txdat;//fifo_rdat[7:0];
    assign usb_txval = (endpt_sel == 4'd0) ? endpt0_send : 1'b0;


    wire fifo_afull;
    wire fifo_aempty;
    wire [7:0]  fifo_rdat;

    reg txact_d0;
    reg txact_d1;
    wire txact_rise;
    assign txact_rise = txact_d0&(~txact_d1);
    assign txact_fall = txact_d1&(~txact_d0);
    always@(posedge pClk, posedge RESET_IN) begin
        if (RESET_IN) begin
            txact_d0 <= 1'b0;
            txact_d1 <= 1'b0;
        end
        else begin
            txact_d0 <= usb_txact;
            txact_d1 <= txact_d0;
        end
    end

    //`define MFRAME_PACKETS3
    `define HSSUPPORT
    //`define MFRAME_PACKETS2
    reg [3:0] iso_pid_data;
    always @(posedge pClk ) begin //or posedge s_reset
        if(RESET_IN) begin
            `ifdef HSSUPPORT
                `ifdef MFRAME_PACKETS3
                    iso_pid_data <= 4'b0111;//DATA2
                `elsif MFRAME_PACKETS2
                    iso_pid_data <= 4'b1011;//DATA1
                `else
                    iso_pid_data <= 4'b0011;//DATA1
                `endif
            `else
                iso_pid_data <= 4'b0011;//DATA0
            `endif
        end
        else begin
            `ifdef HSSUPPORT
                `ifdef MFRAME_PACKETS3
                    if (usb_sof) begin
                        if (fifo_afull) begin
                            iso_pid_data <= 4'b0111;//DATA2
                        end
                        else if (fifo_aempty) begin
                            iso_pid_data <= 4'b0011;//DATA0
                        end
                        else begin
                            iso_pid_data <= 4'b1011;//DATA1
                        end
                        //iso_pid_data <= 4'b0111;//DATA2
                    end
                    else if (txact_fall&&(endpt_sel==4'd2)) begin
                        iso_pid_data <= (iso_pid_data == 4'b0111) ? 4'b1011 : ((iso_pid_data == 4'b1011) ? 4'b0011 : iso_pid_data);//DATA2(0111) -> DATA1(1011) -> DATA0(0011)
                    end
                `elsif MFRAME_PACKETS2
                    if (usb_sof) begin
                        //if (fifo_afull) begin
                        //    iso_pid_data <= 4'b0111;//DATA2
                        //end
                        //else if (fifo_aempty) begin
                        //    iso_pid_data <= 4'b0011;//DATA0
                        //end
                        //else begin
                        //    iso_pid_data <= 4'b1011;//DATA1
                        //end
                        iso_pid_data <= 4'b0111;//DATA2
                    end
                    else if (txact_fall&&(endpt_sel==4'd2)) begin
                        iso_pid_data <= (iso_pid_data == 4'b1011) ? 4'b0011 : iso_pid_data;//DATA1(1011) -> DATA0(0011)
                    end
                `else
                    iso_pid_data <= 4'b0011;//DATA0
                `endif
            `else
                iso_pid_data <= 4'b0011;//DATA0
            `endif
        end
    end

    //==============================================================
    //======Interface Setting
    wire [7:0] interface_alter_i;
    wire [7:0] interface_alter_o;
    wire [7:0] interface_sel;
    wire       interface_update;

    reg [7:0] interface0_alter;
    reg [7:0] interface1_alter;
    assign interface_alter_i = (interface_sel == 0) ?  interface0_alter :
                               (interface_sel == 1) ?  interface1_alter : 8'd0;
    always@(posedge pClk, posedge RESET_IN   ) begin
        if (RESET_IN) begin
            interface0_alter <= 'd0;
            interface1_alter <= 'd0;
        end
        else begin
            if (interface_update) begin
                if (interface_sel == 0) begin
                    interface0_alter <= interface_alter_o;
                end
                else if (interface_sel == 1) begin
                    interface1_alter <= interface_alter_o;
                end
            end
        end
    end

    reg [11:0]  pTxDataLength;
    reg         pTxCork;

    USB_Device_Controller_Top u_usb_device_controller_top (
             .clk_i                 (pClk          )
            ,.reset_i               (RESET_IN            )
            ,.usbrst_o              (usb_busreset        )
            ,.highspeed_o           (usb_highspeed       )
            ,.suspend_o             (usb_suspend         )
            ,.online_o              (usb_online          )
            //,.iso_pid_i           (usb_iso_pid           )//
            ,.txdat_i             (usb_txdat)//
            ,.txval_i             (usb_txval           )//endpt0_send
            ,.txdat_len_i         (pTxDataLength)//
            ,.txiso_pid_i         (iso_pid_data        )//
            ,.txcork_i            (pTxCork)//usb_txcork
            ,.txpop_o             (usb_txpop           )
            ,.txact_o             (usb_txact           )
            ,.txpktfin_o          (usb_txpktfin        )
            ,.rxdat_o             (usb_rxdat           )
            ,.rxval_o             (usb_rxval           )
            ,.rxact_o             (usb_rxact           )
            ,.rxrdy_i             (ep_usb_rxrdy        )
            ,.rxpktval_o          (usb_rxpktval        )
            ,.setup_o             (setup_active        )
            ,.endpt_o             (endpt_sel           )
            ,.sof_o               (usb_sof             )
            ,.inf_alter_i         (interface_alter_i   )
            ,.inf_alter_o         (interface_alter_o   )
            ,.inf_sel_o           (interface_sel       )
            ,.inf_set_o           (interface_update    )
            ,.descrom_rdata_i     (DESCROM_RDAT        )
            ,.descrom_raddr_o     (DESCROM_RADDR       )
            ,.desc_dev_addr_i       (DESC_DEV_ADDR       )
            ,.desc_dev_len_i        (DESC_DEV_LEN        )
            ,.desc_qual_addr_i      (DESC_QUAL_ADDR      )
            ,.desc_qual_len_i       (DESC_QUAL_LEN       )
            ,.desc_fscfg_addr_i     (DESC_FSCFG_ADDR     )
            ,.desc_fscfg_len_i      (DESC_FSCFG_LEN      )
            ,.desc_hscfg_addr_i     (DESC_HSCFG_ADDR     )
            ,.desc_hscfg_len_i      (DESC_HSCFG_LEN      )
            ,.desc_oscfg_addr_i     (DESC_OSCFG_ADDR     )
            ,.desc_strlang_addr_i   (DESC_STRLANG_ADDR   )
            ,.desc_strvendor_addr_i (DESC_STRVENDOR_ADDR )
            ,.desc_strvendor_len_i  (DESC_STRVENDOR_LEN  )
            ,.desc_strproduct_addr_i(DESC_STRPRODUCT_ADDR)
            ,.desc_strproduct_len_i (DESC_STRPRODUCT_LEN )
            ,.desc_strserial_addr_i (DESC_STRSERIAL_ADDR )
            ,.desc_strserial_len_i  (DESC_STRSERIAL_LEN  )
            ,.desc_have_strings_i   (DESCROM_HAVE_STRINGS)

            ,.utmi_dataout_o        (PHY_DATAOUT       )
            ,.utmi_txvalid_o        (PHY_TXVALID       )
            ,.utmi_txready_i        (PHY_TXREADY       )
            ,.utmi_datain_i         (PHY_DATAIN        )
            ,.utmi_rxactive_i       (PHY_RXACTIVE      )
            ,.utmi_rxvalid_i        (PHY_RXVALID       )
            ,.utmi_rxerror_i        (PHY_RXERROR       )
            ,.utmi_linestate_i      (PHY_LINESTATE     )
            ,.utmi_opmode_o         (PHY_OPMODE        )
            ,.utmi_xcvrselect_o     (PHY_XCVRSELECT    )
            ,.utmi_termselect_o     (PHY_TERMSELECT    )
            ,.utmi_reset_o          (PHY_RESET         )
         );

    reg [5:0] clkdiv;
    always@(posedge pClk)
        clkdiv <= clkdiv + 1'd1;
     wire oClk = clkdiv[5];

    wire otp_dout;
    wire otp_shift;
    reg otp_read;

    OTP #(
        .MODE(2'b10)
    )   u_OTP(
        .CLK(oClk),
        .READ(otp_read),
        .SHIFT(otp_shift),
        .DOUT(otp_dout)
    );
    
    reg [128:0] otp_data;
    assign otp_shift = ~otp_data[128];
    always@(posedge oClk or posedge RESET_IN)
    begin
        if(RESET_IN)
        begin
            otp_data <= 1'd1;
            otp_read <= 1'd1;
        end
        else
        begin
            otp_read <= 1'd0;
            if(otp_shift)
                otp_data <= {otp_data[127:0], otp_dout};
        end
    end
    
    wire [63:0] serial;
    //==============================================================
    //======USB Device descriptor Demo
    usb_desc
    #(

             .VENDORID    (16'h374E)//0403   08bb
            ,.PRODUCTID   (16'h013f)//6010   27c6
            ,.VERSIONBCD  (16'h0200)
            ,.HSSUPPORT   (1)
            ,.SELFPOWERED (0)
    )
    u_usb_desc (
         .CLK                    (pClk          )
        ,.RESET                  (RESET_IN            )
        ,.playerNum              (playerNum)
        ,.serial                 (serial)
        ,.i_descrom_raddr        (DESCROM_RADDR       )
        ,.o_descrom_rdat         (DESCROM_RDAT        )
        ,.o_desc_dev_addr        (DESC_DEV_ADDR       )
        ,.o_desc_dev_len         (DESC_DEV_LEN        )
        ,.o_desc_qual_addr       (DESC_QUAL_ADDR      )
        ,.o_desc_qual_len        (DESC_QUAL_LEN       )
        ,.o_desc_fscfg_addr      (DESC_FSCFG_ADDR     )
        ,.o_desc_fscfg_len       (DESC_FSCFG_LEN      )
        ,.o_desc_hscfg_addr      (DESC_HSCFG_ADDR     )
        ,.o_desc_hscfg_len       (DESC_HSCFG_LEN      )
        ,.o_desc_oscfg_addr      (DESC_OSCFG_ADDR     )
        ,.o_desc_strlang_addr    (DESC_STRLANG_ADDR   )
        ,.o_desc_strvendor_addr  (DESC_STRVENDOR_ADDR )
        ,.o_desc_strvendor_len   (DESC_STRVENDOR_LEN  )
        ,.o_desc_strproduct_addr (DESC_STRPRODUCT_ADDR)
        ,.o_desc_strproduct_len  (DESC_STRPRODUCT_LEN )
        ,.o_desc_strserial_addr  (DESC_STRSERIAL_ADDR )
        ,.o_desc_strserial_len   (DESC_STRSERIAL_LEN  )
        ,.o_descrom_have_strings (DESCROM_HAVE_STRINGS)
    );

    //==============================================================
    //======USB SoftPHY 
    USB2_0_SoftPHY_Top u_USB_SoftPHY_Top
    (
         .clk_i            (pClk    )
        ,.rst_i            (PHY_RESET | ERST     )
        ,.fclk_i           (fclk_960M     )
        ,.pll_locked_i     (pll_locked    )
        ,.utmi_data_out_i  (PHY_DATAOUT   )
        ,.utmi_txvalid_i   (PHY_TXVALID   )
        ,.utmi_op_mode_i   (PHY_OPMODE    )
        ,.utmi_xcvrselect_i(PHY_XCVRSELECT)
        ,.utmi_termselect_i(PHY_TERMSELECT)
        ,.utmi_data_in_o   (PHY_DATAIN    )
        ,.utmi_txready_o   (PHY_TXREADY   )
        ,.utmi_rxvalid_o   (PHY_RXVALID   )
        ,.utmi_rxactive_o  (PHY_RXACTIVE  )
        ,.utmi_rxerror_o   (PHY_RXERROR   )
        ,.utmi_linestate_o (PHY_LINESTATE )
        ,.usb_dxp_io        (usb_dxp_io   )
        ,.usb_dxn_io        (usb_dxn_io   )
        ,.usb_rxdp_i        (usb_rxdp_i   )
        ,.usb_rxdn_i        (usb_rxdn_i   )
        ,.usb_pullup_en_o   (usb_pullup_en_o)
        ,.usb_term_dp_io    (usb_term_dp_io)
        ,.usb_term_dn_io    (usb_term_dn_io)
    );

    reg  [15:0] bmHint                  ;//short
    reg  [ 7:0] bFormatIndex            ;//char
    reg  [ 7:0] bFrameIndex             ;//char
    reg  [31:0] dwFrameInterval         ;//int
    reg  [15:0] wKeyFrameRate           ;//short
    reg  [15:0] wPFrameRate             ;//short
    reg  [15:0] wCompQuality            ;//short
    reg  [15:0] wCompWindowSize         ;//short
    reg  [15:0] wDelay                  ;//short
    reg  [31:0] dwMaxVideoFrameSize     ;//int
    reg  [31:0] dwMaxPayloadTransferSize;//int
    reg  [31:0] dwClockFrequency        ;//int
    reg  [ 7:0] bmFramingInfo           ;//char
    reg  [ 7:0] bPreferedVersion        ;//char
    reg  [ 7:0] bMinVersion             ;//char
    reg  [ 7:0] bMaxVersion             ;//char
    reg  [ 7:0] bmRequestType; ///< Specifies direction of dataflow, type of rquest and recipient
    reg  [ 7:0] bRequest     ; ///< Specifies the request
    reg  [15:0] wValue       ; ///< Host can use this to pass info to the device in its own way
    reg  [15:0] wIndex       ; ///< Typically used to pass index/offset such as interface or EP no
    reg  [15:0] wLength      ; ///< Number of data bytes in the data stage (for Host -> Device this this is exact count, for Dev->Host is a max)
    reg  [ 7:0] sub_stage    ;
    reg  [ 7:0] stage        ;
    reg  [ 7:0] endpt0_dat   ;
    reg         endpt0_send  ;


    localparam  SET_LINE_CODING = 8'h20;
    localparam  GET_LINE_CODING = 8'h21;
    localparam  SET_CONTROL_LINE_STATE = 8'h22;
    localparam  ENDPT_UART_CONFIG = 4'h0;
    localparam  ENDPT_UART_DATA = 16'h3;
    
    reg [15:0]  s_ctl_sig;
    reg [15:0]  s_interface_num;
    reg [15:0]  s_set_len;
    reg         s_uart1_en;
    reg [31:0]  s_dte1_rate;
    reg [7:0]   s_char1_format;
    reg [7:0]   s_parity1_type;
    reg [7:0]   s_data1_bits;

    wire [31:0] uart_dte_rate = s_dte1_rate;
    wire [7:0]  uart_char_format = s_char1_format;
    wire [7:0]  uart_parity_type = s_parity1_type;
    wire [7:0]  uart_data_bits = s_data1_bits;
    reg [7:0] lcc;
    always @(posedge pClk,posedge RESET_IN) 
        if (RESET_IN) begin
            stage                    <= 8'd0;
            sub_stage                <= 8'd0;
            endpt0_send              <= 1'd0;
            endpt0_dat               <= 8'd0;
            bmRequestType            <= 8'd0;
            bRequest                 <= 8'd0;
            wValue                   <= 16'd0;
            wIndex                   <= 16'd0;
            wLength                  <= 16'd0;
            bmHint                   <= 0;
            bFormatIndex             <= 8'h01;
            bFrameIndex              <= 8'h01;
            dwFrameInterval          <= 333333;//`FRAME_INTERVAL;
            wKeyFrameRate            <= 0;
            wPFrameRate              <= 0;
            wCompQuality             <= 0;
            wCompWindowSize          <= 0;
            wDelay                   <= 0;
            dwMaxVideoFrameSize      <= `MAX_FRAME_SIZE;
            dwMaxPayloadTransferSize <= 32'd1024;//`PAYLOAD_SIZE;
            dwClockFrequency         <= 60000000;
            bmFramingInfo            <= 0;
            bPreferedVersion         <= 0;
            bMinVersion              <= 0;
            bMaxVersion              <= 0;

            s_interface_num          <= 16'd0;
            s_ctl_sig                <= 16'd0;
            s_dte1_rate              <= 32'd115200;
            s_set_len                <= 16'd0;
            s_uart1_en               <= 1'b0;
            s_char1_format           <= 8'd0;
            s_parity1_type           <= 8'd0;
            s_data1_bits             <= 8'd8;
            lcc                      <= 'd0;

        end
        else 
        begin
            if (setup_active) 
            begin
                if (usb_rxval) 
                begin
                    case (stage)
                        8'd0 : 
                        begin
                            bmRequestType <= usb_rxdat;
                            stage <= stage + 8'd1;
                            sub_stage <= 8'd0;
                            endpt0_send <= 1'd0;
                        end
                        8'd1 : 
                        begin
                            bRequest <= usb_rxdat;
                            stage <= stage + 8'd1;
                        end
                        8'd2 : 
                        begin
                            if (bRequest == GET_LINE_CODING) 
                                lcc <= lcc + 1'd1;
                                
                            if (bRequest == SET_CONTROL_LINE_STATE) 
                            begin
                                s_ctl_sig[7:0] <= usb_rxdat;
                            end                        
                            wValue[7:0] <= usb_rxdat;
                            stage <= stage + 8'd1;
                        end
                        8'd3 : 
                        begin
                            if (bRequest == SET_CONTROL_LINE_STATE) 
                            begin
                                s_ctl_sig[15:8] <= usb_rxdat;
                            end
                            wValue[15:8] <= usb_rxdat;
                            stage <= stage + 8'd1;
                        end
                        8'd4 : 
                        begin
                            if (bRequest == SET_LINE_CODING) 
                            begin
                                s_interface_num[7:0] <= usb_rxdat;
                            end
                            else 
                                if (bRequest == SET_CONTROL_LINE_STATE) 
                                begin
                                    s_interface_num[7:0] <= usb_rxdat;
                                end
                        
                            stage <= stage + 8'd1;
                            wIndex[7:0] <= usb_rxdat;
                        end
                        8'd5 : 
                        begin
                            if (bRequest == SET_LINE_CODING) 
                            begin
                                s_interface_num[15:8] <= usb_rxdat;
                            end
                            else 
                                if (bRequest == SET_CONTROL_LINE_STATE) 
                                begin
                                    s_interface_num[15:8] <= usb_rxdat;
                                end
                        
                        
                            stage <= stage + 8'd1;
                            wIndex[15:8] <= usb_rxdat;
                        end
                        8'd6 : 
                        begin
                            if (bRequest == SET_LINE_CODING) 
                            begin
                                s_set_len[7:0] <= usb_rxdat;
                            end
                            else 
                                if (bRequest == GET_LINE_CODING) 
                                    begin
                                        s_set_len[7:0] <= usb_rxdat;
                                        if (s_interface_num == ENDPT_UART_DATA)
                                        begin
                                            endpt0_send <= 1'd1;
                                        end
                                    end
                                    else 
                                        if (bRequest == SET_CONTROL_LINE_STATE) 
                                        begin
                                            if (s_interface_num == ENDPT_UART_DATA)
                                            begin
                                                s_uart1_en <= s_ctl_sig[0];
                                            end
                                        end
                        
                            if ((bRequest == `GET_CUR)||(bRequest == `GET_DEF)
                               ||(bRequest == `GET_MIN)||(bRequest == `GET_MAX))
                            begin
                                if (wIndex[7:0] == 8'h01) 
                                begin //Video Steam Interface
                                    if (wValue[15:8] == `VS_PROBE_CONTROL) 
                                    begin
                                        endpt0_send <= 1'd1;
                                    end
                                end
                            end
                            wLength[7:0] <= usb_rxdat;
                            stage <= stage + 8'd1;
                        end
                        8'd7 : 
                        begin
                            if (bRequest == SET_LINE_CODING) 
                            begin
                                s_set_len[15:8] <= usb_rxdat;
                            end
                            else 
                                if (bRequest == GET_LINE_CODING) 
                                begin
                                    s_set_len[15:8] <= usb_rxdat;
                                    if (s_interface_num == ENDPT_UART_DATA)
                                    begin
                                        endpt0_send <= 1'd1;
                                        endpt0_dat <= s_dte1_rate[7:0];
                                    end
                                end                        
                        
                            wLength[15:8] <= usb_rxdat;
                            stage <= stage + 8'd1;
                            sub_stage <= 8'd0;
                        end
                    endcase
                end // end if(usb_rxval)
            end // end if(setup_active)
            else 
                if (bRequest == SET_LINE_CODING) 
                begin
                    stage <= 8'd0;
                    if ((usb_rxact)&&(endpt_sel ==ENDPT_UART_CONFIG)) 
                    begin
                        if (usb_rxval) 
                        begin
                            sub_stage <= sub_stage + 8'd1;
                            if(s_interface_num == ENDPT_UART_DATA)
                            begin
                                if (sub_stage <= 3) 
                                    s_dte1_rate <= {usb_rxdat,s_dte1_rate[31:8]};
                                else 
                                    if (sub_stage == 4) 
                                        s_char1_format <= usb_rxdat;
                                    else 
                                        if (sub_stage == 5) 
                                            s_parity1_type <= usb_rxdat;
                                        else 
                                            if (sub_stage == 6) 
                                                s_data1_bits <= usb_rxdat;
                            end // end if(s_interface_num == ENDPT_UART_DATA)
                        end // end if(usb_rxval)
                    end // end if(usb_rxact)&&(endpt_sel_ ==ENDPT_UART_CONFIG)
                end // end if(bRequest == SET_LINE_CODING)
                else 
                    if (bRequest == GET_LINE_CODING) 
                    begin
                        stage <= 8'd0;
//                        if ((usb_txact)&&(endpt_sel ==ENDPT_UART_CONFIG)) 
                        if ((endpt_sel ==ENDPT_UART_CONFIG)) 
                        begin
                            if (endpt0_send == 1'b1) 
                            begin
                                if (usb_txpop) 
                                begin
                                    sub_stage <= sub_stage + 8'd1;
                                end
                                if (bRequest == GET_LINE_CODING) 
                                begin

                                    if (usb_txpop) 
                                    begin// new controller version
                                        if(s_interface_num == ENDPT_UART_DATA)
                                        begin
                                            if (sub_stage <= 0) 
                                                endpt0_dat <= s_dte1_rate[15:8];
                                            else 
                                                if (sub_stage == 1) 
                                                    endpt0_dat <= s_dte1_rate[23:16];
                                                else 
                                                    if (sub_stage == 2) 
                                                        endpt0_dat <= s_dte1_rate[31:24];
                                                    else 
                                                        if (sub_stage == 3) 
                                                            endpt0_dat <= s_char1_format;
                                                        else 
                                                            if (sub_stage == 4) 
                                                                endpt0_dat <= s_parity1_type;
                                                            else 
                                                                if (sub_stage == 5) 
                                                                    endpt0_dat <= s_data1_bits;
                                                                else 
                                                                    endpt0_send <= 1'b0;
                                        end // end if(s_interface_num == ENDPT_UART_DATA)
                                    end // end if(usb_txpop)
                                end //  end if(bRequest == GET_LINE_CODING)
                            end // end if(endpt0_send == 1'b1)
                        end // end if((usb_txact)&&(endpt_sel ==ENDPT_UART_CONFIG)) 
                    end // end if(bRequest == GET_LINE_CODING)
                    else 
                    if (bRequest == `SET_CUR) 
                    begin
                        stage <= 8'd0;
                        if (wIndex[7:0] == 8'h01) 
                        begin
                            if (wValue[15:8] == `VS_PROBE_CONTROL) 
                            begin
                                if ((usb_rxact)&&(endpt_sel == 4'd0))
                                begin
                                    if (usb_rxval) 
                                    begin
                                        sub_stage <= sub_stage + 8'd1;
                                        case (sub_stage)
                                            8'd0 :
                                                bmHint[7:0] <= usb_rxdat;
                                            8'd1 :
                                                bmHint[15:8] <= usb_rxdat;
                                            8'd2 :
                                                bFormatIndex[7:0] <= usb_rxdat;
                                            8'd3 :
                                                bFrameIndex[7:0] <= usb_rxdat;
                                            8'd4 :
                                                dwFrameInterval[7:0]  <= usb_rxdat;
                                            8'd5 :
                                                dwFrameInterval[15:8] <= usb_rxdat;
                                            8'd6 :
                                                dwFrameInterval[23:16] <= usb_rxdat;
                                            8'd7 :
                                                dwFrameInterval[31:24] <= usb_rxdat;
                                            8'd8 :
                                                wKeyFrameRate[7:0] <= usb_rxdat;
                                            8'd9 :
                                                wKeyFrameRate[15:8] <= usb_rxdat;
                                            8'd10 :
                                                wPFrameRate[7:0] <= usb_rxdat;
                                            8'd11 :
                                                wPFrameRate[15:8]<= usb_rxdat;
                                            8'd12 :
                                                wCompQuality[7:0] <= usb_rxdat;
                                            8'd13 :
                                                wCompQuality[15:8] <= usb_rxdat;
                                            8'd14 :
                                                wCompWindowSize[7:0] <= usb_rxdat;
                                            8'd15 :
                                                wCompWindowSize[15:8] <= usb_rxdat;
                                            8'd16 :
                                                wDelay[7:0] <= usb_rxdat;
                                            8'd17 :
                                                wDelay[15:8] <= usb_rxdat;
                                            8'd18 :
                                                dwMaxVideoFrameSize[7:0]  <= usb_rxdat;
                                            8'd19 :
                                                dwMaxVideoFrameSize[15:8] <= usb_rxdat;
                                            8'd20 :
                                                dwMaxVideoFrameSize[23:16] <= usb_rxdat;
                                            8'd21 :
                                                dwMaxVideoFrameSize[31:24] <= usb_rxdat;
                                            8'd22 :
                                                ;//dwMaxPayloadTransferSize[7:0]  <= usb_rxdat;
                                            8'd23 :
                                                ;//dwMaxPayloadTransferSize[15:8] <= usb_rxdat;
                                            8'd24 :
                                                ;//dwMaxPayloadTransferSize[23:16] <= usb_rxdat;
                                            8'd25 :
                                                ;//dwMaxPayloadTransferSize[31:24] <= usb_rxdat;
                                            8'd26 :
                                                dwClockFrequency[7:0]  <= usb_rxdat;
                                            8'd27 :
                                                dwClockFrequency[15:8] <= usb_rxdat;
                                            8'd28 :
                                                dwClockFrequency[23:16] <= usb_rxdat;
                                            8'd29 :
                                                dwClockFrequency[31:24] <= usb_rxdat;
                                            8'd30 :
                                                bmFramingInfo[7:0] <= usb_rxdat;
                                            8'd31 :
                                                bPreferedVersion[7:0] <= usb_rxdat;
                                            8'd32 :
                                                bMinVersion[7:0] <= usb_rxdat;
                                            8'd33 :
                                                bMaxVersion[7:0] <= usb_rxdat;
                                            default : ;
                                        endcase
                                    end // if(usb_rxval)
                                end // if ((usb_rxact)&&(endpt_sel == 4'd0))
                                else 
                                begin
                                    sub_stage <= 8'd0;
                                end
                            end //if (wValue[15:8] == `VS_PROBE_CONTROL) 
                        end // if (wIndex[7:0] == 8'h01) 
                    end // if(bRequest == `SET_CUR) 
                    else 
                        if ((bRequest == `GET_CUR)||(bRequest == `GET_DEF)
                            ||(bRequest == `GET_MIN)||(bRequest == `GET_MAX))
                        begin
                            stage <= 8'd0;
                            if (wIndex[7:0] == 8'h01) 
                            begin
                                if (wValue[15:8] == `VS_PROBE_CONTROL) 
                                begin
                                    if ((usb_txact)&&(endpt_sel == 4'd0)) 
                                    begin
                                        if (endpt0_send == 1'b1) 
                                        begin
                                            if (usb_txpop) 
                                            begin
                                                sub_stage <= sub_stage + 8'd1;
                                                if (sub_stage == 12'd33) 
                                                begin
                                                    endpt0_send <= 1'd0;
                                                end
                                                case (sub_stage)
                                                    8'd0 :
                                                        endpt0_dat <= bmHint[15:8];
                                                    8'd1 :
                                                        endpt0_dat <= bFormatIndex[7:0];
                                                    8'd2 :
                                                        endpt0_dat <= bFrameIndex[7:0];
                                                    8'd3 :
                                                        endpt0_dat <= dwFrameInterval[7:0];
                                                    8'd4 :
                                                        endpt0_dat <= dwFrameInterval[15:8];
                                                    8'd5 :
                                                        endpt0_dat <= dwFrameInterval[23:16];
                                                    8'd6 :
                                                        endpt0_dat <= dwFrameInterval[31:24];
                                                    8'd7 :
                                                        endpt0_dat <= wKeyFrameRate[7:0];
                                                    8'd8 :
                                                        endpt0_dat <= wKeyFrameRate[15:8];
                                                    8'd9 :
                                                        endpt0_dat <= wPFrameRate[7:0];
                                                    8'd10 :
                                                        endpt0_dat <= wPFrameRate[15:8];
                                                    8'd11 :
                                                        endpt0_dat <= wCompQuality[7:0];
                                                    8'd12 :
                                                        endpt0_dat <= wCompQuality[15:8];
                                                    8'd13 :
                                                        endpt0_dat <= wCompWindowSize[7:0];
                                                    8'd14 :
                                                        endpt0_dat <= wCompWindowSize[15:8];
                                                    8'd15 :
                                                        endpt0_dat <= wDelay[7:0];
                                                    8'd16 :
                                                        endpt0_dat <= wDelay[15:8];
                                                    8'd17 :
                                                        endpt0_dat <= dwMaxVideoFrameSize[7:0];
                                                    8'd18 :
                                                        endpt0_dat <= dwMaxVideoFrameSize[15:8];
                                                    8'd19 :
                                                        endpt0_dat <= dwMaxVideoFrameSize[23:16];
                                                    8'd20 :
                                                        endpt0_dat <= dwMaxVideoFrameSize[31:24];
                                                    8'd21 :
                                                        endpt0_dat <= dwMaxPayloadTransferSize[7:0];
                                                    8'd22 :
                                                        endpt0_dat <= dwMaxPayloadTransferSize[15:8];
                                                    8'd23 :
                                                        endpt0_dat <= dwMaxPayloadTransferSize[23:16];
                                                    8'd24 :
                                                        endpt0_dat <= dwMaxPayloadTransferSize[31:24];
                                                    8'd25 :
                                                        endpt0_dat <= dwClockFrequency[7:0];
                                                    8'd26 :
                                                        endpt0_dat <= dwClockFrequency[15:8];
                                                    8'd27 :
                                                        endpt0_dat <= dwClockFrequency[23:16];
                                                    8'd28 :
                                                        endpt0_dat <= dwClockFrequency[31:24];
                                                    8'd29 :
                                                        endpt0_dat <= bmFramingInfo[7:0];
                                                    8'd30 :
                                                        endpt0_dat <= bPreferedVersion[7:0];
                                                    8'd31 :
                                                        endpt0_dat <= bMinVersion[7:0];
                                                    8'd32 :
                                                        endpt0_dat <=  bMaxVersion[7:0];
                                                    default : ;
                                                endcase
                                            end // if(usb_txpop)
                                            else 
                                                if (sub_stage == 8'd0) 
                                                begin
                                                    endpt0_dat <= bmHint[7:0];
                                                end
                                        end //(endpt0_send == 1'b1) 
                                    end //((usb_txact)&&(endpt_sel == 4'd0)) 
                                    else 
                                    begin
                                        sub_stage <= 8'd0;
                                    end
                                end //if (wValue[15:8] == `VS_PROBE_CONTROL)                                
                            end //if (wIndex[7:0] == 8'h01) 
                        end // if ((bRequest == `GET_CUR)||(bRequest == `GET_DEF))
                            //||(bRequest == `GET_MIN)||(bRequest == `GET_MAX))
                        else 
                        begin
                            stage <= 8'd0;
                            sub_stage <= 8'd0;
                        end
        end // if (~RESET_IN)

    reg [3:0] pState;
    reg [3:0] pState_next;

    localparam IDLE = 4'd1;
    localparam WAIT = 4'd2;
    localparam UNCORK = 4'd4;
    localparam TXACTIVE = 4'd8;

    always@(posedge pClk or posedge RESET_IN)
    begin
        if(RESET_IN)
            pState <= IDLE;
        else
            pState <= pState_next;
    end

    always@(*)
    begin
        pState_next <= pState;
        case(pState)
        IDLE  :
            if((endpt_sel == 0)||(endpt_sel == 2))
                pState_next <= UNCORK;
        UNCORK :
            if(usb_txact)
                pState_next <= TXACTIVE;
        TXACTIVE:
            if(~usb_txact)
                pState_next <= WAIT;
        endcase
        
        if(usb_sof)
            pState_next <= IDLE;
    end

    reg [10:0] pktByteCount;
    always@(posedge pClk)
        if(pState != TXACTIVE)
            pktByteCount <= 'd0;
        else
            if((usb_txpop)&&(endpt_sel == 4'd2))
                pktByteCount <= pktByteCount + 1'd1;

    reg [10:0] sofCounts;
    reg [31:0] pts_reg = 32'h55AA55AA;
    reg [7:0] pFrame;
    wire EOF = 1'd0;

    //160*144*2*60=2.7648MB/s
    //240*160*2*60=4.6080MB/s
    // 45 packets
    // each one every 125us = 5.625ms
    // 160*144*2 = 46080-(45*1012)=540+12=552

    parameter WIDTH             = 160;
    parameter HEIGHT            = 144;
    parameter BYTESPERFRAME     = WIDTH*HEIGHT*3;
    parameter PACKETSPERFRAME   = BYTESPERFRAME/1012;
    parameter REMAINDERBYTES    = 12+(BYTESPERFRAME-(PACKETSPERFRAME*1012));
    // 160*144*2 = 46080-(45*1012)=540+12=552

    reg pLastPacket;
    reg pLastReadActive;
    always@(posedge pClk or posedge RESET_IN)
        if(RESET_IN)
            pFrame <= 8'h8C;
        else
            if((pState==TXACTIVE)&&(~usb_txact)&&pLastPacket&&pLastReadActive)
                pFrame <= {pFrame[7:1],pFrame[0]^1'b1};

    reg hLineValid_r1;
    always@(posedge hClk)
        hLineValid_r1 <= hLineValid;

    reg hFrameValid_r1;
    always@(posedge hClk)
        hFrameValid_r1 <= hFrameValid;

    // 60MHz phy clkout
    reg [9:0] hCountX;
    reg [9:0] hCountY;
    
    reg hImage_eof;
    
    reg [2:0] hCount3;
    always@(posedge hClk)
        if(~hEnable)
            hCount3 <= 'd0;
        else
        begin
            if(hCount3 < 2)
                hCount3 <= hCount3 + 1'd1;
            else
                hCount3 <= 'd0;
        end
        
    wire hEnable2 = ((hCount3 == 2)&&(hCountX < 160))&&hEnable;
    wire hEnable1 = ((hCount3 == 1)&&(hCountX < 160))&&hEnable;
    wire hEnable0 = ((hCount3 == 0)&&(hCountX < 160))&&hEnable;
    
    reg [1:0] phase;

    always@(posedge hClk)
        if(hFrameValid & ~hFrameValid_r1)
        begin
            hCountX <= 'd0;
            hCountY <= 'd0;
            hImage_eof <= 'd0;
        end
        else
        begin
            hImage_eof <= 'd0;
            if(hEnable)
            begin
//                if(hEnable2)
                if(hCount3 == 2)
                    hCountX <= hCountX + 1'd1;
            end
            else
            begin
                if(hEnable_r1)
                begin
                    hCountY <= hCountY + 'd1;
                    if(hCountY == 143)
                        hImage_eof <= 1'd1;
                    hCountX <= 'd0;
                end
            end
        end
    
    reg pReadActive;
    wire pReadEnable = (endpt_sel == 4'd2) && (pktByteCount >= 11'd11)&& (pktByteCount < 11'd1023);

    wire fifo_rden = pReadActive && usb_txpop && (endpt_sel == 4'd2) && pReadEnable;
    wire fifo_rden2 = pReadActive && usb_txpop && (endpt_sel == 4'd2) && (pktByteCount > 11'd11);

    reg [4:0] pEnable_sr;
    always@(posedge pClk)
        pEnable_sr <= {pEnable_sr[3:0], hEnable};

    wire pImage_sol = pEnable_sr[4:2] == 3'b001;
    wire pImage_eol = pEnable_sr[4:2] == 3'b110;

    reg [4:0] pFrameValid_sr;
    always@(posedge pClk)
        pFrameValid_sr <= {pFrameValid_sr[3:0], hFrameValid};

    wire pImage_sof = pFrameValid_sr[4:2] == 3'b001;

    reg [7:0] fram [4095:0];
    wire [7:0] pRam_q;
    reg [11:0] pRam_ra;
    reg [11:0] hRam_wa;
    reg [12:0] pRamCount;
    
    
    reg hEnable_r1;
    always@(posedge hClk)
        hEnable_r1  <= hEnable;
    
    always@(posedge hClk)
        if(~hFrameValid_r1&hFrameValid)
            hRam_wa     <= 'd0;
        else
            if(hEnable0 | hEnable1 | hEnable2)
                hRam_wa <= hRam_wa + 'd1;

    reg [17:0] hData_r1;
    always@(posedge hClk)
    begin
        hData_r1 <= hData;
    end


    wire [7:0] R = {hData[17:13],3'd0};
    wire [7:0] G = {hData[11:7],3'd0};
    wire [7:0] B = {hData[5:1],3'd0};

    wire [7:0] Y; // 8-bit output for Luma component
    wire [7:0] Cb; // 8-bit output for Chroma Blue component
    wire [7:0] Cr; // 8-bit output for Chroma Red component

    rgb_to_ycbcr_pipeline u_rgb_to_ycbcr_pipeline(
        .clk(hClk),
        .R(R),
        .G(G),
        .B(B),
        .Y(Y),
        .Cb(Cb),
        .Cr(Cr)
    );

    //{hData_r1[8:6], hData_r1[17:13]} : {hData_r1[5:1], hData_r1[11:9]}; -- RGB565
    wire [7:0] fram_d = hEnable0 ? {hData[17:12], 2'd0} : 
                        hEnable1 ? {hData[11:6], 2'd0} :
                        {hData[5:0], 2'd0};

    always@(posedge hClk)
        if(hEnable0 | hEnable1 | hEnable2)
            fram[hRam_wa] <= fram_d;

    reg pRamOverflow;
    always@(posedge pClk)
    begin
        if(pImage_sof)
        begin
            pRam_ra    <= 'd0;
            pRamCount  <= 'd0;
            pRamOverflow <= 'd0;
        end
        else
        begin
            if(pRamCount > 4095)
                pRamOverflow <= 1'd1;
                
            if(fifo_rden)
                pRam_ra <= pRam_ra + 1'd1;

            if(pImage_eol)
            begin
                if(~fifo_rden2)
                    pRamCount <= pRamCount + 'd480;// 4/22 'd320;
                else
                    pRamCount <= pRamCount + 'd479;// 4/22 'd319;
            end
            else
                if(fifo_rden2)
                    pRamCount <= pRamCount - 1'd1;
        end
    end

    assign pRam_q = fram[pRam_ra];

    always@(posedge pClk)
    begin
        if(usb_sof)
            pUvcPacketData <= 8'h0C; // Header length
        else
        if(usb_txpop)
        case(pktByteCount)
            10'd0:
            begin
                if(pLastPacket&&pLastReadActive)
                    pUvcPacketData <= pFrame | 8'h02;
                else
                    pUvcPacketData <= pFrame;
            end
            10'd1 : pUvcPacketData <= pts_reg[7:0];
            10'd2 : pUvcPacketData <= pts_reg[15:8];
            10'd3 : pUvcPacketData <= pts_reg[23:16];
            10'd4 : pUvcPacketData <= pts_reg[31:24];
            10'd5 : pUvcPacketData <= pts_reg[7:0];
            10'd6 : pUvcPacketData <= pts_reg[15:8];
            10'd7 : pUvcPacketData <= pts_reg[23:16];
            10'd8 : pUvcPacketData <= pts_reg[31:24];
            10'd9 : pUvcPacketData <= sofCounts[7:0];
            10'd10 : pUvcPacketData <= {5'd0,sofCounts[10:8]};
            default : 
            begin
                if(pktByteCount >= pTxDataLength - 1)
                    pUvcPacketData <= 8'h0C;
                else
                    pUvcPacketData <= pRam_q;
            end
        endcase
    end

    reg sof_d0;
    reg sof_d1;
    wire sof_rise;
    always @(posedge pClk or posedge RESET_IN) begin
        if (RESET_IN) begin
            sof_d0 <= 1'b0;
            sof_d1 <= 1'b0;
        end
        else begin
            sof_d0 <= usb_sof;
            sof_d1 <= sof_d0;
        end
    end
    assign sof_rise = (sof_d0)&(~sof_d1);

    reg [10:0] sofCounts_reg;
    reg [3:0] sof_1ms;
    always @(posedge pClk or posedge RESET_IN) begin
        if (RESET_IN) begin
            sofCounts <= 11'd0;
            sof_1ms <= 4'd0;
        end
        else begin
            if (sof_rise) begin
                if (sof_1ms >= 4'd7) begin
                    sof_1ms <= 4'd0;
                end
                else begin
                    sof_1ms <= sof_1ms + 4'd1;
                end
            end
            if ((sof_rise)&&(sof_1ms == 3'd7)) begin
                sofCounts <= sofCounts + 'd1;
            end
        end
    end

    reg [3:0] pImage_eof_sr;
    wire pImage_eof = pImage_eof_sr[3:2] == 2'b01;
    always@(posedge pClk)
        pImage_eof_sr <= {pImage_eof_sr[2:0], hImage_eof};
    
    reg [11:0] pTxReadBytesLength;
    always@(posedge pClk)
    begin
        if(pImage_eof)
            pLastPacket <= 1'd1;
        else
            if(pImage_sof)
            begin
                pLastPacket     <=  1'd0;
                pReadActive     <=  1'd0;
                pLastReadActive <=  1'd0;
            end
            else
                if((pState==TXACTIVE)&&(~usb_txact)&&pLastPacket&&pLastReadActive)
                begin
                    pLastPacket     <=  1'd0;
                    pLastReadActive <=  1'd0;
                    pReadActive     <=  1'd0;
                end
        
        if(usb_sof)
        begin
            if(pRamCount >= 1012)
            begin
            // Header + payload
                pTxReadBytesLength <= 12'd1024;
                pReadActive     <= 1'd1;
            end
            else
            begin
                if(pLastPacket)
                begin
                    // Remainder packet
                    pTxReadBytesLength <= pRamCount + 12'd12;
                    pReadActive     <= 1'd1;
                    pLastReadActive <= 1'd1;
                end
                else
                begin
                    // Just the header
                    pTxReadBytesLength <= 12'd12;
                    pReadActive     <= 1'd0;
                end
            end
        end
    end
    
    assign debugs = {
        pLastReadActive,
        hFrameValid,
        hEnable,
        pImage_sof,
        pReadActive,
        pState==TXACTIVE ? 1'b1 : 1'b0,
        usb_sof,
        pLastPacket
    };
    
    
    always@(posedge pClk, posedge RESET_IN) begin
        if (RESET_IN) begin
            pTxDataLength <= 12'd34;
            pTxCork <= 1'b0;
        end
        else 
            if (~usb_txact) 
            begin
                case(endpt_sel)
                4'd0:
                begin
                    pTxDataLength <= 12'd7;
//                    pTxDataLength <= 12'd34; //Read FIFO Data Bytes Count
                    pTxCork <= 1'b0;
                end
                4'd2:
                begin
                    case(pState)
                        TXACTIVE:
                        begin
                            if(usb_txact)
                            begin
                                pTxDataLength <= pTxReadBytesLength;
                                pTxCork <= 1'b0;
                            end
                            else
                                if(pLastPacket)
                                begin
                                    pTxDataLength <= 12'd0;
                                    pTxCork <= 1'b1;
                                end
                        end
                        UNCORK:
                        begin
                            pTxCork <= 1'b0;
                            pTxDataLength <= pTxReadBytesLength;
                        end
                    endcase
                end
                
                4'd3:
                begin
                    pTxCork         <= ep_usb_txcork;
                    pTxDataLength   <= ep_usb_txlen;
                end
                
                default :
                begin
                    pTxDataLength <= 12'd0;
                    pTxCork <= 1'b1;
                end
                endcase
            end
            else
            begin
                if (endpt_sel == 0)
                begin
                    pTxDataLength <= 12'd7;
                    pTxCork <= 1'b0;
                end
            end
        end

    //==============================================================
    //======UART
    wire [15:0] uart_tx_data    ;
    wire        uart_tx_data_val;
    wire        uart_tx_busy    ;
    wire [15:0] uart_rx_data    ;
    wire        uart_rx_data_val;
    
    
    //assign uart_rxd = uart_txd;
    assign uart_cts = 1'b0;
    wire        ep3_rx_dval;
    wire [7:0]  ep3_rx_data;
    assign uart_tx_data     = {8'd0,ep3_rx_data};
    assign uart_tx_data_val = ep3_rx_dval;
    UART  #(
        .CLK_FREQ     (30'd60000000)  // set system clock frequency in Hz
    )u_UART
    (
         .CLK        (pClk                )// clock
        ,.RST        (usb_busreset | ERST            )// reset
        ,.UART_TXD   (UART_TXD            )//output
        ,.UART_RXD   (UART_RXD            )//input
        ,.UART_RTS   (                    )// when UART_RTS = 0, UART This Device Ready to receive.
        ,.UART_CTS   (1'd0                )// when UART_CTS = 0, UART Opposite Device Ready to receive.
        ,.BAUD_RATE  (uart_dte_rate       )
        ,.PARITY_BIT (uart_parity_type    )
        ,.STOP_BIT   (uart_char_format    )
        ,.DATA_BITS  (uart_data_bits      )
        ,.TX_DATA    (uart_tx_data        ) //
        ,.TX_DATA_VAL(uart_tx_data_val    ) // when TX_DATA_VAL = 1, data on TX_DATA will be transmit, DATA_SEND can set to 1 only when BUSY = 0
        ,.TX_BUSY    (uart_tx_busy        ) // when BUSY = 1 transiever is busy, you must not set DATA_SEND to 1
        ,.RX_DATA    (uart_rx_data        ) //
        ,.RX_DATA_VAL(uart_rx_data_val    ) //
    );

    //==============================================================
    //======FIFO
//    assign usb_txcork    = (endpt_sel ==ENDPT_UART_CONFIG) ? 1'b0 : ep_usb_txcork;
//    assign usb_txdat_len = (endpt_sel ==ENDPT_UART_CONFIG) ? 12'd7 : ep_usb_txlen;

    usb_fifo usb_fifo
    (
         .i_clk         (pClk   )//clock
        ,.i_reset       (usb_busreset | ERST )//reset
        ,.i_usb_endpt   (endpt_sel    )
        ,.i_usb_rxact   (usb_rxact    )
        ,.i_usb_rxval   (usb_rxval    )
        ,.i_usb_rxpktval(usb_rxpktval )
        ,.i_usb_rxdat   (usb_rxdat    )
        ,.o_usb_rxrdy   (ep_usb_rxrdy )
        ,.i_usb_txact   (usb_txact    )
        ,.i_usb_txpop   (usb_txpop    )
        ,.i_usb_txpktfin(usb_txpktfin )
        ,.o_usb_txcork  (ep_usb_txcork)
        ,.o_usb_txlen   (ep_usb_txlen )
        ,.o_usb_txdat   (ep_usb_txdat )
        //Endpoint 3
        ,.i_ep3_tx_clk  (pClk             )
        ,.i_ep3_tx_max  (12'd64           )
        ,.i_ep3_tx_dval (uart_rx_data_val )
        ,.i_ep3_tx_data (uart_rx_data[7:0])
        ,.i_ep3_rx_clk  (pClk             )
        ,.i_ep3_rx_rdy  (!uart_tx_busy    )
        ,.o_ep3_rx_dval (ep3_rx_dval      )
        ,.o_ep3_rx_data (ep3_rx_data      )
    );

    assign    E_UART_DTR = s_ctl_sig[0];
    assign    E_UART_RTS = s_ctl_sig[1];

endmodule


module rgb_to_ycbcr_pipeline (
    input clk, // Clock input
    input [7:0] R, // 5-bit input for Red component
    input [7:0] G, // 5-bit input for Green component
    input [7:0] B, // 5-bit input for Blue component
    output [7:0] Y, // 8-bit output for Luma component
    output [7:0] Cb, // 8-bit output for Chroma Blue component
    output [7:0] Cr // 8-bit output for Chroma Red component
);

    reg [14:0] YR_stage1;
    reg [15:0] YG_stage1;
    reg [12:0] YB_stage1;

    reg signed [15:0] CbR_stage1;
    reg signed [15:0] CbG_stage1;
    reg [14:0] CbB_stage1;

    reg [14:0] CrR_stage1;
    reg signed [15:0] CrG_stage1;
    reg signed [13:0] CrB_stage1;

    reg [15:0] Y_stage1;
    reg signed [15:0] Cb_stage1;
    reg signed [15:0] Cr_stage1;

    reg [12:0] Y_stage2;
    reg signed [12:0] Cb_stage2;
    reg signed [12:0] Cr_stage2;

    // Stage 1: Calculate partial multiplication sums for R, G, and B
    always @(posedge clk) begin
        YR_stage1 <= 66 * R;
        YG_stage1 <= 129 * G;
        YB_stage1 <= 25 * B;

        CbR_stage1 <= $signed(-38) * $signed({1'd0,R});
        CbG_stage1 <= $signed(-74) * $signed({1'd0,G});
        CbB_stage1 <= 112 * B;
        
        CrR_stage1 <= 112 * R;
        CrG_stage1 <= $signed(-94) * $signed({1'd0,G});
        CrB_stage1 <= $signed(-18) * $signed({1'd0,B});    
    end

    // Stage 2: Accumulate partial sums for Y, Cb, and Cr
    always @(posedge clk) begin
        Y_stage1 <= YR_stage1 + YG_stage1 + YB_stage1 + 'd16;
        Cb_stage1 <= CbR_stage1 + CbG_stage1 + $signed({1'd0,CbB_stage1}) + $signed({1'd0,8'd128});
        Cr_stage1 <= $signed({1'd0,CrR_stage1}) + CrG_stage1 + CrB_stage1 + $signed({1'd0,8'd128});
    end

    // Stage 3: Perform right shifts for Y, Cb, and Cr
    always @(posedge clk) begin
        Y_stage2 <= Y_stage1[15:8] + 'd16;
        Cb_stage2 <= $signed(Cb_stage1[15:8]) + $signed({1'd0,8'd128});
        Cr_stage2 <= $signed(Cr_stage1[15:8]) + $signed({1'd0,8'd128});
    end

    wire [7:0] YO = Y_stage2[7:0];
    wire [7:0] CbO = Cb_stage2[7:0];
    wire [7:0] CrO = Cr_stage2[7:0];

    assign Y    = YO > 235 ? 235 : YO < 16 ? 16 : YO;
    assign Cb   = CbO > 240 ? 240 : CbO < 16 ? 16 : CbO;
    assign Cr   = CrO > 240 ? 240 : CrO < 16 ? 16 : CrO;

endmodule
