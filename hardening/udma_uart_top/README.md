# uDMA UART top hardening

This directory contains the canonical GF180 LibreLane configuration for
`udma_uart_top`. It was developed as Trial 11 in the local hardening archive.

## Proven environment

- Date verified: 2026-08-04
- LibreLane: 3.0.5
- PDK: GF180 `gf180mcuD`
- Ciel/PDK revision: `54435919abffb937387ec956209f9cf5fd2dfbee`
- All 19 RTL/dependency inputs match the proven Trial 11 inputs after
  line-ending normalization.

## Signoff result

| Check | Result |
| --- | ---: |
| Worst setup slack | +0.037186 ns |
| Setup violations | 0 |
| Worst hold slack | +0.073652 ns |
| Hold violations | 0 |
| Max-slew violations | 0 |
| Max-capacitance violations | 0 |
| Max-fanout reports | 2 clock-root reports |
| Routing DRC | 0 |
| Magic DRC | 0 |
| LVS | Clean |
| Antenna | Clean |
| Power-grid violations | 0 |

The two fanout reports are the CTS roots `clkbuf_0_periph_clk_i/Z` and
`clkbuf_0_sys_clk_i/Z`, each with fanout 16 against the global limit of 10.
They do not coincide with timing, slew, capacitance, routing, or physical
signoff failures. KLayout DRC was skipped because the GF180 installation did
not provide a supported KLayout runset; Magic DRC completed cleanly.

## Functional regression

The focused FuseSoC regression in `udma_subsystem_tests.core` passed with
FuseSoC 2.4.6 and Verilator 5.044:

- `lint`
- `sim`: camera-free reset/configuration smoke test
- `sim_uart_tx`: APB setup, L2 DMA fetch of `0xA5`, and completion event
- `sim_uart_rx`: receive `0xA5`, L2 DMA write, byte enable, and completion event
- Existing `openhwgroup.org:systems:core-v-mcu` full-SoC `lint` target

Run a target from the repository root with a no-space WSL build directory:

```sh
fusesoc --cores-root . run \
  --target=sim_uart_tx \
  --build-root /home/sahana/core_v_mcu_pr_fusesoc_build \
  openhwgroup.org:tb:udma_subsystem:0
```

Generated LibreLane run directories are ignored. Archive full signoff runs and
release GDS/LEF/lib views separately instead of committing intermediate files.
