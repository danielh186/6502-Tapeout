import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, ReadWrite  # Import ReadOnly
from cocotb.triggers import Timer

import numpy as np

import copy

DEBUG = False


class Opcode:
    def __init__(self, opcode, name, addressing, bytes, cycles, affected_flags, affected_regs):
        self.opcode = opcode  # opcode hex value
        self.name = name  # name of the opcode
        self.addressing = addressing  # addressing mode
        self.bytes = bytes  # number of bytes the opcode uses in memory
        self.cycles = cycles  # number of cycles the opcode takes
        self.affected_flags = affected_flags  # flags affected by the opcode
        self.affected_regs = affected_regs  # registers affected by the opcode

    def __repr__(self):
        return f"{self.name} {self.addressing} ({hex(self.opcode)})"


# Create an array of OpcodeInfo objects
# opcode, name, addressing_mode, length (in bytes), cycles, affected_flags, affected_regs
opcode_list = [
    # LDA
    Opcode(0xA9, "LDA", "imm", 2, 2, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0xA5, "LDA", "zpg", 2, 3, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0xB5, "LDA", "zpg_x", 2, 3, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0xAD, "LDA", "abs", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0xBD, "LDA", "abs_x", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0xB9, "LDA", "abs_y", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0xA1, "LDA", "ind_x", 2, 5, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0xB1, "LDA", "ind_y", 2, 5, ["N", "Z"], ["PC", "ACC"]),
    # STA
    Opcode(0x85, "STA", "zpg", 2, 3, [], ["PC"]),
    Opcode(0x95, "STA", "zpg_x", 2, 3, [], ["PC"]),
    Opcode(0x8D, "STA", "abs", 3, 4, [], ["PC"]),
    Opcode(0x9D, "STA", "abs_x", 3, 4, [], ["PC"]), # reduced cycles (normally always 5, now always 4) TODO: paper: verwunderlich warum hier keine variable Ausführungszeit
    Opcode(0x99, "STA", "abs_y", 3, 4, [], ["PC"]),
    Opcode(0x81, "STA", "ind_x", 2, 5, [], ["PC"]), # reduced cycles (normally always 6, now always 5)
    Opcode(0x91, "STA", "ind_y", 2, 5, [], ["PC"]), # reduced cycles (normally always 6, now always 5)
    # ADC
    Opcode(0x69, "ADC", "imm", 2, 2, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0x65, "ADC", "zpg", 2, 3, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0x75, "ADC", "zpg_x", 2, 3, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0x6D, "ADC", "abs", 3, 4, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0x7D, "ADC", "abs_x", 3, 4, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0x79, "ADC", "abs_y", 3, 4, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0x61, "ADC", "ind_x", 2, 5, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0x71, "ADC", "ind_y", 2, 5, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    # SBC
    Opcode(0xE9, "SBC", "imm", 2, 2, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0xE5, "SBC", "zpg", 2, 3, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0xF5, "SBC", "zpg_x", 2, 3, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0xED, "SBC", "abs", 3, 4, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0xFD, "SBC", "abs_x", 3, 4, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0xF9, "SBC", "abs_y", 3, 4, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0xE1, "SBC", "ind_x", 2, 5, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    Opcode(0xF1, "SBC", "ind_y", 2, 5, ["N", "Z", "C", "V"], ["PC", "ACC"]),
    # ORA
    Opcode(0x09, "ORA", "imm", 2, 2, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x05, "ORA", "zpg", 2, 3, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x15, "ORA", "zpg_x", 2, 3, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x0D, "ORA", "abs", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x1D, "ORA", "abs_x", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x19, "ORA", "abs_y", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x01, "ORA", "ind_x", 2, 5, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x11, "ORA", "ind_y", 2, 5, ["N", "Z"], ["PC", "ACC"]),
    # AND
    Opcode(0x29, "AND", "imm", 2, 2, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x25, "AND", "zpg", 2, 3, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x35, "AND", "zpg_x", 2, 3, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x2D, "AND", "abs", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x3D, "AND", "abs_x", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x39, "AND", "abs_y", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x21, "AND", "ind_x", 2, 5, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x31, "AND", "ind_y", 2, 5, ["N", "Z"], ["PC", "ACC"]),
    # EOR
    Opcode(0x49, "EOR", "imm", 2, 2, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x45, "EOR", "zpg", 2, 3, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x55, "EOR", "zpg_x", 2, 3, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x4D, "EOR", "abs", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x5D, "EOR", "abs_x", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x59, "EOR", "abs_y", 3, 4, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x41, "EOR", "ind_x", 2, 5, ["N", "Z"], ["PC", "ACC"]),
    Opcode(0x51, "EOR", "ind_y", 2, 5, ["N", "Z"], ["PC", "ACC"]),
    # CMP
    Opcode(0xC9, "CMP", "imm", 2, 2, ["N", "Z", "C"], ["PC"]),
    Opcode(0xC5, "CMP", "zpg", 2, 3, ["N", "Z", "C"], ["PC"]),
    Opcode(0xD5, "CMP", "zpg_x", 2, 3, ["N", "Z", "C"], ["PC"]),
    Opcode(0xCD, "CMP", "abs", 3, 4, ["N", "Z", "C"], ["PC"]),
    Opcode(0xDD, "CMP", "abs_x", 3, 4, ["N", "Z", "C"], ["PC"]),
    Opcode(0xD9, "CMP", "abs_y", 3, 4, ["N", "Z", "C"], ["PC"]),
    Opcode(0xC1, "CMP", "ind_x", 2, 5, ["N", "Z", "C"], ["PC"]),
    Opcode(0xD1, "CMP", "ind_y", 2, 5, ["N", "Z", "C"], ["PC"]),
    # Compare Registers
    Opcode(0xC0, "CPY", "imm", 2, 2, ["N", "Z", "C"], ["PC"]),
    Opcode(0xC4, "CPY", "zpg", 2, 3, ["N", "Z", "C"], ["PC"]),
    Opcode(0xCC, "CPY", "abs", 3, 4, ["N", "Z", "C"], ["PC"]),
    #
    Opcode(0xE0, "CPX", "imm", 2, 2, ["N", "Z", "C"], ["PC"]),
    Opcode(0xE4, "CPX", "zpg", 2, 3, ["N", "Z", "C"], ["PC"]),
    Opcode(0xEC, "CPX", "abs", 3, 4, ["N", "Z", "C"], ["PC"]),
    # Load Registers
    Opcode(0xA0, "LDY", "imm", 2, 2, ["N", "Z"], ["PC", "Y"]),
    Opcode(0xA4, "LDY", "zpg", 2, 3, ["N", "Z"], ["PC", "Y"]),
    Opcode(0xB4, "LDY", "zpg_x", 2, 3, ["N", "Z"], ["PC", "Y"]),
    Opcode(0xAC, "LDY", "abs", 3, 4, ["N", "Z"], ["PC", "Y"]),
    Opcode(0xBC, "LDY", "abs_x", 3, 4, ["N", "Z"], ["PC", "Y"]),
    Opcode(0xA2, "LDX", "imm", 2, 2, ["N", "Z"], ["PC", "X"]),
    Opcode(0xA6, "LDX", "zpg", 2, 3, ["N", "Z"], ["PC", "X"]),
    Opcode(0xB6, "LDX", "zpg_y", 2, 3, ["N", "Z"], ["PC", "X"]),
    Opcode(0xAE, "LDX", "abs", 3, 4, ["N", "Z"], ["PC", "X"]),
    Opcode(0xBE, "LDX", "abs_y", 3, 4, ["N", "Z"], ["PC", "X"]),
    # Store Registers
    Opcode(0x84, "STY", "zpg", 2, 3, [], ["PC"]),
    Opcode(0x94, "STY", "zpg_x", 2, 3, [], ["PC"]),
    Opcode(0x8C, "STY", "abs", 3, 4, [], ["PC"]),
    Opcode(0x86, "STX", "zpg", 2, 3, [], ["PC"]),
    Opcode(0x96, "STX", "zpg_y", 2, 3, [], ["PC"]),
    Opcode(0x8E, "STX", "abs", 3, 4, [], ["PC"]),
    # Increment/Decrement
    Opcode(0xE6, "INC", "zpg", 2, 4, ["N", "Z"], ["PC"]), # reduced cycles (4 instead of 5)
    Opcode(0xF6, "INC", "zpg_x", 2, 4, ["N", "Z"], ["PC"]), # reduced by 2 (-1 just like zpg) and (-1 for auto page crossing)
    Opcode(0xEE, "INC", "abs", 3, 5, ["N", "Z"], ["PC"]), # reduced by 1
    Opcode(0xFE, "INC", "abs_x", 3, 5, ["N", "Z"], ["PC"]), # reduced by 2
    #
    Opcode(0xC6, "DEC", "zpg", 2, 4, ["N", "Z"], ["PC"]), # reduced cycles (4 instead of 5)
    Opcode(0xD6, "DEC", "zpg_x", 2, 4, ["N", "Z"], ["PC"]), # reduced by 2 (-1 just like zpg) and (-1 for auto page crossing)
    Opcode(0xCE, "DEC", "abs", 3, 5, ["N", "Z"], ["PC"]), # reduced by 1
    Opcode(0xDE, "DEC", "abs_x", 3, 5, ["N", "Z"], ["PC"]), # reduced by 2
    # Arithmetic Shift Left
    Opcode(0x0A, "ASL", "acc", 1, 1, ["N", "Z", "C"], ["PC", "ACC"]), # reduced cycles (1 instead of 2)
    Opcode(0x06, "ASL", "zpg", 2, 4, ["N", "Z", "C"], ["PC"]), # reduced cycles (4 instead of 5)
    Opcode(0x16, "ASL", "zpg_x", 2, 4, ["N", "Z", "C"], ["PC"]), # reduced by 2 (-1 just like zpg) and (-1 for auto page crossing)
    Opcode(0x0E, "ASL", "abs", 3, 5, ["N", "Z", "C"], ["PC"]), # reduced by 1
    Opcode(0x1E, "ASL", "abs_x", 3, 5, ["N", "Z", "C"], ["PC"]), # reduced by 2
    # Rotate Left
    Opcode(0x2A, "ROL", "acc", 1, 1, ["N", "Z", "C"], ["PC", "ACC"]), # reduced cycles (1 instead of 2)
    Opcode(0x26, "ROL", "zpg", 2, 4, ["N", "Z", "C"], ["PC"]), # reduced cycles (4 instead of 5)
    Opcode(0x36, "ROL", "zpg_x", 2, 4, ["N", "Z", "C"], ["PC"]), # reduced by 2 (-1 just like zpg) and (-1 for auto page crossing)
    Opcode(0x2E, "ROL", "abs", 3, 5, ["N", "Z", "C"], ["PC"]), # reduced by 1
    Opcode(0x3E, "ROL", "abs_x", 3, 5, ["N", "Z", "C"], ["PC"]), # reduced by 2
    # Logical Shift Right
    Opcode(0x4A, "LSR", "acc", 1, 1, ["N", "Z", "C"], ["PC", "ACC"]), # reduced cycles (1 instead of 2)
    Opcode(0x46, "LSR", "zpg", 2, 4, ["N", "Z", "C"], ["PC"]), # reduced cycles (4 instead of 5)
    Opcode(0x56, "LSR", "zpg_x", 2, 4, ["N", "Z", "C"], ["PC"]), # reduced by 2 (-1 just like zpg) and (-1 for auto page crossing)
    Opcode(0x4E, "LSR", "abs", 3, 5, ["N", "Z", "C"], ["PC"]), # reduced by 1
    Opcode(0x5E, "LSR", "abs_x", 3, 5, ["N", "Z", "C"], ["PC"]), # reduced by 2
    # Rotate Right
    Opcode(0x6A, "ROR", "acc", 1, 1, ["N", "Z", "C"], ["PC", "ACC"]), # reduced cycles (1 instead of 2)
    Opcode(0x66, "ROR", "zpg", 2, 4, ["N", "Z", "C"], ["PC"]), # reduced cycles (4 instead of 5)
    Opcode(0x76, "ROR", "zpg_x", 2, 4, ["N", "Z", "C"], ["PC"]), # reduced by 2 (-1 just like zpg) and (-1 for auto page crossing)
    Opcode(0x6E, "ROR", "abs", 3, 5, ["N", "Z", "C"], ["PC"]), # reduced by 1
    Opcode(0x7E, "ROR", "abs_x", 3, 5, ["N", "Z", "C"], ["PC"]), # reduced by 2
    # Set/Clear Flags
    # TODO: make sure that flags are also handled correctly
    Opcode(0x38, "SEC", "impl", 1, 1, ["C"], ["PC"]),  # cycles 2->1
    Opcode(0x18, "CLC", "impl", 1, 1, ["C"], ["PC"]),  # cycles 2->1
    Opcode(0x78, "SEI", "impl", 1, 1, ["I"], ["PC"]),  # cycles 2->1
    Opcode(0x58, "CLI", "impl", 1, 1, ["I"], ["PC"]),  # cycles 2->1
    Opcode(0xF8, "SED", "impl", 1, 1, ["D"], ["PC"]),  # cycles 2->1
    Opcode(0xD8, "CLD", "impl", 1, 1, ["D"], ["PC"]),  # cycles 2->1
    Opcode(0xB8, "CLV", "impl", 1, 1, ["V"], ["PC"]),  # cycles 2->1
    # Increment Register
    Opcode(0xE8, "INX", "impl", 1, 1, ["N", "Z"], ["PC", "X"]),  # reduced cycles (1 instead of 2)
    Opcode(0xC8, "INY", "impl", 1, 1, ["N", "Z"], ["PC", "Y"]),  # reduced cycles (1 instead of 2)
    # Decrement Register
    Opcode(0xCA, "DEX", "impl", 1, 1, ["N", "Z"], ["PC", "X"]),  # reduced cycles (1 instead of 2)
    Opcode(0x88, "DEY", "impl", 1, 1, ["N", "Z"], ["PC", "Y"]),  # reduced cycles (1 instead of 2)
    # Stack
    Opcode(0x08, "PHP", "impl", 1, 2, [], ["PC", "SP"]), # reduced cycles (2 instead of 3)
    Opcode(0x48, "PHA", "impl", 1, 2, [], ["PC", "SP"]), # reduced cycles (2 instead of 3)
    Opcode(0x68, "PLA", "impl", 1, 2, ["N", "Z"], ["PC", "SP", "ACC"]), # reduced cycles (2 instead of 4)
    Opcode(0x28, "PLP", "impl", 1, 2, ["N", "V", "B", "D", "I", "Z", "C"], ["PC", "SP"]), # reduced cycles (2 instead of 4)
    # Transfer instructions
    Opcode(0xAA, "TAX", "impl", 1, 1, ["N", "Z"], ["PC", "X"]),  # reduced cycles (1 instead of 2)
    Opcode(0xA8, "TAY", "impl", 1, 1, ["N", "Z"], ["PC", "Y"]),  # reduced cycles (1 instead of 2)
    Opcode(0x8A, "TXA", "impl", 1, 1, ["N", "Z"], ["PC", "ACC"]),  # reduced cycles (1 instead of 2)
    Opcode(0x98, "TYA", "impl", 1, 1, ["N", "Z"], ["PC", "ACC"]),  # reduced cycles (1 instead of 2)
    Opcode(0xBA, "TSX", "impl", 1, 1, ["N", "Z"], ["PC", "X"]),  # reduced cycles (1 instead of 2)
    Opcode(0x9A, "TXS", "impl", 1, 1, [], ["PC", "SP"]),  # reduced cycles (1 instead of 2)
    # Jumps
    Opcode(0x4C, "JMP", "abs", 3, 3, [], ["PC"]),
    Opcode(0x6C, "JMP", "ind", 3, 5, [], ["PC"]), # reduced cycles to 4
    # Interrupts
    # TODO: on C6502 D Flag is cleared additionally
    # TODO: set I flag (masswerk says no, most other sites say yes) -> do it
    Opcode(0x00, "BRK", "impl", 2, 6, ["I"], ["PC", "SP"]), # reduced cycles (7 -> 6)
    Opcode(0x40, "RTI", "impl", 1, 4, ["N", "V", "B", "D", "I", "Z", "C"], ["PC", "SP"]),
    # Subroutines
    Opcode(0x20, "JSR", "abs", 3, 5, [], ["PC", "SP"]),
    Opcode(0x60, "RTS", "impl", 1, 3, [], ["PC", "SP"]), # reduced cycles (6 -> 3)
    # Branches
    Opcode(0x10, "BPL", "rel", 2, 1, [], ["PC"]), # when not branching: reduced cycles (2 -> 1) when branching: 2 cycles (instead of 3-4)
    Opcode(0x30, "BMI", "rel", 2, 1, [], ["PC"]), # when not branching: reduced cycles (2 -> 1) when branching: 2 cycles (instead of 3-4)
    Opcode(0x50, "BVC", "rel", 2, 1, [], ["PC"]), # when not branching: reduced cycles (2 -> 1) when branching: 2 cycles (instead of 3-4)
    Opcode(0x70, "BVS", "rel", 2, 1, [], ["PC"]), # when not branching: reduced cycles (2 -> 1) when branching: 2 cycles (instead of 3-4)
    Opcode(0x90, "BCC", "rel", 2, 1, [], ["PC"]), # when not branching: reduced cycles (2 -> 1) when branching: 2 cycles (instead of 3-4)
    Opcode(0xB0, "BCS", "rel", 2, 1, [], ["PC"]), # when not branching: reduced cycles (2 -> 1) when branching: 2 cycles (instead of 3-4)
    Opcode(0xD0, "BNE", "rel", 2, 1, [], ["PC"]), # when not branching: reduced cycles (2 -> 1) when branching: 2 cycles (instead of 3-4)
    Opcode(0xF0, "BEQ", "rel", 2, 1, [], ["PC"]), # when not branching: reduced cycles (2 -> 1) when branching: 2 cycles (instead of 3-4)
    # Bit
    Opcode(0x24, "BIT", "zpg", 2, 3, ["N", "V", "Z"], ["PC"]),
    Opcode(0x2C, "BIT", "abs", 3, 4, ["N", "V", "Z"], ["PC"]),


    # NOP
    Opcode(0xEA, "NOP", "impl", 1, 2, [], ["PC"]),
    # Illegal instruction used in testbench to mark end of program
    Opcode(0x04, "END", "impl", 1, 1, [], []),
]

def matches_mask(value, mask):
    """
    Check if a value matches a binary mask with '1', '0', and '?'.

    :param value: Integer to check.
    :param mask: A string mask where '1' means match 1, '0' means match 0, and '?' means don't care.
    :return: Boolean, True if matches, False otherwise.
    """
    value_bin = f"{value:08b}"  # Convert the value to an 8-bit binary string

    for v_bit, m_bit in zip(value_bin, mask):
        if m_bit == '1' and v_bit != '1':  # Match 1
            return False
        if m_bit == '0' and v_bit != '0':  # Match 0
            return False
        # Ignore '?' (don't care)

    return True

@cocotb.test()
async def cpu_minimal_test(dut):
    """
    Test that acts as external memory for 'cpu.v'.
    instructions are stored in a Python array. The CPU fetches them
    via addr, data_in, R/W
    """
    async def runCycles(cycles):
        for cycle in range(cycles):
            # Wait for rising edge
            await RisingEdge(dut.clk)

            # Insert a tiny time delay to exit read-only phase
            # so we can safely write to dut.data_in
            await Timer(1, units="ns")

            if DEBUG:
                print(f"{op}: cycle: {cycle}, state: {dut.state.value}")
                print(
                    f"CPU State: PC={dut.PC.value} IR={hex(dut.IR.value)} ACC={dut.ACC.value} X={dut.X.value} Y={dut.Y.value}"
                )
                print(
                    f"Status Register: N={dut.N.value} V={dut.V.value} Z={dut.Z.value} C={dut.C.value}"
                )
                print("")

            address = dut.addr.value.integer

            # If CPU is reading
            if (dut.RW.value == 1):
                if address < 65536:
                    dut.data_in.value = mem[address]
                else:
                    dut.data_in.value = 0xFF # Return 0xFF if address is out of bounds
            # If CPU is writing, store data_out into mem
            elif (dut.RW.value == 0):
                if address < 65536:
                    mem[address] = dut.data_out.value.integer

    # Create a clock (1 us period = 1MHz)
    cocotb.start_soon(Clock(dut.clk, 1000, units="ns").start())

    mem = [0xFF] * 65536

    with open('test.bin', 'rb') as f:
        binary_data = f.read()
        for i in range(len(binary_data)):
            mem[i] = binary_data[i]

    # # Memory array for code + data
    # mem = [0] * 65536

    # # Program code
    # mem[0] = 0xE6 # INC zpg
    # mem[1] = 0x0A
    # mem[2] = 0xA9  # LDA
    # mem[3] = 0x60
    # mem[4] = 0x06 # ASL
    # mem[5] = 0x0A
    # mem[0x0A] = 0x05

    # STACK: mem[0100] ... mem[01FF] (growing top to bottom)
    # $FFFA, $FFFB ... NMI (Non-Maskable Interrupt) vector
    # $FFFC, $FFFD ... RES (Reset) vector
    # $FFFE, $FFFF ... IRQ (Interrupt Request) vector

    # Initialize signals
    dut.reset_n.value = 0
    dut.RDY.value = 1

    # Wait a few clock cycles with reset=0
    for _ in range(5):
        await RisingEdge(dut.clk)
    did_reset = True
    dut.reset_n.value = 1

    # Iterate through Program code and execute every instruction and test the results

    print("########################### START PROGRAM ###########################")
    mem_index = 0x0600
    # TODO: this needs to be adjusted in the jump test cases
    while mem_index < len(mem):
        # Capture previous values
        previous_values = {
            "PC": int(dut.PC.value),
            "ACC": int(dut.ACC.value),
            "SP": int(dut.SP.value),
            "X": int(dut.X.value),
            "Y": int(dut.Y.value),
            "N": int(dut.N.value),
            "V": int(dut.V.value),
            "B": int(dut.B.value),
            "D": int(dut.D.value),
            "I": int(dut.I.value),
            "Z": int(dut.Z.value),
            "C": int(dut.C.value),
        }
        previous_mem = copy.deepcopy(mem)

        opcode_addr = mem_index
        opcode = mem[opcode_addr]
        nmi_addr = (mem[0xFFFB] << 8) + mem[0xFFFA]
        res_addr = (mem[0xFFFD] << 8) + mem[0xFFFC]
        irq_addr = (mem[0xFFFF] << 8) + mem[0xFFFE]

        # Figure out addressing TODO: remove??
        # if matches_mask(opcode, "???011??"):  # Absoulte
        #     addressed_value = (mem[opcode_addr + 2] << 8) + mem[opcode_addr + 1]
        # elif matches_mask(opcode, "???001??"):  # Zero Page
        #     addressed_value = mem[opcode_addr + 1]
        # else:
        #     assert False, "Invalid addressing mode"

        # Get opcode from opcode_list
        op = next((op for op in opcode_list if op.opcode == opcode), None)
        if op is None:
            assert False, f"Invalid opcode {hex(opcode)} found at address {opcode_addr}"
            # print(f"Invalid opcode {hex(opcode)} found at address {opcode_addr}")
            # continue

        if op.addressing == "impl":
            addressed_value = None
            target_addr = None
        elif op.addressing == "acc":
            addressed_value = previous_values["ACC"]
            target_addr = None
        elif op.addressing == "imm":
            target_addr = opcode_addr + 1
        elif op.addressing == "abs":
            target_addr = (mem[opcode_addr + 2] << 8) + mem[opcode_addr + 1]
        elif op.addressing == "zpg":
            target_addr = mem[opcode_addr + 1]
        elif op.addressing == "abs_x":
            target_addr = ((mem[opcode_addr + 2] << 8) + mem[opcode_addr + 1] + dut.X.value)
        elif op.addressing == "abs_y":
            target_addr = ((mem[opcode_addr + 2] << 8) + mem[opcode_addr + 1] + dut.Y.value)
        elif op.addressing == "zpg_x":
            target_addr = (mem[opcode_addr + 1] + dut.X.value) & 0xFF
        elif op.addressing == "zpg_y":
            target_addr = (mem[opcode_addr + 1] + dut.Y.value) & 0xFF
        elif op.addressing == "ind":
            # Indirect addressing (only used for JMP)
            # Get the low byte of the target address from the instruction
            low_byte = mem[opcode_addr + 1]
            # Get the high byte of the target address from the instruction
            high_byte = mem[opcode_addr + 2]
            # Combine the low and high bytes to get the target address
            target_addr = (high_byte << 8) + low_byte
        elif op.addressing == "ind_x":
            # Indirect addressing (X-indexed)
            # Get the zero page address from the instruction
            zpg_addr = (mem[opcode_addr + 1] + dut.X.value) & 0xFF
            # Get the low byte of the target address from the zero page
            low_byte = mem[zpg_addr]
            # Get the high byte of the target address from the zero page
            high_byte = mem[zpg_addr + 1]
            # Combine the low and high bytes to get the target address
            target_addr = (high_byte << 8) + low_byte
        elif op.addressing == "ind_y":
            # Indirect addressing (Y-indexed)
            # Get the zero page address from the instruction
            zpg_addr = mem[opcode_addr + 1]
            # Get the low byte of the target address from the zero page
            low_byte = mem[zpg_addr]
            # Get the high byte of the target address from the zero page
            high_byte = mem[zpg_addr + 1]
            # Combine the low and high bytes to get the target address
            target_addr = (high_byte << 8) + low_byte + dut.Y.value
        elif op.addressing == "rel":
            # Relative addressing
            # Get the relative offset from the instruction
            offset = mem[opcode_addr + 1]
            # Do signed conversion
            if offset > 127:
                offset = offset - 256
            # if offset & 0x80:
                # offset = -((~offset & 0xFF) + 1)

            # Calculate the target address by adding the offset to the program counter
            target_addr = opcode_addr + op.bytes + offset
        else:
            assert False, "Invalid addressing mode"

        if target_addr is not None:
            addressed_value = mem[target_addr]

        # Run for cycles specified by the opcode
        needed_cycles = op.cycles
        if did_reset:
            # Reset cycles (ST_RESET -> ST_FETCH_OPERAND_LOW -> ST_FETCH_OPERAND_HIGH -> ST_EXEC (indcludes fetch for next operation))
            needed_cycles = needed_cycles + 3
            did_reset = False

        await runCycles(needed_cycles)

        # Move to next opcode
        mem_index = mem_index + op.bytes # TODO: different for jump and branch instructions

        def check_unaffected(previous_values, affected_flags, affected_regs):
            # Check that unaffected registers/flags have not changed
            for key, previous_value in previous_values.items():
                # Skip affected registers/flags
                if key not in affected_flags and key not in affected_regs:
                    current_value = getattr(dut, key).value
                    assert (
                        previous_value == current_value
                    ), f"{key} changed unexpectedly should have stayed {hex(previous_value)} but got {hex(current_value)}"

        def verify_attr(reg, expected_value, verified_array):
            if getattr(dut, reg).value != expected_value:
                assert (
                    False
                ), f"{reg} should have been {hex(expected_value)} but got {hex(getattr(dut, reg).value)}"
            verified_array.append(reg)

        def verify_memory(expected_mem, mem):
            for addr, val in enumerate(expected_mem):
                if mem[addr] != val:
                    assert (
                        False
                    ), f"Memory mismatch at address {hex(addr)}: expected {hex(val)}, got {hex(mem[addr])}"
                else:
                    mem[addr] = val
            # # overwrite memory with expected memory
            # mem = copy.deepcopy(expected_mem)

        verified_regs = []
        verified_flags = []
        if op.name == "ORA":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_acc = (previous_values["ACC"] | addressed_value)
            verify_attr("ACC", expected_acc, verified_regs)
            verify_attr("N", (expected_acc & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_acc == 0, verified_flags)

        elif op.name == "AND":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_acc = previous_values["ACC"] & addressed_value
            verify_attr("ACC", expected_acc, verified_regs)
            verify_attr("N", (expected_acc & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_acc == 0, verified_flags)

        elif op.name == "EOR":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_acc = previous_values["ACC"] ^ addressed_value
            verify_attr("ACC", expected_acc, verified_regs)
            verify_attr("N", (expected_acc & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_acc == 0, verified_flags)

        elif op.name == "ADC":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            if previous_values["D"]:
                # BCD mode addition
                acc = previous_values["ACC"]
                operand = addressed_value
                carry_in = previous_values["C"]

                lo_nibble = (acc & 0x0F) + (operand & 0x0F) + carry_in
                if lo_nibble > 9:
                    lo_nibble += 6

                hi_nibble = (acc >> 4) + (operand >> 4) + (lo_nibble > 0x0F)
                if hi_nibble > 9:
                    hi_nibble += 6
                    expected_carry = 1
                else:
                    expected_carry = 0

                expected_acc = ((hi_nibble << 4) | (lo_nibble & 0x0F)) & 0xFF

                verify_attr("ACC", expected_acc, verified_regs)
                verify_attr("C", expected_carry, verified_flags)
                verify_attr("Z", expected_acc == 0, verified_flags)
                verify_attr("N", (expected_acc & 0x80) != 0, verified_flags)
                # in decimal mode V is undefined (actually on original 6502 it is not always 0 but datasheet says undefined)
                verify_attr("V", 0, verified_flags)
            else:
                # Verify ACC
                expected_acc = (previous_values["ACC"] + addressed_value + previous_values["C"]) & 0xFF
                verify_attr("ACC", expected_acc, verified_regs)

                verify_attr("N", (expected_acc & 0x80) != 0, verified_flags)
                verify_attr("Z", expected_acc == 0, verified_flags)

                expected_carry = (
                    previous_values["ACC"] + addressed_value + previous_values["C"]
                ) > 0xFF
                verify_attr("C", expected_carry, verified_flags)

                # Verify Overflow flag # TODO: compare with simulator
                sign_bit = 0x80  # Mask for the sign bit
                operand_sign = (addressed_value & sign_bit) != 0
                acc_sign = (previous_values["ACC"] & sign_bit) != 0
                result_sign = (expected_acc & sign_bit) != 0

                # Overflow occurs if the signs of the two operands are the same, but the result's sign is different.
                expected_overflow = (operand_sign == acc_sign) and (result_sign != acc_sign)
                verify_attr("V", expected_overflow, verified_flags)

        elif op.name == "SBC":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            if previous_values["D"]:
                # BCD mode subtraction
                acc = previous_values["ACC"]
                operand = addressed_value
                borrow = (~previous_values["C"] & 1)

                lo_nibble = (acc & 0x0F) - (operand & 0x0F) - borrow
                if lo_nibble < 0:
                    lo_nibble -= 6

                hi_nibble = (acc >> 4) - (operand >> 4) - (lo_nibble < 0)
                if hi_nibble < 0:
                    hi_nibble -= 6
                    expected_carry = 0
                else:
                    expected_carry = 1

                expected_acc = ((hi_nibble << 4) | (lo_nibble & 0x0F)) & 0xFF
                verify_attr("ACC", expected_acc, verified_regs)
                verify_attr("C", expected_carry, verified_flags)
                verify_attr("Z", expected_acc == 0, verified_flags)
                verify_attr("N", (expected_acc & 0x80) != 0, verified_flags)
                # in decimal mode V is undefined (actually on original 6502 it is not always 0 but datasheet says undefined)
                verify_attr("V", 0, verified_flags)
            else:
                result = (
                    previous_values["ACC"] - addressed_value - (~previous_values["C"] & 1)
                )
                # Check if borrow occurred
                if result < 0:
                    expected_carry = 0 # Borrow occured -> unset carry
                    result += 256 # Wrap around to simulate 8-bit unsigned subtraction
                else:
                    expected_carry = 1  # No borrow -> set carry

                expected_acc = result & 0xFF  # Mask to 8 bits
                verify_attr("ACC", expected_acc, verified_regs)

                verify_attr("N", (expected_acc & 0x80) != 0, verified_flags)
                verify_attr("Z", expected_acc == 0, verified_flags)
                verify_attr("C", expected_carry, verified_flags)

                # Overflow flag is set if there is a signed overflow
                sign_bit = 0x80  # Mask for the sign bit
                operand_sign = (addressed_value & sign_bit) != 0
                acc_sign = (previous_values["ACC"] & sign_bit) != 0
                result_sign = (expected_acc & sign_bit) != 0

                # Overflow occurs if the signs of the two operands are the same, but the result's sign is different.
                expected_overflow = (operand_sign == acc_sign) and (result_sign != acc_sign)
                verify_attr("V", expected_overflow, verified_flags)

        elif op.name == "STA":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            expected_mem = copy.deepcopy(previous_mem)
            expected_mem[target_addr] = previous_values["ACC"]
            verify_memory(expected_mem, mem)

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

        elif op.name == "LDA":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_acc = addressed_value
            verify_attr("ACC", expected_acc, verified_regs)
            verify_attr("N", (expected_acc & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_acc == 0, verified_flags)

        elif op.name == "CMP":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            result = previous_values["ACC"] - addressed_value
            # Wrap around for negative values
            if result < 0:
                result += 256  # Wrap around to simulate 8-bit unsigned subtraction

            verify_attr("N", (result & 0x80) != 0, verified_flags)
            verify_attr("Z", result == 0, verified_flags)
            verify_attr("C", previous_values["ACC"] >= addressed_value, verified_flags)

        elif op.name == "CPY":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            result = previous_values["Y"] - addressed_value
            # Wrap around for negative values
            if result < 0:
                result += 256  # Wrap around to simulate 8-bit unsigned subtraction

            verify_attr("N", (result & 0x80) != 0, verified_flags)
            verify_attr("Z", result == 0, verified_flags)
            verify_attr("C", previous_values["Y"] >= addressed_value, verified_flags)

        elif op.name == "CPX":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            result = previous_values["X"] - addressed_value
            # Wrap around for negative values
            if result < 0:
                result += 256  # Wrap around to simulate 8-bit unsigned subtraction

            verify_attr("N", (result & 0x80) != 0, verified_flags)
            verify_attr("Z", result == 0, verified_flags)
            verify_attr("C", previous_values["X"] >= addressed_value, verified_flags)

        elif op.name == "TAX":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_x = previous_values["ACC"]
            verify_attr("X", expected_x, verified_regs)
            verify_attr("N", (expected_x & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_x == 0, verified_flags)

        elif op.name == "TAY":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_y = previous_values["ACC"]
            verify_attr("Y", expected_y, verified_regs)
            verify_attr("N", (expected_y & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_y == 0, verified_flags)

        elif op.name == "TXA":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_acc = previous_values["X"]
            verify_attr("ACC", expected_acc, verified_regs)
            verify_attr("N", (expected_acc & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_acc == 0, verified_flags)

        elif op.name == "TYA":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_acc = previous_values["Y"]
            verify_attr("ACC", expected_acc, verified_regs)
            verify_attr("N", (expected_acc & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_acc == 0, verified_flags)

        elif op.name == "TSX":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_x = previous_values["SP"]
            verify_attr("X", expected_x, verified_regs)
            verify_attr("N", (expected_x & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_x == 0, verified_flags)

        elif op.name == "TXS":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_sp = previous_values["X"]
            verify_attr("SP", expected_sp, verified_regs)

        elif op.name == "LDY":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_y = addressed_value
            verify_attr("Y", expected_y, verified_regs)
            verify_attr("N", (expected_y & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_y == 0, verified_flags)

        elif op.name == "LDX":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_x = addressed_value
            verify_attr("X", expected_x, verified_regs)
            verify_attr("N", (expected_x & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_x == 0, verified_flags)

        elif op.name == "STY":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            expected_mem = copy.deepcopy(previous_mem)
            expected_mem[target_addr] = previous_values["Y"]
            verify_memory(expected_mem, mem)

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

        elif op.name == "STX":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            expected_mem = copy.deepcopy(previous_mem)
            expected_mem[target_addr] = previous_values["X"]
            verify_memory(expected_mem, mem)

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

        elif op.name == "INC":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            expected_mem = copy.deepcopy(previous_mem)
            incremented_value = (addressed_value + 1) & 0xFF
            expected_mem[target_addr] = incremented_value
            verify_memory(expected_mem, mem)

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("N", (incremented_value & 0x80) != 0, verified_flags)
            verify_attr("Z", incremented_value == 0, verified_flags)

        elif op.name == "DEC":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")
            expected_mem = copy.deepcopy(previous_mem)
            decremented_value = addressed_value - 1
            if decremented_value < 0: # handle underflow
                decremented_value += 256
            expected_mem[target_addr] = decremented_value
            verify_memory(expected_mem, mem)

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("N", (decremented_value & 0x80) != 0, verified_flags)
            verify_attr("Z", decremented_value == 0, verified_flags)

        elif op.name == "INX":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_x = (previous_values["X"] + 1) & 0xFF
            verify_attr("X", expected_x, verified_regs)
            verify_attr("N", (expected_x & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_x == 0, verified_flags)

        elif op.name == "INY":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_y = (previous_values["Y"] + 1) & 0xFF
            verify_attr("Y", expected_y, verified_regs)
            verify_attr("N", (expected_y & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_y == 0, verified_flags)

        elif op.name == "DEX":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_x = (previous_values["X"] - 1)
            if expected_x < 0: # handle underflow
                expected_x += 256
            verify_attr("X", expected_x, verified_regs)
            verify_attr("N", (expected_x & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_x == 0, verified_flags)

        elif op.name == "DEY":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_y = (previous_values["Y"] - 1)
            if expected_y < 0: # handle underflow
                expected_y += 256
            verify_attr("Y", expected_y, verified_regs)
            verify_attr("N", (expected_y & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_y == 0, verified_flags)

        elif op.name == "SEC":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("C", 1, verified_flags)

        elif op.name == "CLC":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("C", 0, verified_flags)

        elif op.name == "SEI":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("I", 1, verified_flags)

        elif op.name == "CLI":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("I", 0, verified_flags)

        elif op.name == "SED":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("D", 1, verified_flags)

        elif op.name == "CLD":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("D", 0, verified_flags)

        elif op.name == "CLV":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("V", 0, verified_flags)

        ########## Arithmetic Operations ##########
        elif op.name == "ASL":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            shifted_value = (addressed_value << 1) & 0xFF

            if op.addressing == "acc":
                verify_attr("ACC", shifted_value, verified_regs)
            else:
                expected_mem = copy.deepcopy(previous_mem)
                expected_mem[target_addr] = shifted_value
                verify_memory(expected_mem, mem)

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)
            verify_attr("C", (addressed_value & 0x80) != 0, verified_flags)
            verify_attr("N", (shifted_value & 0x80) != 0, verified_flags)
            verify_attr("Z", shifted_value == 0, verified_flags)

        elif op.name == "ROL":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            rotated_value = ((addressed_value << 1) & 0xFF) | previous_values["C"]

            if op.addressing == "acc":
                verify_attr("ACC", rotated_value, verified_regs)
            else:
                expected_mem = copy.deepcopy(previous_mem)
                expected_mem[target_addr] = rotated_value
                verify_memory(expected_mem, mem)

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)
            verify_attr("C", (addressed_value & 0x80) != 0, verified_flags)
            verify_attr("N", (rotated_value & 0x80) != 0, verified_flags)
            verify_attr("Z", rotated_value == 0, verified_flags)

        elif op.name == "LSR":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            shifted_value = addressed_value >> 1

            if op.addressing == "acc":
                verify_attr("ACC", shifted_value, verified_regs)
            else:
                expected_mem = copy.deepcopy(previous_mem)
                expected_mem[target_addr] = shifted_value
                verify_memory(expected_mem, mem)

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)
            verify_attr("C", (addressed_value & 0x01) != 0, verified_flags)
            verify_attr("N", (shifted_value & 0x80) != 0, verified_flags)
            verify_attr("Z", shifted_value == 0, verified_flags)

        elif op.name == "ROR":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            rotated_value = (addressed_value >> 1) | (previous_values["C"] << 7)

            if op.addressing == "acc":
                verify_attr("ACC", rotated_value, verified_regs)
            else:
                expected_mem = copy.deepcopy(previous_mem)
                expected_mem[target_addr] = rotated_value
                verify_memory(expected_mem, mem)

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)
            verify_attr("C", (addressed_value & 0x01) != 0, verified_flags)
            verify_attr("N", (rotated_value & 0x80) != 0, verified_flags)
            verify_attr("Z", rotated_value == 0, verified_flags)

        elif op.name == "BRK":
            # TODO: varying cycle count
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            # if previous_values["I"] == 1:
            #     verify_memory(previous_mem, mem)
            #     check_unaffected(previous_values, op.affected_flags, op.affected_regs)
            #     verify_attr("PC", previous_values["PC"] + 2, verified_regs)
            #     verify_attr("SP", previous_values["SP"], verified_regs)
            # else:
            expected_mem = copy.deepcopy(previous_mem)
            expected_mem[previous_values["SP"]] = (previous_values["PC"] + 2) >> 8 # PCH
            expected_mem[previous_values["SP"] - 1] = (previous_values["PC"] + 2) & 0xFF # PCL
            expected_mem[previous_values["SP"] - 2] = (
                (previous_values["N"] << 7) |
                (previous_values["V"] << 6) |
                (1 << 5) |  # Ignore flag (TODO: check if this is correct)
                (1 << 4) |  # Break flag
                (previous_values["D"] << 3) |
                (previous_values["I"] << 2) |
                (previous_values["Z"] << 1) |
                (previous_values["C"] << 0)
            ) # STATUS

            verify_memory(expected_mem, mem)

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)
            verify_attr("I", 1, verified_flags)
            verify_attr("SP", previous_values["SP"] - 3, verified_regs)
            expected_pc = irq_addr
            verify_attr("PC", expected_pc, verified_regs)
            mem_index = expected_pc

        elif op.name == "RTI":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            expected_status = mem[previous_values["SP"] + 1]
            expected_pc = (mem[previous_values["SP"] + 3] << 8) + mem[previous_values["SP"] + 2]

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("N", (expected_status & 0b10000000) != 0, verified_flags)
            verify_attr("V", (expected_status & 0b01000000) != 0, verified_flags)
            verify_attr("B", previous_values["B"], verified_flags)
            verify_attr("D", (expected_status & 0b00001000) != 0, verified_flags)
            verify_attr("I", (expected_status & 0b00000100) != 0, verified_flags)
            verify_attr("Z", (expected_status & 0b00000010) != 0, verified_flags)
            verify_attr("C", (expected_status & 0b00000001) != 0, verified_flags)
            verify_attr("SP", previous_values["SP"] + 3, verified_regs)
            verify_attr("PC", expected_pc, verified_regs)
            mem_index = expected_pc

        elif op.name == "RTS":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            pulled_pc = (mem[previous_values["SP"] + 2] << 8) + mem[previous_values["SP"] + 1]
            expected_pc = pulled_pc + 1

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)
            verify_attr("SP", previous_values["SP"] + 2, verified_regs)
            verify_attr("PC", expected_pc, verified_regs)
            mem_index = expected_pc

        elif op.name == "JSR":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            expected_mem = copy.deepcopy(previous_mem)
            stored_pc = previous_values["PC"] + 2
            expected_mem[previous_values["SP"]] = (stored_pc) >> 8
            expected_mem[previous_values["SP"] - 1] = (stored_pc) & 0xFF
            verify_memory(expected_mem, mem)

            expected_pc = (mem[opcode_addr + 2] << 8) + mem[opcode_addr + 1]

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)
            verify_attr("SP", previous_values["SP"] - 2, verified_regs)
            verify_attr("PC", expected_pc, verified_regs)
            mem_index = expected_pc

        elif op.name == "JMP":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            following_addr = (mem[opcode_addr + 2] << 8) + mem[opcode_addr + 1]
            if op.addressing == "abs":
                expected_pc = following_addr
            if op.addressing == "ind":
                expected_pc = (mem[following_addr + 1] << 8) + mem[following_addr]

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)
            verify_attr("PC", expected_pc, verified_regs)
            mem_index = expected_pc

        # Branch instructions
        elif op.name in ["BPL", "BMI", "BVC", "BVS", "BCC", "BCS", "BNE", "BEQ"]:
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            if (op.name == "BPL" and previous_values["N"] == 0) \
            or (op.name == "BMI" and previous_values["N"] == 1) \
            or (op.name == "BVC" and previous_values["V"] == 0) \
            or (op.name == "BVS" and previous_values["V"] == 1) \
            or (op.name == "BCC" and previous_values["C"] == 0) \
            or (op.name == "BCS" and previous_values["C"] == 1) \
            or (op.name == "BNE" and previous_values["Z"] == 0) \
            or (op.name == "BEQ" and previous_values["Z"] == 1):
                # branch is taken
                await runCycles(1)
                expected_pc = target_addr
            else:
                expected_pc = previous_values["PC"] + 2

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)
            verify_attr("PC", expected_pc, verified_regs)
            mem_index = expected_pc

        elif op.name == "PHP":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            expected_mem = copy.deepcopy(previous_mem)
            expected_mem[previous_values["SP"]] = (
                (previous_values["N"] << 7) |
                (previous_values["V"] << 6) |
                (1 << 5) |  # Ignore flag (TODO: check if this is correct)
                (1 << 4) |  # Break flag
                (previous_values["D"] << 3) |
                (previous_values["I"] << 2) |
                (previous_values["Z"] << 1) |
                (previous_values["C"] << 0)
            )
            verify_memory(expected_mem, mem)

            check_unaffected(previous_values, op.affected_flags, op.affected_regs)
            verify_attr("SP", previous_values["SP"] - 1, verified_regs)

        elif op.name == "PLP":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            expected_status = mem[previous_values["SP"] + 1]

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("N", (expected_status & 0b10000000) != 0, verified_flags)
            verify_attr("V", (expected_status & 0b01000000) != 0, verified_flags)
            verify_attr("B", previous_values["B"], verified_flags)
            verify_attr("D", (expected_status & 0b00001000) != 0, verified_flags)
            verify_attr("I", (expected_status & 0b00000100) != 0, verified_flags)
            verify_attr("Z", (expected_status & 0b00000010) != 0, verified_flags)
            verify_attr("C", (expected_status & 0b00000001) != 0, verified_flags)
            verify_attr("SP", previous_values["SP"] + 1, verified_regs)

        elif op.name == "PHA":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            expected_mem = copy.deepcopy(previous_mem)
            expected_mem[previous_values["SP"]] = previous_values["ACC"]

            verify_memory(expected_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("SP", previous_values["SP"] - 1, verified_regs)

        elif op.name == "PLA":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            expected_acc = mem[previous_values["SP"] + 1]

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            verify_attr("ACC", expected_acc, verified_regs)
            verify_attr("N", (expected_acc & 0x80) != 0, verified_flags)
            verify_attr("Z", expected_acc == 0, verified_flags)
            verify_attr("SP", previous_values["SP"] + 1, verified_regs)

        elif op.name == "BIT":
            print(f"### mem[{hex(opcode_addr)}]: {op}:", end="")

            verify_memory(previous_mem, mem)
            check_unaffected(previous_values, op.affected_flags, op.affected_regs)

            expected_v = (addressed_value & 0b01000000) != 0
            expected_n = (addressed_value & 0b10000000) != 0
            expected_z = (previous_values["ACC"] & addressed_value) == 0

            verify_attr("V", expected_v, verified_flags)
            verify_attr("N", expected_n, verified_flags)
            verify_attr("Z", expected_z, verified_flags)

        elif op.name == "NOP":
            pass
        elif op.name == "END":
            break

        else:
            # assert No validator for this opcode
            assert False, f"No validator for operation {op.name}"

        # if op.name not in ["JMP", "JSR", "BRK", "RTI", "RTS"]:
        # if PC has not been verified manually, verify it automatically
        if "PC" not in verified_regs:
            verify_attr("PC", opcode_addr + op.bytes, verified_regs)
        if set(verified_regs) != set(op.affected_regs):
            assert (
                False
            ), f"Validated registers do nat match the ones in the opcode declaration. Expected {op.affected_regs}, verified {verified_regs}"
        if set(verified_flags) != set(op.affected_flags):
            assert (
                False
            ), f"Validated flags do nat match the ones in the opcode declaration. Expected {op.affected_flags}, verified {verified_flags}"

        print(f" OK")
        # print("\n")
