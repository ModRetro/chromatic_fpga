// mpmc.v

module mpmc(
    input xClk,
    
    // PSRAM interface
    input               xPsramReady,
    input               xPsramDone,
    output  reg         xPsramReqRead,
    output  reg         xPsramReqWrite,
    output  reg [31:0]  xMemAddress,
    output  reg [10:0]  xBurstLength,
    
    // Port 1 (MCU writes)
    input               xMcuReqWrite,
    output              xMcuActive,
    input [31:0]        xMcuAddress,
    input [10:0]        xMcuBurstLength,

    // Port 2 (Emulation reads)
    input               xGbReqRead,
    output              xGbActive,
    input [31:0]        xGbAddress,
    input [10:0]        xGbBurstLength
);

    reg [1:0]               xActiveChannel;
    assign xMcuActive   =   xActiveChannel == 2'b01;
    assign xGbActive    =   xActiveChannel == 2'b10;

    wire xGrantMCU  = xMcuReqWrite  && xPsramReady;
    // MCU gets priority in case of a tie
    wire xGrantGB   = xGbReqRead    && xPsramReady && ~xMcuReqWrite;

    always@(posedge xClk)
    begin
        xPsramReqRead   <= xGrantGB;
        xPsramReqWrite  <= xGrantMCU;
    end

    always@(posedge xClk)
        if(xGrantGB)
        begin
            xMemAddress <= xGbAddress;
            xBurstLength <= xGbBurstLength;
        end
        else
        begin
            xMemAddress <= xMcuAddress;
            xBurstLength <= xMcuBurstLength;
        end
    
    always@(posedge xClk)
    begin
        case(xActiveChannel)
            // Idle
            2'b00 : 
            begin
                if(xGrantMCU)
                    xActiveChannel <= 2'b01;
                else
                    if(xGbReqRead && xPsramReady)
                        xActiveChannel <= 2'b10;
            end
            // MCU or GB
            default :
                if(xPsramDone)
                    xActiveChannel <= 2'b00;
        endcase
    end
endmodule
