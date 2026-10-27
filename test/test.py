# cocotb test (matches the Tiny Tapeout template layout)
import random, struct
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

def f2b(x): return struct.unpack("<I", struct.pack("<f", x))[0]

def key(w):
    # total order on FP32 bit patterns (-0 < +0), which is what the hardware implements
    return (w ^ 0x80000000) if not (w >> 31) else (~w & 0xFFFFFFFF)

def exp_cycles(wa, wb):
    if (wa ^ wb) >> 31: return 1
    if (wa ^ wb) & 0x7F800000: return 2
    return 3

async def run(dut, wa, wb):
    w = (wa << 32) | wb
    for j in range(8):
        dut.ui_in.value = (w >> (56 - 8 * j)) & 0xFF; dut.uio_in.value = 1
        await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 5)
    out = int(dut.uio_out.value)
    assert (out >> 4) & 1, "done not set"
    cyc = (out >> 5) & 3
    hi = lo = 0
    for j in range(8):
        dut.uio_in.value = j << 1; await ClockCycles(dut.clk, 1)
        byte = int(dut.uo_out.value)
        if j < 4: hi = (hi << 8) | byte
        else: lo = (lo << 8) | byte
    eh, el = (wa, wb) if key(wa) >= key(wb) else (wb, wa)
    assert hi == eh and lo == el, f"{wa:08x} {wb:08x} -> {hi:08x} {lo:08x}"
    assert cyc == exp_cycles(wa, wb), f"{wa:08x} {wb:08x} cycles {cyc}"

@cocotb.test()
async def test_cas(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.ena.value = 1; dut.ui_in.value = 0; dut.uio_in.value = 0; dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5); dut.rst_n.value = 1; await ClockCycles(dut.clk, 2)
    random.seed(1)
    # directed corners: +-0, equal, same exponent, same sign / different sign
    for wa, wb in [(0x00000000, 0x80000000), (0x80000000, 0x00000000), (0x3F800000, 0x3F800000),
                   (0xBF800000, 0xBF800000), (0x3F800000, 0x3F800001), (0xBF800000, 0xBF800001),
                   (0x3F800000, 0xBF800000), (0x7F7FFFFF, 0xFF7FFFFF), (0x00000001, 0x00000002)]:
        await run(dut, wa, wb)
    # random: wide, narrow (shared exponent) and mixed
    for k in range(300):
        a, b = [struct.unpack("<f", struct.pack("<f", random.gauss(0, 3)))[0] for _ in range(2)]
        wa, wb = f2b(a), f2b(b)
        if k % 3 == 0: wb = (wb & 0x807FFFFF) | (wa & 0x7F800000)   # force same exponent
        if k % 5 == 0: wb = (wb & 0x7FFFFFFF) | (wa & 0x80000000)   # force same sign
        await run(dut, wa, wb)
