//
// video.v
//
// Gameboy for the MIST board https://github.com/mist-devel
//
// Copyright (c) 2015 Till Harbaum <till@harbaum.org>
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

module videoBypass (
    input  reset,
    input  clk,
    input  ce, // 4 Mhz cpu clock
    input  ce_cpu, // 4 or 8Mhz
    input  isGBC,
    input  isGBC_mode,
    input  megaduck,

    input  boot_rom_en,
    input  paletteOff,

    // cpu register adn oam interface
    input  cpu_sel_oam,
    input  cpu_sel_reg,
    input [7:0] cpu_addr,
    input  cpu_wr,
    input [7:0] cpu_di,

    // output to lcd
    output lcd_on,
    output lcd_clkena,
    output [14:0] lcd_data,
    output lcd_vsync,
	output overwrite,
	output vsync_overwrite,

    // vram connection
	input  [1:0] mode_real,
    output [1:0] mode
);

wire [7:0] oam_do;
wire [10:0] sprite_addr;

wire sprite_found;
wire [7:0] sprite_attr;
wire [3:0] sprite_index;

wire oam_eval_end;

// $ff40 LCDC
reg [7:0] lcdc;
wire lcdc_on               = megaduck ? lcdc[7] : lcdc[7];
wire lcdc_win_tile_map_sel = megaduck ? lcdc[3] : lcdc[6];
wire lcdc_win_ena          = megaduck ? lcdc[5] : lcdc[5];

