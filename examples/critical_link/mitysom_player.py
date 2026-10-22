# SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-FileCopyrightText: Copyright (c) Altera. All rights reserved.
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

# Streams up to eight IMX678 cameras from a MitySOM-A5E STD baseboard into one tiled
# Holoviz window. With 8 cameras the grid is 3x3 and the centre cell shows the
# Critical Link logo card.
#
# A batching operator takes the latest frame from each camera, so a camera whose link
# goes dead shows a "NO SIGNAL" tile instead of stalling the window. --model pose runs
# YOLO11 body pose on every camera through one batched TensorRT engine.
# The engine is built on the Jetson from the Ultralytics ONNX export at a 384x640
# input, with a batch size of at least the number of cameras:
#   yolo export model=yolo11n-pose.pt format=onnx imgsz=384,640 batch=8
#   trtexec --onnx=yolo11n-pose.onnx --saveEngine=yolo11n-pose_b8_384x640.fp16.engine --fp16

import argparse
import ctypes
import logging
import math
import os
import threading
import time

import cuda.bindings.driver as cuda
import cupy as cp
import holoscan
import numpy as np
import PIL.Image
from holoscan.core import ConditionType, IOSpec
from mitysom_imx678 import CAMERA_CONNECTORS, MitySomImx678

import hololink as hololink_module

DEFAULT_LOGO = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "critical_link_logo_card.png"
)

WINDOW_TITLE = "MitySOM-A5E Holoscan Sensor Bridge"

FPGA_IP = "192.168.0.2"

# HSB IP board UUIDs of the Altera Agilex 5 designs, which these designs keep
UUIDS = ("b26763ac-af25-44f6-850e-dce30f33f4e3", "7b1fa8c7-31aa-44b6-abcc-eac134461fdc")

RESOLUTIONS = {"720p": 720, "1080p": 1080, "4k": 2160}

# Model input: every 16:9 mode scales to 640x360 by an integer factor, padded
# top and bottom to 384 (a multiple of the model's 32-pixel stride).
MODEL_WIDTH = 640
MODEL_HEIGHT = 384
SCALED_HEIGHT = 360
PAD_TOP = (MODEL_HEIGHT - SCALED_HEIGHT) // 2
# Ultralytics letterbox fill, 114/255
PAD_VALUE = 114.0 / 255.0

# COCO keypoint skeleton (0-based keypoint indices), as drawn by Ultralytics
SKELETON = np.array(
    [
        [15, 13], [13, 11], [16, 14], [14, 12], [11, 12], [5, 11], [6, 12],
        [5, 6], [5, 7], [6, 8], [7, 9], [8, 10], [1, 2], [0, 1], [0, 2],
        [1, 3], [2, 4], [3, 5], [4, 6],
    ]
)  # fmt: skip
KEYPOINTS = 17

# A camera with no new frame for this long is drawn as "no signal"
NO_SIGNAL_S = 1.0
# Seconds between performance log lines
STATS_PERIOD_S = 5.0

# Top 8 bits of the 16-bit demosaic output, written into the display buffer
shift_to_uint8 = cp.ElementwiseKernel(
    "uint16 x", "uint8 y", "y = x >> 8", "shift_to_uint8"
)


class CameraStream:
    def __init__(self, cam_idx, hololink_channel, camera):
        self.cam_idx = cam_idx
        self.name = f"cam{cam_idx}-{CAMERA_CONNECTORS[cam_idx]}"
        self.hololink_channel = hololink_channel
        self.camera = camera


def grid_shape(tile_count, columns=None):
    """Return (columns, rows) for the tile grid: near-square by default (5 cameras 3x2,
    8 cameras 3x3), which gives the largest 16:9 tiles on a 16:9 display."""
    if columns is None:
        columns = math.ceil(math.sqrt(tile_count))
    return columns, math.ceil(tile_count / columns)


