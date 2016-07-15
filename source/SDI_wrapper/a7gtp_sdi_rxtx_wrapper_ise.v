// (c) Copyright 2011 - 2013 Xilinx, Inc. All rights reserved.
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
// \   \   \/     Version: $Revision: #1 $
//  \   \         
//  /   /         Filename: $File: //Groups/video_ip/demos/A7/xapp1097_a7_sdi_demos/Verilog/SDI_wrapper/a7gtp_sdi_rxtx_wrapper_ise.v $
// /___/   /\     Timestamp: $DateTime: 2013/09/30 13:31:35 $
// \   \  /  \
//  \___\/\___\
//
// Description:
//  This wrapper file includes a SMPTE SDI core and the series-7 GTP control module.
//  It implements a single SDI RX and a single SDI TX when connected to a series-7
//  GTP transceiver.
//
// Note that this version of the wrapper works with the SMPTE SD/HD/3G-SDI core
// version 1.0, but is not compatible with newer versions of the core. 
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

`timescale 1ns / 1ps

module a7gtp_sdi_rxtx_wrapper #(
    parameter FXDCLK_FREQ               = 27000000, // Frequency, in Hertz, of fixed frequency clock
    parameter DRPCLK_PERIOD             = 37,       // Period of drpclk in ns, always round down
    parameter PLLLOCK_TIMEOUT_PERIOD    = 2000000,  // Period of PLLLOCK timeout in ns, defaults to 2ms
    parameter RESET_TIMEOUT_PERIOD      = 500000,   // Period of GTP RESETDONE timeout in ns, defaults to 500us
    parameter TIMEOUT_CNTR_BITWIDTH     = 16,       // Width in bits of timeout counter
    parameter RETRY_CNTR_BITWIDTH       = 8,        // Width in bits of the retry counter
    parameter TXSYSCLKSEL_M_0           = 2'b00,    // Value to put on TXSYSCLKSEL when tx_m is 0, default selects PLL0
    parameter TXSYSCLKSEL_M_1           = 2'b11)    // Value to put on TXSYSCLKSEL when tx_m is 1, default selects PLL1
(

// RX ports -- ports are synchronous with rx_usrclk unless otherwise noted                                                  (clock domain)
    input   wire        clk,                    // fixed frequency clock SDI RX bit rate detection
    input   wire        rx_rst,                 // sync reset for SDI RX data path
    input   wire        rx_usrclk,              // rxusrclk input
    input   wire        rx_gtp_full_reset,      // causes full reset of the GTP RX including PLL                            (gtp_drpclk)
    input   wire        rx_gtp_reset,           // causes reset of GTP RX, not including PLL                                (gtp_drpclk),
    output  wire        rx_fabric_reset_out,    // asserted High until GTP RX is fully initialized
    input   wire        rx_refclk_stable,       // assert High when the reference clock to RX PLL is stable                 (async)
    input   wire        rx_frame_en,            // 1 = enable framer position update
    input   wire [2:0]  rx_mode_en,             // unary enable bits for SDI mode search {3G, SD, HD} 1=enable, 0=disable
    output  wire [1:0]  rx_mode,                // 00=HD, 01=SD, 10=3G
    output  wire        rx_mode_hd,             // 1 = HD mode      
    output  wire        rx_mode_sd,             // 1 = SD mode
    output  wire        rx_mode_3g,             // 1 = 3G mode
    output  wire        rx_mode_locked,         // auto mode detection locked
    output  wire        rx_bit_rate,            // 0 = 1000/1000, 1 = 1000/1001
    output  wire        rx_t_locked,            // transport format detection locked
    output  wire [3:0]  rx_t_family,            // transport format family
    output  wire [3:0]  rx_t_rate,              // transport frame rate
    output  wire        rx_t_scan,              // transport scan: 0=interlaced, 1=progressive
    output  wire        rx_level_b_3g,          // 0 = level A, 1 = level B
    output  wire        rx_ce_sd,               // clock enable for SD, always 1 for HD & 3G
    output  wire        rx_nsp,                 // framer new start position
    output  wire [10:0] rx_line_a,              // line number for HD & 3G (link A for level B)
    output  wire [31:0] rx_a_vpid,              // payload ID packet ds1 for 3G or HD-SDI
    output  wire        rx_a_vpid_valid,        // 1 = rx_a_vpid is valid
    output  wire [31:0] rx_b_vpid,              // video payload ID packet data from data stream 2
    output  wire        rx_b_vpid_valid,        // 1 = rx_b_vpid is valid
    output  wire        rx_crc_err_a,           // CRC error for HD & 3G
    output  wire [9:0]  rx_ds1a,                // data stream 1A: SD=Y/C, HD=Y, 3GA=ds1, 3GB=Y link A
    output  wire [9:0]  rx_ds2a,                // data stream 2A: HD=C, 3GA=ds2, 3GB=C link A
    output  wire        rx_eav,                 // 1 during XYZ word of EAV
    output  wire        rx_sav,                 // 1 during XYZ word of SAV
    output  wire        rx_trs,                 // 1 during all 4 words of EAV and SAV
    output  wire [10:0] rx_line_b,              // line number of 3G level B link B
    output  wire        rx_dout_rdy_3g,         // 3G data ready: 1 for level A, asserted every other clock for level B
    output  wire        rx_crc_err_b,           // CRC error for link B (level B only)
    output  wire [9:0]  rx_ds1b,                // data stream 1B: 3G level B only = Y link B
    output  wire [9:0]  rx_ds2b,                // data stream 2B: 3G level B only = C link B
    input   wire [15:0] rx_edh_errcnt_en,       // enables various errors to increment rx_edh_errcnt
    input   wire        rx_edh_clr_errcnt,      // clears rx_edh_errcnt
    output  wire        rx_edh_ap,              // 1 = AP CRC error detected previous field
    output  wire        rx_edh_ff,              // 1 = FF CRC error detected previous field
    output  wire        rx_edh_anc,             // 1 = ANC checksum error detected
    output  wire [4:0]  rx_edh_ap_flags,        // EDH AP flags received in last EDH packet
    output  wire [4:0]  rx_edh_ff_flags,        // EDH FF flags received in last EDH packet
    output  wire [4:0]  rx_edh_anc_flags,       // EDH ANC flags received in last EDH packet
    output  wire [3:0]  rx_edh_packet_flags,    // EDH packet error condition flags
    output  wire [15:0] rx_edh_errcnt,          // EDH error counter
    output  wire        rx_change_done,         // 1 when rx_mode change has completed successfully                         (drpclk)
    output  wire        rx_change_fail,         // 1 when rx_mode change failed                                             (drpclk)
    output  wire [2:0]  rx_change_fail_code,    // failure code when rx_change_fail = 1                                     (drpclk)

// TX ports -- ports are synchronous with tx_usrclk unless otherwise noted                                                  (clock domain)
    input   wire        tx_rst,                 // sync reset for SDI TX data path
    input   wire        tx_usrclk,              // clock input
    input   wire        tx_gtp_full_reset,      // causes a full reset of the GTP TX including PLL                          (drpclk)
    input   wire        tx_gtp_reset,           // causes a reset of the GTP TX, not including the PLL                      (drpclk)
    input   wire        tx_refclk_stable,       // assert high when reference clock to the TX PLL is stable                 (async)
    input   wire [2:0]  tx_ce,                  // clock enable - 3 identical copies
    input   wire        tx_din_rdy,             // input data ready for level B, must be 1 for all other modes
    input   wire [1:0]  tx_mode,                // 00 = HD, 01 = SD, 10 = 3G
    input   wire        tx_level_b_3g,          // 0 = level A, 1 = level B
    input   wire        tx_m,                   // 0 = select 148.5 MHz refclk, 1 = select 148.35 MHz refclk                (async)
    input   wire        tx_insert_crc,          // 1 = insert CRC for HD and 3G
    input   wire        tx_insert_ln,           // 1 = insert LN for HD and 3G
    input   wire        tx_insert_edh,          // 1 = generate & insert EDH for SD 
    input   wire        tx_insert_vpid,         // 1 = enable ST352 PID packet insert
    input   wire        tx_overwrite_vpid,      // 1 = overwrite existing ST352 packets
    input   wire [9:0]  tx_video_a_y_in,        // Data stream Y link A input: SD Y/C, HD & 3GA Y in, 3GB A Y in
    input   wire [9:0]  tx_video_a_c_in,        // Data stream C link A input: HD & 3GA C in, 3GB A C in
    input   wire [9:0]  tx_video_b_y_in,        // 3G level B only: Data stream Y link B input
    input   wire [9:0]  tx_video_b_c_in,        // 3G level B only: Data stream C link B input
    input   wire [10:0] tx_line_a,              // current line number for link A
    input   wire [10:0] tx_line_b,              // current line number for link B
    input   wire [7:0]  tx_vpid_byte1,          // ST352 user data word 1
    input   wire [7:0]  tx_vpid_byte2,          // ST352 user data word 2
    input   wire [7:0]  tx_vpid_byte3,          // ST352 user data word 3
    input   wire [7:0]  tx_vpid_byte4a,         // ST352 user data word 4 for link A
    input   wire [7:0]  tx_vpid_byte4b,         // ST352 user data word 4 for link B
    input   wire [10:0] tx_vpid_line_f1,        // insert ST352 packet on this line in field 1
    input   wire [10:0] tx_vpid_line_f2,        // insert ST352 packet on this line in field 2
    input   wire        tx_vpid_line_f2_en,     // enable ST352 packet insertion in field 2
    output  wire [9:0]  tx_ds1a_out,            // data stream 1, link A out
    output  wire [9:0]  tx_ds2a_out,            // data stream 2, link A out
    output  wire [9:0]  tx_ds1b_out,            // data stream 1, link B out
    output  wire [9:0]  tx_ds2b_out,            // data stream 2, link B out
    input   wire        tx_use_dsin,            // 0=use the internal data streams, 1=use the tx_dsxx_in data streams
    input   wire [9:0]  tx_ds1a_in,             // data stream 1 link A in: SD Y/C, HD Y, 3G Y, dual-link A Y
    input   wire [9:0]  tx_ds2a_in,             // data stream 2 link A in: HD C, 3G C, dual-link A C
    input   wire [9:0]  tx_ds1b_in,             // data stream 1 link B in: dual-link B Y
    input   wire [9:0]  tx_ds2b_in,             // data stream 2 link B in: dual-link B C
    output  wire        tx_ce_align_err,        // 1 if ce 5/6/5/6 cadence is broken
    output  wire        tx_slew,                // slew rate control signal for SDI cable driver
    output  wire        tx_change_done,         // 1 when txrate or txsysclksel changes complete successfully               (drpclk)
    output  wire        tx_change_fail,         // 1 when txrate or txsysclksel changes fail                                (drpclk)
    output  wire [2:0]  tx_change_fail_code,    // failure code when tx_change_fail = 1                                     (drpclk)

// RX GTP transceiver ports -- connect these to the GTP associated with the SDI RX
    input   wire [19:0] gtp_rxdata,             // connect to RXDATA port of GTP
    input   wire        gtp_rxplllock,          // connect to PLLxLOCK output of PLL used by RX
    input   wire        gtp_rxresetdone,        // connect to the RXRESETDONE port of the GTP
    output  wire        gtp_gtrxreset,          // connect to GTRXRESET port of GTP
    output  wire        gtp_rxpllreset,         // connect to PLLxRESET of PLL used by RX
    output  wire [2:0]  gtp_rxrate,             // connect to RXRATE port of GTP
    input   wire        gtp_rxratedone,         // connect to RXRATEDONE port of GTP
    output  wire        gtp_rxcdrhold,          // connect to RXCDRHOLD port of GTP
    input   wire        gtp_drpclk,             // connect to same clock driving the DRPCLK port of GTP
    input   wire        gtp_drprdy,             // connect to DRPRDY port of GTP
    input   wire        gtp_drpbusy,            // connect to DRP_BUSY port of the GTP
    output  wire [8:0]  gtp_drpaddr,            // connect to DRPADDR port of GTP
    output  wire [15:0] gtp_drpdi,              // connect to DRPDI port of GTP
    output  wire        gtp_drpen,              // connect to DRPEN port of GTP
    output  wire        gtp_drpwe,              // connect to DRPWE port of GTP
    output  wire        gtp_rxuserrdy,          // connect to RXUSERRDY port of GTP

// TX GTP transceiver ports -- connect tehse to the GTP associated with the SDI TX
    output  wire [19:0] gtp_txdata,             // connect to TXDATA port of GTP
    input   wire        gtp_txplllock,          // connect to PLLxLOCK output of PLL(s) used by TX
    input   wire        gtp_txresetdone,        // connect to TXRESETDONE output of GTP
    input   wire        gtp_txratedone,         // connect to TXRATEDONE output of GTP
    output  wire        gtp_txuserrdy,          // connect to TXUSERRDY port of GTP
    output  wire        gtp_gttxreset,          // connect to GTTXRESET input of GTP
    output  wire        gtp_txpllreset,         // connect to PLLxRESET of PLL(s) used by TX
    output  wire [2:0]  gtp_txrate,             // connect to TXRATE input of GTP
    output  wire [1:0]  gtp_txsysclksel         // connect to TXSYSCLKSEL port of GTP when doing dynamic clock source switching
);

//
// Internal signals
//
wire [9:0]      rx_sd_rxdata;
wire            rx_sd_data_strobe;
wire            rx_m;
reg  [4:0]      rx_userrdy_gen = 5'b11111;
reg  [4:0]      tx_userrdy_gen = 5'b11111;
wire [1:0]      rx_mode_int;
wire            rx_fabric_reset_int;

//------------------------------------------------------------------------------
// SMPTE SDI core
//
smpte_sdi SDIRXTX (     // Edit this line to instance the name of the core as generated by CORE Generator
    .rx_rst             (rx_rst | rx_fabric_reset_int),
    .rx_usrclk          (rx_usrclk),
    .rx_data_in         (gtp_rxdata),
    .rx_sd_data_in      (rx_sd_rxdata),
    .rx_sd_data_strobe  (rx_sd_data_strobe),
    .rx_frame_en        (rx_frame_en),
    .rx_mode_en         (rx_mode_en),
    .rx_mode            (rx_mode_int),
    .rx_mode_HD         (rx_mode_hd),
    .rx_mode_SD         (rx_mode_sd),
    .rx_mode_3G         (rx_mode_3g),
    .rx_mode_detect_en  (1'b1),
    .rx_mode_locked     (rx_mode_locked),
    .rx_forced_mode     (2'b00),
    .rx_bit_rate        (rx_m),
    .rx_t_locked        (rx_t_locked),
    .rx_t_family        (rx_t_family),
    .rx_t_rate          (rx_t_rate),
    .rx_t_scan          (rx_t_scan),
    .rx_level_b_3G      (rx_level_b_3g),
    .rx_ce_sd           (rx_ce_sd),
    .rx_nsp             (rx_nsp),
    .rx_line_a          (rx_line_a),
    .rx_a_vpid          (rx_a_vpid),
    .rx_a_vpid_valid    (rx_a_vpid_valid),
    .rx_b_vpid          (rx_b_vpid),
    .rx_b_vpid_valid    (rx_b_vpid_valid),
    .rx_crc_err_a       (rx_crc_err_a),
    .rx_ds1a            (rx_ds1a),
    .rx_ds2a            (rx_ds2a),
    .rx_eav             (rx_eav),
    .rx_sav             (rx_sav),
    .rx_trs             (rx_trs),
    .rx_line_b          (rx_line_b),
    .rx_dout_rdy_3G     (rx_dout_rdy_3g),
    .rx_crc_err_b       (rx_crc_err_b),
    .rx_ds1b            (rx_ds1b),
    .rx_ds2b            (rx_ds2b),
    .rx_edh_errcnt_en   (rx_edh_errcnt_en),
    .rx_edh_clr_errcnt  (rx_edh_clr_errcnt),
    .rx_edh_ap          (rx_edh_ap),
    .rx_edh_ff          (rx_edh_ff),
    .rx_edh_anc         (rx_edh_anc),
    .rx_edh_ap_flags    (rx_edh_ap_flags),
    .rx_edh_ff_flags    (rx_edh_ff_flags),
    .rx_edh_anc_flags   (rx_edh_anc_flags),
    .rx_edh_packet_flags(rx_edh_packet_flags),
    .rx_edh_errcnt      (rx_edh_errcnt),

    .tx_rst             (tx_rst),
    .tx_usrclk          (tx_usrclk),
    .tx_ce              (tx_ce),
    .tx_din_rdy         (tx_din_rdy),
    .tx_mode            (tx_mode),
    .tx_level_b_3G      (tx_level_b_3g),
    .tx_insert_crc      (tx_insert_crc),
    .tx_insert_ln       (tx_insert_ln),
    .tx_insert_edh      (tx_insert_edh),
    .tx_insert_vpid     (tx_insert_vpid),
    .tx_overwrite_vpid  (tx_overwrite_vpid),
    .tx_video_a_y_in    (tx_video_a_y_in),
    .tx_video_a_c_in    (tx_video_a_c_in),
    .tx_video_b_y_in    (tx_video_b_y_in),
    .tx_video_b_c_in    (tx_video_b_c_in),
    .tx_line_a          (tx_line_a),
    .tx_line_b          (tx_line_b),
    .tx_vpid_byte1      (tx_vpid_byte1),
    .tx_vpid_byte2      (tx_vpid_byte2),
    .tx_vpid_byte3      (tx_vpid_byte3),
    .tx_vpid_byte4a     (tx_vpid_byte4a),
    .tx_vpid_byte4b     (tx_vpid_byte4b),
    .tx_vpid_line_f1    (tx_vpid_line_f1),
    .tx_vpid_line_f2    (tx_vpid_line_f2),
    .tx_vpid_line_f2_en (tx_vpid_line_f2_en),
    .tx_ds1a_out        (tx_ds1a_out),
    .tx_ds2a_out        (tx_ds2a_out),
    .tx_ds1b_out        (tx_ds1b_out),
    .tx_ds2b_out        (tx_ds2b_out),
    .tx_use_dsin        (tx_use_dsin),
    .tx_ds1a_in         (tx_ds1a_in),
    .tx_ds2a_in         (tx_ds2a_in),
    .tx_ds1b_in         (tx_ds1b_in),
    .tx_ds2b_in         (tx_ds2b_in),
    .tx_sd_bitrep_bypass(1'b0),
    .tx_txdata          (gtp_txdata),
    .tx_ce_align_err    (tx_ce_align_err));

assign rx_bit_rate = rx_m;
assign rx_mode = rx_mode_int;
assign rx_fabric_reset_out = rx_fabric_reset_int;

//------------------------------------------------------------------------------
// This module generates the GTTXRESET and GTRXRESET signals to the GTP. It
// also controls the RXCDRHOLD to place the CDR into lock to reference mode
// during SD-SDI mode. It also generates the RXRATE and TXRATE signals appropriately
// based on which SDI mode the RX and TX are in. Finally, it has a RX bit rate
// detection module that determines which bit rate is being received by the RX.
//
a7gtp_sdi_control #(
    .FXDCLK_FREQ            (FXDCLK_FREQ),
    .DRPCLK_PERIOD          (DRPCLK_PERIOD),
    .PLLLOCK_TIMEOUT_PERIOD (PLLLOCK_TIMEOUT_PERIOD),
    .RESET_TIMEOUT_PERIOD   (RESET_TIMEOUT_PERIOD),
    .TIMEOUT_CNTR_BITWIDTH  (TIMEOUT_CNTR_BITWIDTH),
    .RETRY_CNTR_BITWIDTH    (RETRY_CNTR_BITWIDTH))
GTP_CTRL (
    .txusrclk           (tx_usrclk),
    .txmode             (tx_mode),
    .tx_full_reset      (tx_gtp_full_reset),
    .gttxreset_in       (tx_gtp_reset),
    .tx_refclk_stable   (tx_refclk_stable),
    .tx_pll_lock        (gtp_txplllock),
    .tx_m               (tx_m),
    .txsysclksel_m_0    (TXSYSCLKSEL_M_0),
    .txsysclksel_m_1    (TXSYSCLKSEL_M_1),
    .txresetdone        (gtp_txresetdone),
    .txratedone         (gtp_txratedone),
    .gttxreset_out      (gtp_gttxreset),
    .tx_pll_reset       (gtp_txpllreset),
    .txrate             (gtp_txrate),
    .txsysclksel        (gtp_txsysclksel),
    .txslew             (tx_slew),
    .tx_change_done     (tx_change_done),
    .tx_change_fail     (tx_change_fail),
    .tx_change_fail_code(tx_change_fail_code),

    .rxusrclk           (rx_usrclk),
    .fxdclk             (clk),
    .rxmode             (rx_mode_int),
    .rx_full_reset      (rx_gtp_full_reset),
    .gtrxreset_in       (rx_gtp_reset),
    .rx_refclk_stable   (rx_refclk_stable),
    .rx_pll_lock        (gtp_rxplllock),
    .rxresetdone        (gtp_rxresetdone),
    .rxratedone         (gtp_rxratedone),
    .gtrxreset_out      (gtp_gtrxreset),
    .rx_pll_reset       (gtp_rxpllreset),
    .rx_fabric_reset    (rx_fabric_reset_int),
    .rxrate             (gtp_rxrate),
    .rxcdrhold          (gtp_rxcdrhold),
    .rx_m               (rx_m),
    .rx_change_done     (rx_change_done),
    .rx_change_fail     (rx_change_fail),
    .rx_change_fail_code(rx_change_fail_code),

    .dru_rst            (rx_rst),
    .data_in            (gtp_rxdata),
    .sd_data            (rx_sd_rxdata),
    .sd_data_strobe     (rx_sd_data_strobe),
    .recclk_txdata      (),
   
    .drpclk             (gtp_drpclk),
    .drpbusy            (gtp_drpbusy),
    .drprdy             (gtp_drprdy),
    .drpaddr            (gtp_drpaddr),
    .drpdi              (gtp_drpdi),
    .drpen              (gtp_drpen),
    .drpwe              (gtp_drpwe));


//------------------------------------------------------------------------------
// It is a requirement to assert the TXUSERRDY and RXUSERRDY signals at least
// 5 cycles of their respective USRCLK after their respective GTP reset is negated.
//
always @ (posedge tx_usrclk or posedge gtp_gttxreset)
    if (gtp_gttxreset)
        tx_userrdy_gen <= 5'b11111;
    else
        tx_userrdy_gen <= {tx_userrdy_gen[3:0], 1'b0};

assign gtp_txuserrdy = ~tx_userrdy_gen[4];

always @ (posedge rx_usrclk or posedge gtp_gtrxreset)
    if (gtp_gtrxreset)
        rx_userrdy_gen <= 5'b11111;
    else
        rx_userrdy_gen <= {rx_userrdy_gen[3:0], 1'b0};

assign gtp_rxuserrdy = ~rx_userrdy_gen[4];

endmodule

    
