module ST7785_init #(parameter ISSIMU=0)
(
    input       clk,
    input       reset,
    output      LCD_SCK,
    output reg  LCD_CS,
    output reg  LCD_SDA_SDI,
    output reg  LCD_RST,
    output reg  LCD_INIT_DONE
);

    parameter CLK_DIV_2N = 6;

    wire clk_out_ne;
    clock_div #(
        .DIV_2N(CLK_DIV_2N)) 
    c1 (
        .clk_in(clk), 
        .reset(reset),
        .clk_out(sck),
        .clk_out_ne(clk_out_ne)
    );
    
    reg       cs;
    assign LCD_SCK = ~cs ? sck : 1'd0;

    localparam DATA_MAX_CNT = 127;
    
    wire[23:0] RESETSTART = ISSIMU ? 2000 : 0;
    wire[23:0] RESETEND   = ISSIMU ? 3000 : 80000;
    wire[23:0] DELAYMAX   = ISSIMU ? 5000 : 90000;
    wire[17:0] DELAYEND   = ISSIMU ? 18'd500 : 18'd2560;

    reg[8:0] sets[127:0] /* synthesis syn_romstyle = "distributed_rom" */;
    reg[6:0] data_cnt;
    reg[4:0] bit_cnt;
    reg[23:0] delay_cnt;

    initial begin
        $readmemb("regs.bin", sets);
    end

    always @(posedge clk or posedge reset) begin
        if(reset)
            LCD_RST <= 1'd1;
        else
            if(clk_out_ne)
                case (delay_cnt)
                    RESETSTART: LCD_RST <= 0;
                    RESETEND  : LCD_RST <= 1;
                endcase
    end

    always @(posedge clk)
        if(clk_out_ne)
            if ((data_cnt < DATA_MAX_CNT) && (delay_cnt == DELAYMAX)) 
            begin
                if (bit_cnt < 9)
                    bit_cnt <= bit_cnt + 1'd1;
                else 
                    bit_cnt <= 'd0;
            end
            else
                bit_cnt <= 'd0;
                
    reg [8:0] txdata;   
    always@(posedge clk)
        if(clk_out_ne)
            txdata <= sets[data_cnt];
        
    reg [17:0] delay_cnt2;
        
    reg [7:0] datasr;
    reg [7:0] max_cnt;
    always@(posedge clk)
    begin
        LCD_CS <= cs;
    end
    
    always@(posedge clk)
        if(clk_out_ne)
        begin
            if(delay_cnt != DELAYMAX)
            begin
                data_cnt    <= 'd0;
                datasr      <= 'd0;
                cs          <= 'd1;
                LCD_SDA_SDI <= 'd0;
                delay_cnt2   <= 'd0;
                max_cnt     <= DATA_MAX_CNT - 'd4;
            end
            else
                if(bit_cnt == 0)
                begin
                    if (data_cnt < max_cnt)     
                    begin
                        cs <= 1'd0;
                        datasr <= txdata[7:0];
                        LCD_SDA_SDI <= txdata[8];
                        data_cnt <= data_cnt + 1'd1;
                    end
                    else
                    begin
                        cs <= 1'd1;
                        if(delay_cnt2 < DELAYEND)
                            delay_cnt2 <= delay_cnt2 + 1'd1;
                        else
                            max_cnt <= DATA_MAX_CNT;
                    end
                end
                else
                begin
                    if(bit_cnt < 9)
                    begin
                        datasr <= {datasr[6:0], 1'd0};
                        LCD_SDA_SDI <= datasr[7];
                    end
                    else
                    begin
                        cs <= 1'd1;
                    end
                end
        end

    always @(posedge clk or posedge reset)
        if(reset)
            delay_cnt <= 'd0;
        else
            if(clk_out_ne)
                if (delay_cnt < DELAYMAX)
                    delay_cnt <= delay_cnt + 1'd1;

    always@(posedge clk or posedge reset)
        if(reset)
            LCD_INIT_DONE <= 1'd0;
        else
            if(data_cnt < DATA_MAX_CNT)
                LCD_INIT_DONE <= 1'd0;
            else
                LCD_INIT_DONE <= 1'd1;

endmodule

module clock_div
    #(
        parameter SIZE = 8,
        parameter DIV_2N = 1
    )
    (
        input clk_in,
        input reset,
        output reg clk_out = 'd0,
        output reg clk_out_ne,
        output reg clk_out_pe
    );

    reg [SIZE - 1:0] counter = DIV_2N - 1;

    always @(posedge clk_in) begin
        if(reset)
        begin
            counter <= 'd0;
            clk_out <= 'd0;
            clk_out_ne <= 1'd0;
            
        end
        else        
        begin
            clk_out_ne <= 1'd0;

            if (counter == 0) begin
                counter <= DIV_2N - 1;
                clk_out <= !clk_out;
                if(~clk_out)
                    clk_out_ne <= 1'd1;
            end
            else
                counter <= counter - 'd1;
        end
    end
endmodule
