# Restricted-command smoke test for the checked-in XDC. This models object
# selection / ILA construction, not Vivado synthesis, routing, or net naming.
set repo_root [file dirname [file dirname [file normalize [info script]]]]
set constr_dir [file join $repo_root MR4A16B_TEST_0704_3_x16 MR4A16B_TEST_1 MR4A16B_TEST_1.srcs constrs_1 new]
set cores [dict create]
set ports [dict create]
set connections [dict create]
set ring_objects {}
for {set bank 0} {$bank < 5} {incr bank} {
    for {set stage 0} {$stage < 5+2*$bank} {incr stage} {
        lappend ring_objects [format {u_seed_rng/u_entropy/ro_bank[%d].u_ring/ring[%d]} $bank $stage]
    }
}
set meta_objects {}
for {set bit 0} {$bit < 5} {incr bit} {
    lappend meta_objects [format {u_seed_rng/u_entropy/ro_meta_reg[%d]/D} $bit]
}
set loop_count 0
set meta_count 0
set hub_frequency 0

proc select_filter {args candidates} {
    set index [lsearch -exact $args -filter]
    if {$index < 0} {error "Expected an explicit NAME filter"}
    set filter [lindex $args [expr {$index+1}]]
    if {![regexp {^NAME =~ (.+)$} $filter -> pattern]} {error "Unexpected filter: $filter"}
    set found {}
    foreach candidate $candidates {
        if {[string match $pattern $candidate]} {lappend found $candidate}
    }
    return $found
}
proc mock_get_nets {args} {
    global ring_objects
    if {[lsearch -exact $args -filter] >= 0} {
        return [select_filter $args [concat $ring_objects {other_logic/ring[0]}]]
    }
    if {[llength $args] != 1} {error "Unexpected get_nets arguments: $args"}
    set nets [lindex $args 0]
    foreach net $nets {
        if {[string match *u_uart_protocol* $net]} {error "Stale UART debug net: $net"}
    }
    return $nets
}
proc mock_get_pins {args} {
    global meta_objects
    if {[lsearch -exact $args -filter] >= 0} {
        return [select_filter $args [concat $meta_objects {u_seed_rng/u_entropy/ro_sync_reg[0]/D} {other_logic/ro_meta_reg[0]/D}]]
    }
    return [lindex $args end]
}
proc mock_create_clock {args} {
    if {[lindex $args [expr {[lsearch -exact $args -period]+1}]] != 5.000} {
        error "The 200 MHz clock constraint changed"
    }
}
proc mock_create_debug_core {name type} {
    global cores ports
    if {[dict exists $cores $name]} {error "Duplicate core creation: $name"}
    dict set cores $name 1
    dict set cores dbg_hub 1
    dict set ports $name/clk 1
    dict set ports $name/probe0 0
    dict set ports dbg_hub/clk 1
}
proc mock_get_debug_cores {name} {
    global cores
    if {![dict exists $cores $name]} {error "Debug core referenced before creation: $name"}
    return $name
}
proc mock_get_debug_ports {name} {
    global ports
    if {![dict exists $ports $name]} {error "Debug port referenced before creation: $name"}
    return $name
}
proc mock_create_debug_port {core type} {
    global ports
    mock_get_debug_cores $core
    set index [llength [dict keys $ports $core/probe*]]
    dict set ports $core/probe$index 0
}
proc mock_set_property {property value objects} {
    global ports loop_count ring_objects hub_frequency
    if {$property eq "ALLOW_COMBINATORIAL_LOOPS"} {
        if {$value ne "TRUE" || [lsort $objects] ne [lsort $ring_objects]} {
            error "RO permission must cover exactly the 45 intentional ring nets"
        }
        set loop_count [llength $objects]
    } elseif {$property eq "port_width"} {
        mock_get_debug_ports $objects
        dict set ports $objects $value
    } elseif {$property eq "C_CLK_INPUT_FREQ_HZ"} {
        if {$objects ne "dbg_hub" || $value != 200000000} {error "Incorrect debug clock frequency"}
        set hub_frequency $value
    }
}
proc mock_set_false_path {args} {
    global meta_objects meta_count
    if {[llength $args] != 2 || [lindex $args 0] ne "-to" ||
        [lsort [lindex $args 1]] ne [lsort $meta_objects]} {
        error "Entropy exception must target only the five first-stage D pins"
    }
    set meta_count [llength [lindex $args 1]]
}
proc mock_connect_debug_port {port nets} {
    global ports connections
    mock_get_debug_ports $port
    if {[dict exists $connections $port]} {error "Duplicate probe connection: $port"}
    if {[llength $nets] != [dict get $ports $port]} {error "Probe width mismatch: $port"}
    dict set connections $port $nets
}

# Make control flow, variables and arbitrary Tcl unavailable to the XDC.
# The mock Vivado commands run in this parent interpreter.
interp create xdc
set native_commands [interp eval xdc {info commands}]
foreach command $native_commands {
    if {$command ne "list"} {interp hide xdc $command}
}
foreach command {get_nets get_pins create_clock create_debug_core get_debug_cores get_debug_ports create_debug_port set_property set_false_path connect_debug_port} {
    interp alias xdc $command {} mock_$command
}
foreach filename {timing.xdc debug.xdc} {
    interp invokehidden xdc source [file join $constr_dir $filename]
}
if {$loop_count != 45 || $meta_count != 5 || $hub_frequency != 200000000 ||
    [llength [dict keys $ports u_ila_0/probe*]] != 32} {
    error "Incomplete timing/debug configuration"
}
if {[lindex [dict get $connections u_ila_0/probe1] 0] ne {dq_read_data[0]} || [lindex [dict get $connections u_ila_0/probe1] 15] ne {dq_read_data[15]}} {
    error "DQ probe must observe the IOB input-register data"
}
if {[dict get $connections u_ila_0/probe18] ne "spi_miso_OBUF"} {
    error "MISO probe must observe the actual protocol output"
}
puts "PASS: restricted XDC commands; 45 RO nets, 5 first-stage D pins, 32 ordered ILA probes and 200 MHz debug clock"
