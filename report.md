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
| cocotb test (`test/test.py`): directed corners + 300 random, checks order and cycle count | **not run yet** | will run in the `test` workflow |
| Real Tiny Tapeout flow (gds, docs) | **not run yet** | GitHub Actions |

## Area (kept separate by PDK)
| PDK | Tool | Area | Cells | Status |
|---|---|---|---|---|
| sky130 hd | Yosys estimate | about 3,970 um2 | 458 | estimate only |
| IHP SG13G2 | Tiny Tapeout (LibreLane) flow | not reported in the pasted excerpt; utilisation 31.985 % of the placement area | 708 (excluding fill and tap) | from the gds run summary, partial |

The two rows are on different processes and must not be compared directly. The cell count differs partly because the P&R flow adds buffers and hold-fix delay cells that the Yosys-only estimate does not have.

### IHP gds run: routing stats and cell usage
Utilisation 31.985 %, wire length 18,351 um. Linter: 1 warning (text not captured).

| Category | Cells | Count |
|---|---|---|
| Combo logic (o21ai, a21oi, a22oi, a221oi, a21o) | | 220 |
| Misc (dlygate4sd3, hold/delay cells) | | 115 |
| Buffer | buf | 85 |
| NAND | nand2b, nand2, nand4, nand3, nand3b | 84 |
| Flip-flops | dfrbpq | 75 |
| Inverter | inv | 68 |
| NOR/XNOR | nor2b, nor2, nor3, nor4, xnor2 | 32 |
| Multiplexer | mux4, mux2 | 17 |
| AND | and2, and3, and4 | 8 |
| OR/XOR | xor2, or3 | 4 |
| Fill (decap) | not counted in the total | 1,776 |
| **Total (excluding fill and tap)** | | **708** |

Observations: the design fits a 1x1 tile with about two thirds of the area free. 115 delay cells (16 % of the logic) were inserted, most likely by hold fixing. The 75 flip-flops are more than the 73 bits of state in the RTL (a, b, cnt, st, done, gt, cyc), so check the netlist if that matters.

## Timing
- sky130 per-field delays (sign 0.26 ns, exponent 1.28 ns, mantissa 3.63 ns) are process-specific and come from the author's model. They are not confirmed by the IHP run.
- The Actions summary reports whole-design timing only. Only the ordering sign < exponent < mantissa is expected to carry over to IHP.
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

## Actions status
- `test` (cocotb RTL): passed on commit ccf57ab.
- `docs`: passed.
- `gds`: the first run failed only in the `viewer` job (GitHub Pages was not enabled). A re-run is in progress.

## Still to fill in
Area in um2, timing (slack / worst path) and power from the gds summary; `gl_test` and `precheck` result confirmation.
