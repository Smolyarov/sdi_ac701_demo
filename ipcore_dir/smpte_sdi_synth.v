/*******************************************************************************
*     This file is owned and controlled by Xilinx and must be used solely      *
*     for design, simulation, implementation and creation of design files      *
*     limited to Xilinx devices or technologies. Use with non-Xilinx           *
*     devices or technologies is expressly prohibited and immediately          *
*     terminates your license.                                                 *
*                                                                              *
*     XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" SOLELY     *
*     FOR USE IN DEVELOPING PROGRAMS AND SOLUTIONS FOR XILINX DEVICES.  BY     *
*     PROVIDING THIS DESIGN, CODE, OR INFORMATION AS ONE POSSIBLE              *
*     IMPLEMENTATION OF THIS FEATURE, APPLICATION OR STANDARD, XILINX IS       *
*     MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION IS FREE FROM ANY       *
*     CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE FOR OBTAINING ANY        *
*     RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY        *
*     DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE    *
*     IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR           *
*     REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF          *
*     INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A    *
*     PARTICULAR PURPOSE.                                                      *
*                                                                              *
*     Xilinx products are not intended for use in life support appliances,     *
*     devices, or systems.  Use in such applications are expressly             *
*     prohibited.                                                              *
*                                                                              *
*     (c) Copyright 1995-2016 Xilinx, Inc.                                     *
*     All rights reserved.                                                     *
*******************************************************************************/

/*******************************************************************************
*     Generated from core with identifier: xilinx.com:ip:v_smpte_sdi:1.0       *
*                                                                              *
*     SMPTE Serial Digital Interface carries uncompressed digital video and    *
*     ancillary data                                                           *
*******************************************************************************/
// Source Code Wrapper
// This file is provided to wrap around the source code (if appropriate)

