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
//  /   /         Filename: $File: //Groups/video_ip/demos/A7/xapp1097_a7_sdi_demos/Verilog/SDI_wrapper/a7gtp_sdi_drp_arbit.v $
// /___/   /\     Timestamp: $DateTime: 2013/09/30 13:31:35 $
// \   \  /  \
//  \___\/\___\
//
// Description:
//  This module implements an arbiter for the GTP DRP to arbitrate accesses of
//  the DRP between the RX reset control and the RX mode change control.
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

module a7gtp_sdi_drp_arbit (
    input   wire        drpclk,                     // Fixed frequency DRPCLK
    
// RX mode control signals
    input           wire    m_req_in,
    input           wire    m_busy_in,
    output          wire    m_drpbusy_out,

// RX reset control signals
    input           wire    r_req_in,
    input           wire    r_busy_in,
    output          wire    r_drpbusy_out,

// GTP signals
    input           wire    g_drpbusy_in
);

//
// These parameters define the encoding of the FSM states
//
localparam STATE_WIDTH = 2;

localparam [STATE_WIDTH-1:0]
    IDLE_STATE              = 2'b00,
    R_GRANT_STATE           = 2'b01,
    M_GRANT_STATE           = 2'b10;

reg     [STATE_WIDTH-1:0]           current_state = IDLE_STATE;
reg     [STATE_WIDTH-1:0]           next_state;
reg                                 r_grant;
reg                                 m_grant;
reg                                 idle;

//
// These are the DRP grant signals and associated busy logic
//
assign m_drpbusy_out = g_drpbusy_in | r_grant | idle;

assign r_drpbusy_out = g_drpbusy_in | m_grant | idle;


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
        IDLE_STATE:
            if (g_drpbusy_in)
                next_state = IDLE_STATE;
            else if (r_req_in)
                next_state = R_GRANT_STATE;
            else if (m_req_in)
                next_state = M_GRANT_STATE;
            else
                next_state = IDLE_STATE;

        R_GRANT_STATE:
            if (r_req_in | r_busy_in)
                next_state = R_GRANT_STATE;
            else
                next_state = IDLE_STATE;

        M_GRANT_STATE:
            if (m_req_in | m_busy_in)
                next_state = M_GRANT_STATE;
            else
                next_state = IDLE_STATE;

        default:
            next_state = IDLE_STATE;
    endcase
end

//
// FSM output logic
//
always @ (*)
begin
    r_grant = 1'b0;
    m_grant = 1'b0;
    idle    = 1'b0;

    case(current_state)
        IDLE_STATE:
            idle = 1'b1;

        R_GRANT_STATE:
            r_grant = 1'b1;

        M_GRANT_STATE:
            m_grant = 1'b1;

        default:;
    endcase
end

endmodule
