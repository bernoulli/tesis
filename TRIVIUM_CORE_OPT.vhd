----------------------------------------------------------------------------------
--Copyright 2011 Michael Calvin McCoy (calvin.mccoy@gmail.com). All rights reserved.
--
--Redistribution and use in source and binary forms, with or without modification, are
--permitted provided that the following conditions are met:
--
--   1. Redistributions of source code must retain the above copyright notice, this list of
--      conditions and the following disclaimer.
--
--   2. Redistributions in binary form must reproduce the above copyright notice, this list
--      of conditions and the following disclaimer in the documentation and/or other materials
--      provided with the distribution.
--
--THIS SOFTWARE IS PROVIDED BY Michael Calvin McCoy ``AS IS'' AND ANY EXPRESS OR IMPLIED
--WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
--FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Michael Calvin McCoy OR
--CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
--CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
--SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
--ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
--NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
--ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
--The views and conclusions contained in the software and documentation are those of the
--authors and should not be interpreted as representing official policies, either expressed
--or implied, of Michael Calvin McCoy.
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:36:38 09/30/2009 
-- Design Name: 
-- Module Name:    TRIVIUM_CORE - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Basic Trivium stream cipher core. 
--                              Spec: http://www.ecrypt.eu.org/stream/ciphers/trivium/trivium.pdf
--                              Test Vectors: http://www.ecrypt.eu.org/stream/svn/viewcvs.cgi/*checkout*/ecrypt/trunk/submissions/trivium/unverified.test-vectors?rev=210
--                              Includes key/IV load control as well as output control. Requires extra control logic to fully initialize.
--                      Includes litte endian conversion function so output will match offical test vectors, otherwise not required to run cipher.
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity TRIVIUM_CORE is
    Port ( SYS_CLK : in  STD_LOGIC; --System or User clock
			  CNTRL 	 : in STD_LOGIC_VECTOR(1 downto 0); --Control Bus: Manages Key/IV Loading, Init, and general operation
			  KEY     : in STD_LOGIC_VECTOR(79 downto 0); --Secret 80-bit key input port
			  IV      : in STD_LOGIC_VECTOR(79 downto 0); --80-bit Initialization vector input port
			  KEY_OUT : out STD_LOGIC);  --Cipher stream output
end TRIVIUM_CORE;

architecture Behavioral of TRIVIUM_CORE is
SIGNAL STATE : STD_LOGIC_VECTOR(287 downto 0) := (OTHERS => '0');  ---Main LFSR of the Cipher
SIGNAL k1,k2,k3,t1,t2,t3,key_stream : STD_LOGIC := '0';  ---XOR Feedback Nodes

SIGNAL KEY_FLIP : STD_LOGIC_VECTOR(79 downto 0);
SIGNAL IV_FLIP : STD_LOGIC_VECTOR(79 downto 0);

function little_endian (b: std_logic_vector) return std_logic_vector is -- 80-bit Big Endian to Little Endian Convert (bit reverses each byte)
       variable result : std_logic_vector(79 downto 0);                 --ex 0x0123456789 -> 0x084C2A6E19 
                 
   begin
       for i in 0 to 9 loop
                        result(((i*8)+7) downto (i*8)) :=       b(i*8) &
                                                                                                b((i*8) + 1) &
                                                                                                b((i*8) + 2) &
                                                                                                b((i*8) + 3) &
                                                                                                b((i*8) + 4) &
                                                                                                b((i*8) + 5) &
                                                                                                b((i*8) + 6) &
                                                                                                b((i*8) + 7);
       end loop;
       return result;
   end;

begin

MAIN_TRIVIUM : PROCESS (SYS_CLK,CNTRL) ---Core LFSR is comprised of three shift registers connected via feedback nodes (t1,t2,t3) 
begin                                                                   --Core must be loaded with key and 
        IF(SYS_CLK'event AND SYS_CLK='1') then
                IF (CNTRL = "10") then   ---Intial state setup based on spec 
					 
								STATE(110 downto 0) <= "111" & X"000000000000000000000000000"; -- 0 a 110
                        STATE(287 downto 195) <= "0000000000000" & KEY_FLIP; -- 0 a 92
                        STATE(194 downto 111) <=  X"0" & IV_FLIP;-- 0 a 83								
                                    
                ELSIF ((CNTRL = "11") OR (CNTRL = "01")) then   ---shift register mode for init and cipher generation 
								
								STATE(110 downto 0) <= STATE(109 downto 0) & t3;
                        STATE(287 downto 195) <= STATE(286 downto 195) & t1;
                        STATE(194 downto 111) <=  STATE(193 downto 111) & t2;					 
                      
                END IF; 
        END IF;         
END PROCESS;

KEY_OUTPUT : PROCESS (SYS_CLK,CNTRL)  --Output control
begin
      IF(SYS_CLK'event AND SYS_CLK='1') then
              IF (CNTRL = "01") then
						--CNTRL <= "10";
              END IF;
      END IF;
END PROCESS;  

--XOR Nodes

t1 = STATE(222) XOR STATE(195); 
t2 = STATE(126) XOR STATE(111); 
t3 = STATE(45) XOR STATE(0); 

t4 = t3 XOR ((STATE(0) AND STATE(1));
t5 = t1 XOR (((STATE(196) AND STATE(195));
t6 = t2 XOR (((STATE(112) AND STATE(111));

t7 = STATE(266) XOR STATE(197);
t8 = STATE(189) XOR STATE(111);
t9 = STATE(91) XOR STATE(4);

t1 <= t1 XOR ((STATE(197) AND STATE(196)) XOR STATE(117)); --calcular tiempo
t2 <= t2 XOR ((STATE(113) AND STATE(112)) XOR STATE(24)); --calcular tiempo
t3 <= t3 XOR ((STATE(2) AND STATE(1)) XOR STATE(219)); --calcular tiempo
                       
key_stream <= t1 XOR t2 XOR t3;

--Change input values to "little endian" so output matches offical test vectors
KEY_FLIP <= little_endian(KEY);
IV_FLIP  <= little_endian(IV);
KEY_OUT <= key_stream;

end Behavioral;