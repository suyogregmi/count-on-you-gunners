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

    localparam [7:0] ZEROS_BYTE = 8'h00; // 00000000 
    localparam [7:0] ONES_BYTE = 8'hFF; // 11111111 
    localparam [7:0] ALT_BYTE = 8'hAA; // 10101010
    

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

    task set_cs_n(input toggle); 
        begin 
            cs_n = toggle; // 0 is on, 1 is off 
        end 
    endtask 

    task test_byte(input [7:0] testbyte); // Send a test byte through single bits (starting from MSB)
        integer i; 
        begin
            for (i = 7; i >= 0; i = i - 1) begin 
                copi = testbyte[i]; 
                #10 sclk = 1; 
                #10 sclk = 0;   
            end 
        end 
    endtask 

    task test_byte_partial(input [7:0] testbyte, input integer bits); // Send a test byte through single bits (starting from MSB)
        integer i; 
        begin
            for (i = 7; i > 7 - bits; i = i - 1) begin 
                copi = testbyte[i]; 
                #10 sclk = 1; 
                #10 sclk = 0;   
            end 
        end 
    endtask 



    /* The task is able to wait for an event, which the expect_eq macro cannot do;
        Makes sure byte_valid begins the comparasion between the input and output byte.
        Must run in parallel (fork) with test_byte, since byte_valid pulses before test_byte returns */
    task check_byte(input [7:0] testbyte); 
        integer cycles; 
        reg found; 
        begin 
            found = 0; 
            for (cycles = 0; cycles < 100 && !found; cycles = cycles + 1) begin 
                @(posedge clk); 
                if (byte_valid) begin
                    found = 1; 
                    if (recieve_byte === testbyte)
                        $display("PASS: output %h, expected %h", recieve_byte, testbyte);
                    else
                        `EXPECT_EQ(recieve_byte, testbyte) 
                end
            end 

            if (!found) begin
                $display("FAIL: byte_valid did not pulse (expected %h)", testbyte);
                assertion_err = 1; 
                errors = errors + 1; 
                if (!`APIO_SIM) $fatal;
            end
        end
    endtask

    task check_no_byte(input integer cycles);
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
                if (byte_valid) begin
                    $display("FAIL: unexpected byte_valid, recieve_byte = %h", recieve_byte);
                    assertion_err = 1;
                    errors = errors + 1;
                    if (!`APIO_SIM) $fatal;
                end
            end
        end
    endtask

    task test_check(input [7:0] testbyte);
        begin 
            set_cs_n(0);
            fork 
                test_byte(testbyte);
                check_byte(testbyte); 
            join 
            set_cs_n(1); 
            #20; // Idle gap so the DUT sees cs_n high between transactions 
        end 
    endtask 

    task packet_test_check(input [((8*8)-1):0] packet, input integer len); // Tests several bytes in one task 
        integer i; 
        reg [7:0] current_byte; 
        begin 
            set_cs_n(0); 
            for (i = (len - 1); i >= 0; i = i - 1) begin 
                current_byte = packet[8*i +: 8]; 
                fork 
                    test_byte(current_byte); 
                    check_byte(current_byte); 
                join 
            end 
            set_cs_n(1);
            #20;
        end
    endtask

    /* Cuts a byte off after some bits (1-7) with reset or cs_n,
        checks that the partial byte produces no byte_valid pulse,
        then sends a full byte to check that the DUT recovered */
    task test_check_recovery(input [7:0] partial_byte, input integer bits, input set_reset, input [7:0] recovery_byte);
        begin
            set_cs_n(0);
            fork
                begin
                    test_byte_partial(partial_byte, bits);
                    if (set_reset) begin
                        @(negedge clk) reset = 1;
                        @(negedge clk);
                        @(negedge clk) reset = 0;
                    end
                    else begin
                        set_cs_n(1);
                        #20; 
                    end
                end
                check_no_byte(bits * 10 + 20);
            join
            test_check(recovery_byte); 
        end
    endtask

    // Test cases 
    initial begin 
        reset = 1; 
        #10; 
        reset = 0; 
        #10; 

        test_check(ZEROS_BYTE); 
        test_check(ONES_BYTE); 
        test_check(ALT_BYTE); 
        packet_test_check({ALT_BYTE, ONES_BYTE, ZEROS_BYTE}, 3); // Sends in order from FIRST byte to LAST byte 
        packet_test_check({8'h00, 8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07}, 8); // Example packet with 8 bytes, with each byte later representing data types.

        // Recovery tests
        test_check_recovery(8'hFF, 4, 1, 8'hA5); // reset mid-byte
        test_check_recovery(8'hFF, 4, 0, 8'hA5); // cs_n changed mid-byte

        $display("Tests finished, errors = %0d", errors); 
        $finish; 
    end 

endmodule 