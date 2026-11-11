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

# Builds a design and writes its flash images into the design's quartus/output_files/:
#   quartus_sh -t fpga/critical_link/build.tcl <design> [-spl <u-boot-spl.ihex>] [-images_only]
# <design> is the path of a design directory, or the name of one beside this script.
# An FPGA-first design gives <design>.sof and <design>.jic. An HPS-first design needs the
# HPS U-Boot SPL and gives <design>.sof, <design>.hps.jic and <design>.core.rbf, which must
# be used together. -images_only writes the images from the SOF already there.

# QSPI flash on the MitySOM-A5E
set flash_device MT25QU256

proc fail {message} {
    post_message -type error $message
    qexit -error
}

# Runs a Quartus tool with its output on the console; a non-zero exit stops the build
proc run {args} {
    puts "\n=== [join $args]"
    flush stdout
    if {[catch {exec -ignorestderr -- {*}$args >@stdout 2>@stderr}]} {
        fail "[lindex $args 0] failed"
    }
}

set usage "usage: quartus_sh -t [info script] <design> \[-spl <u-boot-spl.ihex>\]\
           \[-images_only\]"
set design ""
set spl ""
set images_only 0
for {set i 0} {$i < [llength $argv]} {incr i} {
    switch -- [lindex $argv $i] {
        -spl {
            incr i
            set value [lindex $argv $i]
            if {$value eq "" || [string index $value 0] eq "-"} {
                fail "-spl needs the path of u-boot-spl.ihex"
            }
            set spl [file normalize $value]
        }
        -images_only {
            set images_only 1
        }
        default {
            set arg [lindex $argv $i]
            if {$design ne "" || [string index $arg 0] eq "-"} {
                fail "unexpected argument $arg; $usage"
            }
            set design $arg
        }
    }
}

if {$design eq ""} {
    fail $usage
}
# A path to the design, else a design name beside this script
set design_dir [file normalize $design]
if {[llength [glob -nocomplain -directory [file join $design_dir quartus] *.qpf]] == 0} {
    set design_dir [file normalize [file join [file dirname [info script]] $design]]
}
set quartus_dir [file join $design_dir quartus]
set qpf [glob -nocomplain -directory $quartus_dir *.qpf]
if {[llength $qpf] != 1} {
    fail "no design $design: expected one .qpf in $quartus_dir"
}
set project [file rootname [file tail [lindex $qpf 0]]]
cd $quartus_dir

project_open -revision $project $project
set device [get_global_assignment -name DEVICE]
set hps_first [string equal -nocase [get_global_assignment -name HPS_INITIALIZATION] "HPS FIRST"]
set hps_owns_qspi [string equal -nocase [get_global_assignment -name QSPI_OWNERSHIP] "HPS"]
project_close -dont_export_assignments

if {$hps_first != $hps_owns_qspi} {
    fail "$project: HPS_INITIALIZATION and QSPI_OWNERSHIP disagree"
}
if {$hps_first && $spl eq ""} {
    fail "$project boots HPS-first: pass -spl <u-boot-spl.ihex> (attached to each release)"
}
if {!$hps_first && $spl ne ""} {
    fail "$project boots FPGA-first and takes no -spl"
}
if {$spl ne "" && ![file isfile $spl]} {
    fail "SPL not found: $spl"
}

set out [file join $quartus_dir output_files]
set sof [file join $out $project.sof]
set jic [file join $out $project.jic]
set images [list $jic [file join $out $project.hps.jic] [file join $out $project.core.rbf]]

if {!$images_only} {
    # The assembler writes <project>_time_limited.sof instead when an IP license is missing,
    # so an old <project>.sof must not survive to be packaged
    file delete -force $sof [file join $out ${project}_time_limited.sof] {*}$images
    run quartus_ipgenerate $project --generate_project_ip_files --clear_ip_generation_dirs
    run quartus_syn $project
    run quartus_fit $project
    run quartus_sta $project
    run quartus_asm $project
    if {![file isfile $sof]} {
        fail "$project.sof was not written: check that the MIPI D-PHY and CSI-2 IP licenses\
              are installed"
    }
} elseif {![file isfile $sof]} {
    fail "no $sof to write images from"
}

# quartus_sta succeeds on a design that misses timing
set summary [file join $out $project.sta.summary]
set timing_warning ""
if {![file isfile $summary]} {
    set timing_warning "no timing summary at $summary to check the SOF against"
} else {
    set f [open $summary]
    if {[regexp {Slack : -} [read $f]]} {
        set timing_warning "$project misses timing: see $summary"
    }
    close $f
}
if {$timing_warning ne ""} {
    post_message -type warning $timing_warning
}

file delete -force {*}$images
set options [list -o device=$flash_device -o mode=ASX4 -o flash_loader=$device]
if {$hps_first} {
    lappend options -o hps_path=$spl -o hps=on
    set expected [lrange $images 1 2]
} else {
    set expected [lrange $images 0 0]
}
run quartus_pfg -c {*}$options $sof $jic
foreach image $expected {
    if {![file isfile $image]} {
        fail "quartus_pfg did not write $image"
    }
}
puts "\n[join [list $sof {*}$expected] \n]"
if {$timing_warning ne ""} {
    post_message -type warning $timing_warning
}
qexit -success
