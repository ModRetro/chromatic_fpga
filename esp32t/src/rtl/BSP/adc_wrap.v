// adc_wrap.v

module adc_wrap(
    input               clk,
    input   reset_n,
    input               hAdcReq_ext,
    output  reg [13:0]  hAdcValue_r1,
    output  reg         hAdcReady_r1,
    input   VBAT_ADC_P,
    input   VBAT_ADC_N
);

    wire hAdcReady;
    wire [13:0] hAdcValue;
    reg [1:0] hAdcState;

    always@(posedge clk)
    begin
        if((hAdcState == 2'd2)&&hAdcReady)
        begin
            hAdcReady_r1    <=  1'd1;
            hAdcValue_r1    <=  hAdcValue;
        end
        else
            hAdcReady_r1    <=  1'd0;
    end
    
    wire [7:0] mdrp_rdata_o;

    TLVDS_IBUF_ADC u_IBUF_ADC(
        .I(VBAT_ADC_P),
        .IB(VBAT_ADC_N),
        .ADCEN(1'd1)
    );


    wire adcen_i = reset_n;
    wire hAdcReq = (hAdcState == 2'd1);

    always@(posedge clk)
        if(~reset_n)
            hAdcState <= 'd0;
        else
            case(hAdcState)
            2'd0 :
                if(hAdcReq_ext)
                    hAdcState <= 2'd1;
            2'd1 : 
                if(~hAdcReady)
                    hAdcState <= 2'd2;
            2'd2 :
            begin            
                if(hAdcReady)
                hAdcState <= 2'd3;
                else
                    if(hAdcReq_ext)
                        hAdcState <= 2'd1;
            end
            2'd3 :
                hAdcState <= 2'd0;
            endcase

    reg adcen;
    always@(posedge clk or negedge reset_n)
        if(~reset_n)
            adcen <= 1'd0;
        else
            adcen <= 1'd1;
    Gowin_ADC u_Gowin_ADC (
        .clk(clk), //input clk
        .drstn(adcen_i ), //input drstn
        .adcrdy(hAdcReady), //output adcrdy
        .adcvalue(hAdcValue), //output [13:0] adcvalue
        .vsenctl(3'b010), //input [2:0] vsenctl
        .adcen(adcen), //input adcen
        .adcreqi(hAdcReq), //input adcreqi
        .adcmode(1'd1), //input adcmode 1 = Voltage, 0 = temperature
        .mdrp_clk(1'd0), //input mdrp_clk
        .mdrp_rdata(mdrp_rdata_o), //output [7:0] mdrp_rdata
        .mdrp_wdata(8'd0), //input [7:0] mdrp_wdata
        .mdrp_a_inc(1'd0), //input mdrp_a_inc
        .mdrp_opcode(2'd0) //input [1:0] mdrp_opcode
    );

endmodule
