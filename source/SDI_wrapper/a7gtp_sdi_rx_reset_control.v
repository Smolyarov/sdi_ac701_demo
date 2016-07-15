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
//  /   /         Filename: $File: //Groups/video_ip/demos/A7/xapp1097_a7_sdi_demos/Verilog/SDI_wrapper/a7gtp_sdi_rx_reset_control.v $
// /___/   /\     Timestamp: $DateTime: 2013/09/30 13:31:35 $
// \   \  /  \
//  \___\/\___\
//
// Description:
//  This module implements the finite state machine that controls the PLLRESET
//  and the GTRXRESET of the 7-series GTP transceiver RX section.
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

module a7gtp_sdi_rx_reset_control #( 
    parameter DRPCLK_PERIOD             = 13,       // Period of drpclk in ns, always round down
    parameter PLLLOCK_TIMEOUT_PERIOD    = 2000000,  // Period of PLLLOCK timeout in ns, defaults to 2ms
    parameter RESET_TIMEOUT_PERIOD      = 500000,   // Period of RESETDONE timeout in ns, defaults to 500us
    parameter TIMEOUT_CNTR_BITWIDTH     = 19,       // Width in bits of timeout counter
    parameter RETRY_CNTR_BITWIDTH       = 8)        // Width in bits of the retry counter       
(
    input   wire        drpclk,                     // Fixed frequency DRPCLK
    input   wire        refclk_stable,              // High indicates reference clock is stable
    input   wire        pll_lock,                   // PLL lock input
    input   wire        rxresetdone,                // RXRESETDONE from the GTP
    input   wire        drp_busy_in,                // DRP BUSY signal
    input   wire        gtrxreset_in,               // Causes a GTRXRESET sequence without a PLL reset
    input   wire        full_reset,                 // Causes a full PLL reset followed by GTRXRESET sequence
    output  reg         drp_busy_out = 1'b0,        // DRP BUSY output
    output  reg         gtrxreset = 1'b0,           // GTP reset output
    output  reg         pll_reset = 1'b0,           // PLL reset output
    output  reg         done = 1'b0,                // Sequence done output
    output  reg         fail = 1'b0,                // Sequence failure output
    output  reg         fail_code = 1'b0,           // Failure code
    output  reg         drp_priority_req = 1'b1     // Indicate the FSM needs the DRP bus
);

//
// These parameters define the encoding of the FSM states
//
localparam STATE_WIDTH = 4;

localparam [STATE_WIDTH-1:0]
    INIT_STATE              = 4'b0000,
    ASSERT_RESETS_STATE     = 4'b0001,
    DRP_CHECK_STATE         = 4'b0010,
    RELEASE_PLLRESET_STATE  = 4'b0011,
    PLL_LOCKED_STATE        = 4'b0100,
    WAIT_RESET_DONEX_STATE  = 4'b0101,
    WAIT_RESET_DONE_STATE   = 4'b0110,
    DONE_STATE              = 4'b0111,
    RETRY_STATE             = 4'b1000,
    CHECK_RETRIES_STATE     = 4'b1001,
    FAIL_STATE              = 4'b1010,
    DRP_REQ_FULL_STATE      = 4'b1011,
    DRP_WAIT_STATE          = 4'b1100,
    DRP_REQ_NO_PLL_STATE    = 4'b1101,
    RETRY2_STATE            = 4'b1110,
    CHECK_RETRIES2_STATE    = 4'b1111;

localparam STARTUP_DELAY = 500; // AR43482:Transceiver needs to wait for 500 ns after config
localparam STARTUP_WAIT_CYCLES = STARTUP_DELAY / DRPCLK_PERIOD;
localparam PLLLOCK_TIMEOUT_CYCLES = PLLLOCK_TIMEOUT_PERIOD / DRPCLK_PERIOD;
localparam RESET_TIMEOUT_CYCLES = RESET_TIMEOUT_PERIOD / DRPCLK_PERIOD;

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
reg     [2:0]                       rxresetdone_ss = 3'b000;
wire                                rxresetdone_s;
reg                                 assert_pll_reset;
reg                                 assert_gt_reset;
reg                                 assert_done;
reg                                 assert_fail;
reg                                 assert_drp_req;
reg                                 assert_drp_busy_out;
reg                                 inc_retry_cntr;
reg                                 clear_retry_cntr;
reg     [RETRY_CNTR_BITWIDTH-1:0]   retry_cntr = 0;
wire                                max_retries;
reg                                 do_pll_reset = 1'b1;    // Do a PLL reset first time after FPGA config
reg                                 assert_do_pll_reset;
reg                                 clear_do_pll_reset;
reg                                 post_config = 1'b1;
reg                                 clear_post_config;
reg                                 set_fail_code_0;
reg                                 set_fail_code_1;

