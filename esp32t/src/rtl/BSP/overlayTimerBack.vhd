library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;     

entity overlayTimerBack is 
   port 
   (
      screenX       : in  unsigned(7 downto 0);
      screenY       : in  unsigned(7 downto 0);
      overlayActive : out std_logic
   );   
end entity;

architecture arch of overlayTimerBack is

begin

   process (all)
   begin
      
      overlayActive <= '0';
      
      if (screenX >= 2 and screenX <= 40 and screenY >= 3 and screenY <= 18) then
         overlayActive <= '1';
         if (screenX = 40 and (screenY = 3 or screenY = 18)) then overlayActive <= '0'; end if;
         if (screenX = 2  and                 screenY = 18)  then overlayActive <= '0'; end if;
      end if;
  
   end process;

   
end architecture;


