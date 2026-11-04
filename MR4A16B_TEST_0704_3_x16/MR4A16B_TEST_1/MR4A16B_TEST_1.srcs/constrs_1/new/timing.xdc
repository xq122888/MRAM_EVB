create_clock -period 5.000 -name clk200m -waveform {0.000 2.500} -add [get_pins u_clk_wiz_0/clk_200m]
#create_clock -period 2.500 -name clk400m -waveform {0.000 1.250} -add [get_pins u_clk_wiz_0/clk_400m]

#set_false_path -from [get_clocks clk200m] -to [get_clocks clk400m]

#set_max_delay -from [get_clocks clk400m] -to [get_clocks clk400m] 4.606

#create_pblock pblock_ila_core_inst
#resize_pblock [get_pblocks pblock_ila_core_inst] -add {SLICE_X0Y218:SLICE_X9Y248}
#resize_pblock [get_pblocks pblock_ila_core_inst] -add {RAMB18_X0Y88:RAMB18_X0Y97}
#resize_pblock [get_pblocks pblock_ila_core_inst] -add {RAMB36_X0Y44:RAMB36_X0Y48}

# Random test words use a synchronous PRNG, seeded from the physical entropy source.

# Only the intentional physical RO loops are permitted. All entropy processing,
# seed storage and PRNG logic retain normal clk200m setup/hold analysis.
set seed_ro_nets [get_nets -quiet -hierarchical -filter {NAME =~ *u_seed_rng/u_entropy/ro_bank*/ring*}]
if {[llength $seed_ro_nets] != 0} {
    set_property ALLOW_COMBINATORIAL_LOOPS true $seed_ro_nets
}
# Asynchronous physical entropy enters only the first synchronizer stage.
set seed_meta_pins [get_pins -quiet -hierarchical -filter {NAME =~ *u_seed_rng/u_entropy/ro_meta_reg*/D}]
if {[llength $seed_meta_pins] != 0} {
    set_false_path -to $seed_meta_pins
}
