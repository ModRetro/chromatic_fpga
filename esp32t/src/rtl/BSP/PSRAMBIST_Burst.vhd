library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;     

entity PSRAMBIST_Burst is 
   generic
   (
      BIST_BURSTLENGTH : integer range 1 to 512 := 512;
      SHORTTEST        : boolean := true
   );
   port 
   (
      clk                  : in  std_logic;
      rst                  : in  std_logic;
      
      test_finished        : out std_logic := '0';                  
      test_failed          : out std_logic := '0';                           
      
      ram_req_read         : out std_logic := '0';
      ram_req_write        : out std_logic := '0';
      ram_addr             : out std_logic_vector(22 downto 0) := (others => '0');
      ram_din              : out std_logic_vector(15 downto 0) := (others => '0');
      burst_length         : out unsigned(10 downto 0);
      ram_ready            : in  std_logic; 
      ram_writeNext        : in  std_logic; 
      ram_done             : in  std_logic; 
      ram_dout             : in  std_logic_vector(15 downto 0);
      ram_dout_valid       : in  std_logic
   );   
end entity;

architecture arch of PSRAMBIST_Burst is

   type tState is 
   (  
      WRITE_START,
      WRITE_WAIT,
      READ_START,
      READ_WAIT,
      TESTDONE
   ); 
   signal state  : tState := WRITE_START;  
   
   type tTesttype is 
   (  
      ALTERNATING,
      COUNT,
      ONES,
      ZEROS
   ); 
   signal testtype  : tTesttype := ALTERNATING; 
   
   signal addr_cnt  : unsigned(21 downto 0) := (others => '0');
   signal burst_cnt : unsigned(9 downto 0);
   
begin

   burst_length <= to_unsigned(BIST_BURSTLENGTH * 2, 11);

   process (clk)
   begin
      if rising_edge(clk) then
      
         ram_req_read  <= '0';
         ram_req_write <= '0';
         
         if (rst = '1') then
            state         <= WRITE_START;
            testtype      <= ALTERNATING;
            addr_cnt      <= (others => '0');
            ram_din       <= x"AA55";
            test_finished <= '0';
            test_failed   <= '0';
         else

            case (state) is
         
               when WRITE_START | READ_START =>
                  if (ram_ready = '1') then
                     if (state = WRITE_START) then
                        state         <= WRITE_WAIT;
                        ram_req_write <= '1';
                     else
                        state         <= READ_WAIT;
                        ram_req_read  <= '1';
                     end if;
                     
                     ram_addr   <= std_logic_vector(addr_cnt) & '0';
                     addr_cnt   <= addr_cnt + 1;
                     burst_cnt  <= to_unsigned(BIST_BURSTLENGTH, 10);
                     
                     if (SHORTTEST = true) then
                        addr_cnt   <= addr_cnt + (512 * BIST_BURSTLENGTH) + 1;
                     end if;
                     
                     case (testtype) is
                        when ALTERNATING => ram_din <= not ram_din;
                        when COUNT       => ram_din <= std_logic_vector(addr_cnt(15 downto 0));
                        when ONES        => ram_din <= (others => '1');
                        when ZEROS       => ram_din <= (others => '0');
                     end case;
                  end if;
                  
               when WRITE_WAIT =>
                  if (ram_done = '1') then
                     state <= WRITE_START;
                     if ((SHORTTEST = true and addr_cnt(addr_cnt'left) = '1') or (SHORTTEST = false and addr_cnt = 0)) then
                        state    <= READ_START;
                        addr_cnt <= (others => '0');
                        ram_din  <= x"AA55";
                     end if;
                  end if;
                  
                  if (ram_writeNext = '1') then
--                   for debug/bring-up, not used by the controller
--                   ram_addr      <= std_logic_vector(unsigned(ram_addr) + 2);
                     if (SHORTTEST = false) then
                        addr_cnt   <= addr_cnt + 1;
                     end if;
                     case (testtype) is
                        when ALTERNATING => ram_din <= not ram_din;
                        when COUNT       => ram_din <= std_logic_vector(unsigned(ram_din) + 1);
                        when ONES        => ram_din <= (others => '1');
                        when ZEROS       => ram_din <= (others => '0');
                     end case;
                  end if;
               
               when READ_WAIT =>
                  if (ram_done = '1') then
                     state <= READ_START;
                     if ((SHORTTEST = true and addr_cnt(addr_cnt'left) = '1') or (SHORTTEST = false and addr_cnt = 0)) then
                        state    <= WRITE_START;
                        addr_cnt <= (others => '0');
                        case (testtype) is
                           when ALTERNATING => testtype <= COUNT;
                           when COUNT       => testtype <= ONES; 
                           when ONES        => testtype <= ZEROS;
                           when ZEROS       => state <= TESTDONE;
                        end case;
                     end if;
                  end if;
                        
                  if (ram_dout_valid = '1') then
                     if (ram_done = '0') then
                        if (SHORTTEST = false) then
                           addr_cnt   <= addr_cnt + 1;
                        end if;
                        case (testtype) is
                           when ALTERNATING => ram_din <= not ram_din;
                           when COUNT       => ram_din <= std_logic_vector(unsigned(ram_din) + 1);
                           when ONES        => ram_din <= (others => '1');
                           when ZEROS       => ram_din <= (others => '0');
                        end case;
                     end if;
                     
                     if (ram_dout /= ram_din) then
                        test_failed <= '1';
                     end if;
                     
                  end if;
                 
               when TESTDONE =>
                  test_finished <= '1';
         
            end case;
            
         end if;
      
      end if;
   end process;
   
end architecture;


