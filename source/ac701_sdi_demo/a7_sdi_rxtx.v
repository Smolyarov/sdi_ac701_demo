
// Description:
// This module is a wrapper around a set of modules that implement an 
// independent SDI RX and TX. The SDI TX is driven by SD and HD video pattern 
// generators. The TX and pattern generators are controlled by ChipScope. The 
// output of the SDI RX is monitored by ChipScope.
//
// This module makes it easier to implement multi-channel SDI demos.
//
// This version supports the latest version of the SDI wrapper which changes
// the RX PLL divider through the DRP rather than using the GTP RXRATE port.
//

`timescale 1ns / 1ps

module a7_sdi_rxtx
(
    input   wire        clk,                // 27 MHz clock
    output  wire        tx_outclk,
    input   wire        tx_usrclk,
    input   wire        tx_refclk_stable,   // Assert High when refclk is stable
    input   wire        tx_plllock,         // Connect to GTP PLLxLOCK
    output  wire        tx_pllreset,        // Connect to PLLxRESET on GTPE2_COMMON
    output  wire        tx_slew,            // SDI cable driver slew rate control
    output  wire        tx_txen,            // SDI bidirectional PHY TX enable
    input   wire        rx_refclk_stable,   // Assert High when refclk is stable
    input   wire        rx_plllock,         // Connect to GTP PLLxLOCK
    output  wire        rx_pllreset,        // Connect to GTP PLLxRESET
    output  wire        rx_outclk,
    input   wire        rx_usrclk,
    output  wire        rx_locked,
    output  wire [3:0]  rx_t_family,
    output  wire [3:0]  rx_t_rate,
    output  wire        rx_t_scan,
    output  wire        rx_level_b,
    output  wire        rx_m,
    output  wire [1:0]  rx_mode,
    input   wire        drpclk,             // DRP clock
    output  wire        txp,                // GTP TXP output
    output  wire        txn,                // GTP TXN output
    input   wire        rxp,                // GTP RXP output
    input   wire        rxn,                // GTP RXN output
    input   wire        pll0clk,            // Connect to GTHE2_COMMON pll0outclk
    input   wire        pll0refclk,         // Connect to GTHE2_COMMON pll0outrefclk
    input   wire        pll1clk,            // Connect to GTHE2_COMMON pll1outclk
    input   wire        pll1refclk,         // Connect to GTHE2_COMMON pll1outrefclk
    inout   wire [35:0] control0,           // ChipScope controls signals
    inout   wire [35:0] control1,
    inout   wire [35:0] control2
);

//
// Internal signals
//

// TX signals
wire        tx_gttxreset;
wire        tx_resetdone;
wire        tx_ratedone;
wire        tx_userrdy;
wire [19:0] tx_txdata;
wire [1:0]  tx_sysclksel;
wire [2:0]  tx_rate;
wire [1:0]  tx_bufstatus;
wire        tx_bitrate_sel;
wire [1:0]  tx_mode;
wire [1:0]  tx_mode_x;
wire [2:0]  tx_fmt_sel;
wire [1:0]  tx_pat;
reg         tx_M;
wire [9:0]  tx_hd_y;
wire [9:0]  tx_hd_c;
wire [9:0]  tx_pal_patgen;
wire [9:0]  tx_ntsc_patgen;
wire [9:0]  tx_sd;
wire [10:0] tx_line;
reg  [2:0]  tx_fmt;
wire [9:0]  tx_c;
wire [9:0]  tx_y;
reg  [7:0]  tx_vpid_byte2;
wire        tx_din_rdy;
reg         tx_fabric_reset = 1'b0;
wire        tx_gtp_full_reset;
wire        tx_gtp_reset;
wire        tx_change_done;
wire        tx_change_fail;
wire [2:0]  tx_change_fail_code;
(* shreg_extract = "NO" *)  
reg  [2:0]  tx_gtp_full_reset_sss = 3'b000;
(* shreg_extract = "NO" *)  
reg  [2:0]  tx_gtp_reset_sss = 3'b000;


(* equivalent_register_removal = "no" *)
(* KEEP = "TRUE" *)
reg [2:0]   tx_ce = 3'b111;                    // 3 copies of the TX clock enable
(* equivalent_register_removal = "no" *)
(* KEEP = "TRUE" *)
reg         tx_sd_ce = 1'b0;                   // This is the SD-SDI TX clock enable
(* equivalent_register_removal = "no" *)
(* KEEP = "TRUE" *)
reg  [10:0] tx_gen_sd_ce = 11'b00000100001;    // Generates 5/6/5/6 cadence SD-SDI TX clock enable
wire        tx_ce_mux;                         // Used to generate the tx_ce signals

// RX signals
wire        rx_gtrxreset;
wire        rx_resetdone;
wire        rx_cdrhold;
wire [19:0] rx_rxdata;
wire        rx_userrdy;
wire        rx_mode_locked;
wire        rx_clr_errs;
wire        rx_ce;
wire        rx_dout_rdy_3g;
wire [10:0] rx_ln_a;
wire [31:0] rx_a_vpid;
wire        rx_a_vpid_valid;
wire        rx_crc_err_a;
wire        rx_crc_err_b;
reg         rx_hd_crc_err = 1'b0;
wire        rx_crc_err_ab;
reg  [1:0]  rx_crc_err_edge = 2'b00;
reg  [15:0] rx_crc_err_count = 0;
wire [15:0] rx_err_count;
wire        rx_err_count_tc;
reg         rx_sd_clr_errs = 1'b0;
wire [15:0] rx_edh_errcnt;
wire [9:0]  rx_ds1a;
wire [9:0]  rx_ds2a;
wire [9:0]  rx_ds1b;
wire [9:0]  rx_ds2b;
wire        rx_eav;
wire        rx_sav;
wire        rx_crc_err;
wire        rx_manual_reset;
wire        rx_gtp_full_reset;
wire        rx_gtp_reset;
wire        rx_change_done;
wire        rx_change_fail;
wire [2:0]  rx_change_fail_code;
(* shreg_extract = "NO" *)  
reg  [2:0]  rx_gtp_full_reset_sss = 3'b000;
(* shreg_extract = "NO" *)  
reg  [2:0]  rx_gtp_reset_sss = 3'b000;
wire        drprdy;
wire        drpbusy;
wire [8:0]  drpaddr;
wire [15:0] drpdi;
wire [15:0] drpdo;
wire        drpen;
wire        drpwe;

//------------------------------------------------------------------------------
// TX section
//

//
// Because of glitches on TXOUTCLK during changes to TXRATE and TXSYSCLKSEL, the
// SDI data path is reset when TXRATEDONE is low (taking care of TXSYSCLKSEL
// changes) and when TXRATEDONE is pulsed high (taking care of TXRATE changes).
//
always @ (posedge tx_usrclk)
    tx_fabric_reset <= tx_ratedone | ~tx_resetdone;

//
// TX clock enable generator
//
// tx_sd_ce runs at 27 MHz and is asserted at a 5/6/5/6 cadence
// tx_ce is always 1 for 3G-SDI and HD-SDI and equal to sd_ce for SD-SDI
//
// Create 3 identical but separate copies of the clock enable for loading purposes.
//

// A shift register that continuously circulates a pattern to generate the
// 5/6/5/6 cadence for the tx_sd_ce.
always @ (posedge tx_usrclk)
    if (tx_fabric_reset)
        tx_gen_sd_ce <= 11'b00000100001;
    else
        tx_gen_sd_ce <= {tx_gen_sd_ce[9:0], tx_gen_sd_ce[10]};

always @ (posedge tx_usrclk)
    tx_sd_ce <= tx_gen_sd_ce[10];

// Use either tx_sd_ce or continuous 1 for tx_ce depending on SDI mode
assign tx_ce_mux = tx_mode == 2'b01 ? tx_gen_sd_ce[10] : 1'b1;

// Make 3 identical copies of the tx_ce
always @ (posedge tx_usrclk)
    tx_ce <= {3 {tx_ce_mux}};

//------------------------------------------------------------------------------
// Some logic to insure that the TX bit rate and video formats chosen by the
// user are never illegal.
//
// In 3G-SDI mode, only video formats 4 (1080p60) and 5 (1080p50) are legal.
//
always @ (*)
    if (tx_mode == 2'b10 && tx_fmt_sel[2:1] != 2'b10)
        tx_fmt <= 3'b100;
    else
        tx_fmt <= tx_fmt_sel;

//
// In SD-SDI mode, tx_M must be 0. In HD and 3G modes, if the video format is
// 0 (720p50), 3 (1080i50), or 5 (1080p25), then tx_M must be 0.
//
always @ (*)
    if (tx_mode == 2'b01)          // In SD-SDI mode, tx_M must be 0
        tx_M <= 1'b0;
    else if (tx_fmt == 3'b000 || tx_fmt == 3'b011 || tx_fmt == 3'b101)
        tx_M <= 1'b0;
    else
        tx_M <= tx_bitrate_sel;

//------------------------------------------------------------------------------
// Video pattern generators
//
multigenHD VIDGEN (
    .clk                (tx_usrclk),
    .rst                (tx_fabric_reset),
    .ce                 (1'b1),
    .std                (tx_fmt),
    .pattern            (tx_pat),
    .user_opt           (2'b00),
    .y                  (tx_hd_y),
    .c                  (tx_hd_c),
    .h_blank            (),
    .v_blank            (),
    .field              (),
    .trs                (),
    .xyz                (),
    .line_num           (tx_line));

vidgen_ntsc NTSC (
    .clk                (tx_usrclk),
    .rst                (tx_fabric_reset),
    .ce                 (tx_sd_ce),
    .pattern            (tx_pat[0]),
    .q                  (tx_ntsc_patgen),
    .h_sync             (),
    .v_sync             (),
    .field              ());

vidgen_pal PAL (
    .clk                (tx_usrclk),
    .rst                (tx_fabric_reset),
    .ce                 (tx_sd_ce),
    .pattern            (tx_pat[0]),
    .q                  (tx_pal_patgen),
    .h_sync             (),
    .v_sync             (),
    .field              ());

//
// Video pattern generator output muxes
//
assign tx_sd = tx_fmt[0] ? tx_pal_patgen : tx_ntsc_patgen;
assign tx_c = tx_hd_c;
assign tx_y = tx_mode == 2'b01 ? tx_sd : tx_hd_y;

assign tx_din_rdy = 1'b1;

always @ (*)
    if (tx_fmt[0])
        tx_vpid_byte2 = 8'hC9;      // 50 Hz
    else if (tx_M)
        tx_vpid_byte2 = 8'hCA;      // 59.94 Hz
    else
        tx_vpid_byte2 = 8'hCB;      // 60 Hz

assign tx_mode = tx_mode_x == 2'b11 ? 2'b00 : tx_mode_x;

//------------------------------------------------------------------------------
// SDI core wrapper including GTP control module
//
a7gtp_sdi_rxtx_wrapper #(
    .FXDCLK_FREQ            (27000000),
    .DRPCLK_PERIOD          (37),
    .TIMEOUT_CNTR_BITWIDTH  (16),   // 2^16 / 27e6 is enough for 2ms timeout period
    .TXSYSCLKSEL_M_0        (2'b00),
    .TXSYSCLKSEL_M_1        (2'b11))
SDI (
    .clk                (clk),
    .rx_rst             (1'b0),
    .rx_mode_search_rst (1'b0),
    .rx_usrclk          (rx_usrclk),
    .rx_gtp_full_reset  (rx_gtp_full_reset),
    .rx_gtp_reset       (rx_gtp_reset),
    .rx_fabric_reset_out(),
    .rx_refclk_stable   (rx_refclk_stable),
    .rx_frame_en        (1'b1),                     // Enable SDI framer
    .rx_mode_en         (3'b111),                   // Enable all three SDI protocols
    .rx_mode            (rx_mode),
    .rx_mode_hd         (),
    .rx_mode_sd         (),
    .rx_mode_3g         (),
    .rx_mode_locked     (rx_mode_locked),
    .rx_bit_rate        (rx_m),
    .rx_t_locked        (rx_locked),
    .rx_t_family        (rx_t_family),
    .rx_t_rate          (rx_t_rate),
    .rx_t_scan          (rx_t_scan),
    .rx_level_b_3g      (rx_level_b),
    .rx_ce_sd           (rx_ce),
    .rx_nsp             (),
    .rx_line_a          (rx_ln_a),
    .rx_a_vpid          (rx_a_vpid),
    .rx_a_vpid_valid    (rx_a_vpid_valid),
    .rx_b_vpid          (),
    .rx_b_vpid_valid    (),
    .rx_crc_err_a       (rx_crc_err_a),
    .rx_ds1a            (rx_ds1a),
    .rx_ds2a            (rx_ds2a),
    .rx_eav             (rx_eav),
    .rx_sav             (rx_sav),
    .rx_trs             (),
    .rx_line_b          (),
    .rx_dout_rdy_3g     (rx_dout_rdy_3g),
    .rx_crc_err_b       (rx_crc_err_b),
    .rx_ds1b            (rx_ds1b),
    .rx_ds2b            (rx_ds2b),
    .rx_edh_errcnt_en   (16'b0_00001_00001_00000),
    .rx_edh_clr_errcnt  (rx_sd_clr_errs),
    .rx_edh_ap          (),
    .rx_edh_ff          (),
    .rx_edh_anc         (),
    .rx_edh_ap_flags    (),
    .rx_edh_ff_flags    (),
    .rx_edh_anc_flags   (),
    .rx_edh_packet_flags(),
    .rx_edh_errcnt      (rx_edh_errcnt),
    .rx_change_done     (rx_change_done),
    .rx_change_fail     (rx_change_fail),
    .rx_change_fail_code(rx_change_fail_code),

    .tx_rst             (tx_fabric_reset),
    .tx_usrclk          (tx_usrclk),
    .tx_gtp_full_reset  (tx_gtp_full_reset),
    .tx_gtp_reset       (tx_gtp_reset),
    .tx_refclk_stable   (tx_refclk_stable),
    .tx_ce              (tx_ce),
    .tx_din_rdy         (tx_din_rdy),
    .tx_mode            (tx_mode),
    .tx_m               (tx_M),
    .tx_level_b_3g      (1'b0),             // In 3G-SDI mode, this demo only transmits level A
    .tx_insert_crc      (1'b1),
    .tx_insert_ln       (1'b1),
    .tx_insert_edh      (1'b1),
    .tx_insert_vpid     (tx_mode == 2'b10),
    .tx_overwrite_vpid  (1'b1),
    .tx_video_a_y_in    (tx_y),
    .tx_video_a_c_in    (tx_c),
    .tx_video_b_y_in    (10'b0),
    .tx_video_b_c_in    (10'b0),
    .tx_line_a          (tx_line),
    .tx_line_b          (tx_line),
    .tx_vpid_byte1      (8'h89),
    .tx_vpid_byte2      (tx_vpid_byte2),
    .tx_vpid_byte3      (8'h00),
    .tx_vpid_byte4a     (8'h09),
    .tx_vpid_byte4b     (8'h09),
    .tx_vpid_line_f1    (11'd10),
    .tx_vpid_line_f2    (11'b0),
    .tx_vpid_line_f2_en (1'b0),
    .tx_ds1a_out        (),
    .tx_ds2a_out        (),
    .tx_ds1b_out        (),
    .tx_ds2b_out        (),
    .tx_use_dsin        (1'b0),
    .tx_ds1a_in         (10'b0),
    .tx_ds2a_in         (10'b0),
    .tx_ds1b_in         (10'b0),
    .tx_ds2b_in         (10'b0),
    .tx_ce_align_err    (),
    .tx_slew            (tx_slew),
    .tx_change_done     (tx_change_done),
    .tx_change_fail     (tx_change_fail),
    .tx_change_fail_code(tx_change_fail_code),

    .gtp_rxdata         (rx_rxdata),
    .gtp_rxplllock      (rx_plllock),
    .gtp_rxresetdone    (rx_resetdone),
    .gtp_gtrxreset      (rx_gtrxreset),
    .gtp_rxpllreset     (rx_pllreset),
    .gtp_rxcdrhold      (rx_cdrhold),
    .gtp_drpclk         (drpclk),
    .gtp_drprdy         (drprdy),
    .gtp_drpbusy        (drpbusy),
    .gtp_drpaddr        (drpaddr),
    .gtp_drpdi          (drpdi),
    .gtp_drpdo          (drpdo),
    .gtp_drpen          (drpen),
    .gtp_drpwe          (drpwe),
    .gtp_rxuserrdy      (rx_userrdy),

    .gtp_txdata         (tx_txdata),
    .gtp_txplllock      (tx_plllock),
    .gtp_txresetdone    (tx_resetdone),
    .gtp_txratedone     (tx_ratedone),
    .gtp_txuserrdy      (tx_userrdy),
    .gtp_gttxreset      (tx_gttxreset),
    .gtp_txpllreset     (tx_pllreset),
    .gtp_txrate         (tx_rate),
    .gtp_txsysclksel    (tx_sysclksel));

//------------------------------------------------------------------------------
// GTP transceiver
//
a7gtp_sdi_wrapper_GT #(
    .GT_SIM_GTRESET_SPEEDUP         ("FALSE"),
    .TXSYNC_OVRD_IN                 (1'b0),
    .TXSYNC_MULTILANE_IN            (1'b0))
GTP_i (
    .rst_in                         (rx_pllreset),
    .drp_busy_out                   (drpbusy),
    .drpaddr_in                     (drpaddr),
    .drpclk_in                      (clk),
    .drpdi_in                       (drpdi),
    .drpdo_out                      (drpdo),
    .drpen_in                       (drpen),
    .drprdy_out                     (drprdy),
    .drpwe_in                       (drpwe),
    .txsysclksel_in                 (tx_sysclksel),
    .pll0clk_in                     (pll0clk),
    .pll0refclk_in                  (pll0refclk),
    .pll1clk_in                     (pll1clk),
    .pll1refclk_in                  (pll1refclk),
    .loopback_in                    (3'b000),
    .rxrate_in                      (3'b000),
    .eyescanreset_in                (1'b0),
    .rxuserrdy_in                   (rx_userrdy),
    .eyescandataerror_out           (),
    .eyescantrigger_in              (1'b0),
    .rxcdrhold_in                   (rx_cdrhold),
    .rxcdrlock_out                  (),
    .rxdata_out                     (rx_rxdata),
    .rxusrclk_in                    (rx_usrclk),
    .rxusrclk2_in                   (rx_usrclk),
    .gtprxn_in                      (rxn),
    .gtprxp_in                      (rxp),
    .rxbufreset_in                  (1'b0),
    .rxbufstatus_out                (),
    .rxlpmhfhold_in                 (1'b0),
    .rxlpmlfhold_in                 (1'b0),
    .rxratedone_out                 (),
    .rxoutclk_out                   (rx_outclk),
    .gtrxreset_in                   (rx_gtrxreset),
    .rxresetdone_out                (rx_resetdone),
    .txpostcursor_in                (5'b00000),
    .txprecursor_in                 (5'b00000),
    .gttxreset_in                   (tx_gttxreset),
    .txuserrdy_in                   (tx_userrdy),
    .txdata_in                      (tx_txdata),
    .txusrclk_in                    (tx_usrclk),
    .txusrclk2_in                   (tx_usrclk),
    .txrate_in                      (tx_rate),
    .txbufstatus_out                (tx_bufstatus),
    .gtptxn_out                     (txn),
    .gtptxp_out                     (txp),
    .txdiffctrl_in                  (4'b1000),
    .txoutclk_out                   (tx_outclk),
    .txoutclkfabric_out             (),
    .txoutclkpcs_out                (),
    .txratedone_out                 (tx_ratedone),
    .txpcsreset_in                  (tx_bufstatus[1]),
    .txpmareset_in                  (1'b0),
    .txresetdone_out                (tx_resetdone)
);

//------------------------------------------------------------------------------
// CRC error capture and counting logic
//
assign rx_crc_err_ab = rx_crc_err_a | (rx_mode == 2'b10 && rx_level_b && rx_crc_err_b);

always @ (posedge rx_usrclk)
    if (rx_clr_errs)
        rx_hd_crc_err <= 1'b0;
    else if (rx_crc_err_ab)
        rx_hd_crc_err <= 1'b1;

always @ (posedge rx_usrclk)
    rx_crc_err_edge <= {rx_crc_err_edge[0], rx_crc_err_ab};

always @ (posedge rx_usrclk)
    if (rx_clr_errs | ~rx_mode_locked)
        rx_crc_err_count <= 0;
    else if (rx_crc_err_edge[0] & ~rx_crc_err_edge[1] & ~rx_err_count_tc)
        rx_crc_err_count <= rx_crc_err_count + 1;

assign rx_err_count = rx_mode == 2'b01 ? rx_edh_errcnt : rx_crc_err_count;
assign rx_err_count_tc = rx_crc_err_count == 16'hffff;

always @ (posedge rx_usrclk)
    if (rx_clr_errs)
        rx_sd_clr_errs <= 1'b1;
    else if (rx_ce)
        rx_sd_clr_errs <= 1'b0;

assign rx_crc_err = rx_mode == 2'b01 ? rx_edh_errcnt != 0 : rx_hd_crc_err;


endmodule