def parse_camera_list(text):
    try:
        cameras = [int(item) for item in text.split(",")]
    except ValueError:
        raise argparse.ArgumentTypeError(f"invalid camera list: {text!r}")
    if not cameras:
        raise argparse.ArgumentTypeError("camera list is empty")
    if len(cameras) != len(set(cameras)):
        raise argparse.ArgumentTypeError(f"duplicate camera in list: {text!r}")
    for camera in cameras:
        if not 0 <= camera < len(CAMERA_CONNECTORS):
            raise argparse.ArgumentTypeError(f"unknown camera index: {camera}")
    return cameras


def as_dict(message, names):
    """Tensors of a received message by name, whether it arrived as a dict or an entity."""
    if isinstance(message, dict):
        return message
    tensors = {}
    for name in names:
        tensor = message.get(name)
        if tensor is not None:
            tensors[name] = tensor
    return tensors


def load_logo(logo_path):
    rgba = np.asarray(PIL.Image.open(logo_path).convert("RGBA"))
    return cp.ascontiguousarray(cp.asarray(rgba))


class BatchOp(holoscan.core.Operator):
    """Collects the latest RGB frame from each camera and emits them as 8-bit display
    frames (output "frames") and, with a `batch_size`, as one normalized NCHW batch
    for the model (output "batch"). It runs once a frame has arrived from every
    camera, or after `timeout` without that, so a dead camera never stalls the
    others."""

    def __init__(self, fragment, *args, cam_names, width, height, batch_size, timeout,
                 logo_path, frame_limit, **kwargs):  # fmt: skip
        self._cam_names = cam_names
        self._ports = [f"in{i}" for i in range(len(cam_names))]
        self._timeout = timeout
        # Rings of display frames and model batches: a slot stays valid while the
        # downstream operators and Holoviz still hold the ones before it.
        self._ring = 5
        self._display = cp.zeros(
            (self._ring, len(cam_names), height, width, 3), cp.uint8
        )
        self._batch = None
        if batch_size:
            self._scale = width // MODEL_WIDTH
            if (width, height) != (
                MODEL_WIDTH * self._scale,
                SCALED_HEIGHT * self._scale,
            ):
                raise ValueError(
                    f"{width}x{height} does not scale to {MODEL_WIDTH}x{SCALED_HEIGHT}"
                )
            self._batch = cp.full(
                (self._ring, batch_size, 3, MODEL_HEIGHT, MODEL_WIDTH),
                PAD_VALUE,
                cp.float32,
            )
        self._slot = 0
        self._last_seen = [None] * len(cam_names)
        self._fresh = [0] * len(cam_names)
        self._fresh_lock = threading.Lock()
        self._frame_limit = frame_limit
        self._ticks = 0
        self._logo = load_logo(logo_path) if logo_path else None
        super().__init__(fragment, *args, **kwargs)

    def setup(self, spec):
        for port in self._ports:
            spec.input(port, policy=IOSpec.QueuePolicy.POP).condition(
                ConditionType.NONE
            )
        spec.multi_port_condition(
            kind=ConditionType.MULTI_MESSAGE_AVAILABLE_TIMEOUT,
            port_names=self._ports,
            sampling_mode="SumOfAll",
            min_sum=len(self._ports),
            execution_frequency=self._timeout,
        )
        spec.output("frames")
        if self._batch is not None:
            spec.output("batch")

    def take_fresh_counts(self):
        with self._fresh_lock:
            counts, self._fresh = self._fresh, [0] * len(self._cam_names)
        return counts

    def compute(self, op_input, op_output, context):
        now = time.monotonic()
        slot = self._slot
        previous_slot = (slot - 1) % self._ring
        self._slot = (slot + 1) % self._ring
        batch = self._batch[slot] if self._batch is not None else None
        frames = {}
        live = []
        for i, port in enumerate(self._ports):
            message = op_input.receive(port)
            display = self._display[slot, i]
            if message is not None:
                if isinstance(message, dict):
                    tensor = next(iter(message.values()))
                else:
                    tensor = message.get(self._cam_names[i])
                shift_to_uint8(cp.asarray(tensor), display)
                if batch is not None:
                    # Area-average down to 640x360, scaled to 0..1, into this camera's
                    # slot of the batch (rows PAD_TOP..PAD_TOP+360 are the image).
                    s = self._scale
                    pooled = display.reshape(SCALED_HEIGHT, s, MODEL_WIDTH, s, 3).sum(
                        axis=(1, 3), dtype=cp.float32
                    )
                    batch[i, :, PAD_TOP : PAD_TOP + SCALED_HEIGHT, :] = (
                        pooled.transpose(2, 0, 1) / (255.0 * s * s)
                    )
                self._last_seen[i] = now
                with self._fresh_lock:
                    self._fresh[i] += 1
            else:
                display[...] = self._display[previous_slot, i]
                if batch is not None:
                    batch[i] = self._batch[previous_slot, i]
            frames[self._cam_names[i]] = display
            seen = self._last_seen[i]
            live.append(seen is not None and now - seen < NO_SIGNAL_S)
        if self._logo is not None:
            frames["logo"] = self._logo
        # Per-camera liveness for the overlay
        frames["live"] = np.array(live, dtype=np.uint8)
        # Holoviz and TensorRT read these buffers on their own CUDA streams
        cp.cuda.get_current_stream().synchronize()
        op_output.emit(frames, "frames")
        if batch is not None:
            op_output.emit({"images": batch}, "batch")
        self._ticks += 1
        if self._frame_limit and self._ticks >= self._frame_limit:
            self.fragment.stop_execution()


