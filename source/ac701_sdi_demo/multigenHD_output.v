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
//  /   /         Filename: $File: //Groups/video_ip/demos/A7/xapp1097_a7_sdi_demos/Verilog/ac701_sdi_demo/multigenHD_output.v $
// /___/   /\     Timestamp: $DateTime: 2013/10/22 15:33:22 $
// \   \  /  \
//  \___\/\___\
//
// Description:
//  This module contains the output section of the HD video pattern generator. A
//  block RAM is used to convert the vertical and horizontal coordinates of the
//  video pattern into Y and C output values.
//
//  A Y-Ramp generator is used to create the Y-Ramp pattern for RP 219.      
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

module multigenHD_output (
    input   wire        clk,            // word-rate clock
    input   wire        rst,            // async reset
    input   wire        ce,             // clock enable
    input   wire [4:0]  h_region,       // horizontal region
    input   wire [2:0]  v_band,         // vertical band
    input   wire        h_counter_lsb,  // LSB of horizontal counter
    input   wire        y_ramp_inc_sel, // controls the Y-Ramp increment MUX
    output  wire [9:0]  y,              // luma output channel
    output  wire [9:0]  c               // chroma output channel
);

//-----------------------------------------------------------------------------
// Parameter definitions
//

//
// This group of parameters defines the bit widths of various fields in the
// module. Note that this version of the module is designed only for 10-bit
// video components so VID_WIDTH must not be changed.
//
localparam VID_WIDTH    = 10;                   // Width of video components
localparam HRGN_WIDTH   = 5;                    // Width of h_region counter
localparam VBAND_WIDTH  = 3;                    // Width of vband code
localparam YRAMP_FRAC   = 7;                    // Number of fractional bits in Y Ramp reg
localparam YRAMP_WIDTH  = VID_WIDTH + YRAMP_FRAC;// Width of Y Ramp reg

localparam VID_MSB      = VID_WIDTH - 1;        // MS bit # of video data path
localparam HRGN_MSB     = HRGN_WIDTH - 1;       // MS bit # of h_region counter
localparam VBAND_MSB    = VBAND_WIDTH - 1;      // MS bit # of vband code
localparam YRAMP_MSB    = YRAMP_WIDTH - 1;      // MS bit # of y_ramp register

localparam ROM_MSB      = 21;
localparam CROM_INIT    = 22'h200100;

//
// Y-ramp parameters
//
// These constants control the Y-Ramp pattern generation.
//
localparam YRAMP_INIT   = 17'b0000111111_1100000;   // 63.75 is initial Y ramp starting value
localparam Y_INC_1920   = 8'b0_1011011;             // 0.7109375 is ramp increment for 1920 wide standards
localparam Y_INC_1280   = 8'b1_0001001;             // 1.0703125 is ramp increment for 1280 wide standards
localparam YRAMP_RND    = 17'b0000000000_1000000;   // 0.5 is the round up increment value for rounder


//-----------------------------------------------------------------------------
// Signal definitions
//

