
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
a7_sdi_rxtx SDI0 (
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


endmodule

    
