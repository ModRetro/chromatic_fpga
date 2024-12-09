library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;     

entity PSRAMController is 
   generic
   (
      ISSIMU             : boolean := false;
   
      IODELAY_SETTING : integer_vector := (
          0 => 0,  -- DQ0
          1 => 0,  -- DQ1
          2 => 0,  -- DQ2
          3 => 0,  -- DQ3
          4 => 0,  -- DQ4
          5 => 0,  -- DQ5
          6 => 0,  -- DQ6
          7 => 0,  -- DQ7
          8 => 0,  -- CLK
          9 => 0,   -- CS_N,
          10 => 0   -- RWDS,
      );
   
      READLATENCY        : integer range 3 to 7 := 5; -- verified in simulation for all options
      WRITELATENCY       : integer range 3 to 7 := 5; -- verified in simulation for all options
      CFG0_LT            : std_logic := '0';                      -- default startup values, changes not verified
      CFG0_DRIVESTRENGTH : std_logic_vector(1 downto 0) := "00";  -- testing increased drive strength (01 is default)
      CFG4_RF            : std_logic := '0';                      -- default startup values, changes not verified
      CFG4_PASR          : std_logic_vector(2 downto 0) := "000"; -- default startup values, changes not verified
      CFG8_RBX           : std_logic := '1';                      -- read across 1k border
      CFG8_BT            : std_logic := '1';                      -- default startup values, changes not verified
      CFG8_BL            : std_logic_vector(1 downto 0) := "11"   -- increase to 1k byte wrap (01 default)
   );
   port 
   (
      clk_sys              : in    std_logic;
      clk_fsys             : in    std_logic;
      rst                  : in    std_logic;
      
      req_read             : in    std_logic;
      req_write            : in    std_logic;
      addr                 : in    std_logic_vector(22 downto 0);
      din                  : in    std_logic_vector(15 downto 0); 
      burst_length         : in    unsigned(10 downto 0); -- in bytes
      
      cfg_0_LT             : out   std_logic;
      cfg_0_readLatency    : out   std_logic_vector(2 downto 0);
      cfg_0_driveStrength  : out   std_logic_vector(1 downto 0);
      cfg_1_ULP            : out   std_logic;
      cfg_1_VendorID       : out   std_logic_vector(4 downto 0);
      cfg_2_GB             : out   std_logic;
      cfg_2_DevID          : out   std_logic_vector(1 downto 0);
      cfg_2_Density        : out   std_logic_vector(2 downto 0);
      cfg_3_RBXen          : out   std_logic;
      cfg_3_VCC            : out   std_logic;
      cfg_3_SRF            : out   std_logic;
      cfg_4_writeLatency   : out   std_logic_vector(2 downto 0);
      cfg_4_RF             : out   std_logic;
      cfg_4_PASR           : out   std_logic_vector(2 downto 0);
      cfg_8_RBX            : out   std_logic;
      cfg_8_BT             : out   std_logic;
      cfg_8_BL             : out   std_logic_vector(1 downto 0);

      ready                : out   std_logic := '0';
      writeNext            : out   std_logic := '0';
      done                 : out   std_logic := '0'; 
      dout_valid           : out   std_logic := '0';
      dout                 : out   std_logic_vector(15 downto 0) := (others => '0'); 
               
      psram_clk            : out   std_logic;
      psram_cs_n           : out   std_logic;
      psram_rwds           : inout std_logic := 'Z';
      psram_dq             : inout std_logic_vector(7 downto 0) := (others => 'Z')
   );   
end entity;

