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
//  /   /         Filename: $File: //Groups/video_ip/demos/A7/xapp1097_a7_sdi_demos/Verilog/ac701_sdi_demo/multigenHD_horz.v $
// /___/   /\     Timestamp: $DateTime: 2013/10/22 15:33:22 $
// \   \  /  \
//  \___\/\___\
//
// Description:
//  This module contains the horizontal sequencer for the HD video pattern 
//  generator. A block RAM is used as a finite state machine to sequence through
//  the various horizontal regions of the video patterns. The module outputs a
//  horizontal region code indicating which horizontal region of the video pattern
//  is currently active.
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

module multigenHD_horz (
    input   wire        clk,            // word-rate clock
    input   wire        rst,            // async reset
    input   wire        ce,             // clock enable
    input   wire [2:0]  std,            // selects video format
    input   wire [1:0]  pattern,        // 00 = RP 219 colorbars, X1 = RP 198 checkfield, 10 = 75% colorbars
    input   wire [1:0]  user_opt,       // selects option for the *2 & *3 blocks of RP 219
    input   wire        first_line,     // asserted during first active video line
    input   wire        f,              // odd/even field indicator
    output  wire        v_inc,          // increment vertical counter
    output  wire        trs,            // asserted at start of TRS
    output  wire        xyz,            // asserted during XYZ word of TRS
    output  wire        h,              // horizontal blanking interval indicator
    output  reg  [4:0]  h_region,       // horizontal region code
    output  wire        h_counter_lsb   // LSB of horizontal counter
);

//-----------------------------------------------------------------------------
// Parameter definitions
//

//
// This group of parameters defines the bit widths of various fields in the
// module. Note that if the VID_WIDTH parameter is changed, the video component
// values for the various colors will need to be modified accordingly.
//
localparam VID_WIDTH    = 10;                   // Width of video components
localparam HCNT_WIDTH   = 12;                   // Width of h_counter
localparam HRGN_WIDTH   = 5;                    // Width of h_region counter

localparam H_EVNT_WIDTH = HCNT_WIDTH - 1;       // Width of h_next_evnt
 
localparam VID_MSB      = VID_WIDTH - 1;        // MS bit # of video data path
localparam HCNT_MSB     = HCNT_WIDTH - 1;       // MS bit # of h_counter
localparam HRGN_MSB     = HRGN_WIDTH - 1;       // MS bit # of h_region counter
localparam H_EVNT_MSB   = H_EVNT_WIDTH - 1;     // MS bit # of h_next_evnt

//
// This group of parameters defines the horizontal regions from the horizontal
// ROM. Note that the three HRGN_USROPTx regions are never generated by the
// horizontal ROM. An encoder will change HRGN_BAR1 to any of these three values
// depending on the user option inputs before feeding the modified horizontal
// region code to the color ROM. The encoder will also determine whether to
// output the HRGN_CEQ_POL0 or POL1 code depending on whether the current frame
// is odd or even.
//
localparam [HRGN_MSB:0]
    HRGN_BAR0           = 0,    // 40% gray
    HRGN_BAR1           = 1,    // 75% white (left part 0% black)
    HRGN_BAR2           = 2,    // left part 75% yellow (right part 0% black)
    HRGN_BAR3           = 3,    // right part 75% yellow (right part 100% white)
    HRGN_BAR4           = 4,    // 75% cyan (middle part 100% white)
    HRGN_BAR5           = 5,    // left part 75% green (left part 100% white)
    HRGN_BAR6           = 6,    // right part 75% green (left part 0% black)
    HRGN_BAR7           = 7,    // left part 75% magenta (right part 0% black) 
    HRGN_BAR8           = 8,    // middle part 75% magenta (-2% black)
    HRGN_BAR9           = 9,    // right part 75% magenta (0% black)
    HRGN_BAR10          = 10,   // left part 75% red (+2% black)
    HRGN_BAR11          = 11,   // middle part 75% red (0% black)
    HRGN_BAR12          = 12,   // right part 75% red (+4% black)
    HRGN_BAR13          = 13,   // 75% blue (0% black)
    HRGN_BAR14          = 14,   // 40% gray
    HRGN_INCV           = 15,   // increment vertical line number
    HRGN_EAV1           = 16,   // first two words of EAV
    HRGN_EAV2_F0        = 17,   // second two words of EAV for field 0
    HRGN_HBLANK         = 18,   // horizontal blanking period
    HRGN_SAV1           = 19,   // first two words of SAV
    HRGN_SAV2_F0        = 20,   // second two words of SAV for field 0
    HRGN_LN             = 21,   // two words of line number
    HRGN_CRC            = 22,   // two words of CRC
    HRGN_SAV2_F1        = 23,   // second two words of SAV for field 1
    HRGN_USROPT1        = 24,   // BAR1 but with 100% white in pat 2, 0% black in pat 3
    HRGN_USROPT2        = 25,   // BAR1 but with +I in pat 2, 0% black in pat 3
    HRGN_USROPT3        = 26,   // BAR1 but with -I in pat 2, +Q in pat 3
    HRGN_EAV2_F1        = 27,   // second two words of EAV for field 1
    HRGN_CEQ_PLL        = 28,   // RP 198 cable equalization pattern
    HRGN_CEQ_POL_0      = 29,   // RP 198 cable eq pattern, polarity word even frame
    HRGN_CEQ_POL_1      = 30,   // RP 198 cable eq pattern, polarity word odd frame
    HRGN_RST            = 31;   // initial state after reset

