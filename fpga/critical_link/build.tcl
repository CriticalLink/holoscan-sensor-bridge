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

# Builds a design for a MitySOM-A5E SOM model and writes its flash images:
#   quartus_sh -t fpga/critical_link/build.tcl <design> [-model <model>] [-spl <SPL .ihex>]
#                                              [-images_only]
# <design> is the path of a design directory, or the name of one beside this script. Without
# -model the design's default model builds: the one model whose part is the design's qsf DEVICE.
# A model with that part, and for an HPS-first design the HPS memory size and rate the design
# carries, builds in place into the design's quartus/output_files/. Any other model builds in
# a copy of the design's sources at fpga/build/<design>_<model>/, so the design itself is not
# changed.
# An FPGA-first design gives <design>_<model>.sof and .jic. An HPS-first design needs the HPS
# U-Boot SPL of its SOM and gives <design>_<model>.sof, .hps.jic and .core.rbf, which must be used
# together. -images_only writes the images from the SOF already there.

# QSPI flash on the MitySOM-A5E
set flash_device MT25QU256
set script_dir [file dirname [file normalize [info script]]]

# The value of an IP-XACT parameter in a .ip or .qsys text, or "" when it is absent
proc ip_parameter {text name} {
    if {[regexp "<ipxact:name>$name</ipxact:name>.*?<ipxact:value>(\[^<\]*)<" $text -> value]} {
        return $value
    }
    return ""
}

proc fail {message} {
    post_message -type error $message
    qexit -error
}

# Runs a Quartus tool with its output on the console; a non-zero exit stops the build
proc run {args} {
    puts "\n=== [join $args]"
    flush stdout
    if {[catch {exec -ignorestderr -- {*}$args >@stdout 2>@stderr} message]} {
        fail "[lindex $args 0] failed: $message"
    }
}

# The MitySOM-A5E parts: group A (SmartVID, "V") or B (fixed voltage, "S")
set part_pattern {^A5ED[0-9]{3}([AB])B[0-9]{2}A[EI][0-9]([VS])(R[0-9]|CS)?$}

# The SOM models these designs build for, with their part, platform (mitysom for the STD SOM,
# mitysom_mini for the Mini SOM) and HPS memory size in GB and rate in MHz as the reference
# design's Makefile defines them
set models {
    A5ED-B64-144-SRI    {part A5ED065BB32AI4S   platform mitysom      size 4 rate 1333.333}
    A5ED-B64-144-SRC-X  {part A5ED065BB32AE4SR0 platform mitysom      size 4 rate 1333.333}
    A5ED-B64-188-SRC-X  {part A5ED065BB32AE4SR0 platform mitysom      size 8 rate 1333.333}
    A5ED-B46-144-SRI    {part A5ED043BB32AI6S   platform mitysom      size 4 rate 1066.667}
    A5ED-A63-144-SRC    {part A5ED065AB32AE3V   platform mitysom      size 4 rate 1333.333}
    A5ED-B16-1X4-MRI-CS {part A5ED013BB23AI6SCS platform mitysom_mini size 4 rate 1066.667}
    A5ED-B06-1X2-MRI-CS {part A5ED008BB23AI6SCS platform mitysom_mini size 2 rate 1066.667}
    A5ED-A43-1X4-MRI    {part A5ED043AB23AI3V   platform mitysom_mini size 4 rate 1333.333}
    A5ED-B44-1X4-MRI    {part A5ED043BB23AI4S   platform mitysom_mini size 4 rate 1333.333}
    A5ED-B14-1X4-MRC-B0 {part A5ED013BB23AE4SR1 platform mitysom_mini size 4 rate 1333.333}
    A5ED-B14-1X8-MRC-B0 {part A5ED013BB23AE4SR1 platform mitysom_mini size 8 rate 1333.333}
}

