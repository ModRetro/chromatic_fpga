library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;     

entity overlayBatteryBack is 
   port 
   (
      screenX       : in  unsigned(7 downto 0);
      screenY       : in  unsigned(7 downto 0);
      overlayActive : out std_logic
   );   
end entity;

architecture arch of overlayBatteryBack is
   
begin

   process (all)
   begin
      
      overlayActive <= '0';
      
      if (screenX >= 141 and screenX <= 157 and screenY >= 3 and screenY <= 18) then
         overlayActive <= '1';
         if (screenX = 157 and (screenY = 3 or screenY = 18)) then overlayActive <= '0'; end if;
         if (screenX = 141 and                 screenY = 18)  then overlayActive <= '0'; end if;
      end if;
  
   end process;

   
end architecture;


