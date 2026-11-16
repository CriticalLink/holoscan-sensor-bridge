# SPDX-FileCopyrightText: Copyright (c) 2026 Critical Link, LLC. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# IMX678 camera support for the MitySOM-A5E STD baseboard (80-001828RI-7), built on
# Altera's FramosImx678 driver.
#
# The baseboard differs from Altera's devkit in three ways:
# - All eight cameras sit at I2C address 0x1A behind a PCA9548A switch (U43), one mux
#   channel per camera, so every camera register access selects its channel first.
# - Each camera is powered by its connector's IO1 line (IO2 is not used): cameras 0-4
#   from HSB GPIO, cameras 5-7 from a PCAL6408A expander (U74) on mux channel 5. Both
#   are off until the host turns a camera on.
# - The camera modules carry a 24 MHz INCK oscillator, not the 37.125 MHz the Framos
#   register tables assume.

import dataclasses
import logging
import threading
import time

import i2c_expander
from hololink.sensors.agx5_imx678.agx5_imx678 import FramosImx678
from hololink.sensors.agx5_imx678.agx5_imx678_mode import imx678_base_settings

import hololink as hololink_module

DRIVER_NAME = "Imx678-MitySOM-A5E"

CAM_I2C_ADDRESS = 0x1A


@dataclasses.dataclass(frozen=True)
class Platform:
    name: str
    # camera index -> baseboard MIPI connector
    connectors: tuple
    # HSB GPIO pin 2 x camera + (IO - 1) drives IO1/IO2 of the cameras below this
    # index; the cameras from it up take IO1/IO2 from the PCAL6408A
    gpio_cameras: int


# HSB IP UUID of each platform's FPGA images -> platform
PLATFORMS = {
    "be9a93bf-a12b-459d-9dfa-2663c79a5dd4": Platform(
        "MitySOM-A5E STD baseboard",
        ("J16", "J15", "J17", "J18", "J20", "J24", "J25", "J26"),
        gpio_cameras=5,
    ),
}

# Settling time after a camera's IO1 rises, before the first sensor write
CAM_POWER_ON_WAIT_MS = 100

# IO1 low time for the camera supplies to fall, so the next power-on resets the sensor
CAM_POWER_OFF_WAIT_MS = 100

# INCK_SEL (0x3014) = 0x04 selects a 24 MHz INCK (IMX678 Software Reference Manual)
INCK_SEL_REGISTER = 0x3014
INCK_SEL_24MHZ = 0x04

# Camera I2C goes through the PCA9548A: a channel select, then the transaction on that
# channel. Receivers start their cameras from scheduler threads, so a select and its
# transaction must not interleave with another camera's.
cam_i2c_lock = threading.Lock()

mitysom_imx678_base_settings = [
    (register, INCK_SEL_24MHZ if register == INCK_SEL_REGISTER else value)
    for register, value in imx678_base_settings
]


def get_cam_gpio(hololink, platform):
    return hololink.get_gpio(
        hololink_module.Metadata({"gpio_pin_count": 2 * platform.gpio_cameras})
    )


# Drives IO1 and IO2 of every camera low and waits for the supplies to fall
def power_off_cameras(hololink, platform, i2c_bus=hololink_module.BL_I2C_BUS):
    gpio = get_cam_gpio(hololink, platform)
    for pin in range(2 * platform.gpio_cameras):
        gpio.set_value(pin, gpio.LOW)
    mux = i2c_expander.PCA9548AI2CExpander(hololink, i2c_bus)
    with cam_i2c_lock:
        mux.configure(i2c_expander.I2C_Expander_Output_EN.CHANNEL_5.value)
        i2c_expander.PCAL6408AIOExpander(hololink, i2c_bus).camera_ios_off()
    time.sleep(CAM_POWER_OFF_WAIT_MS / 1000)


class MitySomImx678(FramosImx678):
    def __init__(
        self,
        hololink_channel,
        platform,
        camera_id=0,
        i2c_bus=hololink_module.BL_I2C_BUS,
    ):
        # FramosImx678.__init__ only accepts the devkit's two camera addresses
        if not 0 <= camera_id < len(platform.connectors):
            raise ValueError(f"Unsupported camera_id={camera_id}")
        logging.info(f"Initializing MitySomImx678 with camera_id={camera_id}")
        self.cam_id = camera_id
        self._hololink_channel = hololink_channel
        self._hololink = hololink_channel.hololink()
        self._i2c_bus = i2c_bus
        self._i2c = self._hololink.get_i2c(i2c_bus)
        self._camera_i2c_address = CAM_I2C_ADDRESS
        self._mux = i2c_expander.PCA9548AI2CExpander(self._hololink, i2c_bus)
        self._mux_channel = 1 << camera_id
        self._first_expander_camera = platform.gpio_cameras
        self._io_expander = None
        self._gpio = None
        if camera_id >= platform.gpio_cameras:
            self._io_expander = i2c_expander.PCAL6408AIOExpander(
                self._hololink, i2c_bus
            )
        else:
            self._gpio = get_cam_gpio(self._hololink, platform)

    def get_name(self):
        return DRIVER_NAME

    # IO1 powers the sensor
    def set_power(self, on):
        if self._io_expander is not None:
            with cam_i2c_lock:
                self._mux.configure(i2c_expander.I2C_Expander_Output_EN.CHANNEL_5.value)
                self._io_expander.set_camera_io1(
                    self.cam_id - self._first_expander_camera, on
                )
        else:
            level = self._gpio.HIGH if on else self._gpio.LOW
            self._gpio.set_value(2 * self.cam_id, level)

    def configure(self, mode):
        self.set_power(True)
        time.sleep(CAM_POWER_ON_WAIT_MS / 1000)
        super().configure(mode)

    def _initialize(self, settings):
        self.write_registers(mitysom_imx678_base_settings)
        self.write_registers(settings)

    def get_register(self, register):
        with cam_i2c_lock:
            self._mux.configure(self._mux_channel)
            return super().get_register(register)

    def set_register(self, register, value, timeout=None):
        with cam_i2c_lock:
            self._mux.configure(self._mux_channel)
            super().set_register(register, value, timeout=timeout)
