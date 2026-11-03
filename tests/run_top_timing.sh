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
# Compare against the actual pre-refactor RTL, not a rewritten reference model.
git -C "$repo_dir" show "a317d2b:$relative_src/top.v" > "$output_dir/top_reference.v"
python - "$output_dir/top_reference.v" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
b = p.read_bytes()
assert b.count(b'module top(') == 1
p.write_bytes(b.replace(b'module top(', b'module top_reference('))
PY
"$iverilog_bin" "${compiler_args[@]}" -g2012 -s tb_top_timing \
  -o "$output_dir/top.vvp" "$repo_dir/tests/tb_top_timing.sv" \
  "$src/top.v" "$output_dir/top_reference.v" "$src/spi.v" "$src/SPI_Slave.v"
timeout 180 "$vvp_bin" "$output_dir/top.vvp"

"$iverilog_bin" "${compiler_args[@]}" -g2012 -s tb_top_predicates \
  -o "$output_dir/predicates.vvp" "$repo_dir/tests/tb_top_timing.sv" \
  "$src/top.v" "$src/spi.v" "$src/SPI_Slave.v"
timeout 60 "$vvp_bin" "$output_dir/predicates.vvp"
