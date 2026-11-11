# Holoscan Sensor Bridge for the Critical Link MitySOM-A5E

This repository is Critical Link's fork of
[Altera's Holoscan Sensor Bridge repository](https://github.com/altera-fpga/holoscan-sensor-bridge),
itself a fork of [NVIDIA's](https://github.com/nvidia-holoscan/holoscan-sensor-bridge).
It adds a demo that streams up to eight IMX678 cameras from a MitySOM-A5E system on
module to an NVIDIA Jetson AGX Thor over Ethernet, with optional YOLO11 body pose on
every camera. This README replaces Altera's; everything else from Altera's release
(2.6.0, built on NVIDIA Holoscan Sensor Bridge 2.6.0) is unchanged.

Critical Link's additions:

- [`fpga/critical_link`](fpga/critical_link/README.md): four FPGA designs, for the Group
  A and Group B MitySOM-A5E, each with and without the HPS
- [`examples/critical_link`](examples/critical_link): the camera support, the
  `mitysom_player.py` demo and a Jetson network setup script

## Get the repository

The images in this repository, including the demo's logo, are stored with Git LFS.
Install it before cloning:

```bash
git lfs install
git clone https://github.com/criticallink/holoscan-sensor-bridge
cd holoscan-sensor-bridge
```

## Hardware

The
[Holoscan Sensor Bridge](https://support.criticallink.com/redmine/projects/mitysom_a5/wiki/Holoscan_Sensor_Bridge)
page of the
[MitySOM-A5E wiki](https://support.criticallink.com/redmine/projects/mitysom_a5/wiki)
shows the board and camera connections with photos.

- A MitySOM-A5E on the MitySOM-A5E STD baseboard (80-001828RI-7), switch S7 on its +1.8V
  side:

  | SOM                       | FPGA            | Designs                                                      |
  | ------------------------- | --------------- | ------------------------------------------------------------ |
  | Group A, A5ED-A63-144-SRC | A5ED065AB32AE3V | `mitysom_ae3v_25g_8cam`, `mitysom_ae3v_25g_hps_8cam` (25GbE) |
  | Group B, A5ED-B64-144-SRI | A5ED065BB32AI4S | `mitysom_ai4s_10g_8cam`, `mitysom_ai4s_10g_hps_8cam` (10GbE) |

- Up to eight IMX678 camera modules with 24 MHz INCK on the baseboard's MIPI connectors:
  camera 0-7 on J16, J15, J17, J18, J20, J24, J25 and J26 (CAM1-CAM8).

- An NVIDIA Jetson AGX Thor developer kit with JetPack 7.2, its QSFP port cabled to the
  baseboard's SFP port through a passive breakout cable: QSFP28 (100G) to 4x SFP28 for
  Group A at 25G, or QSFP+ to 4x SFP+ for Group B at 10G.

- A JTAG cable for the SOM and the Quartus Prime Pro 26.1 programmer.

## Program the MitySOM-A5E

Prebuilt images for each design are attached to this repository's
[GitHub releases](https://github.com/criticallink/holoscan-sensor-bridge/releases):

- FPGA-first designs: `<design>.sof` (load over JTAG) and `<design>.jic.zip` (QSPI
  flash, unzip first)
- HPS-first designs: `<design>.hps.jic.zip` (QSPI flash, unzip first),
  `<design>.core.rbf` (the fabric, loaded from the SD card) and the matching SD card
  image, plus `<design>.sof` for loading the fabric over JTAG

[`fpga/critical_link/README.md`](fpga/critical_link/README.md) has the programming
steps and the details of each design.

To build a design yourself, with Quartus Prime Pro 26.1 and the free MIPI IP licenses,
run `fpga/critical_link/build.tcl`, which writes the SOF and the flash images; see the
[Build](fpga/critical_link/README.md#build) section.

## Set up the Jetson AGX Thor

1. Install JetPack 7.2 and the Holoscan Sensor Bridge host prerequisites by following
   NVIDIA's
   [Holoscan Sensor Bridge user guide](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/).

1. Match the Thor's QSFP port to the design. Its rate is set when JetPack is flashed:
   10G is the developer kit's default, and 25G needs
   `ODMDATA="uphy1-config-8,mgbe0-speed-3,mgbe1-speed-3,mgbe2-speed-3,mgbe3-speed-3";`
   in `Linux_for_Tegra/jetson-agx-thor-devkit.conf` before flashing.
   `cat /sys/class/net/mgbe0_0/speed` shows the result.

1. Build the demo container from the repository root:

   ```bash
   sh docker/build.sh --igpu
   ```

1. Prepare the network port. Run this after every boot of the Thor and after every power
   cycle of the baseboard:

   ```bash
   sudo examples/critical_link/thor_network_setup.sh
   ```

   It gives `mgbe0_0` the address 192.168.0.101/24, tunes the receive path for eight
   camera streams and adds the FPGA's static neighbour entry (the FPGA does not answer
   ARP). Only one interface on the Thor may hold a route to 192.168.0.0/24.

## Run the demo

From the repository root, allow the container to use the display, then start the player:

```bash
xhost +local:docker
sh docker/demo.sh python3 examples/critical_link/mitysom_player.py
```

By default all eight cameras stream at 1080p30 into one window, with the Critical Link
logo in the centre of the 3x3 grid. Useful options:

| Option                         | Effect                                                                      |
| ------------------------------ | --------------------------------------------------------------------------- |
| `--cams 0,1,2`                 | stream a subset of the cameras                                              |
| `--resolution 720p\|1080p\|4k` | camera resolution                                                           |
| `--frame-rate 30\|60`          | camera frame rate                                                           |
| `--bit-depth 10\|12`           | camera bit depth                                                            |
| `--fullscreen`                 | fill the monitor; pass `--window-width`/`--window-height` as its resolution |
| `--gain N`                     | analog gain, 0-240 (default 0)                                              |
| `--grid-columns N`             | tiles per row (default near-square: 3 for 7-9 tiles)                        |
| `--tiles 0,-,1,-,logo,-,2,-,3` | cells in reading order: a camera, `logo` or `-` (blank)                     |
| `--model pose --engine <file>` | YOLO11 body pose on every camera                                            |

A camera that does not answer at start-up (a loose ribbon, no power) is left out and its
tile shows NO CAMERA; a camera that stops sending frames shows NO SIGNAL. The player
exits if no camera answers. A `--tiles` list must fill whole rows of `--grid-columns`
cells (pad with `-`); write a list that starts with `-` as `--tiles=-,0,...`.

### Body pose

The pose model runs as a batched TensorRT engine, built once on the Thor. Export the
ONNX model with Ultralytics (`pip install ultralytics`, on any machine):

```bash
yolo export model=yolo11n-pose.pt format=onnx imgsz=384,640 batch=8
```

then copy `yolo11n-pose.onnx` into the repository root on the Thor and build the engine
there, inside the demo container:

```bash
sh docker/demo.sh /usr/src/tensorrt/bin/trtexec --onnx=yolo11n-pose.onnx \
  --saveEngine=yolo11n-pose_b8_384x640.fp16.engine --fp16
```

and run:

```bash
sh docker/demo.sh python3 examples/critical_link/mitysom_player.py \
  --model pose --engine yolo11n-pose_b8_384x640.fp16.engine
```

The YOLO11 models are distributed by Ultralytics under the AGPL-3.0 license and are not
part of this repository.

## Upstream documentation

- [NVIDIA Holoscan Sensor Bridge user guide](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/)
  and
  [release notes](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/release_notes.html)
- [Altera's Agilex FPGA designs](fpga/altera/README.md)
- [FPGA IP source](https://edge.urm.nvidia.com/artifactory/sw-holoscan-thirdparty-generic-local/hsb/fpga_ip/)

## License

This software is published under the Apache 2.0 license (see [LICENSE](LICENSE)). The
FPGA designs include IP generated by Altera's Quartus Prime software, which is subject
to Altera's license terms.