//-----------------------------------------------------------------------------
// Signal definitions
//

localparam HROM_INIT    = 29'h0040FFFF;

reg     [28:0]          hrom [511:0];
reg     [28:0]          hrom_out = HROM_INIT;   // HROM output
reg     [HCNT_MSB:0]    h_counter;              // horizontal counter
wire    [H_EVNT_MSB:0]  h_next_evnt;            // next horizontal event
wire                    h_evnt_match;           // output of horizontal event comparator
(* KEEP = "TRUE" *)
wire                    hrom_en;                // EN input to horizontal ROM
wire    [HRGN_MSB:0]    h_region_rom;           // current horizontal region
wire    [HRGN_MSB:0]    h_next_region;          // next horizontal region
wire                    h_clr;                  // clears the horizontal counter
wire                    usropt_rgn;             // horz region where h_region is affected by user_opt inputs
wire                    ceqpol_rgn;             // horz region where h_region is affected by ceq polarity
wire                    eav2_rgn;               // last two words of EAV
wire                    sav2_rgn;               // last two words of SAV


//
// Horizontal ROM
//
initial begin
    hrom[   0] = 29'h000009e1;hrom[   1] = 29'h020112a2;hrom[   2] = 29'h000216c3;hrom[   3] = 29'h00031b24;hrom[   4] = 29'h000423a5;hrom[   5] = 29'h000527e6;hrom[   6] = 29'h00062c27;hrom[   7] = 29'h00072f08;hrom[   8] = 29'h000831e9;hrom[   9] = 29'h000934aa;hrom[  10] = 29'h000a378b;hrom[  11] = 29'h000b3a4c;hrom[  12] = 29'h000c3d2d;hrom[  13] = 29'h000d45ee;hrom[  14] = 29'h000e4fcf;hrom[  15] = 29'h004f4ff0;
    hrom[  16] = 29'h01905011;hrom[  17] = 29'h09915035;hrom[  18] = 29'h01127b73;hrom[  19] = 29'h01937b94;hrom[  20] = 29'h11b47ba0;hrom[  21] = 29'h01155056;hrom[  22] = 29'h01165072;hrom[  23] = 29'h00170010;hrom[  24] = 29'h00180010;hrom[  25] = 29'h00190010;hrom[  26] = 29'h001a0010;hrom[  27] = 29'h001b0010;hrom[  28] = 29'h001c0010;hrom[  29] = 29'h001d0010;hrom[  30] = 29'h001e0010;hrom[  31] = 29'h015f0012;
    hrom[  32] = 29'h00000010;hrom[  33] = 29'h00010010;hrom[  34] = 29'h00020010;hrom[  35] = 29'h00030010;hrom[  36] = 29'h00040010;hrom[  37] = 29'h00050010;hrom[  38] = 29'h00060010;hrom[  39] = 29'h00070010;hrom[  40] = 29'h00080010;hrom[  41] = 29'h00090010;hrom[  42] = 29'h000a0010;hrom[  43] = 29'h000b0010;hrom[  44] = 29'h000c0010;hrom[  45] = 29'h000d0010;hrom[  46] = 29'h000e0010;hrom[  47] = 29'h004f4ff0;
    hrom[  48] = 29'h01905011;hrom[  49] = 29'h09915035;hrom[  50] = 29'h01127b73;hrom[  51] = 29'h01937b94;hrom[  52] = 29'h11b47bbd;hrom[  53] = 29'h01155056;hrom[  54] = 29'h01165072;hrom[  55] = 29'h00170010;hrom[  56] = 29'h00180010;hrom[  57] = 29'h00190010;hrom[  58] = 29'h001a0010;hrom[  59] = 29'h001b0010;hrom[  60] = 29'h001c4fcf;hrom[  61] = 29'h041d003c;hrom[  62] = 29'h001e0010;hrom[  63] = 29'h015f0012;
    hrom[  64] = 29'h00000ee1;hrom[  65] = 29'h02011bc2;hrom[  66] = 29'h00022223;hrom[  67] = 29'h000328a4;hrom[  68] = 29'h00043585;hrom[  69] = 29'h00053be6;hrom[  70] = 29'h00064247;hrom[  71] = 29'h00074688;hrom[  72] = 29'h00084ac9;hrom[  73] = 29'h00094f2a;hrom[  74] = 29'h000a536b;hrom[  75] = 29'h000b57cc;hrom[  76] = 29'h000c5c0d;hrom[  77] = 29'h000d68ee;hrom[  78] = 29'h000e77cf;hrom[  79] = 29'h004f77f0;
    hrom[  80] = 29'h01907811;hrom[  81] = 29'h09917835;hrom[  82] = 29'h0112ab93;hrom[  83] = 29'h0193abb4;hrom[  84] = 29'h11b4abc0;hrom[  85] = 29'h01157856;hrom[  86] = 29'h01167872;hrom[  87] = 29'h00170010;hrom[  88] = 29'h00180010;hrom[  89] = 29'h00190010;hrom[  90] = 29'h001a0010;hrom[  91] = 29'h001b0010;hrom[  92] = 29'h001c0010;hrom[  93] = 29'h001d0010;hrom[  94] = 29'h001e0010;hrom[  95] = 29'h015f0012;
    hrom[  96] = 29'h00000010;hrom[  97] = 29'h00010010;hrom[  98] = 29'h00020010;hrom[  99] = 29'h00030010;hrom[ 100] = 29'h00040010;hrom[ 101] = 29'h00050010;hrom[ 102] = 29'h00060010;hrom[ 103] = 29'h00070010;hrom[ 104] = 29'h00080010;hrom[ 105] = 29'h00090010;hrom[ 106] = 29'h000a0010;hrom[ 107] = 29'h000b0010;hrom[ 108] = 29'h000c0010;hrom[ 109] = 29'h000d0010;hrom[ 110] = 29'h000e0010;hrom[ 111] = 29'h004f77f0;
    hrom[ 112] = 29'h01907811;hrom[ 113] = 29'h09917835;hrom[ 114] = 29'h0112ab93;hrom[ 115] = 29'h0193abb4;hrom[ 116] = 29'h11b4abdd;hrom[ 117] = 29'h01157856;hrom[ 118] = 29'h01167872;hrom[ 119] = 29'h00170010;hrom[ 120] = 29'h00180010;hrom[ 121] = 29'h00190010;hrom[ 122] = 29'h001a0010;hrom[ 123] = 29'h001b0010;hrom[ 124] = 29'h001c77cf;hrom[ 125] = 29'h041d003c;hrom[ 126] = 29'h001e0010;hrom[ 127] = 29'h015f0012;
    hrom[ 128] = 29'h00000ee1;hrom[ 129] = 29'h02011bc2;hrom[ 130] = 29'h00022223;hrom[ 131] = 29'h000328a4;hrom[ 132] = 29'h00043585;hrom[ 133] = 29'h00053be6;hrom[ 134] = 29'h00064247;hrom[ 135] = 29'h00074688;hrom[ 136] = 29'h00084ac9;hrom[ 137] = 29'h00094f2a;hrom[ 138] = 29'h000a536b;hrom[ 139] = 29'h000b57cc;hrom[ 140] = 29'h000c5c0d;hrom[ 141] = 29'h000d68ee;hrom[ 142] = 29'h000e77cf;hrom[ 143] = 29'h004f77f0;
    hrom[ 144] = 29'h01907811;hrom[ 145] = 29'h09917835;hrom[ 146] = 29'h01128933;hrom[ 147] = 29'h01938954;hrom[ 148] = 29'h11b48960;hrom[ 149] = 29'h01157856;hrom[ 150] = 29'h01167872;hrom[ 151] = 29'h00170010;hrom[ 152] = 29'h00180010;hrom[ 153] = 29'h00190010;hrom[ 154] = 29'h001a0010;hrom[ 155] = 29'h001b0010;hrom[ 156] = 29'h001c0010;hrom[ 157] = 29'h001d0010;hrom[ 158] = 29'h001e0010;hrom[ 159] = 29'h015f0012;
    hrom[ 160] = 29'h00000010;hrom[ 161] = 29'h00010010;hrom[ 162] = 29'h00020010;hrom[ 163] = 29'h00030010;hrom[ 164] = 29'h00040010;hrom[ 165] = 29'h00050010;hrom[ 166] = 29'h00060010;hrom[ 167] = 29'h00070010;hrom[ 168] = 29'h00080010;hrom[ 169] = 29'h00090010;hrom[ 170] = 29'h000a0010;hrom[ 171] = 29'h000b0010;hrom[ 172] = 29'h000c0010;hrom[ 173] = 29'h000d0010;hrom[ 174] = 29'h000e0010;hrom[ 175] = 29'h004f77f0;
    hrom[ 176] = 29'h01907811;hrom[ 177] = 29'h09917835;hrom[ 178] = 29'h01128933;hrom[ 179] = 29'h01938954;hrom[ 180] = 29'h11b4897d;hrom[ 181] = 29'h01157856;hrom[ 182] = 29'h01167872;hrom[ 183] = 29'h00170010;hrom[ 184] = 29'h00180010;hrom[ 185] = 29'h00190010;hrom[ 186] = 29'h001a0010;hrom[ 187] = 29'h001b0010;hrom[ 188] = 29'h001c77cf;hrom[ 189] = 29'h041d003c;hrom[ 190] = 29'h001e0010;hrom[ 191] = 29'h015f0012;
    hrom[ 192] = 29'h00000ee1;hrom[ 193] = 29'h02011bc2;hrom[ 194] = 29'h00022223;hrom[ 195] = 29'h000328a4;hrom[ 196] = 29'h00043585;hrom[ 197] = 29'h00053be6;hrom[ 198] = 29'h00064247;hrom[ 199] = 29'h00074688;hrom[ 200] = 29'h00084ac9;hrom[ 201] = 29'h00094f2a;hrom[ 202] = 29'h000a536b;hrom[ 203] = 29'h000b57cc;hrom[ 204] = 29'h000c5c0d;hrom[ 205] = 29'h000d68ee;hrom[ 206] = 29'h000e77cf;hrom[ 207] = 29'h004f77f0;
    hrom[ 208] = 29'h01907811;hrom[ 209] = 29'h09917835;hrom[ 210] = 29'h0112a4b3;hrom[ 211] = 29'h0193a4d4;hrom[ 212] = 29'h11b4a4e0;hrom[ 213] = 29'h01157856;hrom[ 214] = 29'h01167872;hrom[ 215] = 29'h00170010;hrom[ 216] = 29'h00180010;hrom[ 217] = 29'h00190010;hrom[ 218] = 29'h001a0010;hrom[ 219] = 29'h001b0010;hrom[ 220] = 29'h001c0010;hrom[ 221] = 29'h001d0010;hrom[ 222] = 29'h001e0010;hrom[ 223] = 29'h015f0012;
    hrom[ 224] = 29'h00000010;hrom[ 225] = 29'h00010010;hrom[ 226] = 29'h00020010;hrom[ 227] = 29'h00030010;hrom[ 228] = 29'h00040010;hrom[ 229] = 29'h00050010;hrom[ 230] = 29'h00060010;hrom[ 231] = 29'h00070010;hrom[ 232] = 29'h00080010;hrom[ 233] = 29'h00090010;hrom[ 234] = 29'h000a0010;hrom[ 235] = 29'h000b0010;hrom[ 236] = 29'h000c0010;hrom[ 237] = 29'h000d0010;hrom[ 238] = 29'h000e0010;hrom[ 239] = 29'h004f77f0;
    hrom[ 240] = 29'h01907811;hrom[ 241] = 29'h09917835;hrom[ 242] = 29'h0112a4b3;hrom[ 243] = 29'h0193a4d4;hrom[ 244] = 29'h11b4a4fd;hrom[ 245] = 29'h01157856;hrom[ 246] = 29'h01167872;hrom[ 247] = 29'h00170010;hrom[ 248] = 29'h00180010;hrom[ 249] = 29'h00190010;hrom[ 250] = 29'h001a0010;hrom[ 251] = 29'h001b0010;hrom[ 252] = 29'h001c77cf;hrom[ 253] = 29'h041d003c;hrom[ 254] = 29'h001e0010;hrom[ 255] = 29'h015f0012;
    hrom[ 256] = 29'h00000ee1;hrom[ 257] = 29'h02011bc2;hrom[ 258] = 29'h00022223;hrom[ 259] = 29'h000328a4;hrom[ 260] = 29'h00043585;hrom[ 261] = 29'h00053be6;hrom[ 262] = 29'h00064247;hrom[ 263] = 29'h00074688;hrom[ 264] = 29'h00084ac9;hrom[ 265] = 29'h00094f2a;hrom[ 266] = 29'h000a536b;hrom[ 267] = 29'h000b57cc;hrom[ 268] = 29'h000c5c0d;hrom[ 269] = 29'h000d68ee;hrom[ 270] = 29'h000e77cf;hrom[ 271] = 29'h004f77f0;
    hrom[ 272] = 29'h01907811;hrom[ 273] = 29'h09917835;hrom[ 274] = 29'h01128933;hrom[ 275] = 29'h01938954;hrom[ 276] = 29'h11b48960;hrom[ 277] = 29'h01157856;hrom[ 278] = 29'h01167872;hrom[ 279] = 29'h00170010;hrom[ 280] = 29'h00180010;hrom[ 281] = 29'h00190010;hrom[ 282] = 29'h001a0010;hrom[ 283] = 29'h001b0010;hrom[ 284] = 29'h001c0010;hrom[ 285] = 29'h001d0010;hrom[ 286] = 29'h001e0010;hrom[ 287] = 29'h015f0012;
    hrom[ 288] = 29'h00000010;hrom[ 289] = 29'h00010010;hrom[ 290] = 29'h00020010;hrom[ 291] = 29'h00030010;hrom[ 292] = 29'h00040010;hrom[ 293] = 29'h00050010;hrom[ 294] = 29'h00060010;hrom[ 295] = 29'h00070010;hrom[ 296] = 29'h00080010;hrom[ 297] = 29'h00090010;hrom[ 298] = 29'h000a0010;hrom[ 299] = 29'h000b0010;hrom[ 300] = 29'h000c0010;hrom[ 301] = 29'h000d0010;hrom[ 302] = 29'h000e0010;hrom[ 303] = 29'h004f77f0;
    hrom[ 304] = 29'h01907811;hrom[ 305] = 29'h09917835;hrom[ 306] = 29'h01128933;hrom[ 307] = 29'h01938954;hrom[ 308] = 29'h11b4897d;hrom[ 309] = 29'h01157856;hrom[ 310] = 29'h01167872;hrom[ 311] = 29'h00170010;hrom[ 312] = 29'h00180010;hrom[ 313] = 29'h00190010;hrom[ 314] = 29'h001a0010;hrom[ 315] = 29'h001b0010;hrom[ 316] = 29'h001c77cf;hrom[ 317] = 29'h041d003c;hrom[ 318] = 29'h001e0010;hrom[ 319] = 29'h015f0012;
    hrom[ 320] = 29'h00000ee1;hrom[ 321] = 29'h02011bc2;hrom[ 322] = 29'h00022223;hrom[ 323] = 29'h000328a4;hrom[ 324] = 29'h00043585;hrom[ 325] = 29'h00053be6;hrom[ 326] = 29'h00064247;hrom[ 327] = 29'h00074688;hrom[ 328] = 29'h00084ac9;hrom[ 329] = 29'h00094f2a;hrom[ 330] = 29'h000a536b;hrom[ 331] = 29'h000b57cc;hrom[ 332] = 29'h000c5c0d;hrom[ 333] = 29'h000d68ee;hrom[ 334] = 29'h000e77cf;hrom[ 335] = 29'h004f77f0;
    hrom[ 336] = 29'h01907811;hrom[ 337] = 29'h09917835;hrom[ 338] = 29'h0112a4b3;hrom[ 339] = 29'h0193a4d4;hrom[ 340] = 29'h11b4a4e0;hrom[ 341] = 29'h01157856;hrom[ 342] = 29'h01167872;hrom[ 343] = 29'h00170010;hrom[ 344] = 29'h00180010;hrom[ 345] = 29'h00190010;hrom[ 346] = 29'h001a0010;hrom[ 347] = 29'h001b0010;hrom[ 348] = 29'h001c0010;hrom[ 349] = 29'h001d0010;hrom[ 350] = 29'h001e0010;hrom[ 351] = 29'h015f0012;
    hrom[ 352] = 29'h00000010;hrom[ 353] = 29'h00010010;hrom[ 354] = 29'h00020010;hrom[ 355] = 29'h00030010;hrom[ 356] = 29'h00040010;hrom[ 357] = 29'h00050010;hrom[ 358] = 29'h00060010;hrom[ 359] = 29'h00070010;hrom[ 360] = 29'h00080010;hrom[ 361] = 29'h00090010;hrom[ 362] = 29'h000a0010;hrom[ 363] = 29'h000b0010;hrom[ 364] = 29'h000c0010;hrom[ 365] = 29'h000d0010;hrom[ 366] = 29'h000e0010;hrom[ 367] = 29'h004f77f0;
    hrom[ 368] = 29'h01907811;hrom[ 369] = 29'h09917835;hrom[ 370] = 29'h0112a4b3;hrom[ 371] = 29'h0193a4d4;hrom[ 372] = 29'h11b4a4fd;hrom[ 373] = 29'h01157856;hrom[ 374] = 29'h01167872;hrom[ 375] = 29'h00170010;hrom[ 376] = 29'h00180010;hrom[ 377] = 29'h00190010;hrom[ 378] = 29'h001a0010;hrom[ 379] = 29'h001b0010;hrom[ 380] = 29'h001c77cf;hrom[ 381] = 29'h041d003c;hrom[ 382] = 29'h001e0010;hrom[ 383] = 29'h015f0012;
    hrom[ 384] = 29'h00000ee1;hrom[ 385] = 29'h02011bc2;hrom[ 386] = 29'h00022223;hrom[ 387] = 29'h000328a4;hrom[ 388] = 29'h00043585;hrom[ 389] = 29'h00053be6;hrom[ 390] = 29'h00064247;hrom[ 391] = 29'h00074688;hrom[ 392] = 29'h00084ac9;hrom[ 393] = 29'h00094f2a;hrom[ 394] = 29'h000a536b;hrom[ 395] = 29'h000b57cc;hrom[ 396] = 29'h000c5c0d;hrom[ 397] = 29'h000d68ee;hrom[ 398] = 29'h000e77cf;hrom[ 399] = 29'h004f77f0;
    hrom[ 400] = 29'h01907811;hrom[ 401] = 29'h09917835;hrom[ 402] = 29'h0112ab93;hrom[ 403] = 29'h0193abb4;hrom[ 404] = 29'h11b4abc0;hrom[ 405] = 29'h01157856;hrom[ 406] = 29'h01167872;hrom[ 407] = 29'h00170010;hrom[ 408] = 29'h00180010;hrom[ 409] = 29'h00190010;hrom[ 410] = 29'h001a0010;hrom[ 411] = 29'h001b0010;hrom[ 412] = 29'h001c0010;hrom[ 413] = 29'h001d0010;hrom[ 414] = 29'h001e0010;hrom[ 415] = 29'h015f0012;
    hrom[ 416] = 29'h00000010;hrom[ 417] = 29'h00010010;hrom[ 418] = 29'h00020010;hrom[ 419] = 29'h00030010;hrom[ 420] = 29'h00040010;hrom[ 421] = 29'h00050010;hrom[ 422] = 29'h00060010;hrom[ 423] = 29'h00070010;hrom[ 424] = 29'h00080010;hrom[ 425] = 29'h00090010;hrom[ 426] = 29'h000a0010;hrom[ 427] = 29'h000b0010;hrom[ 428] = 29'h000c0010;hrom[ 429] = 29'h000d0010;hrom[ 430] = 29'h000e0010;hrom[ 431] = 29'h004f77f0;
    hrom[ 432] = 29'h01907811;hrom[ 433] = 29'h09917835;hrom[ 434] = 29'h0112ab93;hrom[ 435] = 29'h0193abb4;hrom[ 436] = 29'h11b4abdd;hrom[ 437] = 29'h01157856;hrom[ 438] = 29'h01167872;hrom[ 439] = 29'h00170010;hrom[ 440] = 29'h00180010;hrom[ 441] = 29'h00190010;hrom[ 442] = 29'h001a0010;hrom[ 443] = 29'h001b0010;hrom[ 444] = 29'h001c77cf;hrom[ 445] = 29'h041d003c;hrom[ 446] = 29'h001e0010;hrom[ 447] = 29'h015f0012;
    hrom[ 448] = 29'h000009e1;hrom[ 449] = 29'h020112a2;hrom[ 450] = 29'h000216c3;hrom[ 451] = 29'h00031b24;hrom[ 452] = 29'h000423a5;hrom[ 453] = 29'h000527e6;hrom[ 454] = 29'h00062c27;hrom[ 455] = 29'h00072f08;hrom[ 456] = 29'h000831e9;hrom[ 457] = 29'h000934aa;hrom[ 458] = 29'h000a378b;hrom[ 459] = 29'h000b3a4c;hrom[ 460] = 29'h000c3d2d;hrom[ 461] = 29'h000d45ee;hrom[ 462] = 29'h000e4fcf;hrom[ 463] = 29'h004f4ff0;
    hrom[ 464] = 29'h01905011;hrom[ 465] = 29'h09915035;hrom[ 466] = 29'h011266d3;hrom[ 467] = 29'h019366f4;hrom[ 468] = 29'h11b46700;hrom[ 469] = 29'h01155056;hrom[ 470] = 29'h01165072;hrom[ 471] = 29'h00170010;hrom[ 472] = 29'h00180010;hrom[ 473] = 29'h00190010;hrom[ 474] = 29'h001a0010;hrom[ 475] = 29'h001b0010;hrom[ 476] = 29'h001c0010;hrom[ 477] = 29'h001d0010;hrom[ 478] = 29'h001e0010;hrom[ 479] = 29'h015f0012;
    hrom[ 480] = 29'h00000010;hrom[ 481] = 29'h00010010;hrom[ 482] = 29'h00020010;hrom[ 483] = 29'h00030010;hrom[ 484] = 29'h00040010;hrom[ 485] = 29'h00050010;hrom[ 486] = 29'h00060010;hrom[ 487] = 29'h00070010;hrom[ 488] = 29'h00080010;hrom[ 489] = 29'h00090010;hrom[ 490] = 29'h000a0010;hrom[ 491] = 29'h000b0010;hrom[ 492] = 29'h000c0010;hrom[ 493] = 29'h000d0010;hrom[ 494] = 29'h000e0010;hrom[ 495] = 29'h004f4ff0;
    hrom[ 496] = 29'h01905011;hrom[ 497] = 29'h09915035;hrom[ 498] = 29'h011266d3;hrom[ 499] = 29'h019366f4;hrom[ 500] = 29'h11b4671d;hrom[ 501] = 29'h01155056;hrom[ 502] = 29'h01165072;hrom[ 503] = 29'h00170010;hrom[ 504] = 29'h00180010;hrom[ 505] = 29'h00190010;hrom[ 506] = 29'h001a0010;hrom[ 507] = 29'h001b0010;hrom[ 508] = 29'h001c4fcf;hrom[ 509] = 29'h041d003c;hrom[ 510] = 29'h001e0010;hrom[ 511] = 29'h015f0012;
