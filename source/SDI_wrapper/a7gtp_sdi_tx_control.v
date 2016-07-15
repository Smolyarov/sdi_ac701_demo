// (c) Copyright 2013 Xilinx, Inc. All rights reserved.
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
// \   \   \/     Version: $Revision: #3 $
//  \   \         
//  /   /         Filename: $File: //Groups/video_ip/demos/A7/xapp1097_a7_sdi_demos/Verilog/SDI_wrapper/a7gtp_sdi_tx_control.v $
// /___/   /\     Timestamp: $DateTime: 2013/09/30 13:31:35 $
// \   \  /  \
//  \___\/\___\
//
// Description:
//  This module implements the finite state machine that controls the PLLRESET,
//  GTTXRESET, TXRATE, and TXSYSCLKSEL signals of the GTP for the SDI protocol.
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

module a7gtp_sdi_tx_control #( 
    parameter CLK_PERIOD                = 13,       // Period of clk in ns, always round down
    parameter PLLLOCK_TIMEOUT_PERIOD    = 2000000,  // Period of PLLLOCK timeout in ns, defaults to 2ms
    parameter RESET_TIMEOUT_PERIOD      = 500000,   // Period of RESETDONE timeout in ns, defaults to 500us
    parameter TIMEOUT_CNTR_BITWIDTH     = 19,       // Width in bits of timeout counter
    parameter RETRY_CNTR_BITWIDTH       = 8)        // Width in bits of the retry counter       
(
    input   wire        clk,                        // Fixed frequency clock
    input   wire        txusrclk,                   // TXUSRCLK
    input   wire        refclk_stable,              // High indicates reference clock is stable                 (async)
    input   wire        pll_lock,                   // PLL lock input                                           (async)
    input   wire [1:0]  txmode,                     // TX SDI mode                                              (txusrclk)
    input   wire        tx_m,                       // TX bit rate select (0=1000/1000, 1=1000/1001)            (async)
    input   wire [1:0]  txsysclksel_m_0,            // Value to output on TXSYSCLKSEL when tx_m is 0            (drpclk)
    input   wire [1:0]  txsysclksel_m_1,            // Value to output on TXSYSCLKSEL when tx_m is 1            (drpclk)
    input   wire        txresetdone,                // TXRESETDONE from the GTP                                 (async)
    input   wire        txratedone,                 // TXRATEDONE from the GTP                                  (async)
    input   wire        gttxreset_in,               // Causes a GTTXRESET sequence without a PLL reset          (drpclk)
    input   wire        full_reset,                 // Causes a full PLL reset followed by GTTXRESET sequence   (drpclk)
    output  reg         gttxreset = 1'b0,           // GTP reset output                                         (drpclk)
    output  reg         pll_reset = 1'b0,           // PLL reset output                                         (drpclk)
    output  wire [2:0]  txrate,                     // Connect to TXRATE input of GTP                           (txusrclk)
    output  reg  [1:0]  txsysclksel = 2'b00,        // Connect to TXSYSCLKSEL input of GTP                      (drpclk)
    output  reg         done = 1'b0,                // Sequence done output                                     (drpclk)
    output  reg         fail = 1'b0,                // Sequence failure output                                  (drpclk)
    output  reg  [2:0]  fail_code = 3'b000          // Sequence failure code                                    (drpclk)
);

//
// These parameters define the encoding of the FSM states
//
localparam STATE_WIDTH = 5;

localparam [STATE_WIDTH-1:0]
    INIT_STATE              = 5'b00000,
    ASSERT_RESETS_STATE     = 5'b00001,
    RELEASE_PLLRESET_STATE  = 5'b00010,
    PLL_LOCKED_STATE        = 5'b00011,
    WAIT_RESET_DONEX_STATE  = 5'b00100,
    WAIT_RESET_DONE_STATE   = 5'b00101,
    DONE_STATE              = 5'b00111,
    RETRY_STATE             = 5'b01000,
    CHECK_RETRIES_STATE     = 5'b01001,
    FAIL_STATE              = 5'b01010,
    FULL_RESET_STATE        = 5'b01011,
    R1_STATE                = 5'b10000,
    R2_STATE                = 5'b10001,
    RETRY_R_STATE           = 5'b10011,
    CHECK_RETRIES_R_STATE   = 5'b10100,
    M1_STATE                = 5'b11000,
    M2_STATE                = 5'b11001,
    M3_STATE                = 5'b11010,
    M4_STATE                = 5'b11011,
    M5_STATE                = 5'b11100,
    M6_STATE                = 5'b11101,
    RETRY_M_STATE           = 5'b01100,
    CHECK_RETRIES_M_STATE   = 5'b01101;


