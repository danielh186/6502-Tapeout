`timescale 1ns/1ps
`include "include.v"

module CPU (
    input  wire        clk,
    input  wire        reset_n,
    input wire RDY, // Ready signal (wait for memory) -> "pauses execution of the CPU until the signal is high"

    input wire NMI_n, // Non-maskable interrupt
    input wire IRQ_n, // Interrupt request
    input wire SO, // Set Overflow flag
    output reg SYNC, // high on opcode fetch cycle (low otherwise)


    // External Memory Interface
    output reg [15:0]  addr,
    inout wire [7:0]   data,   // Shared data bus
    output reg [1:0]   RW, // 1 = read, 0 = write

    // Debug:
    output reg[4:0] state

);
// Initialize outputs to known values at time zero.
initial begin
    $dumpfile("wave_output.vcd");
    $dumpvars(0,CPU);
end

// Registers for storing values (if needed for later processing)
reg [7:0] data_out; // Data to drive the bus when writing
wire [7:0] data_in;
assign data_in = data;
// Tri-state assignment: drive the bus when writing; otherwise, high impedance.
assign data = ~RW ? data_out : 8'bz; // Drive when writing, high-Z otherwise

// Internal registers
reg [7:0] SP; // Stack Pointer
reg [7:0]   ACC;
reg [7:0]   X;
reg [7:0]   Y;
reg [15:0]  PC;
reg [7:0] IR;          // Instruction register
reg [7:0] operand;     // Immediate operand
reg [15:0]  operand_addr;

// Flags
reg N;  // Negative flag
reg V;  // Overflow flag
reg B;  // Break flag
reg D;  // Decimal flag
reg I;  // Interrupt Disable flag
reg Z;  // Zero flag
reg C;  // Carry flag

// reg [4:0] state;

reg [7:0] INTERNAL_ALU_A;
reg [7:0] INTERNAL_ALU_B;
reg [8:0] INTERNAL_ALU_TMP_OUT;
reg [7:0] INTERNAL_ALU_OUT;

reg nmi_pending; // Flag to indicate NMI request
reg irq_pending; // Flag to indicate IRQ request
reg performing_nmi; // Flag to indicate that NMI is being performed
reg performing_irq; // Flag to indicate that IRQ is being performed

// DEBUG TASK
task print_debug;
begin
    $display("[CPU DBG] time=%0dns state=%0d PC=%04X IR=%02X operand=%02X",
             $time, state, PC, IR, operand);
    $display("[CPU DBG] DEBUG ACC: %02X, IR=%02X, state=%d", ACC, IR, state);
end
endtask

task prepare_next_fetch;
begin
    if (nmi_pending) begin
        data_out <= PC[15:8]; // Push high byte of PC
        addr <= SP;
        SP <= SP - 1;
        RW <= 1'b0; // write
        performing_nmi <= 1'b1;
        state <= `ST_PUSH_PCL;
    end
    else if (irq_pending) begin
        data_out <= PC[15:8]; // Push high byte of PC
        addr <= SP;
        SP <= SP - 1;
        RW <= 1'b0; // write
        performing_irq <= 1'b1;
        state <= `ST_PUSH_PCL;
    end
    else begin
        addr <= PC;
        RW <= 1'b1; // read
        state <= `ST_DECODE;
        SYNC = 1'b1; // high on opcode fetch cycle (low otherwise)
    end
end
endtask

// Branch handling
task branch_taken;
begin
    addr <= PC;
    RW <= 1'b1; // read
    state <= `ST_BRANCH_FETCH;
end
endtask

task branch_not_taken;
begin
    PC = PC + 1;
    prepare_next_fetch();
end
endtask

