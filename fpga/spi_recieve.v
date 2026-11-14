// SPI reciever tool for FPGA board to sepearte bytes 


module spi_recieve ( 
    input wire clk, sclk, reset, // System clock, Serial clock (from the SPI controller), Reset for new byte creation
    input wire copi, // Sends bits of the binary packet one at a time
    input wire cs_n, // Chip select, is ACTIVE_LOW
    output reg [7:0] recieve_byte, // Last full byte received, holding 8 bits
    output reg byte_valid // Pulses high for one clk cycle when recieve_byte holds a new byte
); 

    /* Synchronized registers: combat metastability by reading from the raw wires after they've stabilized; 
    uses a chained approach where newer variables are assigned values from (tick - 1) */
    reg sclk1, sclk2, sclk_prev;
    reg cs_n1, cs_n2;
    reg copi1, copi2; 
    
    reg [7:0] shift_reg; // holds each bit sent from the COPI wire 
    reg [3:0] bit_count; // counts the number of bits (max of 8 bits)

    wire sclk_r; // pulses high for one clk cycle on each SCLK rising edge
    assign sclk_r = sclk2 & ~sclk_prev;


    always @(posedge clk) begin 
        cs_n1 <= cs_n;
        cs_n2 <= cs_n1;

        sclk1 <= sclk;
        sclk2 <= sclk1;
        sclk_prev <= sclk2;

        copi1 <= copi;
        copi2 <= copi1;

        byte_valid <= 1'b0; // Stays low until condition met 

        if (reset || !cs_n2) begin // Chip select is ACTIVE_LOW
            bit_count <= 4'd0;
        end
        else if (bit_count == 4'd8) begin
            bit_count <= 4'd0;
            byte_valid <= 1'b1; // On for one tick, then resets to 0 
            recieve_byte <= shift_reg; // Shift register passes byte into output 
        end
        else if (sclk_r) begin
            bit_count <= bit_count + 4'd1;
            shift_reg <= {shift_reg[6:0], copi2}; // Shifts bit to the left (COPI sends data frrom MSB -> LSB)
        end

    end



endmodule 
