// ##################################################################################
// Copyright (C) Altera Corporation
//
// This software and the related documents are Altera copyrighted materials, and
// your use of them is governed by the express license under which they were
// provided to you ("License"). Unless the License provides otherwise, you may
// not use, modify, copy, publish, distribute, disclose or transmit this software
// or the related documents without Altera's prior written permission.
//
// This software and the related documents are provided as is, with no express
// or implied warranties, other than those that are expressly stated in the License.
// ##################################################################################


`default_nettype none

module mitysom_25g_8cam
  (
    clk_133_mhz,
    rst_pb_n,


      // Code auto-generated from script: gts_eth_subsystem
      serial_i_rx_serial_data,
      serial_i_rx_serial_data_n,
      refclk_eth,
      serial_o_tx_serial_data,
      serial_o_tx_serial_data_n,

      // Code auto-generated from script: hsb_subsystem
      i2c_0_scl,
      i2c_0_sda,

      // Code auto-generated from script: mipi_subsystem
      LINK0_dphy_io_dphy_link_d_p,
      LINK0_dphy_io_dphy_link_d_n,
      LINK0_dphy_io_dphy_link_c_p,
      LINK0_dphy_io_dphy_link_c_n,
      LINK1_dphy_io_dphy_link_d_p,
      LINK1_dphy_io_dphy_link_d_n,
      LINK1_dphy_io_dphy_link_c_p,
      LINK1_dphy_io_dphy_link_c_n,
      LINK2_dphy_io_dphy_link_d_p,
      LINK2_dphy_io_dphy_link_d_n,
      LINK2_dphy_io_dphy_link_c_p,
      LINK2_dphy_io_dphy_link_c_n,
      LINK3_dphy_io_dphy_link_d_p,
      LINK3_dphy_io_dphy_link_d_n,
      LINK3_dphy_io_dphy_link_c_p,
      LINK3_dphy_io_dphy_link_c_n,
      LINK4_dphy_io_dphy_link_d_p,
      LINK4_dphy_io_dphy_link_d_n,
      LINK4_dphy_io_dphy_link_c_p,
      LINK4_dphy_io_dphy_link_c_n,
      LINK5_dphy_io_dphy_link_d_p,
      LINK5_dphy_io_dphy_link_d_n,
      LINK5_dphy_io_dphy_link_c_p,
      LINK5_dphy_io_dphy_link_c_n,
      LINK6_dphy_io_dphy_link_d_p,
      LINK6_dphy_io_dphy_link_d_n,
      LINK6_dphy_io_dphy_link_c_p,
      LINK6_dphy_io_dphy_link_c_n,
      LINK7_dphy_io_dphy_link_d_p,
      LINK7_dphy_io_dphy_link_d_n,
      LINK7_dphy_io_dphy_link_c_p,
      LINK7_dphy_io_dphy_link_c_n,
      mipi_ref_clk_0,
      mipi_rzq,
      mipi_ref_clk_1,
      mipi_rzq_1,

      // MitySOM-A5E STD status LEDs
      dbg_led_1,
      dbg_led_2,

      // MitySOM-A5E STD camera IOs (HSB GPIO, low until the host turns a camera on)
      cam1_io1,
      cam1_io2,
      cam2_io1,
      cam2_io2,
      cam3_io1,
      cam3_io2,
      cam4_io1,
      cam4_io2,
      cam5_io1,
      cam5_io2
  );

  input wire        clk_133_mhz;
  input wire        rst_pb_n;

   // Code auto-generated from script: gts_eth_subsystem
   input  wire    serial_i_rx_serial_data;
   input  wire    serial_i_rx_serial_data_n;
   input  wire    refclk_eth;
   output  wire    serial_o_tx_serial_data;
   output  wire    serial_o_tx_serial_data_n;

   // Code auto-generated from script: hsb_subsystem
   inout  wire    i2c_0_scl;
   inout  wire    i2c_0_sda;

   // Code auto-generated from script: mipi_subsystem
   input  wire  [3:0]  LINK0_dphy_io_dphy_link_d_p;
   input  wire  [3:0]  LINK0_dphy_io_dphy_link_d_n;
   input  wire    LINK0_dphy_io_dphy_link_c_p;
   input  wire    LINK0_dphy_io_dphy_link_c_n;
   input  wire  [3:0]  LINK1_dphy_io_dphy_link_d_p;
   input  wire  [3:0]  LINK1_dphy_io_dphy_link_d_n;
   input  wire    LINK1_dphy_io_dphy_link_c_p;
   input  wire    LINK1_dphy_io_dphy_link_c_n;
   input  wire  [3:0]  LINK2_dphy_io_dphy_link_d_p;
   input  wire  [3:0]  LINK2_dphy_io_dphy_link_d_n;
   input  wire    LINK2_dphy_io_dphy_link_c_p;
   input  wire    LINK2_dphy_io_dphy_link_c_n;
   input  wire  [3:0]  LINK3_dphy_io_dphy_link_d_p;
   input  wire  [3:0]  LINK3_dphy_io_dphy_link_d_n;
   input  wire    LINK3_dphy_io_dphy_link_c_p;
   input  wire    LINK3_dphy_io_dphy_link_c_n;
   input  wire  [3:0]  LINK4_dphy_io_dphy_link_d_p;
   input  wire  [3:0]  LINK4_dphy_io_dphy_link_d_n;
   input  wire    LINK4_dphy_io_dphy_link_c_p;
   input  wire    LINK4_dphy_io_dphy_link_c_n;
   input  wire  [3:0]  LINK5_dphy_io_dphy_link_d_p;
   input  wire  [3:0]  LINK5_dphy_io_dphy_link_d_n;
   input  wire    LINK5_dphy_io_dphy_link_c_p;
   input  wire    LINK5_dphy_io_dphy_link_c_n;
   input  wire  [3:0]  LINK6_dphy_io_dphy_link_d_p;
   input  wire  [3:0]  LINK6_dphy_io_dphy_link_d_n;
   input  wire    LINK6_dphy_io_dphy_link_c_p;
   input  wire    LINK6_dphy_io_dphy_link_c_n;
   input  wire  [3:0]  LINK7_dphy_io_dphy_link_d_p;
   input  wire  [3:0]  LINK7_dphy_io_dphy_link_d_n;
   input  wire    LINK7_dphy_io_dphy_link_c_p;
   input  wire    LINK7_dphy_io_dphy_link_c_n;
   input  wire    mipi_ref_clk_0;
   input  wire    mipi_rzq;
   input  wire    mipi_ref_clk_1;
   input  wire    mipi_rzq_1;

   // MitySOM-A5E STD status LEDs (HVIO bank 6D, 3.3V, active-high)
   output wire    dbg_led_1;
   output wire    dbg_led_2;

   // MitySOM-A5E STD camera IOs (HVIO bank 5B, 3.3V), driven by HSB GPIO
   output wire    cam1_io1;
   output wire    cam1_io2;
   output wire    cam2_io1;
   output wire    cam2_io2;
   output wire    cam3_io1;
   output wire    cam3_io2;
   output wire    cam4_io1;
   output wire    cam4_io2;
   output wire    cam5_io1;
   output wire    cam5_io2;

   // Code auto-generated from script: gts_eth_subsystem
   wire    o_rst_ack_n;
   wire    o_tx_rst_ack_n;
   wire    o_rx_rst_ack_n;
   wire    o_tx_lanes_stable;
   wire    o_rx_pcs_ready;
   wire    rx_is_lockedtodata;
   wire    o_tx_pll_locked;
   wire    eth_pll_lock;
   wire  [7:0]  o_rx_pfc;
   wire    o_rx_pause;

   // Code auto-generated from script: hsb_subsystem
   wire    i_i2c_0_scl;
   wire    i_i2c_0_sda;
   wire    o_i2c_0_scl_en;
   wire    o_i2c_0_sda_en;
   wire    i_i2c_1_scl;
   wire    i_i2c_1_sda;
   wire    o_i2c_1_scl_en;
   wire    o_i2c_1_sda_en;
   wire  [9:0]  cam_gpio;

   // Code auto-generated from script: mipi_subsystem
   wire  [31:0]  mipi_pio_0_in;
   wire  [31:0]  mipi_pio_0_out;

   // MitySOM-A5E STD: R12 on the baseboard pulls SFP TX_DISABLE low; no top-level port needed.

   // Code auto-generated from script: hsb_subsystem
   assign i_i2c_0_scl = i2c_0_scl;
   assign i_i2c_0_sda = i2c_0_sda;
   assign i2c_0_scl = o_i2c_0_scl_en ? 1'bz : 1'b0;
   assign i2c_0_sda = o_i2c_0_sda_en ? 1'bz : 1'b0;
   // i2c_1 (HSB 2nd I2C master) is unused on MitySOM-A5E STD and not brought to a pin.
   // Tie the master's bus inputs idle-high; its output-enables (o_i2c_1_*_en) are left
   // unconnected. The HSB IP keeps both I2C masters so its register map is unchanged.
   assign i_i2c_1_scl = 1'b1;
   assign i_i2c_1_sda = 1'b1;

   // Code auto-generated from script: mipi_subsystem
   assign mipi_pio_0_in[31:12] = 20'b0;
   assign mipi_pio_0_in[11:8] = 4'b0001;
   assign mipi_pio_0_in[7:4] = 4'b0001;
   assign mipi_pio_0_in[3] = 1'b0;
   assign mipi_pio_0_in[2] = 1'b1;
   assign mipi_pio_0_in[1] = 1'b0;
   assign mipi_pio_0_in[0] = 1'b1;

  mitysom_25g_8cam_qsys u0 (
    .board_subsystem_i_clk_clk             (clk_133_mhz),
    .board_subsystem_ia_reset_pb_n_reset   (rst_pb_n),

      // Code auto-generated from script: gts_eth_subsystem
       .gts_eth_subsystem_i_refclk_eth_clk  (refclk_eth),
       .gts_eth_subsystem_c_src_rs_priority_src_rs_priority  (1'b0),
       .gts_eth_subsystem_c_refclk_rdy_data  (1'b1),
       .gts_eth_subsystem_c_status_ports_1_o_sys_pll_locked  (eth_pll_lock),
       .gts_eth_subsystem_c_serial_o_tx_serial_data  (serial_o_tx_serial_data),
       .gts_eth_subsystem_c_serial_i_rx_serial_data  (serial_i_rx_serial_data),
       .gts_eth_subsystem_c_serial_o_tx_serial_data_n  (serial_o_tx_serial_data_n),
       .gts_eth_subsystem_c_serial_i_rx_serial_data_n  (serial_i_rx_serial_data_n),
       .gts_eth_subsystem_c_clk_status_o_cdr_lock  (rx_is_lockedtodata),
       .gts_eth_subsystem_c_clk_status_o_tx_pll_locked  (o_tx_pll_locked),
       .gts_eth_subsystem_c_clk_status_o_tx_lanes_stable  (o_tx_lanes_stable),
       .gts_eth_subsystem_c_clk_status_o_rx_pcs_ready  (o_rx_pcs_ready),
       .gts_eth_subsystem_c_rst_status_o_rst_ack_n  (o_rst_ack_n),
       .gts_eth_subsystem_c_rst_status_o_tx_rst_ack_n  (o_tx_rst_ack_n),
       .gts_eth_subsystem_c_rst_status_o_rx_rst_ack_n  (o_rx_rst_ack_n),
       .gts_eth_subsystem_i_eth_intf_rst_reset  (~eth_pll_lock),
       .gts_eth_subsystem_c_tx_ports_i_tx_skip_crc  (1'b0),
       .gts_eth_subsystem_c_pfc_ports_i_tx_pfc  (8'h00),
       .gts_eth_subsystem_c_pfc_ports_o_rx_pfc  (o_rx_pfc),
       .gts_eth_subsystem_c_sfc_ports_i_tx_pause  (1'b0),
       .gts_eth_subsystem_c_sfc_ports_o_rx_pause  (o_rx_pause),
       .gts_eth_subsystem_i_clk_pll_clk  (1'b0),

      // Code auto-generated from script: hsb_subsystem
       .hsb_subsystem_c_i2c_0_i_i2c_scl  (i_i2c_0_scl),
       .hsb_subsystem_c_i2c_0_i_i2c_sda  (i_i2c_0_sda),
       .hsb_subsystem_c_i2c_0_o_i2c_scl_en  (o_i2c_0_scl_en),
       .hsb_subsystem_c_i2c_0_o_i2c_sda_en  (o_i2c_0_sda_en),
       .hsb_subsystem_c_i2c_1_i_i2c_scl  (i_i2c_1_scl),
       .hsb_subsystem_c_i2c_1_i_i2c_sda  (i_i2c_1_sda),
       .hsb_subsystem_c_i2c_1_o_i2c_scl_en  (o_i2c_1_scl_en),
       .hsb_subsystem_c_i2c_1_o_i2c_sda_en  (o_i2c_1_sda_en),
       .hsb_subsystem_c_gpio_o_gpio  (cam_gpio),
       .hsb_subsystem_c_gpio_i_gpio  (cam_gpio),

      // Code auto-generated from script: mipi_subsystem
       .mipi_subsystem_c_ext_conn_in_port  (mipi_pio_0_in),
       .mipi_subsystem_c_ext_conn_out_port  (mipi_pio_0_out),
       .mipi_subsystem_c_LINK0_dphy_io_dphy_link_dp  (LINK0_dphy_io_dphy_link_d_p),
       .mipi_subsystem_c_LINK0_dphy_io_dphy_link_dn  (LINK0_dphy_io_dphy_link_d_n),
       .mipi_subsystem_c_LINK0_dphy_io_dphy_link_cp  (LINK0_dphy_io_dphy_link_c_p),
       .mipi_subsystem_c_LINK0_dphy_io_dphy_link_cn  (LINK0_dphy_io_dphy_link_c_n),
       .mipi_subsystem_c_LINK1_dphy_io_dphy_link_dp  (LINK1_dphy_io_dphy_link_d_p),
       .mipi_subsystem_c_LINK1_dphy_io_dphy_link_dn  (LINK1_dphy_io_dphy_link_d_n),
       .mipi_subsystem_c_LINK1_dphy_io_dphy_link_cp  (LINK1_dphy_io_dphy_link_c_p),
       .mipi_subsystem_c_LINK1_dphy_io_dphy_link_cn  (LINK1_dphy_io_dphy_link_c_n),
       .mipi_subsystem_c_LINK2_dphy_io_dphy_link_dp  (LINK2_dphy_io_dphy_link_d_p),
       .mipi_subsystem_c_LINK2_dphy_io_dphy_link_dn  (LINK2_dphy_io_dphy_link_d_n),
       .mipi_subsystem_c_LINK2_dphy_io_dphy_link_cp  (LINK2_dphy_io_dphy_link_c_p),
       .mipi_subsystem_c_LINK2_dphy_io_dphy_link_cn  (LINK2_dphy_io_dphy_link_c_n),
       .mipi_subsystem_c_LINK3_dphy_io_dphy_link_dp  (LINK3_dphy_io_dphy_link_d_p),
       .mipi_subsystem_c_LINK3_dphy_io_dphy_link_dn  (LINK3_dphy_io_dphy_link_d_n),
       .mipi_subsystem_c_LINK3_dphy_io_dphy_link_cp  (LINK3_dphy_io_dphy_link_c_p),
       .mipi_subsystem_c_LINK3_dphy_io_dphy_link_cn  (LINK3_dphy_io_dphy_link_c_n),
       .mipi_subsystem_c_LINK4_dphy_io_dphy_link_dp  (LINK4_dphy_io_dphy_link_d_p),
       .mipi_subsystem_c_LINK4_dphy_io_dphy_link_dn  (LINK4_dphy_io_dphy_link_d_n),
       .mipi_subsystem_c_LINK4_dphy_io_dphy_link_cp  (LINK4_dphy_io_dphy_link_c_p),
       .mipi_subsystem_c_LINK4_dphy_io_dphy_link_cn  (LINK4_dphy_io_dphy_link_c_n),
       .mipi_subsystem_c_LINK5_dphy_io_dphy_link_dp  (LINK5_dphy_io_dphy_link_d_p),
       .mipi_subsystem_c_LINK5_dphy_io_dphy_link_dn  (LINK5_dphy_io_dphy_link_d_n),
       .mipi_subsystem_c_LINK5_dphy_io_dphy_link_cp  (LINK5_dphy_io_dphy_link_c_p),
       .mipi_subsystem_c_LINK5_dphy_io_dphy_link_cn  (LINK5_dphy_io_dphy_link_c_n),
       .mipi_subsystem_c_LINK6_dphy_io_dphy_link_dp  (LINK6_dphy_io_dphy_link_d_p),
       .mipi_subsystem_c_LINK6_dphy_io_dphy_link_dn  (LINK6_dphy_io_dphy_link_d_n),
       .mipi_subsystem_c_LINK6_dphy_io_dphy_link_cp  (LINK6_dphy_io_dphy_link_c_p),
       .mipi_subsystem_c_LINK6_dphy_io_dphy_link_cn  (LINK6_dphy_io_dphy_link_c_n),
       .mipi_subsystem_c_LINK7_dphy_io_dphy_link_dp  (LINK7_dphy_io_dphy_link_d_p),
       .mipi_subsystem_c_LINK7_dphy_io_dphy_link_dn  (LINK7_dphy_io_dphy_link_d_n),
       .mipi_subsystem_c_LINK7_dphy_io_dphy_link_cp  (LINK7_dphy_io_dphy_link_c_p),
       .mipi_subsystem_c_LINK7_dphy_io_dphy_link_cn  (LINK7_dphy_io_dphy_link_c_n),
       .mipi_subsystem_i_clk_ref_clk  (mipi_ref_clk_0),
       .mipi_subsystem_c_rzq_rzq  (mipi_rzq),
       .mipi_subsystem_i_clk_ref_1_clk  (mipi_ref_clk_1),
       .mipi_subsystem_c_rzq_1_rzq  (mipi_rzq_1)
  );

   // MitySOM-A5E STD status LEDs (active-high):
   //   dbg_led_1 = GTS system PLL locked; dbg_led_2 = RX CDR lock (SFP cage linked)
   assign dbg_led_1 = eth_pll_lock;
   assign dbg_led_2 = rx_is_lockedtodata;

   // HSB GPIO pin 2 x camera + (IO - 1) drives camera IO1/IO2. The outputs also feed the GPIO
   // inputs: the host sets one pin by reading the input register and writing the output register.
   assign {cam5_io2, cam5_io1, cam4_io2, cam4_io1, cam3_io2, cam3_io1,
           cam2_io2, cam2_io1, cam1_io2, cam1_io1} = cam_gpio;

endmodule

`default_nettype wire









