// (c) Copyright 2004 - 2013 Xilinx, Inc. All rights reserved.
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
//  /   /         Filename: $File: //Groups/video_ip/demos/A7/xapp1097_a7_sdi_demos/Verilog/ac701_sdi_demo/vidgen_ntsc.v $
// /___/   /\     Timestamp: $DateTime: 2013/10/22 15:33:22 $
// \   \  /  \
//  \___\/\___\
//
// Description:
//
//  This video pattern generator generates digital NTSC video in two different
//  patterns: an EG-1 like color bar pattern and the SDI checkfield pattern (RP 178). 
//
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

`timescale 1ns / 1ns

module vidgen_ntsc (
    input   wire        clk,
    input   wire        rst,
    input   wire        ce,
    input   wire        pattern,
    output  wire [9:0]  q,
    output  reg         h_sync = 1'b0,
    output  reg         v_sync = 1'b0,
    output  reg         field = 1'b0
);

//-----------------------------------------------------------------------------
// Parameter definitions
//

localparam VID_WIDTH      = 10;                  // Width of video components
localparam HRGN_WIDTH     = 4;                   // Width of h_region
localparam VRGN_WIDTH     = 4;                   // Width of v_region
localparam HROM_WIDTH     = 18;                  // Width of hrom
localparam VROM_WIDTH     = 18;                  // Width of vrom
localparam CROM_WIDTH     = 9;                   // Width of crom
localparam CROM_ADR_WIDTH = 11;                  // Width of crom address 
localparam VSTATE_WIDTH   = 10;                  // Width of v_state
localparam HSTATE_WIDTH   = 10;                  // Width of h_state

localparam VID_MSB        = VID_WIDTH - 1;       // MS bit # of video
localparam HRGN_MSB       = HRGN_WIDTH - 1;      // MS bit # of h_region
localparam VRGN_MSB       = VRGN_WIDTH - 1;      // MS bit # of v_region
localparam HROM_MSB       = HROM_WIDTH - 1;      // MS bit # of hrom
localparam VROM_MSB       = VROM_WIDTH - 1;      // MS bit # of vrom 
localparam CROM_MSB       = CROM_WIDTH - 1;      // MS bit # of crom
localparam CROM_ADR_MSB   = CROM_ADR_WIDTH - 1;  // MS bit # of crom address
localparam VSTATE_MSB     = VSTATE_WIDTH - 1;    // MS bit # of v_state
localparam HSTATE_MSB     = HSTATE_WIDTH - 1;    // MS bit # of h_state

localparam HROM_INIT      = 18'h23167;
localparam VROM_INIT      = 18'h2320D;
localparam CROM_INIT      = 9'h000;

//-----------------------------------------------------------------------------
// Signal definitions
//
reg     [HROM_MSB:0]        hrom [1023:0];
reg     [VROM_MSB:0]        vrom [1023:0];
reg     [CROM_MSB:0]        crom [2047:0];

// internal signals
reg     [1:0]               samples;      // horizontal sample counter
wire                        h_enable;     // clock enable for h state machine
wire                        v_enable;     // v clock enable output of h state machine
wire                        ven;          // clock enable for v state machine     
wire    [HSTATE_MSB:0]      h_state;      // h state machine present state
wire    [VSTATE_MSB:0]      v_state;      // v state machine present state
wire    [HRGN_MSB:0]        h_region;     // h region value
wire    [VRGN_MSB:0]        v_region;     // v region value
wire                        h;            // h bit from h state machine
wire                        v;            // v bit from v state machine
wire                        f;            // field bit from v state machine
wire    [CROM_ADR_MSB:0]    crom_adr;     // crom address
reg     [HROM_MSB:0]        hrom_reg = HROM_INIT;
reg     [VROM_MSB:0]        vrom_reg = VROM_INIT;
reg     [CROM_MSB:0]        crom_reg = CROM_INIT;

//
// Horizontal state machine
//
// The horizontal state machine changes states every four samples.  During each 
// horizontal state, four video component values are generated in the following 
// pattern: Cb Y Cr Y. 
//
// The horizontal state machine generates a 10-bit current state value which
// is wrapped around to the address inputs of the ROM. Note that for standard
// definition 4:3 aspect ratio video, 9 horizontal state bits are sufficient, 
// but using ten allows for support of 16:9 aspect ratio video.
//
// The horizontal state machine also generates a 4-bit horizontal region 
// (h_region_x) value that indicates to the VIDROM which horizontal region is 
// currently active. The state machine generates a h bit that is clocked into a 
// flip-flop to generate the h_sync output of the module. Also generated is a 
// v_enable bit which enables the vertical state machine to advance to the next 
// vertical state.
//
initial begin
    hrom[   0] = 18'h00001;hrom[   1] = 18'h00002;hrom[   2] = 18'h00003;hrom[   3] = 18'h00004;hrom[   4] = 18'h00005;hrom[   5] = 18'h00006;hrom[   6] = 18'h00007;hrom[   7] = 18'h00008;hrom[   8] = 18'h00009;hrom[   9] = 18'h0000a;hrom[  10] = 18'h0000b;hrom[  11] = 18'h0000c;hrom[  12] = 18'h0000d;hrom[  13] = 18'h0000e;hrom[  14] = 18'h0000f;hrom[  15] = 18'h00010;
    hrom[  16] = 18'h00011;hrom[  17] = 18'h00012;hrom[  18] = 18'h00013;hrom[  19] = 18'h00014;hrom[  20] = 18'h00015;hrom[  21] = 18'h00016;hrom[  22] = 18'h00017;hrom[  23] = 18'h00018;hrom[  24] = 18'h00019;hrom[  25] = 18'h0001a;hrom[  26] = 18'h0001b;hrom[  27] = 18'h0001c;hrom[  28] = 18'h0001d;hrom[  29] = 18'h0001e;hrom[  30] = 18'h0001f;hrom[  31] = 18'h00020;
    hrom[  32] = 18'h00021;hrom[  33] = 18'h00022;hrom[  34] = 18'h00023;hrom[  35] = 18'h00024;hrom[  36] = 18'h00025;hrom[  37] = 18'h00026;hrom[  38] = 18'h00027;hrom[  39] = 18'h00028;hrom[  40] = 18'h00029;hrom[  41] = 18'h0002a;hrom[  42] = 18'h0002b;hrom[  43] = 18'h0002c;hrom[  44] = 18'h0002d;hrom[  45] = 18'h0002e;hrom[  46] = 18'h0002f;hrom[  47] = 18'h00030;
    hrom[  48] = 18'h00031;hrom[  49] = 18'h00032;hrom[  50] = 18'h00033;hrom[  51] = 18'h00434;hrom[  52] = 18'h00435;hrom[  53] = 18'h00436;hrom[  54] = 18'h00437;hrom[  55] = 18'h00438;hrom[  56] = 18'h00439;hrom[  57] = 18'h0043a;hrom[  58] = 18'h0043b;hrom[  59] = 18'h0043c;hrom[  60] = 18'h0043d;hrom[  61] = 18'h0043e;hrom[  62] = 18'h0043f;hrom[  63] = 18'h00440;
    hrom[  64] = 18'h00841;hrom[  65] = 18'h00842;hrom[  66] = 18'h00843;hrom[  67] = 18'h00844;hrom[  68] = 18'h00845;hrom[  69] = 18'h00846;hrom[  70] = 18'h00847;hrom[  71] = 18'h00848;hrom[  72] = 18'h00849;hrom[  73] = 18'h0084a;hrom[  74] = 18'h0084b;hrom[  75] = 18'h0084c;hrom[  76] = 18'h0084d;hrom[  77] = 18'h0084e;hrom[  78] = 18'h0084f;hrom[  79] = 18'h00850;
    hrom[  80] = 18'h00851;hrom[  81] = 18'h00852;hrom[  82] = 18'h00853;hrom[  83] = 18'h00854;hrom[  84] = 18'h00855;hrom[  85] = 18'h00856;hrom[  86] = 18'h00857;hrom[  87] = 18'h00858;hrom[  88] = 18'h00859;hrom[  89] = 18'h0085a;hrom[  90] = 18'h0085b;hrom[  91] = 18'h0085c;hrom[  92] = 18'h0085d;hrom[  93] = 18'h0085e;hrom[  94] = 18'h0085f;hrom[  95] = 18'h00860;
    hrom[  96] = 18'h00861;hrom[  97] = 18'h00862;hrom[  98] = 18'h00863;hrom[  99] = 18'h00864;hrom[ 100] = 18'h00865;hrom[ 101] = 18'h00866;hrom[ 102] = 18'h00867;hrom[ 103] = 18'h00c68;hrom[ 104] = 18'h00c69;hrom[ 105] = 18'h00c6a;hrom[ 106] = 18'h00c6b;hrom[ 107] = 18'h00c6c;hrom[ 108] = 18'h00c6d;hrom[ 109] = 18'h00c6e;hrom[ 110] = 18'h00c6f;hrom[ 111] = 18'h00c70;
    hrom[ 112] = 18'h00c71;hrom[ 113] = 18'h00c72;hrom[ 114] = 18'h00c73;hrom[ 115] = 18'h00c74;hrom[ 116] = 18'h00c75;hrom[ 117] = 18'h00c76;hrom[ 118] = 18'h00c77;hrom[ 119] = 18'h00c78;hrom[ 120] = 18'h00c79;hrom[ 121] = 18'h00c7a;hrom[ 122] = 18'h00c7b;hrom[ 123] = 18'h00c7c;hrom[ 124] = 18'h00c7d;hrom[ 125] = 18'h00c7e;hrom[ 126] = 18'h00c7f;hrom[ 127] = 18'h00c80;
    hrom[ 128] = 18'h00c81;hrom[ 129] = 18'h01082;hrom[ 130] = 18'h01083;hrom[ 131] = 18'h01084;hrom[ 132] = 18'h01085;hrom[ 133] = 18'h01086;hrom[ 134] = 18'h01087;hrom[ 135] = 18'h01088;hrom[ 136] = 18'h01089;hrom[ 137] = 18'h0108a;hrom[ 138] = 18'h0108b;hrom[ 139] = 18'h0108c;hrom[ 140] = 18'h0108d;hrom[ 141] = 18'h0108e;hrom[ 142] = 18'h0108f;hrom[ 143] = 18'h01090;
    hrom[ 144] = 18'h01091;hrom[ 145] = 18'h01092;hrom[ 146] = 18'h01093;hrom[ 147] = 18'h01094;hrom[ 148] = 18'h01095;hrom[ 149] = 18'h01096;hrom[ 150] = 18'h01097;hrom[ 151] = 18'h01098;hrom[ 152] = 18'h01099;hrom[ 153] = 18'h0109a;hrom[ 154] = 18'h0109b;hrom[ 155] = 18'h0149c;hrom[ 156] = 18'h0149d;hrom[ 157] = 18'h0149e;hrom[ 158] = 18'h0149f;hrom[ 159] = 18'h014a0;
    hrom[ 160] = 18'h014a1;hrom[ 161] = 18'h014a2;hrom[ 162] = 18'h014a3;hrom[ 163] = 18'h014a4;hrom[ 164] = 18'h014a5;hrom[ 165] = 18'h014a6;hrom[ 166] = 18'h014a7;hrom[ 167] = 18'h014a8;hrom[ 168] = 18'h014a9;hrom[ 169] = 18'h014aa;hrom[ 170] = 18'h014ab;hrom[ 171] = 18'h014ac;hrom[ 172] = 18'h014ad;hrom[ 173] = 18'h014ae;hrom[ 174] = 18'h014af;hrom[ 175] = 18'h014b0;
    hrom[ 176] = 18'h014b1;hrom[ 177] = 18'h014b2;hrom[ 178] = 18'h014b3;hrom[ 179] = 18'h014b4;hrom[ 180] = 18'h014b5;hrom[ 181] = 18'h014b6;hrom[ 182] = 18'h014b7;hrom[ 183] = 18'h014b8;hrom[ 184] = 18'h014b9;hrom[ 185] = 18'h014ba;hrom[ 186] = 18'h014bb;hrom[ 187] = 18'h014bc;hrom[ 188] = 18'h014bd;hrom[ 189] = 18'h014be;hrom[ 190] = 18'h014bf;hrom[ 191] = 18'h014c0;
    hrom[ 192] = 18'h014c1;hrom[ 193] = 18'h014c2;hrom[ 194] = 18'h018c3;hrom[ 195] = 18'h018c4;hrom[ 196] = 18'h018c5;hrom[ 197] = 18'h018c6;hrom[ 198] = 18'h018c7;hrom[ 199] = 18'h018c8;hrom[ 200] = 18'h018c9;hrom[ 201] = 18'h018ca;hrom[ 202] = 18'h018cb;hrom[ 203] = 18'h018cc;hrom[ 204] = 18'h018cd;hrom[ 205] = 18'h018ce;hrom[ 206] = 18'h018cf;hrom[ 207] = 18'h01cd0;
    hrom[ 208] = 18'h01cd1;hrom[ 209] = 18'h01cd2;hrom[ 210] = 18'h01cd3;hrom[ 211] = 18'h01cd4;hrom[ 212] = 18'h01cd5;hrom[ 213] = 18'h01cd6;hrom[ 214] = 18'h01cd7;hrom[ 215] = 18'h01cd8;hrom[ 216] = 18'h01cd9;hrom[ 217] = 18'h01cda;hrom[ 218] = 18'h01cdb;hrom[ 219] = 18'h01cdc;hrom[ 220] = 18'h01cdd;hrom[ 221] = 18'h01cde;hrom[ 222] = 18'h01cdf;hrom[ 223] = 18'h01ce0;
    hrom[ 224] = 18'h01ce1;hrom[ 225] = 18'h01ce2;hrom[ 226] = 18'h01ce3;hrom[ 227] = 18'h01ce4;hrom[ 228] = 18'h01ce5;hrom[ 229] = 18'h01ce6;hrom[ 230] = 18'h01ce7;hrom[ 231] = 18'h01ce8;hrom[ 232] = 18'h01ce9;hrom[ 233] = 18'h01cea;hrom[ 234] = 18'h01ceb;hrom[ 235] = 18'h01cec;hrom[ 236] = 18'h01ced;hrom[ 237] = 18'h01cee;hrom[ 238] = 18'h01cef;hrom[ 239] = 18'h01cf0;
    hrom[ 240] = 18'h01cf1;hrom[ 241] = 18'h01cf2;hrom[ 242] = 18'h01cf3;hrom[ 243] = 18'h01cf4;hrom[ 244] = 18'h01cf5;hrom[ 245] = 18'h01cf6;hrom[ 246] = 18'h01cf7;hrom[ 247] = 18'h01cf8;hrom[ 248] = 18'h01cf9;hrom[ 249] = 18'h01cfa;hrom[ 250] = 18'h01cfb;hrom[ 251] = 18'h01cfc;hrom[ 252] = 18'h01cfd;hrom[ 253] = 18'h01cfe;hrom[ 254] = 18'h01cff;hrom[ 255] = 18'h01d00;
    hrom[ 256] = 18'h01d01;hrom[ 257] = 18'h01d02;hrom[ 258] = 18'h01d03;hrom[ 259] = 18'h02104;hrom[ 260] = 18'h02105;hrom[ 261] = 18'h02106;hrom[ 262] = 18'h02107;hrom[ 263] = 18'h02108;hrom[ 264] = 18'h02109;hrom[ 265] = 18'h0210a;hrom[ 266] = 18'h0210b;hrom[ 267] = 18'h0210c;hrom[ 268] = 18'h0210d;hrom[ 269] = 18'h0210e;hrom[ 270] = 18'h0210f;hrom[ 271] = 18'h02110;
    hrom[ 272] = 18'h02111;hrom[ 273] = 18'h02112;hrom[ 274] = 18'h02113;hrom[ 275] = 18'h02114;hrom[ 276] = 18'h02515;hrom[ 277] = 18'h02516;hrom[ 278] = 18'h02517;hrom[ 279] = 18'h02518;hrom[ 280] = 18'h02519;hrom[ 281] = 18'h0251a;hrom[ 282] = 18'h0251b;hrom[ 283] = 18'h0251c;hrom[ 284] = 18'h0251d;hrom[ 285] = 18'h0251e;hrom[ 286] = 18'h0251f;hrom[ 287] = 18'h02520;
    hrom[ 288] = 18'h02521;hrom[ 289] = 18'h02522;hrom[ 290] = 18'h02523;hrom[ 291] = 18'h02524;hrom[ 292] = 18'h02525;hrom[ 293] = 18'h02526;hrom[ 294] = 18'h02927;hrom[ 295] = 18'h02928;hrom[ 296] = 18'h02929;hrom[ 297] = 18'h0292a;hrom[ 298] = 18'h0292b;hrom[ 299] = 18'h0292c;hrom[ 300] = 18'h0292d;hrom[ 301] = 18'h0292e;hrom[ 302] = 18'h0292f;hrom[ 303] = 18'h02930;
    hrom[ 304] = 18'h02931;hrom[ 305] = 18'h02932;hrom[ 306] = 18'h02933;hrom[ 307] = 18'h02934;hrom[ 308] = 18'h02935;hrom[ 309] = 18'h02936;hrom[ 310] = 18'h02937;hrom[ 311] = 18'h02d38;hrom[ 312] = 18'h02d39;hrom[ 313] = 18'h02d3a;hrom[ 314] = 18'h02d3b;hrom[ 315] = 18'h02d3c;hrom[ 316] = 18'h02d3d;hrom[ 317] = 18'h02d3e;hrom[ 318] = 18'h02d3f;hrom[ 319] = 18'h02d40;
    hrom[ 320] = 18'h02d41;hrom[ 321] = 18'h02d42;hrom[ 322] = 18'h02d43;hrom[ 323] = 18'h02d44;hrom[ 324] = 18'h02d45;hrom[ 325] = 18'h02d46;hrom[ 326] = 18'h02d47;hrom[ 327] = 18'h02d48;hrom[ 328] = 18'h02d49;hrom[ 329] = 18'h02d4a;hrom[ 330] = 18'h02d4b;hrom[ 331] = 18'h02d4c;hrom[ 332] = 18'h02d4d;hrom[ 333] = 18'h02d4e;hrom[ 334] = 18'h02d4f;hrom[ 335] = 18'h02d50;
    hrom[ 336] = 18'h02d51;hrom[ 337] = 18'h02d52;hrom[ 338] = 18'h02d53;hrom[ 339] = 18'h02d54;hrom[ 340] = 18'h02d55;hrom[ 341] = 18'h02d56;hrom[ 342] = 18'h02d57;hrom[ 343] = 18'h02d58;hrom[ 344] = 18'h02d59;hrom[ 345] = 18'h02d5a;hrom[ 346] = 18'h02d5b;hrom[ 347] = 18'h02d5c;hrom[ 348] = 18'h02d5d;hrom[ 349] = 18'h02d5e;hrom[ 350] = 18'h02d5f;hrom[ 351] = 18'h02d60;
    hrom[ 352] = 18'h02d61;hrom[ 353] = 18'h02d62;hrom[ 354] = 18'h02d63;hrom[ 355] = 18'h02d64;hrom[ 356] = 18'h02d65;hrom[ 357] = 18'h02d66;hrom[ 358] = 18'h23167;hrom[ 359] = 18'h13968;hrom[ 360] = 18'h13569;hrom[ 361] = 18'h1356a;hrom[ 362] = 18'h1356b;hrom[ 363] = 18'h1356c;hrom[ 364] = 18'h1356d;hrom[ 365] = 18'h1356e;hrom[ 366] = 18'h1356f;hrom[ 367] = 18'h13570;
    hrom[ 368] = 18'h13571;hrom[ 369] = 18'h13572;hrom[ 370] = 18'h13573;hrom[ 371] = 18'h13574;hrom[ 372] = 18'h13575;hrom[ 373] = 18'h13576;hrom[ 374] = 18'h13577;hrom[ 375] = 18'h13578;hrom[ 376] = 18'h13579;hrom[ 377] = 18'h1357a;hrom[ 378] = 18'h1357b;hrom[ 379] = 18'h1357c;hrom[ 380] = 18'h1357d;hrom[ 381] = 18'h1357e;hrom[ 382] = 18'h1357f;hrom[ 383] = 18'h13580;
    hrom[ 384] = 18'h13581;hrom[ 385] = 18'h13582;hrom[ 386] = 18'h13583;hrom[ 387] = 18'h13584;hrom[ 388] = 18'h13585;hrom[ 389] = 18'h13586;hrom[ 390] = 18'h13587;hrom[ 391] = 18'h13588;hrom[ 392] = 18'h13589;hrom[ 393] = 18'h1358a;hrom[ 394] = 18'h1358b;hrom[ 395] = 18'h1358c;hrom[ 396] = 18'h1358d;hrom[ 397] = 18'h1358e;hrom[ 398] = 18'h1358f;hrom[ 399] = 18'h13590;
    hrom[ 400] = 18'h13591;hrom[ 401] = 18'h13592;hrom[ 402] = 18'h13593;hrom[ 403] = 18'h13594;hrom[ 404] = 18'h13595;hrom[ 405] = 18'h13596;hrom[ 406] = 18'h13597;hrom[ 407] = 18'h13598;hrom[ 408] = 18'h13599;hrom[ 409] = 18'h1359a;hrom[ 410] = 18'h1359b;hrom[ 411] = 18'h1359c;hrom[ 412] = 18'h1359d;hrom[ 413] = 18'h1359e;hrom[ 414] = 18'h1359f;hrom[ 415] = 18'h135a0;
    hrom[ 416] = 18'h135a1;hrom[ 417] = 18'h135a2;hrom[ 418] = 18'h135a3;hrom[ 419] = 18'h135a4;hrom[ 420] = 18'h135a5;hrom[ 421] = 18'h135a6;hrom[ 422] = 18'h135a7;hrom[ 423] = 18'h135a8;hrom[ 424] = 18'h135a9;hrom[ 425] = 18'h135aa;hrom[ 426] = 18'h135ab;hrom[ 427] = 18'h13dac;hrom[ 428] = 18'h00000;hrom[ 429] = 18'h23167;hrom[ 430] = 18'h23167;hrom[ 431] = 18'h23167;
    hrom[ 432] = 18'h23167;hrom[ 433] = 18'h23167;hrom[ 434] = 18'h23167;hrom[ 435] = 18'h23167;hrom[ 436] = 18'h23167;hrom[ 437] = 18'h23167;hrom[ 438] = 18'h23167;hrom[ 439] = 18'h23167;hrom[ 440] = 18'h23167;hrom[ 441] = 18'h23167;hrom[ 442] = 18'h23167;hrom[ 443] = 18'h23167;hrom[ 444] = 18'h23167;hrom[ 445] = 18'h23167;hrom[ 446] = 18'h23167;hrom[ 447] = 18'h23167;
    hrom[ 448] = 18'h23167;hrom[ 449] = 18'h23167;hrom[ 450] = 18'h23167;hrom[ 451] = 18'h23167;hrom[ 452] = 18'h23167;hrom[ 453] = 18'h23167;hrom[ 454] = 18'h23167;hrom[ 455] = 18'h23167;hrom[ 456] = 18'h23167;hrom[ 457] = 18'h23167;hrom[ 458] = 18'h23167;hrom[ 459] = 18'h23167;hrom[ 460] = 18'h23167;hrom[ 461] = 18'h23167;hrom[ 462] = 18'h23167;hrom[ 463] = 18'h23167;
    hrom[ 464] = 18'h23167;hrom[ 465] = 18'h23167;hrom[ 466] = 18'h23167;hrom[ 467] = 18'h23167;hrom[ 468] = 18'h23167;hrom[ 469] = 18'h23167;hrom[ 470] = 18'h23167;hrom[ 471] = 18'h23167;hrom[ 472] = 18'h23167;hrom[ 473] = 18'h23167;hrom[ 474] = 18'h23167;hrom[ 475] = 18'h23167;hrom[ 476] = 18'h23167;hrom[ 477] = 18'h23167;hrom[ 478] = 18'h23167;hrom[ 479] = 18'h23167;
    hrom[ 480] = 18'h23167;hrom[ 481] = 18'h23167;hrom[ 482] = 18'h23167;hrom[ 483] = 18'h23167;hrom[ 484] = 18'h23167;hrom[ 485] = 18'h23167;hrom[ 486] = 18'h23167;hrom[ 487] = 18'h23167;hrom[ 488] = 18'h23167;hrom[ 489] = 18'h23167;hrom[ 490] = 18'h23167;hrom[ 491] = 18'h23167;hrom[ 492] = 18'h23167;hrom[ 493] = 18'h23167;hrom[ 494] = 18'h23167;hrom[ 495] = 18'h23167;
    hrom[ 496] = 18'h23167;hrom[ 497] = 18'h23167;hrom[ 498] = 18'h23167;hrom[ 499] = 18'h23167;hrom[ 500] = 18'h23167;hrom[ 501] = 18'h23167;hrom[ 502] = 18'h23167;hrom[ 503] = 18'h23167;hrom[ 504] = 18'h23167;hrom[ 505] = 18'h23167;hrom[ 506] = 18'h23167;hrom[ 507] = 18'h23167;hrom[ 508] = 18'h23167;hrom[ 509] = 18'h23167;hrom[ 510] = 18'h23167;hrom[ 511] = 18'h23167;
    hrom[ 512] = 18'h23167;hrom[ 513] = 18'h23167;hrom[ 514] = 18'h23167;hrom[ 515] = 18'h23167;hrom[ 516] = 18'h23167;hrom[ 517] = 18'h23167;hrom[ 518] = 18'h23167;hrom[ 519] = 18'h23167;hrom[ 520] = 18'h23167;hrom[ 521] = 18'h23167;hrom[ 522] = 18'h23167;hrom[ 523] = 18'h23167;hrom[ 524] = 18'h23167;hrom[ 525] = 18'h23167;hrom[ 526] = 18'h23167;hrom[ 527] = 18'h23167;
    hrom[ 528] = 18'h23167;hrom[ 529] = 18'h23167;hrom[ 530] = 18'h23167;hrom[ 531] = 18'h23167;hrom[ 532] = 18'h23167;hrom[ 533] = 18'h23167;hrom[ 534] = 18'h23167;hrom[ 535] = 18'h23167;hrom[ 536] = 18'h23167;hrom[ 537] = 18'h23167;hrom[ 538] = 18'h23167;hrom[ 539] = 18'h23167;hrom[ 540] = 18'h23167;hrom[ 541] = 18'h23167;hrom[ 542] = 18'h23167;hrom[ 543] = 18'h23167;
    hrom[ 544] = 18'h23167;hrom[ 545] = 18'h23167;hrom[ 546] = 18'h23167;hrom[ 547] = 18'h23167;hrom[ 548] = 18'h23167;hrom[ 549] = 18'h23167;hrom[ 550] = 18'h23167;hrom[ 551] = 18'h23167;hrom[ 552] = 18'h23167;hrom[ 553] = 18'h23167;hrom[ 554] = 18'h23167;hrom[ 555] = 18'h23167;hrom[ 556] = 18'h23167;hrom[ 557] = 18'h23167;hrom[ 558] = 18'h23167;hrom[ 559] = 18'h23167;
    hrom[ 560] = 18'h23167;hrom[ 561] = 18'h23167;hrom[ 562] = 18'h23167;hrom[ 563] = 18'h23167;hrom[ 564] = 18'h23167;hrom[ 565] = 18'h23167;hrom[ 566] = 18'h23167;hrom[ 567] = 18'h23167;hrom[ 568] = 18'h23167;hrom[ 569] = 18'h23167;hrom[ 570] = 18'h23167;hrom[ 571] = 18'h23167;hrom[ 572] = 18'h23167;hrom[ 573] = 18'h23167;hrom[ 574] = 18'h23167;hrom[ 575] = 18'h23167;
    hrom[ 576] = 18'h23167;hrom[ 577] = 18'h23167;hrom[ 578] = 18'h23167;hrom[ 579] = 18'h23167;hrom[ 580] = 18'h23167;hrom[ 581] = 18'h23167;hrom[ 582] = 18'h23167;hrom[ 583] = 18'h23167;hrom[ 584] = 18'h23167;hrom[ 585] = 18'h23167;hrom[ 586] = 18'h23167;hrom[ 587] = 18'h23167;hrom[ 588] = 18'h23167;hrom[ 589] = 18'h23167;hrom[ 590] = 18'h23167;hrom[ 591] = 18'h23167;
    hrom[ 592] = 18'h23167;hrom[ 593] = 18'h23167;hrom[ 594] = 18'h23167;hrom[ 595] = 18'h23167;hrom[ 596] = 18'h23167;hrom[ 597] = 18'h23167;hrom[ 598] = 18'h23167;hrom[ 599] = 18'h23167;hrom[ 600] = 18'h23167;hrom[ 601] = 18'h23167;hrom[ 602] = 18'h23167;hrom[ 603] = 18'h23167;hrom[ 604] = 18'h23167;hrom[ 605] = 18'h23167;hrom[ 606] = 18'h23167;hrom[ 607] = 18'h23167;
    hrom[ 608] = 18'h23167;hrom[ 609] = 18'h23167;hrom[ 610] = 18'h23167;hrom[ 611] = 18'h23167;hrom[ 612] = 18'h23167;hrom[ 613] = 18'h23167;hrom[ 614] = 18'h23167;hrom[ 615] = 18'h23167;hrom[ 616] = 18'h23167;hrom[ 617] = 18'h23167;hrom[ 618] = 18'h23167;hrom[ 619] = 18'h23167;hrom[ 620] = 18'h23167;hrom[ 621] = 18'h23167;hrom[ 622] = 18'h23167;hrom[ 623] = 18'h23167;
    hrom[ 624] = 18'h23167;hrom[ 625] = 18'h23167;hrom[ 626] = 18'h23167;hrom[ 627] = 18'h23167;hrom[ 628] = 18'h23167;hrom[ 629] = 18'h23167;hrom[ 630] = 18'h23167;hrom[ 631] = 18'h23167;hrom[ 632] = 18'h23167;hrom[ 633] = 18'h23167;hrom[ 634] = 18'h23167;hrom[ 635] = 18'h23167;hrom[ 636] = 18'h23167;hrom[ 637] = 18'h23167;hrom[ 638] = 18'h23167;hrom[ 639] = 18'h23167;
    hrom[ 640] = 18'h23167;hrom[ 641] = 18'h23167;hrom[ 642] = 18'h23167;hrom[ 643] = 18'h23167;hrom[ 644] = 18'h23167;hrom[ 645] = 18'h23167;hrom[ 646] = 18'h23167;hrom[ 647] = 18'h23167;hrom[ 648] = 18'h23167;hrom[ 649] = 18'h23167;hrom[ 650] = 18'h23167;hrom[ 651] = 18'h23167;hrom[ 652] = 18'h23167;hrom[ 653] = 18'h23167;hrom[ 654] = 18'h23167;hrom[ 655] = 18'h23167;
    hrom[ 656] = 18'h23167;hrom[ 657] = 18'h23167;hrom[ 658] = 18'h23167;hrom[ 659] = 18'h23167;hrom[ 660] = 18'h23167;hrom[ 661] = 18'h23167;hrom[ 662] = 18'h23167;hrom[ 663] = 18'h23167;hrom[ 664] = 18'h23167;hrom[ 665] = 18'h23167;hrom[ 666] = 18'h23167;hrom[ 667] = 18'h23167;hrom[ 668] = 18'h23167;hrom[ 669] = 18'h23167;hrom[ 670] = 18'h23167;hrom[ 671] = 18'h23167;
    hrom[ 672] = 18'h23167;hrom[ 673] = 18'h23167;hrom[ 674] = 18'h23167;hrom[ 675] = 18'h23167;hrom[ 676] = 18'h23167;hrom[ 677] = 18'h23167;hrom[ 678] = 18'h23167;hrom[ 679] = 18'h23167;hrom[ 680] = 18'h23167;hrom[ 681] = 18'h23167;hrom[ 682] = 18'h23167;hrom[ 683] = 18'h23167;hrom[ 684] = 18'h23167;hrom[ 685] = 18'h23167;hrom[ 686] = 18'h23167;hrom[ 687] = 18'h23167;
    hrom[ 688] = 18'h23167;hrom[ 689] = 18'h23167;hrom[ 690] = 18'h23167;hrom[ 691] = 18'h23167;hrom[ 692] = 18'h23167;hrom[ 693] = 18'h23167;hrom[ 694] = 18'h23167;hrom[ 695] = 18'h23167;hrom[ 696] = 18'h23167;hrom[ 697] = 18'h23167;hrom[ 698] = 18'h23167;hrom[ 699] = 18'h23167;hrom[ 700] = 18'h23167;hrom[ 701] = 18'h23167;hrom[ 702] = 18'h23167;hrom[ 703] = 18'h23167;
    hrom[ 704] = 18'h23167;hrom[ 705] = 18'h23167;hrom[ 706] = 18'h23167;hrom[ 707] = 18'h23167;hrom[ 708] = 18'h23167;hrom[ 709] = 18'h23167;hrom[ 710] = 18'h23167;hrom[ 711] = 18'h23167;hrom[ 712] = 18'h23167;hrom[ 713] = 18'h23167;hrom[ 714] = 18'h23167;hrom[ 715] = 18'h23167;hrom[ 716] = 18'h23167;hrom[ 717] = 18'h23167;hrom[ 718] = 18'h23167;hrom[ 719] = 18'h23167;
    hrom[ 720] = 18'h23167;hrom[ 721] = 18'h23167;hrom[ 722] = 18'h23167;hrom[ 723] = 18'h23167;hrom[ 724] = 18'h23167;hrom[ 725] = 18'h23167;hrom[ 726] = 18'h23167;hrom[ 727] = 18'h23167;hrom[ 728] = 18'h23167;hrom[ 729] = 18'h23167;hrom[ 730] = 18'h23167;hrom[ 731] = 18'h23167;hrom[ 732] = 18'h23167;hrom[ 733] = 18'h23167;hrom[ 734] = 18'h23167;hrom[ 735] = 18'h23167;
    hrom[ 736] = 18'h23167;hrom[ 737] = 18'h23167;hrom[ 738] = 18'h23167;hrom[ 739] = 18'h23167;hrom[ 740] = 18'h23167;hrom[ 741] = 18'h23167;hrom[ 742] = 18'h23167;hrom[ 743] = 18'h23167;hrom[ 744] = 18'h23167;hrom[ 745] = 18'h23167;hrom[ 746] = 18'h23167;hrom[ 747] = 18'h23167;hrom[ 748] = 18'h23167;hrom[ 749] = 18'h23167;hrom[ 750] = 18'h23167;hrom[ 751] = 18'h23167;
    hrom[ 752] = 18'h23167;hrom[ 753] = 18'h23167;hrom[ 754] = 18'h23167;hrom[ 755] = 18'h23167;hrom[ 756] = 18'h23167;hrom[ 757] = 18'h23167;hrom[ 758] = 18'h23167;hrom[ 759] = 18'h23167;hrom[ 760] = 18'h23167;hrom[ 761] = 18'h23167;hrom[ 762] = 18'h23167;hrom[ 763] = 18'h23167;hrom[ 764] = 18'h23167;hrom[ 765] = 18'h23167;hrom[ 766] = 18'h23167;hrom[ 767] = 18'h23167;
    hrom[ 768] = 18'h23167;hrom[ 769] = 18'h23167;hrom[ 770] = 18'h23167;hrom[ 771] = 18'h23167;hrom[ 772] = 18'h23167;hrom[ 773] = 18'h23167;hrom[ 774] = 18'h23167;hrom[ 775] = 18'h23167;hrom[ 776] = 18'h23167;hrom[ 777] = 18'h23167;hrom[ 778] = 18'h23167;hrom[ 779] = 18'h23167;hrom[ 780] = 18'h23167;hrom[ 781] = 18'h23167;hrom[ 782] = 18'h23167;hrom[ 783] = 18'h23167;
    hrom[ 784] = 18'h23167;hrom[ 785] = 18'h23167;hrom[ 786] = 18'h23167;hrom[ 787] = 18'h23167;hrom[ 788] = 18'h23167;hrom[ 789] = 18'h23167;hrom[ 790] = 18'h23167;hrom[ 791] = 18'h23167;hrom[ 792] = 18'h23167;hrom[ 793] = 18'h23167;hrom[ 794] = 18'h23167;hrom[ 795] = 18'h23167;hrom[ 796] = 18'h23167;hrom[ 797] = 18'h23167;hrom[ 798] = 18'h23167;hrom[ 799] = 18'h23167;
    hrom[ 800] = 18'h23167;hrom[ 801] = 18'h23167;hrom[ 802] = 18'h23167;hrom[ 803] = 18'h23167;hrom[ 804] = 18'h23167;hrom[ 805] = 18'h23167;hrom[ 806] = 18'h23167;hrom[ 807] = 18'h23167;hrom[ 808] = 18'h23167;hrom[ 809] = 18'h23167;hrom[ 810] = 18'h23167;hrom[ 811] = 18'h23167;hrom[ 812] = 18'h23167;hrom[ 813] = 18'h23167;hrom[ 814] = 18'h23167;hrom[ 815] = 18'h23167;
    hrom[ 816] = 18'h23167;hrom[ 817] = 18'h23167;hrom[ 818] = 18'h23167;hrom[ 819] = 18'h23167;hrom[ 820] = 18'h23167;hrom[ 821] = 18'h23167;hrom[ 822] = 18'h23167;hrom[ 823] = 18'h23167;hrom[ 824] = 18'h23167;hrom[ 825] = 18'h23167;hrom[ 826] = 18'h23167;hrom[ 827] = 18'h23167;hrom[ 828] = 18'h23167;hrom[ 829] = 18'h23167;hrom[ 830] = 18'h23167;hrom[ 831] = 18'h23167;
    hrom[ 832] = 18'h23167;hrom[ 833] = 18'h23167;hrom[ 834] = 18'h23167;hrom[ 835] = 18'h23167;hrom[ 836] = 18'h23167;hrom[ 837] = 18'h23167;hrom[ 838] = 18'h23167;hrom[ 839] = 18'h23167;hrom[ 840] = 18'h23167;hrom[ 841] = 18'h23167;hrom[ 842] = 18'h23167;hrom[ 843] = 18'h23167;hrom[ 844] = 18'h23167;hrom[ 845] = 18'h23167;hrom[ 846] = 18'h23167;hrom[ 847] = 18'h23167;
    hrom[ 848] = 18'h23167;hrom[ 849] = 18'h23167;hrom[ 850] = 18'h23167;hrom[ 851] = 18'h23167;hrom[ 852] = 18'h23167;hrom[ 853] = 18'h23167;hrom[ 854] = 18'h23167;hrom[ 855] = 18'h23167;hrom[ 856] = 18'h23167;hrom[ 857] = 18'h23167;hrom[ 858] = 18'h23167;hrom[ 859] = 18'h23167;hrom[ 860] = 18'h23167;hrom[ 861] = 18'h23167;hrom[ 862] = 18'h23167;hrom[ 863] = 18'h23167;
    hrom[ 864] = 18'h23167;hrom[ 865] = 18'h23167;hrom[ 866] = 18'h23167;hrom[ 867] = 18'h23167;hrom[ 868] = 18'h23167;hrom[ 869] = 18'h23167;hrom[ 870] = 18'h23167;hrom[ 871] = 18'h23167;hrom[ 872] = 18'h23167;hrom[ 873] = 18'h23167;hrom[ 874] = 18'h23167;hrom[ 875] = 18'h23167;hrom[ 876] = 18'h23167;hrom[ 877] = 18'h23167;hrom[ 878] = 18'h23167;hrom[ 879] = 18'h23167;
    hrom[ 880] = 18'h23167;hrom[ 881] = 18'h23167;hrom[ 882] = 18'h23167;hrom[ 883] = 18'h23167;hrom[ 884] = 18'h23167;hrom[ 885] = 18'h23167;hrom[ 886] = 18'h23167;hrom[ 887] = 18'h23167;hrom[ 888] = 18'h23167;hrom[ 889] = 18'h23167;hrom[ 890] = 18'h23167;hrom[ 891] = 18'h23167;hrom[ 892] = 18'h23167;hrom[ 893] = 18'h23167;hrom[ 894] = 18'h23167;hrom[ 895] = 18'h23167;
    hrom[ 896] = 18'h23167;hrom[ 897] = 18'h23167;hrom[ 898] = 18'h23167;hrom[ 899] = 18'h23167;hrom[ 900] = 18'h23167;hrom[ 901] = 18'h23167;hrom[ 902] = 18'h23167;hrom[ 903] = 18'h23167;hrom[ 904] = 18'h23167;hrom[ 905] = 18'h23167;hrom[ 906] = 18'h23167;hrom[ 907] = 18'h23167;hrom[ 908] = 18'h23167;hrom[ 909] = 18'h23167;hrom[ 910] = 18'h23167;hrom[ 911] = 18'h23167;
    hrom[ 912] = 18'h23167;hrom[ 913] = 18'h23167;hrom[ 914] = 18'h23167;hrom[ 915] = 18'h23167;hrom[ 916] = 18'h23167;hrom[ 917] = 18'h23167;hrom[ 918] = 18'h23167;hrom[ 919] = 18'h23167;hrom[ 920] = 18'h23167;hrom[ 921] = 18'h23167;hrom[ 922] = 18'h23167;hrom[ 923] = 18'h23167;hrom[ 924] = 18'h23167;hrom[ 925] = 18'h23167;hrom[ 926] = 18'h23167;hrom[ 927] = 18'h23167;
    hrom[ 928] = 18'h23167;hrom[ 929] = 18'h23167;hrom[ 930] = 18'h23167;hrom[ 931] = 18'h23167;hrom[ 932] = 18'h23167;hrom[ 933] = 18'h23167;hrom[ 934] = 18'h23167;hrom[ 935] = 18'h23167;hrom[ 936] = 18'h23167;hrom[ 937] = 18'h23167;hrom[ 938] = 18'h23167;hrom[ 939] = 18'h23167;hrom[ 940] = 18'h23167;hrom[ 941] = 18'h23167;hrom[ 942] = 18'h23167;hrom[ 943] = 18'h23167;
    hrom[ 944] = 18'h23167;hrom[ 945] = 18'h23167;hrom[ 946] = 18'h23167;hrom[ 947] = 18'h23167;hrom[ 948] = 18'h23167;hrom[ 949] = 18'h23167;hrom[ 950] = 18'h23167;hrom[ 951] = 18'h23167;hrom[ 952] = 18'h23167;hrom[ 953] = 18'h23167;hrom[ 954] = 18'h23167;hrom[ 955] = 18'h23167;hrom[ 956] = 18'h23167;hrom[ 957] = 18'h23167;hrom[ 958] = 18'h23167;hrom[ 959] = 18'h23167;
    hrom[ 960] = 18'h23167;hrom[ 961] = 18'h23167;hrom[ 962] = 18'h23167;hrom[ 963] = 18'h23167;hrom[ 964] = 18'h23167;hrom[ 965] = 18'h23167;hrom[ 966] = 18'h23167;hrom[ 967] = 18'h23167;hrom[ 968] = 18'h23167;hrom[ 969] = 18'h23167;hrom[ 970] = 18'h23167;hrom[ 971] = 18'h23167;hrom[ 972] = 18'h23167;hrom[ 973] = 18'h23167;hrom[ 974] = 18'h23167;hrom[ 975] = 18'h23167;
    hrom[ 976] = 18'h23167;hrom[ 977] = 18'h23167;hrom[ 978] = 18'h23167;hrom[ 979] = 18'h23167;hrom[ 980] = 18'h23167;hrom[ 981] = 18'h23167;hrom[ 982] = 18'h23167;hrom[ 983] = 18'h23167;hrom[ 984] = 18'h23167;hrom[ 985] = 18'h23167;hrom[ 986] = 18'h23167;hrom[ 987] = 18'h23167;hrom[ 988] = 18'h23167;hrom[ 989] = 18'h23167;hrom[ 990] = 18'h23167;hrom[ 991] = 18'h23167;
    hrom[ 992] = 18'h23167;hrom[ 993] = 18'h23167;hrom[ 994] = 18'h23167;hrom[ 995] = 18'h23167;hrom[ 996] = 18'h23167;hrom[ 997] = 18'h23167;hrom[ 998] = 18'h23167;hrom[ 999] = 18'h23167;hrom[1000] = 18'h23167;hrom[1001] = 18'h23167;hrom[1002] = 18'h23167;hrom[1003] = 18'h23167;hrom[1004] = 18'h23167;hrom[1005] = 18'h23167;hrom[1006] = 18'h23167;hrom[1007] = 18'h23167;
    hrom[1008] = 18'h23167;hrom[1009] = 18'h23167;hrom[1010] = 18'h23167;hrom[1011] = 18'h23167;hrom[1012] = 18'h23167;hrom[1013] = 18'h23167;hrom[1014] = 18'h23167;hrom[1015] = 18'h23167;hrom[1016] = 18'h23167;hrom[1017] = 18'h23167;hrom[1018] = 18'h23167;hrom[1019] = 18'h23167;hrom[1020] = 18'h23167;hrom[1021] = 18'h23167;hrom[1022] = 18'h23167;hrom[1023] = 18'h23167;
end

always @ (posedge clk)
    if (rst)
        hrom_reg <= HROM_INIT;
    else if (ce & h_enable)
        hrom_reg <= hrom[h_state];

// Assign the HROM output to the various signals
assign h_enable = &samples;
assign v_enable = hrom_reg[17];
assign h        = hrom_reg[16];
assign h_region = hrom_reg[HRGN_MSB + HSTATE_WIDTH:HSTATE_WIDTH];
assign h_state  = hrom_reg[HSTATE_MSB:0];

// 
// Vertical state machine
//
// The vertical state machine changes states once per line. It advances to the
// next state when the v_enable signal from the horizontal state machine is
// asserted (and the sample counter is at 3). The advancement to the next line
// does not occur when the horizontal state machine is at its maximum count.
// Instead this happens such that the new line begins coincident with the EAV
// symbol.
//
// The vertical state machine ROM generates a 10-bit current state value. This
// is sufficient to support both NTSC and PAL standard definition video. The
// current state is wrapped back to the address inputs of the VROM.
//
// The vertical state machine generates a 4-bit vertical region value 
// (v_region_x) that indicates to the video component ROM which vertical region 
// is active. Also generated by the vertical state machine are f and v signals 
// that are registered by flip-flops and become the field and v_sync outputs of 
// the module.
//
initial begin
    vrom[   0] = 18'h2320d;vrom[   1] = 18'h30002;vrom[   2] = 18'h30003;vrom[   3] = 18'h10404;vrom[   4] = 18'h10405;vrom[   5] = 18'h10406;vrom[   6] = 18'h10407;vrom[   7] = 18'h10408;vrom[   8] = 18'h10409;vrom[   9] = 18'h1040a;vrom[  10] = 18'h1040b;vrom[  11] = 18'h1040c;vrom[  12] = 18'h1040d;vrom[  13] = 18'h1040e;vrom[  14] = 18'h1040f;vrom[  15] = 18'h10410;
    vrom[  16] = 18'h10411;vrom[  17] = 18'h10412;vrom[  18] = 18'h10413;vrom[  19] = 18'h00814;vrom[  20] = 18'h00c15;vrom[  21] = 18'h00c16;vrom[  22] = 18'h00c17;vrom[  23] = 18'h00c18;vrom[  24] = 18'h00c19;vrom[  25] = 18'h00c1a;vrom[  26] = 18'h00c1b;vrom[  27] = 18'h00c1c;vrom[  28] = 18'h00c1d;vrom[  29] = 18'h00c1e;vrom[  30] = 18'h00c1f;vrom[  31] = 18'h00c20;
    vrom[  32] = 18'h00c21;vrom[  33] = 18'h00c22;vrom[  34] = 18'h00c23;vrom[  35] = 18'h00c24;vrom[  36] = 18'h00c25;vrom[  37] = 18'h00c26;vrom[  38] = 18'h00c27;vrom[  39] = 18'h00c28;vrom[  40] = 18'h00c29;vrom[  41] = 18'h00c2a;vrom[  42] = 18'h00c2b;vrom[  43] = 18'h00c2c;vrom[  44] = 18'h00c2d;vrom[  45] = 18'h00c2e;vrom[  46] = 18'h00c2f;vrom[  47] = 18'h00c30;
    vrom[  48] = 18'h00c31;vrom[  49] = 18'h00c32;vrom[  50] = 18'h00c33;vrom[  51] = 18'h00c34;vrom[  52] = 18'h00c35;vrom[  53] = 18'h00c36;vrom[  54] = 18'h00c37;vrom[  55] = 18'h00c38;vrom[  56] = 18'h00c39;vrom[  57] = 18'h00c3a;vrom[  58] = 18'h00c3b;vrom[  59] = 18'h00c3c;vrom[  60] = 18'h00c3d;vrom[  61] = 18'h00c3e;vrom[  62] = 18'h00c3f;vrom[  63] = 18'h00c40;
    vrom[  64] = 18'h00c41;vrom[  65] = 18'h00c42;vrom[  66] = 18'h00c43;vrom[  67] = 18'h00c44;vrom[  68] = 18'h00c45;vrom[  69] = 18'h00c46;vrom[  70] = 18'h00c47;vrom[  71] = 18'h00c48;vrom[  72] = 18'h00c49;vrom[  73] = 18'h00c4a;vrom[  74] = 18'h00c4b;vrom[  75] = 18'h00c4c;vrom[  76] = 18'h00c4d;vrom[  77] = 18'h00c4e;vrom[  78] = 18'h00c4f;vrom[  79] = 18'h00c50;
    vrom[  80] = 18'h00c51;vrom[  81] = 18'h00c52;vrom[  82] = 18'h00c53;vrom[  83] = 18'h00c54;vrom[  84] = 18'h00c55;vrom[  85] = 18'h00c56;vrom[  86] = 18'h00c57;vrom[  87] = 18'h00c58;vrom[  88] = 18'h00c59;vrom[  89] = 18'h00c5a;vrom[  90] = 18'h00c5b;vrom[  91] = 18'h00c5c;vrom[  92] = 18'h00c5d;vrom[  93] = 18'h00c5e;vrom[  94] = 18'h00c5f;vrom[  95] = 18'h00c60;
    vrom[  96] = 18'h00c61;vrom[  97] = 18'h00c62;vrom[  98] = 18'h00c63;vrom[  99] = 18'h00c64;vrom[ 100] = 18'h00c65;vrom[ 101] = 18'h00c66;vrom[ 102] = 18'h00c67;vrom[ 103] = 18'h00c68;vrom[ 104] = 18'h00c69;vrom[ 105] = 18'h00c6a;vrom[ 106] = 18'h00c6b;vrom[ 107] = 18'h00c6c;vrom[ 108] = 18'h00c6d;vrom[ 109] = 18'h00c6e;vrom[ 110] = 18'h00c6f;vrom[ 111] = 18'h00c70;
    vrom[ 112] = 18'h00c71;vrom[ 113] = 18'h00c72;vrom[ 114] = 18'h00c73;vrom[ 115] = 18'h00c74;vrom[ 116] = 18'h00c75;vrom[ 117] = 18'h00c76;vrom[ 118] = 18'h00c77;vrom[ 119] = 18'h00c78;vrom[ 120] = 18'h00c79;vrom[ 121] = 18'h00c7a;vrom[ 122] = 18'h00c7b;vrom[ 123] = 18'h00c7c;vrom[ 124] = 18'h00c7d;vrom[ 125] = 18'h00c7e;vrom[ 126] = 18'h00c7f;vrom[ 127] = 18'h00c80;
    vrom[ 128] = 18'h00c81;vrom[ 129] = 18'h00c82;vrom[ 130] = 18'h00c83;vrom[ 131] = 18'h00c84;vrom[ 132] = 18'h00c85;vrom[ 133] = 18'h00c86;vrom[ 134] = 18'h00c87;vrom[ 135] = 18'h00c88;vrom[ 136] = 18'h00c89;vrom[ 137] = 18'h00c8a;vrom[ 138] = 18'h00c8b;vrom[ 139] = 18'h00c8c;vrom[ 140] = 18'h0108d;vrom[ 141] = 18'h0108e;vrom[ 142] = 18'h0108f;vrom[ 143] = 18'h01090;
    vrom[ 144] = 18'h01091;vrom[ 145] = 18'h01092;vrom[ 146] = 18'h01093;vrom[ 147] = 18'h01094;vrom[ 148] = 18'h01095;vrom[ 149] = 18'h01096;vrom[ 150] = 18'h01097;vrom[ 151] = 18'h01098;vrom[ 152] = 18'h01099;vrom[ 153] = 18'h0109a;vrom[ 154] = 18'h0109b;vrom[ 155] = 18'h0109c;vrom[ 156] = 18'h0109d;vrom[ 157] = 18'h0109e;vrom[ 158] = 18'h0109f;vrom[ 159] = 18'h010a0;
    vrom[ 160] = 18'h010a1;vrom[ 161] = 18'h010a2;vrom[ 162] = 18'h010a3;vrom[ 163] = 18'h010a4;vrom[ 164] = 18'h010a5;vrom[ 165] = 18'h010a6;vrom[ 166] = 18'h010a7;vrom[ 167] = 18'h010a8;vrom[ 168] = 18'h010a9;vrom[ 169] = 18'h010aa;vrom[ 170] = 18'h010ab;vrom[ 171] = 18'h010ac;vrom[ 172] = 18'h010ad;vrom[ 173] = 18'h010ae;vrom[ 174] = 18'h010af;vrom[ 175] = 18'h010b0;
    vrom[ 176] = 18'h010b1;vrom[ 177] = 18'h010b2;vrom[ 178] = 18'h010b3;vrom[ 179] = 18'h010b4;vrom[ 180] = 18'h010b5;vrom[ 181] = 18'h010b6;vrom[ 182] = 18'h014b7;vrom[ 183] = 18'h014b8;vrom[ 184] = 18'h014b9;vrom[ 185] = 18'h014ba;vrom[ 186] = 18'h014bb;vrom[ 187] = 18'h014bc;vrom[ 188] = 18'h014bd;vrom[ 189] = 18'h014be;vrom[ 190] = 18'h014bf;vrom[ 191] = 18'h014c0;
    vrom[ 192] = 18'h014c1;vrom[ 193] = 18'h014c2;vrom[ 194] = 18'h014c3;vrom[ 195] = 18'h014c4;vrom[ 196] = 18'h014c5;vrom[ 197] = 18'h014c6;vrom[ 198] = 18'h014c7;vrom[ 199] = 18'h014c8;vrom[ 200] = 18'h014c9;vrom[ 201] = 18'h014ca;vrom[ 202] = 18'h018cb;vrom[ 203] = 18'h018cc;vrom[ 204] = 18'h018cd;vrom[ 205] = 18'h018ce;vrom[ 206] = 18'h018cf;vrom[ 207] = 18'h018d0;
    vrom[ 208] = 18'h018d1;vrom[ 209] = 18'h018d2;vrom[ 210] = 18'h018d3;vrom[ 211] = 18'h018d4;vrom[ 212] = 18'h018d5;vrom[ 213] = 18'h018d6;vrom[ 214] = 18'h018d7;vrom[ 215] = 18'h018d8;vrom[ 216] = 18'h018d9;vrom[ 217] = 18'h018da;vrom[ 218] = 18'h018db;vrom[ 219] = 18'h018dc;vrom[ 220] = 18'h018dd;vrom[ 221] = 18'h018de;vrom[ 222] = 18'h018df;vrom[ 223] = 18'h018e0;
    vrom[ 224] = 18'h018e1;vrom[ 225] = 18'h018e2;vrom[ 226] = 18'h018e3;vrom[ 227] = 18'h018e4;vrom[ 228] = 18'h018e5;vrom[ 229] = 18'h018e6;vrom[ 230] = 18'h018e7;vrom[ 231] = 18'h018e8;vrom[ 232] = 18'h018e9;vrom[ 233] = 18'h018ea;vrom[ 234] = 18'h018eb;vrom[ 235] = 18'h018ec;vrom[ 236] = 18'h018ed;vrom[ 237] = 18'h018ee;vrom[ 238] = 18'h018ef;vrom[ 239] = 18'h018f0;
    vrom[ 240] = 18'h018f1;vrom[ 241] = 18'h018f2;vrom[ 242] = 18'h018f3;vrom[ 243] = 18'h018f4;vrom[ 244] = 18'h018f5;vrom[ 245] = 18'h018f6;vrom[ 246] = 18'h018f7;vrom[ 247] = 18'h018f8;vrom[ 248] = 18'h018f9;vrom[ 249] = 18'h018fa;vrom[ 250] = 18'h018fb;vrom[ 251] = 18'h018fc;vrom[ 252] = 18'h018fd;vrom[ 253] = 18'h018fe;vrom[ 254] = 18'h018ff;vrom[ 255] = 18'h01900;
    vrom[ 256] = 18'h01901;vrom[ 257] = 18'h01902;vrom[ 258] = 18'h01903;vrom[ 259] = 18'h01904;vrom[ 260] = 18'h01905;vrom[ 261] = 18'h01906;vrom[ 262] = 18'h01907;vrom[ 263] = 18'h11d08;vrom[ 264] = 18'h11d09;vrom[ 265] = 18'h3210a;vrom[ 266] = 18'h3210b;vrom[ 267] = 18'h3210c;vrom[ 268] = 18'h3210d;vrom[ 269] = 18'h3210e;vrom[ 270] = 18'h3210f;vrom[ 271] = 18'h32110;
    vrom[ 272] = 18'h32111;vrom[ 273] = 18'h32112;vrom[ 274] = 18'h32113;vrom[ 275] = 18'h32114;vrom[ 276] = 18'h32115;vrom[ 277] = 18'h32116;vrom[ 278] = 18'h32117;vrom[ 279] = 18'h32118;vrom[ 280] = 18'h32119;vrom[ 281] = 18'h3211a;vrom[ 282] = 18'h2251b;vrom[ 283] = 18'h2251c;vrom[ 284] = 18'h2251d;vrom[ 285] = 18'h2251e;vrom[ 286] = 18'h2251f;vrom[ 287] = 18'h22520;
    vrom[ 288] = 18'h22521;vrom[ 289] = 18'h22522;vrom[ 290] = 18'h22523;vrom[ 291] = 18'h22524;vrom[ 292] = 18'h22525;vrom[ 293] = 18'h22526;vrom[ 294] = 18'h22527;vrom[ 295] = 18'h22528;vrom[ 296] = 18'h22529;vrom[ 297] = 18'h2252a;vrom[ 298] = 18'h2252b;vrom[ 299] = 18'h2252c;vrom[ 300] = 18'h2252d;vrom[ 301] = 18'h2252e;vrom[ 302] = 18'h2252f;vrom[ 303] = 18'h22530;
    vrom[ 304] = 18'h22531;vrom[ 305] = 18'h22532;vrom[ 306] = 18'h22533;vrom[ 307] = 18'h22534;vrom[ 308] = 18'h22535;vrom[ 309] = 18'h22536;vrom[ 310] = 18'h22537;vrom[ 311] = 18'h22538;vrom[ 312] = 18'h22539;vrom[ 313] = 18'h2253a;vrom[ 314] = 18'h2253b;vrom[ 315] = 18'h2253c;vrom[ 316] = 18'h2253d;vrom[ 317] = 18'h2253e;vrom[ 318] = 18'h2253f;vrom[ 319] = 18'h22540;
    vrom[ 320] = 18'h22541;vrom[ 321] = 18'h22542;vrom[ 322] = 18'h22543;vrom[ 323] = 18'h22544;vrom[ 324] = 18'h22545;vrom[ 325] = 18'h22546;vrom[ 326] = 18'h22547;vrom[ 327] = 18'h22548;vrom[ 328] = 18'h22549;vrom[ 329] = 18'h2254a;vrom[ 330] = 18'h2254b;vrom[ 331] = 18'h2254c;vrom[ 332] = 18'h2254d;vrom[ 333] = 18'h2254e;vrom[ 334] = 18'h2254f;vrom[ 335] = 18'h22550;
    vrom[ 336] = 18'h22551;vrom[ 337] = 18'h22552;vrom[ 338] = 18'h22553;vrom[ 339] = 18'h22554;vrom[ 340] = 18'h22555;vrom[ 341] = 18'h22556;vrom[ 342] = 18'h22557;vrom[ 343] = 18'h22558;vrom[ 344] = 18'h22559;vrom[ 345] = 18'h2255a;vrom[ 346] = 18'h2255b;vrom[ 347] = 18'h2255c;vrom[ 348] = 18'h2255d;vrom[ 349] = 18'h2255e;vrom[ 350] = 18'h2255f;vrom[ 351] = 18'h22560;
    vrom[ 352] = 18'h22561;vrom[ 353] = 18'h22562;vrom[ 354] = 18'h22563;vrom[ 355] = 18'h22564;vrom[ 356] = 18'h22565;vrom[ 357] = 18'h22566;vrom[ 358] = 18'h22567;vrom[ 359] = 18'h22568;vrom[ 360] = 18'h22569;vrom[ 361] = 18'h2256a;vrom[ 362] = 18'h2256b;vrom[ 363] = 18'h2256c;vrom[ 364] = 18'h2256d;vrom[ 365] = 18'h2256e;vrom[ 366] = 18'h2256f;vrom[ 367] = 18'h22570;
    vrom[ 368] = 18'h22571;vrom[ 369] = 18'h22572;vrom[ 370] = 18'h22573;vrom[ 371] = 18'h22574;vrom[ 372] = 18'h22575;vrom[ 373] = 18'h22576;vrom[ 374] = 18'h22577;vrom[ 375] = 18'h22578;vrom[ 376] = 18'h22579;vrom[ 377] = 18'h2257a;vrom[ 378] = 18'h2257b;vrom[ 379] = 18'h2257c;vrom[ 380] = 18'h2257d;vrom[ 381] = 18'h2257e;vrom[ 382] = 18'h2257f;vrom[ 383] = 18'h22580;
    vrom[ 384] = 18'h22581;vrom[ 385] = 18'h22582;vrom[ 386] = 18'h22583;vrom[ 387] = 18'h22584;vrom[ 388] = 18'h22585;vrom[ 389] = 18'h22586;vrom[ 390] = 18'h22587;vrom[ 391] = 18'h22588;vrom[ 392] = 18'h22589;vrom[ 393] = 18'h2258a;vrom[ 394] = 18'h2258b;vrom[ 395] = 18'h2258c;vrom[ 396] = 18'h2258d;vrom[ 397] = 18'h2258e;vrom[ 398] = 18'h2258f;vrom[ 399] = 18'h22590;
    vrom[ 400] = 18'h22591;vrom[ 401] = 18'h22592;vrom[ 402] = 18'h22993;vrom[ 403] = 18'h22994;vrom[ 404] = 18'h22995;vrom[ 405] = 18'h22996;vrom[ 406] = 18'h22997;vrom[ 407] = 18'h22998;vrom[ 408] = 18'h22999;vrom[ 409] = 18'h2299a;vrom[ 410] = 18'h2299b;vrom[ 411] = 18'h2299c;vrom[ 412] = 18'h2299d;vrom[ 413] = 18'h2299e;vrom[ 414] = 18'h2299f;vrom[ 415] = 18'h229a0;
    vrom[ 416] = 18'h229a1;vrom[ 417] = 18'h229a2;vrom[ 418] = 18'h229a3;vrom[ 419] = 18'h229a4;vrom[ 420] = 18'h229a5;vrom[ 421] = 18'h229a6;vrom[ 422] = 18'h229a7;vrom[ 423] = 18'h229a8;vrom[ 424] = 18'h229a9;vrom[ 425] = 18'h229aa;vrom[ 426] = 18'h229ab;vrom[ 427] = 18'h229ac;vrom[ 428] = 18'h229ad;vrom[ 429] = 18'h229ae;vrom[ 430] = 18'h229af;vrom[ 431] = 18'h229b0;
    vrom[ 432] = 18'h229b1;vrom[ 433] = 18'h229b2;vrom[ 434] = 18'h229b3;vrom[ 435] = 18'h229b4;vrom[ 436] = 18'h229b5;vrom[ 437] = 18'h229b6;vrom[ 438] = 18'h229b7;vrom[ 439] = 18'h229b8;vrom[ 440] = 18'h229b9;vrom[ 441] = 18'h229ba;vrom[ 442] = 18'h229bb;vrom[ 443] = 18'h229bc;vrom[ 444] = 18'h229bd;vrom[ 445] = 18'h22dbe;vrom[ 446] = 18'h22dbf;vrom[ 447] = 18'h22dc0;
    vrom[ 448] = 18'h22dc1;vrom[ 449] = 18'h22dc2;vrom[ 450] = 18'h22dc3;vrom[ 451] = 18'h22dc4;vrom[ 452] = 18'h22dc5;vrom[ 453] = 18'h22dc6;vrom[ 454] = 18'h22dc7;vrom[ 455] = 18'h22dc8;vrom[ 456] = 18'h22dc9;vrom[ 457] = 18'h22dca;vrom[ 458] = 18'h22dcb;vrom[ 459] = 18'h22dcc;vrom[ 460] = 18'h22dcd;vrom[ 461] = 18'h22dce;vrom[ 462] = 18'h22dcf;vrom[ 463] = 18'h22dd0;
    vrom[ 464] = 18'h231d1;vrom[ 465] = 18'h231d2;vrom[ 466] = 18'h231d3;vrom[ 467] = 18'h231d4;vrom[ 468] = 18'h231d5;vrom[ 469] = 18'h231d6;vrom[ 470] = 18'h231d7;vrom[ 471] = 18'h231d8;vrom[ 472] = 18'h231d9;vrom[ 473] = 18'h231da;vrom[ 474] = 18'h231db;vrom[ 475] = 18'h231dc;vrom[ 476] = 18'h231dd;vrom[ 477] = 18'h231de;vrom[ 478] = 18'h231df;vrom[ 479] = 18'h231e0;
    vrom[ 480] = 18'h231e1;vrom[ 481] = 18'h231e2;vrom[ 482] = 18'h231e3;vrom[ 483] = 18'h231e4;vrom[ 484] = 18'h231e5;vrom[ 485] = 18'h231e6;vrom[ 486] = 18'h231e7;vrom[ 487] = 18'h231e8;vrom[ 488] = 18'h231e9;vrom[ 489] = 18'h231ea;vrom[ 490] = 18'h231eb;vrom[ 491] = 18'h231ec;vrom[ 492] = 18'h231ed;vrom[ 493] = 18'h231ee;vrom[ 494] = 18'h231ef;vrom[ 495] = 18'h231f0;
    vrom[ 496] = 18'h231f1;vrom[ 497] = 18'h231f2;vrom[ 498] = 18'h231f3;vrom[ 499] = 18'h231f4;vrom[ 500] = 18'h231f5;vrom[ 501] = 18'h231f6;vrom[ 502] = 18'h231f7;vrom[ 503] = 18'h231f8;vrom[ 504] = 18'h231f9;vrom[ 505] = 18'h231fa;vrom[ 506] = 18'h231fb;vrom[ 507] = 18'h231fc;vrom[ 508] = 18'h231fd;vrom[ 509] = 18'h231fe;vrom[ 510] = 18'h231ff;vrom[ 511] = 18'h23200;
    vrom[ 512] = 18'h23201;vrom[ 513] = 18'h23202;vrom[ 514] = 18'h23203;vrom[ 515] = 18'h23204;vrom[ 516] = 18'h23205;vrom[ 517] = 18'h23206;vrom[ 518] = 18'h23207;vrom[ 519] = 18'h23208;vrom[ 520] = 18'h23209;vrom[ 521] = 18'h2320a;vrom[ 522] = 18'h2320b;vrom[ 523] = 18'h2320c;vrom[ 524] = 18'h2320d;vrom[ 525] = 18'h30001;vrom[ 526] = 18'h2320d;vrom[ 527] = 18'h2320d;
    vrom[ 528] = 18'h2320d;vrom[ 529] = 18'h2320d;vrom[ 530] = 18'h2320d;vrom[ 531] = 18'h2320d;vrom[ 532] = 18'h2320d;vrom[ 533] = 18'h2320d;vrom[ 534] = 18'h2320d;vrom[ 535] = 18'h2320d;vrom[ 536] = 18'h2320d;vrom[ 537] = 18'h2320d;vrom[ 538] = 18'h2320d;vrom[ 539] = 18'h2320d;vrom[ 540] = 18'h2320d;vrom[ 541] = 18'h2320d;vrom[ 542] = 18'h2320d;vrom[ 543] = 18'h2320d;
    vrom[ 544] = 18'h2320d;vrom[ 545] = 18'h2320d;vrom[ 546] = 18'h2320d;vrom[ 547] = 18'h2320d;vrom[ 548] = 18'h2320d;vrom[ 549] = 18'h2320d;vrom[ 550] = 18'h2320d;vrom[ 551] = 18'h2320d;vrom[ 552] = 18'h2320d;vrom[ 553] = 18'h2320d;vrom[ 554] = 18'h2320d;vrom[ 555] = 18'h2320d;vrom[ 556] = 18'h2320d;vrom[ 557] = 18'h2320d;vrom[ 558] = 18'h2320d;vrom[ 559] = 18'h2320d;
    vrom[ 560] = 18'h2320d;vrom[ 561] = 18'h2320d;vrom[ 562] = 18'h2320d;vrom[ 563] = 18'h2320d;vrom[ 564] = 18'h2320d;vrom[ 565] = 18'h2320d;vrom[ 566] = 18'h2320d;vrom[ 567] = 18'h2320d;vrom[ 568] = 18'h2320d;vrom[ 569] = 18'h2320d;vrom[ 570] = 18'h2320d;vrom[ 571] = 18'h2320d;vrom[ 572] = 18'h2320d;vrom[ 573] = 18'h2320d;vrom[ 574] = 18'h2320d;vrom[ 575] = 18'h2320d;
    vrom[ 576] = 18'h2320d;vrom[ 577] = 18'h2320d;vrom[ 578] = 18'h2320d;vrom[ 579] = 18'h2320d;vrom[ 580] = 18'h2320d;vrom[ 581] = 18'h2320d;vrom[ 582] = 18'h2320d;vrom[ 583] = 18'h2320d;vrom[ 584] = 18'h2320d;vrom[ 585] = 18'h2320d;vrom[ 586] = 18'h2320d;vrom[ 587] = 18'h2320d;vrom[ 588] = 18'h2320d;vrom[ 589] = 18'h2320d;vrom[ 590] = 18'h2320d;vrom[ 591] = 18'h2320d;
    vrom[ 592] = 18'h2320d;vrom[ 593] = 18'h2320d;vrom[ 594] = 18'h2320d;vrom[ 595] = 18'h2320d;vrom[ 596] = 18'h2320d;vrom[ 597] = 18'h2320d;vrom[ 598] = 18'h2320d;vrom[ 599] = 18'h2320d;vrom[ 600] = 18'h2320d;vrom[ 601] = 18'h2320d;vrom[ 602] = 18'h2320d;vrom[ 603] = 18'h2320d;vrom[ 604] = 18'h2320d;vrom[ 605] = 18'h2320d;vrom[ 606] = 18'h2320d;vrom[ 607] = 18'h2320d;
    vrom[ 608] = 18'h2320d;vrom[ 609] = 18'h2320d;vrom[ 610] = 18'h2320d;vrom[ 611] = 18'h2320d;vrom[ 612] = 18'h2320d;vrom[ 613] = 18'h2320d;vrom[ 614] = 18'h2320d;vrom[ 615] = 18'h2320d;vrom[ 616] = 18'h2320d;vrom[ 617] = 18'h2320d;vrom[ 618] = 18'h2320d;vrom[ 619] = 18'h2320d;vrom[ 620] = 18'h2320d;vrom[ 621] = 18'h2320d;vrom[ 622] = 18'h2320d;vrom[ 623] = 18'h2320d;
    vrom[ 624] = 18'h2320d;vrom[ 625] = 18'h2320d;vrom[ 626] = 18'h2320d;vrom[ 627] = 18'h2320d;vrom[ 628] = 18'h2320d;vrom[ 629] = 18'h2320d;vrom[ 630] = 18'h2320d;vrom[ 631] = 18'h2320d;vrom[ 632] = 18'h2320d;vrom[ 633] = 18'h2320d;vrom[ 634] = 18'h2320d;vrom[ 635] = 18'h2320d;vrom[ 636] = 18'h2320d;vrom[ 637] = 18'h2320d;vrom[ 638] = 18'h2320d;vrom[ 639] = 18'h2320d;
    vrom[ 640] = 18'h2320d;vrom[ 641] = 18'h2320d;vrom[ 642] = 18'h2320d;vrom[ 643] = 18'h2320d;vrom[ 644] = 18'h2320d;vrom[ 645] = 18'h2320d;vrom[ 646] = 18'h2320d;vrom[ 647] = 18'h2320d;vrom[ 648] = 18'h2320d;vrom[ 649] = 18'h2320d;vrom[ 650] = 18'h2320d;vrom[ 651] = 18'h2320d;vrom[ 652] = 18'h2320d;vrom[ 653] = 18'h2320d;vrom[ 654] = 18'h2320d;vrom[ 655] = 18'h2320d;
    vrom[ 656] = 18'h2320d;vrom[ 657] = 18'h2320d;vrom[ 658] = 18'h2320d;vrom[ 659] = 18'h2320d;vrom[ 660] = 18'h2320d;vrom[ 661] = 18'h2320d;vrom[ 662] = 18'h2320d;vrom[ 663] = 18'h2320d;vrom[ 664] = 18'h2320d;vrom[ 665] = 18'h2320d;vrom[ 666] = 18'h2320d;vrom[ 667] = 18'h2320d;vrom[ 668] = 18'h2320d;vrom[ 669] = 18'h2320d;vrom[ 670] = 18'h2320d;vrom[ 671] = 18'h2320d;
    vrom[ 672] = 18'h2320d;vrom[ 673] = 18'h2320d;vrom[ 674] = 18'h2320d;vrom[ 675] = 18'h2320d;vrom[ 676] = 18'h2320d;vrom[ 677] = 18'h2320d;vrom[ 678] = 18'h2320d;vrom[ 679] = 18'h2320d;vrom[ 680] = 18'h2320d;vrom[ 681] = 18'h2320d;vrom[ 682] = 18'h2320d;vrom[ 683] = 18'h2320d;vrom[ 684] = 18'h2320d;vrom[ 685] = 18'h2320d;vrom[ 686] = 18'h2320d;vrom[ 687] = 18'h2320d;
    vrom[ 688] = 18'h2320d;vrom[ 689] = 18'h2320d;vrom[ 690] = 18'h2320d;vrom[ 691] = 18'h2320d;vrom[ 692] = 18'h2320d;vrom[ 693] = 18'h2320d;vrom[ 694] = 18'h2320d;vrom[ 695] = 18'h2320d;vrom[ 696] = 18'h2320d;vrom[ 697] = 18'h2320d;vrom[ 698] = 18'h2320d;vrom[ 699] = 18'h2320d;vrom[ 700] = 18'h2320d;vrom[ 701] = 18'h2320d;vrom[ 702] = 18'h2320d;vrom[ 703] = 18'h2320d;
    vrom[ 704] = 18'h2320d;vrom[ 705] = 18'h2320d;vrom[ 706] = 18'h2320d;vrom[ 707] = 18'h2320d;vrom[ 708] = 18'h2320d;vrom[ 709] = 18'h2320d;vrom[ 710] = 18'h2320d;vrom[ 711] = 18'h2320d;vrom[ 712] = 18'h2320d;vrom[ 713] = 18'h2320d;vrom[ 714] = 18'h2320d;vrom[ 715] = 18'h2320d;vrom[ 716] = 18'h2320d;vrom[ 717] = 18'h2320d;vrom[ 718] = 18'h2320d;vrom[ 719] = 18'h2320d;
    vrom[ 720] = 18'h2320d;vrom[ 721] = 18'h2320d;vrom[ 722] = 18'h2320d;vrom[ 723] = 18'h2320d;vrom[ 724] = 18'h2320d;vrom[ 725] = 18'h2320d;vrom[ 726] = 18'h2320d;vrom[ 727] = 18'h2320d;vrom[ 728] = 18'h2320d;vrom[ 729] = 18'h2320d;vrom[ 730] = 18'h2320d;vrom[ 731] = 18'h2320d;vrom[ 732] = 18'h2320d;vrom[ 733] = 18'h2320d;vrom[ 734] = 18'h2320d;vrom[ 735] = 18'h2320d;
    vrom[ 736] = 18'h2320d;vrom[ 737] = 18'h2320d;vrom[ 738] = 18'h2320d;vrom[ 739] = 18'h2320d;vrom[ 740] = 18'h2320d;vrom[ 741] = 18'h2320d;vrom[ 742] = 18'h2320d;vrom[ 743] = 18'h2320d;vrom[ 744] = 18'h2320d;vrom[ 745] = 18'h2320d;vrom[ 746] = 18'h2320d;vrom[ 747] = 18'h2320d;vrom[ 748] = 18'h2320d;vrom[ 749] = 18'h2320d;vrom[ 750] = 18'h2320d;vrom[ 751] = 18'h2320d;
    vrom[ 752] = 18'h2320d;vrom[ 753] = 18'h2320d;vrom[ 754] = 18'h2320d;vrom[ 755] = 18'h2320d;vrom[ 756] = 18'h2320d;vrom[ 757] = 18'h2320d;vrom[ 758] = 18'h2320d;vrom[ 759] = 18'h2320d;vrom[ 760] = 18'h2320d;vrom[ 761] = 18'h2320d;vrom[ 762] = 18'h2320d;vrom[ 763] = 18'h2320d;vrom[ 764] = 18'h2320d;vrom[ 765] = 18'h2320d;vrom[ 766] = 18'h2320d;vrom[ 767] = 18'h2320d;
    vrom[ 768] = 18'h2320d;vrom[ 769] = 18'h2320d;vrom[ 770] = 18'h2320d;vrom[ 771] = 18'h2320d;vrom[ 772] = 18'h2320d;vrom[ 773] = 18'h2320d;vrom[ 774] = 18'h2320d;vrom[ 775] = 18'h2320d;vrom[ 776] = 18'h2320d;vrom[ 777] = 18'h2320d;vrom[ 778] = 18'h2320d;vrom[ 779] = 18'h2320d;vrom[ 780] = 18'h2320d;vrom[ 781] = 18'h2320d;vrom[ 782] = 18'h2320d;vrom[ 783] = 18'h2320d;
    vrom[ 784] = 18'h2320d;vrom[ 785] = 18'h2320d;vrom[ 786] = 18'h2320d;vrom[ 787] = 18'h2320d;vrom[ 788] = 18'h2320d;vrom[ 789] = 18'h2320d;vrom[ 790] = 18'h2320d;vrom[ 791] = 18'h2320d;vrom[ 792] = 18'h2320d;vrom[ 793] = 18'h2320d;vrom[ 794] = 18'h2320d;vrom[ 795] = 18'h2320d;vrom[ 796] = 18'h2320d;vrom[ 797] = 18'h2320d;vrom[ 798] = 18'h2320d;vrom[ 799] = 18'h2320d;
    vrom[ 800] = 18'h2320d;vrom[ 801] = 18'h2320d;vrom[ 802] = 18'h2320d;vrom[ 803] = 18'h2320d;vrom[ 804] = 18'h2320d;vrom[ 805] = 18'h2320d;vrom[ 806] = 18'h2320d;vrom[ 807] = 18'h2320d;vrom[ 808] = 18'h2320d;vrom[ 809] = 18'h2320d;vrom[ 810] = 18'h2320d;vrom[ 811] = 18'h2320d;vrom[ 812] = 18'h2320d;vrom[ 813] = 18'h2320d;vrom[ 814] = 18'h2320d;vrom[ 815] = 18'h2320d;
    vrom[ 816] = 18'h2320d;vrom[ 817] = 18'h2320d;vrom[ 818] = 18'h2320d;vrom[ 819] = 18'h2320d;vrom[ 820] = 18'h2320d;vrom[ 821] = 18'h2320d;vrom[ 822] = 18'h2320d;vrom[ 823] = 18'h2320d;vrom[ 824] = 18'h2320d;vrom[ 825] = 18'h2320d;vrom[ 826] = 18'h2320d;vrom[ 827] = 18'h2320d;vrom[ 828] = 18'h2320d;vrom[ 829] = 18'h2320d;vrom[ 830] = 18'h2320d;vrom[ 831] = 18'h2320d;
    vrom[ 832] = 18'h2320d;vrom[ 833] = 18'h2320d;vrom[ 834] = 18'h2320d;vrom[ 835] = 18'h2320d;vrom[ 836] = 18'h2320d;vrom[ 837] = 18'h2320d;vrom[ 838] = 18'h2320d;vrom[ 839] = 18'h2320d;vrom[ 840] = 18'h2320d;vrom[ 841] = 18'h2320d;vrom[ 842] = 18'h2320d;vrom[ 843] = 18'h2320d;vrom[ 844] = 18'h2320d;vrom[ 845] = 18'h2320d;vrom[ 846] = 18'h2320d;vrom[ 847] = 18'h2320d;
    vrom[ 848] = 18'h2320d;vrom[ 849] = 18'h2320d;vrom[ 850] = 18'h2320d;vrom[ 851] = 18'h2320d;vrom[ 852] = 18'h2320d;vrom[ 853] = 18'h2320d;vrom[ 854] = 18'h2320d;vrom[ 855] = 18'h2320d;vrom[ 856] = 18'h2320d;vrom[ 857] = 18'h2320d;vrom[ 858] = 18'h2320d;vrom[ 859] = 18'h2320d;vrom[ 860] = 18'h2320d;vrom[ 861] = 18'h2320d;vrom[ 862] = 18'h2320d;vrom[ 863] = 18'h2320d;
    vrom[ 864] = 18'h2320d;vrom[ 865] = 18'h2320d;vrom[ 866] = 18'h2320d;vrom[ 867] = 18'h2320d;vrom[ 868] = 18'h2320d;vrom[ 869] = 18'h2320d;vrom[ 870] = 18'h2320d;vrom[ 871] = 18'h2320d;vrom[ 872] = 18'h2320d;vrom[ 873] = 18'h2320d;vrom[ 874] = 18'h2320d;vrom[ 875] = 18'h2320d;vrom[ 876] = 18'h2320d;vrom[ 877] = 18'h2320d;vrom[ 878] = 18'h2320d;vrom[ 879] = 18'h2320d;
    vrom[ 880] = 18'h2320d;vrom[ 881] = 18'h2320d;vrom[ 882] = 18'h2320d;vrom[ 883] = 18'h2320d;vrom[ 884] = 18'h2320d;vrom[ 885] = 18'h2320d;vrom[ 886] = 18'h2320d;vrom[ 887] = 18'h2320d;vrom[ 888] = 18'h2320d;vrom[ 889] = 18'h2320d;vrom[ 890] = 18'h2320d;vrom[ 891] = 18'h2320d;vrom[ 892] = 18'h2320d;vrom[ 893] = 18'h2320d;vrom[ 894] = 18'h2320d;vrom[ 895] = 18'h2320d;
    vrom[ 896] = 18'h2320d;vrom[ 897] = 18'h2320d;vrom[ 898] = 18'h2320d;vrom[ 899] = 18'h2320d;vrom[ 900] = 18'h2320d;vrom[ 901] = 18'h2320d;vrom[ 902] = 18'h2320d;vrom[ 903] = 18'h2320d;vrom[ 904] = 18'h2320d;vrom[ 905] = 18'h2320d;vrom[ 906] = 18'h2320d;vrom[ 907] = 18'h2320d;vrom[ 908] = 18'h2320d;vrom[ 909] = 18'h2320d;vrom[ 910] = 18'h2320d;vrom[ 911] = 18'h2320d;
    vrom[ 912] = 18'h2320d;vrom[ 913] = 18'h2320d;vrom[ 914] = 18'h2320d;vrom[ 915] = 18'h2320d;vrom[ 916] = 18'h2320d;vrom[ 917] = 18'h2320d;vrom[ 918] = 18'h2320d;vrom[ 919] = 18'h2320d;vrom[ 920] = 18'h2320d;vrom[ 921] = 18'h2320d;vrom[ 922] = 18'h2320d;vrom[ 923] = 18'h2320d;vrom[ 924] = 18'h2320d;vrom[ 925] = 18'h2320d;vrom[ 926] = 18'h2320d;vrom[ 927] = 18'h2320d;
    vrom[ 928] = 18'h2320d;vrom[ 929] = 18'h2320d;vrom[ 930] = 18'h2320d;vrom[ 931] = 18'h2320d;vrom[ 932] = 18'h2320d;vrom[ 933] = 18'h2320d;vrom[ 934] = 18'h2320d;vrom[ 935] = 18'h2320d;vrom[ 936] = 18'h2320d;vrom[ 937] = 18'h2320d;vrom[ 938] = 18'h2320d;vrom[ 939] = 18'h2320d;vrom[ 940] = 18'h2320d;vrom[ 941] = 18'h2320d;vrom[ 942] = 18'h2320d;vrom[ 943] = 18'h2320d;
    vrom[ 944] = 18'h2320d;vrom[ 945] = 18'h2320d;vrom[ 946] = 18'h2320d;vrom[ 947] = 18'h2320d;vrom[ 948] = 18'h2320d;vrom[ 949] = 18'h2320d;vrom[ 950] = 18'h2320d;vrom[ 951] = 18'h2320d;vrom[ 952] = 18'h2320d;vrom[ 953] = 18'h2320d;vrom[ 954] = 18'h2320d;vrom[ 955] = 18'h2320d;vrom[ 956] = 18'h2320d;vrom[ 957] = 18'h2320d;vrom[ 958] = 18'h2320d;vrom[ 959] = 18'h2320d;
    vrom[ 960] = 18'h2320d;vrom[ 961] = 18'h2320d;vrom[ 962] = 18'h2320d;vrom[ 963] = 18'h2320d;vrom[ 964] = 18'h2320d;vrom[ 965] = 18'h2320d;vrom[ 966] = 18'h2320d;vrom[ 967] = 18'h2320d;vrom[ 968] = 18'h2320d;vrom[ 969] = 18'h2320d;vrom[ 970] = 18'h2320d;vrom[ 971] = 18'h2320d;vrom[ 972] = 18'h2320d;vrom[ 973] = 18'h2320d;vrom[ 974] = 18'h2320d;vrom[ 975] = 18'h2320d;
    vrom[ 976] = 18'h2320d;vrom[ 977] = 18'h2320d;vrom[ 978] = 18'h2320d;vrom[ 979] = 18'h2320d;vrom[ 980] = 18'h2320d;vrom[ 981] = 18'h2320d;vrom[ 982] = 18'h2320d;vrom[ 983] = 18'h2320d;vrom[ 984] = 18'h2320d;vrom[ 985] = 18'h2320d;vrom[ 986] = 18'h2320d;vrom[ 987] = 18'h2320d;vrom[ 988] = 18'h2320d;vrom[ 989] = 18'h2320d;vrom[ 990] = 18'h2320d;vrom[ 991] = 18'h2320d;
    vrom[ 992] = 18'h2320d;vrom[ 993] = 18'h2320d;vrom[ 994] = 18'h2320d;vrom[ 995] = 18'h2320d;vrom[ 996] = 18'h2320d;vrom[ 997] = 18'h2320d;vrom[ 998] = 18'h2320d;vrom[ 999] = 18'h2320d;vrom[1000] = 18'h2320d;vrom[1001] = 18'h2320d;vrom[1002] = 18'h2320d;vrom[1003] = 18'h2320d;vrom[1004] = 18'h2320d;vrom[1005] = 18'h2320d;vrom[1006] = 18'h2320d;vrom[1007] = 18'h2320d;
    vrom[1008] = 18'h2320d;vrom[1009] = 18'h2320d;vrom[1010] = 18'h2320d;vrom[1011] = 18'h2320d;vrom[1012] = 18'h2320d;vrom[1013] = 18'h2320d;vrom[1014] = 18'h2320d;vrom[1015] = 18'h2320d;vrom[1016] = 18'h2320d;vrom[1017] = 18'h2320d;vrom[1018] = 18'h2320d;vrom[1019] = 18'h2320d;vrom[1020] = 18'h2320d;vrom[1021] = 18'h2320d;vrom[1022] = 18'h2320d;vrom[1023] = 18'h2320d;
end

always @ (posedge clk)
    if (rst)
        vrom_reg <= VROM_INIT;
    else if (ven)
        vrom_reg <= vrom[v_state];

// Assign the VROM output bits to the various signals
assign ven      = h_enable & ce & v_enable;
assign f        = vrom_reg[17];
assign v        = vrom_reg[16];
assign v_region = vrom_reg[VRGN_MSB + VSTATE_WIDTH:VSTATE_WIDTH];
assign v_state  = vrom_reg[VSTATE_MSB:0];

//
// Video component ROM
//
// The video component ROM generates the 9-bit video value. The LS bit out of
// this ROM is used as the two LS bits of the 10-bit video component value
// out of the module.
//
// The video component ROM's address is formed from the pattern input bit that
// selects between the two patterns stored in the ROM and the v_region and
// h_region values from the vertical and horizontal state machines. The last two
// address bits into the ROM come from a 2-bit sample counter.
//
initial begin
    crom[   0] = 9'h100;crom[   1] = 9'h020;crom[   2] = 9'h100;crom[   3] = 9'h020;crom[   4] = 9'h100;crom[   5] = 9'h020;crom[   6] = 9'h100;crom[   7] = 9'h020;crom[   8] = 9'h100;crom[   9] = 9'h020;crom[  10] = 9'h100;crom[  11] = 9'h020;crom[  12] = 9'h100;crom[  13] = 9'h020;crom[  14] = 9'h100;crom[  15] = 9'h020;
    crom[  16] = 9'h100;crom[  17] = 9'h020;crom[  18] = 9'h100;crom[  19] = 9'h020;crom[  20] = 9'h100;crom[  21] = 9'h020;crom[  22] = 9'h100;crom[  23] = 9'h020;crom[  24] = 9'h100;crom[  25] = 9'h020;crom[  26] = 9'h100;crom[  27] = 9'h020;crom[  28] = 9'h100;crom[  29] = 9'h020;crom[  30] = 9'h100;crom[  31] = 9'h020;
    crom[  32] = 9'h100;crom[  33] = 9'h020;crom[  34] = 9'h100;crom[  35] = 9'h020;crom[  36] = 9'h100;crom[  37] = 9'h020;crom[  38] = 9'h100;crom[  39] = 9'h020;crom[  40] = 9'h100;crom[  41] = 9'h020;crom[  42] = 9'h100;crom[  43] = 9'h020;crom[  44] = 9'h100;crom[  45] = 9'h020;crom[  46] = 9'h100;crom[  47] = 9'h020;
    crom[  48] = 9'h100;crom[  49] = 9'h020;crom[  50] = 9'h100;crom[  51] = 9'h020;crom[  52] = 9'h100;crom[  53] = 9'h020;crom[  54] = 9'h100;crom[  55] = 9'h020;crom[  56] = 9'h1ff;crom[  57] = 9'h000;crom[  58] = 9'h000;crom[  59] = 9'h1e2;crom[  60] = 9'h1ff;crom[  61] = 9'h000;crom[  62] = 9'h000;crom[  63] = 9'h1d8;
    crom[  64] = 9'h100;crom[  65] = 9'h020;crom[  66] = 9'h100;crom[  67] = 9'h020;crom[  68] = 9'h100;crom[  69] = 9'h020;crom[  70] = 9'h100;crom[  71] = 9'h020;crom[  72] = 9'h100;crom[  73] = 9'h020;crom[  74] = 9'h100;crom[  75] = 9'h020;crom[  76] = 9'h100;crom[  77] = 9'h020;crom[  78] = 9'h100;crom[  79] = 9'h020;
    crom[  80] = 9'h100;crom[  81] = 9'h020;crom[  82] = 9'h100;crom[  83] = 9'h020;crom[  84] = 9'h100;crom[  85] = 9'h020;crom[  86] = 9'h100;crom[  87] = 9'h020;crom[  88] = 9'h100;crom[  89] = 9'h020;crom[  90] = 9'h100;crom[  91] = 9'h020;crom[  92] = 9'h100;crom[  93] = 9'h020;crom[  94] = 9'h100;crom[  95] = 9'h020;
    crom[  96] = 9'h100;crom[  97] = 9'h020;crom[  98] = 9'h100;crom[  99] = 9'h020;crom[ 100] = 9'h100;crom[ 101] = 9'h020;crom[ 102] = 9'h100;crom[ 103] = 9'h020;crom[ 104] = 9'h100;crom[ 105] = 9'h020;crom[ 106] = 9'h100;crom[ 107] = 9'h020;crom[ 108] = 9'h100;crom[ 109] = 9'h020;crom[ 110] = 9'h100;crom[ 111] = 9'h020;
    crom[ 112] = 9'h100;crom[ 113] = 9'h020;crom[ 114] = 9'h100;crom[ 115] = 9'h020;crom[ 116] = 9'h100;crom[ 117] = 9'h020;crom[ 118] = 9'h100;crom[ 119] = 9'h020;crom[ 120] = 9'h1ff;crom[ 121] = 9'h000;crom[ 122] = 9'h000;crom[ 123] = 9'h16c;crom[ 124] = 9'h1ff;crom[ 125] = 9'h000;crom[ 126] = 9'h000;crom[ 127] = 9'h156;
    crom[ 128] = 9'h100;crom[ 129] = 9'h168;crom[ 130] = 9'h100;crom[ 131] = 9'h168;crom[ 132] = 9'h058;crom[ 133] = 9'h151;crom[ 134] = 9'h10f;crom[ 135] = 9'h151;crom[ 136] = 9'h058;crom[ 137] = 9'h151;crom[ 138] = 9'h10f;crom[ 139] = 9'h151;crom[ 140] = 9'h126;crom[ 141] = 9'h122;crom[ 142] = 9'h058;crom[ 143] = 9'h122;
    crom[ 144] = 9'h126;crom[ 145] = 9'h122;crom[ 146] = 9'h058;crom[ 147] = 9'h122;crom[ 148] = 9'h07e;crom[ 149] = 9'h10b;crom[ 150] = 9'h067;crom[ 151] = 9'h10b;crom[ 152] = 9'h07e;crom[ 153] = 9'h10b;crom[ 154] = 9'h067;crom[ 155] = 9'h10b;crom[ 156] = 9'h181;crom[ 157] = 9'h07d;crom[ 158] = 9'h198;crom[ 159] = 9'h07d;
    crom[ 160] = 9'h0d9;crom[ 161] = 9'h066;crom[ 162] = 9'h1a8;crom[ 163] = 9'h066;crom[ 164] = 9'h0d9;crom[ 165] = 9'h066;crom[ 166] = 9'h1a8;crom[ 167] = 9'h066;crom[ 168] = 9'h0d9;crom[ 169] = 9'h066;crom[ 170] = 9'h1a8;crom[ 171] = 9'h066;crom[ 172] = 9'h1a8;crom[ 173] = 9'h037;crom[ 174] = 9'h0f0;crom[ 175] = 9'h037;
    crom[ 176] = 9'h1a8;crom[ 177] = 9'h037;crom[ 178] = 9'h0f0;crom[ 179] = 9'h037;crom[ 180] = 9'h100;crom[ 181] = 9'h020;crom[ 182] = 9'h100;crom[ 183] = 9'h020;crom[ 184] = 9'h1ff;crom[ 185] = 9'h000;crom[ 186] = 9'h000;crom[ 187] = 9'h13a;crom[ 188] = 9'h1ff;crom[ 189] = 9'h000;crom[ 190] = 9'h000;crom[ 191] = 9'h100;
    crom[ 192] = 9'h100;crom[ 193] = 9'h168;crom[ 194] = 9'h100;crom[ 195] = 9'h168;crom[ 196] = 9'h058;crom[ 197] = 9'h151;crom[ 198] = 9'h10f;crom[ 199] = 9'h151;crom[ 200] = 9'h058;crom[ 201] = 9'h151;crom[ 202] = 9'h10f;crom[ 203] = 9'h151;crom[ 204] = 9'h126;crom[ 205] = 9'h122;crom[ 206] = 9'h058;crom[ 207] = 9'h122;
    crom[ 208] = 9'h126;crom[ 209] = 9'h122;crom[ 210] = 9'h058;crom[ 211] = 9'h122;crom[ 212] = 9'h07e;crom[ 213] = 9'h10b;crom[ 214] = 9'h067;crom[ 215] = 9'h10b;crom[ 216] = 9'h07e;crom[ 217] = 9'h10b;crom[ 218] = 9'h067;crom[ 219] = 9'h10b;crom[ 220] = 9'h181;crom[ 221] = 9'h07d;crom[ 222] = 9'h198;crom[ 223] = 9'h07d;
    crom[ 224] = 9'h0d9;crom[ 225] = 9'h066;crom[ 226] = 9'h1a8;crom[ 227] = 9'h066;crom[ 228] = 9'h0d9;crom[ 229] = 9'h066;crom[ 230] = 9'h1a8;crom[ 231] = 9'h066;crom[ 232] = 9'h0d9;crom[ 233] = 9'h066;crom[ 234] = 9'h1a8;crom[ 235] = 9'h066;crom[ 236] = 9'h1a8;crom[ 237] = 9'h037;crom[ 238] = 9'h0f0;crom[ 239] = 9'h037;
    crom[ 240] = 9'h1a8;crom[ 241] = 9'h037;crom[ 242] = 9'h0f0;crom[ 243] = 9'h037;crom[ 244] = 9'h100;crom[ 245] = 9'h020;crom[ 246] = 9'h100;crom[ 247] = 9'h020;crom[ 248] = 9'h1ff;crom[ 249] = 9'h000;crom[ 250] = 9'h000;crom[ 251] = 9'h13a;crom[ 252] = 9'h1ff;crom[ 253] = 9'h000;crom[ 254] = 9'h000;crom[ 255] = 9'h100;
    crom[ 256] = 9'h100;crom[ 257] = 9'h168;crom[ 258] = 9'h100;crom[ 259] = 9'h168;crom[ 260] = 9'h058;crom[ 261] = 9'h151;crom[ 262] = 9'h10f;crom[ 263] = 9'h151;crom[ 264] = 9'h058;crom[ 265] = 9'h151;crom[ 266] = 9'h10f;crom[ 267] = 9'h151;crom[ 268] = 9'h126;crom[ 269] = 9'h122;crom[ 270] = 9'h058;crom[ 271] = 9'h122;
    crom[ 272] = 9'h126;crom[ 273] = 9'h122;crom[ 274] = 9'h058;crom[ 275] = 9'h122;crom[ 276] = 9'h07e;crom[ 277] = 9'h10b;crom[ 278] = 9'h067;crom[ 279] = 9'h10b;crom[ 280] = 9'h07e;crom[ 281] = 9'h10b;crom[ 282] = 9'h067;crom[ 283] = 9'h10b;crom[ 284] = 9'h181;crom[ 285] = 9'h07d;crom[ 286] = 9'h198;crom[ 287] = 9'h07d;
    crom[ 288] = 9'h0d9;crom[ 289] = 9'h066;crom[ 290] = 9'h1a8;crom[ 291] = 9'h066;crom[ 292] = 9'h0d9;crom[ 293] = 9'h066;crom[ 294] = 9'h1a8;crom[ 295] = 9'h066;crom[ 296] = 9'h0d9;crom[ 297] = 9'h066;crom[ 298] = 9'h1a8;crom[ 299] = 9'h066;crom[ 300] = 9'h1a8;crom[ 301] = 9'h037;crom[ 302] = 9'h0f0;crom[ 303] = 9'h037;
    crom[ 304] = 9'h1a8;crom[ 305] = 9'h037;crom[ 306] = 9'h0f0;crom[ 307] = 9'h037;crom[ 308] = 9'h100;crom[ 309] = 9'h020;crom[ 310] = 9'h100;crom[ 311] = 9'h020;crom[ 312] = 9'h1ff;crom[ 313] = 9'h000;crom[ 314] = 9'h000;crom[ 315] = 9'h13a;crom[ 316] = 9'h1ff;crom[ 317] = 9'h000;crom[ 318] = 9'h000;crom[ 319] = 9'h100;
    crom[ 320] = 9'h1a8;crom[ 321] = 9'h037;crom[ 322] = 9'h0f0;crom[ 323] = 9'h037;crom[ 324] = 9'h100;crom[ 325] = 9'h020;crom[ 326] = 9'h100;crom[ 327] = 9'h020;crom[ 328] = 9'h100;crom[ 329] = 9'h020;crom[ 330] = 9'h100;crom[ 331] = 9'h020;crom[ 332] = 9'h181;crom[ 333] = 9'h07d;crom[ 334] = 9'h198;crom[ 335] = 9'h07d;
    crom[ 336] = 9'h181;crom[ 337] = 9'h07d;crom[ 338] = 9'h198;crom[ 339] = 9'h07d;crom[ 340] = 9'h100;crom[ 341] = 9'h020;crom[ 342] = 9'h100;crom[ 343] = 9'h020;crom[ 344] = 9'h100;crom[ 345] = 9'h020;crom[ 346] = 9'h100;crom[ 347] = 9'h020;crom[ 348] = 9'h126;crom[ 349] = 9'h122;crom[ 350] = 9'h058;crom[ 351] = 9'h122;
    crom[ 352] = 9'h100;crom[ 353] = 9'h020;crom[ 354] = 9'h100;crom[ 355] = 9'h020;crom[ 356] = 9'h100;crom[ 357] = 9'h020;crom[ 358] = 9'h100;crom[ 359] = 9'h020;crom[ 360] = 9'h100;crom[ 361] = 9'h020;crom[ 362] = 9'h100;crom[ 363] = 9'h020;crom[ 364] = 9'h100;crom[ 365] = 9'h168;crom[ 366] = 9'h100;crom[ 367] = 9'h168;
    crom[ 368] = 9'h100;crom[ 369] = 9'h168;crom[ 370] = 9'h100;crom[ 371] = 9'h168;crom[ 372] = 9'h100;crom[ 373] = 9'h020;crom[ 374] = 9'h100;crom[ 375] = 9'h020;crom[ 376] = 9'h1ff;crom[ 377] = 9'h000;crom[ 378] = 9'h000;crom[ 379] = 9'h13a;crom[ 380] = 9'h1ff;crom[ 381] = 9'h000;crom[ 382] = 9'h000;crom[ 383] = 9'h100;
    crom[ 384] = 9'h132;crom[ 385] = 9'h07a;crom[ 386] = 9'h0c5;crom[ 387] = 9'h07a;crom[ 388] = 9'h132;crom[ 389] = 9'h07a;crom[ 390] = 9'h0c5;crom[ 391] = 9'h07a;crom[ 392] = 9'h100;crom[ 393] = 9'h1d6;crom[ 394] = 9'h100;crom[ 395] = 9'h1d6;crom[ 396] = 9'h100;crom[ 397] = 9'h1d6;crom[ 398] = 9'h100;crom[ 399] = 9'h1d6;
    crom[ 400] = 9'h15c;crom[ 401] = 9'h046;crom[ 402] = 9'h12f;crom[ 403] = 9'h046;crom[ 404] = 9'h15c;crom[ 405] = 9'h046;crom[ 406] = 9'h12f;crom[ 407] = 9'h046;crom[ 408] = 9'h100;crom[ 409] = 9'h020;crom[ 410] = 9'h100;crom[ 411] = 9'h020;crom[ 412] = 9'h100;crom[ 413] = 9'h020;crom[ 414] = 9'h100;crom[ 415] = 9'h020;
    crom[ 416] = 9'h100;crom[ 417] = 9'h00e;crom[ 418] = 9'h100;crom[ 419] = 9'h00e;crom[ 420] = 9'h100;crom[ 421] = 9'h020;crom[ 422] = 9'h100;crom[ 423] = 9'h020;crom[ 424] = 9'h100;crom[ 425] = 9'h031;crom[ 426] = 9'h100;crom[ 427] = 9'h031;crom[ 428] = 9'h100;crom[ 429] = 9'h020;crom[ 430] = 9'h100;crom[ 431] = 9'h020;
    crom[ 432] = 9'h100;crom[ 433] = 9'h020;crom[ 434] = 9'h100;crom[ 435] = 9'h020;crom[ 436] = 9'h100;crom[ 437] = 9'h020;crom[ 438] = 9'h100;crom[ 439] = 9'h020;crom[ 440] = 9'h1ff;crom[ 441] = 9'h000;crom[ 442] = 9'h000;crom[ 443] = 9'h13a;crom[ 444] = 9'h1ff;crom[ 445] = 9'h000;crom[ 446] = 9'h000;crom[ 447] = 9'h100;
    crom[ 448] = 9'h100;crom[ 449] = 9'h020;crom[ 450] = 9'h100;crom[ 451] = 9'h020;crom[ 452] = 9'h100;crom[ 453] = 9'h020;crom[ 454] = 9'h100;crom[ 455] = 9'h020;crom[ 456] = 9'h100;crom[ 457] = 9'h020;crom[ 458] = 9'h100;crom[ 459] = 9'h020;crom[ 460] = 9'h100;crom[ 461] = 9'h020;crom[ 462] = 9'h100;crom[ 463] = 9'h020;
    crom[ 464] = 9'h100;crom[ 465] = 9'h020;crom[ 466] = 9'h100;crom[ 467] = 9'h020;crom[ 468] = 9'h100;crom[ 469] = 9'h020;crom[ 470] = 9'h100;crom[ 471] = 9'h020;crom[ 472] = 9'h100;crom[ 473] = 9'h020;crom[ 474] = 9'h100;crom[ 475] = 9'h020;crom[ 476] = 9'h100;crom[ 477] = 9'h020;crom[ 478] = 9'h100;crom[ 479] = 9'h020;
    crom[ 480] = 9'h100;crom[ 481] = 9'h020;crom[ 482] = 9'h100;crom[ 483] = 9'h020;crom[ 484] = 9'h100;crom[ 485] = 9'h020;crom[ 486] = 9'h100;crom[ 487] = 9'h020;crom[ 488] = 9'h100;crom[ 489] = 9'h020;crom[ 490] = 9'h100;crom[ 491] = 9'h020;crom[ 492] = 9'h100;crom[ 493] = 9'h020;crom[ 494] = 9'h100;crom[ 495] = 9'h020;
    crom[ 496] = 9'h100;crom[ 497] = 9'h020;crom[ 498] = 9'h100;crom[ 499] = 9'h020;crom[ 500] = 9'h100;crom[ 501] = 9'h020;crom[ 502] = 9'h100;crom[ 503] = 9'h020;crom[ 504] = 9'h1ff;crom[ 505] = 9'h000;crom[ 506] = 9'h000;crom[ 507] = 9'h16c;crom[ 508] = 9'h1ff;crom[ 509] = 9'h000;crom[ 510] = 9'h000;crom[ 511] = 9'h156;
    crom[ 512] = 9'h100;crom[ 513] = 9'h020;crom[ 514] = 9'h100;crom[ 515] = 9'h020;crom[ 516] = 9'h100;crom[ 517] = 9'h020;crom[ 518] = 9'h100;crom[ 519] = 9'h020;crom[ 520] = 9'h100;crom[ 521] = 9'h020;crom[ 522] = 9'h100;crom[ 523] = 9'h020;crom[ 524] = 9'h100;crom[ 525] = 9'h020;crom[ 526] = 9'h100;crom[ 527] = 9'h020;
    crom[ 528] = 9'h100;crom[ 529] = 9'h020;crom[ 530] = 9'h100;crom[ 531] = 9'h020;crom[ 532] = 9'h100;crom[ 533] = 9'h020;crom[ 534] = 9'h100;crom[ 535] = 9'h020;crom[ 536] = 9'h100;crom[ 537] = 9'h020;crom[ 538] = 9'h100;crom[ 539] = 9'h020;crom[ 540] = 9'h100;crom[ 541] = 9'h020;crom[ 542] = 9'h100;crom[ 543] = 9'h020;
    crom[ 544] = 9'h100;crom[ 545] = 9'h020;crom[ 546] = 9'h100;crom[ 547] = 9'h020;crom[ 548] = 9'h100;crom[ 549] = 9'h020;crom[ 550] = 9'h100;crom[ 551] = 9'h020;crom[ 552] = 9'h100;crom[ 553] = 9'h020;crom[ 554] = 9'h100;crom[ 555] = 9'h020;crom[ 556] = 9'h100;crom[ 557] = 9'h020;crom[ 558] = 9'h100;crom[ 559] = 9'h020;
    crom[ 560] = 9'h100;crom[ 561] = 9'h020;crom[ 562] = 9'h100;crom[ 563] = 9'h020;crom[ 564] = 9'h100;crom[ 565] = 9'h020;crom[ 566] = 9'h100;crom[ 567] = 9'h020;crom[ 568] = 9'h1ff;crom[ 569] = 9'h000;crom[ 570] = 9'h000;crom[ 571] = 9'h1e2;crom[ 572] = 9'h1ff;crom[ 573] = 9'h000;crom[ 574] = 9'h000;crom[ 575] = 9'h1d8;
    crom[ 576] = 9'h100;crom[ 577] = 9'h168;crom[ 578] = 9'h100;crom[ 579] = 9'h168;crom[ 580] = 9'h058;crom[ 581] = 9'h151;crom[ 582] = 9'h10f;crom[ 583] = 9'h151;crom[ 584] = 9'h058;crom[ 585] = 9'h151;crom[ 586] = 9'h10f;crom[ 587] = 9'h151;crom[ 588] = 9'h126;crom[ 589] = 9'h122;crom[ 590] = 9'h058;crom[ 591] = 9'h122;
    crom[ 592] = 9'h126;crom[ 593] = 9'h122;crom[ 594] = 9'h058;crom[ 595] = 9'h122;crom[ 596] = 9'h07e;crom[ 597] = 9'h10b;crom[ 598] = 9'h067;crom[ 599] = 9'h10b;crom[ 600] = 9'h07e;crom[ 601] = 9'h10b;crom[ 602] = 9'h067;crom[ 603] = 9'h10b;crom[ 604] = 9'h181;crom[ 605] = 9'h07d;crom[ 606] = 9'h198;crom[ 607] = 9'h07d;
    crom[ 608] = 9'h0d9;crom[ 609] = 9'h066;crom[ 610] = 9'h1a8;crom[ 611] = 9'h066;crom[ 612] = 9'h0d9;crom[ 613] = 9'h066;crom[ 614] = 9'h1a8;crom[ 615] = 9'h066;crom[ 616] = 9'h0d9;crom[ 617] = 9'h066;crom[ 618] = 9'h1a8;crom[ 619] = 9'h066;crom[ 620] = 9'h1a8;crom[ 621] = 9'h037;crom[ 622] = 9'h0f0;crom[ 623] = 9'h037;
    crom[ 624] = 9'h1a8;crom[ 625] = 9'h037;crom[ 626] = 9'h0f0;crom[ 627] = 9'h037;crom[ 628] = 9'h100;crom[ 629] = 9'h020;crom[ 630] = 9'h100;crom[ 631] = 9'h020;crom[ 632] = 9'h1ff;crom[ 633] = 9'h000;crom[ 634] = 9'h000;crom[ 635] = 9'h1b4;crom[ 636] = 9'h1ff;crom[ 637] = 9'h000;crom[ 638] = 9'h000;crom[ 639] = 9'h18e;
    crom[ 640] = 9'h100;crom[ 641] = 9'h168;crom[ 642] = 9'h100;crom[ 643] = 9'h168;crom[ 644] = 9'h058;crom[ 645] = 9'h151;crom[ 646] = 9'h10f;crom[ 647] = 9'h151;crom[ 648] = 9'h058;crom[ 649] = 9'h151;crom[ 650] = 9'h10f;crom[ 651] = 9'h151;crom[ 652] = 9'h126;crom[ 653] = 9'h122;crom[ 654] = 9'h058;crom[ 655] = 9'h122;
    crom[ 656] = 9'h126;crom[ 657] = 9'h122;crom[ 658] = 9'h058;crom[ 659] = 9'h122;crom[ 660] = 9'h07e;crom[ 661] = 9'h10b;crom[ 662] = 9'h067;crom[ 663] = 9'h10b;crom[ 664] = 9'h07e;crom[ 665] = 9'h10b;crom[ 666] = 9'h067;crom[ 667] = 9'h10b;crom[ 668] = 9'h181;crom[ 669] = 9'h07d;crom[ 670] = 9'h198;crom[ 671] = 9'h07d;
    crom[ 672] = 9'h0d9;crom[ 673] = 9'h066;crom[ 674] = 9'h1a8;crom[ 675] = 9'h066;crom[ 676] = 9'h0d9;crom[ 677] = 9'h066;crom[ 678] = 9'h1a8;crom[ 679] = 9'h066;crom[ 680] = 9'h0d9;crom[ 681] = 9'h066;crom[ 682] = 9'h1a8;crom[ 683] = 9'h066;crom[ 684] = 9'h1a8;crom[ 685] = 9'h037;crom[ 686] = 9'h0f0;crom[ 687] = 9'h037;
    crom[ 688] = 9'h1a8;crom[ 689] = 9'h037;crom[ 690] = 9'h0f0;crom[ 691] = 9'h037;crom[ 692] = 9'h100;crom[ 693] = 9'h020;crom[ 694] = 9'h100;crom[ 695] = 9'h020;crom[ 696] = 9'h1ff;crom[ 697] = 9'h000;crom[ 698] = 9'h000;crom[ 699] = 9'h1b4;crom[ 700] = 9'h1ff;crom[ 701] = 9'h000;crom[ 702] = 9'h000;crom[ 703] = 9'h18e;
    crom[ 704] = 9'h1a8;crom[ 705] = 9'h037;crom[ 706] = 9'h0f0;crom[ 707] = 9'h037;crom[ 708] = 9'h100;crom[ 709] = 9'h020;crom[ 710] = 9'h100;crom[ 711] = 9'h020;crom[ 712] = 9'h100;crom[ 713] = 9'h020;crom[ 714] = 9'h100;crom[ 715] = 9'h020;crom[ 716] = 9'h181;crom[ 717] = 9'h07d;crom[ 718] = 9'h198;crom[ 719] = 9'h07d;
    crom[ 720] = 9'h181;crom[ 721] = 9'h07d;crom[ 722] = 9'h198;crom[ 723] = 9'h07d;crom[ 724] = 9'h100;crom[ 725] = 9'h020;crom[ 726] = 9'h100;crom[ 727] = 9'h020;crom[ 728] = 9'h100;crom[ 729] = 9'h020;crom[ 730] = 9'h100;crom[ 731] = 9'h020;crom[ 732] = 9'h126;crom[ 733] = 9'h122;crom[ 734] = 9'h058;crom[ 735] = 9'h122;
    crom[ 736] = 9'h100;crom[ 737] = 9'h020;crom[ 738] = 9'h100;crom[ 739] = 9'h020;crom[ 740] = 9'h100;crom[ 741] = 9'h020;crom[ 742] = 9'h100;crom[ 743] = 9'h020;crom[ 744] = 9'h100;crom[ 745] = 9'h020;crom[ 746] = 9'h100;crom[ 747] = 9'h020;crom[ 748] = 9'h100;crom[ 749] = 9'h168;crom[ 750] = 9'h100;crom[ 751] = 9'h168;
    crom[ 752] = 9'h100;crom[ 753] = 9'h168;crom[ 754] = 9'h100;crom[ 755] = 9'h168;crom[ 756] = 9'h100;crom[ 757] = 9'h020;crom[ 758] = 9'h100;crom[ 759] = 9'h020;crom[ 760] = 9'h1ff;crom[ 761] = 9'h000;crom[ 762] = 9'h000;crom[ 763] = 9'h1b4;crom[ 764] = 9'h1ff;crom[ 765] = 9'h000;crom[ 766] = 9'h000;crom[ 767] = 9'h18e;
    crom[ 768] = 9'h132;crom[ 769] = 9'h07a;crom[ 770] = 9'h0c5;crom[ 771] = 9'h07a;crom[ 772] = 9'h132;crom[ 773] = 9'h07a;crom[ 774] = 9'h0c5;crom[ 775] = 9'h07a;crom[ 776] = 9'h100;crom[ 777] = 9'h1d6;crom[ 778] = 9'h100;crom[ 779] = 9'h1d6;crom[ 780] = 9'h100;crom[ 781] = 9'h1d6;crom[ 782] = 9'h100;crom[ 783] = 9'h1d6;
    crom[ 784] = 9'h15c;crom[ 785] = 9'h046;crom[ 786] = 9'h12f;crom[ 787] = 9'h046;crom[ 788] = 9'h15c;crom[ 789] = 9'h046;crom[ 790] = 9'h12f;crom[ 791] = 9'h046;crom[ 792] = 9'h100;crom[ 793] = 9'h020;crom[ 794] = 9'h100;crom[ 795] = 9'h020;crom[ 796] = 9'h100;crom[ 797] = 9'h020;crom[ 798] = 9'h100;crom[ 799] = 9'h020;
    crom[ 800] = 9'h100;crom[ 801] = 9'h00e;crom[ 802] = 9'h100;crom[ 803] = 9'h00e;crom[ 804] = 9'h100;crom[ 805] = 9'h020;crom[ 806] = 9'h100;crom[ 807] = 9'h020;crom[ 808] = 9'h100;crom[ 809] = 9'h031;crom[ 810] = 9'h100;crom[ 811] = 9'h031;crom[ 812] = 9'h100;crom[ 813] = 9'h020;crom[ 814] = 9'h100;crom[ 815] = 9'h020;
    crom[ 816] = 9'h100;crom[ 817] = 9'h020;crom[ 818] = 9'h100;crom[ 819] = 9'h020;crom[ 820] = 9'h100;crom[ 821] = 9'h020;crom[ 822] = 9'h100;crom[ 823] = 9'h020;crom[ 824] = 9'h1ff;crom[ 825] = 9'h000;crom[ 826] = 9'h000;crom[ 827] = 9'h1b4;crom[ 828] = 9'h1ff;crom[ 829] = 9'h000;crom[ 830] = 9'h000;crom[ 831] = 9'h18e;
    crom[ 832] = 9'h000;crom[ 833] = 9'h000;crom[ 834] = 9'h000;crom[ 835] = 9'h000;crom[ 836] = 9'h000;crom[ 837] = 9'h000;crom[ 838] = 9'h000;crom[ 839] = 9'h000;crom[ 840] = 9'h000;crom[ 841] = 9'h000;crom[ 842] = 9'h000;crom[ 843] = 9'h000;crom[ 844] = 9'h000;crom[ 845] = 9'h000;crom[ 846] = 9'h000;crom[ 847] = 9'h000;
    crom[ 848] = 9'h000;crom[ 849] = 9'h000;crom[ 850] = 9'h000;crom[ 851] = 9'h000;crom[ 852] = 9'h000;crom[ 853] = 9'h000;crom[ 854] = 9'h000;crom[ 855] = 9'h000;crom[ 856] = 9'h000;crom[ 857] = 9'h000;crom[ 858] = 9'h000;crom[ 859] = 9'h000;crom[ 860] = 9'h000;crom[ 861] = 9'h000;crom[ 862] = 9'h000;crom[ 863] = 9'h000;
    crom[ 864] = 9'h000;crom[ 865] = 9'h000;crom[ 866] = 9'h000;crom[ 867] = 9'h000;crom[ 868] = 9'h000;crom[ 869] = 9'h000;crom[ 870] = 9'h000;crom[ 871] = 9'h000;crom[ 872] = 9'h000;crom[ 873] = 9'h000;crom[ 874] = 9'h000;crom[ 875] = 9'h000;crom[ 876] = 9'h000;crom[ 877] = 9'h000;crom[ 878] = 9'h000;crom[ 879] = 9'h000;
    crom[ 880] = 9'h000;crom[ 881] = 9'h000;crom[ 882] = 9'h000;crom[ 883] = 9'h000;crom[ 884] = 9'h000;crom[ 885] = 9'h000;crom[ 886] = 9'h000;crom[ 887] = 9'h000;crom[ 888] = 9'h000;crom[ 889] = 9'h000;crom[ 890] = 9'h000;crom[ 891] = 9'h000;crom[ 892] = 9'h000;crom[ 893] = 9'h000;crom[ 894] = 9'h000;crom[ 895] = 9'h000;
    crom[ 896] = 9'h000;crom[ 897] = 9'h000;crom[ 898] = 9'h000;crom[ 899] = 9'h000;crom[ 900] = 9'h000;crom[ 901] = 9'h000;crom[ 902] = 9'h000;crom[ 903] = 9'h000;crom[ 904] = 9'h000;crom[ 905] = 9'h000;crom[ 906] = 9'h000;crom[ 907] = 9'h000;crom[ 908] = 9'h000;crom[ 909] = 9'h000;crom[ 910] = 9'h000;crom[ 911] = 9'h000;
    crom[ 912] = 9'h000;crom[ 913] = 9'h000;crom[ 914] = 9'h000;crom[ 915] = 9'h000;crom[ 916] = 9'h000;crom[ 917] = 9'h000;crom[ 918] = 9'h000;crom[ 919] = 9'h000;crom[ 920] = 9'h000;crom[ 921] = 9'h000;crom[ 922] = 9'h000;crom[ 923] = 9'h000;crom[ 924] = 9'h000;crom[ 925] = 9'h000;crom[ 926] = 9'h000;crom[ 927] = 9'h000;
    crom[ 928] = 9'h000;crom[ 929] = 9'h000;crom[ 930] = 9'h000;crom[ 931] = 9'h000;crom[ 932] = 9'h000;crom[ 933] = 9'h000;crom[ 934] = 9'h000;crom[ 935] = 9'h000;crom[ 936] = 9'h000;crom[ 937] = 9'h000;crom[ 938] = 9'h000;crom[ 939] = 9'h000;crom[ 940] = 9'h000;crom[ 941] = 9'h000;crom[ 942] = 9'h000;crom[ 943] = 9'h000;
    crom[ 944] = 9'h000;crom[ 945] = 9'h000;crom[ 946] = 9'h000;crom[ 947] = 9'h000;crom[ 948] = 9'h000;crom[ 949] = 9'h000;crom[ 950] = 9'h000;crom[ 951] = 9'h000;crom[ 952] = 9'h000;crom[ 953] = 9'h000;crom[ 954] = 9'h000;crom[ 955] = 9'h000;crom[ 956] = 9'h000;crom[ 957] = 9'h000;crom[ 958] = 9'h000;crom[ 959] = 9'h000;
    crom[ 960] = 9'h000;crom[ 961] = 9'h000;crom[ 962] = 9'h000;crom[ 963] = 9'h000;crom[ 964] = 9'h000;crom[ 965] = 9'h000;crom[ 966] = 9'h000;crom[ 967] = 9'h000;crom[ 968] = 9'h000;crom[ 969] = 9'h000;crom[ 970] = 9'h000;crom[ 971] = 9'h000;crom[ 972] = 9'h000;crom[ 973] = 9'h000;crom[ 974] = 9'h000;crom[ 975] = 9'h000;
    crom[ 976] = 9'h000;crom[ 977] = 9'h000;crom[ 978] = 9'h000;crom[ 979] = 9'h000;crom[ 980] = 9'h000;crom[ 981] = 9'h000;crom[ 982] = 9'h000;crom[ 983] = 9'h000;crom[ 984] = 9'h000;crom[ 985] = 9'h000;crom[ 986] = 9'h000;crom[ 987] = 9'h000;crom[ 988] = 9'h000;crom[ 989] = 9'h000;crom[ 990] = 9'h000;crom[ 991] = 9'h000;
    crom[ 992] = 9'h000;crom[ 993] = 9'h000;crom[ 994] = 9'h000;crom[ 995] = 9'h000;crom[ 996] = 9'h000;crom[ 997] = 9'h000;crom[ 998] = 9'h000;crom[ 999] = 9'h000;crom[1000] = 9'h000;crom[1001] = 9'h000;crom[1002] = 9'h000;crom[1003] = 9'h000;crom[1004] = 9'h000;crom[1005] = 9'h000;crom[1006] = 9'h000;crom[1007] = 9'h000;
    crom[1008] = 9'h000;crom[1009] = 9'h000;crom[1010] = 9'h000;crom[1011] = 9'h000;crom[1012] = 9'h000;crom[1013] = 9'h000;crom[1014] = 9'h000;crom[1015] = 9'h000;crom[1016] = 9'h000;crom[1017] = 9'h000;crom[1018] = 9'h000;crom[1019] = 9'h000;crom[1020] = 9'h000;crom[1021] = 9'h000;crom[1022] = 9'h000;crom[1023] = 9'h000;
    crom[1024] = 9'h100;crom[1025] = 9'h020;crom[1026] = 9'h100;crom[1027] = 9'h020;crom[1028] = 9'h100;crom[1029] = 9'h020;crom[1030] = 9'h100;crom[1031] = 9'h020;crom[1032] = 9'h100;crom[1033] = 9'h020;crom[1034] = 9'h100;crom[1035] = 9'h020;crom[1036] = 9'h100;crom[1037] = 9'h020;crom[1038] = 9'h100;crom[1039] = 9'h020;
    crom[1040] = 9'h100;crom[1041] = 9'h020;crom[1042] = 9'h100;crom[1043] = 9'h020;crom[1044] = 9'h100;crom[1045] = 9'h020;crom[1046] = 9'h100;crom[1047] = 9'h020;crom[1048] = 9'h100;crom[1049] = 9'h020;crom[1050] = 9'h100;crom[1051] = 9'h020;crom[1052] = 9'h100;crom[1053] = 9'h020;crom[1054] = 9'h100;crom[1055] = 9'h020;
    crom[1056] = 9'h100;crom[1057] = 9'h020;crom[1058] = 9'h100;crom[1059] = 9'h020;crom[1060] = 9'h100;crom[1061] = 9'h020;crom[1062] = 9'h100;crom[1063] = 9'h020;crom[1064] = 9'h100;crom[1065] = 9'h020;crom[1066] = 9'h100;crom[1067] = 9'h020;crom[1068] = 9'h100;crom[1069] = 9'h020;crom[1070] = 9'h100;crom[1071] = 9'h020;
    crom[1072] = 9'h100;crom[1073] = 9'h020;crom[1074] = 9'h100;crom[1075] = 9'h020;crom[1076] = 9'h100;crom[1077] = 9'h020;crom[1078] = 9'h100;crom[1079] = 9'h020;crom[1080] = 9'h1ff;crom[1081] = 9'h000;crom[1082] = 9'h000;crom[1083] = 9'h1e2;crom[1084] = 9'h1ff;crom[1085] = 9'h000;crom[1086] = 9'h000;crom[1087] = 9'h1d8;
    crom[1088] = 9'h100;crom[1089] = 9'h020;crom[1090] = 9'h100;crom[1091] = 9'h020;crom[1092] = 9'h100;crom[1093] = 9'h020;crom[1094] = 9'h100;crom[1095] = 9'h020;crom[1096] = 9'h100;crom[1097] = 9'h020;crom[1098] = 9'h100;crom[1099] = 9'h020;crom[1100] = 9'h100;crom[1101] = 9'h020;crom[1102] = 9'h100;crom[1103] = 9'h020;
    crom[1104] = 9'h100;crom[1105] = 9'h020;crom[1106] = 9'h100;crom[1107] = 9'h020;crom[1108] = 9'h100;crom[1109] = 9'h020;crom[1110] = 9'h100;crom[1111] = 9'h020;crom[1112] = 9'h100;crom[1113] = 9'h020;crom[1114] = 9'h100;crom[1115] = 9'h020;crom[1116] = 9'h100;crom[1117] = 9'h020;crom[1118] = 9'h100;crom[1119] = 9'h020;
    crom[1120] = 9'h100;crom[1121] = 9'h020;crom[1122] = 9'h100;crom[1123] = 9'h020;crom[1124] = 9'h100;crom[1125] = 9'h020;crom[1126] = 9'h100;crom[1127] = 9'h020;crom[1128] = 9'h100;crom[1129] = 9'h020;crom[1130] = 9'h100;crom[1131] = 9'h020;crom[1132] = 9'h100;crom[1133] = 9'h020;crom[1134] = 9'h100;crom[1135] = 9'h020;
    crom[1136] = 9'h100;crom[1137] = 9'h020;crom[1138] = 9'h100;crom[1139] = 9'h020;crom[1140] = 9'h100;crom[1141] = 9'h020;crom[1142] = 9'h100;crom[1143] = 9'h020;crom[1144] = 9'h1ff;crom[1145] = 9'h000;crom[1146] = 9'h000;crom[1147] = 9'h16c;crom[1148] = 9'h1ff;crom[1149] = 9'h000;crom[1150] = 9'h000;crom[1151] = 9'h156;
    crom[1152] = 9'h180;crom[1153] = 9'h0cc;crom[1154] = 9'h180;crom[1155] = 9'h0cc;crom[1156] = 9'h180;crom[1157] = 9'h0cc;crom[1158] = 9'h180;crom[1159] = 9'h0cc;crom[1160] = 9'h180;crom[1161] = 9'h0cc;crom[1162] = 9'h180;crom[1163] = 9'h0cc;crom[1164] = 9'h180;crom[1165] = 9'h0cc;crom[1166] = 9'h180;crom[1167] = 9'h0cc;
    crom[1168] = 9'h180;crom[1169] = 9'h0cc;crom[1170] = 9'h180;crom[1171] = 9'h0cc;crom[1172] = 9'h180;crom[1173] = 9'h0cc;crom[1174] = 9'h180;crom[1175] = 9'h0cc;crom[1176] = 9'h180;crom[1177] = 9'h0cc;crom[1178] = 9'h180;crom[1179] = 9'h0cc;crom[1180] = 9'h180;crom[1181] = 9'h0cc;crom[1182] = 9'h180;crom[1183] = 9'h0cc;
    crom[1184] = 9'h180;crom[1185] = 9'h0cc;crom[1186] = 9'h180;crom[1187] = 9'h0cc;crom[1188] = 9'h180;crom[1189] = 9'h0cc;crom[1190] = 9'h180;crom[1191] = 9'h0cc;crom[1192] = 9'h180;crom[1193] = 9'h0cc;crom[1194] = 9'h180;crom[1195] = 9'h0cc;crom[1196] = 9'h180;crom[1197] = 9'h0cc;crom[1198] = 9'h180;crom[1199] = 9'h0cc;
    crom[1200] = 9'h180;crom[1201] = 9'h0cc;crom[1202] = 9'h180;crom[1203] = 9'h040;crom[1204] = 9'h100;crom[1205] = 9'h020;crom[1206] = 9'h100;crom[1207] = 9'h020;crom[1208] = 9'h1ff;crom[1209] = 9'h000;crom[1210] = 9'h000;crom[1211] = 9'h13a;crom[1212] = 9'h1ff;crom[1213] = 9'h000;crom[1214] = 9'h000;crom[1215] = 9'h100;
    crom[1216] = 9'h180;crom[1217] = 9'h0cc;crom[1218] = 9'h180;crom[1219] = 9'h0cc;crom[1220] = 9'h180;crom[1221] = 9'h0cc;crom[1222] = 9'h180;crom[1223] = 9'h0cc;crom[1224] = 9'h180;crom[1225] = 9'h0cc;crom[1226] = 9'h180;crom[1227] = 9'h0cc;crom[1228] = 9'h180;crom[1229] = 9'h0cc;crom[1230] = 9'h180;crom[1231] = 9'h0cc;
    crom[1232] = 9'h180;crom[1233] = 9'h0cc;crom[1234] = 9'h180;crom[1235] = 9'h0cc;crom[1236] = 9'h180;crom[1237] = 9'h0cc;crom[1238] = 9'h180;crom[1239] = 9'h0cc;crom[1240] = 9'h180;crom[1241] = 9'h0cc;crom[1242] = 9'h180;crom[1243] = 9'h0cc;crom[1244] = 9'h180;crom[1245] = 9'h0cc;crom[1246] = 9'h180;crom[1247] = 9'h0cc;
    crom[1248] = 9'h180;crom[1249] = 9'h0cc;crom[1250] = 9'h180;crom[1251] = 9'h0cc;crom[1252] = 9'h180;crom[1253] = 9'h0cc;crom[1254] = 9'h180;crom[1255] = 9'h0cc;crom[1256] = 9'h180;crom[1257] = 9'h0cc;crom[1258] = 9'h180;crom[1259] = 9'h0cc;crom[1260] = 9'h180;crom[1261] = 9'h0cc;crom[1262] = 9'h180;crom[1263] = 9'h0cc;
    crom[1264] = 9'h180;crom[1265] = 9'h0cc;crom[1266] = 9'h180;crom[1267] = 9'h0cc;crom[1268] = 9'h100;crom[1269] = 9'h020;crom[1270] = 9'h100;crom[1271] = 9'h020;crom[1272] = 9'h1ff;crom[1273] = 9'h000;crom[1274] = 9'h000;crom[1275] = 9'h13a;crom[1276] = 9'h1ff;crom[1277] = 9'h000;crom[1278] = 9'h000;crom[1279] = 9'h100;
    crom[1280] = 9'h100;crom[1281] = 9'h088;crom[1282] = 9'h100;crom[1283] = 9'h088;crom[1284] = 9'h100;crom[1285] = 9'h088;crom[1286] = 9'h100;crom[1287] = 9'h088;crom[1288] = 9'h100;crom[1289] = 9'h088;crom[1290] = 9'h100;crom[1291] = 9'h088;crom[1292] = 9'h100;crom[1293] = 9'h088;crom[1294] = 9'h100;crom[1295] = 9'h088;
    crom[1296] = 9'h100;crom[1297] = 9'h088;crom[1298] = 9'h100;crom[1299] = 9'h088;crom[1300] = 9'h100;crom[1301] = 9'h088;crom[1302] = 9'h100;crom[1303] = 9'h088;crom[1304] = 9'h100;crom[1305] = 9'h088;crom[1306] = 9'h100;crom[1307] = 9'h088;crom[1308] = 9'h100;crom[1309] = 9'h088;crom[1310] = 9'h100;crom[1311] = 9'h088;
    crom[1312] = 9'h100;crom[1313] = 9'h088;crom[1314] = 9'h100;crom[1315] = 9'h088;crom[1316] = 9'h100;crom[1317] = 9'h088;crom[1318] = 9'h100;crom[1319] = 9'h088;crom[1320] = 9'h100;crom[1321] = 9'h088;crom[1322] = 9'h100;crom[1323] = 9'h088;crom[1324] = 9'h100;crom[1325] = 9'h088;crom[1326] = 9'h100;crom[1327] = 9'h088;
    crom[1328] = 9'h100;crom[1329] = 9'h088;crom[1330] = 9'h100;crom[1331] = 9'h088;crom[1332] = 9'h100;crom[1333] = 9'h020;crom[1334] = 9'h100;crom[1335] = 9'h020;crom[1336] = 9'h1ff;crom[1337] = 9'h000;crom[1338] = 9'h000;crom[1339] = 9'h13a;crom[1340] = 9'h1ff;crom[1341] = 9'h000;crom[1342] = 9'h000;crom[1343] = 9'h100;
    crom[1344] = 9'h100;crom[1345] = 9'h088;crom[1346] = 9'h100;crom[1347] = 9'h088;crom[1348] = 9'h100;crom[1349] = 9'h088;crom[1350] = 9'h100;crom[1351] = 9'h088;crom[1352] = 9'h100;crom[1353] = 9'h088;crom[1354] = 9'h100;crom[1355] = 9'h088;crom[1356] = 9'h100;crom[1357] = 9'h088;crom[1358] = 9'h100;crom[1359] = 9'h088;
    crom[1360] = 9'h100;crom[1361] = 9'h088;crom[1362] = 9'h100;crom[1363] = 9'h088;crom[1364] = 9'h100;crom[1365] = 9'h088;crom[1366] = 9'h100;crom[1367] = 9'h088;crom[1368] = 9'h100;crom[1369] = 9'h088;crom[1370] = 9'h100;crom[1371] = 9'h088;crom[1372] = 9'h100;crom[1373] = 9'h088;crom[1374] = 9'h100;crom[1375] = 9'h088;
    crom[1376] = 9'h100;crom[1377] = 9'h088;crom[1378] = 9'h100;crom[1379] = 9'h088;crom[1380] = 9'h100;crom[1381] = 9'h088;crom[1382] = 9'h100;crom[1383] = 9'h088;crom[1384] = 9'h100;crom[1385] = 9'h088;crom[1386] = 9'h100;crom[1387] = 9'h088;crom[1388] = 9'h100;crom[1389] = 9'h088;crom[1390] = 9'h100;crom[1391] = 9'h088;
    crom[1392] = 9'h100;crom[1393] = 9'h088;crom[1394] = 9'h100;crom[1395] = 9'h088;crom[1396] = 9'h100;crom[1397] = 9'h020;crom[1398] = 9'h100;crom[1399] = 9'h020;crom[1400] = 9'h1ff;crom[1401] = 9'h000;crom[1402] = 9'h000;crom[1403] = 9'h13a;crom[1404] = 9'h1ff;crom[1405] = 9'h000;crom[1406] = 9'h000;crom[1407] = 9'h100;
    crom[1408] = 9'h100;crom[1409] = 9'h088;crom[1410] = 9'h100;crom[1411] = 9'h088;crom[1412] = 9'h100;crom[1413] = 9'h088;crom[1414] = 9'h100;crom[1415] = 9'h088;crom[1416] = 9'h100;crom[1417] = 9'h088;crom[1418] = 9'h100;crom[1419] = 9'h088;crom[1420] = 9'h100;crom[1421] = 9'h088;crom[1422] = 9'h100;crom[1423] = 9'h088;
    crom[1424] = 9'h100;crom[1425] = 9'h088;crom[1426] = 9'h100;crom[1427] = 9'h088;crom[1428] = 9'h100;crom[1429] = 9'h088;crom[1430] = 9'h100;crom[1431] = 9'h088;crom[1432] = 9'h100;crom[1433] = 9'h088;crom[1434] = 9'h100;crom[1435] = 9'h088;crom[1436] = 9'h100;crom[1437] = 9'h088;crom[1438] = 9'h100;crom[1439] = 9'h088;
    crom[1440] = 9'h100;crom[1441] = 9'h088;crom[1442] = 9'h100;crom[1443] = 9'h088;crom[1444] = 9'h100;crom[1445] = 9'h088;crom[1446] = 9'h100;crom[1447] = 9'h088;crom[1448] = 9'h100;crom[1449] = 9'h088;crom[1450] = 9'h100;crom[1451] = 9'h088;crom[1452] = 9'h100;crom[1453] = 9'h088;crom[1454] = 9'h100;crom[1455] = 9'h088;
    crom[1456] = 9'h100;crom[1457] = 9'h088;crom[1458] = 9'h100;crom[1459] = 9'h088;crom[1460] = 9'h100;crom[1461] = 9'h020;crom[1462] = 9'h100;crom[1463] = 9'h020;crom[1464] = 9'h1ff;crom[1465] = 9'h000;crom[1466] = 9'h000;crom[1467] = 9'h13a;crom[1468] = 9'h1ff;crom[1469] = 9'h000;crom[1470] = 9'h000;crom[1471] = 9'h100;
    crom[1472] = 9'h100;crom[1473] = 9'h020;crom[1474] = 9'h100;crom[1475] = 9'h020;crom[1476] = 9'h100;crom[1477] = 9'h020;crom[1478] = 9'h100;crom[1479] = 9'h020;crom[1480] = 9'h100;crom[1481] = 9'h020;crom[1482] = 9'h100;crom[1483] = 9'h020;crom[1484] = 9'h100;crom[1485] = 9'h020;crom[1486] = 9'h100;crom[1487] = 9'h020;
    crom[1488] = 9'h100;crom[1489] = 9'h020;crom[1490] = 9'h100;crom[1491] = 9'h020;crom[1492] = 9'h100;crom[1493] = 9'h020;crom[1494] = 9'h100;crom[1495] = 9'h020;crom[1496] = 9'h100;crom[1497] = 9'h020;crom[1498] = 9'h100;crom[1499] = 9'h020;crom[1500] = 9'h100;crom[1501] = 9'h020;crom[1502] = 9'h100;crom[1503] = 9'h020;
    crom[1504] = 9'h100;crom[1505] = 9'h020;crom[1506] = 9'h100;crom[1507] = 9'h020;crom[1508] = 9'h100;crom[1509] = 9'h020;crom[1510] = 9'h100;crom[1511] = 9'h020;crom[1512] = 9'h100;crom[1513] = 9'h020;crom[1514] = 9'h100;crom[1515] = 9'h020;crom[1516] = 9'h100;crom[1517] = 9'h020;crom[1518] = 9'h100;crom[1519] = 9'h020;
    crom[1520] = 9'h100;crom[1521] = 9'h020;crom[1522] = 9'h100;crom[1523] = 9'h020;crom[1524] = 9'h100;crom[1525] = 9'h020;crom[1526] = 9'h100;crom[1527] = 9'h020;crom[1528] = 9'h1ff;crom[1529] = 9'h000;crom[1530] = 9'h000;crom[1531] = 9'h16c;crom[1532] = 9'h1ff;crom[1533] = 9'h000;crom[1534] = 9'h000;crom[1535] = 9'h156;
    crom[1536] = 9'h100;crom[1537] = 9'h020;crom[1538] = 9'h100;crom[1539] = 9'h020;crom[1540] = 9'h100;crom[1541] = 9'h020;crom[1542] = 9'h100;crom[1543] = 9'h020;crom[1544] = 9'h100;crom[1545] = 9'h020;crom[1546] = 9'h100;crom[1547] = 9'h020;crom[1548] = 9'h100;crom[1549] = 9'h020;crom[1550] = 9'h100;crom[1551] = 9'h020;
    crom[1552] = 9'h100;crom[1553] = 9'h020;crom[1554] = 9'h100;crom[1555] = 9'h020;crom[1556] = 9'h100;crom[1557] = 9'h020;crom[1558] = 9'h100;crom[1559] = 9'h020;crom[1560] = 9'h100;crom[1561] = 9'h020;crom[1562] = 9'h100;crom[1563] = 9'h020;crom[1564] = 9'h100;crom[1565] = 9'h020;crom[1566] = 9'h100;crom[1567] = 9'h020;
    crom[1568] = 9'h100;crom[1569] = 9'h020;crom[1570] = 9'h100;crom[1571] = 9'h020;crom[1572] = 9'h100;crom[1573] = 9'h020;crom[1574] = 9'h100;crom[1575] = 9'h020;crom[1576] = 9'h100;crom[1577] = 9'h020;crom[1578] = 9'h100;crom[1579] = 9'h020;crom[1580] = 9'h100;crom[1581] = 9'h020;crom[1582] = 9'h100;crom[1583] = 9'h020;
    crom[1584] = 9'h100;crom[1585] = 9'h020;crom[1586] = 9'h100;crom[1587] = 9'h020;crom[1588] = 9'h100;crom[1589] = 9'h020;crom[1590] = 9'h100;crom[1591] = 9'h020;crom[1592] = 9'h1ff;crom[1593] = 9'h000;crom[1594] = 9'h000;crom[1595] = 9'h1e2;crom[1596] = 9'h1ff;crom[1597] = 9'h000;crom[1598] = 9'h000;crom[1599] = 9'h1d8;
    crom[1600] = 9'h180;crom[1601] = 9'h0cc;crom[1602] = 9'h180;crom[1603] = 9'h0cc;crom[1604] = 9'h180;crom[1605] = 9'h0cc;crom[1606] = 9'h180;crom[1607] = 9'h0cc;crom[1608] = 9'h180;crom[1609] = 9'h0cc;crom[1610] = 9'h180;crom[1611] = 9'h0cc;crom[1612] = 9'h180;crom[1613] = 9'h0cc;crom[1614] = 9'h180;crom[1615] = 9'h0cc;
    crom[1616] = 9'h180;crom[1617] = 9'h0cc;crom[1618] = 9'h180;crom[1619] = 9'h0cc;crom[1620] = 9'h180;crom[1621] = 9'h0cc;crom[1622] = 9'h180;crom[1623] = 9'h0cc;crom[1624] = 9'h180;crom[1625] = 9'h0cc;crom[1626] = 9'h180;crom[1627] = 9'h0cc;crom[1628] = 9'h180;crom[1629] = 9'h0cc;crom[1630] = 9'h180;crom[1631] = 9'h0cc;
    crom[1632] = 9'h180;crom[1633] = 9'h0cc;crom[1634] = 9'h180;crom[1635] = 9'h0cc;crom[1636] = 9'h180;crom[1637] = 9'h0cc;crom[1638] = 9'h180;crom[1639] = 9'h0cc;crom[1640] = 9'h180;crom[1641] = 9'h0cc;crom[1642] = 9'h180;crom[1643] = 9'h0cc;crom[1644] = 9'h180;crom[1645] = 9'h0cc;crom[1646] = 9'h180;crom[1647] = 9'h0cc;
    crom[1648] = 9'h180;crom[1649] = 9'h0cc;crom[1650] = 9'h180;crom[1651] = 9'h0cc;crom[1652] = 9'h100;crom[1653] = 9'h020;crom[1654] = 9'h100;crom[1655] = 9'h020;crom[1656] = 9'h1ff;crom[1657] = 9'h000;crom[1658] = 9'h000;crom[1659] = 9'h1b4;crom[1660] = 9'h1ff;crom[1661] = 9'h000;crom[1662] = 9'h000;crom[1663] = 9'h18e;
    crom[1664] = 9'h100;crom[1665] = 9'h088;crom[1666] = 9'h100;crom[1667] = 9'h088;crom[1668] = 9'h100;crom[1669] = 9'h088;crom[1670] = 9'h100;crom[1671] = 9'h088;crom[1672] = 9'h100;crom[1673] = 9'h088;crom[1674] = 9'h100;crom[1675] = 9'h088;crom[1676] = 9'h100;crom[1677] = 9'h088;crom[1678] = 9'h100;crom[1679] = 9'h088;
    crom[1680] = 9'h100;crom[1681] = 9'h088;crom[1682] = 9'h100;crom[1683] = 9'h088;crom[1684] = 9'h100;crom[1685] = 9'h088;crom[1686] = 9'h100;crom[1687] = 9'h088;crom[1688] = 9'h100;crom[1689] = 9'h088;crom[1690] = 9'h100;crom[1691] = 9'h088;crom[1692] = 9'h100;crom[1693] = 9'h088;crom[1694] = 9'h100;crom[1695] = 9'h088;
    crom[1696] = 9'h100;crom[1697] = 9'h088;crom[1698] = 9'h100;crom[1699] = 9'h088;crom[1700] = 9'h100;crom[1701] = 9'h088;crom[1702] = 9'h100;crom[1703] = 9'h088;crom[1704] = 9'h100;crom[1705] = 9'h088;crom[1706] = 9'h100;crom[1707] = 9'h088;crom[1708] = 9'h100;crom[1709] = 9'h088;crom[1710] = 9'h100;crom[1711] = 9'h088;
    crom[1712] = 9'h100;crom[1713] = 9'h088;crom[1714] = 9'h100;crom[1715] = 9'h088;crom[1716] = 9'h100;crom[1717] = 9'h020;crom[1718] = 9'h100;crom[1719] = 9'h020;crom[1720] = 9'h1ff;crom[1721] = 9'h000;crom[1722] = 9'h000;crom[1723] = 9'h1b4;crom[1724] = 9'h1ff;crom[1725] = 9'h000;crom[1726] = 9'h000;crom[1727] = 9'h18e;
    crom[1728] = 9'h100;crom[1729] = 9'h088;crom[1730] = 9'h100;crom[1731] = 9'h088;crom[1732] = 9'h100;crom[1733] = 9'h088;crom[1734] = 9'h100;crom[1735] = 9'h088;crom[1736] = 9'h100;crom[1737] = 9'h088;crom[1738] = 9'h100;crom[1739] = 9'h088;crom[1740] = 9'h100;crom[1741] = 9'h088;crom[1742] = 9'h100;crom[1743] = 9'h088;
    crom[1744] = 9'h100;crom[1745] = 9'h088;crom[1746] = 9'h100;crom[1747] = 9'h088;crom[1748] = 9'h100;crom[1749] = 9'h088;crom[1750] = 9'h100;crom[1751] = 9'h088;crom[1752] = 9'h100;crom[1753] = 9'h088;crom[1754] = 9'h100;crom[1755] = 9'h088;crom[1756] = 9'h100;crom[1757] = 9'h088;crom[1758] = 9'h100;crom[1759] = 9'h088;
    crom[1760] = 9'h100;crom[1761] = 9'h088;crom[1762] = 9'h100;crom[1763] = 9'h088;crom[1764] = 9'h100;crom[1765] = 9'h088;crom[1766] = 9'h100;crom[1767] = 9'h088;crom[1768] = 9'h100;crom[1769] = 9'h088;crom[1770] = 9'h100;crom[1771] = 9'h088;crom[1772] = 9'h100;crom[1773] = 9'h088;crom[1774] = 9'h100;crom[1775] = 9'h088;
    crom[1776] = 9'h100;crom[1777] = 9'h088;crom[1778] = 9'h100;crom[1779] = 9'h088;crom[1780] = 9'h100;crom[1781] = 9'h020;crom[1782] = 9'h100;crom[1783] = 9'h020;crom[1784] = 9'h1ff;crom[1785] = 9'h000;crom[1786] = 9'h000;crom[1787] = 9'h1b4;crom[1788] = 9'h1ff;crom[1789] = 9'h000;crom[1790] = 9'h000;crom[1791] = 9'h18e;
    crom[1792] = 9'h100;crom[1793] = 9'h088;crom[1794] = 9'h100;crom[1795] = 9'h088;crom[1796] = 9'h100;crom[1797] = 9'h088;crom[1798] = 9'h100;crom[1799] = 9'h088;crom[1800] = 9'h100;crom[1801] = 9'h088;crom[1802] = 9'h100;crom[1803] = 9'h088;crom[1804] = 9'h100;crom[1805] = 9'h088;crom[1806] = 9'h100;crom[1807] = 9'h088;
    crom[1808] = 9'h100;crom[1809] = 9'h088;crom[1810] = 9'h100;crom[1811] = 9'h088;crom[1812] = 9'h100;crom[1813] = 9'h088;crom[1814] = 9'h100;crom[1815] = 9'h088;crom[1816] = 9'h100;crom[1817] = 9'h088;crom[1818] = 9'h100;crom[1819] = 9'h088;crom[1820] = 9'h100;crom[1821] = 9'h088;crom[1822] = 9'h100;crom[1823] = 9'h088;
    crom[1824] = 9'h100;crom[1825] = 9'h088;crom[1826] = 9'h100;crom[1827] = 9'h088;crom[1828] = 9'h100;crom[1829] = 9'h088;crom[1830] = 9'h100;crom[1831] = 9'h088;crom[1832] = 9'h100;crom[1833] = 9'h088;crom[1834] = 9'h100;crom[1835] = 9'h088;crom[1836] = 9'h100;crom[1837] = 9'h088;crom[1838] = 9'h100;crom[1839] = 9'h088;
    crom[1840] = 9'h100;crom[1841] = 9'h088;crom[1842] = 9'h100;crom[1843] = 9'h088;crom[1844] = 9'h100;crom[1845] = 9'h020;crom[1846] = 9'h100;crom[1847] = 9'h020;crom[1848] = 9'h1ff;crom[1849] = 9'h000;crom[1850] = 9'h000;crom[1851] = 9'h1b4;crom[1852] = 9'h1ff;crom[1853] = 9'h000;crom[1854] = 9'h000;crom[1855] = 9'h18e;
    crom[1856] = 9'h000;crom[1857] = 9'h000;crom[1858] = 9'h000;crom[1859] = 9'h000;crom[1860] = 9'h000;crom[1861] = 9'h000;crom[1862] = 9'h000;crom[1863] = 9'h000;crom[1864] = 9'h000;crom[1865] = 9'h000;crom[1866] = 9'h000;crom[1867] = 9'h000;crom[1868] = 9'h000;crom[1869] = 9'h000;crom[1870] = 9'h000;crom[1871] = 9'h000;
    crom[1872] = 9'h000;crom[1873] = 9'h000;crom[1874] = 9'h000;crom[1875] = 9'h000;crom[1876] = 9'h000;crom[1877] = 9'h000;crom[1878] = 9'h000;crom[1879] = 9'h000;crom[1880] = 9'h000;crom[1881] = 9'h000;crom[1882] = 9'h000;crom[1883] = 9'h000;crom[1884] = 9'h000;crom[1885] = 9'h000;crom[1886] = 9'h000;crom[1887] = 9'h000;
    crom[1888] = 9'h000;crom[1889] = 9'h000;crom[1890] = 9'h000;crom[1891] = 9'h000;crom[1892] = 9'h000;crom[1893] = 9'h000;crom[1894] = 9'h000;crom[1895] = 9'h000;crom[1896] = 9'h000;crom[1897] = 9'h000;crom[1898] = 9'h000;crom[1899] = 9'h000;crom[1900] = 9'h000;crom[1901] = 9'h000;crom[1902] = 9'h000;crom[1903] = 9'h000;
    crom[1904] = 9'h000;crom[1905] = 9'h000;crom[1906] = 9'h000;crom[1907] = 9'h000;crom[1908] = 9'h000;crom[1909] = 9'h000;crom[1910] = 9'h000;crom[1911] = 9'h000;crom[1912] = 9'h000;crom[1913] = 9'h000;crom[1914] = 9'h000;crom[1915] = 9'h000;crom[1916] = 9'h000;crom[1917] = 9'h000;crom[1918] = 9'h000;crom[1919] = 9'h000;
    crom[1920] = 9'h000;crom[1921] = 9'h000;crom[1922] = 9'h000;crom[1923] = 9'h000;crom[1924] = 9'h000;crom[1925] = 9'h000;crom[1926] = 9'h000;crom[1927] = 9'h000;crom[1928] = 9'h000;crom[1929] = 9'h000;crom[1930] = 9'h000;crom[1931] = 9'h000;crom[1932] = 9'h000;crom[1933] = 9'h000;crom[1934] = 9'h000;crom[1935] = 9'h000;
    crom[1936] = 9'h000;crom[1937] = 9'h000;crom[1938] = 9'h000;crom[1939] = 9'h000;crom[1940] = 9'h000;crom[1941] = 9'h000;crom[1942] = 9'h000;crom[1943] = 9'h000;crom[1944] = 9'h000;crom[1945] = 9'h000;crom[1946] = 9'h000;crom[1947] = 9'h000;crom[1948] = 9'h000;crom[1949] = 9'h000;crom[1950] = 9'h000;crom[1951] = 9'h000;
    crom[1952] = 9'h000;crom[1953] = 9'h000;crom[1954] = 9'h000;crom[1955] = 9'h000;crom[1956] = 9'h000;crom[1957] = 9'h000;crom[1958] = 9'h000;crom[1959] = 9'h000;crom[1960] = 9'h000;crom[1961] = 9'h000;crom[1962] = 9'h000;crom[1963] = 9'h000;crom[1964] = 9'h000;crom[1965] = 9'h000;crom[1966] = 9'h000;crom[1967] = 9'h000;
    crom[1968] = 9'h000;crom[1969] = 9'h000;crom[1970] = 9'h000;crom[1971] = 9'h000;crom[1972] = 9'h000;crom[1973] = 9'h000;crom[1974] = 9'h000;crom[1975] = 9'h000;crom[1976] = 9'h000;crom[1977] = 9'h000;crom[1978] = 9'h000;crom[1979] = 9'h000;crom[1980] = 9'h000;crom[1981] = 9'h000;crom[1982] = 9'h000;crom[1983] = 9'h000;
    crom[1984] = 9'h000;crom[1985] = 9'h000;crom[1986] = 9'h000;crom[1987] = 9'h000;crom[1988] = 9'h000;crom[1989] = 9'h000;crom[1990] = 9'h000;crom[1991] = 9'h000;crom[1992] = 9'h000;crom[1993] = 9'h000;crom[1994] = 9'h000;crom[1995] = 9'h000;crom[1996] = 9'h000;crom[1997] = 9'h000;crom[1998] = 9'h000;crom[1999] = 9'h000;
    crom[2000] = 9'h000;crom[2001] = 9'h000;crom[2002] = 9'h000;crom[2003] = 9'h000;crom[2004] = 9'h000;crom[2005] = 9'h000;crom[2006] = 9'h000;crom[2007] = 9'h000;crom[2008] = 9'h000;crom[2009] = 9'h000;crom[2010] = 9'h000;crom[2011] = 9'h000;crom[2012] = 9'h000;crom[2013] = 9'h000;crom[2014] = 9'h000;crom[2015] = 9'h000;
    crom[2016] = 9'h000;crom[2017] = 9'h000;crom[2018] = 9'h000;crom[2019] = 9'h000;crom[2020] = 9'h000;crom[2021] = 9'h000;crom[2022] = 9'h000;crom[2023] = 9'h000;crom[2024] = 9'h000;crom[2025] = 9'h000;crom[2026] = 9'h000;crom[2027] = 9'h000;crom[2028] = 9'h000;crom[2029] = 9'h000;crom[2030] = 9'h000;crom[2031] = 9'h000;
    crom[2032] = 9'h000;crom[2033] = 9'h000;crom[2034] = 9'h000;crom[2035] = 9'h000;crom[2036] = 9'h000;crom[2037] = 9'h000;crom[2038] = 9'h000;crom[2039] = 9'h000;crom[2040] = 9'h000;crom[2041] = 9'h000;crom[2042] = 9'h000;crom[2043] = 9'h000;crom[2044] = 9'h000;crom[2045] = 9'h000;crom[2046] = 9'h000;crom[2047] = 9'h000;
end

always @ (posedge clk)
    if (rst)
        crom_reg <= CROM_INIT;
    else if (ce)
        crom_reg <= crom[crom_adr];

// Create the address for the CROM. If there is no pattern input, remove it
// from the concatenations below.
assign crom_adr = {pattern, v_region, h_region, samples};

// Replicate the LS bit of CROM to generate 10-bit video output path then
// scale back down to the video width output.
assign q = {crom_reg, crom_reg[0]} >> (10 - VID_WIDTH);

//
// Sample counters A
//
// This is a two-bit counter used as the LS two address bits into the video
// ROM. The sample counter is also used to generate the clock enable inputs to
// the horizontal and vertical state machine so that these state machines only
// advance on the fourth sample of a horizontal state.
//
always @ (posedge clk or posedge rst)
    if (rst)
        samples <= 2'b11;
    else if (ce)
        samples <= samples + 1;

//
// Output flip-flops
// 
// These flip-flops register the field, h_sync, and v_sync outputs of the module.
//
always @ (posedge clk or posedge rst)
    if (rst)
        begin
            h_sync <= 0;
            v_sync <= 0;
            field <= 0;
        end
    else if (ce)
        begin
            h_sync <= h;
            v_sync <= v;
            field <= f;
        end

endmodule  