end

always @ (posedge clk)
    if (rst)
        hrom_out <= HROM_INIT;
    else if (hrom_en)
        hrom_out <= hrom[{std, pattern[0], h_next_region}];
         
assign h_next_region =  hrom_out[4:0];
assign h_next_evnt =    hrom_out[15:5];
assign h_region_rom =   hrom_out[20:16];
assign h_clr =          hrom_out[21];
assign v_inc =          hrom_out[22];
assign trs =            hrom_out[23];
assign h =              hrom_out[24];
assign usropt_rgn =     hrom_out[25];
assign ceqpol_rgn =     hrom_out[26];
assign eav2_rgn =       hrom_out[27];
assign sav2_rgn =       hrom_out[28];

//
// Horizontal enable
//
// This signal is the clock enable signal to the HROM. It is asserted when the
// horizontal counter value equals the value of the h_next_evnt field from the
// HROM AND when the h_counter LSB is high.
//
assign hrom_en = ce & h_counter[0] & h_evnt_match;

//
// Horizontal counter
//
// The horizontal counter increments every clock cycle unless the h_clr signal
// from the HROM is asserted, in which case, it resets to a value of 0.
//
always @ (posedge clk or posedge rst)
    if (rst)
        h_counter <= 12'd4095;
    else if (ce)
        begin
            if (h_clr & h_counter[0])
                h_counter <= 0;
            else
                h_counter <= h_counter + 1;
        end

