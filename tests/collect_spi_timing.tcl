# Run after Open Implemented Design in Vivado 2018.3.
# Generates a single uploadable bundle; does not change constraints or the design.
proc mram_collect_spi_timing {repo_root} {
    set loop_regs [get_cells -quiet -hierarchical -filter {NAME =~ *loop_idx_reg*}]
    if {[llength $loop_regs] == 0} {
        error "No loop_idx registers found. Open the implemented top design first."
    }
    set stamp [clock format [clock seconds] -format %Y%m%d_%H%M%S]
    set report_dir [file join $repo_root timing_reports $stamp]
    file mkdir $report_dir
    set metadata_path [file join $report_dir build_metadata.txt]
    set metadata [open $metadata_path w]
    if {[catch {exec git -C $repo_root rev-parse HEAD} checkout_head]} {
        set checkout_head "unavailable (Git not callable from Vivado)"
    }
    puts $metadata "Checkout HEAD: $checkout_head"
    puts $metadata "Project directory: [get_property DIRECTORY [current_project]]"
    puts $metadata "Top sources: [get_files -quiet -all *top.v]"
    foreach run_name {synth_2 impl_2} {
        set run [get_runs -quiet $run_name]
        if {[llength $run] != 0} {
            puts $metadata "$run_name status: [get_property STATUS $run]"
            puts $metadata "$run_name strategy: [get_property STRATEGY $run]"
        }
    }
    puts $metadata "Decoded loop-limit registers in loaded design: [llength [get_cells -quiet -hierarchical -filter {NAME =~ *last_loop_index_reg*}]]"
    puts $metadata "Note: checkout/run metadata does not prove the currently loaded checkpoint is fresh."
    close $metadata
    set summary_path [file join $report_dir summary.rpt]
    set failures_path [file join $report_dir failures.rpt]
    set loops_path [file join $report_dir loop_idx.rpt]
    set cdc_path [file join $report_dir cdc.rpt]
    report_timing_summary -delay_type min_max -report_unconstrained -max_paths 20 -file $summary_path
    report_timing -delay_type max -slack_lesser_than 0 -max_paths 1000 -file $failures_path
    report_timing -from $loop_regs -delay_type max -max_paths 100 -file $loops_path
    if {[catch {report_cdc -details -file $cdc_path} cdc_error]} {
        set failed_report [open $cdc_path w]
        puts $failed_report "CDC report generation failed: $cdc_error"
        close $failed_report
        puts "WARNING: CDC reporting failed; see the bundle. CDC is not validated."
    }
    set bundle_path [file join $repo_root timing_bundle_${stamp}.rpt]
    set bundle [open $bundle_path w]
    foreach path [list $metadata_path $summary_path $failures_path $loops_path $cdc_path] {
        puts $bundle "\n===== [file tail $path] =====\n"
        set input_report [open $path r]
        puts $bundle [read $input_report]
        close $input_report
    }
    close $bundle
    puts "Upload this file: [file nativename $bundle_path]"
    puts "Report exists: [file exists $bundle_path]"
}
mram_collect_spi_timing [file dirname [file dirname [file normalize [info script]]]]