always @(negedge NMI_n) begin
    if (NMI_n == 1'b0 && !nmi_pending) begin
        nmi_pending <= 1'b1;
    end
end

always @(posedge clk or negedge reset_n) begin
    SYNC = 1'b0; // high on opcode fetch cycle (low otherwise)
    if (SO) V <= 1; // Set Overflow flag
    if (IRQ_n == 1'b0 && !I && !irq_pending) begin
        irq_pending <= 1'b1;
    end
    // Reset
    if (!reset_n) begin
        // initialize registers
        PC       <= 16'h0000;
        SP       <= 8'hFF;
        ACC      <= 8'h00;
        X        <= 8'h00;
        Y        <= 8'h00;
        IR       <= 8'hEA;       // default NOP
        operand  <= 8'h00;
        nmi_pending <= 1'b0;
        irq_pending <= 1'b0;
        performing_nmi <= 1'b0;
        performing_irq <= 1'b0;
        state    <= `ST_RESET;

        N <=  1'b0;
        V <=  1'b0;
        B <=  1'b0;
        D <=  1'b0;
        I <=  1'b0;
        Z <=  1'b0;
        C <=  1'b0;

        addr     <= 16'h0000;
        // data_in  <= 8'h00;
        data_out <= 8'h00;
        RW <= 1'b1; // read
    end
    else if (RDY) begin // Wait for memory to be ready
        `ifdef DEBUG
        print_debug;  // Print state info each clock
        `endif

        case (state)
            //-------------------------------------------------------
            `ST_RESET: begin // State 0
                IR <= `INS_JMP;
                RW <= 1'b1; // read
                addr <= 16'hFFFC;
                operand_addr <= 16'h0000;
                state <= `ST_FETCH_OPERAND_LOW;
            end

            //-------------------------------------------------------
            `ST_DECODE: begin // State 2
                IR   = data_in;
                PC   = PC + 1;

                // if opcode in binary is aaabbbcc -> bbb contains the addressing type (with a few exceptions)
                // REFERENCE: 6502 instruction layout: https://www.masswerk.at/6502/6502_instruction_set.html#layout

                casez (IR)
                    // Immediate addressing
                    8'b???01001, // a=? b=2 c=1
                    8'b1??00000, // a=(4),5,6,7 b=0 c=0
                    8'hA2        // a=5 b=0 c=2
                    : begin
                        operand_addr <= PC;
                        addr  <= PC;
                        RW <= 1'b1; // read
                        state <= `ST_EXEC;
                    end

                    // Absolute addressing
                    8'b???011??, // abs
                    8'b???001??, // zpg
                    8'b???111??, // abs,X
                    8'b???101??, // zpg,X
                    8'b???11001, // abs,Y
                    8'hBE,       // LDX abs,Y
                    8'b???00001, // ind,X
                    8'b???10001, // ind,Y
                    `INS_JMP,    // basically immediate addressing with 16 bit operand
                    // `INS_JSR,    // basically INS_JMP with stack push of return address
                    `INS_JMP_IND // basically absoulte addressing
                    : begin
                        operand_addr <= 16'h0000;
                        addr  <= PC;
                        RW <= 1'b1; // read
                        state <= `ST_FETCH_OPERAND_LOW;
                    end

                    // ##### Added for Branches #####
                    `INS_BPL: if (N == 0) branch_taken(); else branch_not_taken();
                    `INS_BMI: if (N == 1) branch_taken(); else branch_not_taken();
                    `INS_BVC: if (V == 0) branch_taken(); else branch_not_taken();
                    `INS_BVS: if (V == 1) branch_taken(); else branch_not_taken();
                    `INS_BCC: if (C == 0) branch_taken(); else branch_not_taken();
                    `INS_BCS: if (C == 1) branch_taken(); else branch_not_taken();
                    `INS_BNE: if (Z == 0) branch_taken(); else branch_not_taken();
                    `INS_BEQ: if (Z == 1) branch_taken(); else branch_not_taken();

                    `INS_JSR: begin // JSR
                        PC = PC + 1; // push PC + 2 (+1 already above) providing an extra byte of spacing for a break mark (identifying a reason for the break.)
                        data_out <= PC[15:8]; // Push high byte of PC
                        addr <= SP;
                        RW <= 1'b0; // write
                        SP <= SP - 1;
                        state <= `ST_PUSH_PCL;
                    end
                    // ########## Implied addressing ##########
                    `INS_RTI: begin
                        // Pop status
                        addr <= SP + 1;
                        SP <= SP + 1;
                        RW <= 1'b1; // read
                        state <= `ST_POP_PCL;
                    end
                    `INS_RTS: begin
                        // Pop PC_low
                        addr <= SP + 1;
                        SP <= SP + 1;
                        RW <= 1'b1; // read
                        state <= `ST_POP_PCH;
                    end
                    `INS_BRK: begin
                        PC = PC + 1; // push PC + 2 (+1 already above) providing an extra byte of spacing for a break mark (identifying a reason for the break.)
                        data_out <= PC[15:8]; // Push high byte of PC
                        addr <= SP;
                        SP <= SP - 1;
                        RW <= 1'b0; // write
                        state <= `ST_PUSH_PCL;
                    end

                    // ##### Stack Operations #####
                    `INS_PHP: begin // Push status to stack
                        // difference: takes only 2 cycle instead of 3
                        data_out <= {N, V, 1'b1, 1'b1, D, I, Z, C};
                        addr  <= SP;
                        RW <= 1'b0; // write
                        SP    <= SP - 1;
                        state <= `ST_WRITE;
                    end
                    `INS_PHA: begin // Push ACC to stack
                        // difference: takes only 2 cycle instead of 3
                        data_out <= ACC;
                        addr  <= SP;
                        RW <= 1'b0; // write
                        SP    <= SP - 1;
                        state <= `ST_WRITE;
                    end
                    `INS_PLP: begin // Pull status from stack
                        // difference: takes only 2 cycle instead of 4
                        SP    = SP + 1;

                        addr  <= SP;
                        RW <= 1'b1; // read
                        state <= `ST_EXEC;
                    end
                    `INS_PLA: begin // Pull ACC from stack
                        // difference: takes only 2 cycle instead of 4
                        SP    = SP + 1;

                        addr  <= SP;
                        RW <= 1'b1; // read
                        state <= `ST_EXEC;
                    end

                    // ##### Increment/Decrement #####
                    `INS_INX: begin
                        // difference: cycles
                        X = X + 1;
                        N <= X[7];
                        Z <= ~|X;

                        prepare_next_fetch();
                    end
                    `INS_DEX: begin
                        // difference: cycles
                        X = X - 1;
                        N <= X[7];
                        Z <= ~|X;

                        prepare_next_fetch();
                    end
                    `INS_DEY: begin // Decrement Y
                        // difference: cycles
                        Y = Y - 1;
                        N <= Y[7];
                        Z <= ~|Y;

                        prepare_next_fetch();
                    end
                    `INS_INY: begin // Increment Y
                        // difference: cycles
                        Y = Y + 1;
                        N <= Y[7];
                        Z <= ~|Y;

                        prepare_next_fetch();
                    end


                    // ##### Transfer Operations #####
                    `INS_TYA: begin // Transfer Y to ACC
                        // difference: cycles
                        ACC <= Y;
                        N   <= Y[7];
                        Z   <= ~|Y;

                        prepare_next_fetch();
                    end
                    `INS_TAY: begin // Transfer ACC to Y
                        // difference: cycles
                        Y <= ACC;
                        N <= ACC[7];
                        Z <= ~|ACC;

                        prepare_next_fetch();
                    end
                    `INS_TXA: begin // Transfer X to ACC
                        // difference: cycles
                        ACC <= X;
                        N   <= X[7];
                        Z   <= ~|X;

                        prepare_next_fetch();
                    end
                    `INS_TAX: begin // Transfer ACC to X
                        // difference: cycles
                        X <= ACC;
                        N <= ACC[7];
                        Z <= ~|ACC;

                        prepare_next_fetch();
                    end
                    `INS_TXS: begin // Transfer X to SP
                        // difference: cycles
                        SP <= X;

                        prepare_next_fetch();
                    end
                    `INS_TSX: begin // Transfer SP to X
                        // difference: cycles
                        X <= SP;
                        N <= SP[7];
                        Z <= ~|SP;

                        prepare_next_fetch();
                    end

                    // ##### Set and Clear flags #####
                    `INS_SEC: begin // Set Carry
                        // difference: cycles
                        C = 1;

                        prepare_next_fetch();
                    end
                    `INS_CLC: begin // Clear Carry
                        // difference: cycles
                        C = 0;

                        prepare_next_fetch();
                    end
                    `INS_SEI: begin // Set Interrupt Disable
                        // difference: cycles
                        I = 1;

                        prepare_next_fetch();
                    end
                    `INS_CLI: begin // Clear Interrupt Disable
                        // difference: cycles
                        I = 0;

                        prepare_next_fetch();
                    end
                    `INS_SED: begin // Set Decimal
                        // difference: cycles
                        D = 1;

                        prepare_next_fetch();
                    end
                    `INS_CLD: begin // Clear Decimal
                        // difference: cycles
                        D = 0;

                        prepare_next_fetch();
                    end
                    `INS_CLV: begin // Clear Overflow
                        // difference: cycles
                        V = 0;

                        prepare_next_fetch();
                    end
                    `INS_ASLA: begin
                        {C, ACC} = {ACC, 1'b0};
                        N <= ACC[7];
                        Z <= ~|ACC;

                        prepare_next_fetch();
                    end
                    `INS_ROLA: begin
                        {C, ACC} = {ACC, C};
                        N <= ACC[7];
                        Z <= ~|ACC;

                        prepare_next_fetch();
                    end
                    `INS_LSRA: begin
                        {ACC, C} = {1'b0, ACC};
                        N <= ACC[7]; // (always 0 because of shifting in a 0)
                        Z <= ~|ACC;

                        prepare_next_fetch();
                    end
                    `INS_RORA: begin
                        {ACC, C} = {C, ACC};
                        N <= ACC[7];
                        Z <= ~|ACC;

                        prepare_next_fetch();
                    end

                    `INS_NOP: state <= `ST_EXEC;

                    // OTHER Exceptions (unknown, error)
                    8'b?????0?0: begin
                        $display("###\n###\n### DECODE: UNKNOWN EXCEPTION IR=%16x \n###\n###\n###", IR);
                    end
                    default: begin
                        $display("###\n###\n###\n DECODE: UNKNOWN IR=%16x \n###\n###\n###", IR);

                        state <= `ST_EXEC;
                    end
                endcase
            end

            // Fetch low byte of address for absolute addressing of operand
            `ST_FETCH_OPERAND_LOW: begin // State 3
                operand_addr = {8'h0, data_in};  // Set low byte of addr to data_in and high byte to 0
                // by default read (will be overwritten below if store instruction with zero page addressing)
                RW <= 1'b1; // read

                casez (IR)
                    8'b???001??: begin // Zero page addressing
                        addr <= operand_addr;  // Set low byte of addr to data_in and high byte to 0
                        state <= `ST_EXEC;
                        casez (IR)
                            // Store instructions
                            8'b100???01: begin // STA
                                RW <= 1'b0; // write
                                data_out = ACC;
                            end
                            8'b100??110: begin // STX
                                RW <= 1'b0; // write
                                data_out = X;
                            end
                            8'b100??100: begin // STY
                                RW <= 1'b0; // write
                                data_out = Y;
                            end
                        endcase
                    end
                    8'b???101??: begin // Zero page X addressing
                        // Zero page Y exceptions for STX and LDX
                        if (IR == `INS_LDX_ZPY || IR == `INS_STX_ZPY) begin
                            operand_addr = (operand_addr[7:0] + Y[7:0]);
                        end else begin
                            operand_addr = (operand_addr[7:0] + X[7:0]);
                        end

                        casez (IR)
                            // Store instructions
                            8'b100???01: begin // STA
                                RW <= 1'b0; // write
                                data_out = ACC;
                            end
                            8'b100??110: begin // STX
                                RW <= 1'b0; // write
                                data_out = X;
                            end
                            8'b100??100: begin // STY
                                RW <= 1'b0; // write
                                data_out = Y;
                            end
                        endcase

                        // addr = operand_addr + X; // difference: (alternative) allows page crossing but needs 16 bit adder
                        // alternative2: Use the ALU with carry out to get one extra address bit -> problem: prevent carry out from getting written into status register (unwanted!!)
                        addr <= operand_addr;
                        state = `ST_EXEC;

                    end
                    8'b???00001: begin // Pre-Indexed Indirect
                        addr <= (operand_addr[7:0] + X[7:0]);
                        state <= `ST_FETCH_IND_ADDR_LOW; // fetch address for indirect addressing
                    end
                    8'b???10001: begin // Post-Indexed Indirect
                        addr <= operand_addr;
                        state <= `ST_FETCH_IND_ADDR_LOW; // fetch address for indirect addressing
                    end
                    default:  begin // Absolute
                        PC = PC + 1;
                        addr <= addr + 1;
                        state <= `ST_FETCH_OPERAND_HIGH;
                    end
                endcase
            end

            // Fetch high byte of address for absolute addressing of operand
            `ST_FETCH_OPERAND_HIGH: begin // State 4
                operand_addr[15:8] = data_in;
                casez (IR)
                    8'b???11001, 8'hBE: begin  // Absolute Y indexed
                        operand_addr = operand_addr + {8'b0, Y}; // like this page crossing does not take an extra cycle at the cost of needing to synthesize a 16 bit adder
                        addr <= operand_addr;

                        RW <= 1'b1; // read
                        state <= `ST_EXEC;
                    end
                    8'b???111??: begin // Absolute X indexed
                        operand_addr = operand_addr + {8'b0, X}; // like this page crossing does not take an extra cycle at the cost of needing to synthesize a 16 bit adder
                        addr <= operand_addr;

                        RW <= 1'b1; // read
                        state <= `ST_EXEC;
                    end
                    // TODO: I think this is already handled in ST_FETCH_OPERAND_LOW
                    // 8'b???10001: begin // Post-Indexed Indirect (ind_y)
                    //     addr <= operand_addr;

                    //     RW <= 1'b1; // read
                    //     state <= `ST_FETCH_IND_ADDR_LOW; // fetch address for indirect addressing
                    // end
                    `INS_JMP: begin // JMP abs
                        PC = operand_addr;

                        prepare_next_fetch();
                    end
                    `INS_JMP_IND: begin // JMP ind
                        addr <= operand_addr;
                        RW <= 1'b1; // read
                        state <= `ST_FETCH_IND_ADDR_LOW; // fetch address for indirect addressing
                    end
                    default: begin // Absolute addressing
                        addr <= operand_addr;

                        RW <= 1'b1; // read
                        state <= `ST_EXEC;
                    end
                endcase

                casez (IR)
                    // Store instructions -> overwrite default read/write signals
                    8'b100???01: begin // STA
                        RW <= 1'b0; // write
                        data_out = ACC;
                    end
                    8'b100??110: begin // STX
                        RW <= 1'b0; // write
                        data_out = X;
                    end
                    8'b100??100: begin // STY
                        RW <= 1'b0; // write
                        data_out = Y;
                    end
                endcase
            end

            `ST_FETCH_IND_ADDR_LOW: begin // State 6
                operand_addr <= {8'h0, data_in};  // Set low byte of addr to data_in and high byte to 0
                addr <= addr + 1;
                RW <= 1'b1; // read
                state <= `ST_FETCH_IND_ADDR_HIGH;
            end

            `ST_FETCH_IND_ADDR_HIGH: begin // State 7
                casez (IR)
                // todo: IS THIS RIGHT?
                    8'b???10001 : begin // Post-Indexed Indirect -> add Y register to address
                        operand_addr = operand_addr + {8'b0, Y}; // like this page crossing does not take an extra cycle at the cost of needing to synthesize a 16 bit adder
                    end
                    default: operand_addr[15:8] = data_in;
                endcase

                addr  = operand_addr;
                state = `ST_EXEC;

                casez (IR)
                    // Store instructions -> overwrite default read/write signals
                    8'b100???01: begin // STA
                        RW <= 1'b0; // write
                        data_out = ACC;
                    end
                    8'b100??110: begin // STX
                        RW <= 1'b0; // write
                        data_out = X;
                    end
                    8'b100??100: begin // STY
                        RW <= 1'b0; // write
                        data_out = Y;
                    end
                    `INS_JMP_IND: begin // JMP ind
                        PC = operand_addr;
                        prepare_next_fetch();
                    end

                    // Non-store instructions
                    default: begin
                        RW <= 1'b1; // read
                    end
                endcase
            end

            //-------------------------------------------------------
            // EXEC: handle ALU or direct loads
            //-------------------------------------------------------
            `ST_EXEC: begin // State 5
                operand = data_in;
                if (IR != `INS_PLA && IR != `INS_PLP) begin
                    PC = PC + 1;
                end

                // Default ALU signals
                casez (IR)
                    8'b011???01: begin // ADC

                        if (D) begin // Decimal mode
                            reg [4:0] lo_nibble;
                            reg [4:0] hi_nibble;
                            reg [1:0] carry_lo, carry_hi;

                            // Adjust lower nibble
                            lo_nibble = {1'b0, ACC[3:0]} + {1'b0, operand[3:0]} + {4'b0, C};
                            carry_lo  = (lo_nibble > 5'h9);
                            if (carry_lo) lo_nibble = lo_nibble + 5'h6;

                            // Adjust upper nibble
                            hi_nibble = {1'b0, ACC[7:4]} + {1'b0, operand[7:4]} + {4'b0, carry_lo};
                            carry_hi  = (hi_nibble > 5'h9);
                            if (carry_hi) hi_nibble = hi_nibble + 5'h6;

                            // Store result
                            ACC  <= {hi_nibble[3:0], lo_nibble[3:0]};
                            C    <= carry_hi; // BCD carry
                            Z    <= ~|{hi_nibble[3:0], lo_nibble[3:0]}; // Zero flag
                            N    <= hi_nibble[3]; // Negative flag (MSB)
                            V    <= 0; // In decimal mode, overflow flag is undefined
                        end else begin // Binary mode
                            INTERNAL_ALU_A = ACC;
                            INTERNAL_ALU_B = operand;
                            INTERNAL_ALU_TMP_OUT = INTERNAL_ALU_A + INTERNAL_ALU_B + C;

                            ACC  <= INTERNAL_ALU_TMP_OUT[7:0];
                            C    <= INTERNAL_ALU_TMP_OUT[8]; // 9th bit is carry-out
                            N    <= INTERNAL_ALU_TMP_OUT[7]; // Negative flag (MSB of result)
                            Z    <= ~|INTERNAL_ALU_TMP_OUT[7:0]; // Zero flag (1 if result is 0)
                            V    <= (INTERNAL_ALU_A[7] == INTERNAL_ALU_B[7]) && (INTERNAL_ALU_TMP_OUT[7] != INTERNAL_ALU_A[7]);
                        end

                        prepare_next_fetch();
                    end
                    8'b111???01: begin // SBC
                        if (D) begin // Decimal mode
                            reg [4:0] lo_nibble;
                            reg [4:0] hi_nibble;
                            reg       borrow_lo, borrow_hi;

                            // Adjust lower nibble
                            lo_nibble = {1'b0, ACC[3:0]} - {1'b0, operand[3:0]} - {4'b0, ~C};
                            borrow_lo = (lo_nibble[3:0] > ACC[3:0]); // Borrow occurs if result underflows
                            if (borrow_lo) lo_nibble = lo_nibble - 5'h6;

                            // Adjust upper nibble
                            hi_nibble = {1'b0, ACC[7:4]} - {1'b0, operand[7:4]} - {4'b0, borrow_lo};
                            borrow_hi = (hi_nibble > ACC[7:4]); // Borrow occurs if result underflows
                            if (borrow_hi) hi_nibble = hi_nibble - 5'h6;

                            // Store result
                            ACC  = {hi_nibble[3:0], lo_nibble[3:0]};
                            C    <= ~borrow_hi; // BCD borrow flag (opposite of normal carry)
                            Z    <= ~|ACC; // Zero flag
                            N    <= ACC[7]; // Negative flag (MSB)
                            V    <= 0; // Overflow flag is undefined in decimal mode
                        end else begin // Binary mode
                            INTERNAL_ALU_A = ACC;
                            INTERNAL_ALU_B = operand;
                            INTERNAL_ALU_TMP_OUT = {1'b0, INTERNAL_ALU_A} - {1'b0, INTERNAL_ALU_B} - {8'b0, ~C};

                            ACC  <= INTERNAL_ALU_TMP_OUT[7:0];
                            C    <= ~INTERNAL_ALU_TMP_OUT[8]; // 9th bit is borrow (opposite of carry)
                            N    <= INTERNAL_ALU_TMP_OUT[7]; // Negative flag (MSB of result)
                            Z    <= ~|INTERNAL_ALU_TMP_OUT[7:0]; // Zero flag (1 if result is 0)
                            V    <= (INTERNAL_ALU_A[7] == INTERNAL_ALU_B[7]) && (INTERNAL_ALU_TMP_OUT[7] != INTERNAL_ALU_A[7]);
                        end

                        prepare_next_fetch();
                    end

                    8'b000???01: begin // OR
                        ACC = operand | ACC;

                        N   <= ACC[7]; // Negative flag (MSB of result)
                        Z   <= ~|ACC; // Zero flag (1 if result is 0)

                        prepare_next_fetch();
                    end
                    8'b001???01: begin // AND
                        ACC = operand & ACC;

                        N   <= ACC[7]; // Negative flag (MSB of result)
                        Z   <= ~|ACC; // Zero flag (1 if result is 0)

                        prepare_next_fetch();
                    end
                    8'b010???01: begin // XOR
                        ACC = operand ^ ACC;

                        N   <= ACC[7]; // Negative flag (MSB of result)
                        Z   <= ~|ACC; // Zero flag (1 if result is 0)
                        prepare_next_fetch();
                    end
                    8'b000???10: begin // ASL
                        {C, INTERNAL_ALU_OUT} = {operand[7:0], 1'b0};
                        N <= INTERNAL_ALU_OUT[7];
                        Z <= ~|INTERNAL_ALU_OUT;

                        addr  <= operand_addr;
                        data_out <= INTERNAL_ALU_OUT;
                        RW <= 1'b0; // write
                        state <= `ST_WRITE;
                    end
                    8'b010???10: begin // LSR
                        {INTERNAL_ALU_OUT, C} = {1'b0, operand};
                        N <= INTERNAL_ALU_OUT[7]; // always 0 because of shift
                        Z <= ~|INTERNAL_ALU_OUT;

                        addr  <= operand_addr;
                        data_out <= INTERNAL_ALU_OUT;
                        RW <= 1'b0; // write
                        state <= `ST_WRITE;
                    end
                    8'b001???10: begin // ROL
                        {C, INTERNAL_ALU_OUT} = {operand, C};
                        N <= INTERNAL_ALU_OUT[7];
                        Z <= ~|INTERNAL_ALU_OUT;

                        addr  <= operand_addr;
                        data_out <= INTERNAL_ALU_OUT;
                        RW <= 1'b0; // write
                        state <= `ST_WRITE;
                    end
                    8'b011???10: begin // ROR
                        {INTERNAL_ALU_OUT, C} = {C, operand};
                        N <= INTERNAL_ALU_OUT[7];
                        Z <= ~|INTERNAL_ALU_OUT;

                        addr  <= operand_addr;
                        data_out <= INTERNAL_ALU_OUT;
                        RW <= 1'b0; // write
                        state <= `ST_WRITE;
                    end
                    8'b110???01: begin // CMP
                        INTERNAL_ALU_OUT = ACC - operand;
                        Z = ~|INTERNAL_ALU_OUT;
                        N = INTERNAL_ALU_OUT[7];
                        C = ACC >= operand;

                        prepare_next_fetch();
                    end
                    8'b100???01: begin // STA
                        prepare_next_fetch();
                    end
                    8'b101???01: begin // LDA
                        ACC <= operand;
                        N   <= operand[7];
                        Z   <= ~|operand;

                        prepare_next_fetch();
                    end

                    // ##### Jump Instructions #####
                    `INS_JMP_IND: begin
                        PC    = operand_addr;

                        prepare_next_fetch();
                    end

                    // ###### Stack Operations ######
                    `INS_PLA: begin // Pull ACC from stack
                        ACC <= operand;
                        N   <= ACC[7];
                        Z   <= ~|ACC;

                        prepare_next_fetch();
                    end

                    8'b100??110: begin // STX
                        prepare_next_fetch();
                    end

                    8'b101??110, 8'hA2: begin // LDX
                        X = operand;
                        N <= X[7];
                        Z <= ~|X;

                        prepare_next_fetch();
                    end

                    8'b110??110: begin // DEC
                        // TODO: make sure that this is applied in time (-> see waveform)
                        reg [7:0] dec_result;
                        dec_result = operand - 1;

                        addr <= operand_addr;
                        data_out <= dec_result;
                        N <= dec_result[7];
                        Z <= (dec_result == 8'h00);
                        RW <= 1'b0; // write
                        state <= `ST_WRITE;
                    end

                    8'b111??110: begin // INC
                        // TODO: make sure that this is applied in time (-> see waveform)
                        reg [7:0] inc_result;
                        inc_result = operand + 1;

                        addr <= operand_addr;
                        N <= inc_result[7];
                        Z <= (inc_result == 8'h00);
                        data_out <= inc_result;
                        RW <= 1'b0; // write
                        state <= `ST_WRITE;
                    end

                    8'b100??100: begin // STY
                        prepare_next_fetch();
                    end

                    8'b101??100, 8'hA0: begin // LDY, LDY #imm
                        Y = operand;
                        N <= Y[7];
                        Z <= ~|Y;

                        prepare_next_fetch();
                    end

                    8'b110??100, 8'hC0: begin // CPY, CPY #imm
                        INTERNAL_ALU_OUT = Y - operand;
                        Z = ~|INTERNAL_ALU_OUT;
                        N = INTERNAL_ALU_OUT[7];
                        C = Y >= operand;

                        prepare_next_fetch();
                    end

                    8'b111??100, 8'hE0: begin // CPX, CPX #imm
                        INTERNAL_ALU_OUT = X - operand;
                        Z = ~|INTERNAL_ALU_OUT;
                        N = INTERNAL_ALU_OUT[7];
                        C = X >= operand;

                        prepare_next_fetch();
                    end
                    `INS_BIT_ZPG, `INS_BIT_ABS: begin
                        V = operand[6];
                        N = operand[7];
                        Z = ~(operand & ACC);

                        prepare_next_fetch();
                    end

                    `INS_NOP: begin
                        prepare_next_fetch();
                    end

                    `INS_PLA: begin // Pull ACC from stack
                        ACC <= operand;
                        N   <= ACC[7];
                        Z   <= ~|ACC;

                        prepare_next_fetch();
                    end

                    `INS_PLP: begin // Pull status from stack
                        N <= operand[7];
                        V <= operand[6];
                        D <= operand[3];
                        I <= operand[2];
                        Z <= operand[1];
                        C <= operand[0];

                        prepare_next_fetch();
                    end

                    default: begin
                        $display("###\n###\n###\n EXEC: UNKNOWN IR=%16x \n###\n###\n###", IR);
                        prepare_next_fetch();
                    end
                endcase
            end

            `ST_WRITE: begin // State 8
                prepare_next_fetch();
            end

            `ST_BRANCH_FETCH: begin
                // +1 for parameter (offset byte)
                // PC = PC + 1 + $signed(data_in); // this somehow does not work possibly because PC is unsigned
                PC = PC + 1 + {{8{data_in[7]}}, data_in}; // manually treat data_in as signed

                prepare_next_fetch();
            end

            `ST_PUSH_PCL: begin // State 9
                data_out <= PC[7:0]; // Push low byte of PC
                addr <= SP;
                RW <= 1'b0; // write
                SP <= SP - 1;

                if (IR == `INS_JSR) begin // subroutine -> jump
                    IR <= `INS_JMP;
                    PC <= PC - 1;
                    state <= `ST_JSR_JUMP;
                end
                else begin // interrupt -> push status
                    state <= `ST_PUSH_STATUS;
                end
            end

            `ST_PUSH_PCH: begin // State 10
                data_out <= PC[15:8]; // Push high byte of PC
                addr <= SP;
                RW <= 1'b0; // write
                SP <= SP - 1;
                state <= `ST_PUSH_PCL;
            end

            `ST_JSR_JUMP: begin
                // similar to `ST_DECODE->INS_JMP but without the "IR = data_in"
                // from here follow path of `ST_DECODE->INS_JMP
                operand_addr <= 16'h0000;
                addr  <= PC;
                RW <= 1'b1; // read
                state <= `ST_FETCH_OPERAND_LOW;
            end

            `ST_PUSH_STATUS: begin
                data_out <= {N, V, 1'b1, 1'b1, D, I, Z, C};
                addr  <= SP;
                RW <= 1'b0; // write
                SP    <= SP - 1;
                state <= `ST_GET_IV_LOW;
            end

            `ST_GET_IV_LOW: begin
                if (performing_nmi) begin
                    addr <= 16'hFFFA;
                end
                else begin
                    addr <= 16'hFFFE;
                end
                RW <= 1'b1; // read
                state <= `ST_GET_IV_HIGH;
            end

            `ST_GET_IV_HIGH: begin
                PC[7:0] <= data_in; // Write low byte of PC
                if (performing_nmi) begin
                    addr <= 16'hFFFB;
                end
                else begin
                    addr <= 16'hFFFF;
                end
                RW <= 1'b1; // read
                state <= `ST_WRITE_INTERRUPT_VECTOR;
            end

            `ST_WRITE_INTERRUPT_VECTOR: begin
                I <= 1'b1; // Mask IRQ
                PC[15:8] = data_in; // Write high byte of PC
                if (performing_nmi) begin
                    performing_nmi = 1'b0;
                    nmi_pending = 1'b0; // Clear NMI request flag
                end
                else if (performing_irq) begin
                    performing_irq = 1'b0;
                    irq_pending = 1'b0; // Clear IRQ request flag
                end
                prepare_next_fetch();
            end

            `ST_POP_PCL: begin
                // Write Status registers
                N <= data_in[7];
                V <= data_in[6];
                D <= data_in[3];
                I <= data_in[2];
                Z <= data_in[1];
                C <= data_in[0];
                // Pull PC_low
                addr <= SP + 1;
                SP <= SP + 1;
                RW <= 1'b1; // read
                state <= `ST_POP_PCH;
            end

            `ST_POP_PCH: begin
                PC[7:0] <= data_in; // Write low byte of PC

                addr <= SP + 1;
                SP <= SP + 1;
                RW <= 1'b1; // read
                state <= `ST_WRITE_PCH;
            end

            `ST_WRITE_PCH: begin
                PC[15:8] = data_in; // Write high byte of PC

                // TODO: what does the original 6502 do here on page crossing??
                if (IR == `INS_RTS) begin
                    PC = PC + 16'h01; // This needs a 16 bit adder but makes sure the addition is correct even when page is crossed
                end
                prepare_next_fetch();
            end

            default: begin
                $display("###\n###\n###\ STATEMACHINE: UNKNOWN STATE \n###\n###\n###");
                state <= `ST_RESET;
            end
        endcase
    end
end

endmodule