# HPS LPDDR4 EMIF parameters per size and rate, from the reference design's
# scripts/ddr_settings.tcl as its hps_subsys/create_hps_subsys.tcl applies them. The EMIF IP
# turns the scrambler off with 16 Gb dies whatever the rate asks, so the 8 GB entry says so.
set emif_size_parameters {
    2 {MEM_CHANNEL_CS_WIDTH 1 MEM_CS_WIDTH 1 MEM_CKE_WIDTH 1 MEM_CHANNEL_ADDR_NUM_BITS 34
       MEM_CHANNEL_CAPACITY_GBITS 16.0 MEM_DIE_DENSITY_GBITS 8 MEM_ROW_ADDR_WIDTH 16
       MEM_TRFCAB_NS 280.0 MEM_TRFCPB_NS 140.0 MEM_TXSR_NS 287.5}
    4 {MEM_CHANNEL_CS_WIDTH 2 MEM_CS_WIDTH 2 MEM_CKE_WIDTH 2 MEM_CHANNEL_ADDR_NUM_BITS 35
       MEM_CHANNEL_CAPACITY_GBITS 32.0 MEM_DIE_DENSITY_GBITS 8 MEM_ROW_ADDR_WIDTH 16
       MEM_TRFCAB_NS 280.0 MEM_TRFCPB_NS 140.0 MEM_TXSR_NS 287.5}
    8 {MEM_CHANNEL_CS_WIDTH 2 MEM_CS_WIDTH 2 MEM_CKE_WIDTH 2 MEM_CHANNEL_ADDR_NUM_BITS 36
       MEM_CHANNEL_CAPACITY_GBITS 64.0 MEM_DIE_DENSITY_GBITS 16 MEM_ROW_ADDR_WIDTH 17
       MEM_TRFCAB_NS 380.0 MEM_TRFCPB_NS 190.0 MEM_TXSR_NS 387.5 CTRL_SCRAMBLER_EN 0}
}
set emif_rate_parameters {
    1066.667 {CTRL_SCRAMBLER_EN 0 MEM_CL_CYC 20 MEM_CWL_CYC 18 MEM_TCCD_NS 7.5
              MEM_TCKCKEH_NS 2.8125 MEM_TCKCKEL_NS 5.0 MEM_TCKELCK_NS 5.0 MEM_TCKELCMD_NS 5.0
              MEM_TCMDCKE_NS 2.8125 MEM_TESCKE_NS 2.8125 MEM_TMRR_NS 7.5 MEM_TMRW_NS 10.0
              MEM_TRTP_NS 7.5 MEM_TZQCKE_NS 2.8125}
    1333.333 {CTRL_SCRAMBLER_EN 1 MEM_CL_CYC 24 MEM_CWL_CYC 22 MEM_TCCD_NS 6.0
              MEM_TCKCKEH_NS 2.25 MEM_TCKCKEL_NS 5.0 MEM_TCKELCK_NS 5.0 MEM_TCKELCMD_NS 5.0
              MEM_TCMDCKE_NS 2.25 MEM_TESCKE_NS 2.25 MEM_TMRR_NS 6.0 MEM_TMRW_NS 10.0
              MEM_TRTP_NS 7.5 MEM_TZQCKE_NS 2.25}
}

# The hps_emif_0 parameters for a model's HPS memory
proc emif_parameters {model} {
    global models emif_size_parameters emif_rate_parameters
    set rate [dict get $models $model rate]
    return [dict merge [dict get $emif_rate_parameters $rate] \
        [dict get $emif_size_parameters [dict get $models $model size]] \
        [list MEM_OPERATING_FREQ_MHZ $rate]]
}

# The parameters an EMIF .ip text holds with another value; the ones it does not hold are
# derived by the IP from the others
proc emif_mismatches {text parameters} {
    set mismatches {}
    dict for {name value} $parameters {
        set actual [string map {true 1 false 0} [ip_parameter $text $name]]
        if {$actual ne "" && $actual != $value} {
            lappend mismatches $name
        }
    }
    return $mismatches
}

set usage "usage: quartus_sh -t [info script] <design> \[-model <model>\]\
           \[-spl <SPL .ihex>\] \[-images_only\]"
