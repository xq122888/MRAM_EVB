#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src="$repo_dir/MR4A16B_TEST_0704_3_x16/MR4A16B_TEST_1/MR4A16B_TEST_1.srcs/sources_1/new"
iverilog_bin=${IVERILOG:-iverilog}
vvp_bin=${VVP:-vvp}
compiler_args=()
if [[ -n ${IVL_BASE:-} ]]; then compiler_args+=(-B "$IVL_BASE"); fi
output_dir=$(mktemp -d)
trap 'rm -rf -- "$output_dir"' EXIT
"$iverilog_bin" "${compiler_args[@]}" -g2012 -s tb_spi_port_repro \
  -o "$output_dir/repro.vvp" "$repo_dir/tests/tb_top_timing.sv" \
  "$repo_dir/tests/tb_spi_port_repro.sv" "$src/top.v" "$src/spi.v" "$src/SPI_Slave.v"
(cd "$output_dir" && timeout 120 "$vvp_bin" "$output_dir/repro.vvp" +with_random)
