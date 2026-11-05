#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
relative_src=MR4A16B_TEST_0704_3_x16/MR4A16B_TEST_1/MR4A16B_TEST_1.srcs/sources_1/new
src="$repo_dir/$relative_src"
iverilog_bin=${IVERILOG:-iverilog}
vvp_bin=${VVP:-vvp}
compiler_args=()
if [[ -n ${IVL_BASE:-} ]]; then compiler_args+=(-B "$IVL_BASE"); fi
output_dir=$(mktemp -d)
trap 'rm -rf -- "$output_dir"' EXIT
# First-cycle and restart pins intentionally differ from the old controller.
# Use the independent pin contract, not equivalence to the buggy old waveforms.
bash "$repo_dir/tests/run_mram_pins.sh"

"$iverilog_bin" "${compiler_args[@]}" -g2012 -s tb_top_predicates \
  -o "$output_dir/predicates.vvp" "$repo_dir/tests/tb_top_timing.sv" \
  "$src/top.v" "$src/spi.v" "$src/SPI_Slave.v"
timeout 60 "$vvp_bin" "$output_dir/predicates.vvp"

"$iverilog_bin" "${compiler_args[@]}" -g2012 -s tb_top_spi_reports \
  -o "$output_dir/end_to_end.vvp" "$repo_dir/tests/tb_top_timing.sv" \
  "$repo_dir/tests/tb_top_spi_reports.sv" "$src/top.v" "$src/spi.v" "$src/SPI_Slave.v"
timeout 120 "$vvp_bin" "$output_dir/end_to_end.vvp"
