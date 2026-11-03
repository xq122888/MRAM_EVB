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
    set summary_path [file join $report_dir summary.rpt]
    set failures_path [file join $report_dir failures.rpt]
    set loops_path [file join $report_dir loop_idx.rpt]
    report_timing_summary -delay_type min_max -report_unconstrained -max_paths 20 -file $summary_path
    report_timing -delay_type max -slack_lesser_than 0 -max_paths 1000 -file $failures_path
    report_timing -from $loop_regs -delay_type max -max_paths 100 -file $loops_path
    set bundle_path [file join $repo_root timing_bundle_${stamp}.rpt]
    set bundle [open $bundle_path w]
    foreach path [list $summary_path $failures_path $loops_path] {
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