set design ""
set model ""
set spl ""
set images_only 0
for {set i 0} {$i < [llength $argv]} {incr i} {
    switch -- [lindex $argv $i] {
        -spl {
            incr i
            set value [lindex $argv $i]
            if {$value eq "" || [string index $value 0] eq "-"} {
                fail "-spl needs the path of the SOM's U-Boot SPL (.ihex)"
            }
            set spl [file normalize $value]
        }
        -images_only {
            set images_only 1
        }
        -model {
            incr i
            set model [lindex $argv $i]
            if {![dict exists $models $model]} {
                fail "unsupported model '$model': expected one of [join [dict keys $models] {, }]"
            }
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
    set design_dir [file normalize [file join $script_dir $design]]
}
set quartus_dir [file join $design_dir quartus]
set qpf [glob -nocomplain -directory $quartus_dir *.qpf]
if {[llength $qpf] != 1} {
    fail "no design $design: expected one .qpf in $quartus_dir"
}
set project [file rootname [file tail [lindex $qpf 0]]]
cd $quartus_dir

project_open -revision $project $project
set design_device [get_global_assignment -name DEVICE]
set hps_first [string equal -nocase [get_global_assignment -name HPS_INITIALIZATION] "HPS FIRST"]
set hps_owns_qspi [string equal -nocase [get_global_assignment -name QSPI_OWNERSHIP] "HPS"]
project_close -dont_export_assignments

if {$hps_first != $hps_owns_qspi} {
    fail "$project: HPS_INITIALIZATION and QSPI_OWNERSHIP disagree"
}
if {$hps_first && $spl eq ""} {
    fail "$project boots HPS-first: pass -spl with the SOM's U-Boot SPL (attached to each release)"
}
if {!$hps_first && $spl ne ""} {
    fail "$project boots FPGA-first and takes no -spl"
}
if {$spl ne "" && ![file isfile $spl]} {
    fail "SPL not found: $spl"
}

set design_models [dict keys [dict filter $models script {- settings} {
    string equal [dict get $settings part] $design_device
}]]
if {[llength $design_models] == 0} {
    fail "$project: DEVICE $design_device is not the part of any SOM model"
}
# The models sharing a part share its package, so any of them gives the design's platform
set design_platform [dict get $models [lindex $design_models 0] platform]
if {$model eq ""} {
    if {[llength $design_models] > 1} {
        fail "$project: DEVICE $design_device is the part of several SOM models\
              ([join $design_models {, }]): choose one with -model"
    }
    set model [lindex $design_models 0]
}
set part [dict get $models $model part]
set platform [dict get $models $model platform]
if {$platform ne $design_platform} {
    fail "$model is a $platform SOM, but $project is laid out for $design_platform"
}
if {![regexp $part_pattern $part -> group power]} {
    fail "$model: part $part is not a MitySOM-A5E part"
}
if {($group eq "A") != ($power eq "V")} {
    fail "$part: a group A part has SmartVID (V), a group B part fixed voltage (S)"
}
set eth_ip [file join $design_dir rtl user ip gts_eth_subsystem gts_eth_subsystem_eth_gts.ip]
if {![file isfile $eth_ip]} {
    fail "$project: no GTS Ethernet IP at $eth_ip"
}
set f [open $eth_ip]
set text [read $f]
close $f
set eth_mode [ip_parameter $text ETH_MODE_GUI]
if {$eth_mode eq ""} {
    fail "$project: no ETH_MODE_GUI in $eth_ip"
}
if {[string match 25G* $eth_mode] && $group ne "A"} {
    fail "$project runs 25GbE, which needs a group A part, not $model ($part)"
}

# Copies a design's sources: the Platform Designer output directory beside each .qsys or .ip
# and the Quartus work directories are generated, and stale ones would hide a device mismatch.
proc copy_sources {src dst} {
    file mkdir $dst
    foreach path [glob -nocomplain -directory $src * .gitignore] {
        set name [file tail $path]
        if {[file isdirectory $path]} {
            if {$name in {qdb dni tmp-clearbox output_files}
                || [file exists $path.qsys] || [file exists $path.ip]} {
                continue
            }
            copy_sources $path [file join $dst $name]
        } else {
            file copy $path [file join $dst $name]
        }
    }
}

# Lists the Platform Designer .ip and .qsys sources under a design's rtl directory, skipping the
# generated output directories as copy_sources does
proc system_files {dir} {
    set files {}
    foreach path [glob -nocomplain -directory $dir *] {
        if {[file isdirectory $path]} {
            if {![file exists $path.qsys] && ![file exists $path.ip]} {
                lappend files {*}[system_files $path]
            }
        } elseif {[file extension $path] in {.ip .qsys}} {
            lappend files $path
        }
    }
    return $files
}

# Lists the system files that do not name the part, or name another part, as a whole word
proc stale_files {dir part {other ""}} {
    set stale {}
    foreach path [system_files $dir] {
        set f [open $path]
        set text [read $f]
        close $f
        if {![regexp "\\m$part\\M" $text] || ($other ne "" && [regexp "\\m$other\\M" $text])} {
            lappend stale $path
        }
    }
    return $stale
}

# The HPS memory EMIF of an HPS-first design, and the parameters of it that the model changes
proc hps_emif {dir} {
    set paths [lsearch -all -inline [system_files $dir] */hps_emif_0.ip]
    if {[llength $paths] != 1} {
        fail "expected one hps_emif_0.ip under $dir, found [llength $paths]"
    }
    return [lindex $paths 0]
}
set emif {}
set emif_changes {}
if {$hps_first} {
    set emif [emif_parameters $model]
    set f [open [hps_emif [file join $design_dir rtl]]]
    set emif_changes [emif_mismatches [read $f] $emif]
    close $f
}

if {$part eq $design_device && [llength $emif_changes] == 0} {
    # The Platform Designer systems must already carry the qsf's part: a DEVICE edited by hand
    # leaves them stamped for the old one
    set stale [stale_files [file join $design_dir rtl] $part]
    if {[llength $stale]} {
        fail "[llength $stale] Platform Designer files are not stamped for $part, for example\
              [lindex $stale 0]: restore the qsf DEVICE and build another part with -model"
    }
} else {
    set build_dir [file normalize \
        [file join $design_dir .. .. build [file tail $design_dir]_$model]]
    set quartus_dir [file join $build_dir quartus]
    if {$images_only} {
        if {![file isdirectory $quartus_dir]} {
            fail "no $build_dir to write images from: build it with -model $model first"
        }
    } else {
        file delete -force $build_dir
        copy_sources $design_dir $build_dir
        set qsf [file join $quartus_dir $project.qsf]
        set f [open $qsf]
        set text [read $f]
        close $f
        if {![regsub -line {^(set_global_assignment -name DEVICE ).*$} $text "\\1$part" text]} {
            fail "no DEVICE assignment in $qsf"
        }
        # The top's HPS memory chip-select and clock-enable ports carry one bit per rank
        if {$hps_first} {
            set ranks [dict get $emif MEM_CHANNEL_CS_WIDTH]
            set top_v [file join $build_dir rtl $project.v]
            set has_ranks 0
            if {[file isfile $top_v]} {
                set f [open $top_v]
                set has_ranks [regexp {parameter\s+HPS_EMIF_RANKS\M} [read $f]]
                close $f
            }
            if {$has_ranks} {
                append text "set_parameter -name HPS_EMIF_RANKS $ranks\n"
            } elseif {$ranks != 2} {
                fail "$project has no HPS_EMIF_RANKS parameter for the $ranks-rank HPS memory of\
                      $model"
            }
        }
        set f [open $qsf w]
        puts -nonewline $f $text
        close $f

        # Platform Designer systems take the project's device only from a sync, which also sets
        # the HPS memory; the top system goes last so it sees its subsystems' new boundaries
        cd $quartus_dir
        project_open -revision $project $project
        set systems {}
        foreach_in_collection asgn [get_all_global_assignments -name QSYS_FILE] {
            lappend systems [file normalize [lindex $asgn 2]]
        }
        project_close -dont_export_assignments
        set top [lsearch -inline $systems */${project}_qsys.qsys]
        if {$top eq ""} {
            fail "$project: no ${project}_qsys.qsys among its QSYS_FILE assignments"
        }
        set systems [concat [lsearch -all -inline -not -exact $systems $top] [list $top]]
        set search_path [join [list [file join $build_dir non_qpds_ip ** *] \
            [file join $build_dir rtl shell ** *] [file join $build_dir rtl user ** *] {$}] ,]
        set qpf [file join $quartus_dir $project.qpf]
        set sync [file join $script_dir sync_device.tcl]
        foreach system $systems {
            run qsys-script --system-file=$system --quartus-project=$qpf \
                --search-path=$search_path --script=$sync \
                "--cmd=set emif_parameters [list $emif]"
        }

        # Every IP and system now carries the part and the model's HPS memory, and the D-PHY's
        # view of SmartVID agrees
        set old_part [expr {$part eq $design_device ? "" : $design_device}]
        set stale [stale_files [file join $build_dir rtl] $part $old_part]
        if {[llength $stale]} {
            fail "the device sync left [llength $stale] files without $part, for example\
                  [lindex $stale 0]"
        }
        if {$hps_first} {
            set f [open [hps_emif [file join $build_dir rtl]]]
            set emif_changes [emif_mismatches [read $f] $emif]
            close $f
            if {[llength $emif_changes]} {
                fail "the device sync did not set the $model HPS memory: $emif_changes"
            }
        }
        set dphys [lsearch -all -inline [system_files [file join $build_dir rtl]] *_mipi_dphy*.ip]
        if {[llength $dphys] == 0} {
            fail "$project: no MIPI D-PHY IP to check SmartVID support against"
        }
        foreach path $dphys {
            set f [open $path]
            set dphy_vid [ip_parameter [read $f] SYS_INFO_DEVICE_SUPPORTS_VID]
            close $f
            if {$dphy_vid ne [expr {$group eq "A"}]} {
                fail "$part is group $group but [file tail $path] reports SmartVID support\
                      '$dphy_vid'"
            }
        }
    }
    cd $quartus_dir
}

set out [file join $quartus_dir output_files]
set sof [file join $out $project.sof]
set model_sof [file join $out ${project}_$model.sof]
set jic [file join $out ${project}_$model.jic]
set images [list $jic [file join $out ${project}_$model.hps.jic] \
    [file join $out ${project}_$model.core.rbf]]

if {!$images_only} {
    # The assembler writes <project>_time_limited.sof instead when an IP license is missing,
    # so an old <project>.sof must not survive to be packaged
    file delete -force $sof [file join $out ${project}_time_limited.sof] $model_sof {*}$images
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

file delete -force $model_sof {*}$images
file copy $sof $model_sof
set options [list -o device=$flash_device -o mode=ASX4 -o flash_loader=$part]
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
puts "\n[join [list $model_sof {*}$expected] \n]"
if {$timing_warning ne ""} {
    post_message -type warning $timing_warning
}
qexit -success
