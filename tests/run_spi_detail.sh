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
for bench in tb_detail_fifo tb_detail_fifo_capacity; do
  "$iverilog_bin" "${compiler_args[@]}" -g2012 -s "$bench" \
    -o "$output_dir/$bench.vvp" "$repo_dir/tests/tb_detail_fifo.sv" "$src/spi.v"
  timeout 30 "$vvp_bin" "$output_dir/$bench.vvp"
done

"$iverilog_bin" "${compiler_args[@]}" -g2012 -s tb_spi_detail \
  -o "$output_dir/detail.vvp" "$repo_dir/tests/tb_spi_detail.sv" \
  "$src/spi.v" "$src/SPI_Slave.v"
timeout 180 "$vvp_bin" "$output_dir/detail.vvp"

"$iverilog_bin" "${compiler_args[@]}" -g2012 -s tb_top_detail \
  -o "$output_dir/top_detail.vvp" "$repo_dir/tests/tb_top_timing.sv" \
  "$repo_dir/tests/tb_top_detail.sv" "$src/top.v" "$src/spi.v" "$src/SPI_Slave.v"
timeout 180 "$vvp_bin" "$output_dir/top_detail.vvp"
