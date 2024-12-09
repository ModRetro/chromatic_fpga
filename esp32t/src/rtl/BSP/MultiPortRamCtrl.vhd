-----------------------------------------------------------------
--------------- MultiPortPSRAM Package  -------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pMultiPortPSRAM is

   constant RAMPORTCOUNT : integer := 5;

   type tRAMIn_request         is array(0 to RAMPORTCOUNT - 1) of std_logic;
   type tRAMIn_RnW             is array(0 to RAMPORTCOUNT - 1) of std_logic;
   type tRAMIn_addr            is array(0 to RAMPORTCOUNT - 1) of std_logic_vector(22 downto 0);
   type tRAMIn_din             is array(0 to RAMPORTCOUNT - 1) of std_logic_vector(15 downto 0);
   type tRAMIn_burst_length    is array(0 to RAMPORTCOUNT - 1) of unsigned(10 downto 0);
   
   type tRAMOut_writeNext      is array(0 to RAMPORTCOUNT - 1) of std_logic;
   type tRAMOut_done           is array(0 to RAMPORTCOUNT - 1) of std_logic;
   type tRAMOut_dout_valid     is array(0 to RAMPORTCOUNT - 1) of std_logic;

end package;

-----------------------------------------------------------------
--------------- MultiPortPSRAM Mux   ----------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;     

use work.pMultiPortPSRAM.all;

entity MultiPortRamCtrl is 
   generic
   (
      ISSIMU : boolean := false
   );
   port 
   (
      clk_sys              : in    std_logic;
      clk_fsys             : in    std_logic;
      rst                  : in    std_logic;
      
      RAMIn_request        : in    tRAMIn_request;   
      RAMIn_RnW            : in    tRAMIn_RnW;         
      RAMIn_addr           : in    tRAMIn_addr;        
      RAMIn_din            : in    tRAMIn_din;         
      RAMIn_burst_length   : in    tRAMIn_burst_length;
                                   
      RAMOut_writeNext     : out   tRAMOut_writeNext;        
      RAMOut_done          : out   tRAMOut_done;             
      RAMOut_dout_valid    : out   tRAMOut_dout_valid;       
      
      ram_ready            : out   std_logic;
      ram_dout             : out   std_logic_vector(15 downto 0); 
      
      psram_clk            : out   std_logic;
      psram_cs_n           : out   std_logic;
      psram_rwds           : inout std_logic := 'Z';
      psram_dq             : inout std_logic_vector(7 downto 0) := (others => 'Z')
   );   
end entity;

architecture arch of MultiPortRamCtrl is

   -- statemachine
   type tstate is
   (
      IDLE,
      WAITRAM
   );
   signal state            : tstate := IDLE;
   
   signal rrb              : integer range 0 to RAMPORTCOUNT - 1;
   signal req_latched      : std_logic_vector(0 to RAMPORTCOUNT) := (others => '0');
   signal lastIndex        : integer range 0 to RAMPORTCOUNT - 1;

   -- controller
   signal req_read         : std_logic := '0';
   signal req_write        : std_logic := '0';
   signal addr             : std_logic_vector(22 downto 0) := (others => '0');
   signal din              : std_logic_vector(15 downto 0); 
   signal burst_length     : unsigned(10 downto 0) := (others => '0'); -- in bytes

   signal writeNext        : std_logic;
   signal done             : std_logic; 
   signal dout_valid       : std_logic;
   
   
begin

   din          <= RAMIn_din(lastIndex);
   
   process (all)
   begin
      
      for i in 0 to RAMPORTCOUNT - 1 loop
         RAMOut_done(i)       <= '0';
         RAMOut_dout_valid(i) <= '0';
         RAMOut_writeNext(i)  <= '0';
      end loop;
      
      if (state = WAITRAM) then
         if (done = '1')       then  RAMOut_done(lastIndex)       <= '1'; end if;
         if (dout_valid = '1') then  RAMOut_dout_valid(lastIndex) <= '1'; end if;
         if (writeNext = '1')  then  RAMOut_writeNext(lastIndex)  <= '1'; end if;
      end if;
      
   end process;

   process (clk_sys)
      variable activeRequest : std_logic;
      variable activeIndex   : integer range 0 to RAMPORTCOUNT - 1;
   begin
      if rising_edge(clk_sys) then
      
         req_read  <= '0';
         req_write <= '0';
      
         -- request handling -> any active, but round robin has priority
         activeRequest := '0';
         for i in 0 to RAMPORTCOUNT - 1 loop
            if (RAMIn_request(i) = '1') then
               req_latched(i) <= '1';
            end if;
               
            if (RAMIn_request(i) = '1' or req_latched(i) = '1') then
               activeRequest := '1';
               activeIndex   := i;
            end if;
            
         end loop;
         
         if (req_latched(rrb) = '1') then
            activeIndex := rrb;
         end if;
         
         
         if (rst = '1') then
         
            state       <= IDLE;
            req_latched <= (others => '0');
            
         else

            -- main statemachine
            case (state) is
               when IDLE =>
                  
                  lastIndex    <= activeIndex;
                  
                  -- round robin
                  if (rrb < RAMPORTCOUNT - 1) then
                     rrb <= rrb + 1;
                  else
                     rrb <= 0;
                  end if;
                  
                  if (activeRequest = '1' and ram_ready = '1') then
                  
                     state                    <= WAITRAM;
                     req_latched(activeIndex) <= '0';
                     
                     if (RAMIn_RnW(activeIndex) = '1') then
                        req_read <= '1';
                     else
                        req_write <= '1';
                     end if;                     
                      
                     burst_length  <= RAMIn_burst_length(activeIndex);
                     addr          <= RAMIn_addr(activeIndex);
                     
                  end if;   
                     
               when WAITRAM =>
                  if (done = '1') then
                     state <= IDLE;
                  end if;
              
            end case;
            
         end if;

      end if;
   end process;

   iPsramController : entity work.PSRAMController 
   generic map
   (
        ISSIMU      => ISSIMU
   )
   port map
   (
      clk_sys       => clk_sys,      
      clk_fsys      => clk_fsys,
      rst           => rst,      
      req_read      => req_read,          
      req_write     => req_write,        
      addr          => addr,         
      din           => din,
      burst_length  => burst_length,
                    
      ready         => ram_ready, 
      writeNext     => writeNext,
      dout          => ram_dout, 
      dout_valid    => dout_valid,
      done          => done,         
                    
      psram_clk     => psram_clk,   
      psram_rwds    => psram_rwds,
      psram_dq      => psram_dq,  
      psram_cs_n    => psram_cs_n 
   );
   
end architecture;


