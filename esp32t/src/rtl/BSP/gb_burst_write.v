// gb_burst_write.v

// Converts GB video data into a burst write to PSRAM
module gb_burst_write(
    input               hClk,
    input               hVsync,
    input               hNewLine,
    input   [22:0]      hAddress,
    input               hWrite,
    input   [15:0]      hData,
                        
    input               xClk,
    input               xRdEn,
    input               xRamReady,
    output  reg         xMcuReqWrite,
                        
    output  [15:0]      xDout,
    output  reg [22:0]  xAddress
);

    reg hLineToggle = 0;
    reg hRamReady = 0;

    always@(posedge hClk)
    begin
        if (hNewLine) begin
            hRamReady   <= xRamReady;
            hLineToggle <= ~hLineToggle;
        end
    end

    reg hVsync_r1;
    always@(posedge hClk)
        hVsync_r1 <= hVsync;
        
    wire fifo_rst = ~hVsync_r1 & hVsync;

    wire fifo_empty;
    wire fifo_full;
    wire fifo_almost_full;
    fifo1k u_fifo1k(
        .Data(hData), //input [15:0] Data
        .WrReset(fifo_rst), //input WrReset
        .RdReset(fifo_rst), //input RdReset
        .WrClk(hClk), //input WrClk
        .RdClk(xClk), //input RdClk
        .WrEn(hWrite & hRamReady), //input WrEn
        .RdEn(xRdEn | xMcuReqWrite), //input RdEn
        .Q(xDout), //output [15:0] Q
        .Almost_Full(fifo_almost_full), //output Almost_Full
        .Empty(fifo_empty), //output Empty
        // Full is on the write clock domain
        // Won't update when QSPI CS is high
        .Full(fifo_full) //output Full
    );
    
    reg [3:0] xLine_sr;
    always@(posedge xClk)
        xLine_sr <= {xLine_sr[2:0], hLineToggle};
    
    always@(posedge xClk)
    begin
        xMcuReqWrite <= 1'd0;
        if(xLine_sr[3] != xLine_sr[2]) begin
            xMcuReqWrite <= xRamReady && (~fifo_empty);
            xAddress     <= hAddress[22:0];
        end
    end
    
endmodule
