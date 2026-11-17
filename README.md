# Holoscan Sensor Bridge for the Critical Link MitySOM-A5E

This repository is Critical Link's fork of
[Altera's Holoscan Sensor Bridge repository](https://github.com/altera-fpga/holoscan-sensor-bridge),
itself a fork of [NVIDIA's](https://github.com/nvidia-holoscan/holoscan-sensor-bridge).
It adds a demo that streams IMX678 cameras from a MitySOM-A5E system on module to an
NVIDIA Jetson AGX Thor over Ethernet, with optional YOLO11 body pose on every camera: up
to eight cameras on the MitySOM-A5E STD baseboard, one on the Mini baseboard. This README
replaces Altera's; the rest of Altera's release (2.6.0, built on NVIDIA Holoscan Sensor
Bridge 2.6.0) is unchanged apart from two fixes: `FusaCoeCaptureOp` starts its channels
one at a time and reports capture errors, and the lazy imports in `hololink.operators`,
`hololink.sensors` and `tools` are thread safe.

Critical Link's additions:

- [`fpga/critical_link`](fpga/critical_link/README.md): six FPGA designs, 25GbE and
  10GbE for the STD baseboard and 10GbE for the Mini baseboard, each with and without
  the HPS, built for the Group A or Group B MitySOM-A5E
- [`examples/critical_link`](examples/critical_link): the camera support, the
  `mitysom_player.py` demo and a Jetson network setup script

Terms used below: HSB is NVIDIA's Holoscan Sensor Bridge, the FPGA IP and host software
that carry the camera data over Ethernet. The HPS is the Arm processor system inside the
SOM's Agilex 5 FPGA. Group A SOMs carry the faster FPGA, which the 25GbE designs need and
which uses SmartVID voltage control; Group B SOMs run at a fixed voltage. The SOM model,
for example A5ED-B64-144-SRI, is printed on the SOM's label.

## Get the repository

Clone the release whose FPGA images you use on the Thor, at step 2 of
[Set up the Jetson AGX Thor](#set-up-the-jetson-agx-thor). The images in this repository,
including the demo's logo, are stored with Git LFS, so install it first:

```bash
sudo apt-get install -y git-lfs
git lfs install
git clone --branch cl-release-2.6.0-2 https://github.com/criticallink/holoscan-sensor-bridge
cd holoscan-sensor-bridge
```

## Hardware

The
[Holoscan Sensor Bridge](https://support.criticallink.com/redmine/projects/mitysom_a5/wiki/Holoscan_Sensor_Bridge)
page of the
[MitySOM-A5E wiki](https://support.criticallink.com/redmine/projects/mitysom_a5/wiki)
shows the board and camera connections with photos.

- A MitySOM-A5E on the MitySOM-A5E STD baseboard (80-001828RI-7), with switch S7 on its
  +1.8V side for the camera I2C, or a MitySOM-A5E Mini on the Mini baseboard
  (80-001748RI-2):

  | SOM                               | FPGA              | Designs                                                      |
  | --------------------------------- | ----------------- | ------------------------------------------------------------ |
  | STD Group A, A5ED-A63-144-SRC     | A5ED065AB32AE3V   | `mitysom_25g_8cam`, `mitysom_25g_hps_8cam` (25GbE)           |
  | STD Group B, A5ED-B64-144-SRI     | A5ED065BB32AI4S   | `mitysom_10g_8cam`, `mitysom_10g_hps_8cam` (10GbE)           |
  | Mini Group B, A5ED-B16-1X4-MRI-CS | A5ED013BB23AI6SCS | `mitysom_mini_10g_1cam`, `mitysom_mini_10g_hps_1cam` (10GbE) |

  These are the SOMs the release images are built for; other SOM models need a build of
  their own (see below).

- IMX678 camera modules with 24 MHz INCK on the baseboard's MIPI connectors: on the STD,
  up to eight, camera 0-7 on J16, J15, J17, J18, J20, J24, J25 and J26 (CAM1-CAM8); on
  the Mini, one, on J7. Latch each ribbon at both ends: with the board off, open the
  connector's clamp, push the ribbon fully in with its exposed contacts facing the
  connector's contacts, and press the clamp down flat (photos on the wiki page). A ribbon
  that is not latched, or is the wrong way round, does no harm but makes no contact, and
  that camera shows NO CAMERA; if no camera answers, the player stops with an I2C error.

- An NVIDIA Jetson AGX Thor developer kit with JetPack 7.2.1, its QSFP port cabled to the
  baseboard's SFP+ socket (J5 on the STD, J6 on the Mini) through a passive breakout
  cable: QSFP28 (100G) to 4x SFP28 for the 25G designs, or QSFP+ to 4x SFP+ for the 10G
  designs. Use the breakout's leg 1, which is the Thor's `mgbe0_0`.

- A JTAG cable (USB-Blaster II or compatible) for the baseboard's JTAG header J3, and the
  Quartus Prime Pro 26.1 Programmer on an x86-64 Linux or Windows PC. Altera also offers
  the Programmer as a free standalone download.

- For the HPS-first designs, a microSD card of 1 GB or more, and a USB cable for the
  baseboard's console port (USB-C on the STD, micro-USB on the Mini) with a serial
  terminal at 115200 baud, such as `picocom -b 115200 /dev/ttyUSB0` on Linux or PuTTY on
  Windows.

## Program the MitySOM-A5E

Prebuilt images for each design are attached to this repository's
[GitHub releases](https://github.com/criticallink/holoscan-sensor-bridge/releases):

- FPGA-first designs: `<design>_<model>.sof` (an FPGA image loaded over JTAG, lost at
  power off) and `<design>_<model>.jic.zip` (unzip first; the image for the SOM's QSPI
  flash, which configures the FPGA at every power on)
- HPS-first designs: `<design>_<model>.hps.jic.zip` (QSPI flash, unzip first),
  `<design>_<model>.core.rbf` (the fabric, loaded from the SD card) and the matching SD
  card image `<design>_<model>_sd.img.zip` (unzip, then write it to a microSD card), plus
  `<design>_<model>.sof` for loading the fabric over JTAG

`<model>` is the SOM model from the table above. Start with the HPS-first design: it
boots Linux on the SOM's HPS from the SD card, and Linux turns the baseboard fan on. The
FPGA-first designs need no SD card, but the fan stays off.

[`fpga/critical_link/README.md`](fpga/critical_link/README.md) has the programming
steps and the details of each design. Use the FPGA image and the `examples/` host
software from the same release: the host software turns the cameras on.

To build a design yourself, with Quartus Prime Pro 26.1 and the free MIPI IP licenses,
run `fpga/critical_link/build.tcl`, which writes the SOF and the flash images for the
SOM model you choose with `-model`; see the [Build](fpga/critical_link/README.md#build)
section, which also covers working on the designs with Altera's QuartusIQ AI assistant.

## Set up the Jetson AGX Thor

1. Install JetPack 7.2.1 with the Thor's QSFP port at the design's rate. The rate is set
   when JetPack is flashed: 10G is the developer kit's default, and 25G needs
   `ODMDATA="uphy1-config-8,mgbe0-speed-3,mgbe1-speed-3,mgbe2-speed-3,mgbe3-speed-3";`
   in `Linux_for_Tegra/jetson-agx-thor-devkit.conf`, set after `apply_binaries.sh` and
   before flashing; see NVIDIA's
   [Enable 25 Gigabit Ethernet on QSFP Port](https://docs.nvidia.com/jetson/archives/r39.2/DeveloperGuide/SD/Kernel/Enable25GbEthernetOnQSFP.html)
   and, for the flashing steps (Force Recovery Mode, `l4t_initrd_flash.sh`), the Jetson
   Linux [Quick Start](https://docs.nvidia.com/jetson/archives/r39.2/DeveloperGuide/IN/QuickStart.html).
   Flashing this way needs an x86-64 Ubuntu PC connected to the Thor's USB-C port.
   `cat /sys/class/net/mgbe0_0/speed` shows the result. If Docker or the NVIDIA container
   runtime is missing afterwards (`docker info` fails or lists no `nvidia` runtime),
   install JetPack's components with `sudo apt update && sudo apt install nvidia-jetpack`.

1. From NVIDIA's
   [Host Setup](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/setup.html),
   give your user access to Docker, then reboot, and do its `nmcli`
   step, which gives `mgbe0_0` a static address that NetworkManager keeps: without it,
   NetworkManager's DHCP attempt on the port removes the address. Skip that step's
   `ping`, as the FPGA does not answer ping, and expect `nmcli connection up` to fail
   until the baseboard is connected and powered. The demo runs in a container, so that
   page's `isolcpus`, Holoscan SDK install, cmake dependencies and native build steps are
   not needed. If JetPack came from the ISO image or the flash in step 1 rather than SDK
   Manager, also follow its AGX Thor steps for CUDA, SIPL and the Multimedia API. Then
   clone this repository on the Thor (see [Get the repository](#get-the-repository)).

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
   ARP). It reports `no link on mgbe0_0` if the baseboard is not connected and running.
   The FPGA's address, 192.168.0.2, is fixed, so only `mgbe0_0` on the Thor may use
   192.168.0.0/24: if another network on the Thor uses that subnet, move it to a different
   one.

## Run the demo

From a terminal on the Thor's desktop, in the repository root, allow the container to use
the display, then start the player:

```bash
xhost +local:docker
sh docker/demo.sh python3 examples/critical_link/mitysom_player.py
```

The player reads the FPGA image's HSB board UUID to tell the STD baseboard from the
Mini, and stops if the image is not one of these designs. By default every camera of the
board streams at 1080p30 into one window; on the STD, all eight with the Critical Link
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
| `--coe`                        | the first 3 cameras that answer on the hardware CoE capture (see below)     |
| `--coe 0,1,2`                  | the listed cameras (at most 3) on the hardware CoE capture                  |
| `--force-coe`                  | allow `--coe` up to 5 cameras (see below)                                   |

`--help` lists every option, including `--headless` (no window) and `--no-logo`. Each
camera takes about 0.7 Gb/s of the link at 1080p30, 1.4 Gb/s at 1080p60, 2.6 Gb/s at 4K30
and 5.3 Gb/s at 4K60 (10-bit). Keep the total well under the design's 10 or 25 Gb/s: the
default, every camera at 1080p30, fits both.

A camera that does not answer at start-up (a loose ribbon, no power) is left out and its
tile shows NO CAMERA; a camera that stops sending frames shows NO SIGNAL. The player
exits if no camera answers. A `--tiles` list must fill whole rows of `--grid-columns`
cells (pad with `-`); write a list that starts with `-` as `--tiles=-,0,...`.

### Hardware CoE capture

Hardware CoE capture is experimental; the Linux receiver is the supported path. By
default the Thor receives the camera streams over the Linux network stack. With `--coe`
it receives up to three of them with its hardware Camera over Ethernet (CoE, IEEE 1722B)
capture instead, which takes the packets off the CPU, and the rest over the Linux
network stack, in the same window. `--coe` alone puts the first three cameras that
answer at start-up on CoE; `--coe 1,3,5` names them. The `docker/build.sh --igpu`
container on an AGX Thor includes the CoE capture operator.

```bash
sh docker/demo.sh python3 examples/critical_link/mitysom_player.py --coe
```

Unlike the Linux receiver, the CoE capture stops the player when one of its cameras
delivers no frame for 1.5 s, instead of showing NO SIGNAL; start the player again. After
a `--coe` run, run `sudo examples/critical_link/thor_network_setup.sh` again before the
next start: the port's normal receive path can respond slowly after the CoE streams
close, until the interface is reset, and the script also moves an interrupt that the CoE
capture leaves running off CPU0.

With the Thor's CoE capture on JetPack 7.2.1, a `--coe` run can fail to start, or stop
while streaming: the Thor's port stops receiving, every camera stops, those on
the Linux receiver included, and the player stops on a CoE capture timeout. The port
starts receiving again when the player exits; run the network setup script as after any
`--coe` run and start the player again. This happens more often with more cameras on CoE
and with `--model pose`. The capture engine takes up to five CoE streams per port, and
`--force-coe` lets `--coe` use four or five cameras.

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

## Troubleshooting

- The player stops with `Device with 192.168.0.2 not found`: check that
  `cat /sys/class/net/mgbe0_0/speed` shows the design's rate (10000 or 25000; 10000 with a
  25G design means the Thor needs the 25G flash) and that the cable is a passive breakout
  on leg 1, then run `sudo examples/critical_link/thor_network_setup.sh` again. The FPGA
  does not answer ping.
- A tile shows NO CAMERA, and the log says `camera N (Jxx) did not answer at start-up`:
  that camera's ribbon is not making contact or the camera has no power. Switch the
  baseboard off and latch the ribbon at both ends (see [Hardware](#hardware)).
- The player stops with an I2C error (`I2C_I2C_NAK`): no camera answered. On the STD,
  check that S7 is on its +1.8V side, then the ribbons as above; power cycle the
  baseboard and run the network setup script again.
- A camera shows NO SIGNAL from the start, or the tiles show thin coloured lines: start
  the player again. If the same camera keeps failing, reseat its ribbon.
- `permission denied` on the Docker socket: add your user to the `docker` group (NVIDIA's
  Host Setup) and reboot.
- No window opens, or `cannot open display`: run the player from a terminal on the Thor's
  desktop, after `xhost +local:docker`.
- The fan does not turn: expected with an FPGA-first design. With an HPS-first design,
  Linux did not boot: if the console port does not show `FPGA reconfiguration OK!`, write
  the SD card image again.

## Upstream documentation

- [NVIDIA Holoscan Sensor Bridge user guide](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/)
  and
  [release notes](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/RELEASE_NOTES.html)
- [Altera's Agilex FPGA designs](fpga/altera/README.md)
- [FPGA IP source](https://edge.urm.nvidia.com/artifactory/sw-holoscan-thirdparty-generic-local/hsb/fpga_ip/)

## License

This software is published under the Apache 2.0 license (see [LICENSE](LICENSE)). The
FPGA designs include IP generated by Altera's Quartus Prime software, which is subject
to Altera's license terms.
