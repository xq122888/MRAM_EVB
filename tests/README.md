# Current data patterns

The nine pattern IDs now follow [data-patterns-nine.md](data-patterns-nine.md),
based on 31100b0 with Read1 capture at 40 ns. Pattern 1/2 each use one fixed
background; each write/read loop retains one write pass and one read pass.
Patterns 7/8 roll the starting value by +1/-1 each round and replay the same
round during reads; new commands restart at 0000/FFFF.

# SPI report regression

Current detailed errors use a 4096-entry BRAM FIFO: logging never stalls an
active MRAM access, including on overflow. Total errors remain complete. ILA
and debug_hub have now been removed at the user's request; host loss accounting
uses the total minus the number of valid unique details. See
[detailed-error-log.md](detailed-error-log.md) for the unchanged wire format,
queue/round boundaries, and host-side loss reconciliation.

Current MRAM first-cycle/loop-restart pin fixes and their waveform contract are
documented in [mram-pin-timing.md](mram-pin-timing.md). Run
`bash tests/run_top_timing.sh` for independent pin checks, arithmetic boundaries
and end-to-end reports. The historical a317d2b state/pin equivalence bench has
been replaced because it preserved the old first-cycle bugs. References to that
bench/count below describe earlier commits, not current validation requirements.

The TRNG-seeded random-data repair and its digital replay regression are documented
in [random-pattern.md](random-pattern.md). Run `bash tests/run_random_pattern.sh`
and `bash tests/run_trng_seed.sh` for seed handling, conditioning and health checks.
The memory replay bench now covers lengths through 16385 words, all write/read
modes, all data patterns, and the reported 592-word/50 ns configuration. See
[length-boundary-diagnosis.md](length-boundary-diagnosis.md) for board evidence
and limits. `bash tests/run_random_pattern.sh +repro_only` runs just the six
592-word cases; `MRAM_TEST_SEED=c58ed660` selects the reconstructed log seed
in the digital fixture only.
Check the XDC command subset and absence of debug-core insertion with
`tclsh tests/check_xdc.tcl`; this is a smoke test, not a Vivado run.

The 25-byte detailed-error reporting feature and its build/board checks are
documented in [detailed-error-log.md](detailed-error-log.md). Run its additional
protocol and full-controller regression with `bash tests/run_spi_detail.sh`.

Run with Icarus Verilog 12 and `vvp` on PATH:

```sh
bash tests/run_spi_reports.sh
```

For the cloud environment's local tool installation:

```sh
IVERILOG=/workspace/.mram-tools/iverilog/usr/bin/iverilog \
VVP=/workspace/.mram-tools/iverilog/usr/bin/vvp \
IVL_BASE=/workspace/.mram-tools/iverilog/usr/lib/x86_64-linux-gnu/ivl \
bash tests/run_spi_reports.sh
```

The bench uses the actual `spi.v` selected by the Vivado XPR and `SPI_Slave.v`.
It sends configuration over MOSI, reads every MISO bit in mode 0, checks
502 consecutive loop numbers (499–1000), 11/17-byte reports, idle zero padding,
an aborted read followed by retry, and exactly one completion acknowledgment
per fully read frame. Failures use `$fatal`; a simulation watchdog and process
timeout catch hangs. No clock wizard or FPGA hardware model is substituted.
The 111 ns half-period approximates the saved host's 4.5 MHz configuration;
transaction phases drift relative to the 200 MHz processing clock.

## Trace diagnosis and limits

`release_20260703/release/config/protocol_trace_b.log` contains 500 decoded
11-byte reports, covering expected sequence 499–998. Count `report:frame`
only: `report:chunk` logs the same incoming bytes, not a second received frame.
Eighteen report sequence numbers deviate from the expected sequence, producing
36 anomalous adjacent differences. The sequence returns to its expected position
after each bad report; the trace alone does not demonstrate a queue reordering.
Examples (log line, expected, received):

| Line | Expected | Received |
| --- | --- | --- |
| 19 | 508 | 509 |
| 251 | 624 | 623 |
| 347 | 672 | 689 |
| 411 | 704 | 753 |
| 923 | 960 | 959 |

The raw chunk bytes already contain these values, so this is not merely a
mistake in the displayed decoded sequence. Host source is absent, so driver or
buffer handling cannot be excluded. There is no report checksum in this frame
format to distinguish corrupted data from valid sequence numbers.

