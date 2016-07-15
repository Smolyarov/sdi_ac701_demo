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
//  /   /         Filename: $File: //Groups/video_ip/demos/A7/xapp1097_a7_sdi_demos/Verilog/ac701_sdi_demo/multigenHD.v $
// /___/   /\     Timestamp: $DateTime: 2013/10/22 15:33:22 $
// \   \  /  \
//  \___\/\___\
//
// Description:
/*
This video pattern generator will generate color bars for the 18 video standards
currently supported by the SMPTE 292-1 (HD-SDI) video standard. The color bars 
comply with SMPTE RP 219 standard color bars, as shown below. This module can
also generate the SMPTE RP 198 HD-SDI checkfield test pattern and 75% color
bars.

|<-------------------------------------- a ------------------------------------->|
|                                                                                |
|        |<----------------------------(3/4)a-------------------------->|        |
|        |                                                              |        |
|   d    |    c        c        c        c        c        c        c   |   d    |
+--------+--------+--------+--------+--------+--------+--------+--------+--------+ - - - - -
|        |        |        |        |        |        |        |        |        |   ^     ^
|        |        |        |        |        |        |        |        |        |   |     |
|        |        |        |        |        |        |        |        |        |   |     |
|        |        |        |        |        |        |        |        |        |   |     |
|        |        |        |        |        |        |        |        |        | (7/12)b |
|  40%   |  75%   | YELLOW |  CYAN  |  GREEN | MAGENTA|   RED  |  BLUE  |  40%   |   |     |
|  GRAY  | WHITE  |        |        |        |        |        |        |  GRAY  |   |     |
|   *1   |        |        |        |        |        |        |        |   *1   |   |     b
|        |        |        |        |        |        |        |        |        |   |     |
|        |        |        |        |        |        |        |        |        |   |     |
|        |        |        |        |        |        |        |        |        |   v     |
+--------+--------+--------+--------+--------+--------+--------+--------+--------+ - - -   |
|100%CYAN|  *2    |                   75% WHITE                         |100%BLUE| (1/12)b |
+--------+--------+-----------------------------------------------------+--------+ - - -   |
|100%YELO|  *3    |                    Y-RAMP                           |100% RED| (1/12)b |
+--------+--------+---+-----------------+-------+--+--+--+--+--+--------+--------+ - - -   |
|        |            |                 |       |  |  |  |  |  |        |        |         |
|  15%   |     0%     |       100%      |  0%   |BL|BL|BL|BL|BL|    0%  |  15%   | (3/12)b |
|  GRAY  |    BLACK   |      WHITE      | BLACK |K-|K |K+|K |K+|  BLACK |  GRAY  |         |
|   *4   |            |                 |       |2%|0%|2%|0%|4%|        |   *4   |         v
+--------+------------+-----------------+-------+--+--+--+--+--+--------+--------+ - - - - -
    d        (3/2)c            2c        (5/6)c  c  c  c  c  c      c       d
                                                 -  -  -  -  -
                                                 3  3  3  3  3

*1: The block marked *1 is 40% Gray for a default value. This value may 
optionally be set to any other value in accordance with the operational 
requirements of the user.    
    
*2: In the block marked *2, the user may select 75% White, 100% White, +I, or
-I.

*3: In the block marked *3, the user may select either 0% Black, or +Q. When the
-I value is selected for the block marked *2, then the +Q signal must be
selected for the *3 block.

*4: The block marked *4 is 15% Gray for a default value. This value may
optionally be set to any other value in accordance with the operational
requirements of the user.
      
*/
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

