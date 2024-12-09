library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;     

entity overlayBatteryFront is 
   port 
   (
      screenX       : in  unsigned(7 downto 0);
      screenY       : in  unsigned(7 downto 0);
      overlayActive : out std_logic
   );   
end entity;

architecture arch of overlayBatteryFront is

   type tpixeldata is array (0 to 15) of std_logic_vector(0 to 16);
   constant pixeldata : tpixeldata := 
   (
      "01111111111111110",
      "10000000000000001",
      "10000000000000001",
      "10000000000000001",
      "10000000000000001",
      "10001111111110001",
      "10001000000010001",
      "10001010000011001",
      "10001010000011001",
      "10001000000010001",
      "10001111111110001",
      "10000000000000001",
      "10000000000000001",
      "10000000000000001",
      "10000000000000001",
      "01111111111111110"
   );

   
begin

   process (all)
   begin
      
      overlayActive <= '0';
      
      if (screenX >= 140 and screenX <= 156 and screenY >= 2 and screenY <= 17) then
         if (pixeldata(to_integer(screenY) - 2)(to_integer(screenX) - 140) = '1') then
            overlayActive <= '1';
         end if;
      end if;
  
   end process;

   
end architecture;


