#!/bin/sh
# Strip part of the memory so it can fit into the FPGA (synthesized as FlipFlops).
# A way better solution would be to configure the FPGA to use BlockRAMs instead of FlipFlops. Then this would not be needed

# ### Stripped RAM to fit FPGA ###
# included: 0000 - 0FFF (4096 bytes)
# stripped: 0F00 - FFEF ()
# included: FFF0 - FFFF (16 bytes)
# total: 4096 + 16 bytes = 4112

cp test.bin test_fpga.bin
dd if=test_fpga.bin of=test_fpga.bin bs=1 skip=$((0xFFF0)) seek=$((0x0F00)) count=16 conv=notrunc
truncate -s $((0xF10)) test_fpga.bin
xxd -p -c1 test_fpga.bin > test_fpga.hex