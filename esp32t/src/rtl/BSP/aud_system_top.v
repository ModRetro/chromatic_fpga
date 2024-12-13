// aud_system_top.v

module aud_system_top(
    input               gClk,
    input               hClk,
    input               reset_n,
    input   [15:0]      left,
    input   [15:0]      right,
    input               software_mute,

    output  [7:0]       volume,
    output              hHeadphones,
    output  [7:0]       pmic_sys_status,

    output              AUD_BCLK,
    output              AUD_DIN,
    input               AUD_DOUT,
    output              AUD_MCLK,
    output              AUD_RESET,
    output   reg        AUD_WCLK,
    
    inout               SCL,
    inout               SDA    
);

    reg [31:0] stereo_sr;
    reg [4:0] count;  

    reg gClkHalf;
    always@(posedge gClk)
        gClkHalf <= ~gClkHalf;

    wire [7:0] hpgpio;
    assign hHeadphones = hpgpio[1];
    
    wire mute = (software_mute | volume > 8'h76);
    
    wire [15:0] left_m =  mute ? 16'd0 : left;
    wire [15:0] right_m = mute ? 16'd0 : right;

    reg [16:0] gMonoSpeaker;
    always @(posedge gClk)
        if(reset_n)
            gMonoSpeaker <= left_m + right_m;

    always @(posedge gClkHalf or negedge reset_n) begin
        if (~reset_n) begin
            count <= 5'd0;
        end
        else 
        begin
            if (count == 5'd0) begin
                count <= 5'd31;
                AUD_WCLK <= 1'b1;
                stereo_sr <= ~hHeadphones ? {16'd0,gMonoSpeaker[16:1]} : 
                    { right_m[15:0],left_m[15:0] };
            end
            else begin
                count <= count - 1'd1;
                if(count == 5'd16)
                    AUD_WCLK <= 1'b0;
                stereo_sr <= {stereo_sr[30:0], 1'b0};
            end
        end
    end

    assign AUD_MCLK     = gClk;
    assign AUD_BCLK     = ~gClkHalf;
    assign AUD_DIN      = stereo_sr[31];
    assign AUD_RESET    = reset_n; 

    parameter I2C_DATA_WIDTH = 8;
    parameter REGISTER_WIDTH = 8;
    parameter ADDRESS_WIDTH = 7;
    
    wire    [I2C_DATA_WIDTH-1:0]     i2c_miso_data;  // output
    wire                             i2c_busy;       // output

    wire                             tlv320_init_done;
    wire                             tlv320_i2c_enable;
    wire                             tlv320_i2c_read_write;
    wire     [I2C_DATA_WIDTH-1:0]    tlv320_i2c_mosi_data;
    wire     [REGISTER_WIDTH-1:0]    tlv320_i2c_register_address;
    wire     [ADDRESS_WIDTH-1:0]     tlv320_i2c_device_address;

    wire                             pol_i2c_enable;
    wire                             pol_i2c_read_write;
    wire     [I2C_DATA_WIDTH-1:0]    pol_i2c_mosi_data;
    wire     [REGISTER_WIDTH-1:0]    pol_i2c_register_address;
    wire     [ADDRESS_WIDTH-1:0]     pol_i2c_device_address;

    wire                             i2c_enable = tlv320_init_done ? pol_i2c_enable : tlv320_i2c_enable;
    wire                             i2c_read_write = tlv320_init_done ? pol_i2c_read_write : tlv320_i2c_read_write;
    wire     [I2C_DATA_WIDTH-1:0]    i2c_mosi_data = tlv320_init_done ? pol_i2c_mosi_data : tlv320_i2c_mosi_data;
    wire     [REGISTER_WIDTH-1:0]    i2c_register_address = tlv320_init_done ? pol_i2c_register_address : tlv320_i2c_register_address;
    wire     [ADDRESS_WIDTH-1:0]     i2c_device_address = tlv320_init_done ? pol_i2c_device_address : tlv320_i2c_device_address;

    // Initializes the Audio codec
    tlv320_init u_tlv320_init(
        .pclk(hClk),
        .vb_rst(~reset_n),
        .i2c_busy(i2c_busy),
        .tlv320_init_done(tlv320_init_done),

        .i2c_enable(tlv320_i2c_enable),
        .i2c_read_write(tlv320_i2c_read_write),
        .i2c_mosi_data(tlv320_i2c_mosi_data),
        .i2c_register_address(tlv320_i2c_register_address),
        .i2c_device_address(tlv320_i2c_device_address)
    );

    polling_master u_pol_master(
        .clk(hClk),
        .rst(~reset_n),
        .i2c_busy(i2c_busy),
        .enable(tlv320_init_done),
        .mute(software_mute),
        
        .volume(volume),
        .gpio(hpgpio),
        .pmic_sys_status(pmic_sys_status),

        .i2c_enable(pol_i2c_enable),
        .i2c_miso_data(i2c_miso_data),
        .i2c_read_write(pol_i2c_read_write),
        .i2c_mosi_data(pol_i2c_mosi_data),
        .i2c_register_address(pol_i2c_register_address),
        .i2c_device_address(pol_i2c_device_address)
    );

    i2c_master #(
        .DATA_WIDTH(I2C_DATA_WIDTH),
        .REGISTER_WIDTH(REGISTER_WIDTH),
        .ADDRESS_WIDTH(ADDRESS_WIDTH)
    )
    i2c_master_inst(
        .clock                  (hClk),
        .reset_n                (reset_n),
        .enable                 (i2c_enable),
        .read_write             (i2c_read_write),
        .mosi_data              (i2c_mosi_data),
        .register_address       (i2c_register_address),
        .device_address         (i2c_device_address),
        .divider                (16'd20),

        .miso_data              (i2c_miso_data),
        .busy                   (i2c_busy),

        .external_serial_data   (SDA),
        .external_serial_clock  (SCL)
    );
    

endmodule
