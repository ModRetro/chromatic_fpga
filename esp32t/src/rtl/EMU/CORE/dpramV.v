// dpramV.v

module dpramV #(
    parameter   addr_width  =   8,
    parameter   data_width  =   8
    )(  
    input   clock_a,
    input   ce_a,
    input   [addr_width-1:0]    address_a,
    input   [data_width-1:0]    data_a,
    input                       wren_a,
    output  reg [data_width-1:0]    q_a,
    
    input   clock_b,
    input   [addr_width-1:0]    address_b,
    input   [data_width-1:0]    data_b,
    input                       wren_b,
    output  reg [data_width-1:0]    q_b
);

    reg [data_width-1:0]    dpram [2**addr_width-1:0];
    
    always@(posedge clock_a)
        if(wren_a&ce_a)
            dpram[address_a]    <=  data_a;
            
    always@(posedge clock_a)
        if((~wren_a) & ce_a)
            q_a <=  dpram[address_a];
            

    always@(posedge clock_b)
        if(wren_b&~wren_a)
            dpram[address_b]    <=  data_b;
            
    always@(posedge clock_b)
        if(~wren_b)
            q_b <=  dpram[address_b];





endmodule
