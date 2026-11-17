# MitySOM-A5E Holoscan Sensor Bridge FPGA Designs

Six Quartus Prime Pro projects that stream IMX678 MIPI cameras to a Jetson AGX Thor over
Ethernet: up to eight from a MitySOM-A5E STD baseboard (80-001828RI-7), or one from a
MitySOM-A5E Mini baseboard (80-001748RI-2). Each is derived from Altera's Agilex 5 MIPI
demo (in this repository under `fpga/altera/`), ported to the MitySOM-A5E starting from
that demo's 2.6.0-EA.2 release, and built around the NVIDIA Holoscan Sensor Bridge IP in
`fpga/nv_hsb_ip`.

| Design                      | Baseboard | Ethernet | Boot       | SOMs          | Default SOM         |
| --------------------------- | --------- | -------- | ---------- | ------------- | ------------------- |
| `mitysom_25g_8cam`          | STD       | 25GbE    | FPGA first | Group A       | A5ED-A63-144-SRC    |
| `mitysom_25g_hps_8cam`      | STD       | 25GbE    | HPS first  | Group A       | A5ED-A63-144-SRC    |
| `mitysom_10g_8cam`          | STD       | 10GbE    | FPGA first | Group A and B | A5ED-B64-144-SRI    |
| `mitysom_10g_hps_8cam`      | STD       | 10GbE    | HPS first  | Group A and B | A5ED-B64-144-SRI    |
| `mitysom_mini_10g_1cam`     | Mini      | 10GbE    | FPGA first | Group A and B | A5ED-B16-1X4-MRI-CS |
| `mitysom_mini_10g_hps_1cam` | Mini      | 10GbE    | HPS first  | Group A and B | A5ED-B16-1X4-MRI-CS |

| SOM model           | SOM  | Part              | Group | HPS memory           |
| ------------------- | ---- | ----------------- | ----- | -------------------- |
| A5ED-A63-144-SRC    | STD  | A5ED065AB32AE3V   | A     | 4 GB at 1333.333 MHz |
| A5ED-B64-144-SRI    | STD  | A5ED065BB32AI4S   | B     | 4 GB at 1333.333 MHz |
| A5ED-B64-144-SRC-X  | STD  | A5ED065BB32AE4SR0 | B     | 4 GB at 1333.333 MHz |
| A5ED-B64-188-SRC-X  | STD  | A5ED065BB32AE4SR0 | B     | 8 GB at 1333.333 MHz |
| A5ED-B46-144-SRI    | STD  | A5ED043BB32AI6S   | B     | 4 GB at 1066.667 MHz |
| A5ED-A43-1X4-MRI    | Mini | A5ED043AB23AI3V   | A     | 4 GB at 1333.333 MHz |
| A5ED-B44-1X4-MRI    | Mini | A5ED043BB23AI4S   | B     | 4 GB at 1333.333 MHz |
| A5ED-B16-1X4-MRI-CS | Mini | A5ED013BB23AI6SCS | B     | 4 GB at 1066.667 MHz |
| A5ED-B06-1X2-MRI-CS | Mini | A5ED008BB23AI6SCS | B     | 2 GB at 1066.667 MHz |
| A5ED-B14-1X4-MRC-B0 | Mini | A5ED013BB23AE4SR1 | B     | 4 GB at 1333.333 MHz |
| A5ED-B14-1X8-MRC-B0 | Mini | A5ED013BB23AE4SR1 | B     | 8 GB at 1333.333 MHz |

- **FPGA first:** the SOM's QSPI holds the FPGA image and the HPS is unused. The
  baseboard fan is driven by an HPS GPIO, so it does not run with these designs.
- **HPS first:** the HPS boots Linux from the SD card and loads the FPGA fabric from
  `/lib/firmware/a5e.core.rbf`. The HPS runs independently of the camera pipeline; its
  device tree turns the fan on.
