# uDMA SPI/QSPI master hardening

This directory contains the canonical GF180 LibreLane configuration for
`udma_spim_top`. It was developed as the revised Trial 16 ECO candidate in the
local Schulich-On-Chip-Rkive hardening archive.

## Proven environment

- Date verified: 2026-08-08
- LibreLane: local `stable` checkout
- PDK: `gf180mcuD`
- Ciel/PDK revision: `54435919abffb937387ec956209f9cf5fd2dfbee`
- Clock target: 50 ns / 20 MHz for `sys_clk_i` and `periph_clk_i`
- Production SPI RTL was not modified.

## Why the configuration is structured this way

- `SYNTH_ABC_BUFFERING` eliminated the remaining slow-corner setup paths.
- A 0.9 ns post-global-route hold margin preserved extracted hold closure.
- The SDC uses GF180 library-backed transition and capacitance limits.
- Five weak drive-1 cell families are excluded to avoid extracted slew
  violations.
- Three explicit `buf_2` ECO cells isolate the only remaining over-capacitance
  drivers. LibreLane inserts them after detailed routing and incrementally
  reroutes the six affected nets.
- `gf180_latch_map.v` maps the three intentional clock-gating latches because
  the installed GF180 package does not provide LibreLane's expected latch map.

## Final physical result

| Check | Result |
| --- | ---: |
| Setup WNS / TNS / violations | 0 ns / 0 ns / 0 |
| Hold WNS / TNS / violations | 0 ns / 0 ns / 0 |
| Max-slew violations | 0 |
| Max-capacitance violations | 0 |
| Max-fanout advisories | 2 |
| Antenna nets / pins | 0 / 0 |
| Routing DRC | 0 |
| Magic DRC | 0 |
| GDS XOR differences | 0 |
| Illegal overlaps | 0 |
| LVS errors | 0 |
| Standard-cell area | 459,218 um^2 |
| Final standard-cell utilization | 43.7262% |
| Estimated total power | 0.1130458 W |

The two max-fanout advisories are one-load exceedances: synthesized pins
`_07026_/Z` and `_11700_/Z` each drive 11 loads against a library limit of 10.
Both nets meet extracted slew, capacitance and timing limits, and LibreLane
reports `design__violations=0`.

KLayout DRC is skipped because this GF180 PDK installation does not provide a
supported KLayout DRC runset. Magic DRC, routing DRC, XOR, overlap, LVS and the
scored electrical/timing checks completed cleanly.

## Functional regression

The focused Verilator test configures the command, TX and RX channels and runs
this sequence through the production `udma_spim_top` RTL:

```text
configure -> select CS0 -> transmit 0xA5 -> receive 0xFF -> end transfer
```

It checks command/TX handshakes, chip select, at least 16 SPI rising edges,
both MOSI logic levels, RX data and the end-of-transfer event. The expected
completion message is:

```text
PASS uDMA SPI top: config, CMD=5, TX=0xa5, RX=0xff, edges=16, EOT observed
```

Run the focused checks from the repository root:

```sh
fusesoc --cores-root . run --target=lint_spim_top \
  --build-root /tmp/core_v_mcu_spim_lint \
  openhwgroup.org:tb:udma_subsystem:0

fusesoc --cores-root . run --target=sim_spim_top \
  --build-root /tmp/core_v_mcu_spim_sim \
  openhwgroup.org:tb:udma_subsystem:0
```

Generated LibreLane run directories are ignored. Archive full run logs and
release GDS/LEF/lib views separately instead of committing intermediates.