localparam STARTUP_DELAY = 500; // AR43482:Transceiver needs to wait for 500 ns after config
localparam STARTUP_WAIT_CYCLES = STARTUP_DELAY / CLK_PERIOD;
localparam PLLLOCK_TIMEOUT_CYCLES = PLLLOCK_TIMEOUT_PERIOD / CLK_PERIOD;
localparam RESET_TIMEOUT_CYCLES = RESET_TIMEOUT_PERIOD / CLK_PERIOD;

localparam RATE_DIV_1 = 3'b001;
localparam RATE_DIV_2 = 3'b010;
localparam RATE_DIV_4 = 3'b011;

reg     [STATE_WIDTH-1:0]           current_state = INIT_STATE;
reg     [STATE_WIDTH-1:0]           next_state;
reg     [TIMEOUT_CNTR_BITWIDTH-1:0] timeout_cntr = 0;
reg                                 clear_timeout_cntr;
reg                                 plllock_timeout = 1'b0;
reg                                 reset_timeout = 1'b0;
reg                                 init_period_done = 1'b0;
(* shreg_extract = "NO" *)  
reg     [2:0]                       refclk_stable_ss = 3'b000;
wire                                refclk_stable_s;
(* shreg_extract = "NO" *)  
reg     [2:0]                       pll_lock_ss = 3'b000;
wire                                pll_lock_s;
(* shreg_extract = "NO" *)  
reg     [2:0]                       txresetdone_ss = 3'b000;
wire                                txresetdone_s;
reg                                 txratedone_capture = 1'b0;
(* shreg_extract = "NO" *)  
reg     [2:0]                       txratedone_ss = 3'b000;
wire                                txratedone_s;
reg                                 assert_pll_reset;
reg                                 assert_gt_reset;
reg                                 assert_done;
reg                                 assert_fail;
reg                                 inc_retry_cntr;
reg                                 clear_retry_cntr;
reg     [RETRY_CNTR_BITWIDTH-1:0]   retry_cntr = 0;
wire                                max_retries;
reg                                 do_pll_reset = 1'b1;    // Do a PLL reset first time after FPGA config
reg                                 assert_do_pll_reset;
reg                                 clear_do_pll_reset;
reg                                 clear_txratedone;
reg     [1:0]                       txmode_reg = 2'b00;
reg     [2:0]                       txrate_1 = RATE_DIV_4;
reg     [2:0]                       txrate_2 = RATE_DIV_4;
reg     [2:0]                       txrate_int = RATE_DIV_4;
wire                                txrate_diff;
reg                                 txrate_change_capture = 1'b0;
reg     [2:0]                       txrate_change_s = 3'b000;
wire                                txrate_change;
wire                                ld_txrate;
reg                                 ld_txrate_capture = 1'b0;
reg     [2:0]                       ld_txrate_stretch = 3'b000;
reg                                 do_ld_txrate;
(* shreg_extract = "NO" *)  
reg     [3:0]                       tx_m_sss = 4'b0000;
wire                                tx_m_diff;
reg                                 tx_m_change = 1'b0;
reg                                 ld_txsysclksel;
reg                                 resetdone_went_low = 1'b0;
reg                                 set_resetdone_went_low;
reg                                 clr_resetdone_went_low;
reg     [2:0]                       fail_code_int;
reg     [2:0]                       fail_code_tmp = 3'b000;
reg                                 ld_fail_code;
reg                                 clr_fail_code;

//
// Synchronize input signals
//
always @ (posedge clk)
    refclk_stable_ss <= {refclk_stable_ss[1:0], refclk_stable};

assign refclk_stable_s = refclk_stable_ss[2];

always @ (posedge clk or posedge pll_reset)
    if (pll_reset)
        pll_lock_ss <= 3'b000;
    else
        pll_lock_ss <= {pll_lock_ss[1:0], pll_lock};

