library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity GM_FSM is
    port(
            inclk:          in std_logic;
            but_n, rst_n:   in std_logic;
            glitch:         in std_logic;
            sw:             in std_logic_vector(7 downto 0);
            dir:            in std_logic;
            seg7_1:         out std_logic_vector(6 downto 0);
            seg7_2:         out std_logic_vector(6 downto 0);
            seg7_3:         out std_logic_vector(6 downto 0);
            seg7_4:         out std_logic_vector(6 downto 0);
            state_led:      out std_logic_vector(1 downto 0);
            dir_led:        out std_logic;
            p_out:          inout std_logic
         );
end GM_FSM;

architecture gm of GM_FSM is
    type t_state is (Config, WaitBut, Pulse);
    signal state: t_state;
    signal num_1, num_2: std_logic_vector(3 downto 0) := "0000";
    signal counter_0, counter_1: std_logic_vector(3 downto 0) := "0000";
    signal multiplier: std_logic_vector(7 downto 0) := "00000000";
    signal clk: std_logic := '0';
    signal but_n_de, rst_n_de: std_logic := '1';
    signal direction: std_logic;
    component PLL
        port(
                inclk0: in std_logic;
                c0:     out std_logic
            );
    end component;
    component SEG7
        port (
                i_dig:  in std_logic_vector(3 downto 0);
                o_dig:  out std_logic_vector(6 downto 0)
              );
    end component;
    component DEBOUNCE
        port (
                clk:        in std_logic;
                in_n:       in std_logic;
                out_n:  out std_logic
              );
    end component;
begin
    pll1: PLL
        port map (inclk, clk);
    seg1: SEG7
        port map (num_1, seg7_1);
    seg2: SEG7
        port map (num_2, seg7_2);
    seg3: SEG7
        port map (counter_0, seg7_3);
    seg4: SEG7
        port map (counter_1, seg7_4);
    but1: DEBOUNCE
        port map (clk, but_n, but_n_de);
    but2: DEBOUNCE
        port map (clk, rst_n, rst_n_de);
        
    fsm: process (clk)
        variable cnt: integer := 0;
        variable glitch_cnt: integer := 0;
    begin
        if (rising_edge(clk)) then
            counter_0 <= std_logic_vector(to_unsigned(glitch_cnt, counter_0'length * 2))(3 downto 0);
            counter_1 <= std_logic_vector(to_unsigned(glitch_cnt, counter_1'length * 2))(7 downto 4);
                    
            num_1 <= multiplier(3 downto 0);
            num_2 <= multiplier(7 downto 4);
            
            dir_led <= direction;
        
            case state is
                when Config =>
                    glitch_cnt := 0;
                    state_led <= "01";
                    p_out <= 'Z';
                    
                    multiplier <= sw;
                    direction <= dir;
                    
                    if (rst_n_de = '1' and (but_n_de = '0' or glitch='0') and multiplier > "00000000") then
                        state <= WaitBut;
                    end if;                 
                when WaitBut =>
                    cnt := 0;
                    state_led <= "10";
                    p_out <= 'Z';
                    
                    if (rst_n_de = '0') then
                        state <= Config;
                    elsif (but_n_de = '0' or glitch='0') then
                        glitch_cnt := glitch_cnt + 1;
                        if (glitch_cnt = 256) then
                            glitch_cnt := 0;
                        end if;
                        state <= Pulse;
                    end if;
                when Pulse =>
                    if (rst_n_de = '0') then
                        state <= Config;
                    end if;
                    
                    p_out <= '1' xor direction;
                    
                    if (cnt = to_integer(unsigned(multiplier))) then
                        -- for debugging w/ a probe: p_out <= '0' xor direction;
                        state <= WaitBut;
                    else
                        cnt := cnt + 1;
                    end if;
            end case;
        end if;
    end process fsm;
end architecture gm;