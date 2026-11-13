#!/bin/sh
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

# Prepares a Jetson AGX Thor's QSFP port for the MitySOM-A5E sensor bridge: host
# address, receive tuning for eight camera streams on the Linux network stack, and the
# FPGA's static neighbour entry. Run as root after every boot, again after the sensor
# bridge board is power cycled (a link-down flushes the neighbour entry), and after a
# player run with --coe. It resets the link, so it stops any stream running on the port.
#   usage: sudo thor_network_setup.sh [interface]   (default mgbe0_0)

IF=${1:-mgbe0_0}
[ -d "/sys/class/net/$IF" ] || { echo "$0: no interface $IF" >&2; exit 1; }
HOST_ADDRESS=192.168.0.101/24
FPGA_IP=192.168.0.2
# MAC address of the FPGA's Ethernet port, set in the HSB IP
FPGA_MAC=ca:fe:c0:ff:ee:10

# The receiver asks for a socket buffer of about one frame; the default rmem_max
# (208 KB) clamps it and drops frames.
sysctl -q -w net.core.rmem_max=268435456
sysctl -q -w net.core.rmem_default=33554432
sysctl -q -w net.core.netdev_max_backlog=300000
sysctl -q -w net.core.netdev_budget=1200

# Bounce the link: after a hardware CoE capture closes its channels, the port's normal
# receive path stays slow until the interface is reset.
ip link set "$IF" down
ip link set "$IF" up
ip addr replace $HOST_ADDRESS dev "$IF"

# Largest RX ring to absorb bursts. Resizing resets the NIC, which drops the link and
# flushes the neighbour table, so it goes before the neighbour entry.
ethtool -G "$IF" rx 16384 || true
# Deferred IOMMU unmap for the NIC's DMA
G=$(basename "$(readlink "/sys/class/net/$IF/device/iommu_group")")
echo DMA-FQ > "/sys/kernel/iommu_groups/$G/type" || true

# Pin the four RX queue interrupts to CPUs 10-13. mitysom_player.py pins its camera
# receiver threads to CPUs 2-9 (2 + camera index), so the NIC's work stays off those.
cpu=10
# shellcheck disable=SC2013  # one interrupt number per line
for irq in $(awk -F: -v i="$IF" '$0 ~ i"\\.vm[0-3]" { gsub(/ /, "", $1); print $1 }' /proc/interrupts); do
	echo $cpu > "/proc/irq/$irq/smp_affinity_list"
	cpu=$((cpu + 1))
done
# A CoE capture (--coe) arms the port's macsec_ns interrupt and the Ethernet driver never
# disarms it, so it keeps firing on received packets until the next boot. Left on CPU0
# that load starves the network receive path; move it to CPU 1, clear of the camera
# receiver threads and the RX queues.
# shellcheck disable=SC2013  # one interrupt number per line
for irq in $(awk -F: -v i="$IF" '$0 ~ i"\\.macsec_ns" { gsub(/ /, "", $1); print $1 }' /proc/interrupts); do
	echo 1 > "/proc/irq/$irq/smp_affinity_list"
done
# NAPI poll in per-queue kernel threads, one RX/TX pair per CPU in 10-13, so each RX
# queue's poller has a core of its own.
echo 1 > "/sys/class/net/$IF/threaded"
cpu=10; n=0
for pid in $(for p in $(pgrep "^napi/$IF-"); do echo "$(sed 's/.*-//' "/proc/$p/comm") $p"; done | sort -n | awk '{ print $2 }'); do
	taskset -pc $cpu "$pid" >/dev/null
	n=$((n + 1)); [ $((n % 2)) -eq 0 ] && cpu=$((cpu + 1))
done
# RPS spreads each queue's protocol processing over CPUs 10-13 (mask 0x3c00) by flow
# hash, so a queue that RSS has given several camera streams does not saturate one CPU.
for q in "/sys/class/net/$IF"/queues/rx-*; do echo 3c00 > "$q/rps_cpus"; done
jetson_clocks || true

# Wait for the link to come back up before adding the neighbour entry: the link coming up
# from the resets above would flush an entry added earlier.
for _ in $(seq 30); do [ "$(cat "/sys/class/net/$IF/carrier" 2>/dev/null)" = 1 ] && break; sleep 1; done
[ "$(cat "/sys/class/net/$IF/carrier" 2>/dev/null)" = 1 ] ||
	echo "$0: no link on $IF; power the sensor bridge board and run this again" >&2

# The FPGA's Ethernet MAC does not answer ARP, so its neighbour entry must be static.
ip neigh replace $FPGA_IP lladdr $FPGA_MAC dev "$IF" nud permanent
