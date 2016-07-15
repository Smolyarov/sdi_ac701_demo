// (c) Copyright 2001 - 2013 Xilinx, Inc. All rights reserved.
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
//  /   /         Filename: $File: //Groups/video_ip/demos/A7/xapp1097_a7_sdi_demos/Verilog/SDI_wrapper/sdi_rate_detect.v $
// /___/   /\     Timestamp: $DateTime: 2013/09/30 13:31:35 $
// \   \  /  \
//  \___\/\___\
//
// Description:
//  This module implements two counters. One driven by the reference clock and
//  other driven by the recovered clock. The two counters help in automatic 
//  recognition of the two HD-SDI bit rates. 
//  
//  This module also looks for the clock frequency change and generates a reset
//  signal whenever there is asynchronous clock switching due to rate change or
//  any other reason. It also indicates whenever a drift is seen in the recovered
//  clock beyond a threshold value. This module validates the changes number of 
//  times before generating the reset or clock drift status signals. 
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

module sdi_rate_detect # (
    parameter   REFCLK_FREQ     =   33333333)   // Reference clock in Hz
(
    input  wire refclk,     // reference clock
    input  wire recvclk,    // recovered clock
    input  wire std,        // 0 = HD, 1 = 3G
    input  wire enable,     // Use to hold the module when driven by improper clock
                            // It is active low signal 
    
    output wire rate_change,// indicates a change in rate
    output reg  drift = 0,  // Indicates if recovered clock has significantly
                            // drifted from its expected value.
    output wire rate
);  

localparam MAX_COUNT_REF = REFCLK_FREQ/1000;            // Reference value for 1 millisec
localparam MAX_COUNT_RXREC = 74250;                     // Reference count value for 74.25 MHz clock for
                                                        // a period of one millisec
localparam MAX_COUNT_REF_MONITOR = 744999;              // Variable count value used to validate the change
                                                        // in the status of clock frequency. The rate detector
                                                        // validates the change in status of clock frequency
                                                        // before indicating the changed status

localparam TEST_VAL_RXREC = MAX_COUNT_RXREC - 38;       // Reference value used to decide whether HD rate has
                                                        // changed or not
localparam DRIFT_COUNT1 = MAX_COUNT_RXREC + 125;        // Upper threshold value used for clock drift detection
localparam DRIFT_COUNT2 = MAX_COUNT_RXREC - 125;        // Lower threshold value used for clock drift detection

// This group of parameters defines the states of the FSM.
//                                              
parameter STATE_WIDTH   = 3;
parameter STATE_MSB     = STATE_WIDTH - 1;

//---------------States for validation state machine----------------------------

parameter [STATE_WIDTH-1:0]
    WAIT            = 0,
    START           = 1,
    CHECK           = 2,
    DOUBLE_CHECK1   = 3,
    DOUBLE_CHECK2   = 4,
    END             = 5;
     
reg  [17:0]         count_ref = 0;                   // Counts the reference clock
reg  [17:0]         count_recv = 0;                  // Counts the recovered clock

//----------------Internal Signals----------------------------------------------
wire                count_ref_tc;
reg  [1:0]          tc_reg = 0;
(* shreg_extract = "NO" *)  
reg  [4:0]          capture_reg = 0;
wire                capture;
reg                 drift_int = 0;
reg                 toggle = 0;
reg  [1:0]          count_drift = 0;
reg  [1:0]          drift_reg = 0;
reg                 drift_sts = 0;
reg                 capture_dly = 0;

// control logic signals

reg  [STATE_MSB:0]  current_state = WAIT;   // FSM current state
reg  [STATE_MSB:0]  next_state;             // FSM next state

reg  [24:0]         count_monitor = 0;
reg  [ 1:0]         check_count = 0;
reg  [ 1:0]         hd_reg = 0;
(* shreg_extract = "NO" *)  
reg  [ 1:0]         enable_reg = 0;  // Register definition for synchronisation to reference clk domain
(* shreg_extract = "NO" *)  
reg  [ 1:0]         enable_rec = 0;  // Register definition for synchronisation to recovered clk domain
reg                 reset_reg = 0;
reg                 rate_int = 0;
reg                 count_clr;
reg                 clr_cnt;
reg                 inc_cnt;  
reg                 count_inc;
reg                 load_final;
reg                 clr_final;
wire                hd_change; 
wire                count_monitor_tc;
wire                max_check;


//-------------------------------------------------------------------
// Synchronization logic for enable input
always @ (posedge refclk)
    enable_reg <= {enable_reg[0] , enable};

always @ (posedge recvclk)
    enable_rec <= {enable_rec[0] , enable};

//-------------------------------------------------------------------

// This is a counter that counts the event on the reference clock for
// comparing that with the recovered clock. The counter gets reset after
// 1 millisec. This design compares the recovered clock with the reference
// clock every 1 millisec to compute HD rate change or clock drift 

always @ (posedge refclk)
    if (count_ref_tc | (~enable_reg[1]))
        count_ref <= MAX_COUNT_REF;
    else  
        count_ref <= count_ref - 1;

assign count_ref_tc = (count_ref == 1) ;      // Goes high every 1 millisec.

// This logic extends the pulse to ensure that it is not missed when sampled by a
// slower clock

always @ (posedge refclk)
    tc_reg <= {tc_reg[0], count_ref_tc};

// Synchronisation to recovered clock domain 

always @ (posedge recvclk)
    capture_reg <= {capture_reg[3:0], |tc_reg};

