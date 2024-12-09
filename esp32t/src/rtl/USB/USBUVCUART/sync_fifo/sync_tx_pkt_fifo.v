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

module sync_tx_pkt_fifo
#(
    parameter DSIZE = 8,
    parameter ASIZE = 9
)
(
    input        CLK,
    input        RSTn,
    input        write,
    input        pktfin,
    input        txact,
    input        read,
    input  [7:0] iData,
    
    output [7:0] oData,
    output reg [ASIZE:0] wrnum,
    output       full,
    output       empty
);

reg [ASIZE:0] wp;          //write point should add 1 bit(N+1) 
reg [ASIZE:0] pkt_rp;      //write point should add 1 bit(N+1) 
reg [ASIZE:0] rp;          //read point
reg [ASIZE:0] rp_next;          //read point
reg [DSIZE - 1:0] RAM [0:(1<<ASIZE) - 1];  //deep 512, 8 bit RAM
reg [DSIZE - 1:0] oData_reg;   //regsiter of oData
reg [DSIZE - 1:0] oData_next;   //regsiter of oData
reg  txact_d0;
wire txact_rise;
wire txact_fall;
reg  req_d0;

always @ ( posedge CLK or negedge RSTn )
begin                  //write to RAM
    if (!RSTn)
    begin
        wp <= 'd0;
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
        rp_next <= 'd1;
    end
    //else if ( txact_rise ) begin
    else if ( txact_fall ) begin
        if ( read & (~empty)  ) begin
            rp <= pkt_rp + 1'b1;
        end
        else begin
            rp <= pkt_rp;
        end
    end
    else if ( read & (~empty)  ) begin
        rp <= rp + 1'b1;
        rp_next <= rp + 2'd2;
    end
end
always @ ( posedge CLK or negedge RSTn )
begin                  // read from RAM
    if (!RSTn) begin
        req_d0 <= 1'b0;
    end
    else begin
        req_d0 <= (read & (~empty));
    end
end
always @ ( posedge CLK or negedge RSTn )
begin                  // read from RAM
    if (!RSTn)
    begin
        oData_reg <= 'd0;
    end
    //else if ( read & (~empty)  ) begin
    //    oData_reg <= oData_next;
    //end
    else begin
        oData_reg <= RAM[rp[ASIZE - 1:0]];
    end
end
always @ ( posedge CLK or negedge RSTn )
begin                  // read from RAM
    if (!RSTn)
    begin
        oData_next <= 'd0;
    end
    else begin
        oData_next <= RAM[rp_next[ASIZE - 1:0]];
    end
end

always @ ( posedge CLK or negedge RSTn ) begin    // 
    if (!RSTn) begin
        txact_d0 <= 'd0;
    end
    else begin
        txact_d0 <= txact;
    end
end
assign txact_rise = txact&(!txact_d0);
assign txact_fall = txact_d0&(!txact);

always @ ( posedge CLK or negedge RSTn ) begin    // 
    if (!RSTn) begin
        pkt_rp <= 'd0;
    end
    else if (pktfin) begin
        pkt_rp <= rp;
    end
end
always @ ( posedge CLK or negedge RSTn ) begin    // 
    if (!RSTn) begin
        wrnum <= 'd0;
    end
    else begin
        //if (wp[ASIZE - 1 : 0] > pkt_rp[ASIZE - 1 : 0]) begin
        //    wrnum <= wp[ASIZE - 1 : 0] - pkt_rp[ASIZE - 1 : 0];
        //end
        if (wp[ASIZE : 0] >= pkt_rp[ASIZE : 0]) begin
            wrnum <= wp[ASIZE : 0] - pkt_rp[ASIZE : 0];
        end
        else begin
            wrnum <= {1'b1,wp[ASIZE - 1 : 0]} - {1'b0,pkt_rp[ASIZE - 1 : 0]};
        end
    end
end
assign full = ( (wp[ASIZE] ^ pkt_rp[ASIZE]) & (wp[ASIZE - 1:0] == pkt_rp[ASIZE - 1:0]) );
assign empty = ( wp == pkt_rp );
//assign oData = oData_reg;
assign oData = req_d0 ? oData_next : oData_reg;//RAM[rp[ASIZE - 1:0]];

endmodule