module smpte_sdi (
  rx_rst,
  rx_usrclk,
  rx_data_in,
  rx_sd_data_in,
  rx_sd_data_strobe,
  rx_frame_en,
  rx_mode_en,
  rx_mode,
  rx_mode_HD,
  rx_mode_SD,
  rx_mode_3G,
  rx_mode_detect_en,
  rx_mode_locked,
  rx_forced_mode,
  rx_bit_rate,
  rx_t_locked,
  rx_t_family,
  rx_t_rate,
  rx_t_scan,
  rx_level_b_3G,
  rx_ce_sd,
  rx_nsp,
  rx_line_a,
  rx_a_vpid,
  rx_a_vpid_valid,
  rx_b_vpid,
  rx_b_vpid_valid,
  rx_crc_err_a,
  rx_ds1a,
  rx_ds2a,
  rx_eav,
  rx_sav,
  rx_trs,
  rx_line_b,
  rx_dout_rdy_3G,
  rx_crc_err_b,
  rx_ds1b,
  rx_ds2b,
  rx_edh_errcnt_en,
  rx_edh_clr_errcnt,
  rx_edh_ap,
  rx_edh_ff,
  rx_edh_anc,
  rx_edh_ap_flags,
  rx_edh_ff_flags,
  rx_edh_anc_flags,
  rx_edh_packet_flags,
  rx_edh_errcnt,
  tx_rst,
  tx_usrclk,
  tx_ce,
  tx_din_rdy,
  tx_mode,
  tx_level_b_3G,
  tx_insert_crc,
  tx_insert_ln,
  tx_insert_edh,
  tx_insert_vpid,
  tx_overwrite_vpid,
  tx_video_a_y_in,
  tx_video_a_c_in,
  tx_video_b_y_in,
  tx_video_b_c_in,
  tx_line_a,
  tx_line_b,
  tx_vpid_byte1,
  tx_vpid_byte2,
  tx_vpid_byte3,
  tx_vpid_byte4a,
  tx_vpid_byte4b,
  tx_vpid_line_f1,
  tx_vpid_line_f2,
  tx_vpid_line_f2_en,
  tx_ds1a_out,
  tx_ds2a_out,
  tx_ds1b_out,
  tx_ds2b_out,
  tx_use_dsin,
  tx_ds1a_in,
  tx_ds2a_in,
  tx_ds1b_in,
  tx_ds2b_in,
  tx_sd_bitrep_bypass,
  tx_txdata,
  tx_ce_align_err
);

  input rx_rst;
  input rx_usrclk;
  input [19 : 0] rx_data_in;
  input [9 : 0] rx_sd_data_in;
  input rx_sd_data_strobe;
  input rx_frame_en;
  input [2 : 0] rx_mode_en;
  output [1 : 0] rx_mode;
  output rx_mode_HD;
  output rx_mode_SD;
  output rx_mode_3G;
  input rx_mode_detect_en;
  output rx_mode_locked;
  input [1 : 0] rx_forced_mode;
  input rx_bit_rate;
  output rx_t_locked;
  output [3 : 0] rx_t_family;
  output [3 : 0] rx_t_rate;
  output rx_t_scan;
  output rx_level_b_3G;
  output rx_ce_sd;
  output rx_nsp;
  output [10 : 0] rx_line_a;
  output [31 : 0] rx_a_vpid;
  output rx_a_vpid_valid;
  output [31 : 0] rx_b_vpid;
  output rx_b_vpid_valid;
  output rx_crc_err_a;
  output [9 : 0] rx_ds1a;
  output [9 : 0] rx_ds2a;
  output rx_eav;
  output rx_sav;
  output rx_trs;
  output [10 : 0] rx_line_b;
  output rx_dout_rdy_3G;
  output rx_crc_err_b;
  output [9 : 0] rx_ds1b;
  output [9 : 0] rx_ds2b;
  input [15 : 0] rx_edh_errcnt_en;
  input rx_edh_clr_errcnt;
  output rx_edh_ap;
  output rx_edh_ff;
  output rx_edh_anc;
  output [4 : 0] rx_edh_ap_flags;
  output [4 : 0] rx_edh_ff_flags;
  output [4 : 0] rx_edh_anc_flags;
  output [3 : 0] rx_edh_packet_flags;
  output [15 : 0] rx_edh_errcnt;
  input tx_rst;
  input tx_usrclk;
  input [2 : 0] tx_ce;
  input tx_din_rdy;
  input [1 : 0] tx_mode;
  input tx_level_b_3G;
  input tx_insert_crc;
  input tx_insert_ln;
  input tx_insert_edh;
  input tx_insert_vpid;
  input tx_overwrite_vpid;
  input [9 : 0] tx_video_a_y_in;
  input [9 : 0] tx_video_a_c_in;
  input [9 : 0] tx_video_b_y_in;
  input [9 : 0] tx_video_b_c_in;
  input [10 : 0] tx_line_a;
  input [10 : 0] tx_line_b;
  input [7 : 0] tx_vpid_byte1;
  input [7 : 0] tx_vpid_byte2;
  input [7 : 0] tx_vpid_byte3;
  input [7 : 0] tx_vpid_byte4a;
  input [7 : 0] tx_vpid_byte4b;
  input [10 : 0] tx_vpid_line_f1;
  input [10 : 0] tx_vpid_line_f2;
  input tx_vpid_line_f2_en;
  output [9 : 0] tx_ds1a_out;
  output [9 : 0] tx_ds2a_out;
  output [9 : 0] tx_ds1b_out;
  output [9 : 0] tx_ds2b_out;
  input tx_use_dsin;
  input [9 : 0] tx_ds1a_in;
  input [9 : 0] tx_ds2a_in;
  input [9 : 0] tx_ds1b_in;
  input [9 : 0] tx_ds2b_in;
  input tx_sd_bitrep_bypass;
  output [19 : 0] tx_txdata;
  output tx_ce_align_err;

  v_smpte_sdi_v1_0 #(
    .C_FAMILY("artix7"),
    .INCLUDE_RX_EDH_PROCESSOR("FALSE")
  ) inst (
    .rx_rst(rx_rst),
    .rx_usrclk(rx_usrclk),
    .rx_data_in(rx_data_in),
    .rx_sd_data_in(rx_sd_data_in),
    .rx_sd_data_strobe(rx_sd_data_strobe),
    .rx_frame_en(rx_frame_en),
    .rx_mode_en(rx_mode_en),
    .rx_mode(rx_mode),
    .rx_mode_HD(rx_mode_HD),
    .rx_mode_SD(rx_mode_SD),
    .rx_mode_3G(rx_mode_3G),
    .rx_mode_detect_en(rx_mode_detect_en),
    .rx_mode_locked(rx_mode_locked),
    .rx_forced_mode(rx_forced_mode),
    .rx_bit_rate(rx_bit_rate),
    .rx_t_locked(rx_t_locked),
    .rx_t_family(rx_t_family),
    .rx_t_rate(rx_t_rate),
    .rx_t_scan(rx_t_scan),
    .rx_level_b_3G(rx_level_b_3G),
    .rx_ce_sd(rx_ce_sd),
    .rx_nsp(rx_nsp),
    .rx_line_a(rx_line_a),
    .rx_a_vpid(rx_a_vpid),
    .rx_a_vpid_valid(rx_a_vpid_valid),
    .rx_b_vpid(rx_b_vpid),
    .rx_b_vpid_valid(rx_b_vpid_valid),
    .rx_crc_err_a(rx_crc_err_a),
    .rx_ds1a(rx_ds1a),
    .rx_ds2a(rx_ds2a),
    .rx_eav(rx_eav),
    .rx_sav(rx_sav),
    .rx_trs(rx_trs),
    .rx_line_b(rx_line_b),
    .rx_dout_rdy_3G(rx_dout_rdy_3G),
    .rx_crc_err_b(rx_crc_err_b),
    .rx_ds1b(rx_ds1b),
    .rx_ds2b(rx_ds2b),
    .rx_edh_errcnt_en(rx_edh_errcnt_en),
    .rx_edh_clr_errcnt(rx_edh_clr_errcnt),
    .rx_edh_ap(rx_edh_ap),
    .rx_edh_ff(rx_edh_ff),
    .rx_edh_anc(rx_edh_anc),
    .rx_edh_ap_flags(rx_edh_ap_flags),
    .rx_edh_ff_flags(rx_edh_ff_flags),
    .rx_edh_anc_flags(rx_edh_anc_flags),
    .rx_edh_packet_flags(rx_edh_packet_flags),
    .rx_edh_errcnt(rx_edh_errcnt),
    .tx_rst(tx_rst),
    .tx_usrclk(tx_usrclk),
    .tx_ce(tx_ce),
    .tx_din_rdy(tx_din_rdy),
    .tx_mode(tx_mode),
    .tx_level_b_3G(tx_level_b_3G),
    .tx_insert_crc(tx_insert_crc),
    .tx_insert_ln(tx_insert_ln),
    .tx_insert_edh(tx_insert_edh),
    .tx_insert_vpid(tx_insert_vpid),
    .tx_overwrite_vpid(tx_overwrite_vpid),
    .tx_video_a_y_in(tx_video_a_y_in),
    .tx_video_a_c_in(tx_video_a_c_in),
    .tx_video_b_y_in(tx_video_b_y_in),
    .tx_video_b_c_in(tx_video_b_c_in),
    .tx_line_a(tx_line_a),
    .tx_line_b(tx_line_b),
    .tx_vpid_byte1(tx_vpid_byte1),
    .tx_vpid_byte2(tx_vpid_byte2),
    .tx_vpid_byte3(tx_vpid_byte3),
    .tx_vpid_byte4a(tx_vpid_byte4a),
    .tx_vpid_byte4b(tx_vpid_byte4b),
    .tx_vpid_line_f1(tx_vpid_line_f1),
    .tx_vpid_line_f2(tx_vpid_line_f2),
    .tx_vpid_line_f2_en(tx_vpid_line_f2_en),
    .tx_ds1a_out(tx_ds1a_out),
    .tx_ds2a_out(tx_ds2a_out),
    .tx_ds1b_out(tx_ds1b_out),
    .tx_ds2b_out(tx_ds2b_out),
    .tx_use_dsin(tx_use_dsin),
    .tx_ds1a_in(tx_ds1a_in),
    .tx_ds2a_in(tx_ds2a_in),
    .tx_ds1b_in(tx_ds1b_in),
    .tx_ds2b_in(tx_ds2b_in),
    .tx_sd_bitrep_bypass(tx_sd_bitrep_bypass),
    .tx_txdata(tx_txdata),
    .tx_ce_align_err(tx_ce_align_err)
  );

endmodule