- A design builds for any SOM model in the second table whose SOM matches the design's
  baseboard and whose group the design's SOMs column lists, chosen with `build.tcl
  -model` (see Build). The model sets the part and, in the HPS-first designs, the HPS
  memory size and rate. A Group A part needs SmartVID:
  `quartus/shell/board_subsystem.qsf` configures the core regulator over the SDM PMBus
  for a Group A device and fixed voltage for Group B. 25GbE needs a Group A part.

## Cameras

All cameras answer at I2C address 0x1A. On the STD baseboard, camera N is the HSB sensor
interface N and channel N of the baseboard's PCA9548A I2C switch (U43).

| Camera          | 0    | 1    | 2    | 3    | 4    | 5    | 6    | 7    |
| --------------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
| Connector       | J16  | J15  | J17  | J18  | J20  | J24  | J25  | J26  |
| Baseboard label | CAM1 | CAM2 | CAM3 | CAM4 | CAM5 | CAM6 | CAM7 | CAM8 |

- A camera is powered by its connector's IO1 line; IO2 is not used. Cameras 0-4 take
  IO1/IO2 from HSB GPIO pin 2 x camera + (IO - 1), cameras 5-7 from the PCAL6408A
  expander (U74) on switch channel 5. The GPIO lines are low after FPGA configuration and
  after an HSB reset, and the expander pins are inputs after power-up, so the host
  software turns each camera on before configuring it. Host software that does not
  drive the GPIO leaves cameras 0-4 off.
- The camera I2C reaches the switch through level shifter U73, enabled with switch S7 on
  its +1.8V side.
- Each camera link is four MIPI D-PHY lanes at 1782 Mbps into the Agilex 5 hard MIPI
  I/O, then the Altera MIPI CSI-2 IP, which hands RAW10/RAW12 lines to the HSB IP.

On the Mini baseboard, camera 0 is on J7 and is the HSB sensor interface 0. Its I2C goes
straight to the FPGA, with no switch, and HSB GPIO pins 0 and 1 drive its IO1 and IO2.
Its link is four MIPI D-PHY lanes at 1782 Mbps, as on the STD.

## Host interface

- The FPGA is at 192.168.0.2 with MAC address ca:fe:c0:ff:ee:10 and announces itself
  with a BOOTP broadcast once a second. Its Ethernet MAC does not answer ARP, so the
  host needs a static neighbour entry (see
  `examples/critical_link/thor_network_setup.sh`).
- The host receives over the Linux network stack (`LinuxReceiverOperator`) or over the
  Jetson's hardware CoE (IEEE 1722B) capture (`FusaCoeCaptureOp`); the HSB IP's CoE
  packet path and the sensor packetizers of every camera are built in for that.
  The Thor's capture engine takes at most five CoE streams per port. Images from
  `cl-release-2.6.0-1` are built without the CoE path, so CoE needs a later image.

## Build

Requirements:

- Quartus Prime Pro 26.1 with Agilex 5 device support
- The free Altera licenses for the MIPI D-PHY IP and the MIPI CSI-2 IP, from Altera's
  Self-Service Licensing Center, installed before synthesis. Without them the assembler
  writes only a time-limited SOF and the build stops with an error.
- For the HPS-first designs, the SOM's HPS U-Boot SPL, attached to each
  [GitHub release](https://github.com/criticallink/holoscan-sensor-bridge/releases):
  `mitysom_u-boot-spl.ihex` for the STD SOMs, `mitysom_mini_u-boot-spl.ihex` for the
  Mini SOMs.

`build.tcl`, in this directory, builds any of the designs: it generates the Platform
Designer systems, compiles the design and writes its flash images, named with the SOM
model. `<design>` is a design name from the table above or the path of a design
directory. From the repository root:

```bash
# FPGA-first: <design>_<model>.sof and <design>_<model>.jic
quartus_sh -t fpga/critical_link/build.tcl <design>
# HPS-first, with the SOM's SPL: <design>_<model>.sof, .hps.jic and .core.rbf
quartus_sh -t fpga/critical_link/build.tcl <design> -spl mitysom_u-boot-spl.ihex
# For another SOM model than the default: add -model <model>
quartus_sh -t fpga/critical_link/build.tcl mitysom_10g_8cam -model A5ED-A63-144-SRC
```

A model with the design's part, and in an HPS-first design the HPS memory the design
carries, builds in the design directory, with the images in its `quartus/output_files/`.
Another model builds in a copy of the design's sources at `fpga/build/<design>_<model>/`,
with the images in that copy's `quartus/output_files/`; the design directory is not
changed. `-images_only` writes the images from the SOF already there without compiling.
The script stops at the first step that fails. Each build regenerates the IP, so the HSB
IP datecode and the placement change from build to build; the script warns if the
design's timing summary shows a miss or is absent. The build has been run on Linux.

The MIPI D-PHY IPs enable initial skew calibration on every link, which the IP
recommends above 1500 Mbps; the IMX678 sends the calibration sequence at stream start.
With skew calibration the receive rate is twice the PLL VCO. From the STD baseboard's
125 MHz reference the VCO is 890.625 MHz (1781.25 Mbps, the nearest to the sensor's 1782)
and the D-PHY core clock, VCO/8, is 111.33 MHz; from the Mini baseboard's 20 MHz
reference the VCO is 900 MHz (1800 Mbps) and the core clock 112.5 MHz.
`RX_CLK_SETTLE` is set to 20 on every link instead of the IP's automatic value. It sets
the clock-lane settle time: 20 gives about 250 ns, inside the D-PHY specification's 95 to
300 ns TCLK-SETTLE window with margin from both ends (the IP's maximum, 25, gives about
295 ns).

### Working on the designs with QuartusIQ

The designs are standard Quartus Prime Pro projects: Platform Designer systems, `.qsf`
assignments and Verilog top levels, built by `build.tcl`. QuartusIQ, Altera's AI assistant
in Quartus Prime Pro 26.3 and later, works with projects like these: inside Quartus Prime
Pro, or from AI coding tools such as Claude Code or Cursor through Altera's Quartus MCP
servers. It can explain how a design is put together, look up IP and device documentation,
and help you change a design, for example to retarget pins, reconfigure an IP or add Signal
Tap, then compile it and check timing. See Altera's QuartusIQ documentation for setup.
These designs are built and tested with Quartus Prime Pro 26.1; opening them in a newer
Quartus Prime Pro upgrades their IP.

## Program the SOM

The release files for each tag are attached to the repository's
[GitHub releases](https://github.com/criticallink/holoscan-sensor-bridge/releases). The
commands below run with the Quartus Prime Pro Programmer (in Quartus Prime Pro, or
Altera's free standalone Programmer) on an x86-64 Linux or Windows PC, with a JTAG cable
on the baseboard's JTAG header J3. `-c 1` is the first cable `jtagconfig` lists. The
number after `@` is the Agilex 5 device's position in the JTAG chain: `jtagconfig` lists
the chain's devices in order, so count to the `A5E...` line. It is usually `@2` when the
FPGA is unconfigured and `@1` once it is configured.

### FPGA-first designs

Load a SOF over JTAG (lost at power off):

```bash
quartus_pgm -c 1 -m jtag -o "p;<design>_<model>.sof@2"
```

Or write the release's JIC to the SOM's QSPI flash, then power cycle the board:

```bash
quartus_pgm -c 1 -m jtag -o "piv;<design>_<model>.jic@2"
```

The design is running when `thor_network_setup.sh` on the Thor finishes without
`no link on mgbe0_0`. `build.tcl` writes the JIC for your own builds. To make one from a
SOF by hand, with the SOM model's part as the flash loader:

```bash
quartus_pfg -c -o device=MT25QU256 -o mode=ASX4 -o flash_loader=<part> <design>_<model>.sof <design>_<model>.jic
```

### HPS-first designs

An HPS-first design needs two images from the same build: the JIC in the SOM's QSPI (SDM
firmware, the HPS first-stage bootloader and the I/O configuration) and the core RBF on
the SD card (the FPGA fabric). Both come from one `quartus_pfg` run, which also needs
the SOM's U-Boot SPL attached to the release. `build.tcl -spl` runs it for your own
builds; by hand:

```bash
quartus_pfg -c -o hps_path=<SOM's SPL .ihex> -o hps=on -o device=MT25QU256 -o mode=ASX4 \
  -o flash_loader=<part> <design>_<model>.sof <design>_<model>.jic
# writes <design>_<model>.hps.jic and <design>_<model>.core.rbf
```

1. Write the release's SD card image for the design and SOM model to a microSD card, or
   put `<design>_<model>.core.rbf` on an existing card for the SOM as
   `/lib/firmware/a5e.core.rbf`. On Linux, with the card at `/dev/sdX`:
   `unzip -p <design>_<model>_sd.img.zip | sudo dd of=/dev/sdX bs=4M conv=fsync`; on
   Windows, unzip it and write it with an image writer such as balenaEtcher. With the
   board off, insert the card in the baseboard's microSD slot.
1. If Linux is running, log in on the baseboard's console port (115200 baud) as `root`,
   with no password, and run `poweroff`. Then program the JIC:
   `quartus_pgm -c 1 -m jtag -o "piv;<design>_<model>.hps.jic@2"`
1. Power cycle the board. U-Boot prints `FPGA reconfiguration OK!` on the console port
   when it loads the fabric. Linux then turns the fan on, and `thor_network_setup.sh` on
   the Thor finishes without `no link on mgbe0_0`.

Update the RBF before the JIC: a JIC from a newer build next to an older RBF does not
boot.
