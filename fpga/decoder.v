
module decoder (
    input  wire clk,
    input  wire reset,
    input  wire cs_n,
    input  wire [7:0] recieve_byte,
    input  wire byte_valid,

    output reg  [15:0] r  // Determines what outputs are hot in the decoder
);

    /* Synchronized registers: combat metastability by reading from the raw wires after they've stabilized;
    uses a chained approach where newer variables are assigned values from (tick - 1) */
    reg cs_n1, cs_n2;

    reg [3:0] byte_count;  // Byte count, upto 15 bytes can be counted for
    reg [7:0] packet_header;

    // Packet headers (placeholders, to be changed)
    localparam TYPE_A = 8'h01;
    localparam TYPE_B = 8'h02;

    always @(posedge clk) begin
        cs_n1 <= cs_n;
        cs_n2 <= cs_n1;

        if (reset || cs_n2) begin // Updates between packets being sent
            byte_count  <= 8'd0;
            packet_header <= 8'd0;
            r <= 16'b0;
        end
        else if (byte_valid) begin
            if (byte_count == 8'd0) begin
                packet_header <= recieve_byte; // First byte is stored as the header
                byte_count <= 4'd1;
            end
            else begin
                case (packet_header)
                    TYPE_A: begin // First data type, planned to be SCORE (Score, Team scores, Player Scores, etc...)
                        case (byte_count)
                            4'd1: r <= 16'b0000_0000_0000_0001;
                            4'd2: r <= 16'b0000_0000_0000_0010;
                            4'd3: r <= 16'b0000_0000_0000_0100;
                            4'd4: r <= 16'b0000_0000_0000_1000;
                            4'd5: r <= 16'b0000_0000_0001_0000;
                            4'd6: r <= 16'b0000_0000_0010_0000;
                            4'd7: r <= 16'b0000_0000_0100_0000;
                            default: ;
                        endcase
                        if (byte_count == 8'd7) begin 
                            byte_count <= 8'd0; 
                        end 
                        else begin 
                            byte_count <= byte_count + 8'h1;
                        end 
                    end
                    TYPE_B: begin // Second data type, planned to be MATCHUP (Matchup Details, Countdown to Matchup, Standings, etc...)
                        case (byte_count)
                            4'd1: r <= 16'b0000_0000_0000_0001;
                            4'd2: r <= 16'b0000_0000_0000_0010;
                            4'd3: r <= 16'b0000_0000_0000_0100;
                            4'd4: r <= 16'b0000_0000_0000_1000;
                            4'd5: r <= 16'b0000_0000_0001_0000;
                            4'd6: r <= 16'b0000_0000_0010_0000;
                            4'd7: r <= 16'b0000_0000_0100_0000;
                            4'd8: r <= 16'b0000_0000_1000_0000;
                            4'd9: r <= 16'b0000_0001_0000_0000;
                            default: ;
                        endcase
                        if (byte_count == 8'd9) begin 
                            byte_count <= 8'd0; 
                        end 
                        else begin 
                            byte_count <= byte_count + 8'd1;
                        end 
                    end
                    default: ;
                endcase
            end

            
        end
    end
endmodule