//
// Synchronize input signals
//
always @ (posedge drpclk)
    refclk_stable_ss <= {refclk_stable_ss[1:0], refclk_stable};

assign refclk_stable_s = refclk_stable_ss[2];

always @ (posedge drpclk or posedge pll_reset)
    if (pll_reset)
        pll_lock_ss <= 3'b000;
    else
        pll_lock_ss <= {pll_lock_ss[1:0], pll_lock};

assign pll_lock_s = pll_lock_ss[2];

always @ (posedge drpclk)
    rxresetdone_ss <= {rxresetdone_ss[1:0], rxresetdone};

assign rxresetdone_s = rxresetdone_ss[2];

//
// Timeout counter
//
always @ (posedge drpclk)
    if (clear_timeout_cntr)
        timeout_cntr <= 0;
    else
        timeout_cntr <= timeout_cntr + 1;

always @ (posedge drpclk)
    if (clear_timeout_cntr)
        init_period_done = 1'b0;
    else if (timeout_cntr == STARTUP_WAIT_CYCLES)
        init_period_done = 1'b1;

always @ (posedge drpclk)
    if (clear_timeout_cntr)
        plllock_timeout <= 1'b0;
    else if (timeout_cntr == PLLLOCK_TIMEOUT_CYCLES)
        plllock_timeout <= 1'b1;

always @ (posedge drpclk)
    if (clear_timeout_cntr)
        reset_timeout <= 1'b0;
    else if (timeout_cntr == RESET_TIMEOUT_CYCLES)
        reset_timeout <= 1'b1;

//
// Retry counter
//
always @ (posedge drpclk)
    if (clear_retry_cntr)
        retry_cntr <= 0;
    else if (inc_retry_cntr)
        retry_cntr <= retry_cntr + 1;

assign max_retries = &retry_cntr;

//
// Reset outputs
//
always @ (posedge drpclk)
begin
    gtrxreset <= assert_gt_reset;
    pll_reset <= assert_pll_reset & do_pll_reset;
end

//
// Done, fail, drp_busy_out, and drp_priority_req outputs
//
always @ (posedge drpclk)
begin
    done <= assert_done;
    fail <= assert_fail;
    drp_priority_req <= assert_drp_req;
    drp_busy_out <= assert_drp_busy_out;
end

//
// The do_pll_reset signal
//
always @ (posedge drpclk)
begin
    if (assert_do_pll_reset)
        do_pll_reset <= 1'b1;
    else if (clear_do_pll_reset)
        do_pll_reset <= 1'b0;
end

//
// The post_config signal
//
always @ (posedge drpclk)
    if (clear_post_config)
        post_config <= 1'b0;