architecture arch of PSRAMController is

   type tState is 
   (  
      RESET,
      CONFIGWRITE_NEXT,
      CONFIGWRITE_START,
      CONFIGWRITE,
      CONFIGREAD_NEXT,
      CONFIGREAD_START,
      CONFIGREAD,
      IDLE,
      READING,
      READVAL,
      WRITING,
      WRITE_NEWROW
   ); 
   signal state  : tState := RESET;  
   
   signal configwrite_addr : std_logic_vector(3 downto 0) := x"0";
   signal configread_addr  : std_logic_vector(3 downto 0) := x"0";
   
   signal startup_cnt      : integer range 0 to 50000 := 0; -- adjust for clock speed
   
   signal dq_shiftreg      : std_logic_vector(63 downto 0) := (others => '0');
   signal step             : integer range 0 to 15;
   
   signal burst_count      : unsigned(10 downto 0);
   signal writeburst       : std_logic := '0';
   signal addr_nextRow     : std_logic_vector(12 downto 0);
   signal row_count        : unsigned(8 downto 0);
   
   signal clock_ena        : std_logic := '0';
   signal oe_dq_n          : std_logic := '1';
   signal oe_rwds_n        : std_logic := '1';
   signal cs_ena_n         : std_logic := '1';
   
   signal rwds_out_rising  : std_logic := '1';
   signal rwds_out_falling : std_logic := '1';
   
   signal rwds_in_Q   : std_logic_vector(3 downto 0);

   signal psram_dq_o     : std_logic_vector(7 downto 0);
   
   signal dq_in_adjustH   : std_logic_vector(7 downto 0);
   signal dq_in_adjustL   : std_logic_vector(7 downto 0);

   signal dq_in_Q0     : std_logic_vector(7 downto 0);
   signal dq_in_Q1     : std_logic_vector(7 downto 0);
   signal dq_in_Q2    : std_logic_vector(7 downto 0);
   signal dq_in_Q3    : std_logic_vector(7 downto 0);
   
   signal oddr_rwds_data   : std_logic;
   signal oddr_rwds_enaN   : std_logic;
   signal oddr_dq_data     : std_logic_vector(7 downto 0);
   signal oddr_dq_data_dly : std_logic_vector(7 downto 0);
   signal oddr_dq_enaN     : std_logic_vector(7 downto 0);
   
   signal psram_clk_dly    : std_logic;
   signal psram_cs_n_dly   : std_logic;
   signal oddr_rwds_data_dly : std_logic;
   signal psram_rwds_o     : std_logic;
   
   signal receiving_data   : std_logic;
   
   component IDDR is
   PORT (
      Q0 : OUT std_logic;
      Q1 : OUT std_logic;   
      D : IN std_logic;
      CLK: IN std_logic
   );
   end component;

   component IDES4 is
   PORT (
      D     : IN std_logic;
      FCLK  : IN std_logic;
      PCLK  : IN std_logic;
      CALIB : IN std_logic;
      RESET : IN std_logic;
      Q0    : OUT std_logic;
      Q1    : OUT std_logic;
      Q2    : OUT std_logic;
      Q3    : OUT std_logic
   );
   end component;

   component OSER4 is
   GENERIC (
        HWL : string := "false"; --"true"; "false"
        TXCLK_POL : bit := '0' --'0':Rising edge output; '1':Falling edge output
   );
   PORT (
      D0    : IN std_logic;
      D1    : IN std_logic;
      D2    : IN std_logic;
      D3    : IN std_logic;
      TX0   : IN std_logic; -- active low
      TX1   : IN std_logic; -- active low
      FCLK  : IN std_logic;
      PCLK  : IN std_logic;
      RESET : IN std_logic;
      Q0    : OUT std_logic;
      Q1    : OUT std_logic
   );
   end component;
        
   component ODDR is
   GENERIC ( 
       TXCLK_POL : bit := '0' --'0':Rising edge output; '1':Falling edge output        
   );   
   PORT ( 
      Q0 : OUT std_logic;   
      Q1 : OUT std_logic;   
      D0 : IN std_logic;
      D1 : IN std_logic;
      TX : IN std_logic;
      CLK : IN std_logic
   );   
   end component;
   
    component IODELAY is
    GENERIC (
        C_STATIC_DLY : integer:=0
    );
    PORT (
        DO      : OUT std_logic;
        DF      : OUT std_logic;
        DI      : IN std_logic;
        SDTAP   : IN std_logic;
        DLYSTEP : IN std_logic_vector(7 downto 0);
        VALUE   : IN std_logic
    );
    end component;
   
