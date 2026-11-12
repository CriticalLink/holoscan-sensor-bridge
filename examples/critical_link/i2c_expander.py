# SPDX-FileCopyrightText: Copyright (c) 2023 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
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

# I2C mux driver for the MitySOM-A5E STD baseboard.
#
# On this baseboard the camera I2C does not reach the CSI connectors directly:
# the FPGA camera I2C master drives a PCA9548A 8-channel I2C switch (U43,
# address 0x70), and each downstream channel fans out to one CSI/MIPI camera
# connector. Every camera module sits at the same I2C address (0x1A), so the
# mux channel is what disambiguates them: select the channel for the target
# camera, then run the normal I2C transaction at 0x1A.
#
# The PCA9548A control byte is a one-bit-per-channel enable mask: bit N
# enables downstream channel N. Writing 0x00 disables all channels.

from enum import Enum

import hololink


class I2C_Expander_Output_EN(Enum):
    CHANNEL_0 = 0b00000001  # J16 / CSI1 / LINK0 (camera_id 0)
    CHANNEL_1 = 0b00000010  # J15 / CSI2 / LINK1 (camera_id 1)
    CHANNEL_2 = 0b00000100  # J17 / CSI3 / LINK2 (camera_id 2)
    CHANNEL_3 = 0b00001000  # J18 / CSI4 / LINK3 (camera_id 3)
    CHANNEL_4 = 0b00010000  # J20 / CSI5 / LINK4 (camera_id 4)
    CHANNEL_5 = 0b00100000  # J24 / CSI6 / LINK5 (camera_id 5), also the PCAL6408A
    CHANNEL_6 = 0b01000000  # J25 / CSI7 / LINK6 (camera_id 6)
    CHANNEL_7 = 0b10000000  # J26 / CSI8 / LINK7 (camera_id 7)
    default = 0b00000000


class PCA9548AI2CExpander:
    # PCA9548A 8-channel I2C switch, address pins A2:A0 strapped to 0 -> 0x70.
    I2C_EXPANDER_ADDRESS = 0b01110000

    def __init__(self, hololink_handle, i2c_bus):
        self._i2c = hololink_handle.get_i2c(i2c_bus)

    def configure(self, output_en=I2C_Expander_Output_EN.default.value):
        write_bytes = bytearray(100)
        serializer = hololink.Serializer(write_bytes)
        serializer.append_uint8(output_en)  # one-bit-per-channel enable mask
        read_byte_count = 0
        self._i2c.i2c_transaction(
            self.I2C_EXPANDER_ADDRESS,
            serializer.data(),
            read_byte_count,
        )


class PCAL6408AIOExpander:
    # PCAL6408A 8-bit GPIO expander (U74, address 0x21) on mux channel 5. It drives the
    # IO1/IO2 lines of the three cameras that have no FPGA pins for them:
    # P0/P1 = CAM6 (J24), P2/P3 = CAM7 (J25), P4/P5 = CAM8 (J26); P6/P7 unused.
    # Every pin powers up as an input, so these cameras stay off until the host
    # configures the expander.
    I2C_EXPANDER_ADDRESS = 0x21
    OUTPUT_PORT = 0x01
    CONFIGURATION = 0x03  # 1 = input; power-on default 0xFF
    CAMERA_IO_OUTPUTS = 0xC0  # P0-P5 outputs, P6/P7 inputs

    def __init__(self, hololink_handle, i2c_bus):
        self._i2c = hololink_handle.get_i2c(i2c_bus)

    def write_register(self, register, value):
        write_bytes = bytearray(100)
        serializer = hololink.Serializer(write_bytes)
        serializer.append_uint8(register)
        serializer.append_uint8(value)
        self._i2c.i2c_transaction(
            self.I2C_EXPANDER_ADDRESS,
            serializer.data(),
            0,
        )

    def read_register(self, register):
        write_bytes = bytearray(100)
        serializer = hololink.Serializer(write_bytes)
        serializer.append_uint8(register)
        reply = self._i2c.i2c_transaction(
            self.I2C_EXPANDER_ADDRESS,
            serializer.data(),
            1,
        )
        return hololink.Deserializer(reply).next_uint8()

    def camera_ios_off(self):
        # Drive P0-P5 low. The output register is written first so the pins never drive
        # high on the switch to output (its power-on value is 0xFF).
        self.write_register(self.OUTPUT_PORT, 0x00)
        self.write_register(self.CONFIGURATION, self.CAMERA_IO_OUTPUTS)

    def set_camera_io1(self, camera, on):
        # camera 0-2 = CAM6-CAM8; IO1 is P(2 x camera), the other cameras' pins are kept
        if self.read_register(self.CONFIGURATION) != self.CAMERA_IO_OUTPUTS:
            self.camera_ios_off()
        bit = 1 << (2 * camera)
        value = self.read_register(self.OUTPUT_PORT)
        value = value | bit if on else value & ~bit
        self.write_register(self.OUTPUT_PORT, value)
