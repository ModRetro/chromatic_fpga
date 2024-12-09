// vid_tpg.v

module vid_tpg(
    input               hclk,
    input               reset,
    output  reg [14:0]  color_pixel,
    output  reg         vs,
    output  reg         hs,
    output  reg         valid,
    
    output  reg         hGBNewLine,
    output  reg [22:0]  hGBAddress,
    output  reg         hGBWrite
);

    reg [11:0] xcounter;
    reg [11:0] ycounter;
    reg [1:0] frameCnt; 
    
    always@(posedge hclk) begin : Timing
        hGBWrite   <= 1'b0;
        hGBNewLine <= 1'b0;
    
        if(reset)
        begin
            xcounter <= 'd0;
            ycounter <= 'd0; 
            frameCnt <= 'd0;       
        end
        else
        begin
            if(xcounter < 1824-1)
                xcounter <= xcounter + 1'd1;
            else
            begin
                hGBAddress <= hGBAddress + 320;
                xcounter   <= 'd0;
                if(ycounter < 154)
                    ycounter <= ycounter + 1'd1;
                else begin
                    ycounter <= 'd0;
                    frameCnt <= frameCnt + 1;
                    if (frameCnt == 2) frameCnt <= 'd0;
                    hGBAddress <= 23'h010000;
                end
            end
        end
        
        if (valid)
            hGBWrite   <= 1'b1;
        
        if (xcounter == 640 && ycounter < 144)
            hGBNewLine <= 1'b1;
    end

    always@(posedge hclk)
    begin
        case (frameCnt)
            0 : color_pixel <= {5'b0, 5'b0, ycounter[4:0]};//gb_lcd_data;
            1 : color_pixel <= {5'b0, ycounter[4:0], 5'b0};//gb_lcd_data;
            2 : color_pixel <= {ycounter[4:0], 5'b0, 5'b0};//gb_lcd_data;
        endcase
        
        vs <= ycounter == 12'd153;//gb_lcd_vsync;
        hs <= xcounter < 1006;//gb_lcd_mode[1];
        valid <= (xcounter >= 1) && (xcounter <= 640) && xcounter[0] && xcounter[1] && (ycounter < 144);//gb_lcd_clkena;
    end

endmodule