begin

   u_iodelay_psram_cs_n : IODELAY 
   generic map
   (
      C_STATIC_DLY => IODELAY_SETTING(9)
   )
   port map
   (
        DO      => psram_cs_n,
        DF      => open,
        DI      => psram_cs_n_dly,
        SDTAP   => '0',
        DLYSTEP => 8x"0",
        VALUE   => '0'
   );
   
    oser4_psram_cs_n : OSER4 port map
    (
        PCLK    => clk_sys,
        FCLK    => clk_fsys,
        RESET   => rst,
        TX0     => '0',
        TX1     => '0',
        D0      => cs_ena_n,
        D1      => cs_ena_n,
        D2      => cs_ena_n,
        D3      => cs_ena_n,
        Q0      => psram_cs_n_dly,
        Q1      => open
    );

   u_iodelay_psram_clk : IODELAY 
   generic map
   (
      C_STATIC_DLY => IODELAY_SETTING(8)
   )
   port map
   (
        DO      => psram_clk,
        DF      => open,
        DI      => psram_clk_dly,
        SDTAP   => '0',
        DLYSTEP => 8x"0",
        VALUE   => '0'
   );

    oser4_psram_clk : OSER4 port map
    (
        PCLK    => clk_sys,
        FCLK    => clk_fsys,
        RESET   => rst,
        TX0     => '0',
        TX1     => '0',
        D0      => '0',
        D1      => clock_ena,
        D2      => clock_ena,
        D3      => '0',
        Q0      => psram_clk_dly,
        Q1      => open
    );

   u_iodelay_psram_rwds : IODELAY 
   generic map
   (
      C_STATIC_DLY => IODELAY_SETTING(10)
   )
   port map
   (
        DO      => oddr_rwds_data,
        DF      => open,
        DI      => oddr_rwds_data_dly,
        SDTAP   => '0',
        DLYSTEP => 8x"0",
        VALUE   => '0'
   );

    oser4_psram_rwds : OSER4 port map
    (
        PCLK    => clk_sys,
        FCLK    => clk_fsys,
        RESET   => rst,
        TX0     => oe_rwds_n,
        TX1     => oe_rwds_n,
        D0      => rwds_out_rising,
        D1      => rwds_out_rising,
        D2      => rwds_out_falling,
        D3      => rwds_out_falling,
        Q0      => oddr_rwds_data_dly,
        Q1      => oddr_rwds_enaN
    );

   psram_rwds <= oddr_rwds_data when (oddr_rwds_enaN = '0') else 'Z';
   
   gdq : for i in 0 to 7 generate
   begin
      
   u_iodelay_dq : IODELAY 
   generic map
   (
      C_STATIC_DLY => IODELAY_SETTING(i)
   )
   port map
   (
        DO      => oddr_dq_data_dly(i),
        DF      => open,
        DI      => oddr_dq_data(i),
        SDTAP   => '0',
        DLYSTEP => 8x"0",
        VALUE   => '0'
   );

    oser4_dq : OSER4 
       generic map
       (
          HWL => "false",
          TXCLK_POL => '0'
       )
    port map
    (
        PCLK    => clk_sys,
        FCLK    => clk_fsys,
        RESET   => rst,
        TX0     => oe_dq_n,
        TX1     => oe_dq_n,
        D0      => dq_shiftreg(56 + i),
        D1      => dq_shiftreg(56 + i),
        D2      => dq_shiftreg(48 + i),
        D3      => dq_shiftreg(48 + i),
        Q0      => oddr_dq_data(i),
        Q1      => oddr_dq_enaN(i)
    );
      psram_dq(i) <= oddr_dq_data_dly(i) when (oddr_dq_enaN(i) = '0') else 'Z';