The removed MISO mux selected between two registers with `spi_shift_en`, while
the select and register data changed together on a processing-clock edge. At
byte reloads the two sources can differ, creating an implementation-dependent
glitch risk. The shift register's MSB already represents the intended output;
using it directly removes that mux without changing the wire format or ACK.
The original RTL also passes the nominal digital regression at 5 MHz. Therefore
this change is a targeted timing-risk reduction, **not a reproduced or proven
fix for the hardware trace**. Ideal RTL simulation cannot validate routing delay,
metastability, cable ringing, or the CH347 sampling point.

Remaining board checks:

- Rebuild the actual XPR using Vivado 2018.3 and program the new bitstream;
  repository bitstreams are pre-existing and do not include this change.
- Capture CS, SCLK, MOSI and MISO at the CH347 end. Compare the wire bytes with
  `report:chunk`; verify mode 0, MSB first, CS setup/hold and MISO setup/hold.
- Compare error counts at a lower SPI rate and at the configured 4.5 MHz.
- Review external SPI timing/CDC in Vivado. The checked-in timing XDC does not
  specify external SPI input/output delays. Do not invent those numbers without
  the CH347 timing and board/cable delay budget.

Vivado timing analysis and physical capture were unavailable in the cloud run.

## Counter/control timing refactor

The hardware reports uploaded on November 3 show 353 failing setup endpoints
(WNS -1.831 ns, TNS -161.269 ns). This includes 31 loop-index bits (worst
-0.711 ns), loop completion/done controls, and a loop-index change-detection
path to data control (-0.875 ns in the focused report). The worst address-counter
path serializes compare/control and increment through 12 CARRY4 cells.
There are also ILA internal setup failures, and external SPI timing remains
unconstrained. These are implementation observations, not proof that any one
path explains all sequence-number errors.

`top.v` now:

- Produces the next-loop pulse in the same register update as the loop index,
  removing the 32-bit delayed-index XOR/reduction from downstream control.
  Reset clears this event; restart from a nonzero index still emits the event.
- Keeps increments independent of their enables, to discourage synthesis from
  serializing the decision and increment carry chains.
- Rewrites timing/address boundary comparisons with explicit operand widths and
  zero/one guards, and removes subtraction of loop_count before its comparison.

Run the current pin-contract and arithmetic boundary tests:

```sh
bash tests/run_top_timing.sh
```

Use the same IVERILOG/VVP/IVL_BASE environment variables as above for cloud tools.
The runner now checks external pins against an independent expected waveform,
854,920 arithmetic/compare cases (including all 65,536 timing-limit values and
32-bit loop boundaries), and 10 complete SPI reports. Full Git history is no
longer needed. Ideal clock/TRNG/read-bus models do not verify physical clock
generation, entropy, MRAM access delays, signal integrity, or timing closure.

Required implementation validation after pulling this change:

1. Reset the synthesis run and rerun synthesis and implementation in Vivado 2018.3.
2. Inspect the new setup/hold summaries and failing paths, including ILA paths.
   KEEP hints and algebraic refactoring do not guarantee a particular routed WNS.
3. Preserve the real 200 MHz clock constraints. Treat remaining negative slack
   as unresolved; do not mask it using false paths or an inaccurate clock period.
4. After timing closure, regenerate/program the bitstream and repeat the same
   SPI test. Recheck external SPI constraints and physical timing separately.

This cloud environment has no Vivado, so this refactor is a simulation-validated
candidate; post-refactor placement/routing and board behavior remain unverified.

### Follow-up to the f48311b implementation

The uploaded implementation report for f48311b improved WNS from -1.831 ns to
-1.083 ns and failing setup endpoints from 353 to 252, but did not meet timing.
The 20 worst paths now originate at t_avav_r and terminate at data/address
register enables. They still traverse a 16-bit subtract and equality chain.
The accompanying 500-report trace has 28 ordinal sequence mismatches, versus
50 in the preceding uploaded run. These small samples do not establish that
timing violations are the sole cause or that board behavior is fixed.

The follow-up splits the counter-plus-one/two calculations into independent
four-bit groups with carry lookahead taken directly from the current counter.
KEEP preserves those intermediate group nets. The configuration-to-enable path
then uses equality without a preceding variable subtract. Zero/one and upper
counter guards preserve the widened arithmetic, including all overflow cases.
The cycle/boundary regression above also covers this follow-up. Placement/routing
must still establish whether the new logic meets 200 MHz; ILA and external timing
checks remain required.

To collect the summary, up to 1000 setup failures and focused loop-index paths
in a single file, open the new implemented design and run in Vivado Tcl Console:

