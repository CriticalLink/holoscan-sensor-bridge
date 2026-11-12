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

module mitysom_ae3v_25g_hps_8cam
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
      cam5_io2,

      // Code auto-generated for HPS subsystem (hps_subsys)
      // LPDDR4 EMIF (bank 3A, shared with LINK4 D-PHY)
      HPS_CK_T, HPS_CK_C, HPS_CKE, HPS_MEM_RESET_N, HPS_CS, HPS_CA,
      HPS_DQ, HPS_DQS_T, HPS_DQS_C, HPS_DMI, HPS_RZQ, HPS_CLKIN_P,
      HPS_CLK_25MHz,
      // SD/MMC (boot + rootfs)
      SDMMC_CLK, SDMMC_CMD, SDMMC_D, SDCARD_PRSNT,
      // UART1 console / I2C1 / I3C0 / EMAC sideband I2C
      UART_TX, UART_RX, I2C1_SDA, I2C1_SCL, I3C0_SDA, I3C0_SCL,
      I2C_EMAC0_SDA, I2C_EMAC0_SCL, I2C_EMAC1_SDA, I2C_EMAC1_SCL,
      I2C_EMAC2_SDA, I2C_EMAC2_SCL,
      // USB2 ULPI (usb0, usb1)
      i_usb0_clk, i_usb0_dir, i_usb0_nxt, o_usb0_stp, o_usb0_ulpi_reset_n,
      io_usb0_data0, io_usb0_data1, io_usb0_data2, io_usb0_data3,
      io_usb0_data4, io_usb0_data5, io_usb0_data6, io_usb0_data7,
      i_usb1_clk, i_usb1_dir, i_usb1_nxt, o_usb1_stp, o_usb1_ulpi_reset_n,
      io_usb1_data0, io_usb1_data1, io_usb1_data2, io_usb1_data3,
      io_usb1_data4, io_usb1_data5, io_usb1_data6, io_usb1_data7,
      // USB3.1 PHY (USB-C sideband not connected)
      i_usb31_phy_refclk_p_clk,
      i_usb31_phy_rx_serial_n_i_rx_serial_n, i_usb31_phy_rx_serial_p_i_rx_serial_p,
      o_usb31_phy_tx_serial_n_o_tx_serial_n, o_usb31_phy_tx_serial_p_o_tx_serial_p,
      // misc HPS GPIO
      ETH2_RESETn, FAN_EN
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

   // HPS subsystem (hps_subsys) top-level IO
   // LPDDR4 EMIF (bank 3A, 1.1V, shared with LINK4 D-PHY)
   output wire         HPS_CK_T;
   output wire         HPS_CK_C;
   output wire [1:0]   HPS_CKE;
   output wire         HPS_MEM_RESET_N;
   output wire [1:0]   HPS_CS;
   output wire [5:0]   HPS_CA;
   inout  wire [31:0]  HPS_DQ;
   inout  wire [3:0]   HPS_DQS_T;
   inout  wire [3:0]   HPS_DQS_C;
   inout  wire [3:0]   HPS_DMI;
   input  wire         HPS_RZQ;
   input  wire         HPS_CLKIN_P;
   // HPS 25 MHz boot oscillator
   input  wire         HPS_CLK_25MHz;
   // SD/MMC
   output wire         SDMMC_CLK;
   inout  wire         SDMMC_CMD;
   inout  wire [3:0]   SDMMC_D;
   inout  wire         SDCARD_PRSNT;
   // UART1 / I2C1 / I3C0 / EMAC sideband I2C
   output wire         UART_TX;
   input  wire         UART_RX;
   inout  wire         I2C1_SDA;
   inout  wire         I2C1_SCL;
   inout  wire         I3C0_SDA;
   inout  wire         I3C0_SCL;
   inout  wire         I2C_EMAC0_SDA;
   inout  wire         I2C_EMAC0_SCL;
   inout  wire         I2C_EMAC1_SDA;
   inout  wire         I2C_EMAC1_SCL;
   inout  wire         I2C_EMAC2_SDA;
   inout  wire         I2C_EMAC2_SCL;
   // USB2 ULPI usb0
   input  wire         i_usb0_clk;
   input  wire         i_usb0_dir;
   input  wire         i_usb0_nxt;
   output wire         o_usb0_stp;
   inout  wire         o_usb0_ulpi_reset_n;
   inout  wire         io_usb0_data0;
   inout  wire         io_usb0_data1;
   inout  wire         io_usb0_data2;
   inout  wire         io_usb0_data3;
   inout  wire         io_usb0_data4;
   inout  wire         io_usb0_data5;
   inout  wire         io_usb0_data6;
   inout  wire         io_usb0_data7;
   // USB2 ULPI usb1
   input  wire         i_usb1_clk;
   input  wire         i_usb1_dir;
   input  wire         i_usb1_nxt;
   output wire         o_usb1_stp;
   inout  wire         o_usb1_ulpi_reset_n;
   inout  wire         io_usb1_data0;
   inout  wire         io_usb1_data1;
   inout  wire         io_usb1_data2;
   inout  wire         io_usb1_data3;
   inout  wire         io_usb1_data4;
   inout  wire         io_usb1_data5;
   inout  wire         io_usb1_data6;
   inout  wire         io_usb1_data7;
   // USB3.1 PHY (transceiver + HCSL refclk); USB-C sideband not connected
   input  wire         i_usb31_phy_refclk_p_clk;
   input  wire         i_usb31_phy_rx_serial_n_i_rx_serial_n;
   input  wire         i_usb31_phy_rx_serial_p_i_rx_serial_p;
   output wire         o_usb31_phy_tx_serial_n_o_tx_serial_n;
   output wire         o_usb31_phy_tx_serial_p_o_tx_serial_p;
   // misc HPS GPIO
   inout  wire         ETH2_RESETn;
   inout  wire         FAN_EN;

   // HPS internal glue
   wire [31:0]  hps_gp_out;
   wire [1:0]   usb31_usb_ctrl;

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

  mitysom_ae3v_25g_hps_8cam_qsys u0 (
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
       .mipi_subsystem_c_rzq_1_rzq  (mipi_rzq_1),

      // Code auto-generated for HPS subsystem (hps_subsys)
       .hps_emif_mem_0_mem_cs               (HPS_CS),
       .hps_emif_mem_0_mem_cke              (HPS_CKE),
       .hps_emif_mem_0_mem_ca               (HPS_CA),
       .hps_emif_mem_0_mem_dq               (HPS_DQ),
       .hps_emif_mem_0_mem_dqs_t            (HPS_DQS_T),
       .hps_emif_mem_0_mem_dqs_c            (HPS_DQS_C),
       .hps_emif_mem_0_mem_dmi              (HPS_DMI),
       .hps_emif_mem_ck_0_mem_ck_t          (HPS_CK_T),
       .hps_emif_mem_ck_0_mem_ck_c          (HPS_CK_C),
       .hps_emif_mem_reset_n_mem_reset_n    (HPS_MEM_RESET_N),
       .hps_emif_oct_0_oct_rzqin            (HPS_RZQ),
       .hps_emif_ref_clk_0_clk              (HPS_CLKIN_P),
       .hps_gp_gp_in                        (32'b0),
       .hps_gp_gp_out                       (hps_gp_out),
       .hps_io_hps_osc_clk                  (HPS_CLK_25MHz),
       .hps_io_sdmmc_cclk                   (SDMMC_CLK),
       .hps_io_sdmmc_cmd                    (SDMMC_CMD),
       .hps_io_sdmmc_data0                  (SDMMC_D[0]),
       .hps_io_sdmmc_data1                  (SDMMC_D[1]),
       .hps_io_sdmmc_data2                  (SDMMC_D[2]),
       .hps_io_sdmmc_data3                  (SDMMC_D[3]),
       .hps_io_usb0_clk                     (i_usb0_clk),
       .hps_io_usb0_dir                     (i_usb0_dir),
       .hps_io_usb0_nxt                     (i_usb0_nxt),
       .hps_io_usb0_stp                     (o_usb0_stp),
       .hps_io_usb0_data0                   (io_usb0_data0),
       .hps_io_usb0_data1                   (io_usb0_data1),
       .hps_io_usb0_data2                   (io_usb0_data2),
       .hps_io_usb0_data3                   (io_usb0_data3),
       .hps_io_usb0_data4                   (io_usb0_data4),
       .hps_io_usb0_data5                   (io_usb0_data5),
       .hps_io_usb0_data6                   (io_usb0_data6),
       .hps_io_usb0_data7                   (io_usb0_data7),
       .hps_io_usb1_clk                     (i_usb1_clk),
       .hps_io_usb1_dir                     (i_usb1_dir),
       .hps_io_usb1_nxt                     (i_usb1_nxt),
       .hps_io_usb1_stp                     (o_usb1_stp),
       .hps_io_usb1_data0                   (io_usb1_data0),
       .hps_io_usb1_data1                   (io_usb1_data1),
       .hps_io_usb1_data2                   (io_usb1_data2),
       .hps_io_usb1_data3                   (io_usb1_data3),
       .hps_io_usb1_data4                   (io_usb1_data4),
       .hps_io_usb1_data5                   (io_usb1_data5),
       .hps_io_usb1_data6                   (io_usb1_data6),
       .hps_io_usb1_data7                   (io_usb1_data7),
       .hps_io_i2c_emac0_sda                (I2C_EMAC0_SDA),
       .hps_io_i2c_emac0_scl                (I2C_EMAC0_SCL),
       .hps_io_i2c_emac1_sda                (I2C_EMAC1_SDA),
       .hps_io_i2c_emac1_scl                (I2C_EMAC1_SCL),
       .hps_io_i2c_emac2_sda                (I2C_EMAC2_SDA),
       .hps_io_i2c_emac2_scl                (I2C_EMAC2_SCL),
       .hps_io_uart1_tx                     (UART_TX),
       .hps_io_uart1_rx                     (UART_RX),
       .hps_io_i2c1_sda                     (I2C1_SDA),
       .hps_io_i2c1_scl                     (I2C1_SCL),
       .hps_io_i3c0_sda                     (I3C0_SDA),
       .hps_io_i3c0_scl                     (I3C0_SCL),
       .hps_io_gpio27                       (ETH2_RESETn),
       .hps_io_gpio28                       (SDCARD_PRSNT),
       .hps_io_gpio34                       (o_usb0_ulpi_reset_n),
       .hps_io_gpio35                       (o_usb1_ulpi_reset_n),
       .hps_io_gpio44                       (FAN_EN),
       .usb31_io_vbus_det                   (1'b0),
       .usb31_io_flt_bar                    (1'b1),
       .usb31_io_usb_ctrl                   (usb31_usb_ctrl),
       .usb31_io_usb31_id                   (1'b1),
       .usb31_phy_refclk_p_clk              (i_usb31_phy_refclk_p_clk),
       .usb31_phy_refclk_n_clk              (),
       .usb31_phy_rx_serial_n_i_rx_serial_n (i_usb31_phy_rx_serial_n_i_rx_serial_n),
       .usb31_phy_rx_serial_p_i_rx_serial_p (i_usb31_phy_rx_serial_p_i_rx_serial_p),
       .usb31_phy_tx_serial_n_o_tx_serial_n (o_usb31_phy_tx_serial_n_o_tx_serial_n),
       .usb31_phy_tx_serial_p_o_tx_serial_p (o_usb31_phy_tx_serial_p_o_tx_serial_p),
       .usbc_int_pio_in_export              (1'b1)
  );

   // MitySOM-A5E STD status LEDs (active-high):
   //   dbg_led_1 = GTS system PLL locked; dbg_led_2 = RX CDR lock (SFP cage linked)
   assign dbg_led_1 = eth_pll_lock;
   assign dbg_led_2 = rx_is_lockedtodata;

   // HSB GPIO pin 2 x camera + (IO - 1) drives camera IO1/IO2. The outputs also feed the GPIO
   // inputs: the host sets one pin by reading the input register and writing the output register.
   assign {cam5_io2, cam5_io1, cam4_io2, cam4_io1, cam3_io2, cam3_io1,
           cam2_io2, cam2_io1, cam1_io2, cam1_io1} = cam_gpio;

   // The HPS USB3.1 USB-C sideband (VBUS enable / orientation mux) is not connected;
   // usb31_io.usb_ctrl and hps_gp_out are unused.

endmodule

`default_nettype wire