assign capture = capture_reg[2] & ~capture_reg[3] & ~capture_reg[4];

// This implements a counter for counting the events on the recovered clock.
// The count reading is compared to a predefined value at a fixed interval of
// time to compute the clock rate or any drift in the recovered clock. The 
// counter counts every clock event when the std input is '0' else counts
// every alternate event when it is set to '1'. This is done to support
// both HD-SDI and 3G-SDI protocols.

always @ (posedge recvclk)
    if (capture | (~enable_rec[1]))
    begin
        count_recv <= 0;
        toggle     <= 0;
    end
    else
    begin
        if (~std)
        begin
            toggle     <= 0;
            count_recv <= count_recv + 1;
        end
        else
        begin
            if (~toggle)
            begin
                count_recv <= count_recv + 1;
                toggle  <= ~toggle;
            end
            else
            begin
                count_recv <= count_recv;
                toggle  <= ~toggle;
            end
        end  
    end
      
// This process looks for clock drift from its mean position on one
// direction indicating that the rate of input data rate has changed
//   

always @ (posedge recvclk)
    if (capture)
        rate_int <= (count_recv < TEST_VAL_RXREC);

// This process helps to detect any change in the received HD-SDI bit rate.

always @ (posedge refclk)
    hd_reg <= {hd_reg[0] , rate_int};

assign hd_change = ^hd_reg;

assign rate = hd_reg[1];  

 
// This process looks for clock drift from its mean position. It generates
// an output whenever the clock drift away beyond a particular range on
// either side. The threshold value for this logic is more than that used
// for rate detection in order to avoid the faulty status

always @ (posedge recvclk)
    if (capture)
        drift_int <= (count_recv > DRIFT_COUNT1)|(count_recv < DRIFT_COUNT2);   

always @ (posedge recvclk)
    capture_dly <= capture;

// This logic is used to validate the clock drift for a period of 4 millisec
// before validating it. During this period if the drift status changes it
// shifts the window and continues with the check 

always @ (posedge recvclk)
    if (capture_dly)
    begin      
        if (count_drift == 3 | drift_sts != drift_int)
        begin
            count_drift <= 0;
            drift_sts   <= drift_int;
        end
        else
        begin
            count_drift <= count_drift + 1;
            drift_sts   <= drift_int;
        end     
    end         

always @ (posedge recvclk)
    if (count_drift == 3)
        drift <= drift_sts;  

//**************************** control logic **********************************  
// The logic written now onwards is to generate a reset pulse whenever a change
// is detected in the recovered clock due to either change in the received data
// rate or due to temporary data lost resulting in GTX CDR losing lock resulting
// recovered clock drifting wildly away from its mean position.
// The fabric design can also get re-initialized to unknown state due to this
// asynchronous clock switching and it has to be brought to a known initial 
// state for proper operation to continue.
//

always @ (posedge refclk)
    if (clr_final)
        reset_reg <= 0;
    else if (load_final)
        reset_reg <= 1'b1;

assign rate_change =  reset_reg; 

always @ (posedge refclk)
    if (count_clr)
        count_monitor <= 0;
    else if (count_inc)
        count_monitor <= count_monitor + 1;

assign count_monitor_tc = (count_monitor == MAX_COUNT_REF_MONITOR);

always @ (posedge refclk)
    if (clr_cnt)
        check_count <= 0;
    else if (inc_cnt)
        check_count <= check_count + 1;

assign max_check = (check_count == 2'b11);  

always @ (posedge refclk)
    drift_reg <= {drift_reg[0] , drift};

//
// FSM: current_state register
//
// This code implements the current state register. It loads with the WAIT
// state on reset and the next_state value with each rising clock edge.
//
always @ (posedge refclk)
    current_state <= next_state;

//
// FSM: next_state logic
//
// This case statement generates the next_state value for the FSM based on
// the current_state and the various FSM inputs.
//
always @ *
    case(current_state)
        
        WAIT:           if (hd_change | drift_reg[1])
                            next_state = START;
                        else
                            next_state = WAIT;
        
        START:          if(count_monitor_tc)
                            next_state = CHECK;
                        else
                            next_state = START;

        CHECK:          if(hd_change)
                            next_state = DOUBLE_CHECK1;
                        else
                            next_state = DOUBLE_CHECK2;
        
        DOUBLE_CHECK1:  next_state = DOUBLE_CHECK2;
                                   
        DOUBLE_CHECK2:  if (max_check)
                            next_state = END;
                        else
                            next_state = START;
         
        END :           next_state = WAIT;
    
        default:        next_state = WAIT;

   endcase

//
// FSM: outputs
//
// This block decodes the current state to generate the various outputs of the
// FSM.
//
always @(current_state) 
begin
// Unless specifically assigned in the case statement, all FSM outputs are low.
    inc_cnt         = 1'b0;
    clr_cnt         = 1'b0;
    count_clr       = 1'b0;
    count_inc       = 1'b0;
    load_final      = 1'b0;
    clr_final       = 1'b0;
         
    case(current_state) 
         
        WAIT: begin
                count_clr = 1'b1; 
                clr_cnt   = 1'b1;
                clr_final = 1'b1;
        end
                
        START:          
                count_inc = 1'b1;
           
        CHECK:          
                count_clr = 1'b1;

        DOUBLE_CHECK1:  
                clr_cnt   = 1'b1;

        DOUBLE_CHECK2:  
                inc_cnt = 1'b1;

        END:            
                load_final = 1'b1;
            
    endcase
end

endmodule




