// (c) Copyright 2011 - 2014 Xilinx, Inc. All rights reserved.
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
// \   \   \/     Version: $Revision: $
//  \   \         
//  /   /         Filename: $File: $
// /___/   /\     Timestamp: $DateTime: $
// \   \  /  \
//  \___\/\___\
//
// Description:
//  This module implements the GTP specific logic to be used when implementing
//  SDI interfaces with 7-series GTP transceiver. The functions implemented by
//  this control module are:
//      GTP PLL reset logic
//      GTP RX reset logic
//      GTP TX reset logic
//      GTP TXSYSCLKSEL and TXRATE dynamic change sequence logic
//      GTP RXOUT_DIV attribute dynamic change through DRP to match SDI mode
//      GTP RXCDR_CFG attribute dynamic change through DRP to match SDI mode
//      NI-DRU for recovering SD-SDI data at 270 Mb/s
//      RX bit rate detection
//
// Previous versions of this module used RXRATE to change the RX PLL output
// divider when switching the GTP RX line rate between HD & 3G/SD modes. This
// version uses the RXOUT_DIV attribute dynamically changed through the DRP for
// more reliable operation. Thus, the rxrate and rxratedone ports have been
// removed from this module. The drpdo port has been added.
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

`timescale 1 ns / 1 ns

module a7gtp_sdi_control #( 
    parameter FXDCLK_FREQ               = 27000000, // Frequency, in hertz, of fxdclk
    parameter DRPCLK_PERIOD             = 13,       // Period of drpclk in ns, always round down
    parameter PLLLOCK_TIMEOUT_PERIOD    = 2000000,  // Period of PLLLOCK timeout in ns, defaults to 2ms
    parameter RESET_TIMEOUT_PERIOD      = 500000,   // Period of GTP RESETDONE timeout in ns, defaults to 500us
    parameter TIMEOUT_CNTR_BITWIDTH     = 19,       // Width in bits of timeout counter
    parameter RETRY_CNTR_BITWIDTH       = 8)        // Width in bits of the retry counter
(

// TX related signals                                                                                               (clock domain)
    input   wire        txusrclk,                   // Connect to same clock as drives GTP TXUSRCLK2
    input   wire [1:0]  txmode,                     // TX mode select: 00=HD, 01=SD, 10=3G                          (txusrclk)
    input   wire        tx_full_reset,              // Causes full reset sequence of the GTP TX including the PLL   (drpclk)
    input   wire        gttxreset_in,               // Causes GTTXRESET sequence
    input   wire        tx_refclk_stable,           // Assert High when PLL reference clock is stable               (async)
    input   wire        tx_pll_lock,                // Connect to PLL{0|1}LOCK output of GTP                        (async)
    input   wire        tx_m,                       // TX bit rate select (0=1000/1000, 1=1000/1001)                (async)
    input   wire [1:0]  txsysclksel_m_0,            // Value to output on TXSYSCLKSEL when tx_m is 0                (drpclk)
    input   wire [1:0]  txsysclksel_m_1,            // Value to output on TXSYSCLKSEL when tx_m is 1                (drpclk)
    input   wire        txresetdone,                // Connect to the TXRESETDONE port of the GTP                   (async)
    input   wire        txratedone,                 // Connect to the TXRATEDONE port of the GTP                    (async)
    output  wire        gttxreset_out,              // Connect to GTTXRESET input of GTP                            (drpclk)
    output  wire        tx_pll_reset,               // Connect to PLL{0|1}RESET of GTP                              (drpclk)
    output  wire [2:0]  txrate,                     // Connect to TXRATE input of GTP                               (txusrclk)
    output  wire [1:0]  txsysclksel,                // Connect to TXSYSCLKSEL input of GTP                          (drpclk)
    output  reg         txslew = 1'b0,              // Slew rate control signal for SDI cable driver                (txusrclk)
    output  wire        tx_change_done,             // 1 when txrate or txsysclksel changes are complete            (drpclk)
    output  wire        tx_change_fail,             // 1 when txrate or txsysclksel changes fail                    (drpclk)
    output  wire [2:0]  tx_change_fail_code,        // TX change failure code

// RX related signals
    input   wire        rxusrclk,                   // Connect to same clock as drives GTP RXUSRCLK2
    input   wire        fxdclk,                     // Used for RX bit rate detection (usually same as drpclk)
    input   wire [1:0]  rxmode,                     // RX mode select: 00=HD, 01=SD, 10=3G                          (rxusrclk)
    input   wire        rx_full_reset,              // Causes full reset sequence of the GTP RX including the PLL   (drpclk)
    input   wire        gtrxreset_in,               // Causes GTRXRESET sequence                                    (drpclk)
    input   wire        rx_refclk_stable,           // Assert High when PLL reference clock is stable               (async)
    input   wire        rx_pll_lock,                // Connect to PLL{0|1}LOCK output of GTP                        (async)
    input   wire        rxresetdone,                // Connect to RXRESETDONE port of the GTP                       (async)
    output  wire        gtrxreset_out,              // Connect to GTRXRESET input of GTP                            (drpclk)
    output  wire        rx_pll_reset,               // Connect to PLL{0|1}RESET port of GTP                                     (drpclk)
    output  wire        rx_fabric_reset,            // Connect to rx_rst input of SDI core                          (rxusrclk)
    output  wire        rxcdrhold,                  // Connect to RXCDRHOLD port of GTP                             (drpclk)
    output  wire        rx_m,                       // Indicates received bit rate: 1=/1.001 rate, 0 = /1 rate      (rxusrclk)
    output  wire        rx_change_done,             // 1 when rx_mode change has completed successfully             (drpclk)
    output  wire        rx_change_fail,             // 1 when rx_mode change failed                                 (drpclk)
    output  reg [2:0]   rx_change_fail_code = 3'b000,// RX change failure code

// SD-SDI DRU signals
    input   wire         dru_rst,                   // Sync reset input for DRU
    input   wire [19:0]  data_in,                   // 11X oversampled data input vector
    output  reg  [9:0]   sd_data = 0,               // Recovered SD-SDI data
    output  wire         sd_data_strobe,            // Asserted high when an output data word is ready
    output  wire [19:0]  recclk_txdata,             // Optional output data for recovering a clock using transmitter

// DRP signals -- The DRP is used to change the RXCDR_CFG attribute depending
// on the RX SDI mode. Connect these signal to the DRP of the GTP associated
// with the SDI RX. Even if the RX section of the GTP is not used, these
// signals must be properly connected to the GTP.
    input   wire        drpclk,                     // Connect to GTP DRP clock
    input   wire        drpbusy,                    // Connect to GTP DRP_BUSY port
    input   wire        drprdy,                     // Connect to GTP DRPRDY port
    output  wire [8:0]  drpaddr,                    // Connect to GTP DRPADDR port
    output  wire [15:0] drpdi,                      // Connect to GTP DRPDI port
    input   wire [15:0] drpdo,                      // Connect to GTH DRPDO port
    output  wire        drpen,                      // Connect to GTP DRPEN port
    output  wire        drpwe                       // Connect to GTP DRPWE port
);

//
// These parameters define the encoding of the txmode and rxmode ports.
//
localparam MODE_SD = 2'b01;

//
// Internal signal definitions
//
(* shreg_extract = "NO" *)  
reg  [2:0]                  rx_m_sss = 3'b000;
wire                        rx_m_int;
reg  [1:0]                  rxmode_reg = 2'b00;
wire [3:0]                  samv;
wire [9:0]                  sam;
wire [9:0]                  dru_dout;
wire                        dru_drdy;
reg                         dru_enable = 1'b0;
wire                        init_drp_busy;
wire                        drp_gtrxreset;      // gtrxreset request from DRP controller
wire                        drp_full_reset;     // full reset request from DRP controller
wire                        rx_init_busy;
wire                        rx_init_fail;
wire                        rx_drp_fail;
wire                        drp_priority_req;
wire                        rx_change_done_int;
wire                        rx_drp_busy;
wire                        rx_busy;
wire                        rx_drp_req;
wire                        rst;
wire                        rx_init_fail_code;
wire [2:0]                  rx_drp_fail_code;
wire                        rx_drp_done;

//------------------------------------------------------------------------------
// rxmode input register
//
always @ (posedge rxusrclk)
    rxmode_reg <= rxmode;

//------------------------------------------------------------------------------
// RX bit rate detection
//
// This logic distinguishes between the 1000/1000 and the 1000/1001 bit rates
// of the incoming SDI signal by timing the RXUSRCLK relative to a fixed
// frequency clk, fxdclk.
//
sdi_rate_detect #(
    .REFCLK_FREQ     (FXDCLK_FREQ))
RATE0 (
    .refclk     (fxdclk),
    .recvclk    (rxusrclk),
    .std        (rxmode_reg[1]),
    .rate_change(),
    .enable     (rxresetdone),
    .drift      (),
    .rate       (rx_m_int));

always @ (posedge rxusrclk)
    rx_m_sss <= {rx_m_sss[1:0], rx_m_int};

assign rx_m = rx_m_sss[2];


//------------------------------------------------------------------------------
// 11X oversampling data recovery unit for SD-SDI
//

//
// Only enable the DRU when in SD-SDI mode by generating a dru_enable clock
// enable. This saves power by disabling the DRU when it is not being used.
//
always @ (posedge rxusrclk)
    if (rxmode_reg == 2'b01)
        dru_enable <= 1'b1;
    else
        dru_enable <= 1'b0;

dru NIDRU (
    .DT_IN      (data_in),
    .CENTER_F   (37'b0000111010001101011111110100101111011),
    .G1         (5'b00110),
    .G1_P       (5'b10000),
    .G2         (5'b00111),
    .CLK        (rxusrclk),
    .RST        (~dru_rst),         // The NI-DRU reset is asserted low
    .RST_FREQ   (1'b1),
    .VER        (),
    .EN         (dru_enable),
    .INTEG      (),
    .DIRECT     (),
    .CTRL       (),
    .PH_OUT     (),
    .RECCLK     (recclk_txdata),
    .SAMV       (samv),
    .SAM        (sam));

dru_bshift10to10 DRUBSHIFT (
    .CLK        (rxusrclk),
    .RST        (~dru_rst),
    .DIN        ({8'b0, sam[1:0]}),
    .DV         ({2'b0, samv[1:0]}),
    .DV10       (dru_drdy),
    .DOUT10     (dru_dout));

always @ (posedge rxusrclk)
    if (dru_drdy)
        sd_data <= dru_dout;

assign sd_data_strobe = dru_drdy;

//------------------------------------------------------------------------------
// RX control logic
//
// This logic controls the RXRATE and GTRXRESET signals to the GTP, the DRP
// of the GTP, and the rx_pll_reset signal to correctly reset the GTP RX and
// its associated PLL and change the bit rate of the GTP in response to changes
// on the rxmode input. These functions are all carefully sequenced so as to
// not cause conflicts on the DRP which is also used by the state machines
// internal to the GTP wrapper.
//

//
// a7gtp_sdi_rx_reset_control
//
// This module controls resets of the GTP RX and the PLL in response to the
// assertion of the full_reset or gtrxreset_in signals.
//
a7gtp_sdi_rx_reset_control #(
    .DRPCLK_PERIOD      (DRPCLK_PERIOD))
RXRST (
    .drpclk             (drpclk),
    .refclk_stable      (rx_refclk_stable),
    .pll_lock           (rx_pll_lock),
    .rxresetdone        (rxresetdone),
    .drp_busy_in        (init_drp_busy),                    // from arbiter r_drpbusy_out
    .gtrxreset_in       (gtrxreset_in | drp_gtrxreset),
    .full_reset         (drp_full_reset | rx_full_reset),
    .drp_busy_out       (rx_init_busy),                     // to arbiter r_busy_in
    .gtrxreset          (gtrxreset_out),
    .pll_reset          (rx_pll_reset),
    .done               (rx_change_done_int),
    .fail               (rx_init_fail),
    .fail_code          (rx_init_fail_code),
    .drp_priority_req   (drp_priority_req));

assign rx_change_fail = rx_init_fail | rx_drp_fail;
assign rx_change_done = rx_change_done_int & rx_drp_done;

always @ (posedge drpclk)
    if (rx_init_fail && rx_init_fail_code == 1'b0)
        rx_change_fail_code <= 3'b000;
    else if (rx_init_fail && rx_init_fail_code == 1'b1)
        rx_change_fail_code <= 3'b001;
    else if (rx_drp_fail)
        rx_change_fail_code <= rx_drp_fail_code;
    else
        rx_change_fail_code <= 3'b000;
//
// a7gtp_sdi_drp_control
//
// This module controls DRP write cycles to change the RXCDR_CFG attribute of
// the GTP whenever the rxmode input changes. It also controls RXRATE and
// RXCDRHOLD appropriately for rxmode changes.
//
a7gtp_sdi_drp_control DRPCTRL (
    .drpclk             (drpclk),
    .rxusrclk           (rxusrclk),
    .rst                (rst),
    .init_done          (rx_change_done_int),
    .rx_mode            (rxmode),
    .rx_fabric_rst      (rx_fabric_reset),
    .drpbusy_in         (rx_drp_busy),                  // from arbiter m_drpbusy_out
    .drpbusy_out        (rx_busy),                      // to arbiter m_busy_in
    .drpreq             (rx_drp_req),                   // to arbiter rx_drp_req
    .drprdy             (drprdy),
    .drpaddr            (drpaddr),
    .drpdi              (drpdi),
    .drpdo              (drpdo),
    .drpen              (drpen),
    .drpwe              (drpwe),
    .done               (rx_drp_done),
    .fail               (rx_drp_fail),
    .fail_code          (rx_drp_fail_code),
    .rxcdrhold          (rxcdrhold),
    .gtrxreset          (drp_gtrxreset),
    .full_reset         (drp_full_reset));

assign rst = rx_pll_reset;

//
// a7gtp_sdi_drp_arbit
//
// This module arbits access to the GTX DRP. The state machines inside the GTP
// wrapper will grab the DRP bus unconditionally whenever triggered, so the DRP
// arbiter works with the sdi_drp_control and the sdi_rx_reset_control modules
// to coordinate assertion of signals into the GTP that would trigger DRP
// cycles by the state machines in the GTP wrapper.
//
a7gtp_sdi_drp_arbit ARBIT (
    .drpclk             (drpclk),
    .m_req_in           (rx_drp_req),
    .m_busy_in          (rx_busy),
    .m_drpbusy_out      (rx_drp_busy),
    .r_req_in           (drp_priority_req),
    .r_busy_in          (rx_init_busy),
    .r_drpbusy_out      (init_drp_busy),
    .g_drpbusy_in       (drpbusy));

//------------------------------------------------------------------------------
// TX control logic
//
// This module controls the TXRATE, TXSYSCLKSEL, GTTXRESET, and PLLRESET signals
// in order to initialize the GTP TX and to change the SDI mode and the clock
// source of the GTP TX.
//
a7gtp_sdi_tx_control #(
    .CLK_PERIOD         (DRPCLK_PERIOD))
TXCTRL (
    .clk                (drpclk),
    .txusrclk           (txusrclk),
    .refclk_stable      (tx_refclk_stable),
    .pll_lock           (tx_pll_lock),
    .txmode             (txmode),
    .tx_m               (tx_m),
    .txsysclksel_m_0    (txsysclksel_m_0),
    .txsysclksel_m_1    (txsysclksel_m_1),
    .txresetdone        (txresetdone),
    .txratedone         (txratedone),
    .gttxreset_in       (gttxreset_in),
    .full_reset         (tx_full_reset),
    .gttxreset          (gttxreset_out),
    .pll_reset          (tx_pll_reset),
    .txrate             (txrate),
    .txsysclksel        (txsysclksel),
    .done               (tx_change_done),
    .fail               (tx_change_fail),
    .fail_code          (tx_change_fail_code));

always @ (posedge txusrclk)
    txslew <= txmode == MODE_SD;

endmodule