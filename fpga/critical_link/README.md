# MitySOM-A5E Holoscan Sensor Bridge FPGA Designs

Four Quartus Prime Pro projects that stream up to eight IMX678 MIPI cameras from a
MitySOM-A5E STD baseboard (80-001828RI-7) to a Jetson AGX Thor over Ethernet. Each is
derived from Altera's Agilex 5 MIPI demo (in this repository under `fpga/altera/`),
ported to the MitySOM-A5E starting from that demo's 2.6.0-EA.2 release, and built around
the NVIDIA Holoscan Sensor Bridge IP in `fpga/nv_hsb_ip`.

| Design                      | SOM                       | FPGA            | Ethernet | Boot       |
| --------------------------- | ------------------------- | --------------- | -------- | ---------- |
| `mitysom_ae3v_25g_8cam`     | Group A, A5ED-A63-144-SRC | A5ED065AB32AE3V | 25GbE    | FPGA first |
| `mitysom_ae3v_25g_hps_8cam` | Group A, A5ED-A63-144-SRC | A5ED065AB32AE3V | 25GbE    | HPS first  |
| `mitysom_ai4s_10g_8cam`     | Group B, A5ED-B64-144-SRI | A5ED065BB32AI4S | 10GbE    | FPGA first |
| `mitysom_ai4s_10g_hps_8cam` | Group B, A5ED-B64-144-SRI | A5ED065BB32AI4S | 10GbE    | HPS first  |

- **FPGA first:** the SOM's QSPI holds the FPGA image and the HPS is unused. The
  baseboard fan is driven by an HPS GPIO, so it does not run with these designs.
- **HPS first:** the HPS boots Linux from the SD card and loads the FPGA fabric from
  `/lib/firmware/a5e.core.rbf`. The HPS runs independently of the camera pipeline; its
  device tree turns the fan on.
- The Group A part needs SmartVID: each AE3V design's
  `quartus/shell/board_subsystem.qsf` configures the core regulator over the SDM PMBus.
  A design moves between the two parts only through a copy that already targets the
  destination part, never by changing the device string alone.

## Cameras

Camera N is the HSB sensor interface N and channel N of the baseboard's PCA9548A I2C
switch (U43). All cameras answer at I2C address 0x1A.

| Camera          | 0    | 1    | 2    | 3    | 4    | 5    | 6    | 7    |
| --------------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| Connector       | J16  | J15  | J17  | J18  | J20  | J24  | J25  | J26  |
| Baseboard label | CAM1 | CAM2 | CAM3 | CAM4 | CAM5 | CAM6 | CAM7 | CAM8 |

- Cameras 0-4 take their IO1/IO2 enables from FPGA pins, cameras 5-7 from the PCAL6408A
  expander (U74) on switch channel 5, which the host software sets.
- The camera I2C reaches the switch through level shifter U73, enabled with switch S7 on
  its +1.8V side.
- Each camera link is four MIPI D-PHY lanes at 1782 Mbps into the Agilex 5 hard MIPI
  I/O, then the Altera MIPI CSI-2 IP, which hands RAW10/RAW12 lines to the HSB IP.

## Host interface

- The FPGA is at 192.168.0.2 with MAC address ca:fe:c0:ff:ee:10 and announces itself
  with a BOOTP broadcast once a second. Its Ethernet MAC does not answer ARP, so the
  host needs a static neighbour entry (see
  `examples/critical_link/thor_network_setup.sh`).
- The host receives over the Linux network stack (`LinuxReceiverOperator`). The HSB IP's
  sensor packetizers and its CoE (IEEE 1722B) packet path are left out of these builds,
  so the Jetson's hardware CoE capture (`FusaCoeCaptureOp`) is not supported.

## Build

Requirements:

- Quartus Prime Pro 26.1 with Agilex 5 device support
- The free Altera licenses for the MIPI D-PHY IP and the MIPI CSI-2 IP, installed before
  synthesis. Without them the assembler writes only a time-limited SOF and the build
  stops with an error.
- For the HPS-first designs, the HPS U-Boot SPL `u-boot-spl.ihex`, attached to each
  [GitHub release](https://github.com/criticallink/holoscan-sensor-bridge/releases). The
  same SPL serves both SOMs.

`build.tcl`, in this directory, builds any of the designs: it generates the Platform
Designer systems, compiles the design and writes its flash images into the design's
`quartus/output_files/`. `<design>` is a design name from the table above or the path of
a design directory. From the repository root:

```bash
# FPGA-first: <design>.sof and <design>.jic
quartus_sh -t fpga/critical_link/build.tcl <design>
# HPS-first: <design>.sof, <design>.hps.jic and <design>.core.rbf
quartus_sh -t fpga/critical_link/build.tcl <design> -spl u-boot-spl.ihex
```

`-images_only` writes the images from the SOF already in `quartus/output_files/` without
compiling. The script stops at the first step that fails. Each build regenerates the IP,
so the HSB IP datecode and the placement change from build to build; the script warns if
the design's timing summary shows a miss or is absent. The build has been run on Linux.

Both MIPI D-PHY IPs set `RX_CLK_SETTLE` to 16 on every link instead of the IP's
automatic value. It sets the clock-lane settle time in D-PHY core clock cycles (12.8 ns
at 78.125 MHz), and 16 is the largest value the IP's own range allows under the D-PHY
specification's 300 ns TCLK-SETTLE maximum. At the automatic value (8) a camera link can
come up dead at stream start, with the sensor streaming and nothing captured, until the
camera is restarted.

## Program the SOM

The release files for each tag are attached to the repository's
[GitHub releases](https://github.com/criticallink/holoscan-sensor-bridge/releases). The
commands below run with the Quartus programming tools and a JTAG cable connected to the
baseboard. `@2` is the Agilex 5 device's position in the JTAG chain when it is
unconfigured; check yours with `jtagconfig`.

### FPGA-first designs

Load a SOF over JTAG (lost at power off):

```bash
quartus_pgm -c 1 -m jtag -o "p;<design>.sof@2"
```

Or write the image to the SOM's QSPI flash. The release has the JIC, and `build.tcl`
writes it for your own builds; by hand, create it from the SOF with the design's FPGA as
the flash loader:

```bash
quartus_pfg -c -o device=MT25QU256 -o mode=ASX4 -o flash_loader=<fpga> <design>.sof <design>.jic
quartus_pgm -c 1 -m jtag -o "piv;<design>.jic@2"
```

then power cycle the board.

### HPS-first designs

An HPS-first design needs two images from the same build: the JIC in the SOM's QSPI (SDM
firmware, the HPS first-stage bootloader and the I/O configuration) and the core RBF on
the SD card (the FPGA fabric). Both come from one `quartus_pfg` run, which also needs
the U-Boot SPL `u-boot-spl.ihex` attached to the release. `build.tcl -spl` runs it for
your own builds; by hand:

```bash
quartus_pfg -c -o hps_path=u-boot-spl.ihex -o hps=on -o device=MT25QU256 -o mode=ASX4 \
  -o flash_loader=<fpga> <design>.sof <design>.jic
# writes <design>.hps.jic and <design>.core.rbf
```

1. Write the release's SD card image for the design, or put `<design>.core.rbf` on an
   existing card as `/lib/firmware/a5e.core.rbf`.
1. Halt Linux (`poweroff`) and program the JIC:
   `quartus_pgm -c 1 -m jtag -o "piv;<design>.hps.jic@2"`
1. Power cycle the board. U-Boot prints `FPGA reconfiguration OK!` when it loads the
   fabric.

Update the RBF before the JIC: a JIC from a newer build next to an older RBF does not
boot.