```tcl
source E:/workspace/xilinx_workspace/MRAM_EVB_spi_fix/tests/collect_spi_timing.tcl
```

It prints the absolute path of a `timing_bundle_YYYYMMDD_HHMMSS.rpt` file in the
repository root. Upload that one file. The collector changes no constraints and
does not run synthesis, implementation, or bitstream generation. The collector
requires Vivado; it has not been executed in Vivado in the cloud environment.

### Follow-up to the 36fa661 implementation

The next hardware timing bundle shows further improvement: WNS -0.583 ns,
TNS -38.242 ns, 129 failing setup endpoints and WHS +0.019 ns. Timing still
fails. Of those 129, 7 are internal ILA endpoints; most remaining functional
failures are loop-index feedback, address enables, terminal address detection
and counter/data controls. The new worst loop-index path traverses the serial
32-bit increment before its completion comparison (7 CARRY4 cells). The worst
address-enable path is dominated by routing (3.366 ns of 5.290 ns data delay).

The next candidate partitions the loop/address increments into four-bit groups
with independent carry lookahead, and replaces terminal-address subtraction
with a comparison of the grouped increment. Period comparisons precompute both
carry choices in each group; a low-group carry selects a match bit rather than
feeding an upper-group adder followed by equality. The same cycle comparison and
full-width boundary tests validate these expressions; the predicate test now
also checks the increment results directly.

For the next implementation, select the Vivado 2018.3 `Performance_Explore`
implementation strategy to enable its timing-oriented implementation/physical
optimization flow. In Tcl, before rerunning implementation:

```tcl
set_property strategy Performance_Explore [get_runs impl_2]
```

Then reset/rerun synthesis and implementation and collect the timing bundle as
above. This changes implementation choices, not clock periods or timing
exceptions. The strategy has not been run in the cloud; only the local Vivado
result can demonstrate timing closure. Any remaining ILA, functional, hold or
external timing issues still require review before claiming the design works.

The accompanying 36fa661 board trace contains 55 sequence mismatches in 500
frames: 48 are one behind, 6 are two behind, and one is 14 ahead. Raw chunks
and parsed frames agree. This does not demonstrate communication recovery;
sequence errors must be checked separately from timing-summary improvement.

A separate code review found uncontained asynchronous input usage:

- spi.v formed internal CS edge pulses directly from the asynchronous CS port
  and a single delayed register. CS now passes two ASYNC_REG stages before
  internal edge detection and frame-buffer control.
- SPI_Slave.v formed SCLK/CS edges using the first synchronizer stage and used
  raw CS to gate receive/shift state. Edge detectors now compare the second
  stage to a delayed copy; synchronous state uses the second-stage CS only.
- MOSI is synchronized before capture. Raw CS remains only on external MISO
  output gating; it does not qualify internal state updates.

The regression sweeps SPI half-periods 100–111 ns (5 MHz to approximately
4.5 MHz) with drifting phase against the 200 MHz processing clock. This change
adds synchronization latency. It does not establish support for every selectable
SPI frequency or mode, and RTL simulation cannot reproduce analog metastability.
The frame wire format and MRAM clock period remain unchanged. The timing-bundle
collector now also includes report_cdc -details for implementation review;
CDC reports alone do not establish external setup/hold margins for unclocked
input ports. Verify actual physical margins and observed SPI bytes on hardware.

### Predecode configuration terminal values

After reloading the implementation for 4820850, the report shows WNS -1.032 ns,
TNS -67.776 ns and 189 failing endpoints. This corrects the earlier stale
checkpoint report, which repeated the 36fa661 paths exactly. The corresponding
uploaded SPI trace has 500 consecutive ordinal reports with zero mismatches;
that sample does not establish timing closure or long-run reliability.

The grouped lookahead implementation increased routed delay on counter
feedback. The next revision replaces those groups with native data increments
and moves terminal-value subtraction into the configuration decoder:

- last_loop_index = loop_count - 1 (32-bit unsigned, including zero count).
- last_test_address = low 21 bits of test_length - 1. The existing 21-bit
  address-count truncation and its zero-length guard are preserved.
- Read/write period-minus-one/two values, including the existing 10-cycle
  fallback for write_mode 3 and explicit zero/one guards in top.v.

Base and decoded parameters are committed atomically. A registered configuration
write enable separates checksum/state decoding from the high-fanout parameter
register enables; it commits one processing-clock cycle later than before,
well before the following frame-tail byte can assert start_test. SPI input
synchronization and registered next-loop signaling from 4820850 are retained.
No runtime test step or MRAM clock period is added or changed.