`timescale 1 ps / 1 ps

module multigenHD (
    input   wire        clk,        // word-rate clock
    input   wire        rst,        // async reset
    input   wire        ce,         // clock enable
    input   wire [2:0]  std,        // selects video format
    input   wire [1:0]  pattern,    // 00 = RP 219 colorbars, X1 = RP 198 checkfield, 10 = 75% colorbars
    input   wire [1:0]  user_opt,   // selects option for the *2 & *3 blocks of RP 219
    output  reg  [9:0]  y,          // luma output channel
    output  reg  [9:0]  c,          // chroma output channel
    output  wire        h_blank,    // asserted during horizontal blanking period
    output  wire        v_blank,    // asserted 
    output  wire        field,      // indicates current field
    output  wire        trs,        // asserted during 4 words of TRS symbol,
    output  wire        xyz,        // asserted during TRS XYZ word
    output  reg  [10:0] line_num    // current vertical line number
);

//-----------------------------------------------------------------------------
// Parameter definitions
//

//
// This group of parameters defines the bit widths of various fields in the
// module. 
//
localparam VID_WIDTH     = 10;                   // Width of video components
localparam VCNT_WIDTH    = 11;                   // Width of v_counter
localparam HRGN_WIDTH    = 5;                    // Width of h_region counter
localparam VRGN_WIDTH    = 5;                    // Width of v_region counter
localparam VBAND_WIDTH   = 3;                    // Width of vband code
 
localparam VID_MSB       = VID_WIDTH - 1;        // MS bit # of video data path
localparam VCNT_MSB      = VCNT_WIDTH - 1;       // MS bit # of v_counter
localparam HRGN_MSB      = HRGN_WIDTH - 1;       // MS bit # of h_region counter
localparam VBAND_MSB     = VBAND_WIDTH - 1;      // MS bit # of vband code



//-----------------------------------------------------------------------------
// Signal definitions
//

reg     [2:0]           std_q;          // register for std inputs
wire                    std_change;     // difference between std and std_q
wire                    v_inc;          // increments the vertical counter
wire    [HRGN_MSB:0]    h_region;       // modified horizontal region value
wire                    h_counter_lsb;  // LSB of h_counter
wire    [VCNT_MSB:0]    v_counter;      // current line number
wire    [VBAND_MSB:0]   v_band;         // current vertical band
wire                    f_int;          // vert section F output
wire                    v_int;          // vert section V output
wire                    first_line;     // vert section output indicating first active 
wire                    y_ramp_inc_sel; // vert section output indicating which Y-Ramp increment value to use
wire                    trs_int;        // horz section TRS output
wire                    xyz_int;        // horz section XYZ output
wire                    h_int;          // horz section H output
wire    [VID_MSB:0]     y_int;          // Y output of output generator
wire    [VID_MSB:0]     c_int;          // C output of output generator
reg     [1:0]           trs_reg;        // TRS signal delay reg
reg     [1:0]           xyz_reg;        // XYZ signal delay reg
reg     [1:0]           h_reg;          // H delay register
reg     [1:0]           v_reg;          // V delay register
reg     [1:0]           f_reg;          // F delay register
reg     [15:0]          delay_rst;      // generates a delayed reset to block RAMs
wire                    reset;          // delayed reset signal

//
// Video format select input register
//
always @ (posedge clk or posedge rst)
    if (rst)
        std_q <= 0;
    else if (ce)
        std_q <= std;
        
assign std_change = std != std_q;

//----------------------------------------------------------------------------
// Vertical section
//
multigenHD_vert VERT (
    .clk            (clk),
    .rst            (reset),
    .ce             (ce),
    .std            (std_q),
    .pattern        (pattern),
    .h_counter_lsb  (h_counter_lsb),
    .v_inc          (v_inc),
    .v_band         (v_band),
    .v              (v_int),
    .f              (f_int),
    .first_line     (first_line),
    .y_ramp_inc_sel (y_ramp_inc_sel),
    .line_num       (v_counter));



//----------------------------------------------------------------------------
// Horizontal section
//

multigenHD_horz HORZ (
    .clk            (clk),
    .rst            (reset),
    .ce             (ce),
    .std            (std_q),
    .pattern        (pattern),
    .user_opt       (user_opt),
    .first_line     (first_line),
    .f              (f_int),
    .v_inc          (v_inc),
    .trs            (trs_int),
    .xyz            (xyz_int),
    .h              (h_int),
    .h_region       (h_region),
    .h_counter_lsb  (h_counter_lsb));   

//----------------------------------------------------------------------------
// Output section
//

multigenHD_output OUTGEN (
    .clk            (clk),
    .rst            (reset),
    .ce             (ce),
    .h_region       (h_region),
    .v_band         (v_band),
    .h_counter_lsb  (h_counter_lsb),
    .y_ramp_inc_sel (y_ramp_inc_sel),
    .y              (y_int),
    .c              (c_int));

//
// Output registers
//
// These registers delay various output signals so that they all have the same
// amount of delay and are synchronized at the output of the module.
//
always @ (posedge clk or posedge reset)
    if (reset)
        begin
            y <= 0;
            c <= 0;
            f_reg <= 0;
            v_reg <= 0;
            h_reg <= 0;
            trs_reg <= 0;
            xyz_reg <= 0;
            line_num <= 0;
        end
    else if (ce)
        begin
            y <= y_int;
            c <= c_int;
            f_reg <= {f_reg[0], f_int};
            v_reg <= {v_reg[0], v_int};
            h_reg <= {h_reg[0], h_int};
            trs_reg <= {trs_reg[0], trs_int};
            xyz_reg <= {xyz_reg[0], xyz_int};
            line_num <= v_counter;
        end

assign field = f_reg[1];
assign v_blank = v_reg[1];
assign h_blank = h_reg[1];
assign trs = trs_reg[1];
assign xyz = xyz_reg[1];

//
// Reset generator
//
// This circuit keeps the module reset for about 64 clock cycles after the rst
// input to the module goes away. This insures that the module starts up in an
// orderly fashion. Also, the reset signal is asserted whenever the std inputs
// change, insuring that the video pattern generator begins at a good state
// when the video format changes.
//

always @ (posedge clk or posedge rst)
    if (rst)
        delay_rst <= 0;
    else
        delay_rst <= {delay_rst[14:0], 1'b1};

assign reset = rst | ~delay_rst[15] | std_change;

endmodule
