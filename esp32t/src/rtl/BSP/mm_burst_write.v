// mm_burst_write.v

// Converts QSPI memory mapped transfer into a burst write to PSRAM
module mm_burst_write(
    input           QSPI_CLK,
    input           QSPI_CS,
    input   [31:0]  qAddress,
    input           qDataValid,
    input   [15:0]  qData,
    
    input           xClk,
    input           xRdEn,
    input           xRamReady,
    output  reg     xMcuReqWrite,
    
    output  [15:0]  xDout,
    output  [22:0]  xAddress
);

    assign xAddress = qAddress[22:0];

    wire fifo_empty;
    wire fifo_full;
    wire fifo_almost_full;
    fifo1k u_fifo1k(
        .Data(qData), //input [15:0] Data
        .WrReset(1'd0), //input WrReset
        .RdReset(1'd0), //input RdReset
        .WrClk(~QSPI_CLK), //input WrClk
        .RdClk(xClk), //input RdClk
        .WrEn(qDataValid), //input WrEn
        .RdEn(xRdEn | xMcuReqWrite), //input RdEn
        .Q(xDout), //output [15:0] Q
        .Almost_Full(fifo_almost_full), //output Almost_Full
        .Empty(fifo_empty), //output Empty
        // Full is on the write clock domain
        // Won't update when QSPI CS is high
        .Full(fifo_full) //output Full
    );
    
    reg [3:0] xCS_sr;
    always@(posedge xClk)
        xCS_sr <= {xCS_sr[2:0], QSPI_CS};
    
    always@(posedge xClk)
    begin
        xMcuReqWrite <= 1'd0;
        if(xCS_sr[3:2] == 2'b01)
            xMcuReqWrite <= xRamReady;      
    end
    
endmodule
