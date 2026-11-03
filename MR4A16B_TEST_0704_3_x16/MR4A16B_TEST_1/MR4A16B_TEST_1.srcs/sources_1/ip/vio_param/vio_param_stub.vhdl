-- Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2018.3 (win64) Build 2405991 Thu Dec  6 23:38:27 MST 2018
-- Date        : Fri Dec 27 09:47:10 2024
-- Host        : PC-ZIJING running 64-bit major release  (build 9200)
-- Command     : write_vhdl -force -mode synth_stub
--               E:/ZiJing/16M/MR4A16B_TEST_1/MR4A16B_TEST_1.srcs/sources_1/ip/vio_param/vio_param_stub.vhdl
-- Design      : vio_param
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a200tfbg484-2
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity vio_param is
  Port ( 
    clk : in STD_LOGIC;
    probe_out0 : out STD_LOGIC_VECTOR ( 0 to 0 );
    probe_out1 : out STD_LOGIC_VECTOR ( 3 downto 0 );
    probe_out2 : out STD_LOGIC_VECTOR ( 0 to 0 );
    probe_out3 : out STD_LOGIC_VECTOR ( 7 downto 0 );
    probe_out4 : out STD_LOGIC_VECTOR ( 19 downto 0 );
    probe_out5 : out STD_LOGIC_VECTOR ( 20 downto 0 );
    probe_out6 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out7 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out8 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out9 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out10 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out11 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out12 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out13 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out14 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out15 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out16 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out17 : out STD_LOGIC_VECTOR ( 15 downto 0 );
    probe_out18 : out STD_LOGIC_VECTOR ( 15 downto 0 )
  );

end vio_param;

architecture stub of vio_param is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "clk,probe_out0[0:0],probe_out1[3:0],probe_out2[0:0],probe_out3[7:0],probe_out4[19:0],probe_out5[20:0],probe_out6[15:0],probe_out7[15:0],probe_out8[15:0],probe_out9[15:0],probe_out10[15:0],probe_out11[15:0],probe_out12[15:0],probe_out13[15:0],probe_out14[15:0],probe_out15[15:0],probe_out16[15:0],probe_out17[15:0],probe_out18[15:0]";
attribute X_CORE_INFO : string;
attribute X_CORE_INFO of stub : architecture is "vio,Vivado 2018.3";
begin
end;