assign pll_lock_s = pll_lock_ss[2];

always @ (posedge clk)
    txresetdone_ss <= {txresetdone_ss[1:0], txresetdone};

assign txresetdone_s = txresetdone_ss[2];

//
// Timeout counter
//
always @ (posedge clk)
    if (clear_timeout_cntr)
        timeout_cntr <= 0;
    else
        timeout_cntr <= timeout_cntr + 1;

always @ (posedge clk)
    if (clear_timeout_cntr)
        init_period_done = 1'b0;
    else if (timeout_cntr == STARTUP_WAIT_CYCLES)
        init_period_done = 1'b1;

always @ (posedge clk)
    if (clear_timeout_cntr)
        plllock_timeout <= 1'b0;
    else if (timeout_cntr == PLLLOCK_TIMEOUT_CYCLES)
        plllock_timeout <= 1'b1;

always @ (posedge clk)
    if (clear_timeout_cntr)
        reset_timeout <= 1'b0;
    else if (timeout_cntr == RESET_TIMEOUT_CYCLES)
        reset_timeout <= 1'b1;

//
// Retry counter
//
always @ (posedge clk)
    if (clear_retry_cntr)
        retry_cntr <= 0;
    else if (inc_retry_cntr)
        retry_cntr <= retry_cntr + 1;

assign max_retries = &retry_cntr;

//
// Reset outputs
//
always @ (posedge clk)
begin
    gttxreset <= assert_gt_reset;
    pll_reset <= assert_pll_reset & do_pll_reset;
end

//
// Done and fail outputs
//
always @ (posedge clk)
begin
    done <= assert_done;
    fail <= assert_fail;
end

//
// The do_pll_reset signal
//
always @ (posedge clk)
begin
    if (assert_do_pll_reset)
        do_pll_reset <= 1'b1;
    else if (clear_do_pll_reset)
        do_pll_reset <= 1'b0;
end

//
// txmode & txrate related logic
//
always @ (posedge txusrclk)
    txmode_reg <= txmode;