// ff41 STAT
reg [7:0] stat_r;
// DMG STAT bug: IRQs are enabled for 1 cycle during a write
wire [7:0] stat = (cpu_sel_reg & cpu_wr & cpu_addr == 8'h41 & ~isGBC) ? 8'hFF : stat_r;

// ff42, ff43 background scroll registers
reg [7:0] scy;
reg [7:0] scx;

// ff44 line counter
reg [6:0] h_cnt;            // 0-113 at 1MHz
reg [1:0] h_div_cnt;        // Divide by 4
reg [7:0] v_cnt;            // max 153
wire [7:0] ly = v_cnt;

// ff45 line counter compare
reg [7:0] lyc_r_dmg, lyc_r_gbc;
wire [7:0] lyc = (isGBC ? lyc_r_gbc : lyc_r_dmg);
wire lyc_match = (ly == lyc);

reg [7:0] bgp;
reg [7:0] obp0;
reg [7:0] obp1;

reg [7:0] wy;
reg [7:0] wx;

//ff68-ff6A GBC
//FF68 - BCPS/BGPI  - Background Palette Index
reg [5:0] bgpi; //Bit 0-5   Index (00-3F)
reg bgpi_ai;    //Bit 7     Auto Increment  (0=Disabled, 1=Increment after Writing)

//FF69 - BCPD/BGPD - Background Palette Data
reg[7:0] bgpd [63:0]; //64 bytes

//FF6A - OCPS/OBPI - Sprite Palette Index
reg [5:0] obpi; //Bit 0-5   Index (00-3F)
reg obpi_ai;    //Bit 7     Auto Increment  (0=Disabled, 1=Increment after Writing)

//FF6B - OCPD/OBPD - Sprite Palette Data
reg[7:0] obpd [63:0]; //64 bytes

//FF6C Bit 0 OBJ priority mode select
// 0: smaller OBJ-NO has higher priority (GBC)
// 1: smaller X coordinate has higher priority (DMG)
// https://forums.nesdev.org/viewtopic.php?t=19888
reg ff6c_opri;
reg obj_prio_dmg_mode;


reg lcdc_on_1  = 1'b0;
reg reset_now  = 1'b0;
reg [3:0] reset_count  = 4'd0;

parameter RESET_OFF           = 3'b000;
parameter RESET_WAITVSYNC     = 3'b001;
parameter RESET_WAITVSYNCREAL = 3'b010;
parameter RESET_WAITSTARTREAL = 3'b011;
parameter RESET_WAITCE        = 3'b100;
parameter RESET_WAITVSYNCEND  = 3'b101;
reg[2:0] reset_state = RESET_OFF;

// switch enable
always @(posedge clk) begin

	if (reset) begin
		lcdc_on_1      <= 1'b0;
      reset_now      <= 1'b0;
      reset_state    <= RESET_OFF;
	end else begin
   
      if (ce) lcdc_on_1 <= lcdc_on;
      
      if (ce) reset_count <= reset_count + 1'd1;
      
      case (reset_state)
         RESET_OFF           : if (~lcdc_on_1 && lcdc_on)    begin reset_state <= RESET_WAITVSYNC;     end
         RESET_WAITVSYNC     : if (lcd_vsync)                begin reset_state <= RESET_WAITVSYNCREAL; reset_now <= 1'b1; end
         RESET_WAITVSYNCREAL : if (mode_real == 2'b01)       begin reset_state <= RESET_WAITSTARTREAL; end
         RESET_WAITSTARTREAL : if (ce && mode_real == 2'b10) begin reset_state <= RESET_WAITCE;        end
         RESET_WAITCE        : if (ce)                       begin reset_state <= RESET_WAITVSYNCEND;  reset_now <= 1'b0; end
         RESET_WAITVSYNCEND  : if (mode_real == 2'b00)       begin reset_state <= RESET_OFF;           end
      endcase
      
	end
end

assign overwrite = (reset_state == RESET_WAITVSYNC || reset_state == RESET_WAITVSYNCREAL || reset_state == RESET_WAITSTARTREAL) ? 1'b1 : 1'b0;

assign vsync_overwrite = (reset_state == RESET_WAITVSYNCREAL || reset_state == RESET_WAITSTARTREAL) ? 1'b1 : 1'b0;
assign lcd_on          = ((reset_state == RESET_WAITVSYNCREAL || reset_state == RESET_WAITSTARTREAL) && reset_count > 0) ? 1'b0 : 1'b1; 

// --------------------------------------------------------------------
// ------------------------------- IRQs -------------------------------
// --------------------------------------------------------------------
//
// "The interrupt is triggered when transitioning from "No conditions met" to
// "Any condition met", which can cause the interrupt to not fire."
//
// Example: Altered Space enables OAM+Hblank+Vblank interrupt and requires the
// interrupt to trigger only on a Mode 3 to Hblank transition.
// OAM follows immediately after Hblank/Vblank so no OAM interrupt is triggered.

wire h_clk_en     = (lcd_on && h_div_cnt == 2'd0);
wire h_clk_en_neg = (lcd_on && h_div_cnt == 2'd2);

wire hcnt_end = (h_cnt == 7'd113);
wire vblank  = (v_cnt >= 144);

reg vblank_l, vblank_t;
reg end_of_line, end_of_line_l;
reg lyc_match_l, lyc_match_t;

always @(posedge clk) begin
    if (reset) begin
        vblank_l       <= 1'b0;
        end_of_line    <= 1'b0;
        end_of_line_l  <= 1'b0;
        vblank_t       <= 1'b0;
	end else if (reset_now) begin // reset only when LCD is turned back on
        vblank_l       <= 1'b0;
        end_of_line    <= 1'b0;
        end_of_line_l  <= 1'b0;
        vblank_t       <= 1'b0;
    end else if (ce) begin
        vblank_l <= vblank_t;

        if (h_clk_en_neg & hcnt_end)
            end_of_line <= 1'b1;
        else if (end_of_line) begin
            // Vblank is latched a few cycles after line end.
            // This causes an OAM interrupt at the beginning of line 144.
            // It also makes the OAM interrupt at line 0 after Vblank a few cycles late.
            if (h_clk_en) begin
                vblank_t <= vblank;
            end
            // end_of_line is active for 4 cycles
            if (h_clk_en_neg) begin
                end_of_line <= 1'b0;
            end
        end

        end_of_line_l <= end_of_line;
    end
end

always @(posedge clk) begin
    if (reset) begin
        lyc_match_l <= 1'b0; // lyc_match_l does not reset when lcd is off
        lyc_match_t <= 1'b0;
    end else if (ce) begin
        lyc_match_l <= lyc_match_t;

        if (h_clk_en) begin
            lyc_match_t <= lyc_match;
            if (lyc_match_t & ~lyc_match & ~isGBC) begin // DMG: lyc_match falling edge must be 1 cycle faster to pass Wilbertpol LYC tests.
                lyc_match_l <= lyc_match;
            end
        end
    end
end

wire pcnt_reset, pcnt_end;
wire lcd_clk;
reg [7:0] pcnt;
wire mode3_end = (lcd_clk & pcnt == 8'd167) | pcnt_end;

reg mode3_end_l;

always @(posedge clk) begin
    if (reset) begin
        mode3_end_l <= 1'b0;
	end else if (reset_now) begin // reset only when LCD is turned back on
        mode3_end_l <= 1'b0;
    end else if (ce) begin
        if (pcnt_reset)
            mode3_end_l <= 1'b0;
        else
            mode3_end_l <= mode3_end;
    end
end

wire int_lyc = (stat[6] & lyc_match_l);
wire int_oam = (stat[5] & end_of_line_l & ~vblank_l);
wire int_vbl = (stat[4] & vblank_l);
wire int_hbl = (stat[3] & mode3_end_l & ~vblank_l);

assign irq = (int_lyc | int_oam | int_hbl | int_vbl);
assign vblank_irq = vblank_l;

wire oam_eval;
wire mode3   = lcd_on & ~mode3_end_l;// & oam_eval_end;

reg mode3_l, oam_eval_l;

// Delay mode 2/3 to pass Mooneye/Wilbertpol Lcd on timing tests.
// The CPU cannot read from OAM/VRAM 1 cycle before Mode 2/3 is read
always @(posedge clk) begin
    if (reset) begin
        mode3_l    <= 1'b0;
        oam_eval_l <= 1'b0;
	end else if (reset_now) begin // reset only when LCD is turned back on
        mode3_l    <= 1'b0;
        oam_eval_l <= 1'b0;
    end else if (ce) begin
        mode3_l    <= mode3;
        oam_eval_l <= oam_eval;
    end
end

// DMG: STAT reads mode 0 for 1 Tcycle between Vblank and mode 2
// but the interrupt signals of Vblank and mode 2 do overlap
wire mode_vblank = isGBC ? vblank_l : (vblank_l & vblank_t);

assign mode = 
    mode_vblank          ? 2'b01 :
    oam_eval_l           ? 2'b10 :
    mode3_l & ~mode3_end ? 2'b11 :
                           2'b00;

assign oam_cpu_allow = ~(oam_eval | mode3);
assign vram_cpu_allow = ~mode3;

// --------------------------------------------------------------------
// --------------------- CPU register interface -----------------------
// --------------------------------------------------------------------

// Use negedge on some registers to pass tests
always @(negedge clk) begin
    if(reset) begin
        lcdc      <= 8'h00;  // screen must be off since dmg rom writes to vram
        lyc_r_dmg <= 8'h00;
    end else if (ce_cpu) begin
        if(cpu_sel_reg && cpu_wr) begin
            case(cpu_addr)
                8'h40:  lcdc <= cpu_di;
                8'h45:  lyc_r_dmg <= cpu_di;
            endcase
        end
    end

end

always @(posedge clk) begin

    if(reset) begin
    
        scy       <= 8'h00;
        scx       <= 8'h00;
        wy        <= 8'h00;
        wx        <= 8'h00;
        stat_r    <= 8'h00;
        bgp       <= 8'hfc;
        obp0      <= 8'hff;
        obp1      <= 8'hff;                              
        bgpi      <= 6'h0;
        obpi      <= 6'h0;
        bgpi_ai   <= 1'b0;
        obpi_ai   <= 1'b0;
        lyc_r_gbc <= 8'h00;
        ff6c_opri <= 1'b0;
        obj_prio_dmg_mode <= 1'b0;

    end else if (ce_cpu) begin
        if(cpu_sel_reg && cpu_wr) begin
            case(cpu_addr)
                8'h41:  stat_r <= cpu_di;
                8'h42:  scy <= cpu_di;
                8'h43:  scx <= cpu_di;
                8'h45:  lyc_r_gbc <= cpu_di;
                8'h47:  bgp <= cpu_di;
                8'h48:  obp0 <= cpu_di;
                8'h49:  obp1 <= cpu_di;
                8'h4a:  wy <= cpu_di;
                8'h4b:  wx <= cpu_di;
            endcase

            //gbc
            if (isGBC) case(cpu_addr)
                8'h68: begin
                            bgpi <= cpu_di[5:0];
                            bgpi_ai <= cpu_di[7];
                         end
                8'h69: if (isGBC_mode) begin
                            if (vram_cpu_allow) begin
                                bgpd[bgpi] <= cpu_di;
                            end
                            //"Writing to FF69 during rendering still causes auto-increment to occur."
                            if (bgpi_ai) bgpi <= bgpi + 6'h1;
                         end
                8'h6A: begin
                            obpi <= cpu_di[5:0];
                            obpi_ai <= cpu_di[7];
                         end
                8'h6B: if (isGBC_mode) begin
                            if (vram_cpu_allow) begin
                                obpd[obpi] <= cpu_di;
                            end
                            if (obpi_ai) obpi <= obpi + 6'h1;
                         end
                8'h6C: begin
                            // Reportedly can be written to when boot rom is enabled or FF4C Bit2=0 (GBC mode)
                            // but only affects OBJ prio if written when boot rom is enabled.
                            if (boot_rom_en | isGBC_mode) begin
                                ff6c_opri <= cpu_di[0];
                            end
                            if (boot_rom_en) obj_prio_dmg_mode <= cpu_di[0];
                        end
            endcase
        end
    end
end

// --------------------------------------------------------------------
// -------------- counters & background tilemap address----------------
// --------------------------------------------------------------------

reg skip_done;
reg [2:0] skip_cnt;
wire sprite_fetch_hold;
wire bg_shift_empty;
wire skip_end = (skip_cnt == scx[2:0] || &skip_cnt);
wire skip_en = ~skip_done & ~skip_end;

assign pcnt_end = ( pcnt == 8'd168 );
assign pcnt_reset = h_clk_en & end_of_line & ~vblank;

always @(posedge clk) begin
    if (reset) begin
        skip_cnt  <= 3'd0;
        pcnt      <= 8'd0;
        skip_done <= 1'd0;
	end else if (reset_now) begin // reset only when LCD is turned back on
        skip_cnt <= 3'd0;
        pcnt     <= 8'd0;
        skip_done <= 1'b0;
    end else if (ce) begin
        // Only skip when not paused for sprites and fifo is not empty.
        // Skipping pixels must happen at pcnt = 0 to pass Wilbertpol intr2_mode0_scx_timing tests.
        if (~sprite_fetch_hold & ~bg_shift_empty) begin

            if (~skip_done) begin
                if (~skip_end)
                    skip_cnt <= skip_cnt + 1'd1;
                else
                    skip_done <= 1'd1;
            end

            // Pixels 0-7 are for fetching partially offscreen sprites and window.
            // Pixels 8-167 are output to the display.
            if(~skip_en & ~pcnt_end)
                pcnt <= pcnt + 1'd1;

        end

        if (pcnt_reset) begin
            pcnt <= 8'd0;
            skip_done <= 1'b0;
            skip_cnt <= 3'd0;
        end

    end
end


wire line153 = (v_cnt == 8'd153);
reg vcnt_reset;
reg vsync;
reg vcnt_eol_l;

always @(posedge clk) begin
    if (reset) begin
        vcnt_eol_l <= 1'b0;
        vcnt_reset <= 1'b0;
        v_cnt      <= 8'd0;
        vsync      <= 1'b0;
	end else if (reset_now) begin // reset only when LCD is turned back on
        vcnt_eol_l <= 1'b0;
        vcnt_reset <= 1'b0;
        v_cnt      <= 8'd0;
        vsync      <= 1'b0;
    end else if (ce) begin
        if (~vcnt_reset & h_clk_en_neg & hcnt_end) begin
            v_cnt <= v_cnt + 1'b1;
        end

        // Line 153->0 reset happens a few cycles later on GBC
        if ( (~isGBC & h_clk_en) | (isGBC & h_clk_en_neg) ) begin
            vcnt_eol_l <= end_of_line;
            if (vcnt_eol_l & ~end_of_line) begin
                // vcnt_reset goes high a few cycles after v_cnt is incremented to 153.
                // It resets v_cnt back to 0 and keeps it in reset until the following line.
                // This results in v_cnt 0 lasting for almost 2 lines.
                vcnt_reset <= line153;
                if (line153) begin
                    v_cnt <= 8'd0;
                end

                // VSync goes high on line 0 but it takes a full frame after the LCD is enabled
                // because the first line where end_of_line is high after LCD is enabled is line 1.
                vsync <= !v_cnt;
            end
        end

    end
end

assign lcd_vsync = vsync;

wire bg_fetch_done;
wire bg_reload_shift;

always @(posedge clk) begin

    if (reset) begin
        h_cnt        <= 7'd0;
        h_div_cnt    <= 2'd0;
	end else if (reset_now) begin // reset only when LCD is turned back on
        //reset counters
        h_cnt        <= 7'd0;
        h_div_cnt    <= 2'd0;
    end else if (ce) begin

        h_div_cnt <= h_div_cnt + 1'b1;
        if (h_clk_en) begin
            h_cnt <= hcnt_end ? 7'd0 : h_cnt + 1'b1;
        end
      
   end
      
end

// --------------------------------------------------------------------
// ------------------- bg, window and sprite fetch  -------------------
// --------------------------------------------------------------------

// A bg or sprite fetch takes 6 cycles
reg [2:0] bg_fetch_cycle;
reg [2:0] sprite_fetch_cycle;

assign bg_fetch_done = (bg_fetch_cycle >= 3'd5);
wire sprite_fetch_done = (sprite_fetch_hold && sprite_fetch_cycle >= 3'd5);

// The first B01 cycle does not fetch sprites so wait until the bg shift register is not empty
assign sprite_fetch_hold = sprite_found & ~bg_shift_empty;

reg [3:0] bg_shift_cnt = 4'd0;
assign bg_shift_empty = (bg_shift_cnt == 0);
assign bg_reload_shift = (bg_shift_cnt <= 1);

always @(posedge clk) begin
    
    if (reset) begin
    
        bg_fetch_cycle     <= 3'b000;
        sprite_fetch_cycle <= 3'b000;

    end else if (ce) begin

        if (~&bg_fetch_cycle) begin
            bg_fetch_cycle <= bg_fetch_cycle + 1'b1;
        end

        if (~sprite_fetch_hold) begin

            if (|bg_shift_cnt) bg_shift_cnt <= bg_shift_cnt - 1'b1;

            if (bg_fetch_done && bg_reload_shift) begin
                bg_shift_cnt <= 4'd8;
                bg_fetch_cycle <= 0;
            end
        end

        // Start sprite fetch after background fetching is done
        // Sprite fetching continues until there are no more sprites on the current x position
        if (sprite_fetch_hold && bg_fetch_done) begin
            sprite_fetch_cycle <= sprite_fetch_cycle + 1'b1;
        end

        if (~sprite_fetch_hold || sprite_fetch_done) sprite_fetch_cycle <= 0;

    end

end

sprites sprites (
    .clk      ( clk   ),
    .ce       ( ce    ),
    .ce_cpu   ( ce_cpu),
    .size16   ( 1'b0 ),
    .isGBC    ( 1'b1 ),
    .sprite_en( 1'b0 ),
    .lcd_on   ( 1'b1 ),

    .v_cnt    ( v_cnt),
    .h_cnt    ( pcnt ),

    .oam_eval       ( oam_eval     ),
    .oam_fetch      ( mode3        ),
    .oam_eval_reset ( pcnt_reset   ),
    .oam_eval_end   ( oam_eval_end ),

    .sprite_fetch (sprite_found),
    .sprite_addr ( sprite_addr ),
    .sprite_attr ( sprite_attr ),
    .sprite_index ( sprite_index ),
    .sprite_fetch_done ( sprite_fetch_done) ,

    .dma_active ( 1'b0),
    .oam_wr     ( 1'b0),
    .oam_addr_in( 8'd0),
    .oam_di     ( 8'd0),

    .Savestate_OAMRAMAddr      (8'd0),     
    .Savestate_OAMRAMRWrEn     (1'b0),    
    .Savestate_OAMRAMWriteData (8'd0)
);

// --------------------------------------------------------------------
// ----------------------- lcd output stage   -------------------------
// --------------------------------------------------------------------

assign lcd_clk = mode3 && ~skip_en && ~sprite_fetch_hold && ~bg_shift_empty && (pcnt >= 8);

reg lcd_clk_out;
always @(posedge clk) begin
    if (ce) begin
        lcd_clk_out <= lcd_clk;
    end
end

assign lcd_data = (isGBC_mode || ~paletteOff) ? 15'h7FFF : { bgpd[1][6:0],bgpd[0] };
assign lcd_clkena = lcd_clk_out;

endmodule
