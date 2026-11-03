# SPI report regression

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

Run the cycle comparison and arithmetic boundary tests:

```sh
bash tests/run_top_timing.sh
```

Use the same IVERILOG/VVP/IVL_BASE environment variables as above for cloud tools.
The runner reads pre-refactor `top.v` from Git commit a317d2b; history containing
that commit and Python 3 are required. It compares actual RTL state/pins over
617,129 cycles (modes 0/1/2, ACK timing, restart, periods 7 through 65535, zero
loop count and 32-bit carry boundaries), and checks 342,144 arithmetic cases
including all 65,536 timing-limit values. Ideal clock/TRNG/read-bus models are
used **only** for this counter/control comparison. They do not verify actual
clock generation, randomness, MRAM operation, signal integrity, or timing closure.

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
