
module uart_packet_wrapper_tx(
    input               clk,
    input               reset,
    input               uart_tx_busy,
    output  reg [7:0]   uart_tx_data,
    output  reg         uart_tx_val,
    output              write_done,
    input               write,
    input               menuDisabled,
    input               uartDisabled,
    input       [6:0]   tx_address,
    input       [7:0]   tx_byteCount,
    output reg  [7:0]   tx_bytepos,
    input       [7:0]   tx_senddata
);

    // Extra rate limiter between UART bytes
    reg [3:0] cnt = 'd0;
    always@(posedge clk)
        cnt <= cnt + 1'd1;

    localparam  TX_IDLE        =   4'd1;
    localparam  TX_ADDR        =   4'd2;
    localparam  TX_COUNT       =   4'd3;
    localparam  TX_DATA        =   4'd4;
    localparam  TX_CRC         =   4'd5;
    localparam  TX_DONE        =   4'd6;
    localparam  TX_SLEEP       =   4'd7;
    localparam  TX_AWAKE       =   4'd8;
    localparam  TX_START       =   4'd9;

    reg [4:0] tx_state;
    reg [7:0] bytecount;
    
    always@(posedge clk or posedge reset) begin
        if(reset)
            tx_state <= TX_IDLE;
        else begin
            if(uartDisabled)
                tx_state <= TX_IDLE;
            else begin
                case(tx_state)
                    
                    TX_IDLE    :
                        if (menuDisabled) begin
                           tx_state <= TX_SLEEP;
                        end else if(~uart_tx_busy&&write) begin
                            tx_state <= TX_ADDR;
                        end
                            
                    TX_ADDR    :
                        if((~uart_tx_busy)&&(cnt == 'd0))
                            tx_state <= TX_COUNT;       
                            
                    TX_COUNT    :
                        if((~uart_tx_busy)&&(cnt == 'd0)) begin
                            bytecount     <= tx_byteCount;
                            tx_bytepos    <= 8'd0;
                            tx_state <= TX_DATA;
                        end
                           
                    TX_DATA   :
                        if((~uart_tx_busy)&&(cnt == 'd0)) begin
                            if (bytecount == 8'd1) begin
                                tx_state <= TX_CRC; 
                            end else begin
                                bytecount  <= bytecount - 1'd1;
                                tx_bytepos <= tx_bytepos + 1'd1;
                            end
                        end
                            
                    TX_CRC   :
                        if((~uart_tx_busy)&&(cnt == 'd0))
                            tx_state <= TX_DONE;
                            
                    TX_DONE   :
                        if((~uart_tx_busy)&&(cnt == 'd0))
                            tx_state <= TX_IDLE;
                         
                    TX_SLEEP :
                        if(~uart_tx_busy&&write) begin
                            tx_state <= TX_AWAKE;
                            bytecount <= 8'd20; // test show about 15 bytes are lost after sleep
                        end
                            
                    TX_AWAKE   :
                        if((~uart_tx_busy)&&(cnt == 'd0)) begin
                            if (bytecount == 8'd1) begin
                                tx_state <= TX_START; 
                            end else begin
                                bytecount  <= bytecount - 1'd1;
                            end
                        end
                        
                    TX_START:
                        if((~uart_tx_busy)&&(cnt == 'd0))
                            tx_state <= TX_ADDR;
                         
                    default :
                        tx_state <= TX_IDLE;
                endcase
            end
        end
    end
    
    always@(posedge clk) 
    begin
        uart_tx_val <=  1'd0;
        if(~uart_tx_busy&~uartDisabled) begin
            if(tx_state == TX_IDLE | tx_state == TX_SLEEP) begin
                uart_tx_val <= write;
            end else begin
                if((cnt == 'd0)&&(tx_state != TX_DONE)) begin
                    uart_tx_val <=  1'd1;
                end
            end
        end
    end
    
    assign write_done = tx_state == TX_DONE && (~uart_tx_busy)&&(cnt == 'd0);
    
    reg [7:0] crc;
    
    always@(posedge clk)
    begin
        case(tx_state)
            TX_IDLE:       uart_tx_data    <=  8'h8F; //Magic header
            TX_ADDR:       uart_tx_data    <=  {1'd0,tx_address[6:0]};
            TX_COUNT:      uart_tx_data    <=  tx_byteCount;
            TX_DATA:       uart_tx_data    <=  tx_senddata;
            TX_CRC:        uart_tx_data    <=  crc;
            TX_SLEEP:      uart_tx_data    <=  8'h00;
            TX_AWAKE:      uart_tx_data    <=  8'h00;
            TX_START:      uart_tx_data    <=  8'h8F; //Magic header
            default:       uart_tx_data    <=  8'hCA;
        endcase
    end
    
    // CRC-8-SAE J1850 parameters
    parameter POLY = 8'h1D; // Polynomial: x^8 + x^5 + x^4 + 1
    reg [3:0] bit_count;
    
    always @(posedge clk) begin
        if (tx_state == TX_IDLE && ~write) begin
            crc <= 8'hFF;
            bit_count <= 4'd0;
        end else if (uart_tx_val && tx_state != TX_SLEEP && tx_state != TX_AWAKE && tx_state != TX_START) begin
            bit_count <= 4'd8;
            crc <= crc ^ uart_tx_data;
        end else if (bit_count > 0) begin
            bit_count <= bit_count - 1'd1;
            if (crc[7]) begin
                crc <= {crc[6:0], 1'b0} ^ POLY;
            end else begin
                crc <= {crc[6:0], 1'b0};
            end
        end
    end
    

endmodule
