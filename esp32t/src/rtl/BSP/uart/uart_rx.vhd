--------------------------------------------------------------------------------
-- PROJECT: SIMPLE UART FOR FPGA
--------------------------------------------------------------------------------
-- MODULE:  UART RECEIVER
-- AUTHORS: Jakub Cabal <jakubcabal@gmail.com>
-- lICENSE: The MIT License (MIT)
-- WEBSITE: https://github.com/jakubcabal/uart_for_fpga
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_RX is
    Generic (
        P_PARITY_BIT  : string := "none" -- legal values: "none", "even", "odd", "mark", "space"
    );
    Port (
        CLK         : in  std_logic; -- system clock
        RST         : in  std_logic; -- high active synchronous reset
        -- UART INTERFACE
        --UART_CLK_EN : in  std_logic; -- oversampling (15x) UART clock enable
        UART_RXD    : in  std_logic;
        -- UART PARAMETER
        PARITY_BIT  : in  std_logic_vector(7 downto 0);
        STOP_BIT    : in  std_logic_vector(7 downto 0);
        DATA_BITS   : in  std_logic_vector(7 downto 0);
        DIVIDER_VALUE : in  std_logic_vector(23 downto 0);
        DIV_CORRECT  : in  std_logic_vector(1 downto 0);
        -- USER DATA OUTPUT INTERFACE
        DATA_OUT    : out std_logic_vector(15 downto 0);
        DATA_VLD    : out std_logic; -- when DATA_VLD = 1, data on DATA_OUT are valid
        FRAME_ERROR : out std_logic  -- when FRAME_ERROR = 1, stop bit was invalid, current and next data may be invalid
    );
end UART_RX;

architecture FULL of UART_RX is

    signal rx_clk_en          : std_logic;
    signal rx_hf_clk_en       : std_logic;
    signal rx_ticks           : unsigned(23 downto 0);
    signal rx_clk_divider_en  : std_logic;
    signal rx_data            : std_logic_vector(15 downto 0);
    signal parity_bit_reg     : std_logic_vector(7 downto 0);
    signal stop_bit_reg       : std_logic_vector(7 downto 0);
    signal data_bits_reg      : std_logic_vector(7 downto 0);
    signal divider_value_reg  : std_logic_vector(23 downto 0);
    signal div_correct_reg    : std_logic_vector(1 downto 0);
    signal rx_bit_count       : unsigned(3 downto 0);
    signal rx_bit_count_en    : std_logic;
    signal rx_data_shreg_en   : std_logic;
    signal rx_parity_bit      : std_logic;
    signal rx_parity_error    : std_logic;
    signal parity_temp        : std_logic;
    signal rx_parity_check_en : std_logic;
    signal rx_output_reg_en   : std_logic;
    signal rx_busy            : std_logic;
    signal uart_ticks         : unsigned(15 downto 0);
    signal uart_clk_en        : std_logic;

    type state is (idle, startbit, databits, paritybit, stopbit, stopbit15, stopbit2);
    signal rx_pstate : state;
    signal rx_nstate : state;