run_top_timing.sh still compares against the original controller over 617,129
cycles and checks 342,144 boundary cases. Its abstract configuration fixtures now
supply coherent base/decoded values. run_spi_reports.sh independently exercises
the REAL serial configuration decoder: 518 report polls plus 11 configuration
checks, all write modes including fallback, period values 0/1/2/255, 32-bit loop
limits, address truncation boundaries, per-clock atomicity, start-after-commit,
and rejection of a bad checksum. Only these functional results are cloud-
validated; the new implementation must still demonstrate routed timing closure.

The report collector now includes checkout HEAD, project/source paths, run
status/strategy and a loaded-design register signature. Before collecting a new
implementation result, explicitly reload it to avoid a cached open design:

```tcl
close_design
open_run impl_2
source E:/workspace/xilinx_workspace/MRAM_EVB_spi_fix/tests/collect_spi_timing.tcl
```

Run metadata is diagnostic evidence, not proof of which bitstream was programmed.
Keep a copy of the programmed bitstream and associated reports when comparing
board results. Review CDC/reset and external input/output timing separately.

The controller runner also executes tb_top_spi_reports.sv: 10 end-to-end reports
across write/read/write-read modes using actual top.v SPI configuration, decoded
threshold connections, test-start, completion, and ACK-driven loop advancement.
This test does not force configuration/threshold wires. It uses the documented
ideal clock/TRNG fixtures and constant-zero read bus, so it validates digital
protocol/control integration rather than physical MRAM behavior.

### Remaining four paths after implementation optimization

For ec9263e with Performance_Explore, routed timing improved to WNS -0.060 ns,
TNS -0.108 ns and four failing setup endpoints, with WHS +0.005 ns. The focused
loop-index paths now meet timing (worst reported +0.953 ns). Changing to
Performance_ExplorePostRoutePhysOpt improved WNS to -0.044 ns but retained four
failures (GN control plus three address-counter bits). The following Aggressive-
Explore timing bundle has identical timing bodies, so it shows no further gain;
it does not distinguish a no-change optimization from reloading the old design.

The next source change targets those remaining comparisons:

- The GN release offset is computed during configuration commit. Read and write
  values preserve the same rd_en_d2 bank selection used for BOTH operands in
  the original release expression. GH2GL assertion still uses rd_en_d, unchanged.
  The original
  expression `addr_hold_cnt == t_AVAV - t_GL2GH` evaluates the subtraction
  at the 21-bit comparison width. The decoder preserves that exact underflow
  behavior; replacing it with a 16- or 32-bit subtraction would not be equivalent.
- Terminal-address equality is divided into kept three-bit comparisons and two
  small reduction groups. This aims to avoid a wide equality carry reduction
  on the shared counter update-enable path without changing its logic.

The predicate regression now covers 342,248 cases, including randomized GL2GH
inputs, all four delayed read-enable combinations, explicit 21-bit underflow matches, and adjacent
nonmatches. Per-clock decoder assertions check both GN offsets against the
committed base registers. Serial tests exercise all read/write mode values,
including invalid-write fallback, zero/one timing boundaries, and checksum rejection.
The full cycle comparison and end-to-end SPI/controller tests remain required.
These are functional guarantees only; routed setup/hold and physical SPI timing
must still be checked after rebuilding the implementation.

### Last bank-selection-to-enable path

The e5ef9ea implementation removes the GN and terminal-address failures. The
uploaded report confirms the intended source/strategy and shows WNS -0.011 ns,
TNS -0.011 ns, one failing setup endpoint (rd_en_d2 replica to dout[13]/CE),
and WHS +0.032 ns with no hold violations. Loop-index paths meet timing.

The next candidate computes the write/read period-boundary comparisons in
parallel, then selects their one-bit results. Kept intermediate results prevent
folding the operation back into a wide bank mux followed by equality. This aims
to shorten the remaining selector-to-enable path without adding a cycle or
changing frame/MRAM timing. The base periods, decoded limits and zero/one guards
remain coherent per bank.

The predicate suite now checks 354,536 cases, including unequal read/write
periods, both selector values, 0/1 and 16-bit-wrap guard cases, and GN underflow.
The 10-report end-to-end test additionally uses write-mode-3 fallback (10 cycles)
with a configured 7-cycle read period in write/read mode, so actual top-level
bank switching is tested without forced configuration signals. The other full
cycle, serial and configuration-atomicity regressions still pass. Only a new
Vivado implementation can establish whether setup/hold now meet timing.
