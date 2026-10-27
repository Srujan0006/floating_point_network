# Hierarchical FP32 compare-and-swap: Tiny Tapeout project report

## Summary
A clocked compare-and-swap for two FP32 numbers. It compares **sign**, then **exponent**, then **mantissa**, and stops at the first field that decides. It reports on the pins how many cycles it used (1, 2 or 3), so the data-dependent latency is visible. Fields that are not needed have their comparator inputs held at zero. It is the closest synthesizable, clocked form of the self-timed unit; it is **not** truly asynchronous.

Target: Tiny Tapeout IHP shuttle template (`ttihp-verilog-template`, branch `cmos5l`), top module `tt_um_hier_fp_cas`, 1x1 tile, 10 MHz.

## Interface
| Pin | Function |
|---|---|
| `ui_in[7:0]` | data byte |
| `uio[0]` | WR: load strobe (8 bytes: a[31:24]..a[7:0], b[31:24]..b[7:0]); the compare starts after the 8th byte |
| `uio[3:1]` | SEL: result byte select |
| `uio[4]` | DONE (output) |
| `uio[6:5]` | cycles used: 1 = sign, 2 = exponent, 3 = mantissa (output) |
| `uo_out` | SEL 0-3: larger value, 4-7: smaller value (MSB first) |

Ordering is by FP32 bit pattern with sign-magnitude rules (-0 < +0). NaN is not handled.

## Verification status
| Check | Result | Where |
|---|---|---|
| Plain Verilog testbench, 3005 vectors vs numpy | 0 errors (reported by author) | local, not re-run in this session |
| Cycle counts over those vectors | 1012 sign, 722 exponent, 1271 mantissa | local, not re-run in this session |
| cocotb test (`test/test.py`): directed corners + 300 random, checks order and cycle count | passed | `test` workflow, commit a698a95 |
| Real Tiny Tapeout flow: gds, precheck, gl_test, viewer, docs | all passed (after enabling GitHub Pages for `viewer`) | GitHub Actions run 40498704141 |

## Area (kept separate by PDK)
| PDK | Tool | Area | Cells | Status |
|---|---|---|---|---|
| sky130 hd | Yosys estimate | about 3,970 um2 | 458 | estimate only |
| IHP SG13G2 (cmos5l) | Tiny Tapeout (LibreLane) flow, final | 11,053 um2 standard-cell area (core 28,942 um2, die 31,318 um2) | 796 incl. tap cells, 708 excluding fill and tap | from `final/metrics.json` of the gds run |

The two rows are on different processes and must not be compared directly. For reference, the IHP Yosys synthesis step alone reported 8,261 um2 before placement, repair and clock-tree buffers.

### IHP gds run (commit a698a95, run 40498704141)
| Metric | Value |
|---|---|
| Utilisation | 38.2 % of core (31.985 % in the cell-usage table, which excludes tap cells) |
| Standard-cell area | 11,053 um2, of which flip-flops 3,674 (75 flops x 48.99), multi-input logic 4,237, timing-repair buffers 2,364 (182 cells), clock buffers 401, inverters 343 |
| Hold-fix buffers | 115 (`dlygate4sd3`), setup-fix buffers 0 |
| Wire length | 18,351 um |
| Setup worst slack | +9.72 ns (slow corner 1.08 V, 125 C), +10.46 ns typical, +10.91 ns fast |
| Hold worst slack | +0.18 ns (fast corner), +0.40 typical, +0.78 slow |
| Timing violations | 0 setup, 0 hold, 0 max-slew, 0 max-cap |
| Power (total, vectorless, typical) | 0.367 mW (internal 0.293, switching 0.072, leakage 0.001) |
| DRC / LVS / antenna | 0 / 0 / 0 |
| Lint | 1 warning: unused bits `rs[55:0]` at `src/project.v:81`. Harmless; only the top byte of the shifted result is used |

Cell categories (excluding fill and tap): combo logic 220, delay cells 115, buffers 85, NAND 84, flip-flops 75, inverters 68, NOR/XNOR 32, multiplexers 17, AND 8, OR/XOR 4; total 708. Fill: 1,776 decap cells.

Observations:
- The flip-flops are the single largest block (33 % of cell area): 75 flops at about 49 um2 each. The RTL has 73 bits of state (a, b, cnt, st, done, gt, cyc), so 2 extra flops come from the flow or the reset/enable mapping; this was not investigated.
- 115 hold-fix delay cells and 182 timing-repair buffers in total add 2,364 um2 (21 % of cell area). The wide input paths and the zero-skew-sensitive shift register are the likely cause.
- The design fits one tile with room to spare (38 % utilisation).

## Timing
- The flow's own constraints met timing in all three corners with positive slack. Setup slack is large because the flow uses a relaxed clock period (20 ns in the template `config.json`) and `timing__setup_r2r__ws` is reported as infinity, so the worst setup path is an input/output path and the slack does **not** give a reliable maximum clock frequency.
- sky130 per-field delays (sign 0.26 ns, exponent 1.28 ns, mantissa 3.63 ns) are process-specific and come from the author's model. They are not confirmed by the IHP run, which reports whole-design timing only. Only the ordering sign < exponent < mantissa is expected to carry over.
- IHP per-field figures would need the field-compare modules run separately in that flow.

## Changes made in this review
- `uio_oe` is now `8'b0111_0000` (uio[7] stays an input).
- Header comment corrected: CYC is `uio_out[6:5]`.
- `test/test.py` rewritten: reference uses bit-pattern order (-0 < +0), checks the cycle count, adds directed corners, and forces shared exponent/sign in some random vectors.
- `README.md` points to the `cmos5l` template.

## Known limitations
- Operand gating adds AND gates and the shift registers still toggle while loading, so the power saving is probably small.
- If `Clock(..., unit="ns")` fails in the `test` workflow, change `unit` to `units` (older cocotb).
- Use the template's own `test/Makefile` and `test/tb.v`, and keep the template's `yaml_version` line in `info.yaml`.

## Actions status (commit a698a95)
- `test` (cocotb RTL): passed.
- `docs`: passed.
- `gds`: passed, including `precheck`, `gl_test` (gate-level) and `viewer`. The first run's `viewer` failure was only GitHub Pages not being enabled.

## Open items
- Optional: silence the `rs[55:0]` lint warning.
- Power is a vectorless estimate; it says nothing about the claimed saving from operand gating.
