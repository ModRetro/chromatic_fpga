module ST7785_panel_master(
    input               gClk,
    input               nRST,

    input               hClk,
    input       [17:0]  hColorPixel,
    input       [17:0]  hColorPixelUVC,
    input               lcd_on,
    input               hVsync,
    input               hHsync,
    input               hValid,
    input               LCD_EN,
    output  reg         LCD_DE,
    output  reg         LCD_HSYNC,
    output  reg         LCD_VSYNC,
    output  reg         LCD_GENLOCK,
    output  reg [5:0]   LCD_DB,
    output  reg         LCD_ENABLE_UVC,
    output  reg [17:0]  LCD_DB_UVC
);
    
    parameter       H_Lw             = 16'd30; 
    parameter       H_Pixel_Valid    = 16'd720; 
    parameter       H_FrontPorch     = 16'd129;
    parameter       H_BackPorch      = 16'd32;  

    parameter       PixelForHS       = H_Lw + H_Pixel_Valid + H_FrontPorch + H_BackPorch;
    
    parameter       V_Lw             = 16'd2;
    parameter       V_Pixel_Valid    = 16'd144;
    parameter       V_FrontPorch     = 16'd2; // was 64
    parameter       V_BackPorch      = 16'd10;

    parameter       PixelForVS       = V_Pixel_Valid + V_FrontPorch + V_BackPorch;

    reg                 gLcdOn_r1;
    reg                 gLcdOn_r2;
    always@(posedge gClk)
    begin
        gLcdOn_r1 <= lcd_on;
        gLcdOn_r2 <= gLcdOn_r1;
    end

    reg                 gVs_r1;
    reg                 gVs_r2;
    always@(posedge gClk)
    begin
        gVs_r1 <= hVsync;
        gVs_r2 <= gVs_r1;
    end

    reg hgVs_r1;
    reg hgVs_r2;
    always@(posedge hClk)
    begin
        hgVs_r1 <= hVsync;
        hgVs_r2 <= hgVs_r1;
    end
    wire hGbVsync = hgVs_r1 & ~hgVs_r2;
    
    reg [15:0] hs_sr;
    always@(posedge hClk)
        hs_sr <= {hs_sr[14:0], hHsync};
    wire gbhsync = hs_sr[15] & ~hs_sr[14];
    reg valid_r1;
    always@(posedge hClk)
        valid_r1 <= hValid;
        

    wire [17:0] color_pixeluvc;
    wire [17:0] color_pixelp;
    
    localparam DEPTH = 1024;
    reg [35:0] lineBuffer [DEPTH-1:0];
    reg [35:0]  lineBuffer_q;

    reg [9:0]   lineBuffer_wa;
    reg [7:0]   lineBuffer_wrCount;
    reg [9:0]   lineBuffer_ra;
    reg [7:0]   lineBuffer_rdCount;
    
    always@(posedge hClk)
    begin
        if(hGbVsync)
        begin
            lineBuffer_wrCount <= 'd0;
            lineBuffer_wa      <= 'd0;
        end
        else
            if(gbhsync)
                lineBuffer_wrCount <= 'd0;
            else
                if(hValid)
                    if(lineBuffer_wrCount <= 8'd159)
                    begin
                        lineBuffer_wrCount  <= lineBuffer_wrCount + 1'd1;
                        if(lineBuffer_wa < DEPTH - 1'd1)
                            lineBuffer_wa       <= lineBuffer_wa + 1'd1;
                        else
                            lineBuffer_wa       <= 'd0;
                    end
    end
    
    reg         [11:0]  H_PixelCount;
    reg         [11:0]  V_PixelCount;
    reg         [15:0]  frameCount;
    wire  LCD_DEI =    ( H_PixelCount > H_BackPorch + H_Lw ) && ( H_PixelCount <= H_Pixel_Valid + H_BackPorch + H_Lw ) && (V_PixelCount < V_Pixel_Valid + V_Lw + V_FrontPorch) && (V_PixelCount >= V_Lw + V_FrontPorch);      

    always@(posedge hClk)
        if(hValid&&(lineBuffer_wrCount <= 8'd159))
            lineBuffer[lineBuffer_wa]  <=  {hColorPixelUVC, hColorPixel};

    reg [1:0] phase;
    reg [7:0] hoffset;
    localparam OFFSET = 41;
    reg pGbVsync;
    reg pGbVsync_r1;
    wire pGbVsyncRising = pGbVsync & ~pGbVsync_r1;
    always@(posedge gClk)
    begin
        pGbVsync <= hVsync;
        pGbVsync_r1 <= pGbVsync;
    end
    
    always@(posedge gClk)
    begin
        if(pGbVsyncRising)
        begin
            lineBuffer_ra       <= 'd0;
            lineBuffer_rdCount  <= 'd0;
            phase               <= 'd2;
        end
        else
            if(~LCD_HSYNC)
            begin
                phase <= 'd2;
                hoffset <= 'd0;
                lineBuffer_rdCount <= 'd0;
            end
            else
            begin
                if(phase < 3'd2)
                    phase <= phase + 1'd1;
                else
                    phase <= 'd0;

                if((LCD_DEI) && LCD_VSYNC && (phase == 'd2))
                    if(hoffset < OFFSET)
                        hoffset <= hoffset + 1'd1;
                    
                if((LCD_DEI) && (V_PixelCount >= V_Lw + V_FrontPorch) && (phase == 'd1))
                begin
                    if(hoffset >= OFFSET)
                        if(lineBuffer_rdCount <= 8'd159)
                        begin
                            if(lineBuffer_ra < DEPTH - 1'd1)
                                lineBuffer_ra <= lineBuffer_ra + 1'd1;
                            else
                                lineBuffer_ra <= 'd0;
                            lineBuffer_rdCount <= lineBuffer_rdCount + 1'd1;
                        end
                end
            end
    end
                
    always@(posedge gClk)
        lineBuffer_q <= lineBuffer[lineBuffer_ra];

    assign color_pixeluvc = lineBuffer_q[35:18];
    assign color_pixelp = lineBuffer_q[17:0];

    localparam FINE_OFFSET = 11'd418;
    reg [10:0] fineDelay;
    // LCD scanout is several rows behind the emulator
    // Need to delay the falling edge of lcd_on
    //
    // When we get falling edge of lcd_on, scanout remaining rows
    // then enter 
    reg lcd_on_aligned;
    reg lcd_on_aligned_r1;
    reg lcd_on_aligned_r2;
    wire frameDone = (V_PixelCount >= V_Pixel_Valid + V_Lw + V_FrontPorch)&&~LCD_HSYNC;    
    always@(posedge gClk)
        if((gVs_r1 & ~gVs_r2)|(lcd_on_aligned_r1 & ~lcd_on_aligned_r2))
            fineDelay <= 'd0;
        else
            if(fineDelay != FINE_OFFSET)
                fineDelay <= fineDelay + 1'd1;

    reg delayed;
    always@(posedge gClk)
        delayed <= (fineDelay == (FINE_OFFSET - 1'd1)) ? 1'd1 : 1'd0;

    always@(posedge gClk)
    begin
        if((V_PixelCount == 0) || frameDone)
        lcd_on_aligned <= lcd_on;
        lcd_on_aligned_r1 <= lcd_on_aligned;
        lcd_on_aligned_r2 <= lcd_on_aligned_r1;
    end

    always @(posedge gClk)begin
        if( !nRST || delayed || ~lcd_on_aligned) begin
            V_PixelCount      <=  0;
            H_PixelCount      <=  'd0;
            frameCount        <=  16'd0;
        end
        else 
            if(  H_PixelCount == PixelForHS )
            begin
            V_PixelCount      <=  V_PixelCount + 1'b1;
            H_PixelCount      <=  'd0;
            end
        else if(  V_PixelCount >= (PixelForVS + V_Lw) ) begin
            V_PixelCount      <=  'd0;
            H_PixelCount      <=  'd0;
            frameCount        <=  frameCount + 1'd1;
            end
        else begin
            H_PixelCount      <=  H_PixelCount + 1'b1;
        end
    end
      
    reg LCD_DEI_r1;
    reg LCD_DEI_r2;
    reg LCD_VSYNC_r1;
    always@(posedge gClk)
    begin
        LCD_DEI_r1 <= LCD_DEI;
        LCD_DEI_r2 <= LCD_DEI_r1;
        LCD_DE <= LCD_DEI_r2;
        LCD_HSYNC <= H_PixelCount < H_Lw ? 1'b0 : 1'b1;
        LCD_VSYNC <= (V_PixelCount >= 0)&&(V_PixelCount < V_Lw)  ? 1'b0 : 1'b1;
        LCD_VSYNC_r1 <= LCD_VSYNC;
        if(LCD_VSYNC & ~LCD_VSYNC_r1)
            LCD_GENLOCK <= ~LCD_GENLOCK;

        if((hoffset >= OFFSET) && lcd_on_aligned)
        begin
            if(LCD_EN)
            begin
                if(phase == 2)
                    LCD_DB <= color_pixelp[17:12]; // Blue
                if(phase == 1)
                    LCD_DB <= color_pixelp[11:6]; // Green
                if(phase == 0)
                    LCD_DB <= color_pixelp[5:0]; // Red

                LCD_DB_UVC <= color_pixeluvc;
                LCD_ENABLE_UVC <= LCD_DEI_r2;
            end
            else
            begin
                LCD_DB          <= {6{1'b1}};
                LCD_DB_UVC      <= {18{1'b1}};
                LCD_ENABLE_UVC  <= LCD_DEI_r2;
            end
        end
        else
        begin
            LCD_DB <= 'd0;
            LCD_DB_UVC <= 'd0;
            LCD_ENABLE_UVC <= 1'd0;
        end
    end

endmodule