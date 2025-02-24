// top.v

module top #(parameter ISSIMU=0)
(
    output              ADC_SEL,
    output              AUD_BCLK,
    output              AUD_DIN,
    output              AUD_MCLK,
    output              AUD_RESET,
    output              AUD_WCLK,

    input               BTN_A,
    input               BTN_B,
    input               BTN_DPAD_DOWN,
    input               BTN_DPAD_LEFT,
    input               BTN_DPAD_RIGHT,
    input               BTN_DPAD_UP,
    input               BTN_MENU,
    input               BTN_SEL,
    input               BTN_START,
    
    output  [15:0]      CART_A,
    output              CART_CLK,
    output              CART_CS,
    inout   [7:0]       CART_D,
    output              CART_RD,
    inout               CART_RST,
    output              CART_WR,
    output              CART_DATA_DIR_E,

    input               CART_DET,
    input               CART_AUDIN,

    input               CLK_FPGA,       // 33.55432MHz 
    input               CLK_27MHz,
    input               CLK_24MHz,

    output reg          ESP32_EN,

    output              SDIO_LS,
    input               POWER_ON_FPGA,
    output              POWER_DOWN_IO,
    input               VBUS_DET,

    output reg          ESP32_IO0,

    output              I2S_BCLK,       // D16 IO33 
    input               I2S_WS,         // D15 IO25 CC 
    input               I2S_DIN,        // D14 IO26 
    input               I2S_DOUT,       // D13 IO27 
    input               ESP32_MCU_D12,  // D12 IO9 
    output              ESP32_MCU_D11,  // D11 IO10 CC
    input               QSPI_CS,        // CS D10 IO5 CC 
    input               QSPI_CLK,       // CLK D9 IO18 CC
    input               QSPI_MOSI,      // D D8 IO23
    input               QSPI_MISO,      // Q D7 IO19
    input               QSPI_WP,        // WP D6 IO22
    input               QSPI_HD,        // HD D5 IO21 CC
    output  reg         ESP32_MCU_D4,   // RXD
    input               ESP32_MCU_D3,   // TXD

    output              FPGA_LED_EN,
    output  reg         FPGA_LED_R,
    output  reg         FPGA_LED_G,
    output  reg         FPGA_LED_B,

    output  [2:0]       HDMI_D_P,
    output  [2:0]       HDMI_D_N,
    output              HDMI_CLK_P,
    output              HDMI_CLK_N,
    input               HDMI_SBU1_HPD,
    output              HDMI_SBU2_CEC,

    input               IR_RX,
    output              IR_LED,

    output              LCD_PWM,
    
    output [5:0]        LCD_DB,
    output              LCD_DOTCLK,
    output              LCD_ENABLE,
    output              LCD_HSYNC,
    output              LCD_RESET,
    output              LCD_SPI_CSX,
    output              LCD_SPI_SCLK,
    output              LCD_SPI_SDA,
    input               LCD_TE,
    output              LCD_VSYNC,

    inout               LINK_CLK,
    input               LINK_IN,
    output              LINK_OUT,
    output              LINK_SD,

    output              PS_CE_N,
    output              PS_CLK,
    inout   [7:0]       PS_DQ,
    inout               PS_DQS,

    inout               SCL,
    inout               SDA,

    input               USBC_FLIP,
    inout               usb_dxp_io,
    inout               usb_dxn_io,
    input               usb_rxdp_i,
    input               usb_rxdn_i,
    output              usb_pullup_en_o,
    inout               usb_term_dp_io,
    inout               usb_term_dn_io,

    input               VBAT_ADC_P,
    input               VBAT_ADC_N
);

    assign POWER_DOWN_IO = 1'bZ;
    assign SDIO_LS = 1'd1;

    wire    BIST_failed;
    wire    BIST_finished;

    assign FPGA_LED_EN = 1'd1;
    
    wire lock_o;

    wire fClk;
    wire pClk;
    wire hClk;
    wire gClk;
    wire xClk;
    
    Gowin_PLL u_Gowin_PLL(
        .reset(1'd0),//input reset
        .clkout0(fClk), //output clkout0 ~150MHz
        .clkout1(pClk), //output clkout1 ~33.554MHz
        .clkout2(hClk), //output clkout2 ~16.777MHz
        .clkout3(gClk), //output clkout3 ~8.388MHz
        .clkout4(xClk), //output clkout4 ~75MHz
//        .clkout5(hdmiclk), //output clkout4 ~75MHz
        .lock(lock_o), //output lock
        .clkin(CLK_FPGA) //input clkin
    );
    
    reg [13:0] voltageSim = 14'd1500;
    reg voltageSimDir = 1'b0;
    
    reg [22:0] secondCounter = 'd0;
    reg secondEna;
    reg halfSecondEna;
    reg [16:0] percentCounter = 'd0;
    reg percentEna;
    
    always@(posedge gClk) begin
        percentEna <= 1'b0;
        if (percentCounter == 83886) begin
            percentEna     <= 1'b1;
            percentCounter <= 17'd0;
        end else begin
            percentCounter <= percentCounter + 1'd1;
        end 
    
        secondEna      <= 1'b0;
        halfSecondEna  <= 1'b0;
        if (secondCounter == 4194303) begin
            halfSecondEna  <= 1'b1;
        end
        if (secondCounter == 8388607) begin
            secondEna      <= 1'b1;
            halfSecondEna  <= 1'b1;
            secondCounter  <= 23'd0;
            percentCounter <= 17'd0;
        end else begin
            secondCounter <= secondCounter + 1'd1;
        end 
        
        if (secondEna) begin
            if (voltageSimDir) begin
                voltageSim <= voltageSim + 50;
                if (voltageSim > 1800) begin
                  voltageSimDir <= 1'b0;
                end
            end else begin
                voltageSim <= voltageSim - 50;
                if (voltageSim < 950) begin
                  voltageSimDir <= 1'b1;
                end
            end
        end
    end
    
    wire low_battery;
    wire boot_rom_enabled;
    wire LED_Green;
    wire LED_Red;
    wire LED_Yellow;
    wire [7:0]  pmic_sys_status;
    
    always@(posedge xClk)
    begin
        if (LED_Green) begin
            FPGA_LED_R <= 1'd1;
            FPGA_LED_B <= 1'd1;
            FPGA_LED_G <= 1'd0;
        end else if (LED_Yellow) begin
            FPGA_LED_R <= 1'd0;
            FPGA_LED_B <= 1'd1;
            FPGA_LED_G <= secondCounter[4];
        end else if (LED_Red) begin
            FPGA_LED_R <= 1'd0;
            FPGA_LED_B <= 1'd1;
            FPGA_LED_G <= 1'd1;
        end else begin
            FPGA_LED_R <= 1'd1;
            FPGA_LED_B <= 1'd1;
            FPGA_LED_G <= 1'd1;
        end
    end
    
    wire [15:0]       hWrBurstQ;
    wire [15:0]       hWrBurstQ2;
    wire              hValid;
    wire              hHsync;
    wire              hVsync;

    wire gb_lcd_clkena;
    wire [14:0] gb_lcd_data;
    wire [1:0] gb_lcd_mode;
    wire gb_lcd_on;
    wire gb_lcd_vsync;
    wire LCD_INIT_DONE;

    wire              hGBNewLine;
    wire [22:0]       hGBAddress;
    wire              hGBWrite;
    wire [15:0]       hGBData;
    wire              LCD_ENABLE_UVC;


    reg LCD_VSYNC_r1;
    always@(posedge gClk)
        LCD_VSYNC_r1 <= LCD_VSYNC;

    reg memrst = 1'd0;

    reg LCD_EN1;
    reg LCD_EN0;
    reg LCD_EN;
    wire qMenuInit;
    wire LCD_BACKLIGHT_INIT;
    always@(posedge gClk or posedge memrst) begin
        if(memrst) begin
            LCD_EN <= 1'd0;
            LCD_EN0 <= 1'd0;
            LCD_EN1 <= 1'd0;
        end else begin
            if(LCD_VSYNC&~LCD_VSYNC_r1) begin
                LCD_EN0 <= LCD_INIT_DONE & LCD_BACKLIGHT_INIT;
                LCD_EN1 <= LCD_EN0;
                LCD_EN  <= LCD_EN1;
            end
            // synthesis translate_off
            LCD_EN  <= 1'd1;
            // synthesis translate_on
        end
    end
    
    wire [31:0] debug_system;
    wire [15:0] system_control;
    wire [17:0] LCD_DB_UVC;
    wire menuDisabled;
    wire slideOutActive;
    wire hDrawOSD;
    vid_system_top #(ISSIMU) 
    u_vid_system_top(
        .gClk(gClk),
        .hClk(hClk),
        .pClk(pClk),
        .reset(memrst),
        
        .BTN_MENU(menuDisabled),
        .slideOutActive(slideOutActive),
        
        .LCD_DB(LCD_DB),
        .LCD_ENABLE_UVC(LCD_ENABLE_UVC),
        .LCD_DB_UVC(LCD_DB_UVC),
        .LCD_DOTCLK(LCD_DOTCLK),
        .LCD_ENABLE(LCD_ENABLE),
        .LCD_HSYNC(LCD_HSYNC),
        .LCD_EN(LCD_EN),
        .LCD_RESET(LCD_RESET),
        .LCD_SPI_CSX(LCD_SPI_CSX),
        .LCD_SPI_SCLK(LCD_SPI_SCLK),
        .LCD_SPI_SDA(LCD_SPI_SDA),
        .LCD_TE(LCD_TE),
        .LCD_VSYNC(LCD_VSYNC),
        .LCD_GENLOCK(),
        
        .frameBlendEnable(system_control[1]),
        .colorCorrectionEnableLCD(system_control[2]),
        .colorCorrectionEnableUVC(system_control[3]),
        .voltageLow(low_battery),
        .lowBattDispMode(system_control[14:13]),
        .showTimer(1'b0), //system_control[8]),
        .runTimer(system_control[9]),
        .resetTimer(system_control[10]),
        .gSecondEna(secondEna),
        .gPercentEna(percentEna),
        .debug_system(debug_system),
        .debug_system_on(1'b0),
        
        .hDrawOSD(hDrawOSD),
        .hGBNewLine(hGBNewLine),
        .hGBAddress(hGBAddress),
        .hGBWrite(hGBWrite),
        .hGBData(hGBData),
    
        .hValid(hValid),
        .hHsync(hHsync),
        .hVsync(hVsync),
        .hWrBurstQ(hWrBurstQ),
        .hWrBurstQ2(hWrBurstQ2),

        .LCD_INIT_DONE(LCD_INIT_DONE),
        .gb_lcd_clkena(gb_lcd_clkena),
        .gb_lcd_mode(gb_lcd_mode),
        .gb_lcd_on(gb_lcd_on),
        .gb_lcd_vsync(gb_lcd_vsync),
        .gb_lcd_data(gb_lcd_data)
    );

    wire [15:0] left, right;
    wire [7:0]  volume;
    wire        hHeadphones;    

    aud_system_top u_aud_system_top(
        .gClk(gClk),
        .hClk(hClk),
        .reset_n(lock_o),
        .left(left),
        .right(right),
        
        .AUD_BCLK(AUD_BCLK),
        .AUD_DIN(AUD_DIN),
        .AUD_DOUT(),
        .AUD_MCLK(AUD_MCLK),
        .AUD_RESET(AUD_RESET),
        .AUD_WCLK(AUD_WCLK),
            
        .software_mute(system_control[0]),
        .pmic_sys_status(pmic_sys_status),
        .volume(volume),
        .hHeadphones(hHeadphones),
        .SCL(SCL),
        .SDA(SDA)
    );

    reg [17:0] CART_DET_sr;
    always@(posedge xClk)
        CART_DET_sr <= {CART_DET_sr[16:0], CART_DET};

    // CART_DET = 0 (no cart inserted)
    always@(posedge xClk or negedge lock_o)
        if(~lock_o)
            memrst <= 1'd1;
        else
            memrst <= CART_DET_sr[17:2] == 16'h7FFF || CART_DET_sr[17:2] == 16'h8000;

    mem_system_top #(ISSIMU) 
    u_mem_system_top 
    (
        .xClk(xClk),
        .fClk(fClk),
        .hClk(hClk),
        .reset(memrst),
        
        .QSPI_CLK(QSPI_CLK),
        .QSPI_MOSI(QSPI_MOSI),
        .QSPI_MISO(QSPI_MISO),
        .QSPI_CS(QSPI_CS),
        .QSPI_WP(QSPI_WP),
        .QSPI_HD(QSPI_HD),

        .PS_CE_N(PS_CE_N),
        .PS_CLK(PS_CLK),
        .PS_DQ(PS_DQ),
        .PS_DQS(PS_DQS),

        .BIST_failed(BIST_failed),
        .BIST_finished(BIST_finished),
        .qMenuInit(qMenuInit),
        .hGBNewLine(hGBNewLine),
        .hGBAddress(hGBAddress),
        .hGBWrite(hGBWrite),
        .hGBData(hGBData),

        // mm_burst_read_to_stream 
        .hValid(gb_lcd_clkena),
        .hHsync(gb_lcd_mode[1]),
        .hVsync(gb_lcd_vsync),
        .hWrBurstQ(hWrBurstQ),
        .hWrBurstQ2(hWrBurstQ2)
    );

    wire IR_RX_FILTER;

    wire lcd_on_int;
    wire lcd_off_overwrite;
    
    emu_system_top u_emu_system_top(
        .hclk(hClk),
        .pclk(pClk),
        .reset_n(~memrst),//lock_o),
        
        .paletteOff(system_control[12]),
        
        .BTN_NODIAGONAL(system_control[11]),
        .BTN_A(BTN_A),
        .BTN_B(BTN_B),
        .BTN_DPAD_DOWN(BTN_DPAD_DOWN),
        .BTN_DPAD_LEFT(BTN_DPAD_LEFT),
        .BTN_DPAD_RIGHT(BTN_DPAD_RIGHT),
        .BTN_DPAD_UP(BTN_DPAD_UP),
        .BTN_MENU(~BTN_MENU),
        .BTN_SEL(BTN_SEL),
        .BTN_START(BTN_START),
        .MENU_CLOSED(menuDisabled & ~slideOutActive),
        
        .CART_A(CART_A),
        .CART_CLK(CART_CLK),
        .CART_CS(CART_CS),
        .CART_D(CART_D),
        .CART_RD(CART_RD),
        .CART_RST(CART_RST),
        .CART_WR(CART_WR),
        .CART_DATA_DIR_E(CART_DATA_DIR_E),

        .IR_RX(IR_RX),
        .IR_LED(IR_LED),

        .LINK_CLK(LINK_CLK),
        .LINK_IN(LINK_IN),
        .LINK_OUT(LINK_OUT),
        
        .lcd_on_int(lcd_on_int),
        .lcd_off_overwrite(lcd_off_overwrite),

        .boot_rom_enabled(boot_rom_enabled),
        
        // audio
        .left(left),
        .right(right),
        // video
        .LCD_INIT_DONE(LCD_INIT_DONE),
        .gb_lcd_clkena(gb_lcd_clkena),
        .gb_lcd_mode(gb_lcd_mode),
        .gb_lcd_on(gb_lcd_on),
        .gb_lcd_vsync(gb_lcd_vsync),
        .gb_lcd_data(gb_lcd_data)
    );

    reg UART_TXD;
    wire UART_RXD;
    wire PHY_CLKOUT;
    wire usblocked;
    always@(posedge PHY_CLKOUT or negedge usblocked)
    begin
        if(~usblocked)
        begin
            UART_TXD     <= 1'd1;
            ESP32_MCU_D4 <= 1'd1;
        end
        else
        begin
            UART_TXD     <= ESP32_MCU_D3;
            ESP32_MCU_D4 <= UART_RXD;
        end
    end
    wire UART_DTR;
    wire UART_RTS;
    wire [1:0] DTRRTS = {UART_DTR, UART_RTS};

    always@(posedge PHY_CLKOUT or negedge usblocked)
    begin
        if(~usblocked)
        begin
            ESP32_EN <= 1'd1;
            ESP32_IO0 <= 1'd1;
        end
        else
        begin
            ESP32_EN <= ~UART_RTS;
            ESP32_IO0 <= DTRRTS == 2'b00;
        end
    end

    wire clk24;
    wire [7:0] debugs;

    assign HDMI_D_P[2] = lcd_on_int;
    assign HDMI_D_N[2] = hDrawOSD;
    assign HDMI_D_P[1] = lcd_off_overwrite;
    assign HDMI_D_N[1] = gb_lcd_on;
    assign HDMI_D_P[0] = gb_lcd_vsync;
    assign HDMI_D_N[0] = gb_lcd_mode[1];
    assign HDMI_CLK_P = gb_lcd_clkena;
    assign HDMI_CLK_N = hGBWrite;

    reg hr1;
    reg vr1;
    reg he1;
    reg [17:0] d1;

    always@(posedge gClk or posedge memrst)
    begin
        if(memrst)
        begin
            hr1 <= 'd0;
            vr1 <= 'd0;
            he1 <= 'd0;
            d1  <= 'd0;
        end
        else
        begin        
            hr1 <= LCD_HSYNC;
            vr1 <= LCD_VSYNC;
            he1 <= LCD_ENABLE_UVC;
            d1  <= LCD_DB_UVC;
        end
    end

    reg [31:0] usbinitcnt;
    reg usbrst = 1'd1;

    // 8388607 = 1s
    always@(posedge gClk or negedge lock_o)
        if(~lock_o)
        begin
            usbinitcnt <= 'd0;
            usbrst     <= 1'd1;
        end
        else
            if(usbinitcnt < 8388607)
            begin
                usbinitcnt <= usbinitcnt + 1'd1;
                usbrst <= 1'd1;
            end
            else
                usbrst <= 1'd0;

    usbuvcuart_top u_usb_top(
        .CLK_24MHz(CLK_24MHz),
        .ERST(usbrst),
        .pClk(PHY_CLKOUT),
        .usblocked(usblocked),
        .hClk(gClk),

        .UART_TXD(UART_RXD), // output
        .UART_RXD(UART_TXD), // input
        .E_UART_DTR(UART_DTR), // used for ESP32_EN
        .E_UART_RTS(UART_RTS), // used for ESP32_IO0 (bootloader select)

        .hLineValid(hr1),
        .hEnable(he1),
        .hFrameValid(vr1),
        .hData(d1),
        .debugs(debugs),
        .playerNum({4'd0, system_control[7:4]}),
        .usb_dxp_io(usb_dxp_io),
        .usb_dxn_io(usb_dxn_io),
        .usb_rxdp_i(usb_rxdp_i),
        .usb_rxdn_i(usb_rxdn_i),
        .usb_pullup_en_o(usb_pullup_en_o),
        .usb_term_dp_io(usb_term_dp_io),
        .usb_term_dn_io(usb_term_dn_io)
    );

    wire [13:0] hAdcValue_r1;
    wire hAdcReq_ext;
    wire hAdcReady_r1;
    adc_wrap u_adc_wrap(
        .clk(gClk),
        .reset_n(lock_o),
        .hAdcReq_ext(hAdcReq_ext),
        .hAdcValue_r1(hAdcValue_r1),
        .hAdcReady_r1(hAdcReady_r1),
        .VBAT_ADC_P(VBAT_ADC_P),
        .VBAT_ADC_N(VBAT_ADC_N)
    );
    
    wire [7:0]  uart_tx_data;
    wire        uart_tx_busy;
    wire        uart_tx_val;

    wire [15:0] uart_rx_data;
    wire        uart_rx_val;

    wire menu_gated = qMenuInit&(CART_DET_sr[6:3]==4'b1111) ? BTN_MENU : 1'b1;

    system_monitor u_system_monitor(
        .clk(gClk),
        .reset(~lock_o),
        .BTN_A(BTN_A),
        .BTN_B(BTN_B),
        .BTN_DPAD_DOWN(BTN_DPAD_DOWN),
        .BTN_DPAD_LEFT(BTN_DPAD_LEFT),
        .BTN_DPAD_RIGHT(BTN_DPAD_RIGHT),
        .BTN_DPAD_UP(BTN_DPAD_UP),
        .BTN_MENU(menu_gated),
        .BTN_SEL(BTN_SEL),
        .BTN_START(BTN_START),
        .menuDisabled(menuDisabled),
        .LCD_BACKLIGHT_INIT(LCD_BACKLIGHT_INIT),
        .LCD_INIT_DONE(LCD_INIT_DONE & ~boot_rom_enabled),
        .LCD_PWM(LCD_PWM),
        .hAdcReq_ext(hAdcReq_ext),
        //.hAdcValue_r1(voltageSim),
        .hAdcValue_r1(hAdcValue_r1),
        .hAdcReady_r1(hAdcReady_r1),
        .ADC_SEL(ADC_SEL),
        .hButtons(9'd0),
        .hVolume(volume[6:0]),
        .pmic_sys_status(pmic_sys_status),
        .hHeadphones(hHeadphones),
        .gSecondEna(secondEna),
        .gHalfSecondEna(halfSecondEna),
        .debug_system(debug_system),
        .low_battery(low_battery),
        .LED_Green(LED_Green),
        .LED_Red(LED_Red),
        .LED_Yellow(LED_Yellow),
        .system_control(system_control),
        .uart_rx_data(uart_rx_data[7:0]),
        .uart_rx_val(uart_rx_val),
        .uart_tx_busy(uart_tx_busy),
        .uart_tx_data(uart_tx_data),
        .uart_tx_val(uart_tx_val)
    );

    UART2 
    #(.CLK_FREQ(30'd8388608))
    u_UART2
    (
        .CLK(gClk), // clock
        .RST(~lock_o), // reset
        // UART INTERFACE     
        .UART_TXD(ESP32_MCU_D11), //output
        .UART_RXD(ESP32_MCU_D12), //input    
        .UART_RTS(), //output // when UART_RTS = 0, UART This Device Ready to receive.
        .UART_CTS(1'd0), //input// when UART_CTS = 0, UART Opposite Device Ready to receive.
        // UART Control Reg
        .BAUD_RATE(32'd115200), //input 32
        .PARITY_BIT(8'd0), // input 8
        .STOP_BIT(8'd0), // input 8
        .DATA_BITS(8'd8), // input 8
        // USER DATA INPUT INTERFACE
        .TX_DATA({8'd0, uart_tx_data}), //input 16
        .TX_DATA_VAL(uart_tx_val), //input 1 when TX_DATA_VAL = 1, data on TX_DATA will be transmit, DATA_SEND can set to 1 only when BUSY = 0
        .TX_BUSY(uart_tx_busy), //output when BUSY = 1 transiever is busy, you must not set DATA_SEND to 1
        // USER FIFO CONTROL INTERFACE
        .RX_DATA(uart_rx_data), //output 16
        .RX_DATA_VAL(uart_rx_val)//output
    );

    assign I2S_BCLK = menuDisabled;

endmodule
