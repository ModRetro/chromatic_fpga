// dpramV.v .clock (clk_sys),

module dpram_difV #(
    parameter   addr_widthA =   12,
    parameter   data_widthA =   8,
    parameter   addr_widthB =   8,
    parameter   data_widthB =   8,
    parameter   init = "BootROMs/cgb_boot.hex"
    )(  
    input   clock,

    input   [addr_widthA-1:0]   address_a,
    output  reg [data_widthA-1:0]   q_a,
    
    input   [addr_widthB-1:0]   address_b,
    input   [data_widthB-1:0]   data_b,
    input                       wren_b
);

    reg [data_widthA-1:0]   myramdA [2047:0];
    
    initial
    begin
        $readmemh("BootROMs/cgb_boot.mif.vmem", myramdA);
    end

    always@(posedge clock)
        q_a <=  myramdA[address_a];
            
endmodule
