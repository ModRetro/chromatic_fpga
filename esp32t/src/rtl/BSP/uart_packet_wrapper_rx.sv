
module uart_packet_wrapper_rx(
    input               clk,
    input               reset,
    input   [7:0]       uart_rx_data,
    input               uart_rx_val,
    input               uartDisabled,
    output  reg [6:0]   rx_address,
    output  reg [79:0]  rx_data,
    output  reg         rx_data_val
);

    localparam  RX_IDLE        =   3'd1;
    localparam  RX_ADDR        =   3'd2;
    localparam  RX_COUNT       =   3'd3;
    localparam  RX_DATA        =   3'd4;
    localparam  RX_CRC         =   3'd5;    
    localparam  RX_ERROR       =   3'd6;    

    reg [2:0] rx_state;
    reg [7:0] rx_count;
    reg [7:0] crc;
    always@(posedge clk or posedge reset)
    begin
        if(reset) begin
            rx_state <= RX_IDLE;
        end else begin
        
            rx_data_val <=  1'd0;
        
            case(rx_state)
            
                  RX_IDLE    :
                     if((uart_rx_val)&&(uart_rx_data == 8'h8F))
                        rx_state <= RX_ADDR;
                        
                  RX_ADDR    :
                     if(uart_rx_val) begin
                         rx_state <= RX_COUNT;
                         rx_address  <=  uart_rx_data[6:0];
                     end
                     
                  RX_COUNT    :
                     if(uart_rx_val) begin
                         rx_state <= RX_DATA;
                         rx_count <= uart_rx_data;
                     end
                     
                  RX_DATA   :
                     if(uart_rx_val) begin
                         if (rx_count < 8'd2) begin
                             rx_state <= RX_CRC;
                         end else begin
                             rx_count <= rx_count - 1'd1;
                         end
                         rx_data <= {rx_data[71:0], uart_rx_data};
                     end
                     
                  RX_CRC   :
                     if(uart_rx_val) begin
                        if (crc == uart_rx_data) begin
                           rx_data_val <=  1'd1;
                           rx_state    <= RX_IDLE;
                        end else begin
                           rx_state <= RX_ERROR;
                        end
                     end
                     
                  RX_ERROR :
                     rx_state    <= RX_IDLE;
                        
                  default :
                     rx_state <= RX_IDLE;
            endcase
        end
    end
    
    // CRC-8-SAE J1850 parameters
    parameter POLY = 8'h1D; // Polynomial: x^8 + x^5 + x^4 + 1
    reg [3:0] bit_count;
    
    always @(posedge clk) begin
        if (rx_state == RX_IDLE && ~uart_rx_val) begin
            crc <= 8'hFF;
            bit_count <= 4'd0;
        end else if (uart_rx_val) begin
            bit_count <= 4'd8;
            crc <= crc ^ uart_rx_data;
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