module top(
        input clk_25mhz,
        input [6:0] btn,
        output [7:0] led,
        output wifi_gpio0,
        output [27:0] gp
        );

    wire [15:0] addr;
    wire [7:0] data;
    wire RW;
    wire reset_n;
    wire SYNC;
    wire nmi_n;
    wire irq_n;

    wire [4:0] cpu_state;

    wire clk_1Hz;
    wire clk_100kHz;
    wire clk_1MHz;
    wire clk_5MHz;

    // assign wifi_gpio0 = 1'b1;
    assign reset_n = ~btn[4]; // Down button (could also modify constraint file to use pullup)
    assign irq_n = ~btn[5]; // Left button
    assign nmi_n = ~btn[6]; // Righ button

    // DEBUG SIGNALS
    assign led[0] = reset_n;
    assign led[6] = reset_n;

    assign gp[0] = clk_1MHz;
    assign gp[8:1] = data;
    assign gp[9] = RW;

    // Clock divider
    clock_divider clk_div (
        .clk_25MHz(clk_25mhz),
        .reset_n(reset_n),
        .clk_1Hz(clk_1Hz),
        .clk_100kHz(clk_100kHz),
        .clk_1MHz(clk_1MHz),
        .clk_5MHz(clk_5MHz)
    );

    CPU cpu (
        .clk(clk_1MHz),
        .reset_n(reset_n),
        .RDY(1'b1),
        .NMI_n(nmi_n),
        .IRQ_n(irq_n),
        // .NMI_n(1'b1),
        // .IRQ_n(1'b1),
        .SO(1'b0),
        .SYNC(SYNC),
        .addr(addr),
        .data(data),
        .RW(RW),
        .state(cpu_state),
    );

    RAM ram (
        .clk(clk_1MHz),
        .addr(addr),
        .data(data),
        .RW(RW)
    );

endmodule


module clock_divider (
    input wire clk_25MHz,      // 25 MHz input clock
    input wire reset_n,    // Synchronous reset
    output reg clk_1Hz,  // 1 Hz output clock
    output reg clk_100kHz, // 100 kHz output clock
    output reg clk_1MHz, // 1 MHz output clock
    output reg clk_5MHz  // 5 MHz output clock
);

    // Parameters for the divider ratios
    localparam DIV_1Hz = 25_000_000;   // 25 MHz / 1 Hz = 25_000_000
    localparam DIV_100kHz = 250;       // 25 MHz / 100 kHz = 250
    localparam DIV_1MHz = 25;          // 25 MHz / 1 MHz = 25
    localparam DIV_5MHz = 5;           // 25 MHz / 5 MHz = 5

    // Counters for clock division
    reg [31:0] counter_1Hz;
    reg [31:0] counter_100kHz;
    reg [31:0] counter_1MHz;
    reg [31:0] counter_5MHz;

    always @(posedge clk_25MHz or negedge reset_n) begin
        if (!reset_n) begin
            // Reset all counters and outputs
            counter_1Hz <= 0;
            counter_100kHz <= 0;
            counter_1MHz <= 0;
            counter_5MHz <= 0;
            clk_1Hz <= 0;
            clk_100kHz <= 0;
            clk_1MHz <= 0;
            clk_5MHz <= 0;
        end else begin
            // Counter for 1 Hz
            if (counter_1Hz == DIV_1Hz - 1) begin
                counter_1Hz <= 0;
                clk_1Hz <= ~clk_1Hz; // Toggle for 1 Hz
            end else begin
                counter_1Hz <= counter_1Hz + 1;
            end

            // Counter for 100 kHz
            if (counter_100kHz == DIV_100kHz - 1) begin
                counter_100kHz <= 0;
                clk_100kHz <= ~clk_100kHz; // Toggle for 100 kHz
            end else begin
                counter_100kHz <= counter_100kHz + 1;
            end

            // Counter for 1 MHz
            if (counter_1MHz == DIV_1MHz - 1) begin
                counter_1MHz <= 0;
                clk_1MHz <= ~clk_1MHz; // Toggle for 1 MHz
            end else begin
                counter_1MHz <= counter_1MHz + 1;
            end

            // Counter for 5 MHz
            if (counter_5MHz == DIV_5MHz - 1) begin
                counter_5MHz <= 0;
                clk_5MHz <= ~clk_5MHz; // Toggle for 5 MHz
            end else begin
                counter_5MHz <= counter_5MHz + 1;
            end
        end
    end
endmodule


// could be for example: https://www.alldatasheet.com/datasheet-pdf/download/77314/HITACHI/HM62256.html
module RAM (
    input wire clk,             // Clock signal
    input wire [15:0] addr,     // 16-bit address bus
    inout wire [7:0] data,   // 8-bit data input
    input wire RW,              // Write enable
);
    // ### Stripped RAM to fit FPGA ###
    // included: 0000 - 0FFF (4096 bytes)
    // stripped: 0F00 - FFEF ()
    // included: FFF0 - FFFF (16 bytes)
    // total: 4096 + 16 bytes = 4112

    wire [7:0] data_out;
    assign data = (RW == 1'b1) ? data_out : 8'bz;
    // assign data_out = ram[addr];  // Read data from RAM
    assign data_out = ((addr >= 16'h0F00 && addr < 16'hFFF0)) ? 8'b0 : ((addr >= 16'hFFF0)) ? ram[addr - 16'hFFF0 + 16'h0F00] : ram[addr];  // Read data from RAM

    // Declare the RAM using the FPGA's block RAM primitive
    reg [7:0] ram [0:4112];  // 64KB RAM (65536 addresses, 8-bit data)

    always @(posedge clk) begin
        if (~RW) begin
            if (addr < 16'hFFF0) begin
                ram[addr] <= data;
            end
            else if (addr >= 16'hFFF0) begin
                ram[addr - 16'hFFF0 + 16'h0F00] <= data;
            end
        end
    end
    // Load program from external file (readmemh not supported on hardware)
    initial begin
        $readmemh("test_fpga.hex", ram); // Load HEX file
    end
endmodule