//
// FSM current state register
// 
always @ (posedge drpclk)
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

        DRP_REQ_FULL_STATE:
            next_state = DRP_WAIT_STATE;

        DRP_REQ_NO_PLL_STATE:
            next_state = DRP_WAIT_STATE;

        DRP_WAIT_STATE:
            next_state = DRP_CHECK_STATE;

        DRP_CHECK_STATE:
            if (~drp_busy_in)
                next_state = ASSERT_RESETS_STATE;
            else if (reset_timeout)
                next_state = RETRY2_STATE;
            else
                next_state = DRP_CHECK_STATE;

        ASSERT_RESETS_STATE:
            if (~refclk_stable_s | full_reset | gtrxreset_in)
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
            if (~rxresetdone_s)
                next_state = WAIT_RESET_DONE_STATE;
            else if (reset_timeout)
                next_state = RETRY_STATE;
            else
                next_state = WAIT_RESET_DONEX_STATE;

        WAIT_RESET_DONE_STATE:
            if (rxresetdone_s) 
                next_state = DONE_STATE;
            else if (reset_timeout)
                next_state = RETRY_STATE;
            else
                next_state = WAIT_RESET_DONE_STATE;

        DONE_STATE:
            if (full_reset)
                next_state = DRP_REQ_FULL_STATE;
            else if (gtrxreset_in)
                next_state = DRP_REQ_NO_PLL_STATE;
            else
                next_state = DONE_STATE;

        RETRY_STATE:    
            next_state = CHECK_RETRIES_STATE;

        CHECK_RETRIES_STATE:
            if (max_retries)
                next_state = FAIL_STATE;
            else if (post_config | pll_lock_s)
                next_state = WAIT_RESET_DONE_STATE;
            else
                next_state = RELEASE_PLLRESET_STATE;

        RETRY2_STATE:
            next_state = CHECK_RETRIES2_STATE;

        CHECK_RETRIES2_STATE:
            if (max_retries)
                next_state = FAIL_STATE;
            else
                next_state = DRP_CHECK_STATE;

        FAIL_STATE:
            if (full_reset)
                next_state = DRP_REQ_FULL_STATE;
            else
                next_state = FAIL_STATE;
                
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
    assert_drp_req          = 1'b0;
    assert_drp_busy_out     = 1'b0;
    assert_do_pll_reset     = 1'b0;
    clear_do_pll_reset      = 1'b0;
    clear_post_config       = 1'b0;
    clear_retry_cntr        = 1'b0;
    set_fail_code_0         = 1'b0;
    set_fail_code_1         = 1'b0;

    case(current_state)
        INIT_STATE:
        begin
            assert_drp_req = 1'b1;
            clear_retry_cntr = 1'b1;
        end

        DRP_REQ_FULL_STATE:
        begin
            assert_drp_req = 1'b1;
            assert_do_pll_reset = 1'b1;
        end

        DRP_REQ_NO_PLL_STATE:
            assert_drp_req = 1'b1;

        DRP_WAIT_STATE:
        begin
            assert_drp_req = 1'b1;
            clear_timeout_cntr = 1'b1;
        end

        DRP_CHECK_STATE:
            assert_drp_req = 1'b1;

        ASSERT_RESETS_STATE:
        begin
            assert_pll_reset = 1'b1;
            assert_gt_reset = 1'b1;
            clear_timeout_cntr = 1'b1;
            assert_drp_busy_out = 1'b1;
        end

        RELEASE_PLLRESET_STATE:
        begin
            assert_gt_reset = 1'b1;
            assert_drp_busy_out = 1'b1;
        end

        PLL_LOCKED_STATE:
        begin
            assert_gt_reset = 1'b1;
            clear_timeout_cntr = 1'b1;
            assert_drp_busy_out = 1'b1;
        end

        WAIT_RESET_DONE_STATE:
            assert_drp_busy_out = 1'b1;

        WAIT_RESET_DONEX_STATE:
            assert_drp_busy_out = 1'b1;

        DONE_STATE:
        begin
            assert_done = 1'b1;
            clear_timeout_cntr = 1'b1;
            clear_do_pll_reset = 1'b1;
            clear_post_config = 1'b1;
            clear_retry_cntr = 1'b1;
        end

        FAIL_STATE:
        begin
            assert_fail = 1'b1;
            clear_timeout_cntr = 1'b1;
            clear_retry_cntr = 1'b1;
        end

        RETRY_STATE:
        begin
            inc_retry_cntr = 1'b1;
            clear_timeout_cntr = 1'b1;
            assert_drp_busy_out = 1'b1;
        end

        RETRY2_STATE:
        begin
            inc_retry_cntr = 1'b1;
            clear_timeout_cntr = 1'b1;
        end

        CHECK_RETRIES_STATE:
        begin
            assert_drp_busy_out = 1'b1;
            if (max_retries)
                set_fail_code_0 = 1'b1;
        end

        CHECK_RETRIES2_STATE:
            if (max_retries)
                set_fail_code_1 = 1'b1;

        default:;
    endcase
end

//
// Fail code register
//
always @ (posedge drpclk)
    if (set_fail_code_0)
        fail_code <= 1'b0;
    else if (set_fail_code_1)
        fail_code <= 1'b1;
         
endmodule
