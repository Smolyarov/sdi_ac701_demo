// (c) Copyright 2006 - 2014 Xilinx, Inc. All rights reserved.
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
//  This module modifies attributes in the GTP transceiver in response to 
//  changes in the RX SDI mode. This module is specifically designed to support 
//  SDI interfaces implemented in the 7series GTP. It changes the RXCDR_CFG 
//  attribute when the rx_mode input changes.
//
// This version of the module also dynamically modifies the RXOUT_DIV attribute
// through the DRP to change the RX PLL divider. Previously, the RXRATE port
// on the GTP was used to change the RX PLL divider, but now the RXOUT_DIV
// attribute is used for more reliable dynamic line rate changes. A drpdo port
// has been added.

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

module a7gtp_sdi_drp_control 
#(
    parameter RXCDR_CFG_HD      = 83'h0_0011_07FE_1060_2104_1010,   // HD-SDI CDR setting
    parameter RXCDR_CFG_3G      = 83'h0_0011_07FE_2060_2108_1010,   // 3G-SDI CDR setting
    parameter RXCDR_CFG_6G      = 83'h0_0011_07FE_4060_2104_1010,   // 6G-SDI CDR setting (experimental only)
    parameter DRP_TIMEOUT_MSB   = 9,                                // MSB of DRP timeout counter
    parameter RETRY_CNTR_MSB    = 8)                                // MSB of retry counter
(
    input   wire        drpclk,                 // DRP DCLK
    input   wire        rxusrclk,               // RXUSRCLK used for generation of rst output only
    input   wire        rst,                    // Connect to same reset that drives RST_IN of inner GTP wrapper_gt (usually RX PLLRESET)
    input   wire        init_done,              // GTP initialization is complete
    input   wire [1:0]  rx_mode,                // RX mode select
    output  wire        rx_fabric_rst,          // SDI RX fabric reset
    input   wire        drpbusy_in,             // GTP DRP_BUSY
    output  reg         drpbusy_out = 1'b0,     // 1 indicates DRP cycle in progress
    output  reg         drpreq = 1'b0,          // 1 requests the DRP from the arbiter
    input   wire        drprdy,                 // GTP DRPRDY
    output  reg  [8:0]  drpaddr   = 9'b0,       // GTP DRPADDR
    output  reg  [15:0] drpdi     = 16'b0,      // GTP DRPDI
    input   wire [15:0] drpdo,                  // GTP DRPDO
    output  reg         drpen     = 1'b0,       // GTP DRPEN
    output  reg         drpwe     = 1'b0,       // GTP DRPWE
    output  reg         done      = 1'b0,       // sequence done output
    output  reg         fail      = 1'b0,       // 1 = sequence failure
    output  reg  [2:0]  fail_code = 3'b000,     // sequence failure code
    output  reg         rxcdrhold = 1'b0,       // GTP RXCDRHOLD
    output  reg         gtrxreset = 1'b0,       // GTRXRESET request
    output  reg         full_reset = 1'b0       // GTP full reset request
);
             
localparam RXCDR_CFG_DRPADDR = 9'h0A8;
localparam RXOUT_DIV_DRPADDR = 9'h088;

//
// This group of constants defines the states of the master state machine.
// 
localparam MSTR_STATE_WIDTH = 4;
localparam MSTR_STATE_MSB   = MSTR_STATE_WIDTH - 1;

localparam [MSTR_STATE_MSB:0]
    MSTR_IDLE           = 4'h0,
    MSTR_REQUEST        = 4'h1,
    MSTR_CHECK          = 4'h2,
    MSTR_DRPBUSY_TO     = 4'h3,
    MSTR_CDRCFG_WRITE   = 4'h4,
    MSTR_CDRCFG_WAIT    = 4'h5,
    MSTR_CDRCFG_NEXT    = 4'h6,
    MSTR_CDRCFG_ERR     = 4'h7,
    MSTR_RXDIV_GO       = 4'h8,
    MSTR_RXDIV_WAIT     = 4'h9,
    MSTR_RXDIV_ERR      = 4'hA,
    MSTR_DONE           = 4'hB,
    MSTR_SD             = 4'hC,
    MSTR_DO_RESET       = 4'hD,
    MSTR_DO_RESET_TO    = 4'hE,
    MSTR_FAIL           = 4'hF;

//
// This group of parameters defines the states of the DRP state machine.
//
localparam DRP_STATE_WIDTH = 4;
localparam DRP_STATE_MSB = DRP_STATE_WIDTH - 1;

