--------------------------------------------------------------------------------
-- PROJECT: SIMPLE UART FOR FPGA
--------------------------------------------------------------------------------
-- MODULE:  UART TRANSMITTER
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- lICENSE: The MIT License (MIT)
-- WEBSITE: https://github.com/jakubcabal/uart_for_fpga
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_TX is
    --Generic (
        --PARITY_BIT  : string := "none" -- legal values: "none", "even", "odd", "mark", "space"
    --);
    Port (
        CLK         : in  std_logic; -- system clock
        RST         : in  std_logic; -- high active synchronous reset
        -- UART INTERFACE
        --UART_CLK_EN : in  std_logic; -- oversampling (15x) UART clock enable
        UART_TXD    : out std_logic;
        -- UART PARAMETER
        PARITY_BIT  : in  std_logic_vector(7 downto 0);
        STOP_BIT    : in  std_logic_vector(7 downto 0);
        DATA_BITS   : in  std_logic_vector(7 downto 0);
        DIVIDER_VALUE : in  std_logic_vector(23 downto 0);
        DIV_CORRECT  : in  std_logic_vector(1 downto 0);
        -- USER DATA INPUT INTERFACE
        DATA_IN     : in  std_logic_vector(15 downto 0);
        DATA_SEND   : in  std_logic; -- when DATA_SEND = 1, data on DATA_IN will be transmit, DATA_SEND can set to 1 only when BUSY = 0
        BUSY        : out std_logic  -- when BUSY = 1 transiever is busy, you must not set DATA_SEND to 1
    );
end UART_TX;

architecture FULL of UART_TX is

    signal tx_clk_en         : std_logic;
    signal tx_hf_clk_en      : std_logic;
    signal tx_clk_divider_en : std_logic;
    signal tx_ticks          : unsigned(23 downto 0);
    signal tx_data           : std_logic_vector(15 downto 0);
    signal parity_bit_reg    : std_logic_vector(7 downto 0);
    signal stop_bit_reg      : std_logic_vector(7 downto 0);
    signal data_bits_reg     : std_logic_vector(7 downto 0);
    signal divider_value_reg : std_logic_vector(23 downto 0);
    signal div_correct_reg   : std_logic_vector(1 downto 0);
    signal tx_bit_count      : unsigned(3 downto 0);
    signal tx_bit_count_en   : std_logic;
    signal tx_busy           : std_logic;
    signal tx_parity_bit     : std_logic;
    signal parity_temp       : std_logic;
    signal tx_data_out_sel   : std_logic_vector(1 downto 0);
    signal uart_ticks        : unsigned(15 downto 0);
    signal uart_clk_en       : std_logic;

    type state is (idle, txsync, startbit, databits, paritybit, stopbit, stopbit15, stopbit2);
    signal tx_pstate : state;
    signal tx_nstate : state;

