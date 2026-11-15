`timescale 1ns/1ps 

// Safeguard to make sure apio_sim runs 
`ifndef APIO_SIM 
    `define APIO_SIM 0
`endif

// apio conventional expected value definition; errors is NOT conventional and is only there for total error count 
`define EXPECT_EQ(actual, expected) \
    if (actual !== expected) begin \
        $display("FAILED at %s, line %0d: ACTUAL = %h, EXPECTED = %h", `__FILE__, `__LINE__, actual, expected); \
        assertion_err = 1; \
        errors = errors + 1; \
        if(!`APIO_SIM) $fatal; \
    end

module spi_recieve_tb; // Remember that the testbench itself has no IO ports and values going into the SPI must have a value
    reg clk = 0; 
    reg sclk = 0; 
    reg reset = 0; 
    reg cs_n = 1; 
    reg copi = 0; 
    wire [7:0] recieve_byte;
    wire byte_valid; 

    integer errors = 0; 
    integer assertion_err = 0; 
    

    // SPI Reciever, inputs and outputs wired so that the testbench can read its values 
    spi_recieve dut (
        // Inputs 
        .clk(clk), 
        .sclk(sclk),
        .reset(reset), 
        .cs_n(cs_n), 
        .copi(copi), 

        //Outputs 
        .recieve_byte(recieve_byte), 
        .byte_valid(byte_valid) 

    ); 

    initial begin 
        $dumpvars(0, spi_recieve_tb); // Dumps all variables from the highest level (0) so that every variable under the level is imported in 
    end 

    always #1 clk = ~clk; 

    task test_byte(input [7:0] testbyte); // Send a test byte through single bits (starting from MSB)
        integer i; 
        begin  
            for (i = 7; i > -1; i = i - 1) begin 
                copi = testbyte[i]; 
                #10 sclk = 1; 
                #10 sclk = 0; 
            end 
        end 
    endtask 

endmodule 