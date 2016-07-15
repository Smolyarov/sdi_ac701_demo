// (c) Copyright 2005 - 2013 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
//------------------------------------------------------------------------------
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: $Revision: #4 $
//  \   \         
//  /   /         Filename: $File: //Groups/video_ip/demos/A7/xapp1097_a7_sdi_demos/Verilog/ac701_sdi_demo/multigenHD_vert.v $
// /___/   /\     Timestamp: $DateTime: 2013/10/22 15:33:22 $
// \   \  /  \
//  \___\/\___\
//
// Description:
//  This file contains the vertical sequencer for the HD video pattern generator.
//  A block RAM is used as a finite state machine, sequencing through the various
//  vertical sections of each video pattern. The module outputs a v_band code 
//  indicating which vertical portion of the video pattern should be displayed.      
//------------------------------------------------------------------------------
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//------------------------------------------------------------------------------ 

`timescale 1 ps / 1 ps

module multigenHD_vert (
    input   wire        clk,            // word-rate clock
    input   wire        rst,            // async reset
    input   wire        ce,             // clock enable
    input   wire [2:0]  std,            // selects video format
    input   wire [1:0]  pattern,        // 00 = RP 219 colorbars, X1 = RP 198 checkfield, 10 = 75% colorbars
    input   wire        h_counter_lsb,  // LSB of the horz section's h_counter
    input   wire        v_inc,          // causes the vertical counter to increment
    output  wire [2:0]  v_band,         // vertical band code output
    output  wire        v,              // vertical blanking interval indicator
    output  wire        f,              // odd/even field bit
    output  wire        first_line,     // asserted during first active line
    output  wire        y_ramp_inc_sel, // controls output sections Y-Ramp increment MUX
    output  wire [10:0] line_num        // current vertical line number
);

//-----------------------------------------------------------------------------
// Parameter definitions
//

//
// This group of parameters defines the bit widths of various fields in the
// module. 
//
localparam VID_WIDTH    = 10;                   // Width of video components
localparam VCNT_WIDTH   = 11;                   // Width of v_counter
localparam VRGN_WIDTH   = 5;                    // Width of v_region counter
localparam VBAND_WIDTH  = 3;                    // Width of vband code

localparam V_EVNT_WIDTH = VCNT_WIDTH;           // Width of v_next_evnt
 
localparam VID_MSB      = VID_WIDTH - 1;        // MS bit # of video data path
localparam VCNT_MSB     = VCNT_WIDTH - 1;       // MS bit # of v_counter
localparam VRGN_MSB     = VRGN_WIDTH - 1;       // MS bit # of v_region counter
localparam VBAND_MSB    = VBAND_WIDTH - 1;      // MS bit # of vband code
localparam V_EVNT_MSB   = V_EVNT_WIDTH - 1;     // MS bit # of v_next_evnt

//
// The group of parameters defines the vertical regions from the vertical ROM.
// Note that the vertical ROM generates a 5-bit vertical region code and a 3-bit
// vertical band code. The region code is essentially the current state of the
// vertical state machine and feeds back to the input of the vertical ROM.
// The vertical band code is sent to the color ROM to indicate the current
// vertical pattern band.
//
localparam [VRGN_MSB:0]
    VRGN_FM0_F0_VB_0    = 0,    // frame 0, field 0, first vertical blanking interval
    VRGN_FM0_F0_1ST_ACT = 1,    // frame 0, field 0, first active line (for CEQ polarity)
    VRGN_FM0_F0_PAT1    = 2,    // frame 0, field 0, pattern 1 or cable eq pattern
    VRGN_FM0_F0_PAT2    = 3,    // frame 0, field 0, pattern 2 or PLL pattern
    VRGN_FM0_F0_PAT3    = 4,    // frame 0, field 0, pattern 3
    VRGN_FM0_F0_PAT4    = 5,    // frame 0, field 0, pattern 4
    VRGN_FM0_F0_VB_1    = 6,    // frame 0, field 0, second vertical blanking interval
    VRGN_FM0_F1_VB_0    = 7,    // frame 0, field 1, first vertical blanking interval
    VRGN_FM0_F1_PAT1    = 8,    // frame 0, field 1, pattern 1 or cable eq pattern
    VRGN_FM0_F1_PAT2    = 9,    // frame 0, field 1, pattern 2 or PLL pattern
    VRGN_FM0_F1_PAT3    = 10,   // frame 0, field 1, pattern 3
    VRGN_FM0_F1_PAT4    = 11,   // frame 0, field 1, pattern 4
    VRGN_FM0_F1_VB_1    = 12,   // frame 0, field 1, second vertical blanking interval
    VRGN_FM0_CLRV       = 13,   // frame 0 clears the vertical counter back to 1
    VRGN_X14            = 14,   // unused
    VRGN_X15            = 15,   // unused
    VRGN_FM1_F0_VB_0    = 16,   // frame 1, field 0, first vertical blanking interval
    VRGN_FM1_F0_PAT1    = 17,   // frame 1, field 0, pattern 1 or cable eq pattern
    VRGN_FM1_F0_PAT2    = 18,   // frame 1, field 0, pattern 2 or PLL pattern
    VRGN_FM1_F0_PAT3    = 19,   // frame 1, field 0, pattern 3
    VRGN_FM1_F0_PAT4    = 20,   // frame 1, field 0, pattern 4
    VRGN_FM1_F0_VB_1    = 21,   // frame 1, field 0, second vertical blanking interval
    VRGN_X22            = 22,   // unused
    VRGN_FM1_F1_VB_0    = 23,   // frame 1, field 1, first vertical blanking interval
    VRGN_FM1_F1_PAT1    = 24,   // frame 1, field 1, pattern 1 or cable eq pattern
    VRGN_FM1_F1_PAT2    = 25,   // frame 1, field 1, pattern 2 or PLL pattern
    VRGN_FM1_F1_PAT3    = 26,   // frame 1, field 1, pattern 3
    VRGN_FM1_F1_PAT4    = 27,   // frame 1, field 1, pattern 4
    VRGN_FM1_F1_VB_1    = 28,   // frame 1, field 1, second vertical blanking interval
    VRGN_FM1_CLRV       = 29,   // frame 1 clears the vertical counter back to 1
    VRGN_X30            = 30,   // unused
    VRGN_RST            = 31;   // initial state after reset

localparam [VBAND_MSB:0]
    VBAND_VB            = 0,    // vertical blanking interval
    VBAND_PAT1          = 1,    // pattern 1
    VBAND_PAT2          = 2,    // pattern 2
    VBAND_PAT3          = 3,    // pattern 3
    VBAND_PAT4          = 4,    // pattern 4
    VBAND_CEQ           = 5,    // cable equalization pattern
    VBAND_PLL           = 6,    // PLL pattern
    VBAND_X7            = 7;    // unused


//-----------------------------------------------------------------------------
// Signal definitions
//
localparam VROM_INIT    = 26'h048FFFF;

reg     [26:0]          vrom [511:0];
reg     [26:0]          vrom_out = VROM_INIT;   // VROM output
reg     [VCNT_MSB:0]    v_counter;              // vertical counter
wire    [V_EVNT_MSB:0]  v_next_evnt;            // next vertical event
wire                    v_evnt_match;           // output of vertical event comparator
wire                    vrom_en;                // EN input to vertical ROM
wire    [VRGN_MSB:0]    v_region;               // current vertical region
wire    [VBAND_MSB:0]   v_band_rom;             // VBAND for most patterns
wire    [VBAND_MSB:0]   v_band_75_rom;          // VBAND for 75% color bars pattern
wire                    v_clr;                  // vertical counter clear signal

//
// Vertical ROM
//
initial begin
    vrom[   0] = 27'h0880321;vrom[   1] = 27'h1c10342;vrom[   2] = 27'h18137a3;vrom[   3] = 27'h1823f24;vrom[   4] = 27'h18346a5;vrom[   5] = 27'h1845d26;vrom[   6] = 27'h0885dad;vrom[   7] = 27'h0980008;vrom[   8] = 27'h1910009;vrom[   9] = 27'h192000a;vrom[  10] = 27'h193000b;vrom[  11] = 27'h194000c;vrom[  12] = 27'h0985dad;vrom[  13] = 27'h0a85dd0;vrom[  14] = 27'h0885dc0;vrom[  15] = 27'h0885dc0;
    vrom[  16] = 27'h0880331;vrom[  17] = 27'h18137b2;vrom[  18] = 27'h1823f33;vrom[  19] = 27'h18346b4;vrom[  20] = 27'h1845d35;vrom[  21] = 27'h0885dbd;vrom[  22] = 27'h0885dc0;vrom[  23] = 27'h0980018;vrom[  24] = 27'h1910019;vrom[  25] = 27'h192001a;vrom[  26] = 27'h193001b;vrom[  27] = 27'h194001c;vrom[  28] = 27'h0985dbd;vrom[  29] = 27'h0a85dc0;vrom[  30] = 27'h0885dc0;vrom[  31] = 27'h0880020;
    vrom[  32] = 27'h0880321;vrom[  33] = 27'h5c50342;vrom[  34] = 27'h5853023;vrom[  35] = 27'h6865d26;vrom[  36] = 27'h1830005;vrom[  37] = 27'h1840006;vrom[  38] = 27'h0885dad;vrom[  39] = 27'h0980008;vrom[  40] = 27'h5950009;vrom[  41] = 27'h696000c;vrom[  42] = 27'h193000b;vrom[  43] = 27'h194000c;vrom[  44] = 27'h0985dad;vrom[  45] = 27'h0a85dd0;vrom[  46] = 27'h0885dc0;vrom[  47] = 27'h0885dc0;
    vrom[  48] = 27'h0880331;vrom[  49] = 27'h5853032;vrom[  50] = 27'h6865d35;vrom[  51] = 27'h1830014;vrom[  52] = 27'h1840015;vrom[  53] = 27'h0885dbd;vrom[  54] = 27'h0885dc0;vrom[  55] = 27'h0980018;vrom[  56] = 27'h5950019;vrom[  57] = 27'h696001c;vrom[  58] = 27'h193001b;vrom[  59] = 27'h194001c;vrom[  60] = 27'h0985dbd;vrom[  61] = 27'h0a85dc0;vrom[  62] = 27'h0885dc0;vrom[  63] = 27'h0880020;
    vrom[  64] = 27'h0080281;vrom[  65] = 27'h14102a2;vrom[  66] = 27'h10129e3;vrom[  67] = 27'h1022f84;vrom[  68] = 27'h1033525;vrom[  69] = 27'h1044606;vrom[  70] = 27'h0084667;vrom[  71] = 27'h01848e8;vrom[  72] = 27'h1117049;vrom[  73] = 27'h11275ea;vrom[  74] = 27'h1137b8b;vrom[  75] = 27'h1148c6c;vrom[  76] = 27'h0188c8d;vrom[  77] = 27'h0388cb0;vrom[  78] = 27'h0088ca0;vrom[  79] = 27'h0088ca0;
    vrom[  80] = 27'h0080291;vrom[  81] = 27'h10129f2;vrom[  82] = 27'h1022f93;vrom[  83] = 27'h1033534;vrom[  84] = 27'h1044615;vrom[  85] = 27'h0084677;vrom[  86] = 27'h0088ca0;vrom[  87] = 27'h01848f8;vrom[  88] = 27'h1117059;vrom[  89] = 27'h11275fa;vrom[  90] = 27'h1137b9b;vrom[  91] = 27'h1148c7c;vrom[  92] = 27'h0188c9d;vrom[  93] = 27'h0388ca0;vrom[  94] = 27'h0088ca0;vrom[  95] = 27'h0080020;
    vrom[  96] = 27'h0080281;vrom[  97] = 27'h54502a2;vrom[  98] = 27'h5052443;vrom[  99] = 27'h6064606;vrom[ 100] = 27'h1030005;vrom[ 101] = 27'h1040006;vrom[ 102] = 27'h0084667;vrom[ 103] = 27'h01848e8;vrom[ 104] = 27'h5156aa9;vrom[ 105] = 27'h6168c6c;vrom[ 106] = 27'h113000b;vrom[ 107] = 27'h114000c;vrom[ 108] = 27'h0188c8d;vrom[ 109] = 27'h0388cb0;vrom[ 110] = 27'h0088ca0;vrom[ 111] = 27'h0088ca0;
    vrom[ 112] = 27'h0080291;vrom[ 113] = 27'h5052452;vrom[ 114] = 27'h6064615;vrom[ 115] = 27'h1030014;vrom[ 116] = 27'h1040015;vrom[ 117] = 27'h0084677;vrom[ 118] = 27'h0088ca0;vrom[ 119] = 27'h01848f8;vrom[ 120] = 27'h5156ab9;vrom[ 121] = 27'h6168c7c;vrom[ 122] = 27'h113001b;vrom[ 123] = 27'h114001c;vrom[ 124] = 27'h0188c9d;vrom[ 125] = 27'h0388ca0;vrom[ 126] = 27'h0088ca0;vrom[ 127] = 27'h0080020;
    vrom[ 128] = 27'h0080281;vrom[ 129] = 27'h14102a2;vrom[ 130] = 27'h10129e3;vrom[ 131] = 27'h1022f84;vrom[ 132] = 27'h1033525;vrom[ 133] = 27'h1044606;vrom[ 134] = 27'h0084667;vrom[ 135] = 27'h01848e8;vrom[ 136] = 27'h1117049;vrom[ 137] = 27'h11275ea;vrom[ 138] = 27'h1137b8b;vrom[ 139] = 27'h1148c6c;vrom[ 140] = 27'h0188c8d;vrom[ 141] = 27'h0388cb0;vrom[ 142] = 27'h0088ca0;vrom[ 143] = 27'h0088ca0;
    vrom[ 144] = 27'h0080291;vrom[ 145] = 27'h10129f2;vrom[ 146] = 27'h1022f93;vrom[ 147] = 27'h1033534;vrom[ 148] = 27'h1044615;vrom[ 149] = 27'h0084677;vrom[ 150] = 27'h0088ca0;vrom[ 151] = 27'h01848f8;vrom[ 152] = 27'h1117059;vrom[ 153] = 27'h11275fa;vrom[ 154] = 27'h1137b9b;vrom[ 155] = 27'h1148c7c;vrom[ 156] = 27'h0188c9d;vrom[ 157] = 27'h0388ca0;vrom[ 158] = 27'h0088ca0;vrom[ 159] = 27'h0080020;
    vrom[ 160] = 27'h0080281;vrom[ 161] = 27'h54502a2;vrom[ 162] = 27'h5052443;vrom[ 163] = 27'h6064606;vrom[ 164] = 27'h1030005;vrom[ 165] = 27'h1040006;vrom[ 166] = 27'h0084667;vrom[ 167] = 27'h01848e8;vrom[ 168] = 27'h5156aa9;vrom[ 169] = 27'h6168c6c;vrom[ 170] = 27'h113000b;vrom[ 171] = 27'h114000c;vrom[ 172] = 27'h0188c8d;vrom[ 173] = 27'h0388cb0;vrom[ 174] = 27'h0088ca0;vrom[ 175] = 27'h0088ca0;
    vrom[ 176] = 27'h0080291;vrom[ 177] = 27'h5052452;vrom[ 178] = 27'h6064615;vrom[ 179] = 27'h1030014;vrom[ 180] = 27'h1040015;vrom[ 181] = 27'h0084677;vrom[ 182] = 27'h0088ca0;vrom[ 183] = 27'h01848f8;vrom[ 184] = 27'h5156ab9;vrom[ 185] = 27'h6168c7c;vrom[ 186] = 27'h113001b;vrom[ 187] = 27'h114001c;vrom[ 188] = 27'h0188c9d;vrom[ 189] = 27'h0388ca0;vrom[ 190] = 27'h0088ca0;vrom[ 191] = 27'h0080020;
    vrom[ 192] = 27'h0080281;vrom[ 193] = 27'h14102a2;vrom[ 194] = 27'h10129e3;vrom[ 195] = 27'h1022f84;vrom[ 196] = 27'h1033525;vrom[ 197] = 27'h1044606;vrom[ 198] = 27'h0084667;vrom[ 199] = 27'h01848e8;vrom[ 200] = 27'h1117049;vrom[ 201] = 27'h11275ea;vrom[ 202] = 27'h1137b8b;vrom[ 203] = 27'h1148c6c;vrom[ 204] = 27'h0188c8d;vrom[ 205] = 27'h0388cb0;vrom[ 206] = 27'h0088ca0;vrom[ 207] = 27'h0088ca0;
    vrom[ 208] = 27'h0080291;vrom[ 209] = 27'h10129f2;vrom[ 210] = 27'h1022f93;vrom[ 211] = 27'h1033534;vrom[ 212] = 27'h1044615;vrom[ 213] = 27'h0084677;vrom[ 214] = 27'h0088ca0;vrom[ 215] = 27'h01848f8;vrom[ 216] = 27'h1117059;vrom[ 217] = 27'h11275fa;vrom[ 218] = 27'h1137b9b;vrom[ 219] = 27'h1148c7c;vrom[ 220] = 27'h0188c9d;vrom[ 221] = 27'h0388ca0;vrom[ 222] = 27'h0088ca0;vrom[ 223] = 27'h0080020;
    vrom[ 224] = 27'h0080281;vrom[ 225] = 27'h54502a2;vrom[ 226] = 27'h5052443;vrom[ 227] = 27'h6064606;vrom[ 228] = 27'h1030005;vrom[ 229] = 27'h1040006;vrom[ 230] = 27'h0084667;vrom[ 231] = 27'h01848e8;vrom[ 232] = 27'h5156aa9;vrom[ 233] = 27'h6168c6c;vrom[ 234] = 27'h113000b;vrom[ 235] = 27'h114000c;vrom[ 236] = 27'h0188c8d;vrom[ 237] = 27'h0388cb0;vrom[ 238] = 27'h0088ca0;vrom[ 239] = 27'h0088ca0;
    vrom[ 240] = 27'h0080291;vrom[ 241] = 27'h5052452;vrom[ 242] = 27'h6064615;vrom[ 243] = 27'h1030014;vrom[ 244] = 27'h1040015;vrom[ 245] = 27'h0084677;vrom[ 246] = 27'h0088ca0;vrom[ 247] = 27'h01848f8;vrom[ 248] = 27'h5156ab9;vrom[ 249] = 27'h6168c7c;vrom[ 250] = 27'h113001b;vrom[ 251] = 27'h114001c;vrom[ 252] = 27'h0188c9d;vrom[ 253] = 27'h0388ca0;vrom[ 254] = 27'h0088ca0;vrom[ 255] = 27'h0080020;
    vrom[ 256] = 27'h0080521;vrom[ 257] = 27'h1410542;vrom[ 258] = 27'h10153e3;vrom[ 259] = 27'h1025f24;vrom[ 260] = 27'h1036a65;vrom[ 261] = 27'h1048c26;vrom[ 262] = 27'h0088c8d;vrom[ 263] = 27'h0180008;vrom[ 264] = 27'h1110009;vrom[ 265] = 27'h112000a;vrom[ 266] = 27'h113000b;vrom[ 267] = 27'h114000c;vrom[ 268] = 27'h0188c8d;vrom[ 269] = 27'h0288cb0;vrom[ 270] = 27'h0088ca0;vrom[ 271] = 27'h0088ca0;
    vrom[ 272] = 27'h0080531;vrom[ 273] = 27'h10153f2;vrom[ 274] = 27'h1025f33;vrom[ 275] = 27'h1036a74;vrom[ 276] = 27'h1048c35;vrom[ 277] = 27'h0088c9d;vrom[ 278] = 27'h0088ca0;vrom[ 279] = 27'h0180018;vrom[ 280] = 27'h1110019;vrom[ 281] = 27'h112001a;vrom[ 282] = 27'h113001b;vrom[ 283] = 27'h114001c;vrom[ 284] = 27'h0188c9d;vrom[ 285] = 27'h0288ca0;vrom[ 286] = 27'h0088ca0;vrom[ 287] = 27'h0080020;
    vrom[ 288] = 27'h0080521;vrom[ 289] = 27'h5450542;vrom[ 290] = 27'h50548a3;vrom[ 291] = 27'h6068c26;vrom[ 292] = 27'h1030005;vrom[ 293] = 27'h1040006;vrom[ 294] = 27'h0088c8d;vrom[ 295] = 27'h0180008;vrom[ 296] = 27'h5150009;vrom[ 297] = 27'h616000c;vrom[ 298] = 27'h113000b;vrom[ 299] = 27'h114000c;vrom[ 300] = 27'h0188c8d;vrom[ 301] = 27'h0288cb0;vrom[ 302] = 27'h0088ca0;vrom[ 303] = 27'h0088ca0;
    vrom[ 304] = 27'h0080531;vrom[ 305] = 27'h50548b2;vrom[ 306] = 27'h6068c35;vrom[ 307] = 27'h1030014;vrom[ 308] = 27'h1040015;vrom[ 309] = 27'h0088c9d;vrom[ 310] = 27'h0088ca0;vrom[ 311] = 27'h0180018;vrom[ 312] = 27'h5150019;vrom[ 313] = 27'h616001c;vrom[ 314] = 27'h113001b;vrom[ 315] = 27'h114001c;vrom[ 316] = 27'h0188c9d;vrom[ 317] = 27'h0288ca0;vrom[ 318] = 27'h0088ca0;vrom[ 319] = 27'h0080020;
    vrom[ 320] = 27'h0080521;vrom[ 321] = 27'h1410542;vrom[ 322] = 27'h10153e3;vrom[ 323] = 27'h1025f24;vrom[ 324] = 27'h1036a65;vrom[ 325] = 27'h1048c26;vrom[ 326] = 27'h0088c8d;vrom[ 327] = 27'h0180008;vrom[ 328] = 27'h1110009;vrom[ 329] = 27'h112000a;vrom[ 330] = 27'h113000b;vrom[ 331] = 27'h114000c;vrom[ 332] = 27'h0188c8d;vrom[ 333] = 27'h0288cb0;vrom[ 334] = 27'h0088ca0;vrom[ 335] = 27'h0088ca0;
    vrom[ 336] = 27'h0080531;vrom[ 337] = 27'h10153f2;vrom[ 338] = 27'h1025f33;vrom[ 339] = 27'h1036a74;vrom[ 340] = 27'h1048c35;vrom[ 341] = 27'h0088c9d;vrom[ 342] = 27'h0088ca0;vrom[ 343] = 27'h0180018;vrom[ 344] = 27'h1110019;vrom[ 345] = 27'h112001a;vrom[ 346] = 27'h113001b;vrom[ 347] = 27'h114001c;vrom[ 348] = 27'h0188c9d;vrom[ 349] = 27'h0288ca0;vrom[ 350] = 27'h0088ca0;vrom[ 351] = 27'h0080020;
    vrom[ 352] = 27'h0080521;vrom[ 353] = 27'h5450542;vrom[ 354] = 27'h50548a3;vrom[ 355] = 27'h6068c26;vrom[ 356] = 27'h1030005;vrom[ 357] = 27'h1040006;vrom[ 358] = 27'h0088c8d;vrom[ 359] = 27'h0180008;vrom[ 360] = 27'h5150009;vrom[ 361] = 27'h616000c;vrom[ 362] = 27'h113000b;vrom[ 363] = 27'h114000c;vrom[ 364] = 27'h0188c8d;vrom[ 365] = 27'h0288cb0;vrom[ 366] = 27'h0088ca0;vrom[ 367] = 27'h0088ca0;
    vrom[ 368] = 27'h0080531;vrom[ 369] = 27'h50548b2;vrom[ 370] = 27'h6068c35;vrom[ 371] = 27'h1030014;vrom[ 372] = 27'h1040015;vrom[ 373] = 27'h0088c9d;vrom[ 374] = 27'h0088ca0;vrom[ 375] = 27'h0180018;vrom[ 376] = 27'h5150019;vrom[ 377] = 27'h616001c;vrom[ 378] = 27'h113001b;vrom[ 379] = 27'h114001c;vrom[ 380] = 27'h0188c9d;vrom[ 381] = 27'h0288ca0;vrom[ 382] = 27'h0088ca0;vrom[ 383] = 27'h0080020;
    vrom[ 384] = 27'h0080521;vrom[ 385] = 27'h1410542;vrom[ 386] = 27'h10153e3;vrom[ 387] = 27'h1025f24;vrom[ 388] = 27'h1036a65;vrom[ 389] = 27'h1048c26;vrom[ 390] = 27'h0088c8d;vrom[ 391] = 27'h0180008;vrom[ 392] = 27'h1110009;vrom[ 393] = 27'h112000a;vrom[ 394] = 27'h113000b;vrom[ 395] = 27'h114000c;vrom[ 396] = 27'h0188c8d;vrom[ 397] = 27'h0288cb0;vrom[ 398] = 27'h0088ca0;vrom[ 399] = 27'h0088ca0;
    vrom[ 400] = 27'h0080531;vrom[ 401] = 27'h10153f2;vrom[ 402] = 27'h1025f33;vrom[ 403] = 27'h1036a74;vrom[ 404] = 27'h1048c35;vrom[ 405] = 27'h0088c9d;vrom[ 406] = 27'h0088ca0;vrom[ 407] = 27'h0180018;vrom[ 408] = 27'h1110019;vrom[ 409] = 27'h112001a;vrom[ 410] = 27'h113001b;vrom[ 411] = 27'h114001c;vrom[ 412] = 27'h0188c9d;vrom[ 413] = 27'h0288ca0;vrom[ 414] = 27'h0088ca0;vrom[ 415] = 27'h0080020;
    vrom[ 416] = 27'h0080521;vrom[ 417] = 27'h5450542;vrom[ 418] = 27'h50548a3;vrom[ 419] = 27'h6068c26;vrom[ 420] = 27'h1030005;vrom[ 421] = 27'h1040006;vrom[ 422] = 27'h0088c8d;vrom[ 423] = 27'h0180008;vrom[ 424] = 27'h5150009;vrom[ 425] = 27'h616000c;vrom[ 426] = 27'h113000b;vrom[ 427] = 27'h114000c;vrom[ 428] = 27'h0188c8d;vrom[ 429] = 27'h0288cb0;vrom[ 430] = 27'h0088ca0;vrom[ 431] = 27'h0088ca0;
    vrom[ 432] = 27'h0080531;vrom[ 433] = 27'h50548b2;vrom[ 434] = 27'h6068c35;vrom[ 435] = 27'h1030014;vrom[ 436] = 27'h1040015;vrom[ 437] = 27'h0088c9d;vrom[ 438] = 27'h0088ca0;vrom[ 439] = 27'h0180018;vrom[ 440] = 27'h5150019;vrom[ 441] = 27'h616001c;vrom[ 442] = 27'h113001b;vrom[ 443] = 27'h114001c;vrom[ 444] = 27'h0188c9d;vrom[ 445] = 27'h0288ca0;vrom[ 446] = 27'h0088ca0;vrom[ 447] = 27'h0080020;
    vrom[ 448] = 27'h0880321;vrom[ 449] = 27'h1c10342;vrom[ 450] = 27'h18137a3;vrom[ 451] = 27'h1823f24;vrom[ 452] = 27'h18346a5;vrom[ 453] = 27'h1845d26;vrom[ 454] = 27'h0885dad;vrom[ 455] = 27'h0980008;vrom[ 456] = 27'h1910009;vrom[ 457] = 27'h192000a;vrom[ 458] = 27'h193000b;vrom[ 459] = 27'h194000c;vrom[ 460] = 27'h0985dad;vrom[ 461] = 27'h0a85dd0;vrom[ 462] = 27'h0885dc0;vrom[ 463] = 27'h0885dc0;
    vrom[ 464] = 27'h0880331;vrom[ 465] = 27'h18137b2;vrom[ 466] = 27'h1823f33;vrom[ 467] = 27'h18346b4;vrom[ 468] = 27'h1845d35;vrom[ 469] = 27'h0885dbd;vrom[ 470] = 27'h0885dc0;vrom[ 471] = 27'h0980018;vrom[ 472] = 27'h1910019;vrom[ 473] = 27'h192001a;vrom[ 474] = 27'h193001b;vrom[ 475] = 27'h194001c;vrom[ 476] = 27'h0985dbd;vrom[ 477] = 27'h0a85dc0;vrom[ 478] = 27'h0885dc0;vrom[ 479] = 27'h0880020;
    vrom[ 480] = 27'h0880321;vrom[ 481] = 27'h5c50342;vrom[ 482] = 27'h5853023;vrom[ 483] = 27'h6865d26;vrom[ 484] = 27'h1830005;vrom[ 485] = 27'h1840006;vrom[ 486] = 27'h0885dad;vrom[ 487] = 27'h0980008;vrom[ 488] = 27'h5950009;vrom[ 489] = 27'h696000c;vrom[ 490] = 27'h193000b;vrom[ 491] = 27'h194000c;vrom[ 492] = 27'h0985dad;vrom[ 493] = 27'h0a85dd0;vrom[ 494] = 27'h0885dc0;vrom[ 495] = 27'h0885dc0;
    vrom[ 496] = 27'h0880331;vrom[ 497] = 27'h5853032;vrom[ 498] = 27'h6865d35;vrom[ 499] = 27'h1830014;vrom[ 500] = 27'h1840015;vrom[ 501] = 27'h0885dbd;vrom[ 502] = 27'h0885dc0;vrom[ 503] = 27'h0980018;vrom[ 504] = 27'h5950019;vrom[ 505] = 27'h696001c;vrom[ 506] = 27'h193001b;vrom[ 507] = 27'h194001c;vrom[ 508] = 27'h0985dbd;vrom[ 509] = 27'h0a85dc0;vrom[ 510] = 27'h0885dc0;vrom[ 511] = 27'h0880020;
end

always @ (posedge clk)
    if (rst)
        vrom_out <= VROM_INIT;
    else if (vrom_en)
        vrom_out <= vrom[{std, pattern[0], v_region}];
         
assign v_region =      vrom_out[4:0];
assign v_next_evnt =   vrom_out[15:5];
assign v_band_rom =    vrom_out[18:16];
assign v =             vrom_out[19];
assign f =             vrom_out[20];
assign v_clr =         vrom_out[21];
assign first_line =    vrom_out[22];
assign y_ramp_inc_sel =vrom_out[23];
assign v_band_75_rom = vrom_out[26:24];
//
// vrom_en
//
// This signal is asserted to advance the vertical sequencer. It is asserted
// whenever the vertical counter matches the next vertical event value AND
// the v_inc signal from the HROM is asserted AND the LSB of the h_counter is
// high.
//
assign vrom_en = ce & v_inc & h_counter_lsb & v_evnt_match;

// 
// Vertical counter
//
// The vertical counter increments once per line. When the v_clr signal is
// asserted the counter resets to a value of 1.
//
always @ (posedge clk or posedge rst)
    if (rst)
        v_counter <= 11'd2047;
    else if (ce & h_counter_lsb)
        if (v_inc)
            begin
                if (v_clr)
                    v_counter <= 1;
                else 
                    v_counter <= v_counter + 1;
            end

assign line_num = v_counter;

//
// Vertical event comparator
//
// This compares the current vertical counter value with the v_next_evnt
// field from the VROM. When they match, v_evnt_match is asserted to enable
// clocking of the VROM.
//
assign v_evnt_match = (v_next_evnt == v_counter) | v_clr;

//
// v_band MUX
//
// When 75% color bars are being generated use the v_band_75_rom bits
// for the v_band, otherwise use v_band_rom.
//
assign v_band = pattern[1] ? v_band_75_rom : v_band_rom;


endmodule
