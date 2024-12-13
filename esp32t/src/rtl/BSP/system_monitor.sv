// system_monitor.v

module system_monitor(
    input               clk,
    input               reset,
    input               BTN_A,
    input               BTN_B,
    input               BTN_DPAD_DOWN,
    input               BTN_DPAD_LEFT,
    input               BTN_DPAD_RIGHT,
    input               BTN_DPAD_UP,
    input               BTN_MENU, // pressed = 0
    input               BTN_SEL,
    input               BTN_START,
    // Controls external mux into ADC
    output  reg         menuDisabled,
    output  reg         ADC_SEL,
    output  reg         hAdcReq_ext,
    input               LCD_INIT_DONE,
    output  reg         LCD_PWM,
    output  reg         LCD_BACKLIGHT_INIT = 1'd0,
    input               hAdcReady_r1,
    input   [13:0]      hAdcValue_r1,
    input   [8:0]       hButtons,
    input   [6:0]       hVolume,
    input   [7:0]       pmic_sys_status,
    input               hHeadphones,
    input               gSecondEna,
    input               gHalfSecondEna,
    output  reg         low_battery,
    output  reg         LED_Green,
    output  reg         LED_Red,
    output  reg         LED_Yellow,
    output  reg [13:0]  system_control = 'd1,
    output  reg [31:0]  debug_system,
    input   [7:0]       uart_rx_data,
    input               uart_rx_val,
    input               uart_tx_busy,
    output  [7:0]       uart_tx_data,
    output              uart_tx_val
);

    wire    [6:0]   rx_address;
    wire    [79:0]  rx_data;
    wire            rx_data_val;

    reg [15:0] btnMenu_sr;
    reg btnMenu_r1;
    reg btnMenu_r2;
    
    reg [15:0] btnDown_sr;
    reg btnDown_r1;
    reg btnDown_r2;
    
    reg [15:0] btnUp_sr;
    reg btnUp_r1;
    reg btnUp_r2;
    
    reg [15:0] btnLeft_sr;
    reg btnLeft_r1;
    reg btnLeft_r2;
    
    reg [15:0] btnRight_sr;
    reg btnRight_r1;
    reg btnRight_r2;
    
    reg btnStart_r1;
    reg btnStart_r2;    
    reg btnSelect_r1;
    reg btnSelect_r2;    
    reg btnA_r1;
    reg btnA_r2;
    reg btnB_r1;
    reg btnB_r2;

    reg pressed;
    reg [3:0] brightness = 4'd3;
    reg [1:0] blockBrightnessReceive;
    
    reg request_buttons  = 1'b0;
    reg request_version  = 1'b0;
    reg updateBrightness = 1'b0;
    
    always@(posedge clk or posedge reset)
    begin
        if(reset)
            system_control <= 14'd1;
        else
        begin
            request_buttons  <= 1'b0;
            request_version  <= 1'b0;
            updateBrightness <= 1'b0;
            
            if (gHalfSecondEna) begin
               LCD_BACKLIGHT_INIT  <= 1'd1;
            end
            
            if(rx_data_val)
            begin
                if(rx_address == 7'd6) begin
                    request_version <= 1'b1;
                end
                if(rx_address == 7'd5) begin
                    if (blockBrightnessReceive == 2'd0) begin
                        brightness      <=  rx_data[13:0];
                    end else begin
                        blockBrightnessReceive <= blockBrightnessReceive - 1;
                    end
                end
                if(rx_address == 7'd4) begin
                    system_control  <=  rx_data[13:0];
                end
                if(rx_address == 7'd2) begin
                    request_buttons <= 1'b1;
                end
            end
                
            if (menuDisabled) begin     
                if((btnLeft_sr[15:0] == 16'h8000)&&~btnMenu_r2) begin
                    if(brightness >= 1)
                    begin
                        brightness <= brightness - 9'd1;
                        pressed <= 1'd0;
                        blockBrightnessReceive <= 2'd3;
                        updateBrightness <= 1'b1;
                    end
                end
                if((btnRight_sr[15:0] == 16'h8000)&&~btnMenu_r2) begin
                    if(brightness != 15)
                    begin
                        pressed <= 1'd0;
                        brightness <= brightness + 9'd1;
                        blockBrightnessReceive <= 2'd3;
                        updateBrightness <= 1'b1;
                    end
                end
            end
        end
    end

    reg menuDown = 1'b0;
    always@(posedge clk)
    begin
        if(reset) begin
            menuDisabled <= 1'b1;
        end else begin
            btnMenu_r1 <= BTN_MENU;
            btnMenu_r2 <= btnMenu_r1;
            btnMenu_sr <= {btnMenu_sr[14:0], btnMenu_r2};
            if(btnMenu_sr[15:0] == 16'h8000) begin
               menuDown <= 1'b1;
            end
            if(btnMenu_sr[15:0] == 16'h7FFF && menuDown) begin
               menuDisabled <= ~menuDisabled;
               menuDown     <= 1'b0;
            end
            
            if (btnA_r2 | btnB_r2 | btnDown_r2 | btnUp_r2 | btnLeft_r2 | btnRight_r2 | btnSelect_r2 | btnStart_r2) menuDown <= 1'b0;
            
            btnDown_r1 <= BTN_DPAD_DOWN;
            btnDown_r2 <= btnDown_r1;
            btnDown_sr <= {btnDown_sr[14:0], btnDown_r2};
                    
            btnUp_r1 <= BTN_DPAD_UP;
            btnUp_r2 <= btnUp_r1;
            btnUp_sr <= {btnUp_sr[14:0], btnUp_r2};
            
            btnLeft_r1 <= BTN_DPAD_LEFT;
            btnLeft_r2 <= btnLeft_r1;
            btnLeft_sr <= {btnLeft_sr[14:0], btnLeft_r2};
                    
            btnRight_r1 <= BTN_DPAD_RIGHT;
            btnRight_r2 <= btnRight_r1;
            btnRight_sr <= {btnRight_sr[14:0], btnRight_r2};
            
            btnSelect_r1 <= BTN_SEL;
            btnSelect_r2 <= btnSelect_r1;
            
            btnStart_r1 <= BTN_START;
            btnStart_r2 <= btnStart_r1;
            
            btnA_r1 <= BTN_A;
            btnA_r2 <= btnA_r1;
            
            btnB_r1 <= BTN_B;
            btnB_r2 <= btnB_r1;
                    
        end
    end
    
    reg [7:0] lcdcount;
    always@(posedge clk)
        if(lcdcount < 448)
            lcdcount <= lcdcount + 1'd1;
        else
            lcdcount <= 'd0;

    assign LCD_PWM = LCD_INIT_DONE&LCD_BACKLIGHT_INIT ? (lcdcount <= {brightness[3:0], 4'd0}) : 1'd0;


    // 8.388608Mhz clock -> ~119.2ns
    // 0.005s / 119.2ns = 41946
    
    localparam ADC_INTERVAL_CYCLES = 'd41946;
    reg [15:0] adc_timer;
    reg [9:0] startup_cnt;            // wait for ~4 seconds to have stable measurements
    reg signed [10:0] startup_select; // measure if AA or lithium is used, negative -> LI, positive -> AA
    reg startup_done = 1'b0;
    
    always@(posedge clk) begin
        if(adc_timer < ADC_INTERVAL_CYCLES) begin
            adc_timer <= adc_timer + 1'd1;
            hAdcReq_ext <= 'd0;
            // Toggle the mux slightly ahead of starting the measurement
            if (startup_done) begin
                ADC_SEL <= startup_select[10];
            end else if(adc_timer == ADC_INTERVAL_CYCLES - 1000) begin
                ADC_SEL <= ~ADC_SEL;
            end
        end else begin
            adc_timer <= 'd0;
            hAdcReq_ext <= 'd1;
        end
    end

   wire       bat_is_LI = startup_select[10];
   reg [21:0] volt_sum;
   reg [8:0]  volt_cnt;
   reg [13:0] volt;
   reg        transmitVolt;

   wire [13:0] VOLTAGE_FULL   = bat_is_LI ? 14'd1662 : 14'd1810; //  4.4V LI : 4.8v AA
   wire [13:0] VOLTAGE_CRIT   = bat_is_LI ? 14'd1404 : 14'd1071; //  3.7v LI : 2.8v AA
   wire [13:0] VOLTAGE_RED    = bat_is_LI ? 14'd1441 : 14'd1145; //  3.8V LI : 3.0v AA
   wire [13:0] VOLTAGE_YELLOW = bat_is_LI ? 14'd1589 : 14'd1441; //  4.2v LI : 3.8v AA

   reg dischargeFirst;
   reg blink;
   reg [2:0] secondCount;
   reg wasGreen;
    
   always@(posedge clk or posedge reset) begin

      if(reset) begin
         low_battery    <= 1'd0;
         LED_Red        <= 1'd0;
         LED_Green      <= 1'd0;
         LED_Yellow     <= 1'd0;
         dischargeFirst <= 1'd1;
         blink          <= 1'd0;
         wasGreen       <= 1'd0;
         volt           <= 14'd0;
         volt_sum       <= 22'd0;
         volt_cnt       <=  9'd0;
         startup_cnt    <= 11'd0;
         startup_select <= 11'd0;
         startup_done   <= 1'b0;
         transmitVolt   <= 1'b0;
      end else begin
      
         transmitVolt <= 1'b0;
      
         debug_system <= {1'd0 , startup_select,  6'd0, volt };
      
         if(hAdcReady_r1) begin
            if (~startup_cnt[9]) begin // wait for ~4 seconds to have stable measurements
               startup_cnt <= startup_cnt + 1'd1;
            end
         
            if (startup_done) begin // average values for determined type only
               volt_sum <= volt_sum + hAdcValue_r1;
               volt_cnt <= volt_cnt + 1;
            end else if (startup_cnt[9] && hAdcValue_r1 >= 850) begin // measure if AA or lithium is used, negative -> LI, positive -> AA
               if (ADC_SEL) begin
                  startup_select <= startup_select - 1'd1;
               end else begin
                  startup_select <= startup_select + 1'd1;
               end
            end
            
            if (startup_select > 11'sd127 || startup_select < -11'sd127) begin // determine type based on which delivered higher values for some seconds
               startup_done <= 1'b1;
            end
         end
         
         if (volt_cnt[8]) begin
            volt_sum    <= 22'd0;
            volt_cnt    <=  9'd0;
            volt        <= volt_sum[21:8];
            if (volt_sum[21:8] >= 14'd850) begin
               transmitVolt <= 1'b1;
            end
         end
         
         if (gSecondEna) blink <= ~blink;
         
         low_battery <= 1'd0;
         LED_Red     <= 1'd0;
         LED_Green   <= 1'd0;
         LED_Yellow  <= 1'd0;
         wasGreen    <= 1'd0;
         
         if (volt >= 850) begin // ~2.2V
         
            if (pmic_sys_status[2]) begin // charging
            
               dischargeFirst <= 1'd1;
            
               if(volt < VOLTAGE_FULL) begin // 4.8v AA / 4.4V LI
                  if (blink) LED_Green <= 1'd1;
               end else begin
                  LED_Green <= 1'd1;
               end
            
            end else begin
            
               dischargeFirst <= 1'd0;
         
               if(volt < VOLTAGE_CRIT) begin // 2.8v AA / 3.7v LI
                  low_battery <= 1'd1;
                  if (blink) LED_Red <= 1'd1;
               end else if(volt < VOLTAGE_RED) begin // 3.0v AA / 3.8V LI
                  low_battery <= 1'd1;
                  LED_Red <= 1'd1;
               end else if(volt < VOLTAGE_YELLOW) begin // 3.8v AA / 4.2v LI
                  if (secondCount < 5) LED_Yellow <= 1'd1;
                  if (wasGreen) dischargeFirst <= 1'd1;
               end else begin
                  if (secondCount < 5) LED_Green <= 1'd1;
                  wasGreen <= 1'd1;
               end
               
               if (dischargeFirst) begin 
                  secondCount <= 3'd0;
               end else if (gSecondEna && secondCount < 7) begin
                  secondCount <= secondCount + 1'd1;
               end
               
            end 
            
         end
      end 
   end 
    
    wire [6:0] tx_address;
    wire       write;

    wire [13:0] buttons = {
        4'd0,
        menuDisabled,
        ~BTN_MENU,
        BTN_DPAD_DOWN,
        BTN_DPAD_LEFT,
        BTN_DPAD_RIGHT,
        BTN_DPAD_UP,
        BTN_A,
        BTN_B,
        BTN_SEL,
        BTN_START
    };
    
    reg [13:0] version = {
        1'd0,  // 1 bit reserved   
        1'd0,  // 1 bit debug,
        6'd0,  // 6 bits minor version
        6'd18  // 6 bits major version
    };
    
    localparam  NUM_CH = 7;
    wire [$clog2(NUM_CH)-1:0] tx_channel;
    
    wire [NUM_CH-1:0] channelsNewDataValid = {
        ~menuDisabled | request_version,            // version info
        ~menuDisabled,                              // pmic sys status
        ~menuDisabled,                              // System Control
        ~menuDisabled | updateBrightness,           // Audio + Brightness
        ~menuDisabled | request_buttons,            // Buttons
        (~menuDisabled & transmitVolt & bat_is_LI), // Lithium
        (~menuDisabled & transmitVolt & ~bat_is_LI) // AA
    };
    
    wire [13:0] audio_brightness = {2'd0, brightness, hHeadphones, hVolume};
    wire [13:0] mic_sys_status = {6'd0 , pmic_sys_status};
    
    wire [7:0] tx_byteCount = (tx_channel == 0) ? 8'd2 : // AA
                              (tx_channel == 1) ? 8'd2 : // Lithium 
                              (tx_channel == 2) ? 8'd2 : // Buttons 
                              (tx_channel == 3) ? 8'd2 : // Audio + Brightness 
                              (tx_channel == 4) ? 8'd2 : // System Control 
                              (tx_channel == 5) ? 8'd2 : // pmic sys status 
                              (tx_channel == 6) ? 8'd2 : // version info
                              8'd1;
    
    wire [7:0] tx_bytepos;
    
    wire [7:0] tx_senddata = (tx_channel == 0 && tx_bytepos == 0) ? {2'd0, volt[13:8]} : // AA
                             (tx_channel == 0 && tx_bytepos == 1) ? volt[7:0] :
                             
                             (tx_channel == 1 && tx_bytepos == 0) ? {2'd0, volt[13:8]} : // Lithium 
                             (tx_channel == 1 && tx_bytepos == 1) ? volt[7:0] :
                             
                             (tx_channel == 2 && tx_bytepos == 0) ? {2'd0, buttons[13:8]} : // Buttons 
                             (tx_channel == 2 && tx_bytepos == 1) ? buttons[7:0] : 
                             
                             (tx_channel == 3 && tx_bytepos == 0) ? {2'd0, audio_brightness[13:8]} : // Audio + Brightness 
                             (tx_channel == 3 && tx_bytepos == 1) ? audio_brightness[7:0] :
                             
                             (tx_channel == 4 && tx_bytepos == 0) ? {2'd0, system_control[13:8]} : // System Control 
                             (tx_channel == 4 && tx_bytepos == 1) ? system_control[7:0] :
                             
                             (tx_channel == 5 && tx_bytepos == 0) ? {2'd0, mic_sys_status[13:8]} : // pmic sys status 
                             (tx_channel == 5 && tx_bytepos == 1) ? mic_sys_status[7:0]  : 
                             
                             (tx_channel == 6 && tx_bytepos == 0) ? {2'd0, version[13:8]} : // version info
                             (tx_channel == 6 && tx_bytepos == 1) ? version[7:0] : 
                             8'd0;
   
    
    wire uartDisabled;
    
    system_monitor_arbiter 
    #(
        .NUM_CH(NUM_CH)
    ) u_system_monitor_arbiter
    (
        .clk(clk),
        .reset(reset),
        .uartDisabled(uartDisabled),
        .menuDisabled(menuDisabled),
        .channelsNewDataValid(channelsNewDataValid),
        .uart_tx_busy(uart_tx_busy),
        .tx_address(tx_address),
        .tx_channel(tx_channel),
        .write_done(write_done),
        .write(write)
    );
    
    uart_packet_wrapper_tx u_uart_packet_wrapper_tx
    (
        .clk(clk),
        .reset(reset),
        .uart_tx_busy(uart_tx_busy),
        .uart_tx_data(uart_tx_data),
        .uart_tx_val(uart_tx_val),
        .uartDisabled(uartDisabled),
        .menuDisabled(menuDisabled),
        .write(write),
        .write_done(write_done),      
        .tx_address(tx_address),
        .tx_byteCount(tx_byteCount),
        .tx_bytepos(tx_bytepos),
        .tx_senddata(tx_senddata)
    );
    
    uart_packet_wrapper_rx u_uart_packet_wrapper_rx
    (
        .clk(clk),
        .reset(reset),
        .uart_rx_val(uart_rx_val),
        .uart_rx_data(uart_rx_data),
        .uartDisabled(uartDisabled),
        .rx_address(rx_address),
        .rx_data(rx_data),
        .rx_data_val(rx_data_val)
    );

endmodule
