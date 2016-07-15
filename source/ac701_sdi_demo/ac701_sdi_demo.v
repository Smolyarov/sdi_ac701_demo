// (c) Copyright 2011 - 2013 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//------------------------------------------------------------------------------
//   ____  ____
//  /   /\/   /
// /___/  \  /    Vendor: Xilinx
// \   \   \/     Version: $Revision: #1 $
//  \   \         
//  /   /         Filename: $File: //Groups/video_ip/demos/A7/xapp1097_a7_sdi_demos/Verilog/ac701_sdi_demo/ac701_sdi_demo.v $
// /___/   /\     Timestamp: $DateTime: 2013/09/30 13:31:35 $
// \   \  /  \
//  \___\/\___\
//
// Description:
//  This module is the top level HDL file for the Dual SDI demo for the AC701
//  evaluation board.
//
// This version adds some delay before asserting the rx_refclk_stable and
// tx_refclk_stable signals so that the GTP starts reliably after FPGA 
// configuration.
//
//------------------------------------------------------------------------------
//
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

`timescale 1ns / 1ps

module ac701_sdi_demo (
// MGTs
    output  wire        FMC1_HPC_DP0_C2M_N,
    output  wire        FMC1_HPC_DP0_C2M_P,
    input   wire        FMC1_HPC_DP0_M2C_N,
    input   wire        FMC1_HPC_DP0_M2C_P,
    output  wire        FMC1_HPC_DP1_C2M_N,
    output  wire        FMC1_HPC_DP1_C2M_P,
    input   wire        FMC1_HPC_DP1_M2C_N,
    input   wire        FMC1_HPC_DP1_M2C_P,

// MGT REFCLKs
    input   wire        SFP_MGT_CLK0_C_N,           // 148.5 MHz clock from FMC board
    input   wire        SFP_MGT_CLK0_C_P,    
    input   wire        SFP_MGT_CLK1_C_N,           // 148.3516 MHz clock from FMC board
    input   wire        SFP_MGT_CLK1_C_P,
    output  wire        SFP_MGT_CLK_SEL0,           // SFP_MGT_CLK0 clock mux select
    output  wire        SFP_MGT_CLK_SEL1,
    output  wire        PCIE_MGT_CLK_SEL0,          // SFP_MGT_CLK1 clock mux select
    output  wire        PCIE_MGT_CLK_SEL1,

// Inrevium SDI FMC Mezzanine board connections
    output  wire        FMC1_HPC_LA01_CC_P,         // LMH0387 TX0 SPI SS
    output  wire        FMC1_HPC_LA01_CC_N,         // LMH0387 RX0 SPI SS
    output  wire        FMC1_HPC_LA05_P,            // LMH0387 TX1 SPI SS
    output  wire        FMC1_HPC_LA05_N,            // LMH0387 RX1 SPI SS
    output  wire        FMC1_HPC_LA09_P,            // LMH0387 RX/TX2 SPI SS
    output  wire        FMC1_HPC_LA09_N,            // LMH0387 RX/TX3 SPI SS
    output  wire        FMC1_HPC_LA13_P,            // LMH0387 SPI MOSI
    input   wire        FMC1_HPC_LA13_N,            // LMH0387 SPI MISO
    output  wire        FMC1_HPC_LA17_CC_P,         // LMH0387 SPI SCLK

    output  wire        FMC1_HPC_LA06_P,            // LMH0387 TX0 slew rate
    output  wire        FMC1_HPC_LA06_N,            // always drive low
    output  wire        FMC1_HPC_LA10_P,            // LMH0387 TX1 slew rate
    output  wire        FMC1_HPC_LA10_N,            // always drive low
    output  wire        FMC1_HPC_LA14_P,            // LMH0387 TX2 slew rate
    output  wire        FMC1_HPC_LA14_N,            // LMH0387 TX3 slew rate
    output  wire        FMC1_HPC_LA18_CC_P,         // LMH0387 TX2 TX_EN
    output  wire        FMC1_HPC_LA18_CC_N,         // LMH0387 TX3 TX_EN

    output  wire        FMC1_HPC_LA11_P,            // Clock crossbar select S10
    output  wire        FMC1_HPC_LA11_N,            // Clock crossbar select S11
    output  wire        FMC1_HPC_LA15_P,            // Clock crossbar select S20
    output  wire        FMC1_HPC_LA15_N,            // Clock crossbar select S21

    input   wire        FMC1_HPC_CLK0_M2C_P,        // LMH1983 27 MHz clock
    input   wire        FMC1_HPC_CLK0_M2C_N,

    output  wire        FMC1_HPC_LA16_N,            // LMH1983 Hin
    output  wire        FMC1_HPC_LA16_P,            // LMH1983 Vin
    output  wire        FMC1_HPC_LA20_P,            // LMH1983 Fin
    output  wire        FMC1_HPC_LA12_N,            // LMH1983 INIT 

// Debug signals
    output  wire        USER_SMA_GPIO_P,

// Other AC701 board connections
    output  wire        LCD_DB4_LS,                 // LCD display
    output  wire        LCD_DB5_LS,
    output  wire        LCD_DB6_LS,
    output  wire        LCD_DB7_LS,
    output  wire        LCD_E_LS,
    output  wire        LCD_RW_LS,
    output  wire        LCD_RS_LS,
    input   wire        GPIO_SW_C,                  // Pushbuttons
    input   wire        GPIO_SW_W,
    input   wire        GPIO_SW_E,
    input   wire        GPIO_SW_N,
    input   wire        GPIO_SW_S
);


//------------------------------------------------------------------------------
// Internal signals definitions

//
// Set this parameter to "TRUE" to use ChipScope to control and monitor the demo.
// Set this parameter to "FALSE" to use Vivado Analyzer to control and monitor
// the demo.
//
parameter USE_CHIPSCOPE = "TRUE";

// Global signals
wire        clk_27M_in;
wire        clk_27M;
wire        mgtclk_148_5;
wire        mgtclk_148_35;
wire        pll0lock;
wire        pll0reset;
wire        pll0clk;
wire        pll0refclk;
wire        pll1lock;
wire        pll1reset;
wire        pll1clk;
wire        pll1refclk;

wire        tx0_outclk;
wire        tx0_usrclk;
wire        tx0_slew;

wire        tx1_outclk;
wire        tx1_usrclk;
wire        tx1_slew;

wire        rx0_outclk;
wire        rx0_usrclk;
wire        rx0_locked;
wire [3:0]  rx0_t_family;
wire [3:0]  rx0_t_rate;
wire        rx0_t_scan;
wire        rx0_level_b;
wire        rx0_m;
wire [1:0]  rx0_mode;

wire        rx1_outclk;
wire        rx1_usrclk;
wire        rx1_locked;
wire [3:0]  rx1_t_family;
wire [3:0]  rx1_t_rate;
wire        rx1_t_scan;
wire        rx1_level_b;
wire        rx1_m;
wire [1:0]  rx1_mode;

wire [3:0]  lcd_d;

reg  [24:0] refclk_stable_dly = 1;
wire        refclk_stable_tc;
reg         refclk_stable = 1'b0;


// ChipScope signals
wire [35:0] control0;
wire [35:0] control1;
wire [35:0] control2;
wire [35:0] control3;
wire [35:0] control4;
wire [35:0] control5;
wire [35:0] control6;


//------------------------------------------------------------------------------
// Clock inputs, outputs, and buffers

assign FMC1_HPC_LA16_N = 1'b1;      // LMH1983 Hin
assign FMC1_HPC_LA16_P = 1'b1;      // LMH1983 Vin
assign FMC1_HPC_LA20_P = 1'b1;      // LMH1983 Fin
assign FMC1_HPC_LA12_N = 1'b0;      // LMH1983 INIT

assign SFP_MGT_CLK_SEL0 = 1'b0;     // MGTCLKIN0 gets GBTCLK0 from FMC (148.5 MHz XO)
assign SFP_MGT_CLK_SEL1 = 1'b1;
assign PCIE_MGT_CLK_SEL0 = 1'b0;    // MGTCLKIN1 gets GBTCLK1 from FMC (148.35 MHz XO)
assign PCIE_MGT_CLK_SEL1 = 1'b1;

//
// With the clock crossbar on the Inrevium SDI mezzanine board, select the 148.5 MHz
// XO as the clock source to FMC1_HPC_GBTCLK0_M2C reference clock input and the
// 148.3516 MHz XO as the clock source to the FMC1_HPC_GBTCLK1_M2C reference
// clock input.
//
assign FMC1_HPC_LA11_P = 1'b1;
assign FMC1_HPC_LA11_N = 1'b0;
assign FMC1_HPC_LA15_P = 1'b1;
assign FMC1_HPC_LA15_N = 1'b1;


BUFG BUFGTX0 (
    .I      (tx0_outclk),
    .O      (tx0_usrclk));

BUFG BUFGRX0 (
    .I      (rx0_outclk),
    .O      (rx0_usrclk));

BUFG BUFGTX1 (
    .I      (tx1_outclk),
    .O      (tx1_usrclk));

BUFG BUFGRX1 (
    .I      (rx1_outclk),
    .O      (rx1_usrclk));

//
// 27MHz clock from FMC board
// This clock is used to drive some peripheral control logic associated with
// devices on the AC701 and SDI FMC mezzanine board. This clock is also used
// as the fixed frequency and DRP clock for the SDI core and GTP.
//
IBUFDS #(
    .IOSTANDARD ("LVDS_25"),
    .DIFF_TERM  ("TRUE"))
IBUFDS27M (
    .I          (FMC1_HPC_CLK0_M2C_P),
    .IB         (FMC1_HPC_CLK0_M2C_N),
    .O          (clk_27M_in));

BUFG BUFG27M (
    .I          (clk_27M_in),
    .O          (clk_27M));

//
// This is the 148.5 MHz MGT reference clock input from FMC SDI mezzanine board.
//
(* LOC = "IBUFDS_GTE2_X0Y0" *)
IBUFDS_GTE2 MGTCLKIN0 (
    .I          (SFP_MGT_CLK0_C_P),
    .IB         (SFP_MGT_CLK0_C_N),
    .CEB        (1'b0),
    .O          (mgtclk_148_5),
    .ODIV2      ());

assign USER_SMA_GPIO_P = tx0_usrclk;

//
// 148.35 MHz MGT reference clock input from the FMC SDI mezzanine board.
//
(* LOC = "IBUFDS_GTE2_X0Y1" *)
IBUFDS_GTE2 MGTCLKIN1 (
    .I          (SFP_MGT_CLK1_C_P),
    .IB         (SFP_MGT_CLK1_C_N),
    .CEB        (1'b0),
    .O          (mgtclk_148_35),
    .ODIV2      ());

//
// Generate approximately 1.25 second delay after FPGA configuration before
// releasing the refclk_stable signal in order to make sure reference clocks
// are stable.
//
always @ (posedge clk_27M)
    if (!refclk_stable)
        refclk_stable_dly <= refclk_stable_dly + 1;

assign refclk_stable_tc = &refclk_stable_dly;

always @ (posedge clk_27M)
    if (refclk_stable_tc)
        refclk_stable <= 1'b1;

//------------------------------------------------------------------------------
// SDI RX/TX modules
//
// Each of these modules contains the SDI wrapper (containing the SDI core and
// the SDI control logic), the GTP transceiver, video pattern generators to 
// drive the SDI transmitter, and ChipScope or Vivado Analyzer modules to 
// control and monitor the SDI interface.
//
a7_sdi_rxtx #(
    .USE_CHIPSCOPE      (USE_CHIPSCOPE))
SDI0 (
    .clk                (clk_27M),
    .tx_outclk          (tx0_outclk),
    .tx_usrclk          (tx0_usrclk),
    .tx_refclk_stable   (refclk_stable),
    .tx_plllock         (pll0lock & pll1lock),  // GTP TX uses both PLL0 and PLL1
    .tx_pllreset        (pll1reset),            // but only resets PLL1 because PLL0 is reset by RX
    .tx_slew            (tx0_slew),
    .tx_txen            (),
    .rx_refclk_stable   (refclk_stable),
    .rx_plllock         (pll0lock),             // RX only uses PLL0
    .rx_pllreset        (pll0reset),
    .rx_outclk          (rx0_outclk),
    .rx_usrclk          (rx0_usrclk),
    .rx_locked          (rx0_locked),
    .rx_t_family        (rx0_t_family),
    .rx_t_rate          (rx0_t_rate),
    .rx_t_scan          (rx0_t_scan),
    .rx_level_b         (rx0_level_b),
    .rx_m               (rx0_m),
    .rx_mode            (rx0_mode),
    .drpclk             (clk_27M),
    .txp                (FMC1_HPC_DP0_C2M_P),
    .txn                (FMC1_HPC_DP0_C2M_N),
    .rxp                (FMC1_HPC_DP0_M2C_P),
    .rxn                (FMC1_HPC_DP0_M2C_N),
    .pll0clk            (pll0clk),
    .pll0refclk         (pll0refclk),
    .pll1clk            (pll1clk),
    .pll1refclk         (pll1refclk),
    .control0           (control1),
    .control1           (control2),
    .control2           (control3));

a7_sdi_rxtx #(
    .USE_CHIPSCOPE      (USE_CHIPSCOPE))
SDI1 (
    .clk                (clk_27M),
    .tx_outclk          (tx1_outclk),
    .tx_usrclk          (tx1_usrclk),
    .tx_refclk_stable   (refclk_stable),
    .tx_plllock         (pll0lock & pll1lock),
    .tx_pllreset        (),
    .tx_slew            (tx1_slew),
    .tx_txen            (),
    .rx_refclk_stable   (refclk_stable),
    .rx_plllock         (pll0lock),             // RX only uses PLL0
    .rx_pllreset        (),
    .rx_outclk          (rx1_outclk),
    .rx_usrclk          (rx1_usrclk),
    .rx_locked          (rx1_locked),
    .rx_t_family        (rx1_t_family),
    .rx_t_rate          (rx1_t_rate),
    .rx_t_scan          (rx1_t_scan),
    .rx_level_b         (rx1_level_b),
    .rx_m               (rx1_m),
    .rx_mode            (rx1_mode),
    .drpclk             (clk_27M),
    .txp                (FMC1_HPC_DP1_C2M_P),
    .txn                (FMC1_HPC_DP1_C2M_N),
    .rxp                (FMC1_HPC_DP1_M2C_P),
    .rxn                (FMC1_HPC_DP1_M2C_N),
    .pll0clk            (pll0clk),
    .pll0refclk         (pll0refclk),
    .pll1clk            (pll1clk),
    .pll1refclk         (pll1refclk),
    .control0           (control4),
    .control1           (control5),
    .control2           (control6));

//------------------------------------------------------------------------------
// GTP COMMON wrapper
//
// This wrapper is generated by the GT wizard. It contains the two PLLs for the
// GTP Quad.
//

a7gtp_sdi_wrapper_common #(
    .WRAPPER_SIM_GTRESET_SPEEDUP    ("FALSE"))
gtpe2_common_0 (
    .GTGREFCLK0_IN                  (1'b0),
    .GTGREFCLK1_IN                  (1'b0),
    .GTEASTREFCLK0_IN               (1'b0),
    .GTEASTREFCLK1_IN               (1'b0),
    .GTREFCLK0_IN                   (mgtclk_148_5),
    .GTREFCLK1_IN                   (mgtclk_148_35),
    .GTWESTREFCLK0_IN               (1'b0),
    .GTWESTREFCLK1_IN               (1'b0),
    .PLL0OUTCLK_OUT                 (pll0clk),
    .PLL0OUTREFCLK_OUT              (pll0refclk),
    .PLL0LOCK_OUT                   (pll0lock),
    .PLL0LOCKDETCLK_IN              (clk_27M),
    .PLL0REFCLKLOST_OUT             (),
    .PLL0RESET_IN                   (pll0reset),
    .PLL1OUTCLK_OUT                 (pll1clk),
    .PLL1OUTREFCLK_OUT              (pll1refclk),
    .PLL1LOCK_OUT                   (pll1lock),
    .PLL1LOCKDETCLK_IN              (clk_27M),
    .PLL1REFCLKLOST_OUT             (),
    .PLL1RESET_IN                   (pll1reset),
    .PLL0REFCLKSEL_IN               (3'b001),
    .PLL1REFCLKSEL_IN               (3'b010));

//
// Control for the slew rate and TX_EN signals of the SDI cable drivers
//

assign FMC1_HPC_LA06_P = tx0_slew;
assign FMC1_HPC_LA10_P = tx1_slew;
assign FMC1_HPC_LA14_P = 1'b0;
assign FMC1_HPC_LA14_N = 1'b0;

assign FMC1_HPC_LA18_CC_P = 1'b0;
assign FMC1_HPC_LA18_CC_N = 1'b0;
assign FMC1_HPC_LA10_N = 1'b0;
assign FMC1_HPC_LA06_N = 1'b0;

//------------------------------------------------------------------------------
// Control module for LCD display on AC701 board
//
lcd_control5 #(
    .ROM_FILE_NAME          ("a7_sdi_demo_name.txt"),
    .MIN_FMC_FPGA_REVISION  (8'd0),
    .REQUIRED_CML_TYPE      (16'h0000), // None
    .REQUIRED_CMH_TYPE      (16'h0000)) // None
LCD (
    .clk                (clk_27M),
    .rst                (1'b0),
    .sw_c               (GPIO_SW_C),
    .sw_w               (GPIO_SW_W),
    .sw_e               (GPIO_SW_E),
    .sw_n               (GPIO_SW_N),
    .sw_s               (GPIO_SW_S),
    .fpga_rev           (8'd0),
    .cml_type           (16'h0000),
    .cml_type_valid     (1'b0),
    .cml_type_error     (1'b0),
    .cmh_type           (16'h0000),
    .cmh_type_valid     (1'b0),
    .cmh_type_error     (1'b0),
    .active_rx          (4'b0011),
    .rx0_locked         (rx0_locked),
    .rx0_mode           (rx0_mode),
    .rx0_level          (rx0_level_b),
    .rx0_t_family       (rx0_t_family),
    .rx0_t_rate         (rx0_t_rate),
    .rx0_t_scan         (rx0_t_scan),
    .rx0_m              (rx0_m),
    .rx1_locked         (rx1_locked),
    .rx1_mode           (rx1_mode),
    .rx1_level          (rx1_level_b),
    .rx1_t_family       (rx1_t_family),
    .rx1_t_rate         (rx1_t_rate),
    .rx1_t_scan         (rx1_t_scan),
    .rx1_m              (rx1_m),
    .rx2_locked         (1'b0),
    .rx2_mode           (2'b00),
    .rx2_level          (1'b0),
    .rx2_t_family       (4'b0000),
    .rx2_t_rate         (4'b0000),
    .rx2_t_scan         (1'b0),
    .rx2_m              (1'b0),
    .rx3_locked         (1'b0),
    .rx3_mode           (2'b00),
    .rx3_level          (1'b0),
    .rx3_t_family       (4'b0000),
    .rx3_t_rate         (4'b0000),
    .rx3_t_scan         (1'b0),
    .rx3_m              (1'b0),
    .sync_active        (1'b0),
    .sync_enable        (1'b0),
    .sync_v             (1'b0),
    .sync_err           (1'b0),
    .sync_m             (1'b0),
    .sync_frame_rate    (3'b0),
    .sync_video_fmt     (11'b0),
    .lcd_e              (LCD_E_LS),
    .lcd_rw             (LCD_RW_LS),
    .lcd_rs             (LCD_RS_LS),
    .lcd_d              (lcd_d));

assign LCD_DB4_LS = lcd_d[0];
assign LCD_DB5_LS = lcd_d[1];
assign LCD_DB6_LS = lcd_d[2];
assign LCD_DB7_LS = lcd_d[3];

//------------------------------------------------------------------------------
// This module controls the LMH0387 bidirectional SDI PHY devices on the SDI
// FMC mezzanine board with I2C bus.
//
LMH0387_control LMH0387ctrl (
    .clk        (clk_27M),
    .rst        (1'b0),
    .sclk       (FMC1_HPC_LA17_CC_P),
    .mosi       (FMC1_HPC_LA13_P),
    .miso       (FMC1_HPC_LA13_N),
    .ss0t       (FMC1_HPC_LA01_CC_P),
    .ss0r       (FMC1_HPC_LA01_CC_N),
    .ss1t       (FMC1_HPC_LA05_P),
    .ss1r       (FMC1_HPC_LA05_N),
    .ss2        (FMC1_HPC_LA09_P),
    .ss3        (FMC1_HPC_LA09_N),
    .rxeq_en    (4'b0011));         // Enable EQ on RX1 and RX2

//------------------------------------------------------------------------------
// ChipScope or Vivado analyzer modules
//
generate 
if (USE_CHIPSCOPE == "TRUE")
begin : chipscope
    icon icon (
        .CONTROL0   (control0),
        .CONTROL1   (control1),
        .CONTROL2   (control2),
        .CONTROL3   (control3),
        .CONTROL4   (control4),
        .CONTROL5   (control5),
        .CONTROL6   (control6));

    vio vio (
        .CONTROL    (control0),
        .ASYNC_IN   ({4'b0000, pll1reset, pll0reset, pll1lock, pll0lock}));

end else
begin : vivado_analyzer
    vio0 vio0 (
        .clk        (clk_27M),
        .probe_in3  (pll1reset),        // 1 bit
        .probe_in4  (pll0reset),        // 1 bit
        .probe_in5  (pll1lock),         // 1 bit
        .probe_in6  (pll0lock));        // 1 bit

    assign control1 = 35'b0;
    assign control2 = 35'b0;
    assign control3 = 35'b0;
    assign control4 = 35'b0;
    assign control5 = 35'b0;
    assign control6 = 35'b0;
end
endgenerate

endmodule

    
