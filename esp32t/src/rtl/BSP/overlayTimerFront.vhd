library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;     

entity overlayTimerFront is 
   port 
   (
      screenX       : in  unsigned(7 downto 0);
      screenY       : in  unsigned(7 downto 0);
      overlayActive : out std_logic
   );   
end entity;

architecture arch of overlayTimerFront is

begin

   process (all)
   begin
      
      overlayActive <= '0';
      
      if (screenX >= 1 and screenX <= 39 and screenY >= 2 and screenY <= 17) then
         if ( screenX = 1 or screenX = 39   or  screenY = 2 or screenY = 17)  then overlayActive <= '1'; end if;
         if ((screenX = 1 or screenX = 39) and (screenY = 2 or screenY = 17)) then overlayActive <= '0'; end if;
      end if;
  
   end process;

   
end architecture;