begin

    BUSY <= tx_busy OR DATA_SEND;

    -- -------------------------------------------------------------------------
    -- UART TRANSMITTER CLOCK DIVIDER
    -- -------------------------------------------------------------------------

    uart_tx_sample_clk : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                uart_ticks <= (others => '0');
                uart_clk_en <= '0';
            else
                if (uart_ticks = (unsigned(divider_value_reg) - 1)) then
                    uart_ticks <= (others => '0');
                    uart_clk_en <= '1';
                else
                    uart_ticks <= uart_ticks + 1;
                    uart_clk_en <= '0';
                end if;
            end if;
         end if;
    end process;

    uart_tx_clk_divider : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (tx_clk_divider_en = '1') then
                --if (uart_clk_en = '1') thediv
                    --if (tx_ticks = "1110") then
                 if ((tx_bit_count(1 downto 0) = "01") AND (div_correct_reg(1 downto 1) = "1")) then
                    if (tx_ticks = (unsigned(divider_value_reg))) then
                        tx_ticks <= (others => '0');
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '0';
                    --elsif (tx_ticks = "0001") then
                    elsif (tx_ticks = "000000000000000000000001") then
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '1';
                        tx_hf_clk_en <= '1';
                    --elsif (tx_ticks = "1001") then
                    elsif (tx_ticks = (unsigned(divider_value_reg) srl 1) + 1) then
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '1';
                    else
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '0';
                    end if;
                 elsif ((tx_bit_count(1 downto 0) = "10") AND (div_correct_reg(1 downto 0) = "11")) then
                    if (tx_ticks = (unsigned(divider_value_reg))) then
                        tx_ticks <= (others => '0');
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '0';
                    --elsif (tx_ticks = "0001") then
                    elsif (tx_ticks = "000000000000000000000001") then
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '1';
                        tx_hf_clk_en <= '1';
                    --elsif (tx_ticks = "1001") then
                    elsif (tx_ticks = (unsigned(divider_value_reg) srl 1) + 1) then
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '1';
                    else
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '0';
                    end if;
                 elsif ((tx_bit_count(1 downto 0) = "11") AND (div_correct_reg(1 downto 0) /= "00")) then
                    if (tx_ticks = (unsigned(divider_value_reg))) then
                        tx_ticks <= (others => '0');
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '0';
                    --elsif (tx_ticks = "0001") then
                    elsif (tx_ticks = "000000000000000000000001") then
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '1';
                        tx_hf_clk_en <= '1';
                    --elsif (tx_ticks = "1001") then
                    elsif (tx_ticks = (unsigned(divider_value_reg) srl 1) + 1) then
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '1';
                    else
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '0';
                    end if;
                else
                    if (tx_ticks = (unsigned(divider_value_reg) - 1)) then
                        tx_ticks <= (others => '0');
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '0';
                    --elsif (tx_ticks = "0001") then
                    elsif (tx_ticks = "000000000000000000000001") then
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '1';
                        tx_hf_clk_en <= '1';
                    --elsif (tx_ticks = "1001") then
                    elsif (tx_ticks = (unsigned(divider_value_reg) srl 1) + 1) then
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '1';
                    else
                        tx_ticks <= tx_ticks + 1;
                        tx_clk_en <= '0';
                        tx_hf_clk_en <= '0';
                    end if;
                end if;
                --else
                --    tx_ticks <= tx_ticks;
                --    tx_clk_en <= '0';
                --    tx_hf_clk_en <= '0';
                --end if;
            else
                tx_ticks <= (others => '0');
                tx_clk_en <= '0';
                tx_hf_clk_en <= '0';
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- UART TRANSMITTER INPUT DATA REGISTER
    -- -------------------------------------------------------------------------

    uart_tx_input_data_reg : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                tx_data <= (others => '0');
            elsif (DATA_SEND = '1' AND tx_busy = '0') then
                tx_data <= DATA_IN;
            end if;
        end if;
    end process;

    uart_tx_ctrl_reg : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                parity_bit_reg <= (others => '0');
                stop_bit_reg  <= (others => '0');
                data_bits_reg <= "00001000";
                divider_value_reg <= "000000000000000000100000";
                div_correct_reg <= "00";
            elsif ((tx_pstate = txsync) or (tx_pstate = idle)) then
            --else
                parity_bit_reg <= PARITY_BIT;
                stop_bit_reg   <= STOP_BIT;
                data_bits_reg  <= DATA_BITS;
                divider_value_reg <= DIVIDER_VALUE;
                div_correct_reg <= DIV_CORRECT;
            end if;
        end if;
    end process;
    -- -------------------------------------------------------------------------
    -- UART TRANSMITTER BIT COUNTER
    -- -------------------------------------------------------------------------

    uart_tx_bit_counter : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                tx_bit_count <= (others => '0');
            elsif (tx_bit_count_en = '1' AND tx_clk_en = '1') then
                if (tx_bit_count = "1111") then
                    tx_bit_count <= (others => '0');
                else
                    tx_bit_count <= tx_bit_count + 1;
                end if;
            elsif (tx_bit_count_en = '0') then
                tx_bit_count <= (others => '0');
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- UART TRANSMITTER PARITY GENERATOR
    -- -------------------------------------------------------------------------

    --uart_tx_parity_g : if (PARITY_BIT /= "none") generate
    --uart_tx_parity_g uart_tx_parity_gen_i: entity work.UART_PARITY
    --    generic map (
    --        DATA_WIDTH  => 8,
    --        PARITY_TYPE => PARITY_BIT
    --    )
    --    port map (
    --        DATA_IN     => tx_data,
    --        PARITY_OUT  => tx_parity_bit
    --    );
    --end generate;

    --uart_tx_noparity_g : if (PARITY_BIT = "none") generate
    --    tx_parity_bit <= 'Z';
    --end generate;

    tx_parity_bit <= parity_temp;
    -- -------------------------------------------------------------------------
    -- UART TRANSMITTER OUTPUT DATA REGISTER
    -- -------------------------------------------------------------------------

    uart_tx_output_data_reg : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                UART_TXD <= '1';
            else
                case tx_data_out_sel is
                    when "01" => -- START BIT
                        UART_TXD <= '0';
                    when "10" => -- DATA BITS
                        UART_TXD <= tx_data(to_integer(tx_bit_count));
                    when "11" => -- PARITY BIT
                        UART_TXD <= tx_parity_bit;
                    when others => -- STOP BIT OR IDLE
                        UART_TXD <= '1';
                end case;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- UART PARITY GEN
    -- -------------------------------------------------------------------------
    parity_gen : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                parity_temp <= '0';
            elsif (parity_bit_reg = "00000000") then --none
                parity_temp <= '0';
            elsif (parity_bit_reg = "00000001") then --odd
                if (tx_pstate = startbit) then
                    parity_temp <= '1';
                elsif (tx_bit_count_en = '1' AND tx_clk_en = '1') then
                    parity_temp <= parity_temp XOR tx_data(to_integer(tx_bit_count));
                end if;
            elsif (parity_bit_reg = "00000010") then --even
                if (tx_pstate = startbit) then
                    parity_temp <= '0';
                elsif (tx_bit_count_en = '1' AND tx_clk_en = '1') then
                    parity_temp <= parity_temp XOR tx_data(to_integer(tx_bit_count));
                end if;
            elsif (parity_bit_reg = "00000011") then --mark
                parity_temp <= '1';
            elsif (parity_bit_reg = "00000100") then --space
                parity_temp <= '0';
            end if;
        end if;
    end process;
    -- -------------------------------------------------------------------------
    -- UART TRANSMITTER FSM
    -- -------------------------------------------------------------------------

    -- PRESENT STATE REGISTER
    --process (CLK)
    --begin
    --    if (rising_edge(CLK)) then
    --        if (RST = '1') then
    --            tx_pstate <= idle;
    --        else
    --            tx_pstate <= tx_nstate;
    --        end if;
    --    end if;
    --end process;

    -- NEXT STATE AND OUTPUTS LOGIC
    -- process (tx_pstate, DATA_SEND, tx_hf_clk_en, tx_clk_en, tx_bit_count)
    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                tx_pstate <= idle;
            else
                case tx_pstate is
                    when idle =>
                        tx_busy <= '0';
                        tx_data_out_sel <= "00";
                        tx_bit_count_en <= '0';
                        tx_clk_divider_en <= '0';
                
                        if (DATA_SEND = '1') then
                            tx_pstate <= txsync;
                        else
                            tx_pstate <= idle;
                        end if;
                
                    when txsync =>
                        tx_busy <= '1';
                        tx_data_out_sel <= "00";
                        tx_bit_count_en <= '0';
                        tx_clk_divider_en <= '1';
                
                        --if (stop_bit_reg = "00000000") then
                        --    if (tx_clk_en = '1') then
                        --        tx_pstate <= startbit;
                        --    else
                        --        tx_pstate <= txsync;
                        --    end if;
                        --elsif (stop_bit_reg = "00000001") then
                        --    if (tx_hf_clk_en = '1') then
                        --        tx_pstate <= startbit;
                        --    else
                        --        tx_pstate <= txsync;
                        --    end if;
                        --elsif (stop_bit_reg = "00000010") then
                        --    if (tx_clk_en = '1') then
                        --        tx_pstate <= startbit;
                        --    else
                        --        tx_pstate <= txsync;
                        --    end if;
                        --end if;
                            if (tx_clk_en = '1') then
                                tx_pstate <= startbit;
                            else
                                tx_pstate <= txsync;
                            end if;
                    when startbit =>
                        tx_busy <= '1';
                        tx_data_out_sel <= "01";
                        tx_bit_count_en <= '0';
                        tx_clk_divider_en <= '1';
                
                        if (tx_clk_en = '1') then
                            tx_pstate <= databits;
                        else
                            tx_pstate <= startbit;
                        end if;
                
                    when databits =>
                        tx_busy <= '1';
                        tx_data_out_sel <= "10";
                        tx_bit_count_en <= '1';
                        tx_clk_divider_en <= '1';
                
                        --if ((tx_clk_en = '1') AND (tx_bit_count = "111")) then
                        if (tx_clk_en = '1') then
                            if ((data_bits_reg = "00000101") AND (tx_bit_count = "0100")) then --5 bit
                                if (parity_bit_reg = "00000000") then
                                    tx_pstate <= stopbit;
                                else
                                    tx_pstate <= paritybit;
                                end if ;
                            elsif ((data_bits_reg = "00000110") AND (tx_bit_count = "0101")) then --6 bit
                                if (parity_bit_reg = "00000000") then
                                    tx_pstate <= stopbit;
                                else
                                    tx_pstate <= paritybit;
                                end if ;
                            elsif ((data_bits_reg = "00000111") AND (tx_bit_count = "0110")) then --7 bit
                                if (parity_bit_reg = "00000000") then
                                    tx_pstate <= stopbit;
                                else
                                    tx_pstate <= paritybit;
                                end if ;
                            elsif ((data_bits_reg = "00001000") AND (tx_bit_count = "0111")) then --8 bit
                                if (parity_bit_reg = "00000000") then
                                    tx_pstate <= stopbit;
                                else
                                    tx_pstate <= paritybit;
                                end if ;
                            elsif ((data_bits_reg = "00010000") AND (tx_bit_count = "1111")) then --16 bit
                                if (parity_bit_reg = "00000000") then
                                    tx_pstate <= stopbit;
                                else
                                    tx_pstate <= paritybit;
                                end if ;
                            else
                                tx_pstate <= databits;
                            end if ;
                        else
                            tx_pstate <= databits;
                        end if;
                
                    when paritybit =>
                        tx_busy <= '1';
                        tx_data_out_sel <= "11";
                        tx_bit_count_en <= '0';
                        tx_clk_divider_en <= '1';
                
                        if (tx_clk_en = '1') then
                            tx_pstate <= stopbit;
                        else
                            tx_pstate <= paritybit;
                        end if;
                
                    when stopbit =>
                        tx_data_out_sel <= "00";
                        tx_bit_count_en <= '0';
                        tx_clk_divider_en <= '1';
                        if (stop_bit_reg = "00000000") then
                            tx_busy <= '0';
                            if (DATA_SEND = '1') then
                                tx_pstate <= txsync;
                            elsif (tx_clk_en = '1') then
                                tx_pstate <= idle;
                            else
                                tx_pstate <= stopbit;
                            end if;
                        elsif (stop_bit_reg = "00000001") then
                            tx_busy <= '1';
                            if (tx_clk_en = '1') then
                                tx_pstate <= stopbit15;
                            else
                                tx_pstate <= stopbit;
                            end if;
                        elsif (stop_bit_reg = "00000010") then
                            if (tx_clk_en = '1') then
                                tx_pstate <= stopbit2;
                            else
                                tx_pstate <= stopbit;
                            end if;
                        end if;
                
                    when stopbit15 =>
                        tx_data_out_sel <= "00";
                        tx_bit_count_en <= '0';
                        tx_clk_divider_en <= '1';
                        tx_busy <= '0';
                        if (DATA_SEND = '1') then
                            tx_pstate <= txsync;
                        elsif (tx_hf_clk_en = '1') then
                            tx_pstate <= idle;
                        else
                            tx_pstate <= stopbit15;
                        end if;
                
                    when stopbit2 =>
                        tx_data_out_sel <= "00";
                        tx_bit_count_en <= '0';
                        tx_clk_divider_en <= '1';
                        tx_busy <= '0';
                        if (DATA_SEND = '1') then
                            tx_pstate <= txsync;
                        elsif (tx_clk_en = '1') then
                            tx_pstate <= idle;
                        else
                            tx_pstate <= stopbit2;
                        end if;
                
                    when others =>
                        tx_busy <= '1';
                        tx_data_out_sel <= "00";
                        tx_bit_count_en <= '0';
                        tx_clk_divider_en <= '0';
                        tx_pstate <= idle;
                end case;
            end if;
        end if;
    end process;

end FULL;