reg     [ROM_MSB:0]     crom [511:0];
wire                    y_ramp_reload;          // reloads the y_ramp reg
wire                    y_ramp_en;              // enables output of the y_ramp reg
reg     [YRAMP_MSB:0]   y_ramp;                 // Y ramp register
wire    [YRAMP_MSB:0]   y_ramp_round;           // Y ramp rounder
wire    [VID_MSB:0]     y_ramp_out;             // rounded output of Y ramp reg
wire    [YRAMP_MSB:0]   y_ramp_inc;             // output of Y ramp increment MUX
reg     [ROM_MSB:0]     crom_out = CROM_INIT;   // CROM output
wire    [VID_MSB:0]     y_rom;                  // Y output of color ROM
wire    [VID_MSB:0]     c_rom;                  // C output of color ROM
wire    [VID_MSB:0]     y_ramp_mux;             // output of Y ramp mux

    
//----------------------------------------------------------------------------
// Color ROM
//
initial begin
    crom[   0] = 22'h200100;crom[   1] = 22'h200100;crom[   2] = 22'h200100;crom[   3] = 22'h200100;crom[   4] = 22'h200100;crom[   5] = 22'h200100;crom[   6] = 22'h200100;crom[   7] = 22'h200100;crom[   8] = 22'h200100;crom[   9] = 22'h200100;crom[  10] = 22'h200100;crom[  11] = 22'h200100;crom[  12] = 22'h200100;crom[  13] = 22'h200100;crom[  14] = 22'h200100;crom[  15] = 22'h200100;
    crom[  16] = 22'h200100;crom[  17] = 22'h200100;crom[  18] = 22'h200100;crom[  19] = 22'h200100;crom[  20] = 22'h200100;crom[  21] = 22'h200100;crom[  22] = 22'h200100;crom[  23] = 22'h200100;crom[  24] = 22'h200100;crom[  25] = 22'h200100;crom[  26] = 22'h200100;crom[  27] = 22'h200100;crom[  28] = 22'h200100;crom[  29] = 22'h200100;crom[  30] = 22'h200100;crom[  31] = 22'h200100;
    crom[  32] = 22'h3ffffc;crom[  33] = 22'h000000;crom[  34] = 22'h000000;crom[  35] = 22'h2d8b60;crom[  36] = 22'h200100;crom[  37] = 22'h200100;crom[  38] = 22'h3ffffc;crom[  39] = 22'h000000;crom[  40] = 22'h000000;crom[  41] = 22'h2acab0;crom[  42] = 22'h200100;crom[  43] = 22'h200100;crom[  44] = 22'h200100;crom[  45] = 22'h200100;crom[  46] = 22'h000000;crom[  47] = 22'h3b0ec0;
    crom[  48] = 22'h200100;crom[  49] = 22'h200100;crom[  50] = 22'h200100;crom[  51] = 22'h200100;crom[  52] = 22'h200100;crom[  53] = 22'h200100;crom[  54] = 22'h000000;crom[  55] = 22'h3c4f10;crom[  56] = 22'h200100;crom[  57] = 22'h200100;crom[  58] = 22'h200100;crom[  59] = 22'h200100;crom[  60] = 22'h200100;crom[  61] = 22'h200100;crom[  62] = 22'h200100;crom[  63] = 22'h200100;
    crom[  64] = 22'h200678;crom[  65] = 22'h200678;crom[  66] = 22'h200b44;crom[  67] = 22'h200b44;crom[  68] = 22'h0b0a88;crom[  69] = 22'h21fa88;crom[  70] = 22'h0b0a88;crom[  71] = 22'h21fa88;crom[  72] = 22'h24d914;crom[  73] = 22'h0b0914;crom[  74] = 22'h0fd858;crom[  75] = 22'h0cf858;crom[  76] = 22'h0fd858;crom[  77] = 22'h0cf858;crom[  78] = 22'h3033ec;crom[  79] = 22'h3313ec;
    crom[  80] = 22'h3033ec;crom[  81] = 22'h3313ec;crom[  82] = 22'h3033ec;crom[  83] = 22'h3313ec;crom[  84] = 22'h1b3330;crom[  85] = 22'h350330;crom[  86] = 22'h1b3330;crom[  87] = 22'h350330;crom[  88] = 22'h1b3330;crom[  89] = 22'h350330;crom[  90] = 22'h3501bc;crom[  91] = 22'h1e11bc;crom[  92] = 22'h200678;crom[  93] = 22'h200678;crom[  94] = 22'h200678;crom[  95] = 22'h200678;
    crom[  96] = 22'h3ffffc;crom[  97] = 22'h000000;crom[  98] = 22'h000000;crom[  99] = 22'h2749d0;crom[ 100] = 22'h200100;crom[ 101] = 22'h200100;crom[ 102] = 22'h3ffffc;crom[ 103] = 22'h000000;crom[ 104] = 22'h000000;crom[ 105] = 22'h200800;crom[ 106] = 22'h200100;crom[ 107] = 22'h200100;crom[ 108] = 22'h200100;crom[ 109] = 22'h200100;crom[ 110] = 22'h000000;crom[ 111] = 22'h31cc70;
    crom[ 112] = 22'h200b44;crom[ 113] = 22'h200b44;crom[ 114] = 22'h200b44;crom[ 115] = 22'h200b44;crom[ 116] = 22'h200b44;crom[ 117] = 22'h200b44;crom[ 118] = 22'h000000;crom[ 119] = 22'h368da0;crom[ 120] = 22'h200100;crom[ 121] = 22'h200100;crom[ 122] = 22'h200100;crom[ 123] = 22'h200100;crom[ 124] = 22'h200100;crom[ 125] = 22'h200100;crom[ 126] = 22'h200100;crom[ 127] = 22'h200100;
    crom[ 128] = 22'h267bc8;crom[ 129] = 22'h040bc8;crom[ 130] = 22'h200b44;crom[ 131] = 22'h200b44;crom[ 132] = 22'h200b44;crom[ 133] = 22'h200b44;crom[ 134] = 22'h200b44;crom[ 135] = 22'h200b44;crom[ 136] = 22'h200b44;crom[ 137] = 22'h200b44;crom[ 138] = 22'h200b44;crom[ 139] = 22'h200b44;crom[ 140] = 22'h200b44;crom[ 141] = 22'h200b44;crom[ 142] = 22'h200b44;crom[ 143] = 22'h200b44;
    crom[ 144] = 22'h200b44;crom[ 145] = 22'h200b44;crom[ 146] = 22'h200b44;crom[ 147] = 22'h200b44;crom[ 148] = 22'h200b44;crom[ 149] = 22'h200b44;crom[ 150] = 22'h200b44;crom[ 151] = 22'h200b44;crom[ 152] = 22'h200b44;crom[ 153] = 22'h200b44;crom[ 154] = 22'h200b44;crom[ 155] = 22'h200b44;crom[ 156] = 22'h3c01fc;crom[ 157] = 22'h1d71fc;crom[ 158] = 22'h3c01fc;crom[ 159] = 22'h1d71fc;
    crom[ 160] = 22'h3ffffc;crom[ 161] = 22'h000000;crom[ 162] = 22'h000000;crom[ 163] = 22'h2749d0;crom[ 164] = 22'h200100;crom[ 165] = 22'h200100;crom[ 166] = 22'h3ffffc;crom[ 167] = 22'h000000;crom[ 168] = 22'h000000;crom[ 169] = 22'h200800;crom[ 170] = 22'h200100;crom[ 171] = 22'h200100;crom[ 172] = 22'h200100;crom[ 173] = 22'h200100;crom[ 174] = 22'h000000;crom[ 175] = 22'h31cc70;
    crom[ 176] = 22'h200eb0;crom[ 177] = 22'h200eb0;crom[ 178] = 22'h19c3d4;crom[ 179] = 22'h2753d4;crom[ 180] = 22'h2643d0;crom[ 181] = 22'h18b3d0;crom[ 182] = 22'h000000;crom[ 183] = 22'h368da0;crom[ 184] = 22'h200100;crom[ 185] = 22'h200100;crom[ 186] = 22'h200100;crom[ 187] = 22'h200100;crom[ 188] = 22'h200100;crom[ 189] = 22'h200100;crom[ 190] = 22'h200100;crom[ 191] = 22'h200100;
    crom[ 192] = 22'h040db4;crom[ 193] = 22'h229db4;crom[ 194] = 22'h200101;crom[ 195] = 22'h200101;crom[ 196] = 22'h200eb2;crom[ 197] = 22'h200eb2;crom[ 198] = 22'h200eb2;crom[ 199] = 22'h200eb2;crom[ 200] = 22'h200eb2;crom[ 201] = 22'h200eb2;crom[ 202] = 22'h200eb2;crom[ 203] = 22'h200eb2;crom[ 204] = 22'h200eb2;crom[ 205] = 22'h200eb2;crom[ 206] = 22'h200eb2;crom[ 207] = 22'h200eb2;
    crom[ 208] = 22'h200eb2;crom[ 209] = 22'h200eb2;crom[ 210] = 22'h200eb2;crom[ 211] = 22'h200eb2;crom[ 212] = 22'h200eb2;crom[ 213] = 22'h200eb2;crom[ 214] = 22'h200eb2;crom[ 215] = 22'h200eb2;crom[ 216] = 22'h200eb2;crom[ 217] = 22'h200eb2;crom[ 218] = 22'h200eb2;crom[ 219] = 22'h200eb2;crom[ 220] = 22'h1993e8;crom[ 221] = 22'h3c03e8;crom[ 222] = 22'h1993e8;crom[ 223] = 22'h3c03e8;
    crom[ 224] = 22'h3ffffc;crom[ 225] = 22'h000000;crom[ 226] = 22'h000000;crom[ 227] = 22'h2749d0;crom[ 228] = 22'h200100;crom[ 229] = 22'h200100;crom[ 230] = 22'h3ffffc;crom[ 231] = 22'h000000;crom[ 232] = 22'h000000;crom[ 233] = 22'h200800;crom[ 234] = 22'h200100;crom[ 235] = 22'h200100;crom[ 236] = 22'h200100;crom[ 237] = 22'h200100;crom[ 238] = 22'h000000;crom[ 239] = 22'h31cc70;
    crom[ 240] = 22'h200101;crom[ 241] = 22'h200101;crom[ 242] = 22'h200101;crom[ 243] = 22'h200101;crom[ 244] = 22'h2b9235;crom[ 245] = 22'h25e235;crom[ 246] = 22'h000000;crom[ 247] = 22'h368da0;crom[ 248] = 22'h200100;crom[ 249] = 22'h200100;crom[ 250] = 22'h200100;crom[ 251] = 22'h200100;crom[ 252] = 22'h200100;crom[ 253] = 22'h200100;crom[ 254] = 22'h200100;crom[ 255] = 22'h200100;
    crom[ 256] = 22'h20030c;crom[ 257] = 22'h20030c;crom[ 258] = 22'h200100;crom[ 259] = 22'h200100;crom[ 260] = 22'h200100;crom[ 261] = 22'h200100;crom[ 262] = 22'h200eb0;crom[ 263] = 22'h200eb0;crom[ 264] = 22'h200eb0;crom[ 265] = 22'h200eb0;crom[ 266] = 22'h200eb0;crom[ 267] = 22'h200eb0;crom[ 268] = 22'h200100;crom[ 269] = 22'h200100;crom[ 270] = 22'h200100;crom[ 271] = 22'h200100;
    crom[ 272] = 22'h2000b8;crom[ 273] = 22'h2000b8;crom[ 274] = 22'h200100;crom[ 275] = 22'h200100;crom[ 276] = 22'h200148;crom[ 277] = 22'h200148;crom[ 278] = 22'h200100;crom[ 279] = 22'h200100;crom[ 280] = 22'h20018c;crom[ 281] = 22'h20018c;crom[ 282] = 22'h200100;crom[ 283] = 22'h200100;crom[ 284] = 22'h20030c;crom[ 285] = 22'h20030c;crom[ 286] = 22'h20030c;crom[ 287] = 22'h20030c;
    crom[ 288] = 22'h3ffffc;crom[ 289] = 22'h000000;crom[ 290] = 22'h000000;crom[ 291] = 22'h2749d0;crom[ 292] = 22'h200100;crom[ 293] = 22'h200100;crom[ 294] = 22'h3ffffc;crom[ 295] = 22'h000000;crom[ 296] = 22'h000000;crom[ 297] = 22'h200800;crom[ 298] = 22'h200100;crom[ 299] = 22'h200100;crom[ 300] = 22'h200100;crom[ 301] = 22'h200100;crom[ 302] = 22'h000000;crom[ 303] = 22'h31cc70;
    crom[ 304] = 22'h200100;crom[ 305] = 22'h200100;crom[ 306] = 22'h200100;crom[ 307] = 22'h200100;crom[ 308] = 22'h200100;crom[ 309] = 22'h200100;crom[ 310] = 22'h000000;crom[ 311] = 22'h368da0;crom[ 312] = 22'h200100;crom[ 313] = 22'h200100;crom[ 314] = 22'h200100;crom[ 315] = 22'h200100;crom[ 316] = 22'h200100;crom[ 317] = 22'h200100;crom[ 318] = 22'h200100;crom[ 319] = 22'h200100;
    crom[ 320] = 22'h200100;crom[ 321] = 22'h200100;crom[ 322] = 22'h200100;crom[ 323] = 22'h200100;crom[ 324] = 22'h200100;crom[ 325] = 22'h200100;crom[ 326] = 22'h200100;crom[ 327] = 22'h200100;crom[ 328] = 22'h200100;crom[ 329] = 22'h200100;crom[ 330] = 22'h200100;crom[ 331] = 22'h200100;crom[ 332] = 22'h200100;crom[ 333] = 22'h200100;crom[ 334] = 22'h200100;crom[ 335] = 22'h200100;
    crom[ 336] = 22'h200100;crom[ 337] = 22'h200100;crom[ 338] = 22'h200100;crom[ 339] = 22'h200100;crom[ 340] = 22'h200100;crom[ 341] = 22'h200100;crom[ 342] = 22'h200100;crom[ 343] = 22'h200100;crom[ 344] = 22'h200100;crom[ 345] = 22'h200100;crom[ 346] = 22'h200100;crom[ 347] = 22'h200100;crom[ 348] = 22'h200100;crom[ 349] = 22'h200100;crom[ 350] = 22'h300660;crom[ 351] = 22'h300660;
    crom[ 352] = 22'h3ffffc;crom[ 353] = 22'h000000;crom[ 354] = 22'h000000;crom[ 355] = 22'h2749d0;crom[ 356] = 22'h200100;crom[ 357] = 22'h200100;crom[ 358] = 22'h3ffffc;crom[ 359] = 22'h000000;crom[ 360] = 22'h000000;crom[ 361] = 22'h200800;crom[ 362] = 22'h200100;crom[ 363] = 22'h200100;crom[ 364] = 22'h200100;crom[ 365] = 22'h200100;crom[ 366] = 22'h000000;crom[ 367] = 22'h31cc70;
    crom[ 368] = 22'h200100;crom[ 369] = 22'h200100;crom[ 370] = 22'h200100;crom[ 371] = 22'h200100;crom[ 372] = 22'h200100;crom[ 373] = 22'h200100;crom[ 374] = 22'h000000;crom[ 375] = 22'h368da0;crom[ 376] = 22'h300660;crom[ 377] = 22'h300660;crom[ 378] = 22'h300660;crom[ 379] = 22'h300660;crom[ 380] = 22'h300640;crom[ 381] = 22'h300640;crom[ 382] = 22'h200100;crom[ 383] = 22'h200100;
    crom[ 384] = 22'h200100;crom[ 385] = 22'h200100;crom[ 386] = 22'h200100;crom[ 387] = 22'h200100;crom[ 388] = 22'h200100;crom[ 389] = 22'h200100;crom[ 390] = 22'h200100;crom[ 391] = 22'h200100;crom[ 392] = 22'h200100;crom[ 393] = 22'h200100;crom[ 394] = 22'h200100;crom[ 395] = 22'h200100;crom[ 396] = 22'h200100;crom[ 397] = 22'h200100;crom[ 398] = 22'h200100;crom[ 399] = 22'h200100;
    crom[ 400] = 22'h200100;crom[ 401] = 22'h200100;crom[ 402] = 22'h200100;crom[ 403] = 22'h200100;crom[ 404] = 22'h200100;crom[ 405] = 22'h200100;crom[ 406] = 22'h200100;crom[ 407] = 22'h200100;crom[ 408] = 22'h200100;crom[ 409] = 22'h200100;crom[ 410] = 22'h200100;crom[ 411] = 22'h200100;crom[ 412] = 22'h200100;crom[ 413] = 22'h200100;crom[ 414] = 22'h200440;crom[ 415] = 22'h200440;
    crom[ 416] = 22'h3ffffc;crom[ 417] = 22'h000000;crom[ 418] = 22'h000000;crom[ 419] = 22'h2749d0;crom[ 420] = 22'h200100;crom[ 421] = 22'h200100;crom[ 422] = 22'h3ffffc;crom[ 423] = 22'h000000;crom[ 424] = 22'h000000;crom[ 425] = 22'h200800;crom[ 426] = 22'h200100;crom[ 427] = 22'h200100;crom[ 428] = 22'h200100;crom[ 429] = 22'h200100;crom[ 430] = 22'h000000;crom[ 431] = 22'h31cc70;
    crom[ 432] = 22'h200100;crom[ 433] = 22'h200100;crom[ 434] = 22'h200100;crom[ 435] = 22'h200100;crom[ 436] = 22'h200100;crom[ 437] = 22'h200100;crom[ 438] = 22'h000000;crom[ 439] = 22'h368da0;crom[ 440] = 22'h200440;crom[ 441] = 22'h200440;crom[ 442] = 22'h200440;crom[ 443] = 22'h200440;crom[ 444] = 22'h200440;crom[ 445] = 22'h200440;crom[ 446] = 22'h200100;crom[ 447] = 22'h200100;
    crom[ 448] = 22'h200100;crom[ 449] = 22'h200100;crom[ 450] = 22'h200100;crom[ 451] = 22'h200100;crom[ 452] = 22'h200100;crom[ 453] = 22'h200100;crom[ 454] = 22'h200100;crom[ 455] = 22'h200100;crom[ 456] = 22'h200100;crom[ 457] = 22'h200100;crom[ 458] = 22'h200100;crom[ 459] = 22'h200100;crom[ 460] = 22'h200100;crom[ 461] = 22'h200100;crom[ 462] = 22'h200100;crom[ 463] = 22'h200100;
    crom[ 464] = 22'h200100;crom[ 465] = 22'h200100;crom[ 466] = 22'h200100;crom[ 467] = 22'h200100;crom[ 468] = 22'h200100;crom[ 469] = 22'h200100;crom[ 470] = 22'h200100;crom[ 471] = 22'h200100;crom[ 472] = 22'h200100;crom[ 473] = 22'h200100;crom[ 474] = 22'h200100;crom[ 475] = 22'h200100;crom[ 476] = 22'h200100;crom[ 477] = 22'h200100;crom[ 478] = 22'h200100;crom[ 479] = 22'h200100;
    crom[ 480] = 22'h200100;crom[ 481] = 22'h200100;crom[ 482] = 22'h200100;crom[ 483] = 22'h200100;crom[ 484] = 22'h200100;crom[ 485] = 22'h200100;crom[ 486] = 22'h200100;crom[ 487] = 22'h200100;crom[ 488] = 22'h200100;crom[ 489] = 22'h200100;crom[ 490] = 22'h200100;crom[ 491] = 22'h200100;crom[ 492] = 22'h200100;crom[ 493] = 22'h200100;crom[ 494] = 22'h200100;crom[ 495] = 22'h200100;
    crom[ 496] = 22'h200100;crom[ 497] = 22'h200100;crom[ 498] = 22'h200100;crom[ 499] = 22'h200100;crom[ 500] = 22'h200100;crom[ 501] = 22'h200100;crom[ 502] = 22'h200100;crom[ 503] = 22'h200100;crom[ 504] = 22'h200100;crom[ 505] = 22'h200100;crom[ 506] = 22'h200100;crom[ 507] = 22'h200100;crom[ 508] = 22'h200100;crom[ 509] = 22'h200100;crom[ 510] = 22'h200100;crom[ 511] = 22'h200100;
