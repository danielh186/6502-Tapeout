// States
`define ST_RESET          5'h00
`define ST_DECODE         5'h01
`define ST_FETCH_OPERAND_LOW  5'h02
`define ST_FETCH_OPERAND_HIGH 5'h03
`define ST_EXEC           5'h04
`define ST_FETCH_IND_ADDR_LOW 5'h05
`define ST_FETCH_IND_ADDR_HIGH 5'h06
`define ST_WRITE          5'h07
`define ST_PUSH_PCL       5'h08
`define ST_PUSH_PCH       5'h09
`define ST_PUSH_STATUS    5'h0A
`define ST_JSR_JUMP       5'h0B
`define ST_POP_PCL        5'h0C
`define ST_POP_PCH        5'h0D
`define ST_WRITE_PCH      5'h0E
`define ST_GET_IV_LOW     5'h0F
`define ST_GET_IV_HIGH    5'h10
`define ST_WRITE_INTERRUPT_VECTOR 5'h11
`define ST_BRANCH_FETCH   5'h12


// ########## ALU Operations ##########
`define OP_NOP  4'b0000  // NOP
`define OP_OR   4'b0001  // OR
`define OP_AND  4'b0010  // AND
`define OP_XOR  4'b0011  // XOR
`define OP_ADC  4'b0100  // ADD with carry
`define OP_SBC  4'b0101  // SUBTRACT with carry
`define OP_SUB  4'b0110  // SUBTRACT without carry
`define OP_ROL  4'b0111  // Rotate Left (ROL)
`define OP_ROR  4'b1000  // Rotate Right (ROR)

// ########## Implicit Addressing Modes ##########
`define INS_NOP 8'hEA // 2 cycle NOP
// Stack
`define INS_PHP 8'h08 // Push Processor Status
`define INS_PHA 8'h48 // Push Accumulator
`define INS_PLP 8'h28 // Pull Processor Status
`define INS_PLA 8'h68 // Pull Accumulator

// Increment/Decrement
`define INS_INY 8'hC8 // Increment Y
`define INS_DEY 8'h88 // Decrement Y
`define INS_INX 8'hE8 // Increment X
`define INS_DEX 8'hCA // Decrement X

// Set and Clear flags
`define INS_SEC 8'h38 // Set Carry
`define INS_CLC 8'h18 // Clear Carry
`define INS_SEI 8'h78 // Set Interrupt Disable
`define INS_CLI 8'h58 // Clear Interrupt Disable

`define INS_SED 8'hF8 // Set Decimal
`define INS_CLD 8'hD8 // Clear Decimal
`define INS_CLV 8'hB8 // Clear Overflow

// Transfer
`define INS_TAY 8'hA8 // Transfer ACC to Y
`define INS_TYA 8'h98 // Transfer ACC to Y
`define INS_TAX 8'hAA // Transfer ACC to X
`define INS_TXA 8'h8A // Transfer X to ACC
`define INS_TXS 8'h9A // Transfer X to Stack Pointer
`define INS_TSX 8'hBA // Transfer Stack Pointer to X

// Implied accumulator operations
`define INS_ASLA 8'h0A // Arithmetic Shift Left Accumulator
`define INS_ROLA 8'h2A // Rotate Left Accumulator
`define INS_LSRA  8'h4A // Logical Shift Right Accumulator
`define INS_RORA 8'h6A // Rotate Right Accumulator

// Interrupts
`define INS_BRK 8'h00
`define INS_JSR 8'h20
`define INS_RTI 8'h40
`define INS_RTS 8'h60

// Jumps
`define INS_JMP 8'h4C
`define INS_JMP_IND 8'h6C

// Zero Page Y Indexed
`define INS_LDX_ZPY 8'hB6
`define INS_STX_ZPY 8'h96

// Branches
`define INS_BPL 8'h10 // Branch if Positive (N=0)
`define INS_BMI 8'h30 // Branch if Negative (N=1)
`define INS_BVC 8'h50 // Branch if Overflow Clear (V=0)
`define INS_BVS 8'h70 // Branch if Overflow Set (V=1)
`define INS_BCC 8'h90 // Branch if Carry Clear (C=0)
`define INS_BCS 8'hB0 // Branch if Carry Set (C=1)
`define INS_BNE 8'hD0 // Branch if Not Equal (Z=0)
`define INS_BEQ 8'hF0 // Branch if Equal (Z=1)

`define INS_BIT_ZPG 8'h24
`define INS_BIT_ABS 8'h2C