class TileOverlayOp(holoscan.core.Operator):
    """Emits the camera frames and the logo to Holoviz, with a NO SIGNAL label over
    each camera that has stopped delivering frames, and the matching input specs.
    Camera frame rates go to the log."""

    def __init__(self, fragment, *args, cam_names, views, logo_view, batch_op,
                 **kwargs):  # fmt: skip
        self._cam_names = cam_names
        self._views = views
        self._logo_view = logo_view
        self._batch_op = batch_op
        self._ticks = 0
        self._busy_s = 0.0
        self._stats_start = None
        super().__init__(fragment, *args, **kwargs)

    def setup(self, spec):
        spec.input("frames")
        spec.output("out")
        spec.output("specs")

    def _spec(self, name, kind, view, color=None, **settings):
        spec = holoscan.operators.HolovizOp.InputSpec(name, kind)
        if view is not None:
            spec.views = [view]
        if color is not None:
            spec.color = color
        for key, value in settings.items():
            setattr(spec, key, value)
        return spec

    def _tiles(self, frames):
        """Returns (tensors, specs, live) for the camera frames, the logo and the
        NO SIGNAL labels."""
        HV = holoscan.operators.HolovizOp
        live = np.asarray(frames["live"])
        out = {}
        specs = []
        for i, name in enumerate(self._cam_names):
            out[name] = frames[name]
            specs.append(self._spec(name, HV.InputType.COLOR, self._views[i]))
        if self._logo_view is not None and "logo" in frames:
            out["logo"] = frames["logo"]
            specs.append(
                self._spec(
                    "logo",
                    HV.InputType.COLOR,
                    self._logo_view,
                    image_format=HV.ImageFormat.R8G8B8A8_SRGB,
                )
            )
        for i in range(len(self._cam_names)):
            if not live[i]:
                out[f"nosig{i}"] = cp.asarray([[0.36, 0.45, 0.10]], cp.float32)
                specs.append(self._spec(f"nosig{i}", HV.InputType.TEXT, self._views[i],
                                        [1.0, 0.3, 0.3, 1.0], text=["NO SIGNAL"]))  # fmt: skip
        return out, specs, live

    def _stats(self, elapsed, cam_fps):
        return f"viewer: {self._ticks / elapsed:.1f} frames/s, camera fps [{cam_fps}]"

    def _finish(self, op_output, out, specs, start):
        if self._stats_start is None:
            self._stats_start = start
        self._ticks += 1
        self._busy_s += time.monotonic() - start
        elapsed = time.monotonic() - self._stats_start
        if elapsed >= STATS_PERIOD_S:
            fresh = self._batch_op.take_fresh_counts()
            cam_fps = " ".join(f"{n / elapsed:.0f}" for n in fresh)
            logging.info(self._stats(elapsed, cam_fps))
            self._ticks = 0
            self._busy_s = 0.0
            self._stats_start = time.monotonic()
        # Holoviz reads the overlay tensors on its own CUDA stream
        cp.cuda.get_current_stream().synchronize()
        op_output.emit(out, "out")
        op_output.emit(specs, "specs")

    def compute(self, op_input, op_output, context):
        start = time.monotonic()
        frames = as_dict(op_input.receive("frames"), self._cam_names + ["logo", "live"])
        out, specs, _ = self._tiles(frames)
        self._finish(op_output, out, specs, start)