end

always @ (posedge clk)
    if (rst)
        crom_out <= CROM_INIT;
    else if (ce)
        crom_out <= crom[{v_band, h_region, h_counter_lsb}];

assign y_ramp_reload = crom_out[0];
assign y_ramp_en = crom_out[1];
assign y_rom = crom_out[VID_MSB+2:2];
assign c_rom = crom_out[VID_MSB*2+3:VID_MSB+3];

//
// Y Ramp increment selection
//
// This MUX selects the Y Ramp increment value. Different increment values are
// used for formats with 1920 active samples per line vs. 1280 active samples
// per line. This is because the Y Ramp pattern contains less samples if there
// are only 1280 active samples per line, so the increment value must be
// bigger in order to reach the maximum Y value by the end of the Y Ramp
// pattern.
//
// The control for this MUX comes from an output of the VROM. The VROM decodes
// the std input code and controls this MUX appropriately.
//
assign y_ramp_inc = y_ramp_inc_sel ? Y_INC_1280 : Y_INC_1920;

//
// Y Ramp register & adder
//
// This is the accumulator section of the Y Ramp generator. The register
// normally accumulates new Y Ramp increment values with the current contents
// of the register every clock cycle. However, if the y_ramp_reload output of
// the CROM is asserted, the register is loaded with the YRAMP_INIT value to
// begin the Y_RAMP pattern. The accumulator contains 10 integer bits and 7
// fractional bits to make a smooth ramp function.
//
always @ (posedge clk or posedge rst)
    if (rst)
        y_ramp <= YRAMP_INIT;
    else if (ce)
        begin
            if (y_ramp_reload)
                y_ramp <= YRAMP_INIT;
            else
                y_ramp <= y_ramp + y_ramp_inc;
        end

//
// Y Ramp rounder
//
// This code rounds the output of the Y Ramp accumulator to the nearest integer
// by adding a value of 0.5 and then truncating the fractional bits.
//
assign y_ramp_round = y_ramp + YRAMP_RND;
assign y_ramp_out = y_ramp_round[YRAMP_MSB:(YRAMP_MSB - VID_WIDTH) + 1];

//
// Y output mux
//
// This MUX will normally output the Y value from the CROM unless the Y Ramp
// pattern is being shown, in which case it outputs the rounded output of the
// Y Ramp accumulator.
//
assign y_ramp_mux = y_ramp_en ? y_ramp_out : y_rom;

assign y = y_ramp_mux;
assign c = c_rom;

endmodule
