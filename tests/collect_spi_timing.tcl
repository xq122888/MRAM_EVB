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
    puts $metadata "Detailed FIFO head-valid registers: [llength [get_cells -quiet -hierarchical -filter {NAME =~ *u_detail_fifo/head_valid_reg}]]"
    puts $metadata "Detailed FIFO occupancy registers (default 13): [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && NAME =~ *u_detail_fifo/fifo_count_reg*}]]"
    set detail_rams [get_cells -quiet -hierarchical -filter {REF_NAME =~ RAMB* && NAME =~ *u_detail_fifo*}]
    puts $metadata "Detailed FIFO inferred block RAMs: [llength $detail_rams]"
    foreach detail_ram $detail_rams {
        puts $metadata "DETAIL_FIFO_RAM $detail_ram REF=[get_property REF_NAME $detail_ram] LOC=[get_property LOC $detail_ram]"
    }
    puts $metadata "Detailed FIFO loss-counter registers: [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && NAME =~ *u_detail_fifo/dropped_count_reg*}]]"
    puts $metadata "Predecoded error compare registers in loaded design: [llength [get_cells -quiet -hierarchical -filter {NAME =~ *compare_early_*reg*}]]"
    puts $metadata "Local period-counter replica registers in loaded design: [llength [get_cells -quiet -hierarchical -filter {NAME =~ *hold_release_count_reg* || NAME =~ *hold_sample_count_reg*}]]"
    puts $metadata "Local address-comparison replica registers in loaded design: [llength [get_cells -quiet -hierarchical -filter {NAME =~ *addr_compare_count_reg*}]]"
    puts $metadata "Unified MRAM IO cycle-origin nets in loaded design: [llength [get_nets -quiet -hierarchical -filter {NAME =~ *io_cycle_start}]]"
    # Exclude combinational *_reg[...]_i_* cells (two CARRY4s were counted as
    # registers in the 16:45 bundle). Count only actual FD* flip-flops.
    set mram_io_regs [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && (NAME =~ *addr_d_reg* || NAME =~ *R_EN_reg || NAME =~ *R_WN_reg || NAME =~ *R_GN_reg || NAME =~ *R_UBN_reg || NAME =~ *R_LBN_reg || NAME =~ *dq_write_data_reg* || NAME =~ *dq_read_data_reg* || NAME =~ *dq_tristate_reg*)}]
    puts $metadata "MRAM IOB register candidates (expected 75): [llength $mram_io_regs]"
    puts $metadata "Registered output-command FFs (expected 44): [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && NAME =~ *pad_cmd*reg*}]]"
    puts $metadata "Registered period-event FFs: [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && NAME =~ *period_event_reg*}]]"
    puts $metadata "Predicted P-1/P-2 event FFs: [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && (NAME =~ *before_one_event_reg* || NAME =~ *before_two_event_reg*)}]]"
    puts $metadata "Registered effective count-bound FFs: [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && (NAME =~ *engine_count_limit_reg* || NAME =~ *engine_last_address_reg*)}]]"
    puts $metadata "Registered one-hot data-select FFs: [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && NAME =~ *data_select_reg*}]]"
    puts $metadata "Multi-pass/March algorithm FFs: [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && NAME =~ *u_algorithm/*}]]"
    puts $metadata "Algorithm phase FFs: [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && NAME =~ *u_algorithm/phase_reg*}]]"
    puts $metadata "ILA/debug-hub cells (expected 0): [llength [get_cells -quiet -hierarchical -filter {NAME =~ u_ila_0 || NAME =~ u_ila_0/* || NAME =~ dbg_hub || NAME =~ dbg_hub/*}]]"
    puts $metadata "Inspect LOC/BEL below; IOB=TRUE alone does not prove packing."
    set placed_in_io 0
    set placed_in_slice 0
    foreach io_reg $mram_io_regs {
        set io_location [get_property LOC $io_reg]
        if {[regexp {^(ILOGIC|OLOGIC|IOB)_} $io_location]} {incr placed_in_io}
        if {[string match SLICE_* $io_location]} {incr placed_in_slice}
        puts $metadata "MRAM_IOB $io_reg REF=[get_property REF_NAME $io_reg] IOB=[get_property IOB $io_reg] LOC=$io_location BEL=[get_property BEL $io_reg]"
        set q_pins [get_pins -quiet -of_objects $io_reg -filter {REF_PIN_NAME == Q}]
        set q_loads unavailable
        if {[llength $q_pins] != 0} {
            set q_nets [get_nets -quiet -of_objects $q_pins]
            if {[llength $q_nets] != 0} {
                set q_loads [get_pins -quiet -of_objects $q_nets -filter {DIRECTION == IN}]
            }
        }
        puts $metadata "MRAM_IOB_Q_LOADS $io_reg $q_loads"
    }
    puts $metadata "MRAM registers placed in IO logic: $placed_in_io/[llength $mram_io_regs]; placed in SLICE: $placed_in_slice"
    # Carry the packing diagnostics with the bundle instead of requesting a
    # separate build log when a register still cannot pack in an IOB.
    foreach run_name {synth_2 impl_2} {
        set run [get_runs -quiet $run_name]
        if {[llength $run] == 0} {continue}
        set run_log [file join [get_property DIRECTORY $run] runme.log]
        if {![file exists $run_log]} {continue}
        puts $metadata "IO packing diagnostics from $run_log (up to 200 matching lines):"
        set run_input [open $run_log r]
        set matches 0
        while {[gets $run_input log_line] >= 0} {
            if {[regexp -nocase {IOB|IOLOGIC|pack.*reg|reg.*pack|cannot.*pack|prevent.*pack} $log_line]} {
                puts $metadata $log_line
                incr matches
                if {$matches >= 200} {break}
            }
        }
        close $run_input
    }
    puts $metadata "Qualified DQ capture comparison-stage registers: [llength [get_cells -quiet -hierarchical -filter {NAME =~ *read_compare_valid_reg}]]"
    puts $metadata "Pipelined mismatch-valid FFs: [llength [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && NAME =~ *compare_valid_d_reg}]]"
    puts $metadata "Latched TRNG test-seed registers: [llength [get_cells -quiet -hierarchical -filter {NAME =~ *random_test_seed_reg*}]]"
    puts $metadata "Physical RO loop nets matched: [llength [get_nets -quiet -hierarchical -filter {NAME =~ *u_seed_rng/u_entropy/ro_bank*/ring*}]]"
    set ro_nets [get_nets -quiet -hierarchical -filter {NAME =~ *u_seed_rng/u_entropy/ro_bank*/ring*}]
    set ro_acknowledged 0
    foreach ro_net $ro_nets {
        set ro_permission [get_property ALLOW_COMBINATORIAL_LOOPS $ro_net]
        if {$ro_permission eq "1" || [string equal -nocase $ro_permission true]} {
            incr ro_acknowledged
        }
    }
    puts $metadata "Physical RO loop nets acknowledged: $ro_acknowledged/[llength $ro_nets]"
    puts $metadata "Entropy first-stage D pins matched: [llength [get_pins -quiet -hierarchical -filter {NAME =~ *u_seed_rng/u_entropy/ro_meta_reg*/D}]]"
    puts $metadata "Note: checkout/run metadata does not prove the currently loaded checkpoint is fresh."
    close $metadata
    set summary_path [file join $report_dir summary.rpt]
    set failures_path [file join $report_dir failures.rpt]
    set loops_path [file join $report_dir loop_idx.rpt]
    set address_path [file join $report_dir address_count.rpt]
    set cdc_path [file join $report_dir cdc.rpt]
    set ro_drc_path [file join $report_dir ro_drc.rpt]
    set utilization_path [file join $report_dir utilization.rpt]
    report_timing_summary -delay_type min_max -report_unconstrained -max_paths 20 -file $summary_path
    report_timing -delay_type max -slack_lesser_than 0 -max_paths 1000 -file $failures_path
    report_timing -from $loop_regs -delay_type max -max_paths 100 -file $loops_path
    # A length-dependent board failure can expose a carry/address path even
    # when it is absent from the globally worst 1000 paths. Include positive
    # slack here too; this report is diagnostic and changes no constraints.
    set address_regs [get_cells -quiet -hierarchical -filter {REF_NAME =~ FD* && (NAME =~ *addr_cnt_reg* || NAME =~ *addr_compare_count_reg* || NAME =~ *addr_reg* || NAME =~ *pad_cmd_addr_reg* || NAME =~ *u_algorithm/operation_address_reg* || NAME =~ *u_algorithm/word_index_reg*)}]
    if {[llength $address_regs] != 0} {
        report_timing -from $address_regs -delay_type max -max_paths 100 -file $address_path
    } else {
        set address_report [open $address_path w]
        puts $address_report "No address/count FFs found in the loaded design. Address timing is not validated."
        close $address_report
    }
    if {[catch {report_cdc -details -file $cdc_path} cdc_error]} {
        set failed_report [open $cdc_path w]
        puts $failed_report "CDC report generation failed: $cdc_error"
        close $failed_report
        puts "WARNING: CDC reporting failed; see the bundle. CDC is not validated."
    }
    if {[catch {report_drc -checks [get_drc_checks LUTLP-1] -file $ro_drc_path} ro_drc_error]} {
        set failed_report [open $ro_drc_path w]
        puts $failed_report "RO loop DRC report generation failed: $ro_drc_error"
        close $failed_report
        puts "WARNING: RO loop DRC is not validated; see the bundle."
    }
    if {[catch {report_utilization -file $utilization_path} utilization_error]} {
        set failed_report [open $utilization_path w]
        puts $failed_report "Resource report generation failed: $utilization_error"
        close $failed_report
    }
    set bundle_path [file join $repo_root timing_bundle_${stamp}.rpt]
    set bundle [open $bundle_path w]
    foreach path [list $metadata_path $summary_path $failures_path $loops_path $address_path $cdc_path $ro_drc_path $utilization_path] {
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