/*
    -- Cleanup L/H from memory sim model
    process (psram_dq(i)) 
    begin
      case psram_dq(i) is
        when 'L' => psram_dq_o(i) <= '0';
        when 'H' => psram_dq_o(i) <= '1';
        when others => psram_dq_o(i) <= psram_dq(i);
      end case;
    end process;
*/
    -- Register these here to improve timing
    process (clk_sys)
    begin
        if rising_edge(clk_sys) then
          -- Delay enable by 1 cycle
            if (rst = '1') then
                receiving_data  <= '0';
            else
                if(rwds_in_Q(2) or rwds_in_Q(0)) then
                    receiving_data <= '1';
                else
                    receiving_data <= '0';
                end if;
            end if;
          
          case rwds_in_Q is
            when "0011" => 
               if (ISSIMU = true) then
                  if (dq_in_Q1(0) /= '0' and dq_in_Q1(0) /= '1') then
                     dq_in_adjustL <= x"AB";
                     dq_in_adjustH <= x"CD";
                  else
                     dq_in_adjustL <= dq_in_Q1;
                     dq_in_adjustH <= dq_in_Q3;
                  end if;
               else
                  dq_in_adjustL <= dq_in_Q0;
                  dq_in_adjustH <= dq_in_Q2;
               end if;
            when "0001" => 
                dq_in_adjustL <= dq_in_Q0;
                dq_in_adjustH <= dq_in_Q2; 
            when "1001" => 
                dq_in_adjustL <= dq_in_Q0;
                dq_in_adjustH <= dq_in_Q2;
            when "0110" => 
                dq_in_adjustL <= dq_in_Q1;
                dq_in_adjustH <= dq_in_Q3;
            when others => 
                dq_in_adjustL <= dq_in_Q3;
                dq_in_adjustH <= dq_in_Q2;
          end case;
        end if;
    end process;

    ides4_dq : IDES4 port map
    (
        D     => psram_dq(i),
        PCLK  => clk_sys,
        FCLK  => clk_fsys,
        CALIB => '0',
        RESET => rst,
        Q0  => dq_in_Q0(i),
        Q1  => dq_in_Q1(i),
        Q2  => dq_in_Q2(i),
        Q3  => dq_in_Q3(i)
    );

   end generate;