localparam [DRP_STATE_MSB:0]
    DRP_START       = 4'h0,
    DRP_WRITE       = 4'h1,
    DRP_WAIT        = 4'h2,
    DRP_DONE        = 4'h3,
    DRP_TO          = 4'h4,
    DRP_BUSY        = 4'h5,
    DRP_DIV_START   = 4'h7,
    DRP_DIV_READ    = 4'h8,
    DRP_DIV_BUSY    = 4'h9,
    DRP_DIV_RD_WAIT = 4'ha,
    DRP_DIV_WR_SETUP= 4'hB,
    DRP_DIV_WRITE   = 4'hC,
    DRP_DIV_WR_WAIT = 4'hD;

//
// Local signal declarations
//
reg  [1:0]              rx_mode_in_reg = 2'b00;
reg  [1:0]              rx_mode_sync1_reg = 2'b00;
reg  [1:0]              rx_mode_sync2_reg = 2'b00;
reg  [1:0]              rx_mode_last_reg = 2'b00;
reg                     rx_change_req = 1'b1;
reg                     clr_rx_change_req;

reg  [MSTR_STATE_MSB:0] mstr_current_state = MSTR_IDLE;     // master FSM current state
reg  [MSTR_STATE_MSB:0] mstr_next_state;                    // master FSM next state
reg  [DRP_STATE_MSB:0]  drp_current_state = DRP_START;      // DRP FSM current state
reg  [DRP_STATE_MSB:0]  drp_next_state;                     // DRP FSM next state

reg                     drp_go;                             // Go signal from master FSM to DRP FSM
reg                     drp_go_rxdiv;                       // Go signal from master FSM to DRP FSM for RXDIV change
reg                     drp_done;                           // Done signal from DRP FSM to master FSM
reg                     drp_err;

reg  [2:0]              cycle = 3'b000;                     // cycle counter
reg                     clr_cycle;
reg                     inc_cycle;
wire                    complete;

reg  [8:0]              drp_addr;
reg  [15:0]             drp_data;
reg  [82:0]             rxcdr_cfg = RXCDR_CFG_HD;

reg [DRP_TIMEOUT_MSB:0] to_counter = 0;
reg                     m_clr_to;
reg                     clr_to;
wire                    timeout;
reg                     do_gt_reset;
reg                     do_full_reset;
reg                     clr_retries;
reg                     inc_retries;
reg  [RETRY_CNTR_MSB:0] retry_counter;
reg                     clr_drpbusy_out;
reg                     assert_drpbusy_out;
reg                     clr_fail;
reg                     assert_fail;
reg                     clr_drpreq;
reg                     assert_drpreq;
wire                    max_retries;
reg                     clr_fabric_reset;
reg                     rx_fabric_rst_int = 1'b1;
(* shreg_extract = "NO" *)
reg  [2:0]              rx_fabric_rst_sss = 3'b111;
reg                     set_fail_code_2;
reg                     set_fail_code_3;
reg                     set_fail_code_4;
reg                     set_fail_code_5;
reg                     drp_rxdiv_cycle;
reg  [15:0]             new_rxdiv_out_value;
reg  [15:0]             drp_rddata = 16'h0000;
reg                     ld_drp_rddata;
reg                     set_rxcdrhold;
reg                     clr_rxcdrhold;
reg                     set_done;
reg                     clr_done;

//------------------------------------------------------------------------------
// rx_mode change detectors
//
// Synchronize the rx_mode signal to the clock
always @ (posedge drpclk)
begin
    rx_mode_in_reg <= rx_mode;
    rx_mode_sync1_reg <= rx_mode_in_reg;
    rx_mode_sync2_reg <= rx_mode_sync1_reg;
    rx_mode_last_reg <= rx_mode_sync2_reg;
end

always @ (posedge drpclk)
    if (rst)
        rx_change_req <= 1'b1;
    else if (clr_rx_change_req)
        rx_change_req <= 1'b0;
    else if (rx_mode_sync2_reg != rx_mode_last_reg)
        rx_change_req <= 1'b1;

//
// Assert rxcdrhold if mode changes to SD-SDI mode
//
always @ (posedge drpclk)
    if (set_rxcdrhold)
        rxcdrhold <= 1'b1;
    else if (clr_rxcdrhold)
        rxcdrhold <= 1'b0;
        
