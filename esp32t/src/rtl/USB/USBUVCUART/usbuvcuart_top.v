// usbuvc_top.v

`include "usb_video/usb_defs.v"
`include "usb_video/uvc_defs.v"
`include "usb_video/uac_defs.v"

`define UART_BASE_IFACE  8'd2
`define UART_CTRL_IFACE  (`UART_BASE_IFACE)
`define UART_DATA_IFACE  (`UART_BASE_IFACE + 1)

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

    input [15:0]        left,
    input [15:0]        right,

    output  [7:0]       debugs,
    inout               usb_dxp_io,
    inout               usb_dxn_io,
    input               usb_rxdp_i,
    input               usb_rxdn_i,
    output              usb_pullup_en_o,
    inout               usb_term_dp_io,
    inout               usb_term_dn_io
);

    wire yLineValid;
    wire yEnable;
    wire yFrameValid;

    wire [7:0] PHY_DATAOUT;
    wire       PHY_TXVALID;
    wire [1:0] PHY_XCVRSELECT;
    wire [7:0] PHY_DATAIN;
    wire [1:0] PHY_LINESTATE;
    wire [1:0] PHY_OPMODE;

    wire        uart_rxrdy;
    wire        uart_txcork;
    wire [11:0] uart_txdat_len;
    wire [7:0]  uart_txdat;

    wire usb_busreset;
    wire usb_highspeed;
    wire usb_suspend;
    wire usb_online;
    wire usb_rxpktval;
    wire usb_sof;
    wire sof_rise;

    wire PHY_TXREADY;
    wire PHY_RXACTIVE;
    wire PHY_RXVALID;
    wire PHY_RXERROR;
    wire PHY_TERMSELECT;
    wire PHY_RESET;

    wire [7:0]  usb_txdat;
    wire        usb_txval;
    wire [11:0] usb_txdat_len;
    wire        usb_txcork;
    wire        usb_txpop;
    wire        usb_txact;
    wire        usb_txpktfin;
    wire [7:0]  usb_rxdat;
    wire        usb_rxact;
    wire        usb_rxval;
    wire        usb_rxrdy;
    reg  [7:0]  rst_cnt;
    wire [3:0]  endpt_sel;
    wire        setup_active;
    wire        setup_val;
    wire [7:0]  setup_data;
    wire        fclk_960M;

    wire [15:0] DESCROM_RADDR       ;
    wire [7:0]  DESCROM_RDAT        ;
    wire [15:0] DESC_DEV_ADDR       ;
    wire [15:0] DESC_DEV_LEN        ;
    wire [15:0] DESC_QUAL_ADDR      ;
    wire [15:0] DESC_QUAL_LEN       ;
    wire [15:0] DESC_FSCFG_ADDR     ;
    wire [15:0] DESC_FSCFG_LEN      ;
    wire [15:0] DESC_HSCFG_ADDR     ;
    wire [15:0] DESC_HSCFG_LEN      ;
    wire [15:0] DESC_OSCFG_ADDR     ;
    wire [15:0] DESC_STRLANG_ADDR   ;
    wire [15:0] DESC_STRVENDOR_ADDR ;
    wire [15:0] DESC_STRVENDOR_LEN  ;
    wire [15:0] DESC_STRPRODUCT_ADDR;
    wire [15:0] DESC_STRPRODUCT_LEN ;
    wire [15:0] DESC_STRSERIAL_ADDR ;
    wire [15:0] DESC_STRSERIAL_LEN  ;
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
    wire   RESET_N = pll_locked&~ERST;

    //==============================================================
    //      Synchronous reset, should be long enough to be reliably
    //      detected for 2 hClk
    localparam RESET_LEN = 32;
    assign RESET_IN = rst_cnt < RESET_LEN;
    always@(posedge pClk, negedge RESET_N) begin
        if (!RESET_N) begin
            rst_cnt <= 8'd0;
        end
        else if (rst_cnt < RESET_LEN) begin
            rst_cnt <= rst_cnt + 8'd1;
        end
    end

    //==============================================================
    //======UVC pFrame Data

    wire [11:0] uvc_txlen;
    wire [7:0] frame_data;
    wire [7:0] endpt0_dat;
    wire [11:0] endpt0_txlen;
    wire        endpt0_send;

    reg [7:0]   video_txdat;
    reg [11:0]  video_txdat_len;
    reg         video_txcork;

    reg [7:0]   audio_txdat;
    reg [11:0]  audio_txdat_len;
    reg         audio_txcork;

    localparam EP_CTRL = 4'd0;
    localparam EP_VC = 4'd1;
    localparam EP_VS = 4'd2;
    localparam EP_UART = 4'd3;
    localparam EP_UAC = {`AUDIO_DATA_EP_NUM}[3:0];

    wire        cuart_txval;
    wire [ 7:0] cuart_txdat;
    wire [11:0] cuart_txdat_len;

    wire        cuvc_txval;
    wire [ 7:0] cuvc_txdat;
    wire [11:0] cuvc_txdat_len;

    wire        cuac_txval;
    wire [ 7:0] cuac_txdat;
    wire [11:0] cuac_txdat_len;

    assign endpt0_dat = cuart_txval ? cuart_txdat :
                        cuvc_txval ? cuvc_txdat :
                        cuac_txval ? cuac_txdat :
                        8'd0;
    assign endpt0_txlen = cuart_txval ? cuart_txdat_len :
                        cuvc_txval ? cuvc_txdat_len :
                        cuac_txval ? cuac_txdat_len :
                        12'd0;
    /* Right, assuming endpt_sel cannot change during transfer,
     * mux functions signals onto USB Device Controller */
    /* signals to Device Controller from EPs*/
    assign usb_txdat = (endpt_sel == EP_CTRL) ? endpt0_dat[7:0] :
                       (endpt_sel == EP_VS) ? video_txdat  :
                       (endpt_sel == EP_UAC) ? audio_txdat :
                       uart_txdat;
    /* only valid for ep0 */
    assign endpt0_send = cuart_txval | cuvc_txval | cuac_txval;
    assign usb_txval = (endpt_sel == EP_CTRL) ? endpt0_send : 1'b0;

    assign usb_txdat_len = (endpt_sel == EP_CTRL) ? endpt0_txlen :
                           (endpt_sel == EP_VS) ? video_txdat_len :
                           (endpt_sel == EP_UART) ? uart_txdat_len :
                           (endpt_sel == EP_UAC) ? audio_txdat_len :
                           12'hFAE;

    assign usb_txcork = (endpt_sel == EP_CTRL) ? 1'b0 :
                        (endpt_sel == EP_VS) ? video_txcork :
                        (endpt_sel == EP_UART) ? uart_txcork :
                        (endpt_sel == EP_UAC) ? audio_txcork :
                        1'b1;

    assign usb_rxrdy = (endpt_sel == EP_UART) ? uart_rxrdy :
                       (endpt_sel == EP_CTRL) ? 1'b1 : 1'b0;

    /* TODO: txiso_pid_i(iso_pid_data) shall be per endpoint, but so far
       we need only 1 packet/microframe on each EP */

    /* signals from Device Controller to EPs*/
    wire video_txact = (endpt_sel == EP_VS) ? usb_txact : 0;
    wire audio_txact = (endpt_sel == EP_UAC) ? usb_txact : 0;
    wire uart_txact = (endpt_sel == EP_UART) ? usb_txact : 0;

    wire video_txpop = (endpt_sel == EP_VS) ? usb_txpop : 0;
    wire audio_txpop = (endpt_sel == EP_UAC) ? usb_txpop : 0;
    wire uart_txpop = (endpt_sel == EP_UART) ? usb_txpop : 0;

    wire uart_rxact = (endpt_sel == EP_UART) ? usb_rxact : 0;

    wire uart_rxval = (endpt_sel == EP_UART) ? usb_rxval : 0;

    usbuac_ep audio_ep(
        .rst(RESET_IN),
        .pClk(pClk),
        .usb_sof_rise(sof_rise),
        .gClk(hClk),
        .left(left),
        .right(right),
        .uac_txpop(audio_txpop),
        .uac_txact(audio_txact),
        .uac_txdat(audio_txdat),
        .uac_txdat_len(audio_txdat_len),
        .uac_txcork(audio_txcork));

    wire uvc_fifo_afull;
    wire uvc_fifo_aempty;
    wire [12:0] uvc_fifo_rnum;

    /* This is for video EP only */
    reg v_txact_d0;
    reg v_txact_d1;
    wire v_txact_rise;
    wire v_txact_fall;
    assign v_txact_rise = v_txact_d0&(~v_txact_d1);
    assign v_txact_fall = v_txact_d1&(~v_txact_d0);
    always @(posedge pClk) begin
        if (RESET_IN) begin
            v_txact_d0 <= 1'b0;
            v_txact_d1 <= 1'b0;
        end
        else begin
            v_txact_d0 <= video_txact;
            v_txact_d1 <= v_txact_d0;
        end
    end

    /* TODO:
     * Rest of the code assumes HSSUPPORT is on and one packet per MFRAME
     */
    `define HSSUPPORT
    //`define MFRAME_PACKETS3
    //`define MFRAME_PACKETS2
    reg [3:0] iso_pid_data;
    always @(posedge pClk) begin
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
                        if (uvc_fifo_afull) begin
                            iso_pid_data <= 4'b0111;//DATA2
                        end
                        else if (uvc_fifo_aempty) begin
                            iso_pid_data <= 4'b0011;//DATA0
                        end
                        else begin
                            iso_pid_data <= 4'b1011;//DATA1
                        end
                        //iso_pid_data <= 4'b0111;//DATA2
                    end
                    else if (v_txact_fall) begin
                        iso_pid_data <= (iso_pid_data == 4'b0111) ? 4'b1011 : ((iso_pid_data == 4'b1011) ? 4'b0011 : iso_pid_data);//DATA2(0111) -> DATA1(1011) -> DATA0(0011)
                    end
                `elsif MFRAME_PACKETS2
                    if (usb_sof) begin
                        if (uvc_fifo_afull) begin
                            iso_pid_data <= 4'b0111;//DATA2
                        end
                        else if (uvc_fifo_aempty) begin
                            iso_pid_data <= 4'b0011;//DATA0
                        end
                        else begin
                            iso_pid_data <= 4'b1011;//DATA1
                        end
                        iso_pid_data <= 4'b0111;//DATA2
                    end
                    else if (v_txact_fall)) begin
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

    /* Handle Set Interface for sub-blocks */
    wire [7:0] interface_alter_i;
    wire [7:0] interface_alter_o;
    wire [7:0] interface_sel;
    wire       interface_update;

    wire [7:0] uart_iface_alter;
    wire [7:0] uvc_iface_alter;
    wire [7:0] uac_iface_alter;

    interface_alt_select uart_interface(
        .RESET_IN(RESET_IN),
        .pClk(pClk),
        .interface_update(interface_update & (interface_sel == `UART_DATA_IFACE)),
        .interface_alter_i(interface_alter_o),
        .interface_alter_o(uart_iface_alter)
    );

    interface_alt_select uvc_interface(
        .RESET_IN(RESET_IN),
        .pClk(pClk),
        .interface_update(interface_update & (interface_sel == `UVC_VS_INTERFACE)),
        .interface_alter_i(interface_alter_o),
        .interface_alter_o(uvc_iface_alter)
    );

    interface_alt_select uac_interface(
        .RESET_IN(RESET_IN),
        .pClk(pClk),
        .interface_update(interface_update & (interface_sel == `UAC_AS_INTERFACE)),
        .interface_alter_i(interface_alter_o),
        .interface_alter_o(uac_iface_alter)
    );

    assign interface_alter_i =
        (interface_sel == `UART_DATA_IFACE) ?  uart_iface_alter :
        (interface_sel == `UVC_VS_INTERFACE) ?  uvc_iface_alter :
        (interface_sel == `UAC_AS_INTERFACE) ?  uac_iface_alter :
        8'd0;

    USB_Device_Controller_Top u_usb_device_controller_top (
             .clk_i                 (pClk          )
            ,.reset_i               (RESET_IN            )
            ,.usbrst_o              (usb_busreset        )
            ,.highspeed_o           (usb_highspeed       )
            ,.suspend_o             (usb_suspend         )
            ,.online_o              (usb_online          )
            ,.txdat_i             (usb_txdat)
            ,.txval_i             (usb_txval           )
            ,.txdat_len_i         (usb_txdat_len)
            ,.txiso_pid_i         (iso_pid_data        )
            ,.txcork_i            (usb_txcork)
            ,.txpop_o             (usb_txpop           )
            ,.txact_o             (usb_txact           )
            ,.txpktfin_o          (usb_txpktfin        )
            ,.rxdat_o             (usb_rxdat           )
            ,.rxval_o             (usb_rxval           )
            ,.rxact_o             (usb_rxact           )
            ,.rxrdy_i             (usb_rxrdy           )
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

            ,.desc_bos_addr_i(16'd0)
            ,.desc_bos_len_i(16'd0)
            ,.desc_hidrpt_addr_i(16'd0)
            ,.desc_hidrpt_len_i(16'd0)
            ,.desc_index_o()
            ,.desc_type_o()

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

    wire [63:0] serial;
    //==============================================================
    //======USB Device descriptor Demo
    usb_desc
    #(

             .VENDORID    (16'h374E)
            ,.PRODUCTID   (16'h013f)
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
        ,.rst_i            (PHY_RESET | RESET_IN)
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

    reg  [ 7:0] bmRequestType; ///< Specifies direction of dataflow, type of rquest and recipient
    reg  [ 7:0] bRequest     ; ///< Specifies the request
    reg  [15:0] wValue       ; ///< Host can use this to pass info to the device in its own way
    reg  [15:0] wIndex       ; ///< Typically used to pass index/offset such as interface or EP no
    reg  [15:0] wLength      ; ///< Number of data bytes in the data stage (for Host -> Device this this is exact count, for Dev->Host is a max)


    wire [ 1:0] s_ctl_sig;
    wire [31:0] s_dte1_rate;
    wire [ 7:0] s_char1_format;
    wire [ 7:0] s_parity1_type;
    wire [ 7:0] s_data1_bits;

    wire [31:0] uart_dte_rate = s_dte1_rate;
    wire [7:0]  uart_char_format = s_char1_format;
    wire [7:0]  uart_parity_type = s_parity1_type;
    wire [7:0]  uart_data_bits = s_data1_bits;

    reg [2:0] hdr_len; /* Control header offset, also indicates header ready */
    reg [15:0] cdata_ofs;
    reg cdata_rxtx; /* Need to handle RX/TX after control request */
    reg cdata_phase_active; /* data phase of control request is active */

    wire header_ready = (hdr_len == 3'd7);

    wire [15:0] clength = {usb_rxdat, wLength[7:0]};

    always @(posedge pClk)
        if (RESET_IN) begin
            hdr_len <= 0;
            cdata_rxtx <= 0;
            cdata_phase_active <= 0;
        end else begin
            if (setup_active) begin
                if (usb_rxval) begin
                    if (~header_ready)
                        hdr_len <= hdr_len + 3'd1;
                    case (hdr_len)
                    8'd0 : begin
                        bmRequestType <= usb_rxdat;
                        cdata_rxtx <= 0;
                        cdata_phase_active <= 0;
                        cdata_ofs <= 16'd0;
                    end
                    8'd1 : bRequest <= usb_rxdat;
                    8'd2 : wValue[7:0] <= usb_rxdat;
                    8'd3 : wValue[15:8] <= usb_rxdat;
                    8'd4 : wIndex[7:0] <= usb_rxdat;
                    8'd5 : wIndex[15:8] <= usb_rxdat;
                    8'd6 : wLength[7:0] <= usb_rxdat;
                    8'd7 : begin
                        wLength[15:8] <= usb_rxdat;
                        cdata_phase_active <= 1'b0;
                        cdata_rxtx <= clength != 16'd0;
                    end
                    endcase
                end
            end else if (header_ready && (endpt_sel == EP_CTRL)) begin
                if (cdata_rxtx) begin
                    if ((usb_rxact && usb_rxval)
                            || (usb_txact && usb_txpop)) begin
                        cdata_ofs <= cdata_ofs + 16'd1;
                    end
                    if (usb_rxact || usb_txact) begin
                        cdata_phase_active <= 1'b1;
                    end else if (cdata_phase_active) begin
                        cdata_phase_active <= 1'b0;
                        cdata_rxtx <= 1'b0;
                        hdr_len <= 3'd0;
                    end
                end else
                    hdr_len <= 3'd0;
            end
        end // if (~RESET_IN)

    ctrl_uart uart_if_ctrl(
        .RESET_IN(RESET_IN),
        .pClk(pClk),
        .header_ready(header_ready),
        .bmRequestType(bmRequestType),
        .bRequest(bRequest),
        .wValue(wValue),
        .wIndex(wIndex),
        .wLength(wLength),
        .cdata_ofs(cdata_ofs),
        .usb_rxdat(usb_rxdat),
        .usb_rxact(usb_rxact),
        .usb_rxval(usb_rxval),
        .usb_txpop(usb_txpop),
        .usb_txval(cuart_txval),
        .usb_txdat_len(cuart_txdat_len),
        .usb_txdat(cuart_txdat),
        .s_ctl_sig(s_ctl_sig),
        .s_dte1_rate(s_dte1_rate),
        .s_char1_format(s_char1_format),
        .s_parity1_type(s_parity1_type),
        .s_data1_bits(s_data1_bits));

    ctrl_uvc uvc_if_ctrl(
        .RESET_IN(RESET_IN),
        .pClk(pClk),
        .header_ready(header_ready),
        .bmRequestType(bmRequestType),
        .bRequest(bRequest),
        .wValue(wValue),
        .wIndex(wIndex),
        .wLength(wLength),
        .cdata_ofs(cdata_ofs),
        .usb_rxdat(usb_rxdat),
        .usb_rxact(usb_rxact),
        .usb_rxval(usb_rxval),
        .usb_txpop(usb_txpop),
        .usb_txval(cuvc_txval),
        .usb_txdat_len(cuvc_txdat_len),
        .usb_txdat(cuvc_txdat),
        .bmHint(),
        .bFormatIndex(),
        .bFrameIndex(),
        .dwFrameInterval(),
        .wKeyFrameRate(),
        .wPFrameRate(),
        .wCompQuality(),
        .wCompWindowSize(),
        .wDelay(),
        .dwMaxVideoFrameSize(),
        .dwMaxPayloadTransferSize(),
        .dwClockFrequency(),
        .bmFramingInfo(),
        .bPreferedVersion(),
        .bMinVersion(),
        .bMaxVersion());

    ctrl_uac uac_if_ctrl(
        .RESET_IN(RESET_IN),
        .pClk(pClk),
        .header_ready(header_ready),
        .bmRequestType(bmRequestType),
        .bRequest(bRequest),
        .wValue(wValue),
        .wIndex(wIndex),
        .wLength(wLength),
        .cdata_ofs(cdata_ofs),
        .usb_rxdat(usb_rxdat),
        .usb_rxact(usb_rxact),
        .usb_rxval(usb_rxval),
        .usb_txpop(usb_txpop),
        .usb_txval(cuac_txval),
        .usb_txdat_len(cuac_txdat_len),
        .usb_txdat(cuac_txdat));

    reg [3:0] pState;

    localparam IDLE = 4'd1; //Wait for usb_sof
    localparam UNCORK = 4'd2; //Ready for TX (waiting txact)
    localparam TXACTIVE = 4'd4; //TX in progress (waiting ~txact)

    /* pLastPacket indicates that last data of the frame is in the buffer */
    reg pLastPacket;
    /* pLastReadActive indicates that last data of the frame is sent to USB */
    reg pLastReadActive;
    reg pReadActive;

    parameter PACKET_SIZE       = `PACKET_SIZE;
    localparam HEADER_SIZE      = 11'd12;
    localparam PACKET_PAYLOAD   = PACKET_SIZE - HEADER_SIZE;
    parameter WIDTH             = `WIDTH;
    parameter HEIGHT            = `HEIGHT;

    always @(posedge pClk) begin
        if(RESET_IN)
            pState <= IDLE;
        else if (usb_sof) begin
            /* WARNING ! Currently uvc_fifo_afull triggers at 1012 bytes,
               while we only need 1011 inside to fill full packet (one
               extra byte is always kept at the fifo output). */
            if (uvc_fifo_afull) begin
                video_txdat_len <= PACKET_SIZE;
                pLastReadActive <= 1'd0;
                pReadActive <= 1;
            end else if (pLastPacket) begin
                video_txdat_len <= uvc_fifo_rnum[11:0] + HEADER_SIZE;
                pLastReadActive <= 1'd1;
                pReadActive <= 1;
            end else begin
                video_txdat_len <= HEADER_SIZE;
                pLastReadActive <= 1'd0;
                pReadActive <= 0;
            end
            video_txcork <= 1'b0;
            pState <= UNCORK;
        end else if (video_txact && (pState == UNCORK)) begin
            pState <= TXACTIVE;
        end else if (~video_txact && (pState == TXACTIVE)) begin
            pState <= IDLE;
        end
    end

    reg [10:0] pktByteCount;
    always@(posedge pClk)
        if(pState != TXACTIVE)
            pktByteCount <= 'd0;
        else if (video_txpop)
            pktByteCount <= pktByteCount + 1'd1;

    reg [31:0] pts_counter;
    always @(posedge pClk)
        if (RESET_IN)
            pts_counter = 32'd0;
        else
            pts_counter = pts_counter + 32'd1;

    reg [10:0] sofCounts;
    reg [31:0] pts_reg;
    reg [7:0] pFrame;
    wire EOF = 1'd0;

    always @(posedge pClk)
        if(RESET_IN) begin
            pFrame <= 8'h8C;
            pts_reg <= 32'd0;
        end else if (v_txact_fall && pLastReadActive) begin
            pFrame <= {pFrame[7:1], pFrame[0]^1'b1};
            pts_reg <= pts_counter;
        end

    wire uvc_fifo_rden = video_txpop
                && (((pktByteCount >= (HEADER_SIZE - 1))
                  && (pktByteCount < (PACKET_SIZE - 1)) && pReadActive));

    /* ================= hClk ==================
       Get incoming YUV data, put it into FIFO */

    /* not really used */
    reg yLineValid_r1;
    always@(posedge hClk)
        yLineValid_r1 <= yLineValid;

    reg yFrameValid_r1;
    always@(posedge hClk)
        yFrameValid_r1 <= yFrameValid;
    wire h_sof = yFrameValid & ~yFrameValid_r1;

    reg [9:0] hCountX;
    reg [9:0] hCountY;

    reg hImage_eof;

    reg [2:0] hCount3;

    always@(posedge hClk)
        if (~yEnable) begin
            hCount3 <= 3'b001;
        end else begin
            hCount3 <= {hCount3[1:0], hCount3[2]};
        end

    wire vnu = hCountX[0];
    /*
        For each pair of pixels:
        P1   P1   P1   P2   P2   P2   pixel data available
        Y1   MU   MV   Us   Y2   Vs   write this part
        001  010  100  001  010  100  hCount3
        0    0    0    1    1    1    vnu

    */

    wire can_write = (hCountX < WIDTH) && yEnable;
    /* write Vs */
    wire hEnable2 = hCount3[2] && vnu && can_write;
    /* write Us */
    wire hEnable1 = hCount3[0] && vnu && can_write;
    /* write Y */
    wire hEnable0 = ((hCount3[0] && !vnu) || (hCount3[1] && vnu))
                && can_write;
    wire store_u = hCount3[1] && !vnu && can_write;
    wire store_v = hCount3[2] && !vnu && can_write;

    reg yEnable_r1;
    always@(posedge hClk)
        yEnable_r1  <= yEnable;

    always@(posedge hClk)
        if (h_sof) begin
            hCountX <= 'd0;
            hCountY <= 'd0;
            hImage_eof <= 'd0;
        end else begin
            hImage_eof <= 'd0;
            if (yEnable) begin
                if(hCount3[2])
                    hCountX <= hCountX + 1'd1;
            end else begin
                if (yEnable_r1) begin
                    hCountY <= hCountY + 1'd1;
                    if(hCountY == (HEIGHT - 1))
                        hImage_eof <= 1'd1;
                    hCountX <= 'd0;
                end
            end
        end

    wire [7:0] pRam_q;

    /* Input data has BGR (B in the high bits) */
    wire [7:0] B = {hData[17:12], 2'd0};
    wire [7:0] G = {hData[11:6], 2'd0};
    wire [7:0] R = {hData[5:0], 2'd0};
    wire [7:0] Y; // 8-bit output for Luma component
    wire [7:0] Cb; // 8-bit output for Chroma Blue component
    wire [7:0] Cr; // 8-bit output for Chroma Red component

    rgb_to_ycbcr_pipeline convert(
        .rst(RESET_IN),
        .hClk(hClk),
        .hLineValid(hLineValid),
        .hEnable(hEnable),
        .hFrameValid(hFrameValid),
        .R(R),
        .G(G),
        .B(B),
        .yLineValid(yLineValid),
        .yEnable(yEnable),
        .yFrameValid(yFrameValid),
        .Y(Y),
        .Cb(Cb),
        .Cr(Cr)
    );

    reg [7:0] Mu;
    reg [7:0] Mv;

    /* Which component to write in current pixel: Y, U(Cb) or V(Cr) */
    wire [7:0] fram_d = hEnable0 ? Y :
                        hEnable1 ? (Mu + Cb) >> 1 :
                        hEnable2 ? (Mv + Cr) >> 1 : 0;
    always@(posedge hClk)
        if(store_u)
            Mu <= Cb;

    always@(posedge hClk)
        if(store_v)
            Mv <= Cr;

    wire Empty;
    wire Full;
    fifo_video uvc_fifo(
            .Data(fram_d), //input [7:0] Data
            .Reset(RESET_IN | h_sof), //input Reset
            .WrClk(hClk), //input WrClk
            .RdClk(pClk), //input RdClk
            .WrEn(hEnable2 | hEnable1 | hEnable0), //input WrEn
            .RdEn(uvc_fifo_rden), //input RdEn
            .Rnum(uvc_fifo_rnum), //output [12:0] Rnum
            .Almost_Empty(uvc_fifo_aempty), //output Almost_Empty
            .Almost_Full(uvc_fifo_afull), //output Almost_Full
            .AlmostFullTh(PACKET_SIZE - HEADER_SIZE), //input [11:0] AlmostFullTh
            .Q(pRam_q), //output [7:0] Q
            .Empty(Empty), //output Empty
            .Full(Full) //output Full
            );

    /* Pull FrameValid to pClk */
    reg [4:0] pFrameValid_sr;
    always@(posedge pClk)
        pFrameValid_sr <= {pFrameValid_sr[3:0], yFrameValid};

    wire pImage_sof = pFrameValid_sr[4:2] == 3'b001;

    reg [3:0] pImage_eof_sr;
    wire pImage_eof = pImage_eof_sr[3:2] == 2'b01;
    always@(posedge pClk)
        pImage_eof_sr <= {pImage_eof_sr[2:0], hImage_eof};

    /* ================= hClk end ================== */


    always @(posedge pClk) begin
        if(usb_sof)
            video_txdat <= HEADER_SIZE; // Header length
        else if (video_txpop)
        case (pktByteCount)
            10'd0: begin
                if (pLastReadActive)
                    video_txdat <= pFrame | 8'h02;
                else
                    video_txdat <= pFrame;
            end
            10'd1 : video_txdat <= pts_reg[7:0];
            10'd2 : video_txdat <= pts_reg[15:8];
            10'd3 : video_txdat <= pts_reg[23:16];
            10'd4 : video_txdat <= pts_reg[31:24];
            10'd5 : video_txdat <= pts_reg[7:0];
            10'd6 : video_txdat <= pts_reg[15:8];
            10'd7 : video_txdat <= pts_reg[23:16];
            10'd8 : video_txdat <= pts_reg[31:24];
            10'd9 : video_txdat <= sofCounts[7:0];
            10'd10 : video_txdat <= {5'd0,sofCounts[10:8]};
            default : begin
                if (pktByteCount >= video_txdat_len - 1)
                    video_txdat <= HEADER_SIZE;
                else
                    video_txdat <= pRam_q;
            end
        endcase
    end

    reg sof_d0;
    reg sof_d1;
    always @(posedge pClk) begin
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
    always @(posedge pClk) begin
        if (RESET_IN) begin
            sofCounts <= 11'd0;
            sof_1ms <= 4'd0;
        end else begin
            if (sof_rise) begin
                if (sof_1ms >= 4'd7) begin
                    sof_1ms <= 4'd0;
                    sofCounts <= sofCounts + 11'd1;
                end else begin
                    sof_1ms <= sof_1ms + 4'd1;
                end
            end
        end
    end

    always @(posedge pClk) begin
        if (pImage_eof)
            pLastPacket <= 1'd1;
        else if (!usb_sof && pLastReadActive) begin
            pLastPacket <= 1'd0;
        end
    end

    assign debugs = {
        pLastReadActive,
        hFrameValid,
        hEnable,
        pImage_sof,
        uvc_fifo_rden,
        pState==TXACTIVE ? 1'b1 : 1'b0,
        usb_sof,
        pLastPacket
    };

    //==============================================================
    //======UART
    wire [15:0] uart_tx_data    ;
    wire        uart_tx_data_val;
    wire        uart_tx_busy    ;
    wire [15:0] uart_rx_data    ;
    wire        uart_rx_data_val;


    wire uart_cts = 1'b0;
    wire        ep3_rx_dval;
    wire [7:0]  ep3_rx_data;

    assign uart_tx_data     = {8'd0,ep3_rx_data};
    assign uart_tx_data_val = ep3_rx_dval;
    UART  #(
        .CLK_FREQ     (30'd60000000)  // set system clock frequency in Hz
    )u_UART
    (
         .CLK        (pClk                )// clock
        ,.RST        (usb_busreset | RESET_IN)// reset
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

    usb_fifo usb_fifo
    (
         .i_clk         (pClk   )//clock
        ,.i_reset       (usb_busreset | RESET_IN)//reset
        ,.i_usb_endpt   (endpt_sel    )
        ,.i_usb_rxact   (uart_rxact    )
        ,.i_usb_rxval   (uart_rxval    )
        ,.i_usb_rxpktval(usb_rxpktval )
        ,.i_usb_rxdat   (usb_rxdat    )
        ,.o_usb_rxrdy   (uart_rxrdy )
        ,.i_usb_txact   (uart_txact    )
        ,.i_usb_txpop   (uart_txpop    )
        ,.i_usb_txpktfin(usb_txpktfin )
        ,.o_usb_txcork  (uart_txcork)
        ,.o_usb_txlen   (uart_txdat_len )
        ,.o_usb_txdat   (uart_txdat )
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

module delay(input rst, input clk, input in, output out);

    parameter DELAY = 6;

    reg [DELAY-1:0] d;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            d <= 0;
        end else begin
            d <= {d[DELAY - 2:0], in};
        end
    end
    assign out = d[DELAY-1];

endmodule

module interface_alt_select(
    input RESET_IN,
    input pClk,
    input interface_update,
    input [7:0] interface_alter_i,
    output [7:0] interface_alter_o);

    reg [7:0] interface_alt_sel;

    assign interface_alter_o = interface_alt_sel;

    always @(posedge pClk) begin
        if (RESET_IN) begin
            interface_alt_sel <= 8'd0;
        end else if (interface_update) begin
            interface_alt_sel <= interface_alter_i;
        end
    end
endmodule

module rgb_to_ycbcr_pipeline(
    input rst,
    input hClk,
    input hLineValid,
    input hEnable,
    input hFrameValid,
    input [7:0] R, // 5-bit input for Red component
    input [7:0] G, // 5-bit input for Green component
    input [7:0] B, // 5-bit input for Blue component
    output yLineValid,
    output yEnable,
    output yFrameValid,
    output [7:0] Y, // 8-bit output for Luma component
    output [7:0] Cb, // 8-bit output for Chroma Blue component
    output [7:0] Cr // 8-bit output for Chroma Red component
);

    /* keep synchronisation signals in sync with data */
    delay hs(rst, hClk, hLineValid, yLineValid);
    delay vs(rst, hClk, hFrameValid, yFrameValid);

    /* Delays data and data valid for 6 clk */
    Color_Space_Convertor_Top rgb2yuv(
        .I_rst_n(!rst), //input I_rst_n
        .I_clk(hClk), //input I_clk
        .I_din0(R), //input [7:0] I_din0
        .I_din1(G), //input [7:0] I_din1
        .I_din2(B), //input [7:0] I_din2
        .I_dinvalid(hEnable), //input I_dinvalid
        .O_dout0(Y), //output [7:0] O_dout0
        .O_dout1(Cb), //output [7:0] O_dout1
        .O_dout2(Cr), //output [7:0] O_dout2
        .O_doutvalid(yEnable) //output O_doutvalid
        );

endmodule

module ctrl_uart(
    input RESET_IN,
    input pClk,
    input header_ready,
    input [7:0] bmRequestType,
    input [7:0] bRequest,
    input [15:0] wValue,
    input [15:0] wIndex,
    input [15:0] wLength,
    input [15:0] cdata_ofs,
    input [7:0] usb_rxdat,
    input usb_rxact,
    input usb_rxval,
    input usb_txpop,
    output reg usb_txval,
    output reg [11:0] usb_txdat_len,
    output reg [7:0] usb_txdat,
    output reg [1:0]  s_ctl_sig,
    output reg [31:0] s_dte1_rate,
    output reg [7:0]  s_char1_format,
    output reg [7:0]  s_parity1_type,
    output reg [7:0]  s_data1_bits
);

    localparam  SET_LINE_CODING = 8'h20;
    localparam  GET_LINE_CODING = 8'h21;
    localparam  SET_CONTROL_LINE_STATE = 8'h22;

    always @(posedge pClk)
        if (RESET_IN) begin
            usb_txval <= 1'd0;
            s_ctl_sig <= 2'd0;
            s_dte1_rate <= 32'd115200;
            s_char1_format <= 8'd0;
            s_parity1_type <= 8'd0;
            s_data1_bits <= 8'd8;
        end else if ((header_ready) && (wIndex == {8'd0, `UART_CTRL_IFACE})) begin
            if (bmRequestType == 8'h21) begin /* Set requests */
                if ((bRequest == SET_CONTROL_LINE_STATE) && (wLength == 0)) begin
                    s_ctl_sig[1:0] <= wValue[1:0];
                end else if (usb_rxact && (bRequest == SET_LINE_CODING)
                            && (wLength == 7)) begin
                    case (cdata_ofs)
                    16'd0: s_dte1_rate[7:0] <= usb_rxdat;
                    16'd1: s_dte1_rate[15:8] <= usb_rxdat;
                    16'd2: s_dte1_rate[23:16] <= usb_rxdat;
                    16'd3: s_dte1_rate[31:24] <= usb_rxdat;
                    16'd4: s_char1_format[7:0] <= usb_rxdat;
                    16'd5: s_parity1_type[7:0] <= usb_rxdat;
                    16'd6: s_data1_bits[7:0] <= usb_rxdat;
                    endcase
                end
            end else if (bmRequestType == 8'hA1) begin /* Get Resquests */
                if ((bRequest == GET_LINE_CODING) && (wLength != 0)) begin
                    if (usb_txpop) begin
                        case (cdata_ofs)
                        16'd0: usb_txdat <= s_dte1_rate[15:8];
                        16'd1: usb_txdat <= s_dte1_rate[23:16];
                        16'd2: usb_txdat <= s_dte1_rate[31:24];
                        16'd3: usb_txdat <= s_char1_format;
                        16'd4: usb_txdat <= s_parity1_type;
                        16'd5: usb_txdat <= s_data1_bits;
                        16'd6: usb_txdat <= 8'd0;
                        endcase
                        if ((usb_txdat_len - 16'd1) == cdata_ofs)
                            usb_txval <= 1'd0;
                    end else begin
                        if (cdata_ofs == 16'd0) begin
                            usb_txval <= 1;
                            usb_txdat_len <= wLength[11:0];
                            usb_txdat <= s_dte1_rate[7:0];
                        end
                    end
                end
            end
        end
endmodule

module ctrl_uvc(
    input RESET_IN,
    input pClk,
    input header_ready,
    input [ 7:0] bmRequestType,
    input [ 7:0] bRequest,
    input [15:0] wValue,
    input [15:0] wIndex,
    input [15:0] wLength,
    input [15:0] cdata_ofs,
    input [ 7:0] usb_rxdat,
    input usb_rxact,
    input usb_rxval,
    input usb_txpop,
    output reg  usb_txval,
    output reg  [11:0] usb_txdat_len,
    output reg  [ 7:0] usb_txdat,
    output reg  [15:0] bmHint,
    output reg  [ 7:0] bFormatIndex,
    output reg  [ 7:0] bFrameIndex,
    output reg  [31:0] dwFrameInterval,
    output reg  [15:0] wKeyFrameRate,
    output reg  [15:0] wPFrameRate,
    output reg  [15:0] wCompQuality,
    output reg  [15:0] wCompWindowSize,
    output reg  [15:0] wDelay,
    output reg  [31:0] dwMaxVideoFrameSize,
    output reg  [31:0] dwMaxPayloadTransferSize,
    output reg  [31:0] dwClockFrequency,
    output reg  [ 7:0] bmFramingInfo,
    output reg  [ 7:0] bPreferedVersion,
    output reg  [ 7:0] bMinVersion,
    output reg  [ 7:0] bMaxVersion
);

    always @(posedge pClk)
        if (RESET_IN) begin
            usb_txval <= 1'd0;
            bmHint                   <= 0;
            bFormatIndex             <= 8'h01;
            bFrameIndex              <= 8'h01;
            dwFrameInterval          <= `FRAME_INTERVAL;
            wKeyFrameRate            <= 0;
            wPFrameRate              <= 0;
            wCompQuality             <= 0;
            wCompWindowSize          <= 0;
            wDelay                   <= 0;
            dwMaxVideoFrameSize      <= `MAX_FRAME_SIZE;
            dwMaxPayloadTransferSize <= `PAYLOAD_SIZE;
            dwClockFrequency         <= 60000000;
            bmFramingInfo            <= 0;
            bPreferedVersion         <= 0;
            bMinVersion              <= 0;
            bMaxVersion              <= 0;
        end else if ((header_ready) &&
                    (wIndex == `UVC_VS_INTERFACE)) begin
            /* Ignore set requests */
            if (bmRequestType == 8'hA1) begin /* Get Resquests */
                /* wLength == 16'd34
                 * Accept any length > 0, either truncate or pad with zeroes */
                if ((wLength != 0) && (wValue[15:8] == `VS_PROBE_CONTROL)
                            &&((bRequest == `GET_CUR)
                            || (bRequest == `GET_DEF)
                            || (bRequest == `GET_MIN)
                            || (bRequest == `GET_MAX))) begin
                    if (usb_txpop) begin
                        case (cdata_ofs)
                        16'd0: usb_txdat <= bmHint[15:8];
                        16'd1: usb_txdat <= bFormatIndex[7:0];
                        16'd2: usb_txdat <= bFrameIndex[7:0];
                        16'd3: usb_txdat <= dwFrameInterval[7:0];
                        16'd4: usb_txdat <= dwFrameInterval[15:8];
                        16'd5: usb_txdat <= dwFrameInterval[23:16];
                        16'd6: usb_txdat <= dwFrameInterval[31:24];
                        16'd7: usb_txdat <= wKeyFrameRate[7:0];
                        16'd8: usb_txdat <= wKeyFrameRate[15:8];
                        16'd9: usb_txdat <= wPFrameRate[7:0];
                        16'd10: usb_txdat <= wPFrameRate[15:8];
                        16'd11: usb_txdat <= wCompQuality[7:0];
                        16'd12: usb_txdat <= wCompQuality[15:8];
                        16'd13: usb_txdat <= wCompWindowSize[7:0];
                        16'd14: usb_txdat <= wCompWindowSize[15:8];
                        16'd15: usb_txdat <= wDelay[7:0];
                        16'd16: usb_txdat <= wDelay[15:8];
                        16'd17: usb_txdat <= dwMaxVideoFrameSize[7:0];
                        16'd18: usb_txdat <= dwMaxVideoFrameSize[15:8];
                        16'd19: usb_txdat <= dwMaxVideoFrameSize[23:16];
                        16'd20: usb_txdat <= dwMaxVideoFrameSize[31:24];
                        16'd21: usb_txdat <= dwMaxPayloadTransferSize[7:0];
                        16'd22: usb_txdat <= dwMaxPayloadTransferSize[15:8];
                        16'd23: usb_txdat <= dwMaxPayloadTransferSize[23:16];
                        16'd24: usb_txdat <= dwMaxPayloadTransferSize[31:24];
                        16'd25: usb_txdat <= dwClockFrequency[7:0];
                        16'd26: usb_txdat <= dwClockFrequency[15:8];
                        16'd27: usb_txdat <= dwClockFrequency[23:16];
                        16'd28: usb_txdat <= dwClockFrequency[31:24];
                        16'd29: usb_txdat <= bmFramingInfo[7:0];
                        16'd30: usb_txdat <= bPreferedVersion[7:0];
                        16'd31: usb_txdat <= bMinVersion[7:0];
                        16'd32: usb_txdat <=  bMaxVersion[7:0];
                        default: usb_txdat <= 0;
                        endcase
                        if ((usb_txdat_len - 16'd1) == cdata_ofs)
                            usb_txval <= 1'd0;
                    end else if (cdata_ofs == 16'd0) begin
                        /* initial setup */
                        usb_txval <= 1'd1;
                        usb_txdat_len <= wLength < 16'd34
                                            ? wLength[11:0] : 16'd34;
                        usb_txdat <= bmHint[7:0];
                    end
                end
            end
        end
endmodule

module ctrl_uac(
    input RESET_IN,
    input pClk,
    input header_ready,
    input [7:0] bmRequestType,
    input [7:0] bRequest,
    input [15:0] wValue,
    input [15:0] wIndex,
    input [15:0] wLength,
    input [15:0] cdata_ofs,
    input [7:0] usb_rxdat,
    input usb_rxact,
    input usb_rxval,
    input usb_txpop,
    output reg usb_txval,
    output reg [11:0] usb_txdat_len,
    output reg [ 7:0] usb_txdat);

    always @(posedge pClk)
        if (RESET_IN) begin
            usb_txval <= 1'd0;
        end else if ((header_ready) && (wIndex[7:0] == `UAC_AC_INTERFACE)) begin
            /* Ignore set requests */
            if ((bmRequestType == 8'hA1) && (wLength != 0)) begin
                /* Get Resquests */
                if ((wValue[7:0] == 0)
                        && (wValue[15:8] == `CS_SAM_FREQ_CONTROL)
                        && (wIndex[15:8] == `UAC_CLOCK_ID)) begin
                    if ((bRequest == `UAC_CUR_ATTR)
                            && (wLength != 16'd0)) begin
                        if (usb_txpop) begin
                            case (cdata_ofs)
                            16'd0: usb_txdat <= {`UAC_FREQUENCY}[15:8];
                            16'd1: usb_txdat <= {`UAC_FREQUENCY}[23:16];
                            16'd2: usb_txdat <= {`UAC_FREQUENCY}[31:24];
                            default: usb_txdat <= 8'd0;
                            endcase
                        end else if (cdata_ofs == 16'd0) begin
                            usb_txval <= 1'd1;
                            usb_txdat_len <= wLength < 4 ? wLength[11:0] : 12'd4;
                            usb_txdat <= {`UAC_FREQUENCY}[7:0];
                        end
                    end else if (bRequest == `UAC_RANGE_ATTR) begin
                        if (usb_txpop) begin
                            case (cdata_ofs)
                            /* Number of ranges: 1, high byte */
                            16'd0: usb_txdat <= 8'h00;
                            /* RANGE.MIN = UAC_FREQUENCY */
                            16'd1: usb_txdat <= {`UAC_FREQUENCY}[7:0];
                            16'd2: usb_txdat <= {`UAC_FREQUENCY}[15:8];
                            16'd3: usb_txdat <= {`UAC_FREQUENCY}[23:16];
                            16'd4: usb_txdat <= {`UAC_FREQUENCY}[31:24];
                            /* RANGE.MAX = UAC_FREQUENCY */
                            16'd5: usb_txdat <= {`UAC_FREQUENCY}[7:0];
                            16'd6: usb_txdat <= {`UAC_FREQUENCY}[15:8];
                            16'd7: usb_txdat <= {`UAC_FREQUENCY}[23:16];
                            16'd8: usb_txdat <= {`UAC_FREQUENCY}[31:24];
                            /* RANGE.RES = 1 */
                            16'd9: usb_txdat <= 8'h00;
                            16'd10: usb_txdat <= 8'h00;
                            16'd11: usb_txdat <= 8'h00;
                            16'd12: usb_txdat <= 8'h00;
                            default: usb_txdat <= 8'd0;
                            endcase
                        end else if (cdata_ofs == 16'd0) begin
                            usb_txval <= 1'd1;
                            usb_txdat_len <= wLength < 14 ? wLength[11:0] : 12'd14; /* length */
                            /* Number of ranges: 1, low byte */
                            usb_txdat <= 8'h01;
                        end
                    end
                    if (usb_txpop && usb_txval
                            && ((usb_txdat_len - 16'd1) == cdata_ofs))
                        usb_txval <= 1'd0;
                end
            end
        end
endmodule

module usbuac_ep(
    input rst,
    input pClk,
    input usb_sof_rise,
    input gClk,
    input [15:0] left,
    input [15:0] right,
    input uac_txpop,
    input uac_txact,
    output reg [7:0] uac_txdat,
    output reg [11:0] uac_txdat_len,
    output reg uac_txcork);

    /* 2 bytes per ch, 2 ch, 6 smaples per microframe */
    localparam ASFREQ = 44100;
    localparam CH = 2;
    localparam BITS_PER_SUBSAMPLE = 16;
    localparam AFREQ = ASFREQ * BITS_PER_SUBSAMPLE * CH;
    localparam SAMPLES_PER_MFRAME = (ASFREQ + 7999)/8000;
    localparam MAXBUFFER = BITS_PER_SUBSAMPLE * CH * SAMPLES_PER_MFRAME / 8;

    reg write_to; /* mem area that is currently written to */
    //reg [MAXBUFFER - 1:0][7:0] mem0;
    //reg [MAXBUFFER - 1:0][7:0] mem1;
    reg [MAXBUFFER*8 - 1:0] mem0;
    reg [MAXBUFFER*8 - 1:0] mem1;
    reg [11:0] write_ptr0;
    reg [11:0] write_ptr1;

    reg [3:0] pState;

    localparam IDLE = 4'd1; //Wait for usb_sof
    localparam UNCORK = 4'd2; //Ready for TX (waiting txact)
    localparam TXACTIVE = 4'd4; //TX in progress (waiting ~txact)

    reg store_state;
    reg switch_active;
    reg switch_complete;

    always @(posedge pClk) begin
        if (rst)
            pState <= IDLE;
        else if (usb_sof_rise) begin
            pState <= UNCORK;
        end else if (uac_txact && (pState == UNCORK)) begin
            pState <= TXACTIVE;
        end else if (~uac_txact && (pState == TXACTIVE)) begin
            pState <= IDLE;
        end
    end

    wire [31:0] sample;
    wire sample_ready;
    sample_get_p usb_sam(
        .pClk(pClk),
        .gClk(gClk),
        .left(left),
        .right(right),
        .sample(sample),
        .ready(sample_ready));

    reg p_sample_ready;

    always@(posedge pClk) begin
        if (usb_sof_rise) begin
            switch_active <= 1;
        end
        p_sample_ready <= sample_ready;
        if (sample_ready & ~p_sample_ready) begin
            store_state <= 1'b1;
        end
        switch_complete <= 0;
        if (store_state) begin
            if (write_ptr0 != MAXBUFFER) begin
                mem0 <= {sample, mem0[MAXBUFFER*8 - 1:32]};
                write_ptr0 <= write_ptr0 + 12'd4;
            end
            store_state <= 1'b0;
        end else begin
            if (switch_active) begin
                write_ptr1 <= write_ptr0;
                if (write_ptr0 != MAXBUFFER)
                    mem1 <= {32'd0, mem0[MAXBUFFER*8 - 1:32]};
                else
                    mem1 <= mem0;
                write_ptr0 <= 12'd0;
                switch_active <= 0;
                switch_complete <= 1;
            end
        end
        if(switch_complete) begin
            uac_txdat <= mem1[7:0];
            mem1 <= {8'd0, mem1[MAXBUFFER*8 - 1:8]};
            uac_txdat_len <= (write_ptr1 >= MAXBUFFER - 4) ? write_ptr1 : 0;
            uac_txcork <= 1'b0;
        end else if (uac_txpop) begin
            uac_txdat <= mem1[7:0];
            mem1 <= {8'd0, mem1[MAXBUFFER*8 - 1:8]};
        end
    end
endmodule

module audioclk_gen(input pClk, input reset, output bclk, output aclk);
    parameter BASE_FREQ = 60000000;
    parameter FREQ_SUM = BASE_FREQ / 2;
    parameter AFREQ = 44100;
    parameter BFREQ = AFREQ * 32;

    reg [31:0] count;
    reg [4:0] acount;
    reg bclkin;

    always @(posedge pClk or posedge reset) begin
        if (reset) begin
            count <= 32'd0;
            acount <= 6'd0;
            bclkin <= 0;
        end else begin
            if (count < FREQ_SUM)
                count <= count + BFREQ;
            else begin
                count <= count - FREQ_SUM + BFREQ;
                bclkin <= ~bclkin;
                if (~bclkin)
                    acount <= acount + 5'd1;
            end
        end
    end

    assign bclk = bclkin;
    assign aclk = (acount[4] == 0);
endmodule

module sync_audio(
    input gClk,
    input pClk,
    input [15:0] left,
    input [15:0] right,
    output [31:0] p_sample);

    reg [31:0] sample;

    delay #(.DELAY(2)) sync_g(1'b0, pClk, gClk, g_rdy);

    reg g_prdy;

    always @(posedge pClk) begin
        g_prdy <= g_rdy;
        if (~g_prdy && g_rdy) begin
            sample <= {right, left};
        end
    end
    assign p_sample = sample;
endmodule

module sample_get_p(
    input pClk,
    input gClk,
    input [15:0] left,
    input [15:0] right,
    output reg [31:0] sample,
    output reg ready);

    wire [31:0] s;
    wire aclk;

    /* aclk is synchronized to pClk */
    audioclk_gen g_ab(.pClk(pClk), .reset(1'b0), .bclk(), .aclk(aclk));

    sync_audio sa(
        .gClk(gClk),
        .pClk(pClk),
        .left(left),
        .right(right),
        .p_sample(s));

    always @(posedge pClk) begin
        if (~ready & aclk) begin
            sample <= s;
        end
        ready <= aclk;
    end
endmodule
