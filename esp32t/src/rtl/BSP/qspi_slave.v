// QSPI_Slave.v

module QSPI_Slave(
    input               QSPI_CLK,
    input               QSPI_CS,
    input               QSPI_MOSI,
    input               QSPI_MISO,
    input               QSPI_WP,
    input               QSPI_HD,
    
    output              qMenuInit,
    output              qDataValid,
    output      [15:0]  qData,
    output  reg [31:0]  qAddress = 'd0,
    output  reg [9:0]   qLength = 'd0,
    output  reg         qCommand = 'd0
);

    reg qAddReady = 'd0;
    reg qLenReady = 'd0;

    reg [3:0] qPins_r1 = 'd0;
    reg [7:0] qDataByte = 'd0;
    reg qCyclePhase = 'd0;

    reg qValid = 'd0;
    wire [3:0] qPins = {
                    QSPI_HD,
                    QSPI_WP,
                    QSPI_MISO,
                    QSPI_MOSI};

    reg [7:0] qCycleCount = 'd0;

    reg qMenuInit1 = 1'd0;
    reg qMenuInit2 = 1'd0;
    assign qMenuInit = qMenuInit2;

    always@(posedge QSPI_CLK or posedge QSPI_CS)
    begin
        if(QSPI_CS)
        begin
            qCyclePhase <= 1'd0;
            qValid      <= 1'd0;
            qCycleCount <= 1'd0;
            qCommand    <= 1'd0;
            qAddReady   <= 1'd0;
            qLenReady   <= 1'd0;
        end
        else
        begin
            if(qCycleCount <= 50)
                qCycleCount   <= qCycleCount + 1'd1;
            
            // Command
            if(qCycleCount == 0)
                qCommand <= QSPI_MOSI;

            if((qCycleCount >= 1) && (qCycleCount <= 10))
                qLength <= {qLength[8:0], QSPI_MOSI};
                
            if((qCycleCount >= 11) && (qCycleCount <= 42))
                qAddress <= {qAddress[30:0], QSPI_MOSI};
                
            if(qCycleCount == 11)
                qLenReady <= 1'd1;
            else
                qLenReady <= 1'd0;

            if(qCycleCount == 43)
            begin
                qAddReady <= 1'd1;
                if(qAddress == 0) // first row
                begin
                    qMenuInit1  <=  1'd1;
                    if(qMenuInit1)
                        qMenuInit2 <= 1'd1;
                end
            end
            else
                qAddReady <= 1'd0;
                
            // QSPI data
            if(qCycleCount >= 46)
            begin
                qCyclePhase      <= ~qCyclePhase;
                if(qCyclePhase)
                begin
                    qDataByte   <= {qPins_r1,qPins};
                    qValid      <= 1'd1;
                end
                else
                begin
                    qPins_r1    <= qPins;
                    qValid      <= 1'd0;
                end
            end
        end
    end

    reg [7:0] qDataByte_r1 = 'd0;
    reg QSPI_VALID_phase = 'd0;
    always@(posedge QSPI_CLK or posedge QSPI_CS)
        if(QSPI_CS)
            QSPI_VALID_phase <= 'd0;
        else
            if(qValid)
            begin
                qDataByte_r1 <= qDataByte;
                QSPI_VALID_phase <= ~QSPI_VALID_phase;
            end

    assign qDataValid = qValid&QSPI_VALID_phase;
    assign qData = {qDataByte,qDataByte_r1};

endmodule