begin

    -- -------------------------------------------------------------------------
    -- UART RECEIVER CLOCK DIVIDER
    -- -------------------------------------------------------------------------

    uart_rx_sample_clk : process (CLK)
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

    uart_rx_clk_divider : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (rx_clk_divider_en = '1') then
                --if (uart_clk_en = '1') then
                    --if (rx_ticks = "1110") then
                if ((rx_bit_count(1 downto 0) = "01") AND (div_correct_reg(1 downto 1) = "1")) then
                    if (rx_ticks = (unsigned(divider_value_reg))) then
                        rx_ticks <= (others => '0');
                        rx_clk_en <= '0';
                        rx_hf_clk_en <= '1';
                    --elsif (rx_ticks = "0111") then
                    elsif (rx_ticks = (unsigned(divider_value_reg) srl 1)) then
                        rx_ticks <= rx_ticks + 1;
                        rx_clk_en <= '1';
                        rx_hf_clk_en <= '1';
                    else
                        rx_ticks <= rx_ticks + 1;
                        rx_clk_en <= '0';
                        rx_hf_clk_en <= '0';
                    end if;
                elsif ((rx_bit_count(1 downto 0) = "10") AND (div_correct_reg(1 downto 0) = "11")) then
                    if (rx_ticks = (unsigned(divider_value_reg))) then
                        rx_ticks <= (others => '0');
                        rx_clk_en <= '0';
                        rx_hf_clk_en <= '1';
                    --elsif (rx_ticks = "0111") then
                    elsif (rx_ticks = (unsigned(divider_value_reg) srl 1)) then
                        rx_ticks <= rx_ticks + 1;
                        rx_clk_en <= '1';
                        rx_hf_clk_en <= '1';
                    else
                        rx_ticks <= rx_ticks + 1;
                        rx_clk_en <= '0';
                        rx_hf_clk_en <= '0';
                    end if;
                 elsif ((rx_bit_count(1 downto 0) = "11") AND (div_correct_reg(1 downto 0) /= "00")) then
                    if (rx_ticks = (unsigned(divider_value_reg))) then
                        rx_ticks <= (others => '0');
                        rx_clk_en <= '0';
                        rx_hf_clk_en <= '1';
                    --elsif (rx_ticks = "0111") then
                    elsif (rx_ticks = (unsigned(divider_value_reg) srl 1)) then
                        rx_ticks <= rx_ticks + 1;
                        rx_clk_en <= '1';
                        rx_hf_clk_en <= '1';
                    else
                        rx_ticks <= rx_ticks + 1;
                        rx_clk_en <= '0';
                        rx_hf_clk_en <= '0';
                    end if;
                else
                    if (rx_ticks = (unsigned(divider_value_reg) - 1)) then
                        rx_ticks <= (others => '0');
                        rx_clk_en <= '0';
                        rx_hf_clk_en <= '1';
                    --elsif (rx_ticks = "0111") then
                    elsif (rx_ticks = (unsigned(divider_value_reg) srl 1)) then
                        rx_ticks <= rx_ticks + 1;
                        rx_clk_en <= '1';
                        rx_hf_clk_en <= '1';
                    else
                        rx_ticks <= rx_ticks + 1;
                        rx_clk_en <= '0';
                        rx_hf_clk_en <= '0';
                    end if;
                end if;
                --else
                --    rx_ticks <= rx_ticks;
                --    rx_clk_en <= '0';
                --    rx_hf_clk_en <= '0';
                --end if;
            else
                rx_ticks <= (others => '0');
                rx_clk_en <= '0';
                rx_hf_clk_en <= '0';
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- UART RECEIVER BIT COUNTER
    -- -------------------------------------------------------------------------

    uart_rx_bit_counter : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                rx_bit_count <= (others => '0');
            elsif (rx_bit_count_en = '1' AND rx_clk_en = '1') then
                if (rx_bit_count = "1111") then
                    rx_bit_count <= (others => '0');
                else
                    rx_bit_count <= rx_bit_count + 1;
                end if;
            elsif (rx_bit_count_en = '0') then
                rx_bit_count <= (others => '0');
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- UART RECEIVER DATA SHIFT REGISTER
    -- -------------------------------------------------------------------------

    uart_rx_data_shift_reg : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                rx_data <= (others => '0');
            elsif (rx_clk_en = '1' AND rx_data_shreg_en = '1') then
                if (data_bits_reg = "00000101") then
                    rx_data <= "00000000000" & UART_RXD & rx_data(4 downto 1);
                elsif (data_bits_reg = "00000110") then
                    rx_data <= "0000000000" & UART_RXD & rx_data(5 downto 1);
                elsif (data_bits_reg = "00000111") then
                    rx_data <= "000000000" & UART_RXD & rx_data(6 downto 1);
                elsif (data_bits_reg = "00001000") then
                    rx_data <= "00000000" & UART_RXD & rx_data(7 downto 1);
                else
                    rx_data <= UART_RXD & rx_data(15 downto 1);
                end if;
            end if;
        end if;
    end process;

    DATA_OUT <= rx_data;

    uart_rx_ctrl_reg : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                parity_bit_reg <= (others => '0');
                stop_bit_reg   <= (others => '0');
                data_bits_reg  <= (others => '0');
                divider_value_reg  <= (others => '0');
                div_correct_reg <= "00";
            elsif (rx_busy = '0') then
                parity_bit_reg <= PARITY_BIT;
                stop_bit_reg   <= STOP_BIT;
                data_bits_reg  <= DATA_BITS;
                divider_value_reg  <= DIVIDER_VALUE;
                div_correct_reg <= DIV_CORRECT;
                --divider_value_reg  <= "00100000";
            end if;
        end if;
    end process;
    -- -------------------------------------------------------------------------
    -- UART RECEIVER PARITY GENERATOR AND CHECK
    -- -------------------------------------------------------------------------

    --uart_rx_parity_g : if (P_PARITY_BIT /= "none") generate
    --    uart_rx_parity_gen_i: entity work.UART_PARITY
    --    generic map (
    --        DATA_WIDTH  => 8,
    --        PARITY_TYPE => P_PARITY_BIT
    --    )
    --    port map (
    --        DATA_IN     => rx_data,
    --        PARITY_OUT  => rx_parity_bit
    --    );
    --end generate;

    parity_gen : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                parity_temp <= '0';
            elsif (parity_bit_reg = "00000000") then --none
                parity_temp <= '0';
            elsif (parity_bit_reg = "00000001") then --odd
                if (rx_pstate = startbit) then
                    parity_temp <= '1';
                elsif (rx_bit_count_en = '1' AND rx_clk_en = '1') then
                    parity_temp <= parity_temp XOR UART_RXD;
                end if;
            elsif (parity_bit_reg = "00000010") then --even
                if (rx_pstate = startbit) then
                    parity_temp <= '0';
                elsif (rx_bit_count_en = '1' AND rx_clk_en = '1') then
                    parity_temp <= parity_temp XOR UART_RXD;
                end if;
            elsif (parity_bit_reg = "00000011") then --mark
                parity_temp <= '1';
            elsif (parity_bit_reg = "00000100") then --space
                parity_temp <= '0';
            end if;
        end if;
    end process;

        uart_rx_parity_check_reg : process (CLK)
        begin
            if (rising_edge(CLK)) then
                if (RST = '1') then
                    rx_parity_error <= '0';
                elsif (rx_parity_check_en = '1') then
                    --rx_parity_error <= rx_parity_bit XOR UART_RXD;
                    if (parity_bit_reg = "00000000") then
                        rx_parity_error <= '0';
                    else
                        rx_parity_error <= parity_temp XOR UART_RXD;
                    end if;
                end if;
            end if;
        end process;

    --uart_rx_noparity_g : if (PARITY_BIT = "none") generate
    --    rx_parity_error <= '0';
    --end generate;

    -- -------------------------------------------------------------------------
    -- UART RECEIVER OUTPUT REGISTER
    -- -------------------------------------------------------------------------

    uart_rx_output_reg : process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                DATA_VLD <= '0';
                FRAME_ERROR <= '0';
            else
                if (rx_output_reg_en = '1') then
                    DATA_VLD <= NOT rx_parity_error AND UART_RXD;
                    FRAME_ERROR <= NOT UART_RXD;
                else
                    DATA_VLD <= '0';
                    FRAME_ERROR <= '0';
                end if;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- UART RECEIVER FSM
    -- -------------------------------------------------------------------------

    -- PRESENT STATE REGISTER
    process (CLK)
    begin
        if (rising_edge(CLK)) then
            if (RST = '1') then
                rx_pstate <= idle;
            else
                rx_pstate <= rx_nstate;
            end if;
        end if;
    end process;

    -- NEXT STATE AND OUTPUTS LOGIC
    process (rx_pstate, UART_RXD,  rx_hf_clk_en, rx_clk_en, rx_bit_count, data_bits_reg, parity_bit_reg, stop_bit_reg)
    begin
        case rx_pstate is

            when idle =>
                rx_output_reg_en <= '0';
                rx_bit_count_en <= '0';
                rx_data_shreg_en <= '0';
                rx_clk_divider_en <= '0';
                rx_parity_check_en <= '0';
                rx_busy <= '0';
                if (UART_RXD = '0') then
                    rx_nstate <= startbit;
                else
                    rx_nstate <= idle;
                end if;

            when startbit =>
                rx_output_reg_en <= '0';
                rx_bit_count_en <= '0';
                rx_data_shreg_en <= '0';
                rx_clk_divider_en <= '1';
                rx_parity_check_en <= '0';
                rx_busy <= '1';

                if (rx_clk_en = '1') then
                    rx_nstate <= databits;
                else
                    rx_nstate <= startbit;
                end if;

            when databits =>
                rx_output_reg_en <= '0';
                rx_bit_count_en <= '1';
                rx_data_shreg_en <= '1';
                rx_clk_divider_en <= '1';
                rx_parity_check_en <= '0';
                rx_busy <= '1';

                --if ((rx_clk_en = '1') AND (rx_bit_count = "111")) then
                if (rx_clk_en = '1') then
                    if ((data_bits_reg = "00000101") AND (rx_bit_count = "0100")) then --data bit 5
                        if (parity_bit_reg = "00000000") then
                            rx_nstate <= stopbit;
                        else
                            rx_nstate <= paritybit;
                        end if ;
                    elsif ((data_bits_reg = "00000110") AND (rx_bit_count = "0101")) then --data bit 6
                        if (parity_bit_reg = "00000000") then
                            rx_nstate <= stopbit;
                        else
                            rx_nstate <= paritybit;
                        end if ;
                    elsif ((data_bits_reg = "00000111") AND (rx_bit_count = "0110")) then --data bit 7
                        if (parity_bit_reg = "00000000") then
                            rx_nstate <= stopbit;
                        else
                            rx_nstate <= paritybit;
                        end if ;
                    elsif ((data_bits_reg = "00001000") AND (rx_bit_count = "0111")) then --data bit 8
                        if (parity_bit_reg = "00000000") then
                            rx_nstate <= stopbit;
                        else
                            rx_nstate <= paritybit;
                        end if ;
                    elsif ((data_bits_reg = "00010000") AND (rx_bit_count = "1111")) then --data bit 16
                        if (parity_bit_reg = "00000000") then
                            rx_nstate <= stopbit;
                        else
                            rx_nstate <= paritybit;
                        end if ;
                    else
                        rx_nstate <= databits;
                    end if;
                else
                    rx_nstate <= databits;
                end if;

            when paritybit =>
                rx_output_reg_en <= '0';
                rx_bit_count_en <= '0';
                rx_data_shreg_en <= '0';
                rx_clk_divider_en <= '1';
                rx_parity_check_en <= '1';
                rx_busy <= '1';

                if (rx_clk_en = '1') then
                    rx_nstate <= stopbit;
                else
                    rx_nstate <= paritybit;
                end if;

            when stopbit =>
                rx_bit_count_en <= '0';
                rx_data_shreg_en <= '0';
                rx_clk_divider_en <= '1';
                rx_parity_check_en <= '0';
                rx_busy <= '1';

                if (rx_clk_en = '1') then
                    if (stop_bit_reg = "00000000") then --Stop bit 1
                        rx_nstate <= idle;
                        rx_output_reg_en <= '1';
                    elsif (stop_bit_reg = "00000001") then --Stop bit 1.5
                        rx_nstate <= stopbit15;
                        rx_output_reg_en <= '0';
                    elsif (stop_bit_reg = "00000010") then --Stop bit 2
                        rx_nstate <= stopbit2;
                        rx_output_reg_en <= '0';
                    else
                        rx_nstate <= idle;
                        rx_output_reg_en <= '1';
                    end if;
                else
                    rx_nstate <= stopbit;
                    rx_output_reg_en <= '0';
                end if;

            when stopbit15 =>
                rx_bit_count_en <= '0';
                rx_data_shreg_en <= '0';
                rx_clk_divider_en <= '1';
                rx_parity_check_en <= '0';
                rx_busy <= '1';

                if (rx_hf_clk_en = '1') then
                    rx_nstate <= idle;
                    rx_output_reg_en <= '1';
                else
                    rx_nstate <= stopbit15;
                    rx_output_reg_en <= '0';
                end if;

            when stopbit2 =>
                rx_bit_count_en <= '0';
                rx_data_shreg_en <= '0';
                rx_clk_divider_en <= '1';
                rx_parity_check_en <= '0';
                rx_busy <= '1';

                if (rx_clk_en = '1') then
                    rx_nstate <= idle;
                    rx_output_reg_en <= '1';
                else
                    rx_nstate <= stopbit2;
                    rx_output_reg_en <= '0';
                end if;

            when others =>
                rx_output_reg_en <= '0';
                rx_bit_count_en <= '0';
                rx_data_shreg_en <= '0';
                rx_clk_divider_en <= '0';
                rx_parity_check_en <= '0';
                rx_nstate <= idle;

        end case;
    end process;

end FULL;
