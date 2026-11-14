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

# qsys-script for build.tcl -model: sets the emif_parameters given with --cmd on the system's
# hps_emif_0, and stamps the --quartus-project's device into a Platform Designer system and
# its instances, which IP generation alone does not do.
package require -exact qsys 26.1

proc set_emif_parameters {} {
    global emif_parameters
    load_component hps_emif_0
    foreach {name value} $emif_parameters {
        set_component_sub_module_parameter_value emif_0_lpddr4 $name $value
    }
    save_component
    validate_instance hps_emif_0
}

# The EMIF IP rejects a memory rate above the stamped part's speed-grade limit, so a slower
# memory goes in before the part and a faster one after it
set has_emif [expr {[llength $emif_parameters] && [lsearch -exact [get_instances] hps_emif_0] >= 0}]
set emif_first 0
if {$has_emif} {
    load_component hps_emif_0
    set rate [get_component_sub_module_parameter_value emif_0_lpddr4 MEM_OPERATING_FREQ_MHZ]
    foreach {name value} $emif_parameters {
        if {[string equal $name MEM_OPERATING_FREQ_MHZ]} {
            set emif_first [expr {$value <= $rate}]
        }
    }
    if {$emif_first} {
        set_emif_parameters
    }
}
foreach instance [get_instances] {
    validate_instance $instance
}
sync_sysinfo_parameters
if {$has_emif && !$emif_first} {
    set_emif_parameters
}
validate_system
save_system