assign h_counter_lsb = h_counter[0];

//
// Horizontal event comparator
//
// This signal is asserted when the h_next_evnt value from the HROM matches the
// 11 MSBs of the h_counter.
//
assign h_evnt_match = (h_next_evnt == h_counter[HCNT_MSB:1]);

//
// Horizontal region encoder
// 
// This encoder can change the horizontal region value coming out of the horz
// ROM before it is used to address the color ROM. The horizontal region is
// modified under 3 conditions. 
//
// First, if the horizontal region is the first (leftmost) colorbar, then the 
// two user_opt inputs are applied to modify the horizontal region to affect 
// the color generated by the color ROM. 
//
// Second, if the region is the first sample of first line of the first field 
// of an even frame and the cable equalization pattern is being drawn, then 
// the sample must be drawn differently in order to provide both DC levels of 
// the cable equalization pattern. The horizontal ROM will indicate this 
// region by generating a region code of HRGN_CEQ_POL_0. The encoder will 
// normally change this to HRGN_CEQ_POL_0, unless this is the first active 
// line of the first field of an even frame, in which case it will output 
// HRGN_CEQ_POL_1 to the color ROM.
//
// Third, the color ROM needs to know the sense of the field bit in order to
// properly generate the XYZ word of EAVs and SAVs. The v_band does not carry
// the field information into the color ROM, so the field bit from the vertical
// ROM is used to modify the horizontal region during the second half of the
// EAV and SAV regions to indicate the status of the field bit.
//
always @*
    if (usropt_rgn)
        case(user_opt)
            2'b01: h_region = HRGN_USROPT1;
            2'b10: h_region = HRGN_USROPT2;
            2'b11: h_region = HRGN_USROPT3;
            default: h_region = HRGN_BAR1;
        endcase
    
    else if (ceqpol_rgn)
        begin
            if (first_line & h_counter[1:0] == 2'b00)
                h_region = HRGN_CEQ_POL_1;
            else
                h_region = HRGN_CEQ_POL_0;
        end
    
    else if (eav2_rgn)
        h_region = f ? HRGN_EAV2_F1 : HRGN_EAV2_F0;
    
    else if (sav2_rgn)
        h_region = f ? HRGN_SAV2_F1 : HRGN_SAV2_F0;

    else
        h_region = h_region_rom;

//
// XYZ signal decoding
//
assign xyz = (eav2_rgn | sav2_rgn) & h_counter[0];

endmodule
