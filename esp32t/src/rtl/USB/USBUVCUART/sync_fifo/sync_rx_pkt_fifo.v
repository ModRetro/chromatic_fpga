`timescale 1 ns/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: ZHANG ZEKUN
// 
// Create Date: 2019/08/22 15:01:16
// Design Name: 
// Module Name: Synchronize FIFO
// Project Name:  
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module sync_rx_pkt_fifo
#(
    parameter DSIZE = 8,
    parameter ASIZE = 9
)
(
    input        CLK,
    input        RSTn,
    input        write,
    input        pktval,
    input        rxact,
    input        read,
    input  [7:0] iData,
    
    output [7:0] oData,
    output reg [ASIZE:0] wrnum,
    output       full,
    output       empty
);

reg [ASIZE:0] wp;          //write point should add 1 bit(N+1) 
//reg [ASIZE:0] wrnum;       //write point should add 1 bit(N+1) 
reg [ASIZE:0] pkg_wp;      //write point should add 1 bit(N+1) 
reg [ASIZE:0] rp;          //read point
reg [DSIZE - 1:0] RAM [0:(1<<ASIZE) - 1];  //deep 512, 8 bit RAM
reg [DSIZE - 1:0] oData_reg;   //regsiter of oData
reg [1:0] rxact_dly;
wire rxact_rise;

always @ ( posedge CLK or negedge RSTn )
begin                  //write to RAM
    if (!RSTn)
    begin
        wp <= 'd0;
    end
    else if ( rxact_rise ) begin
        wp <= pkg_wp;
    end
    else if ( write & (~full))
    begin
        RAM[wp[ASIZE - 1:0]] <= iData;
        wp <= wp + 1'b1;
    end
end

always @ ( posedge CLK or negedge RSTn )
begin                  // read from RAM
    if (!RSTn)
    begin
        rp <= 'd0;
        oData_reg <= 'd0;
    end
    else if ( read & (~empty)  )
    begin
        oData_reg <= RAM[rp[ASIZE - 1:0]];
        rp <= rp + 1'b1;
    end
end

always @ ( posedge CLK or negedge RSTn ) begin    // 
    if (!RSTn) begin
        rxact_dly <= 'd0;
    end
    else begin
        rxact_dly <= {rxact_dly[0],rxact};
    end
end
assign rxact_rise = (rxact_dly == 2'b01);

always @ ( posedge CLK or negedge RSTn ) begin    // 
    if (!RSTn) begin
        pkg_wp <= 'd0;
    end
    else if (pktval) begin
        pkg_wp <= wp;
    end
end
always @ ( posedge CLK or negedge RSTn ) begin    // 
    if (!RSTn) begin
        wrnum <= 'd0;
    end
    else begin
        if (wp[ASIZE - 1 : 0] >= rp[ASIZE - 1 : 0]) begin
            wrnum <= wp[ASIZE - 1 : 0] - rp[ASIZE - 1 : 0];
        end
        else begin
            wrnum <= {1'b1,wp[ASIZE - 1 : 0]} - {1'b0,rp[ASIZE - 1 : 0]};
        end
    end
end

//assign full = ( pkg_wp[ASIZE] ^ rp[ASIZE] & pkg_wp[ASIZE - 1:0] == rp[ASIZE - 1:0] );
assign full = ( (wp[ASIZE] ^ rp[ASIZE]) & (wp[ASIZE - 1:0] == rp[ASIZE - 1:0]) );
assign empty = ( pkg_wp == rp );
assign oData = oData_reg;

endmodule
