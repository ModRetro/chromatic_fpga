// vid_system_top.v

module vid_system_top #(parameter ISSIMU=0)
(
    input               gClk,
    input               hClk,
    input               pClk,
    input               reset,

    input               BTN_MENU,
    output reg          slideOutActive,

    output [5:0]        LCD_DB,
    output              LCD_ENABLE_UVC,
    output [17:0]       LCD_DB_UVC,
    output              LCD_DOTCLK,
    output              LCD_ENABLE,
    output              LCD_HSYNC,
    output              LCD_RESET,
    output              LCD_SPI_CSX,
    output              LCD_SPI_SCLK,
    output              LCD_SPI_SDA,
    input               LCD_TE,
    input               LCD_EN,
    output              LCD_GENLOCK,
    output              LCD_VSYNC,

    input               frameBlendEnable,
    input               colorCorrectionEnableLCD,
    input               colorCorrectionEnableUVC,
    input               voltageLow,
    input [1:0]         lowBattDispMode,
    input               showTimer,
    input               runTimer,
    input               resetTimer,
    input               gSecondEna,
    input               gPercentEna,
    input [31:0]        debug_system,
    input               debug_system_on,

    output              hGBNewLine,
    output reg [22:0]   hGBAddress,
    output              hGBWrite,
    output  [15:0]      hGBData,

    output              hValid,
    output              hHsync,
    output              hVsync,
    input [15:0]        hWrBurstQ,
    input [15:0]        hWrBurstQ2,
    output  reg         hDrawOSD,

    output              LCD_INIT_DONE,
    input               gb_lcd_clkena,
    input [14:0]        gb_lcd_data,
    input [1:0]         gb_lcd_mode,
    input               gb_lcd_on,
    input               gb_lcd_vsync

);

    ODDR u_ODDR(
        .Q0(LCD_DOTCLK),
        .Q1(),
        .D0(1'd1),
        .D1(1'd0),
        .TX(1'd1),
        .CLK(gClk)
    );


    ST7785_init #(ISSIMU)
    u_ST7785_init(
        .clk(pClk),
        .reset(reset),
        .LCD_CS(LCD_SPI_CSX),
        .LCD_SCK(LCD_SPI_SCLK),
        .LCD_SDA_SDI(LCD_SPI_SDA),
        .LCD_RST(LCD_RESET),
        .LCD_INIT_DONE(LCD_INIT_DONE)
    );

    wire [14:0] hColorPixel;
    assign hHsync = gb_lcd_mode[1];
    assign hVsync = gb_lcd_vsync;


    reg hHsync_r1;
    reg hVsync_r1;
    always@(posedge hClk)
    begin
        hHsync_r1 <= hHsync;
        hVsync_r1 <= hVsync;
    end

    reg hGBFrameBufferNum;
    always@(posedge hClk)
    begin
        if(hVsync&~hVsync_r1)
        begin
           hGBAddress        <= 23'h10000;
        end
        else
            if(hGBNewLine&~hVsync)
                hGBAddress <= hGBAddress + 'd320;
    end

    assign  hGBWrite    = gb_lcd_clkena;
    assign  hGBNewLine  = ~hHsync&hHsync_r1;
    assign  hGBData     = {1'd0, gb_lcd_data[14:0]};

    reg [7:0] screenX;
    reg [7:0] screenY;
    always@(posedge hClk) begin
        if (hHsync&~hHsync_r1) begin
            screenX <= 8'd0;
            screenY <= screenY + 1'd1;
        end else if (gb_lcd_clkena) begin
            screenX <= screenX + 1'd1;
        end

        if(hVsync&~hVsync_r1) begin
            hDrawOSD <= ~BTN_MENU;
            screenY  <= 8'd0;
        end
    end
        
/* 50% blend
    wire [6:0] sum_r = {hWrBurstQ[4:0],1'd0} + {gb_lcd_data[4:0],1'd0};
    wire [6:0] sum_g = {hWrBurstQ[9:5],1'd0} + {gb_lcd_data[9:5],1'd0};
    wire [6:0] sum_b = {hWrBurstQ[14:10],1'd0} + {gb_lcd_data[14:10],1'd0};
*/
/* 25% blend
*/
    wire [6:0] sum_r = hWrBurstQ[4:0] + {gb_lcd_data[4:0],1'd0} + gb_lcd_data[4:0];
    wire [6:0] sum_g = hWrBurstQ[9:5] + {gb_lcd_data[9:5],1'd0} + gb_lcd_data[9:5];
    wire [6:0] sum_b = hWrBurstQ[14:10] + {gb_lcd_data[14:10],1'd0} + gb_lcd_data[14:10];
/* 12.5% blend
*/
    wire [5:0]  game_r  =   frameBlendEnable ? sum_r[6:1] : {gb_lcd_data[4:0],1'b0};
    wire [5:0]  game_g  =   frameBlendEnable ? sum_g[6:1] : {gb_lcd_data[9:5],1'b0};
    wire [5:0]  game_b  =   frameBlendEnable ? sum_b[6:1] : {gb_lcd_data[14:10],1'b0};
    
    wire [17:0] psel = {game_b,game_g,game_r};

    // OSD and overlay
    reg [17:0] overlayColor;
    reg overlayActive;
    reg overlayCrush;
    
    wire overlayActive_batteryFront;
    wire overlayActive_batteryBack;
    wire overlayActive_TimerFront;
    wire overlayActive_TimerBack;
    wire overlayActive_TimerNumber;
    wire overlayActive_debug;
    
    overlayBatteryFront u_overlayBatteryFront
    (
       .screenX       (screenX),
       .screenY       (screenY),
       .overlayActive (overlayActive_batteryFront)
    );     
    
    overlayBatteryBack u_overlayBatteryBack
    (
       .screenX       (screenX),
       .screenY       (screenY),
       .overlayActive (overlayActive_batteryBack)
    ); 
    
    overlayTimerFront u_overlayTimerFront
    (
       .screenX       (screenX),
       .screenY       (screenY),
       .overlayActive (overlayActive_TimerFront)
    );     
    
    overlayTimerBack u_overlayTimerBack
    (
       .screenX       (screenX),
       .screenY       (screenY),
       .overlayActive (overlayActive_TimerBack)
    ); 
    
    reg [3:0] timePL = 4'd0;
    reg [3:0] timePH = 4'd0;
    reg [3:0] timeSL = 4'd0;
    reg [3:0] timeSH = 4'd0;
    reg [3:0] timeML = 4'd0;
    reg [3:0] timeMH = 4'd0;
    reg [3:0] timeHL = 4'd0;
    
    // Flash the low battery indicator when configured
    localparam LB_VIS_SHOW  = 2'b00;
    localparam LB_VIS_BLINK = 2'b01;
    localparam LB_VIS_HIDE  = 2'b10;
    localparam LB_VIS_RSVD  = 2'b11;

    typedef enum reg {
        LBB_HIDE = 1'b0,
        LBB_SHOW = 1'b1
    } low_batt_blink_state_t;

    low_batt_blink_state_t LBBState = LBB_HIDE;
    reg showLowBatt = 0;

    always@(posedge gClk) begin
        if (runTimer && gPercentEna) begin
            if (timePL == 4'd9) begin
               timePH <= timePH + 1'd1;
               timePL <= 4'd0;
            end else begin
               timePL <= timePL + 1'd1;
            end
        end
        
        if (runTimer && gSecondEna) begin
            timePL <= 4'd0;
            timePH <= 4'd0;
            if (timeSL == 4'd9) begin
               timeSL <= 4'd0;
               if (timeSH == 4'd5) begin
                  timeSH <= 4'd0;
                  if (timeML == 4'd9) begin
                     timeML <= 4'd0;
                     if (timeMH == 4'd5) begin
                        timeMH <= 4'd0;
                        if (timeHL == 4'd9) begin
                           timePL <= 4'd9;
                           timePH <= 4'd9;
                           timeSL <= 4'd9;
                           timeSH <= 4'd5;
                           timeML <= 4'd9;
                           timeMH <= 4'd5;
                           timeHL <= 4'd9;
                        end else begin
                           timeHL <= timeHL + 1'd1;
                        end
                     end else begin
                        timeMH <= timeMH + 1'd1;
                     end
                  end else begin
                     timeML <= timeML + 1'd1;
                  end
               end else begin
                  timeSH <= timeSH + 1'd1;
               end
            end else begin
               timeSL <= timeSL + 1'd1;
            end
        end
        
        if (resetTimer) begin
            timePL <= 4'd0;
            timePH <= 4'd0;
            timeSL <= 4'd0;
            timeSH <= 4'd0;
            timeML <= 4'd0;
            timeMH <= 4'd0;
            timeHL <= 4'd0;
        end

        if ( lowBattDispMode == LB_VIS_BLINK ) begin
            if (gSecondEna == 1) begin
                case (LBBState)
                    LBB_HIDE: begin
                        LBBState <= LBB_SHOW;
                    end

                    LBB_SHOW: begin
                        LBBState <= LBB_HIDE;
                    end
                endcase
            end

            showLowBatt <= (LBBState == LBB_SHOW);
        end else if ( lowBattDispMode == LB_VIS_HIDE ) begin
            LBBState <= LBB_HIDE;
            showLowBatt <= 0;
        end else begin
            LBBState <= LBB_HIDE;
            showLowBatt <= ((lowBattDispMode == LB_VIS_SHOW) || (lowBattDispMode == LB_VIS_RSVD));
        end


    end
    
    wire [1:0] screenXNumber = (screenX >=  4 && screenX <=  6) ? (screenX -  4) :
                               (screenX >=  8 && screenX <=  8) ? (screenX -  8) :
                               (screenX >= 10 && screenX <= 13) ? (screenX - 10) :
                               (screenX >= 14 && screenX <= 17) ? (screenX - 14) :
                               (screenX >= 18 && screenX <= 18) ? (screenX - 18) :
                               (screenX >= 20 && screenX <= 23) ? (screenX - 20) :
                               (screenX >= 24 && screenX <= 27) ? (screenX - 24) :
                               (screenX >= 28 && screenX <= 28) ? (screenX - 28) :
                               (screenX >= 30 && screenX <= 33) ? (screenX - 30) :
                               (screenX >= 34 && screenX <= 37) ? (screenX - 34) :
                               2'd3;

    wire [2:0] screenYNumber = (screenY >= 8 && screenY <= 12) ? (screenY - 8) :
                               3'd7;
   
    wire [3:0] screenNumber =  (screenX >=  4 && screenX <=  6) ? timeHL :
                               (screenX >=  8 && screenX <=  8) ? 4'd10 :
                               (screenX >= 10 && screenX <= 13) ? timeMH :
                               (screenX >= 14 && screenX <= 17) ? timeML :
                               (screenX >= 18 && screenX <= 18) ? 4'd10 :
                               (screenX >= 20 && screenX <= 23) ? timeSH :
                               (screenX >= 24 && screenX <= 27) ? timeSL :
                               (screenX >= 28 && screenX <= 28) ? 4'd11 :
                               (screenX >= 30 && screenX <= 33) ? timePH :
                               (screenX >= 34 && screenX <= 37) ? timePL :
                               4'd15;
   
    overlayTimerNumber u_overlayTimerNumber
    (
       .screenX       (screenXNumber),
       .screenY       (screenYNumber),
       .number        (screenNumber),
       .overlayActive (overlayActive_TimerNumber)
    ); 
    
    
    
   wire [1:0] debugXNumber = (screenX >=  0 && screenX <=  3) ? (screenX -  0) :
                             (screenX >=  4 && screenX <=  7) ? (screenX -  4) :
                             (screenX >=  8 && screenX <= 11) ? (screenX -  8) :
                             (screenX >= 12 && screenX <= 15) ? (screenX - 12) :
                             (screenX >= 16 && screenX <= 19) ? (screenX - 16) :
                             (screenX >= 20 && screenX <= 23) ? (screenX - 20) :
                             (screenX >= 24 && screenX <= 27) ? (screenX - 24) :
                             (screenX >= 28 && screenX <= 31) ? (screenX - 28) :
                             2'd3;

    wire [2:0] debugYNumber = (screenY >= 136) ? (screenY - 136) :
                               3'd7;
   
    wire [3:0] debugNumber =  (screenX >=  0 && screenX <=  3) ? debug_system[31:28] :
                              (screenX >=  4 && screenX <=  7) ? debug_system[27:24] :
                              (screenX >=  8 && screenX <= 11) ? debug_system[23:20] :
                              (screenX >= 12 && screenX <= 15) ? debug_system[19:16] :
                              (screenX >= 16 && screenX <= 19) ? debug_system[15:12] :
                              (screenX >= 20 && screenX <= 23) ? debug_system[11: 8] :
                              (screenX >= 24 && screenX <= 27) ? debug_system[ 7: 4] :
                              (screenX >= 28 && screenX <= 31) ? debug_system[ 3: 0] :
                              4'd15;
   
    overlayDebug u_overlayDebug
    (
       .screenX       (debugXNumber),
       .screenY       (debugYNumber),
       .number        (debugNumber),
       .overlayActive (overlayActive_debug)
    ); 
    
    
    wire osdTransparent = (hWrBurstQ2 == 16'hF81F) ? 1'd1 : 1'd0;

    always@(posedge hClk)
    begin
        overlayColor  <= {hWrBurstQ2[4:0],hWrBurstQ2[0],hWrBurstQ2[10:6],hWrBurstQ2[6],hWrBurstQ2[15:11],hWrBurstQ2[11]};
        overlayActive <= hDrawOSD & ~osdTransparent;  
        overlayCrush  <= hDrawOSD & osdTransparent;
        
        if (~hDrawOSD) begin
            if (debug_system_on && overlayActive_debug) begin
               overlayColor  <= {6'h00, 6'h00, 6'h00}; // black
               overlayActive <= 1'b1;
            end else if (debug_system_on && screenX <= 31 && screenY >= 136) begin
               overlayColor  <= {6'h3F, 6'h3F, 6'h3F}; // white
               overlayActive <= 1'b1;            
            end else if (voltageLow && showLowBatt && overlayActive_batteryFront) begin
               overlayColor  <= {6'h00, 6'h00, 6'h3F}; // red
               overlayActive <= 1'b1;
            end else if (showTimer && (overlayActive_TimerFront || overlayActive_TimerNumber)) begin
               overlayColor  <= {6'h3F, 6'h3F, 6'h3F}; // white
               overlayActive <= 1'b1;
            end else if ((voltageLow && showLowBatt && overlayActive_batteryBack) || (showTimer && overlayActive_TimerBack)) begin
               overlayCrush  <= 1'b1;
            end
        end
    end

    // High = Blue
    // Mid = Green
    // LSBs == Red

    wire hValidCorrected;
    wire hHsyncCorrected;
    wire hVsyncCorrected;
    wire [17:0] hColorPixelCorrected;
    wire [17:0] hColorPixelUVCCorrected;

    color_correction u_color_correction(
        .hClk(hClk),
        .hValid(gb_lcd_clkena),
        .hHsync(gb_lcd_mode[1]),
        .hVsync(gb_lcd_vsync),
        .hCorrectLCD(colorCorrectionEnableLCD),
        .hCorrectUVC(colorCorrectionEnableUVC),
        .hColorPixel(psel),
        .hValidCorrected(hValidCorrected),
        .hHsyncCorrected(hHsyncCorrected),
        .hVsyncCorrected(hVsyncCorrected),
        .hColorPixelCorrected(hColorPixelCorrected),
        .hColorPixelUVCCorrected(hColorPixelUVCCorrected)
    );
    
    wire [17:0] hColorPixelLCD = overlayCrush ? {2'd0,hColorPixelCorrected[17:14],2'd0,hColorPixelCorrected[11:8],2'd0,hColorPixelCorrected[5:2]} : 
                                 overlayActive ? overlayColor : hColorPixelCorrected;
                                 
    wire [17:0] hColorPixelUVC = overlayCrush ? {2'd0,hColorPixelUVCCorrected[17:14],2'd0,hColorPixelUVCCorrected[11:8],2'd0,hColorPixelUVCCorrected[5:2]} : 
                                 overlayActive ? overlayColor : hColorPixelUVCCorrected;

    ST7785_panel_master u_ST7785_panel_master(
        .gClk(gClk),
        .nRST(LCD_INIT_DONE),
        .hClk(hClk),
        .hValid(hValidCorrected),
        .hHsync(hHsyncCorrected),
        .hVsync(hVsyncCorrected),
        .hColorPixel(hColorPixelLCD),
        .hColorPixelUVC(hColorPixelUVC),

        .lcd_on(gb_lcd_on),
        .LCD_EN(LCD_EN),
        .LCD_DE(LCD_ENABLE),
        .LCD_HSYNC(LCD_HSYNC),
        .LCD_VSYNC(LCD_VSYNC),
        .LCD_GENLOCK(LCD_GENLOCK),
        .LCD_DB(LCD_DB),
        .LCD_ENABLE_UVC(LCD_ENABLE_UVC),
        .LCD_DB_UVC(LCD_DB_UVC)
    );

endmodule

module color_correction(
    input                     hClk,

    input                     hCorrectLCD,
    input                     hCorrectUVC,

    input                     hValid,
    input                     hHsync,
    input                     hVsync,
    input       [17:0]        hColorPixel,

    output  reg               hValidCorrected,
    output  reg               hHsyncCorrected,
    output  reg               hVsyncCorrected,
    output  reg [17:0]        hColorPixelCorrected,
    output  reg [17:0]        hColorPixelUVCCorrected
);

    wire [5:0] red = hColorPixel[5:0];
    wire [5:0] green = hColorPixel[11:6];
    wire [5:0] blue = hColorPixel[17:12];

    wire [9:0] r10 = (red * 'd13) + (green * 'd2) + blue; // 999
    wire [7:0] g8 = (green * 'd3) + blue; // 252
    wire [9:0] b10 = (red * 'd3) + (green * 'd2) + (blue * 'd11); // 1008

    wire [15:0] rlcd1 = red[5:1]  * 'd216  + green[5:1] * 'd30;
    wire [15:0] rlcd2 = blue[5:1] * 'd25;
    wire [15:0] rlcd3 = ( rlcd1 < rlcd2 ) ? 'd0 : rlcd1 - rlcd2;
    wire [15:0] glcd = red[5:1] * 'd39  + green[5:1] * 'd137 +  blue[5:1] * 'd24;//620 + 1054 + 217 = 1891
    wire [15:0] blcd = red[5:1] * 'd21  + green[5:1] * 'd24 +  blue[5:1] * 'd125;//620 + 1054 + 217 = 1891

    wire [5:0] blcdc = blcd[13] ? 6'h3F : blcd[12:7];
    wire [5:0] glcdc = glcd[13] ? 6'h3F : glcd[12:7];
    wire [5:0] rlcdc = rlcd3[13] ? 6'h3F : rlcd3[12:7];

    always@(posedge hClk)
    begin
        hValidCorrected <= hValid;
        hHsyncCorrected <= hHsync;
        hVsyncCorrected <= hVsync;
        hColorPixelCorrected    <= ~hCorrectLCD ? {blue, green, red} : {blcdc, glcdc, rlcdc};
        hColorPixelUVCCorrected <= ~hCorrectUVC ? {blue, green, red} : {b10[9:4], g8[7:2], r10[9:4]};
    end

endmodule