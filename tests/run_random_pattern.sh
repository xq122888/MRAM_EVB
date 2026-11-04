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
python - "$output_dir/vectors.hex" <<'PY'
from pathlib import Path
import sys
state = 0x6d2b79f5
values = []
for _ in range(512):
    values.append(f"{state:08x}\n")
    state ^= (state << 13) & 0xffffffff
    state ^= state >> 17
    state ^= (state << 5) & 0xffffffff
Path(sys.argv[1]).write_text("".join(values))
PY
"$iverilog_bin" "${compiler_args[@]}" -g2012 -s tb_random_pattern \
  -o "$output_dir/random.vvp" "$repo_dir/tests/tb_top_timing.sv" \
  "$repo_dir/tests/tb_random_pattern.sv" "$src/top.v" "$src/spi.v" "$src/SPI_Slave.v"
timeout 120 "$vvp_bin" "$output_dir/random.vvp" +vectors="$output_dir/vectors.hex"
