# Vivado 2018.3: Open Implemented Design for the SAME run as the programmed bit,
# then source this file. Exports the loaded netlist and adds a separate simset.
# Does not edit hardware RTL, constraints or launch synthesis/implementation.
proc mram_repro_post_impl {repo_root} {
    if {[catch {current_design} design] || $design eq ""} {
        error "Open Implemented Design for the programmed bit before sourcing this script."
    }
    set bench_path [file join $repo_root tests tb_spi_port_repro.sv]
    if {![file exists $bench_path]} {error "Missing port-only bench: $bench_path"}
    set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
    set output_dir [file join $repo_root port_repro_$stamp]
    file mkdir $output_dir
    set netlist_path [file join $output_dir top_funcsim.v]
    # Export first: the file is useful even if the local simulator cannot launch.
    write_verilog -force -mode funcsim $netlist_path
    report_timing_summary -delay_type min_max -report_unconstrained -max_paths 10 -file [file join $output_dir summary.rpt]
    report_io -file [file join $output_dir io.rpt]
    set metadata [open [file join $output_dir metadata.txt] w]
    puts $metadata "Loaded design: $design"
    puts $metadata "Project: [get_property DIRECTORY [current_project]]"
    puts $metadata "Active implementation: [current_run -implementation]"
    puts $metadata "Top sources: [get_files -quiet -all *top.v]"
    if {![catch {exec git -C $repo_root rev-parse HEAD} head]} {
        puts $metadata "Checkout HEAD: $head (does not prove checkpoint freshness)"
    }
    puts $metadata "Mismatch-pipeline FFs: [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && NAME =~ *compare_valid_d_reg}]]"
    puts $metadata "Effective-count FFs: [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && NAME =~ *engine_count_limit_reg*}]]"
    close $metadata
    puts "Exported implemented netlist: [file nativename $netlist_path]"
    puts "Diagnostics folder: [file nativename $output_dir]"

    set sim_name spi_port_repro
    if {[llength [get_filesets -quiet $sim_name]]==0} {create_fileset -simset $sim_name}
    set simset [get_filesets $sim_name]
    set_property SOURCE_SET sources_1 $simset
    add_files -fileset $sim_name -norecurse $bench_path
    set_property TOP tb_spi_port_repro $simset
    set_property TOP_LIB xil_defaultlib $simset
    set_property xsim.simulate.runtime all $simset
    update_compile_order -fileset $sim_name
    puts "Running port-only post-implementation functional simulation (patterns 1-8)."
    puts "Configurations: N=4 CEN/Read1 and N=2 WEN/Read2, both at 50 ns."
    puts "Expected: two complete write/read pairs for patterns 1/2; one pair for patterns 3-8; 60 writes and 16 summaries total."
    # Production RO entropy cannot be validated in functional simulation.
    # Pattern 9 is exercised by the cloud RTL runner with its labelled seed fixture.
    launch_simulation -simset $sim_name -mode post-implementation -type functional
    puts "Inspect PASS/FATAL in the XSim log, plus spi_port_repro_pins.csv in its working directory."
}
mram_repro_post_impl [file dirname [file dirname [file normalize [info script]]]]