//
// Create values used for the new data word
//
always @ *
    case(rx_mode_sync1_reg)
        2'b10:   rxcdr_cfg = RXCDR_CFG_3G;
        2'b11:   rxcdr_cfg = RXCDR_CFG_6G;
        default: rxcdr_cfg = RXCDR_CFG_HD;
    endcase

//------------------------------------------------------------------------------        
// Master state machine
//
// The master FSM examines the rx_change_req register and then initiates multiple
// DRP write cycles to modify the RXCDR_CFG attribute and, if necessary, a
// read-modify-write cycle to modify the RXOUT_DIV attribute.
//
// The actual DRP read and write cycles are handled by a separate FSM, the DRP
// FSM. The master FSM provides a DRP address and new data word to the DRP FSM and 
// asserts a drp_go signal. The DRP FSM does the actual write cycle and responds
// with a drp_done signal when the cycle is complete. For read-modify-write 
// cycles to modify the RXOUT_DIV attribute, the FSM asserts the rx_go_div signal
// instead.
//

//
// Current state register
// 
always @ (posedge drpclk)
    if (rst)
        mstr_current_state <= MSTR_IDLE;
    else
        mstr_current_state <= mstr_next_state;

//
// Next state logic
//
always @ (*)
begin
    case(mstr_current_state)
        MSTR_IDLE:
            if (init_done & rx_change_req)
                mstr_next_state = MSTR_REQUEST;
            else
                mstr_next_state = MSTR_IDLE;

        MSTR_REQUEST:
            if (~drpbusy_in)
                mstr_next_state = MSTR_CHECK;
            else if (timeout)
                mstr_next_state = MSTR_DRPBUSY_TO;
            else
                mstr_next_state = MSTR_REQUEST;

        MSTR_CHECK:
            if (~drpbusy_in)
            begin
                if (rx_mode_sync1_reg == 2'b01)
                    mstr_next_state = MSTR_SD;
                else
                    mstr_next_state = MSTR_CDRCFG_WRITE;
            end
            else
                mstr_next_state = MSTR_REQUEST;

        MSTR_DRPBUSY_TO:
            if (max_retries)
                mstr_next_state = MSTR_FAIL;
            else
                mstr_next_state = MSTR_REQUEST;
        
        MSTR_CDRCFG_WRITE:
            mstr_next_state = MSTR_CDRCFG_WAIT;

        MSTR_CDRCFG_WAIT:
            if (drp_done)
                mstr_next_state = MSTR_CDRCFG_NEXT;
            else if (drp_err)
                mstr_next_state = MSTR_CDRCFG_ERR;
            else
                mstr_next_state = MSTR_CDRCFG_WAIT;

        MSTR_CDRCFG_NEXT:
            if (complete)
                mstr_next_state = MSTR_RXDIV_GO;
            else
                mstr_next_state = MSTR_CDRCFG_WRITE;

        MSTR_CDRCFG_ERR:
            if (max_retries)
                mstr_next_state = MSTR_FAIL;
            else
                mstr_next_state = MSTR_CDRCFG_WRITE;

        MSTR_RXDIV_GO:
            mstr_next_state = MSTR_RXDIV_WAIT;

        MSTR_RXDIV_WAIT:
            if (drp_done)
                mstr_next_state = MSTR_DONE;
            else if (timeout)
                mstr_next_state = MSTR_RXDIV_ERR;
            else
                mstr_next_state = MSTR_RXDIV_WAIT;

        MSTR_RXDIV_ERR:
            if (max_retries)
                mstr_next_state = MSTR_FAIL;
            else
                mstr_next_state = MSTR_RXDIV_WAIT;

        MSTR_DONE:
            mstr_next_state = MSTR_DO_RESET;

        MSTR_SD:
            mstr_next_state = MSTR_RXDIV_GO;

        MSTR_DO_RESET:
            if (~init_done)
                mstr_next_state = MSTR_IDLE;
            else if (timeout)
                mstr_next_state = MSTR_DO_RESET_TO;
            else
                mstr_next_state = MSTR_DO_RESET;

        MSTR_DO_RESET_TO:
            if (max_retries)
                mstr_next_state = MSTR_FAIL;
            else
                mstr_next_state = MSTR_DO_RESET;

        MSTR_FAIL:
            if (init_done)
                mstr_next_state = MSTR_FAIL;
            else
                mstr_next_state = MSTR_IDLE;

        default:
            mstr_next_state = MSTR_FAIL;
    endcase
end

//
// Output logic
//
always @ (*)
begin
    clr_cycle = 1'b0;
    inc_cycle = 1'b0;
    clr_rx_change_req = 1'b0;
    drp_go = 1'b0;
    drp_go_rxdiv = 1'b0;
    do_gt_reset = 1'b0;
    do_full_reset = 1'b0;
    m_clr_to = 1'b0;
    clr_retries = 1'b0;
    clr_drpbusy_out = 1'b0;
    clr_drpreq = 1'b0;
    clr_fail = 1'b0;
    assert_drpreq = 1'b0;
    assert_drpbusy_out = 1'b0;
    inc_retries = 1'b0;
    assert_fail = 1'b0;
    set_rxcdrhold = 1'b0;
    clr_rxcdrhold = 1'b0;
    set_fail_code_2 = 1'b0;
    set_fail_code_3 = 1'b0;
    set_fail_code_4 = 1'b0;
    set_fail_code_5 = 1'b0;
    clr_fabric_reset = 1'b0;
    set_done = 1'b0;
    clr_done = 1'b0;

    case(mstr_current_state)
        MSTR_IDLE:
        begin
            clr_cycle = 1'b1;
            clr_fail = 1'b1;
            clr_drpreq = 1'b1;
            clr_drpbusy_out = 1'b1;
            m_clr_to = 1'b1;
            clr_retries = 1'b1;
        end

        MSTR_REQUEST:
        begin
            assert_drpreq = 1'b1;
            clr_drpbusy_out = 1'b1;
            clr_done = 1'b1;
        end

        MSTR_CHECK:
        begin
            assert_drpbusy_out = 1'b1;
            clr_drpreq = 1'b1;
        end

        MSTR_DRPBUSY_TO:
        begin
            inc_retries = 1'b1;
            m_clr_to = 1'b1;
            if (max_retries)
                set_fail_code_2 = 1'b1;
        end

        MSTR_CDRCFG_WRITE:
        begin
            drp_go = 1'b1;
            clr_rxcdrhold = 1'b1;
        end

        MSTR_CDRCFG_ERR:   
        begin
            inc_retries = 1'b1;
            m_clr_to = 1'b1;
            if (max_retries)
                set_fail_code_3 = 1'b1;
        end

        MSTR_CDRCFG_NEXT:
            inc_cycle = 1'b1;

        MSTR_SD:
            set_rxcdrhold = 1'b1;

        MSTR_RXDIV_GO:
            drp_go_rxdiv = 1'b1;

        MSTR_RXDIV_ERR:
        begin
            inc_retries = 1'b1;
            m_clr_to = 1'b1;
            if (max_retries)
                set_fail_code_4 = 1'b1;
        end

        MSTR_DONE:
        begin
            clr_rx_change_req = 1'b1;
            m_clr_to = 1'b1;
            clr_retries = 1'b1;
        end

        MSTR_DO_RESET:
        begin
            clr_drpbusy_out = 1'b1;
            do_gt_reset = 1'b1;
            clr_rx_change_req = 1'b1;
            clr_fabric_reset = 1'b1;
            if (~init_done)
                set_done = 1'b1;
        end

        MSTR_DO_RESET_TO:
        begin
            inc_retries = 1'b1;
            m_clr_to = 1'b1;
            if (max_retries)
                set_fail_code_5 = 1'b1;
        end

        MSTR_FAIL:
        begin
            clr_drpbusy_out = 1'b1;
            clr_drpreq = 1'b1;
            do_full_reset = 1'b1;
            assert_fail = 1'b1;
        end

        default:;
    endcase
end

always @ (posedge drpclk)
    if (rst)
        gtrxreset <= 1'b0;
    else 
        gtrxreset <= do_gt_reset;
        
always @ (posedge drpclk)
    if (rst)
        full_reset <= 1'b0;
    else
        full_reset <= do_full_reset;

always @ (posedge drpclk)
    if (rst | clr_drpbusy_out)
        drpbusy_out <= 1'b0;
    else if (assert_drpbusy_out)
        drpbusy_out <= 1'b1;

always @ (posedge drpclk)
    if (rst | clr_fail)
        fail <= 1'b0;
    else if (assert_fail)
        fail <= 1'b1;

always @ (posedge drpclk)
    if (rst | clr_drpreq)
        drpreq <= 1'b0;
    else if (assert_drpreq)
        drpreq <= 1'b1;

always @ (posedge drpclk)
    if (rst | clr_retries)
        retry_counter <= 0;
    else if (inc_retries)
        retry_counter <= retry_counter + 1;

assign max_retries = &retry_counter;

//
// This logic creates the correct DRP address and data values.
//
//
// This logic creates the correct DRP address and data values.
//
always @ (*)
    if (drp_rxdiv_cycle)
    begin
        drp_addr = RXOUT_DIV_DRPADDR;
        drp_data = new_rxdiv_out_value;
    end else
        case(cycle)
            3'b000:  
                begin
                    drp_data = rxcdr_cfg[15:0];
                    drp_addr = RXCDR_CFG_DRPADDR;
                end
            3'b001:
                begin  
                    drp_data = rxcdr_cfg[31:16];
                    drp_addr = RXCDR_CFG_DRPADDR + 1;
                end
            3'b010:  
                begin
                    drp_data = rxcdr_cfg[47:32];
                    drp_addr = RXCDR_CFG_DRPADDR + 2;
                end
            3'b011:
                begin  
                    drp_data = rxcdr_cfg[63:48];
                    drp_addr = RXCDR_CFG_DRPADDR + 3;
                end
            3'b100: 
                begin
                    drp_data = rxcdr_cfg[79:64];
                    drp_addr = RXCDR_CFG_DRPADDR + 4;
                end
            default:
                begin
                    drp_data = {13'b0, rxcdr_cfg[82:80]};
                    drp_addr = RXCDR_CFG_DRPADDR + 5;
                end
        endcase

//
// Calculate new_rxdiv_out_value
//
always @ (*)
    case(rx_mode_sync1_reg)
        2'b01:   new_rxdiv_out_value = (drp_rddata & 16'hfff8) | 3'b001; // SD-SDI RXOUT_DIV = /2
        2'b10:   new_rxdiv_out_value = (drp_rddata & 16'hfff8) | 3'b001; // 3G-SDI RXOUT_DIV = /2
        2'b11:   new_rxdiv_out_value = (drp_rddata & 16'hfff8);          // 6G-SDI RXOUT_DIV = /1
        default: new_rxdiv_out_value = (drp_rddata & 16'hfff8) | 3'b010; // HD-SDI RXOUT_DIV = /4
    endcase

//
// cycle counter
//
// This counts the number of write cycles that have been executed to update the
// RXCDR_CFG attribute through the DRP. It takes 6 write cycles to consecutive
// DRP addresses to update the RXCDR_CFG value.
//
always @ (posedge drpclk)
    if (clr_cycle)
        cycle <= 0;
    else if (inc_cycle)
        cycle <= cycle + 1;

assign complete = cycle == 3'b101;

//------------------------------------------------------------------------------
// DRP state machine
//
// The DRP state machine performs the write cycle to the DRP at the request of
// the master FSM to change the RXCDR_CFG attribute words. I also does read-
// modify-write cycles to the DRP to modify the RXOUT_DIV attribute. 
//
// A timeout timer is used to timeout a DRP access should the DRP fail to
// respond with a DRDY signal within a given amount of time controlled by the
// DRP_TIMEOUT_MSB parameter.
//

//
// Current state register
//
always @ (posedge drpclk)
    if (rst)
        drp_current_state <= DRP_START;
    else
        drp_current_state <= drp_next_state;

//
// Next state logic
//
always @ *
    case(drp_current_state)
        DRP_START:
            if (drp_go & ~drpbusy_in)
                drp_next_state = DRP_WRITE;
            else if (drp_go & drpbusy_in)
                drp_next_state = DRP_BUSY;
            else if (drp_go_rxdiv & ~drpbusy_in)
                drp_next_state = DRP_DIV_START;
            else if (drp_go_rxdiv & drpbusy_in)
                drp_next_state = DRP_DIV_BUSY;
            else
                drp_next_state = DRP_START;

        DRP_BUSY:
            if (~drpbusy_in)
                drp_next_state = DRP_WRITE;
            else if (timeout)
                drp_next_state = DRP_TO;
            else
                drp_next_state = DRP_BUSY;

        DRP_WRITE:
            drp_next_state = DRP_WAIT;

        DRP_WAIT:
            if (drprdy)
                drp_next_state = DRP_DONE;
            else if (timeout)
                drp_next_state = DRP_TO;
            else
                drp_next_state = DRP_WAIT;

        DRP_DONE:
            drp_next_state = DRP_START;

        DRP_TO:
            drp_next_state = DRP_START;

        DRP_DIV_START:
            drp_next_state = DRP_DIV_READ;

        DRP_DIV_READ:
            drp_next_state = DRP_DIV_RD_WAIT;

        DRP_DIV_RD_WAIT:
            if (drprdy)
                drp_next_state = DRP_DIV_WR_SETUP;
            else if (timeout)
                drp_next_state = DRP_TO;
            else
                drp_next_state = DRP_DIV_RD_WAIT;

        DRP_DIV_WR_SETUP:
            drp_next_state = DRP_DIV_WRITE;

        DRP_DIV_WRITE:
            drp_next_state = DRP_DIV_WR_WAIT;

        DRP_DIV_WR_WAIT:    
            if (drprdy)
                drp_next_state = DRP_DONE;
            else if (timeout)
                drp_next_state = DRP_TO;
            else
                drp_next_state = DRP_DIV_WR_WAIT;

        DRP_DIV_BUSY:
            if (~drpbusy_in)
                drp_next_state = DRP_DIV_START;
            else if (timeout)
                drp_next_state = DRP_TO;
            else
                drp_next_state = DRP_DIV_BUSY;

        default: 
            drp_next_state = DRP_START;
    endcase

always @ (posedge drpclk)
    begin
        drpdi <= drp_data;
        drpaddr <= drp_addr;
    end

//
// Output logic
//
always @ *
begin
    drpen = 1'b0;
    drpwe = 1'b0;
    drp_done = 1'b0;
    drp_err = 1'b0;
    clr_to = 1'b0;
    ld_drp_rddata = 1'b0;
    drp_rxdiv_cycle = 1'b0; 
    
    case(drp_current_state)
        DRP_START:
            clr_to = 1'b1;

        DRP_WRITE:
            begin
                drpen = 1'b1;
                drpwe = 1'b1;
                clr_to = 1'b1;
            end

        DRP_DONE:
            drp_done = 1'b1;

        DRP_TO:
            drp_err = 1'b1;

        DRP_DIV_START:
            drp_rxdiv_cycle = 1'b1;

        DRP_DIV_READ:
            begin
                drp_rxdiv_cycle = 1'b1;
                drpen = 1'b1;
                clr_to = 1'b1;
            end

        DRP_DIV_RD_WAIT:
            begin
                drp_rxdiv_cycle = 1'b1;
                ld_drp_rddata = 1'b1;
            end

        DRP_DIV_WR_SETUP:
            drp_rxdiv_cycle = 1'b1;

        DRP_DIV_WRITE:
            begin
                drp_rxdiv_cycle = 1'b1;
                drpen = 1'b1;
                drpwe = 1'b1;
                clr_to = 1'b1;
            end

        DRP_DIV_WR_WAIT:
            drp_rxdiv_cycle = 1'b1;

        DRP_DIV_BUSY:
            drp_rxdiv_cycle = 1'b1;

        default:;
    endcase
end

//
// A timeout counter for DRP accesses. If the timeout counter reaches its
// terminal count, the DRP state machine aborts the transfer.
//
always @ (posedge drpclk)
    if (m_clr_to | clr_to)
        to_counter <= 0;
    else if (~timeout)
        to_counter <= to_counter + 1;

assign timeout = to_counter[DRP_TIMEOUT_MSB];

//
// DRP read data register
//
always @ (posedge drpclk)
    if (ld_drp_rddata & drprdy)
        drp_rddata <= drpdo;

//
// rx_fabric_rst output
//
// This output is asserted as the FPGA comes out of config and after assertion
// of rst. It is intended to be used to keep the SDI core RX section in reset
// when RXRATE must be 3'b000 at initialization time.  This signal goes low only
// after the first RXRATE change cycle has completed.
//
always @ (posedge drpclk or posedge rst)
    if (rst)
        rx_fabric_rst_int <= 1'b1;
    else if (clr_fabric_reset)
        rx_fabric_rst_int <= 1'b0;

always @ (posedge rxusrclk)
    rx_fabric_rst_sss <= {rx_fabric_rst_sss[1:0], rx_fabric_rst_int};

assign rx_fabric_rst = rx_fabric_rst_sss[2];

//
// Fail code register
//
always @ (posedge drpclk)
    if (set_fail_code_2)
        fail_code <= 3'b010;
    else if (set_fail_code_3)
        fail_code <= 3'b011;
    else if (set_fail_code_4)
        fail_code <= 3'b100;
    else if (set_fail_code_5)
        fail_code <= 3'b101;

//
// Done register
//
always @ (posedge drpclk)
    if (set_done)
        done <= 1'b1;
    else if (clr_done)
        done <= 1'b0;

endmodule