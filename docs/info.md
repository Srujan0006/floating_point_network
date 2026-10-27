## How it works
Two FP32 numbers are loaded one byte at a time. The unit compares **sign**, then **exponent**, then **mantissa**, and stops at the first field that decides which number is larger. Fields that are not needed are not evaluated (their comparator inputs are held at zero). The number of cycles used (1, 2 or 3) appears on `uio[6:5]`, so the data-dependent latency can be seen on the pins. This is the clocked form of the self-timed hierarchical compare: same logic, early exit counted in cycles.

## How to test
1. Reset. Set `uio[0]=1` and put the 8 bytes on `ui_in`, one per clock: a[31:24], a[23:16], a[15:8], a[7:0], b[31:24], ... b[7:0].
2. Set `uio[0]=0`. Wait for `uio[4]` (DONE).
3. Read `uio[6:5]` for cycles used. Set `uio[3:1]` = 0..7 to read the result bytes on `uo_out`: 0-3 larger value, 4-7 smaller value (MSB first).

## External hardware
None (a microcontroller or the TT demo board).