/*   
    -- Cleanup L/H from memory sim model
    process (psram_rwds) 
    begin
      case psram_rwds is
        when 'L' => psram_rwds_o <= '0';
        when 'H' => psram_rwds_o <= '1';
        when others => psram_rwds_o <= psram_rwds;
      end case;
    end process;
*/
   ides4_psram_rwds : IDES4 port map
   (
      D     => psram_rwds,
      PCLK  => clk_sys,
      FCLK  => clk_fsys,
      CALIB => '0',
      RESET => rst,
      Q0  => rwds_in_Q(0),
      Q1  => rwds_in_Q(1),
      Q2  => rwds_in_Q(2),
      Q3  => rwds_in_Q(3)
   );
   
   ready <= '1' when (state = IDLE and cfg_1_VendorID = 5x"0D") else '0';
   
   writeNext <= '1' when (state = WRITING and writeburst = '1' and burst_count > 2) else '0';
   
   process (clk_sys)
   begin
      if rising_edge(clk_sys) then
      
         done        <= '0';
         dout_valid  <= '0';
         dq_shiftreg <= dq_shiftreg(47 downto 0) & 16x"0";
         
         if (step < 15) then
            step <= step + 1;
         end if;
      
         if (rst = '1') then
            state            <= RESET;
            startup_cnt      <= 0;
            configread_addr  <= x"0";
            configwrite_addr <= x"F";
            step             <= 0;
            cs_ena_n         <= '1';
            clock_ena        <= '0';
            oe_dq_n          <= '1';
            oe_rwds_n        <= '1';
         else

            case (state) is
         
               when RESET =>
                  if (startup_cnt < 50000) then
                     startup_cnt <= startup_cnt + 1;
                  else
                     state     <= CONFIGWRITE_NEXT;
                     step      <= 0;
                  end if;
                  
               when CONFIGWRITE_NEXT =>
                  if (step >= 8) then
                     state     <= CONFIGWRITE_START;
                     cs_ena_n  <= '0';
                     step      <= 0;
                  end if;
               
               when CONFIGWRITE_START =>
                  state        <= CONFIGWRITE;
                  dq_shiftreg  <= x"C0C0000000000000";
                  oe_dq_n      <= '0';
                  clock_ena    <= '1';
                  dq_shiftreg(19 downto 16) <= configwrite_addr;
                  case (configwrite_addr) is
                     
                     when  x"F" =>
                        dq_shiftreg      <= (others => '1');
                        
                     when x"0" =>
                        dq_shiftreg(15 downto 8) <= "00" & CFG0_LT & std_logic_vector(to_unsigned(READLATENCY - 3,3)) & CFG0_DRIVESTRENGTH;
                        
                     when x"4" =>
                        dq_shiftreg(15 downto 8) <= "0000" & CFG4_RF & CFG4_PASR;   
                        case (WRITELATENCY) is
                           when 3 => dq_shiftreg(15 downto 13) <= "000";
                           when 4 => dq_shiftreg(15 downto 13) <= "100";
                           when 5 => dq_shiftreg(15 downto 13) <= "010";
                           when 6 => dq_shiftreg(15 downto 13) <= "110";
                           when 7 => dq_shiftreg(15 downto 13) <= "001";
                           when others => null;
                        end case;
                        
                     when x"8" =>
                        dq_shiftreg(15 downto 8) <= "0000" & CFG8_RBX & CFG8_BT & CFG8_BL;
                        
                     when others => null;
                        
                  end case;
                  
               when CONFIGWRITE =>
                  if (step = 4) then
                     
                     state        <= CONFIGWRITE_NEXT;
                     clock_ena    <= '0';
                     oe_dq_n      <= '1';
                     cs_ena_n     <= '1';
                     
                     case (configwrite_addr) is
                     
                        when  x"F" =>
                           configwrite_addr <= x"0";
                           state            <= RESET;
                           startup_cnt      <= 0;
                           
                        when x"0" =>
                           configwrite_addr         <= x"4";
                           
                        when x"4" =>
                           configwrite_addr         <= x"8"; 
                           
                        when x"8" =>
                           state                    <= CONFIGREAD_NEXT;
                           
                        when others => null;
                        
                     end case;
                     
                  end if; 
                  
               when CONFIGREAD_NEXT =>
                  if (step >= 8) then
                     state     <= CONFIGREAD_START;
                     cs_ena_n  <= '0';
                     step      <= 0;
                  end if;
                  
               when CONFIGREAD_START =>
                  state        <= CONFIGREAD;
                  dq_shiftreg  <= x"4040000000000000";
                  oe_dq_n      <= '0';
                  clock_ena    <= '1';
                  dq_shiftreg(19 downto 16) <= configread_addr;
                  
               when CONFIGREAD =>
                  if (step = 3) then
                     oe_dq_n      <= '1';
                  end if;
                  if (step > 9 and receiving_data = '1') then
                     
                     state     <= CONFIGREAD_NEXT;
                     step      <= 0;
                     cs_ena_n  <= '1';
                     clock_ena <= '0';
   
                     case (configread_addr) is
                        when x"0" => 
                           configread_addr     <= x"1"; 
                           cfg_0_LT            <= dq_in_adjustL(5);
                           cfg_0_readLatency   <= dq_in_adjustL(4 downto 2);
                           cfg_0_driveStrength <= dq_in_adjustL(1 downto 0);
                           
                        when x"1" => 
                           configread_addr <= x"2";
                           cfg_1_ULP       <= dq_in_adjustL(7);  
                           cfg_1_VendorID  <= dq_in_adjustL(4 downto 0); 
                           
                        when x"2" => 
                           configread_addr <= x"3";
                           cfg_2_GB        <= dq_in_adjustL(7);  
                           cfg_2_DevID     <= dq_in_adjustL(4 downto 3);    
                           cfg_2_Density   <= dq_in_adjustL(2 downto 0); 
                           
                        when x"3" => 
                           configread_addr <= x"4";
                           cfg_3_RBXen     <= dq_in_adjustL(7);     
                           cfg_3_VCC       <= dq_in_adjustL(6);     
                           cfg_3_SRF       <= dq_in_adjustL(5);  
                           
                        when x"4" => 
                           configread_addr    <= x"8";
                           cfg_4_writeLatency <= dq_in_adjustL(7 downto 5); 
                           cfg_4_RF           <= dq_in_adjustL(3); 
                           cfg_4_PASR         <= dq_in_adjustL(2 downto 0); 
                           
                        when x"8" => 
                           state     <= IDLE;
                           cfg_8_RBX <= dq_in_adjustL(3); 
                           cfg_8_BT  <= dq_in_adjustL(2);
                           cfg_8_BL  <= dq_in_adjustL(1 downto 0);
                        
                        when others => null;
                        
                     end case;
                  end if;
                  
               when IDLE =>
                  oe_rwds_n    <= '1';
                  oe_dq_n      <= '1';
                  clock_ena    <= '0';
                  cs_ena_n     <= '1';
                  writeburst   <= '0';
                  burst_count  <= burst_length;
                  addr_nextRow <= std_logic_vector(unsigned(addr(22 downto 10)) + 1);
                  row_count    <= 9x"1FF" - unsigned(addr(9 downto 1));
                  if (req_read = '1' or req_write = '1') then
                     if (req_read = '1') then
                        state       <= READING;
                        dq_shiftreg(63 downto 48) <= x"2020";
                     else
                        state       <= WRITING;
                        dq_shiftreg(63 downto 48) <= x"A0A0";
                     end if;
                     dq_shiftreg(47 downto 0) <= 9x"0" & addr(22 downto 1) & '0' & 16x"0";
                     cs_ena_n    <= '0';
                     clock_ena   <= '1';
                     oe_dq_n     <= '0';
                     step        <= 1;
                  end if;
                  
               when READING =>
                  if (step = 3) then
                     oe_dq_n <= '1';
                  elsif (step > 9 and rwds_in_Q(3) /= rwds_in_Q(1)) then
                     if (burst_count = 1) then
                        state     <= IDLE;
                        done      <= '1';
                        cs_ena_n  <= '1';
                        clock_ena <= '0';
                     else
                        state <= READVAL;
                     end if;
                  end if;
                  
               when READVAL =>
                  if (receiving_data = '1') then
                     dout_valid  <= '1';
                     dout        <= dq_in_adjustH & dq_in_adjustL;
                     if (burst_count <= 2) then
                        state     <= IDLE;
                        done      <= '1';
                        cs_ena_n  <= '1';
                        clock_ena <= '0';
                     else
                        burst_count <= burst_count - 2;
                     end if;
                  end if;
               
               when WRITING =>
                  if (step = 1 + WRITELATENCY) then
                     writeburst <= '1';
                  end if;
                  if (writeburst = '1') then
                     oe_dq_n                    <= '0';
                     oe_rwds_n                  <= '0';
                     rwds_out_rising            <= '0'; --todo: byte mask together with addr bit 0 in case of single byte write
                     rwds_out_falling           <= '0'; --todo: byte mask together with addr bit 0 in case of single byte write
                     dq_shiftreg(63 downto 48)  <= din(7 downto 0) & din(15 downto 8); 
                     
                     row_count <= row_count - 1;
                     if (row_count = 0) then
                        state      <= WRITE_NEWROW;
                        writeburst <= '0';
                        step       <= 0;
                     end if;
                     
                     if (burst_count <= 2) then
                        state                   <= IDLE;
                        done                    <= '1';
                     else
                        burst_count <= burst_count - 2;
                     end if;
                  end if;
                  
               when WRITE_NEWROW =>
                  oe_dq_n     <= '1';
                  oe_rwds_n   <= '1';
                  clock_ena   <= '0';
                  cs_ena_n    <= '1';
                  if (step = 4) then
                     state       <= WRITING;
                     dq_shiftreg(63 downto 48) <= x"A0A0";
                     dq_shiftreg(47 downto 0) <= 9x"0" & addr_nextRow & 10x"0" & 16x"0";
                     cs_ena_n    <= '0';
                     clock_ena   <= '1';
                     oe_dq_n     <= '0';
                     step        <= 1;
                  end if;
                  
         
            end case;
            
         end if;
      
      end if;
   end process;
   
end architecture;


