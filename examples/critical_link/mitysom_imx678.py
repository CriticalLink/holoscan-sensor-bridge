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
# - Cameras 5-7 take their IO1/IO2 enables from a PCAL6408A expander (U74) on mux
#   channel 5 instead of FPGA pins.
# - The camera modules carry a 24 MHz INCK oscillator, not the 37.125 MHz the Framos
#   register tables assume.

import logging
import threading
import time

import i2c_expander
from hololink.sensors.agx5_imx678.agx5_imx678 import FramosImx678
from hololink.sensors.agx5_imx678.agx5_imx678_mode import imx678_base_settings

import hololink as hololink_module

DRIVER_NAME = "Imx678-MitySOM-A5E"

CAM_I2C_ADDRESS = 0x1A

# camera index -> baseboard MIPI connector
CAMERA_CONNECTORS = ("J16", "J15", "J17", "J18", "J20", "J24", "J25", "J26")

# Cameras at or above this index get IO1/IO2 from the PCAL6408A
FIRST_EXPANDER_CAMERA = 5

# Settling time after the PCAL6408A raises IO1/IO2, before the first sensor write
CAM_IO_ENABLE_WAIT_MS = 100

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


class MitySomImx678(FramosImx678):
    def __init__(
        self, hololink_channel, camera_id=0, i2c_bus=hololink_module.BL_I2C_BUS
    ):
        # FramosImx678.__init__ only accepts the devkit's two camera addresses
        if not 0 <= camera_id < len(CAMERA_CONNECTORS):
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
        self._io_expander = None
        if camera_id >= FIRST_EXPANDER_CAMERA:
            self._io_expander = i2c_expander.PCAL6408AIOExpander(
                self._hololink, i2c_bus
            )

    def get_name(self):
        return DRIVER_NAME

    def configure(self, mode):
        if self._io_expander is not None:
            with cam_i2c_lock:
                self._mux.configure(i2c_expander.I2C_Expander_Output_EN.CHANNEL_5.value)
                self._io_expander.enable_camera_ios()
            time.sleep(CAM_IO_ENABLE_WAIT_MS / 1000)
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
