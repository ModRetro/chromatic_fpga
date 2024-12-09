// tlv320_init.v
// Contains a ROM with a default register set, masters I2C controller

module tlv320_init#(
    parameter I2C_DATA_WIDTH = 8,
    parameter REGISTER_WIDTH = 8,
    parameter ADDRESS_WIDTH = 7

)(
    input                                   pclk,
    input                                   vb_rst,
    input                                   i2c_busy,
    
    output  reg                             tlv320_init_done,
    output  reg                             i2c_enable,
    output  reg                             i2c_read_write,
    output  reg     [I2C_DATA_WIDTH-1:0]    i2c_mosi_data,
    output  reg     [REGISTER_WIDTH-1:0]    i2c_register_address,
    output  reg     [ADDRESS_WIDTH-1:0]     i2c_device_address
    
);

    localparam numregs = 64; 
    localparam numregsactual = 64; 
    reg [15:0] tlv320regs [numregs-1:0] /* synthesis syn_romstyle = "distributed_rom" */;
    initial
    begin
        $readmemh("tlv320regs.hex", tlv320regs);
    end

    reg [7:0] scount;
    reg [7:0] regindex;
    reg [23:0] regvalue;
    always@(posedge pclk)
        regvalue <= tlv320regs[regindex];
        
    always@(posedge pclk)
    begin
        if(vb_rst)
        begin
            scount               <= 'd0;
            i2c_read_write       <= 'd0;
            i2c_register_address <= 'd0;
            i2c_mosi_data        <= 'd0;
            i2c_device_address   <= 'd0;
            i2c_enable           <= 'd0;
            regindex             <= 'd0;
            tlv320_init_done     <= 'd0;
        end
        else
            case(scount)
            0:
            begin
                i2c_read_write       <= 'd0;
                i2c_register_address <= regvalue[15:8];
                i2c_mosi_data        <= regvalue[7:0];
                i2c_device_address   <= 7'h18;
                i2c_enable           <= 'd0;
                scount               <= scount + 1'd1;
            end
            1:
                // if master is not busy start a write
                if(~i2c_busy)
                begin
                    i2c_enable           <= 'd1;
                    scount               <= scount + 1'd1;
                end
            2:
                // once busy set enable low
                if(i2c_busy)
                begin
                    i2c_enable           <= 'd0;
                    scount               <= scount + 1'd1;
                end
            3:
                // if master is not busy start next write
                if(~i2c_busy)
                begin
                    if(regindex < numregsactual)
                    begin
                        scount               <= 'd0;
                        regindex             <= regindex + 1'd1;
                    end
                    else
                        tlv320_init_done     <= 1'd1;
                end
            endcase
    end

endmodule