always @ (posedge txusrclk)
    if (txmode_reg == 2'b00)
        txrate_1 <= RATE_DIV_4;
    else if (txmode_reg == 2'b11)
        txrate_1 <= RATE_DIV_1;
    else
        txrate_1 <= RATE_DIV_2;

always @ (posedge txusrclk)
    txrate_2 <= txrate_1;

always @ (posedge txusrclk)
    if (ld_txrate)
        txrate_int <= txrate_2;

assign txrate = txrate_int;

assign txrate_diff = txrate_1 != txrate_2;

always @ (posedge txusrclk)
    if (txrate_diff)
        txrate_change_capture <= 1'b1;
    else if (ld_txrate)
        txrate_change_capture <= 1'b0;

always @ (posedge clk)
    txrate_change_s <= {txrate_change_s[1:0], txrate_change_capture};

assign txrate_change = txrate_change_s[2];

always @ (posedge clk or posedge ld_txrate)
    if (ld_txrate)
        ld_txrate_capture <= 1'b0;
    else if (do_ld_txrate)
        ld_txrate_capture <= 1'b1;
        
always @ (posedge txusrclk)
    if (ld_txrate)
        ld_txrate_stretch <= 3'b000;
    else
        ld_txrate_stretch <= {ld_txrate_stretch[1:0], ld_txrate_capture};

assign ld_txrate = ld_txrate_stretch[2];

//
// TXRATEDONE logic
//
always @ (posedge clk or posedge txratedone)
    if (txratedone)
        txratedone_capture <= 1'b1;
    else if (clear_txratedone)
        txratedone_capture <= 1'b0;

always @ (posedge clk)
    if (clear_txratedone)
        txratedone_ss <= 3'b000;
    else
        txratedone_ss <= {txratedone_ss[1:0], txratedone_capture};

assign txratedone_s = txratedone_ss[2];

//
// TXSYSCLKSEL related logic
//
always @ (posedge clk)
    tx_m_sss <= {tx_m_sss[2:0], tx_m};

assign tx_m_diff = tx_m_sss[3] != tx_m_sss[2];

always @ (posedge clk)
    if (tx_m_diff)
        tx_m_change <= 1'b1;
    else if (ld_txsysclksel)
        tx_m_change <= 1'b0;

always @ (posedge clk)
    if (ld_txsysclksel)
        txsysclksel <= tx_m_sss[2] == 1'b0 ? txsysclksel_m_0 : txsysclksel_m_1;

//
// FF to help with the retry flow in the tx_m change sequence
//
always @ (posedge clk)
    if (set_resetdone_went_low)
        resetdone_went_low <= 1'b1;
    else if (clr_resetdone_went_low)
        resetdone_went_low <= 1'b0;

//
// FSM current state register
// 
always @ (posedge clk)
    current_state <= next_state;

//
// FSM next state logic
//
always @ (*)
begin
    case(current_state)
        INIT_STATE:
            if (init_period_done)
                next_state = ASSERT_RESETS_STATE;
            else
                next_state = INIT_STATE;

        ASSERT_RESETS_STATE:
            if (~refclk_stable_s | full_reset | gttxreset_in)
                next_state = ASSERT_RESETS_STATE;
            else
                next_state = RELEASE_PLLRESET_STATE;

        RELEASE_PLLRESET_STATE:
            if (pll_lock_s)
                next_state = PLL_LOCKED_STATE;
            else if (plllock_timeout)
                next_state = RETRY_STATE;
            else
                next_state = RELEASE_PLLRESET_STATE;

        PLL_LOCKED_STATE:
             next_state = WAIT_RESET_DONEX_STATE;

        WAIT_RESET_DONEX_STATE:
            if (~txresetdone_s)
                next_state = WAIT_RESET_DONE_STATE;
            else if (reset_timeout)
                next_state = RETRY_STATE;
            else
                next_state = WAIT_RESET_DONEX_STATE;

        WAIT_RESET_DONE_STATE:
            if (txresetdone_s) 
                next_state = DONE_STATE;
            else if (reset_timeout)
                next_state = RETRY_STATE;
            else
                next_state = WAIT_RESET_DONE_STATE;

        DONE_STATE:
            if (full_reset)
                next_state = FULL_RESET_STATE;
            else if (gttxreset_in)
                next_state = ASSERT_RESETS_STATE;
            else if (txrate_change)
                next_state = R1_STATE;
            else if (tx_m_change)
                next_state = M1_STATE;
            else
                next_state = DONE_STATE;

        RETRY_STATE:    
            next_state = CHECK_RETRIES_STATE;

        CHECK_RETRIES_STATE:
            if (max_retries)
                next_state = FAIL_STATE;
            else if (pll_lock_s)
                next_state = WAIT_RESET_DONE_STATE;
            else
                next_state = RELEASE_PLLRESET_STATE;

        FAIL_STATE:
            if (full_reset)
                next_state = ASSERT_RESETS_STATE;
            else
                next_state = FAIL_STATE;

        FULL_RESET_STATE:
            next_state = ASSERT_RESETS_STATE;
                            
        R1_STATE:
            next_state = R2_STATE;

        R2_STATE:
            if (txratedone_s)
                next_state = DONE_STATE;
            else if (reset_timeout)
                next_state = RETRY_R_STATE;
            else
                next_state = R2_STATE;

        RETRY_R_STATE:
            next_state = CHECK_RETRIES_R_STATE;

        CHECK_RETRIES_R_STATE:
            if (max_retries)
                next_state = FAIL_STATE;
            else
                next_state = R2_STATE;

        M1_STATE:
            next_state = M2_STATE;

        M2_STATE:
            next_state = M3_STATE;

        M3_STATE:
            if (~txresetdone_s)
                next_state = M4_STATE;
            else if (reset_timeout)
                next_state = RETRY_M_STATE;
            else
                next_state = M3_STATE;

        M4_STATE:
            next_state = M5_STATE;

        M5_STATE:
            next_state = M6_STATE;

        M6_STATE:
            if (txresetdone_s)
                next_state = DONE_STATE;
            else if (reset_timeout)
                next_state = RETRY_M_STATE;
            else 
                next_state = M6_STATE;

        RETRY_M_STATE:
            next_state = CHECK_RETRIES_M_STATE;

        CHECK_RETRIES_M_STATE:
            if (max_retries)
                next_state = FAIL_STATE;
            else if (resetdone_went_low)
                next_state = M6_STATE;
            else
                next_state = M3_STATE;

        default:
            next_state = FAIL_STATE;
    endcase
end

//
// FSM output logic
//
always @ (*)
begin
    clear_timeout_cntr      = 1'b0;
    assert_pll_reset        = 1'b0;
    assert_gt_reset         = 1'b0;
    assert_done             = 1'b0;
    assert_fail             = 1'b0;
    inc_retry_cntr          = 1'b0;
    assert_do_pll_reset     = 1'b0;
    clear_do_pll_reset      = 1'b0;
    clear_retry_cntr        = 1'b0;
    do_ld_txrate            = 1'b0;
    ld_txsysclksel          = 1'b0;
    clear_txratedone        = 1'b0;
    set_resetdone_went_low  = 1'b0;
    clr_resetdone_went_low  = 1'b0;
    fail_code_int           = 3'b000;
    clr_fail_code           = 1'b0;
    ld_fail_code            = 1'b0;

    case(current_state)
        INIT_STATE:
        begin
            clear_retry_cntr = 1'b1;
            clr_fail_code = 1'b1;
        end

        ASSERT_RESETS_STATE:
        begin
            assert_pll_reset = 1'b1;
            assert_gt_reset = 1'b1;
            clear_timeout_cntr = 1'b1;
        end

        RELEASE_PLLRESET_STATE:
        begin
            assert_gt_reset = 1'b1;
            fail_code_int = 3'b001;
        end
                
        PLL_LOCKED_STATE:
        begin
            assert_gt_reset = 1'b1;
            clear_timeout_cntr = 1'b1;
            clear_txratedone = 1'b1;
        end

        WAIT_RESET_DONEX_STATE:
            fail_code_int = 3'b010;

        WAIT_RESET_DONE_STATE:
            fail_code_int = 3'b011;

        DONE_STATE:
        begin
            assert_done = 1'b1;
            clear_timeout_cntr = 1'b1;
            clear_do_pll_reset = 1'b1;
            clear_retry_cntr = 1'b1;
            clear_txratedone = 1'b1;
        end

        FAIL_STATE:
        begin
            assert_fail = 1'b1;
            clear_timeout_cntr = 1'b1;
            clear_retry_cntr = 1'b1;
            clear_txratedone = 1'b1;
            ld_fail_code = 1'b1;
        end

        RETRY_STATE:
        begin
            inc_retry_cntr = 1'b1;
            clear_timeout_cntr = 1'b1;
        end

        FULL_RESET_STATE:
        begin
            assert_do_pll_reset = 1'b1;
            clr_fail_code = 1'b1;
        end

        R1_STATE:
        begin
            do_ld_txrate = 1'b1;
            clear_timeout_cntr = 1'b1;
        end

        RETRY_R_STATE:
        begin
            inc_retry_cntr = 1'b1;
            clear_timeout_cntr = 1'b1;
            fail_code_int = 3'b100;
        end

        M1_STATE:
            assert_gt_reset = 1'b1;

        M2_STATE:
        begin
            assert_gt_reset = 1'b1;
            clear_timeout_cntr = 1'b1;
            clr_resetdone_went_low = 1'b1;
        end

        M3_STATE:
        begin
            assert_gt_reset = 1'b1;
            fail_code_int = 3'b101;
        end

        M4_STATE:
        begin
            assert_gt_reset = 1'b1;
            ld_txsysclksel = 1'b1;
            set_resetdone_went_low = 1'b1;
        end

        M5_STATE:
            assert_gt_reset = 1'b1;

        M6_STATE:
            fail_code_int = 3'b110;

        RETRY_M_STATE:
        begin
            inc_retry_cntr = 1'b1;
            assert_gt_reset = 1'b1;
        end

        CHECK_RETRIES_M_STATE:
            assert_gt_reset = 1'b1;

        default:;
    endcase
end

//
// Fail code registers
//
always @ (posedge clk)
    if (fail_code_int != 3'b000)
        fail_code_tmp <= fail_code_int;

always @ (posedge clk)
    if (clr_fail_code)
        fail_code <= 3'b000;
    else if (ld_fail_code)
        fail_code <= fail_code_tmp;

endmodule