class PoseOverlayOp(TileOverlayOp):
    """Decodes the batched YOLO11 pose output [B, 4+1+17*3, N], runs per-camera
    non-max suppression and adds boxes and skeletons to the tiles."""

    def __init__(self, fragment, *args, score_threshold, iou_threshold, **kwargs):
        self._score_threshold = score_threshold
        self._iou_threshold = iou_threshold
        self._detections = 0
        super().__init__(fragment, *args, **kwargs)

    def setup(self, spec):
        super().setup(spec)
        spec.input("inference")

    def _candidates(self, output):
        """Returns per-candidate rows [batch index, score, x1, y1, x2, y2, keypoint x,
        keypoint y, keypoint confidence] above the score threshold, on the host, in
        frame-normalized coordinates."""
        scores = output[:, 4, :]
        b, a = cp.nonzero(scores > self._score_threshold)
        if b.size == 0:
            return np.zeros((0, 6 + 3 * KEYPOINTS), np.float32)
        rows = output[b, :, a]
        cx, cy, w, h = rows[:, 0], rows[:, 1], rows[:, 2], rows[:, 3]
        kp = rows[:, 5:].reshape(-1, KEYPOINTS, 3)
        return cp.column_stack(
            [
                b.astype(cp.float32),
                scores[b, a],
                (cx - w / 2) / MODEL_WIDTH,
                (cy - h / 2 - PAD_TOP) / SCALED_HEIGHT,
                (cx + w / 2) / MODEL_WIDTH,
                (cy + h / 2 - PAD_TOP) / SCALED_HEIGHT,
                kp[:, :, 0] / MODEL_WIDTH,
                (kp[:, :, 1] - PAD_TOP) / SCALED_HEIGHT,
                kp[:, :, 2],
            ]
        ).get()

    def _nms(self, rows):
        """Greedy non-max suppression on host rows of one camera."""
        rows = rows[np.argsort(-rows[:, 1])[:300]]
        x1, y1, x2, y2 = rows[:, 2:6].T
        area = (x2 - x1) * (y2 - y1)
        keep = []
        remaining = np.arange(len(rows))
        while remaining.size:
            i = remaining[0]
            keep.append(i)
            rest = remaining[1:]
            w = np.clip(
                np.minimum(x2[i], x2[rest]) - np.maximum(x1[i], x1[rest]), 0, None
            )
            h = np.clip(
                np.minimum(y2[i], y2[rest]) - np.maximum(y1[i], y1[rest]), 0, None
            )
            inter = w * h
            iou = inter / (area[i] + area[rest] - inter + 1e-9)
            remaining = rest[iou < self._iou_threshold]
        return rows[keep]

    def compute(self, op_input, op_output, context):
        start = time.monotonic()
        frames = as_dict(op_input.receive("frames"), self._cam_names + ["logo", "live"])
        inference = as_dict(op_input.receive("inference"), ["output0"])
        output = cp.asarray(inference["output0"])
        out, specs, live = self._tiles(frames)
        rows = self._candidates(output)
        HV = holoscan.operators.HolovizOp

        total = 0
        for i, view in enumerate(self._views):
            if not live[i]:
                continue
            camera_rows = rows[rows[:, 0] == i]
            if len(camera_rows) == 0:
                continue
            kept = self._nms(camera_rows)
            total += len(kept)
            corners = (
                np.clip(kept[:, 2:6], 0.0, 1.0).reshape(1, -1, 2).astype(np.float32)
            )
            out[f"box{i}"] = cp.asarray(corners)
            specs.append(self._spec(f"box{i}", HV.InputType.RECTANGLES, view,
                                    [0.0, 1.0, 0.0, 0.6], line_width=2.0))  # fmt: skip
            kx = np.clip(kept[:, 6 : 6 + KEYPOINTS], 0.0, 1.0)
            ky = np.clip(kept[:, 6 + KEYPOINTS : 6 + 2 * KEYPOINTS], 0.0, 1.0)
            visible = kept[:, 6 + 2 * KEYPOINTS : 6 + 3 * KEYPOINTS] > 0.5
            start_kp, end_kp = SKELETON[:, 0], SKELETON[:, 1]
            drawn = visible[:, start_kp] & visible[:, end_kp]
            if drawn.any():
                segments = np.stack(
                    [kx[:, start_kp][drawn], ky[:, start_kp][drawn],
                     kx[:, end_kp][drawn], ky[:, end_kp][drawn]], axis=-1
                ).reshape(1, -1, 2).astype(np.float32)  # fmt: skip
                out[f"seg{i}"] = cp.asarray(segments)
                specs.append(self._spec(f"seg{i}", HV.InputType.LINES, view,
                                        [0.0, 0.9, 1.0, 1.0], line_width=3.0))  # fmt: skip
            if visible.any():
                points = np.stack([kx[visible], ky[visible]], axis=-1)
                out[f"kp{i}"] = cp.asarray(points[None].astype(np.float32))
                specs.append(self._spec(f"kp{i}", HV.InputType.POINTS, view,
                                        [1.0, 0.2, 0.2, 1.0], point_size=6.0))  # fmt: skip

        self._detections += total
        self._finish(op_output, out, specs, start)

    def _stats(self, elapsed, cam_fps):
        ticks = max(self._ticks, 1)
        line = (
            f"pose: {self._ticks / elapsed:.1f} batches/s, camera fps [{cam_fps}],"
            f" overlay {1000 * self._busy_s / ticks:.1f} ms/batch,"
            f" {self._detections / ticks:.1f} people/batch"
        )
        self._detections = 0
        return line


