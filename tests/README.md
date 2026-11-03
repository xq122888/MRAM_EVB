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