class PlayerApplication(holoscan.core.Application):
    def __init__(self, args, cuda_context, cuda_device_ordinal, camera_streams,
                 window_width, window_height, logo_path):  # fmt: skip
        logging.info("__init__")
        super().__init__()
        self._args = args
        self._cuda_context = cuda_context
        self._cuda_device_ordinal = cuda_device_ordinal
        self._camera_streams = camera_streams
        self._window_width = window_width
        self._window_height = window_height
        self._logo_path = logo_path
        # Nothing here reads the receivers' metadata, and Holoscan 4.2 faults merging the
        # eight camera paths' metadata into one operator.
        self.is_metadata_enabled = False

    def _layout(self):
        """Returns the Holoviz view of each camera tile and of the logo tile (or None)."""
        grid_columns, grid_rows = grid_shape(
            len(self._camera_streams), self._args.grid_columns
        )
        # Keep every tile 16:9 and centre the grid, so a window shaped differently from
        # the grid letterboxes instead of stretching.
        tile_width = min(
            self._window_width / grid_columns,
            self._window_height / grid_rows * 16 / 9,
        )
        tile_height = tile_width * 9 / 16
        margin_x = (self._window_width - tile_width * grid_columns) / 2
        margin_y = (self._window_height - tile_height * grid_rows) / 2
        # Tile edges on whole pixels, each tile reaching one pixel into its right and
        # lower neighbours: a window width that does not divide by the column count
        # otherwise rounds a one-pixel black seam between two of the columns.
        edges_x = [round(margin_x + i * tile_width) for i in range(grid_columns + 1)]
        edges_y = [round(margin_y + i * tile_height) for i in range(grid_rows + 1)]

        def tile_view(cell):
            col, row = cell % grid_columns, cell // grid_columns
            view = holoscan.operators.HolovizOp.InputSpec.View()
            view.offset_x = edges_x[col] / self._window_width
            view.offset_y = edges_y[row] / self._window_height
            view.width = (
                edges_x[col + 1] - edges_x[col] + (col < grid_columns - 1)
            ) / self._window_width
            view.height = (
                edges_y[row + 1] - edges_y[row] + (row < grid_rows - 1)
            ) / self._window_height
            return view

        # With one cell to spare in an odd-by-odd grid (8 cameras in 3x3) the logo takes
        # the centre cell and the cameras fill the rest in reading order; otherwise the
        # logo takes the first empty cell.
        cells = grid_columns * grid_rows
        logo_cell = None
        if self._logo_path and len(self._camera_streams) < cells:
            if (
                len(self._camera_streams) == cells - 1
                and grid_columns % 2
                and grid_rows % 2
            ):
                logo_cell = (grid_rows // 2) * grid_columns + grid_columns // 2
            else:
                logo_cell = len(self._camera_streams)
        camera_cells = [c for c in range(cells) if c != logo_cell]
        camera_views = [
            tile_view(camera_cells[i]) for i in range(len(self._camera_streams))
        ]
        logo_view = tile_view(logo_cell) if logo_cell is not None else None
        return camera_views, logo_view

    def _camera_pipeline(self, stream):
        """Receiver through demosaic for one camera; returns (receiver, demosaic)."""
        width, height = stream.camera._width, stream.camera._height
        csi_to_bayer_pool = holoscan.resources.BlockMemoryPool(
            self,
            name=f"csi_pool-{stream.name}",
            # storage_type of 1 is device memory
            storage_type=1,
            block_size=width * ctypes.sizeof(ctypes.c_uint16) * height,
            num_blocks=6,
        )
        bayer_pool = holoscan.resources.BlockMemoryPool(
            self,
            name=f"bayer_pool-{stream.name}",
            storage_type=1,
            block_size=width * 3 * ctypes.sizeof(ctypes.c_uint16) * height,
            num_blocks=6,
        )
        condition = holoscan.conditions.BooleanCondition(
            self, name=f"ok-{stream.name}", enable_tick=True
        )
        csi_to_bayer = hololink_module.operators.CsiToBayerOp(
            self,
            name=f"csi_to_bayer-{stream.name}",
            allocator=csi_to_bayer_pool,
            cuda_device_ordinal=self._cuda_device_ordinal,
            out_tensor_name=stream.name,
        )
        stream.camera.configure_converter(csi_to_bayer)
        receiver = hololink_module.operators.LinuxReceiverOperator(
            self,
            condition,
            name=f"receiver-{stream.name}",
            frame_size=csi_to_bayer.get_csi_length(),
            frame_context=self._cuda_context,
            hololink_channel=stream.hololink_channel,
            device=stream.camera,
            # spread the receivers over distinct CPUs
            receiver_affinity={2 + stream.cam_idx},
        )
        bayer_format = stream.camera.bayer_format()
        image_processor = hololink_module.operators.ImageProcessorOp(
            self,
            name=f"image_processor-{stream.name}",
            optical_black=stream.camera.optical_black(),
            bayer_format=bayer_format.value,
            pixel_format=stream.camera.pixel_format().value,
        )
        demosaic = holoscan.operators.BayerDemosaicOp(
            self,
            name=f"demosaic-{stream.name}",
            pool=bayer_pool,
            bayer_grid_pos=bayer_format.value,
            interpolation_mode=0,
            in_tensor_name=stream.name,
            out_tensor_name=stream.name,
            generate_alpha=False,
        )
        self.add_flow(receiver, csi_to_bayer, {("output", "input")})
        self.add_flow(csi_to_bayer, image_processor, {("output", "input")})
        self.add_flow(image_processor, demosaic, {("output", "receiver")})
        return receiver, demosaic

    def _visualizer(self, **kwargs):
        return holoscan.operators.HolovizOp(
            self,
            name="holoviz",
            fullscreen=self._args.fullscreen,
            headless=self._args.headless,
            framebuffer_srgb=True,
            # FIFO presentation: swaps only on the vertical blank, so no tearing
            vsync=True,
            height=self._window_height,
            width=self._window_width,
            window_title=WINDOW_TITLE,
            **kwargs,
        )

    def compose(self):
        logging.info("compose")
        args = self._args
        camera_views, logo_view = self._layout()
        streams = list(self._camera_streams.values())
        cam_names = [stream.name for stream in streams]
        pose = args.model == "pose"
        batch_op = BatchOp(
            self,
            name="batch",
            cam_names=cam_names,
            width=streams[0].camera._width,
            height=streams[0].camera._height,
            batch_size=args.batch_size if pose else None,
            # Just over one frame period: while a camera is dead every tick waits out
            # the timeout, so the others run a little below the frame rate
            timeout=f"{int(1100 / args.frame_rate)}ms",
            logo_path=self._logo_path if logo_view is not None else None,
            frame_limit=args.frame_limit,
        )
        overlay_args = dict(
            name="overlay",
            cam_names=cam_names,
            views=camera_views,
            logo_view=logo_view,
            batch_op=batch_op,
        )
        if pose:
            overlay = PoseOverlayOp(
                self,
                score_threshold=args.score_threshold,
                iou_threshold=args.iou_threshold,
                **overlay_args,
            )
            inference = holoscan.operators.InferenceOp(
                self,
                name="inference",
                allocator=holoscan.resources.UnboundedAllocator(self),
                backend="trt",
                model_path_map={"yolo": args.engine},
                pre_processor_map={"yolo": ["images"]},
                inference_map={"yolo": ["output0"]},
                input_on_cuda=True,
                output_on_cuda=True,
                is_engine_path=True,
            )
            self.add_flow(batch_op, inference, {("batch", "receivers")})
            self.add_flow(inference, overlay, {("transmitter", "inference")})
        else:
            overlay = TileOverlayOp(self, **overlay_args)
        visualizer = self._visualizer()
        for index, stream in enumerate(streams):
            _, demosaic = self._camera_pipeline(stream)
            self.add_flow(demosaic, batch_op, {("transmitter", f"in{index}")})
        self.add_flow(batch_op, overlay, {("frames", "frames")})
        self.add_flow(overlay, visualizer, {("out", "receivers")})
        self.add_flow(overlay, visualizer, {("specs", "input_specs")})
        # Multi-threaded, so the batching operator's timeout keeps a dead camera from
        # stalling the others.
        self.scheduler(
            holoscan.schedulers.MultiThreadScheduler(
                self,
                name="multithread_scheduler",
                worker_thread_number=8,
                stop_on_deadlock=True,
            )
        )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--cams",
        type=parse_camera_list,
        default=list(range(len(CAMERA_CONNECTORS))),
        help="comma-separated list of cameras to stream:"
        + ", ".join(f" {i}={c}" for i, c in enumerate(CAMERA_CONNECTORS))
        + " (default all eight)",
    )
    parser.add_argument(
        "--resolution",
        default="1080p",
        choices=tuple(RESOLUTIONS),
        help="camera resolution (default 1080p)",
    )
    parser.add_argument(
        "--frame-rate",
        type=int,
        default=30,
        choices=(30, 60),
        help="camera frame rate (default 30)",
    )
    parser.add_argument(
        "--bit-depth",
        type=int,
        default=10,
        choices=(10, 12),
        help="camera bit depth (default 10)",
    )
    parser.add_argument(
        "--gain",
        type=int,
        default=32,
        help="analog gain, 0 to 240 (default 32)",
    )
    parser.add_argument(
        "--model",
        default="none",
        choices=("none", "pose"),
        help="none: camera view only; pose: YOLO11 body pose on every camera"
        " (default none)",
    )
    parser.add_argument(
        "--engine",
        default=None,
        help="YOLO11 pose TensorRT engine file, required with --model pose",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=8,
        help="batch size the engine was built with, at least the number of cameras"
        " (default 8)",
    )
    parser.add_argument(
        "--score-threshold",
        type=float,
        default=0.5,
        help="minimum person score (default 0.5)",
    )
    parser.add_argument(
        "--iou-threshold",
        type=float,
        default=0.5,
        help="non-max suppression IoU threshold (default 0.5)",
    )
    parser.add_argument("--fullscreen", action="store_true", help="run fullscreen")
    parser.add_argument("--headless", action="store_true", help="run without a window")
    parser.add_argument(
        "--window-width",
        type=int,
        default=None,
        help="window width (default fits the camera grid; with --fullscreen pass the"
        " monitor resolution)",
    )
    parser.add_argument(
        "--window-height",
        type=int,
        default=None,
        help="window height (default fits the camera grid)",
    )
    parser.add_argument(
        "--grid-columns",
        type=int,
        default=None,
        help="tiles per row (default near-square: 3x3 for 7-9 cameras)",
    )
    parser.add_argument(
        "--logo",
        default=None,
        help="image shown in a spare grid cell (default the Critical Link logo card"
        " when the centre cell of an odd-by-odd grid is the only spare one)",
    )
    parser.add_argument("--no-logo", action="store_true", help="show no logo")
    parser.add_argument(
        "--frame-limit",
        type=int,
        default=None,
        help="exit after this many display frames",
    )
    parser.add_argument(
        "--log-level",
        type=int,
        default=20,
        help="logging level (default 20, INFO)",
    )
    args = parser.parse_args()
    hololink_module.logging_level(args.log_level)
    logging.info("Initializing.")

    if args.model == "pose":
        if args.engine is None:
            parser.error("--model pose needs --engine")
        if not os.path.exists(args.engine):
            parser.error(f"TensorRT engine not found: {args.engine}")
        if len(args.cams) > args.batch_size:
            parser.error(
                f"{len(args.cams)} cameras exceed --batch-size {args.batch_size}"
            )

    grid_columns, grid_rows = grid_shape(len(args.cams), args.grid_columns)
    logo = None if args.no_logo else args.logo
    if (
        logo is None
        and not args.no_logo
        and len(args.cams) == grid_columns * grid_rows - 1
        and grid_columns % 2
        and grid_rows % 2
    ):
        logo = DEFAULT_LOGO
    if logo is not None:
        try:
            PIL.Image.open(logo).verify()
        except (OSError, SyntaxError) as e:
            # A clone made without Git LFS holds a pointer file instead of the image; Pillow
            # reports a damaged PNG as SyntaxError
            logging.warning(f"Not showing the logo: {e}")
            logo = None
    window_width = args.window_width or grid_columns * 640
    window_height = args.window_height or grid_rows * 360

    # Get a handle to the GPU
    (cu_result,) = cuda.cuInit(0)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS
    cu_device_ordinal = 0
    cu_result, cu_device = cuda.cuDeviceGet(cu_device_ordinal)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS
    cu_result, cu_context = cuda.cuDevicePrimaryCtxRetain(cu_device)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS

    # The designs carry one sensor interface per camera on a single data plane
    uuid_strategy = hololink_module.BasicEnumerationStrategy(
        total_sensors=len(CAMERA_CONNECTORS), total_dataplanes=1, sifs_per_sensor=1
    )
    for uuid in UUIDS:
        hololink_module.Enumerator.set_uuid_strategy(uuid, uuid_strategy)

    channel_metadata = hololink_module.Enumerator.find_channel(channel_ip=FPGA_IP)
    # The designs have no HSB VSYNC generator and do not use PTP
    channel_metadata.update(
        hololink_module.Metadata({"vsync_enable": 0, "ptp_enable": 0})
    )

    camera_streams = {}
    for cam_index in args.cams:
        camera_channel = hololink_module.Metadata(channel_metadata)
        hololink_module.DataChannel.use_sensor(camera_channel, cam_index)
        hololink_channel = hololink_module.DataChannel(camera_channel)
        camera = MitySomImx678(hololink_channel, camera_id=cam_index)
        camera_streams[cam_index] = CameraStream(cam_index, hololink_channel, camera)

    first_stream = next(iter(camera_streams.values()))
    mode = first_stream.camera.get_mode(
        RESOLUTIONS[args.resolution], args.frame_rate, args.bit_depth
    )

    hololink = first_stream.hololink_channel.hololink()
    hololink.start()
    try:
        hololink.reset()
        for camera_stream in camera_streams.values():
            camera_stream.camera.configure(mode)
            camera_stream.camera.set_analog_gain_reg(args.gain)
        application = PlayerApplication(
            args,
            cu_context,
            cu_device_ordinal,
            camera_streams,
            window_width,
            window_height,
            logo,
        )
        application.run()
    finally:
        hololink.stop()

    (cu_result,) = cuda.cuDevicePrimaryCtxRelease(cu_device)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS


if __name__ == "__main__":
    main()
