module ecc_hamming_encoder #( 
  parameter DATA_WIDTH = 8,        // Hamming (13,8) parity bits 
  parameter BUS_WIDTH = 13         // Hamming (13,8) parity bits 
)( 
  input wire clk, 
  input wire reset_n, 
  input wire [DATA_WIDTH-1:0] data_in, 
  output reg [BUS_WIDTH-1:0] code_out 
); 
  wire p1, p2, p4, p8, p0; 
   
  assign p1 = data_in[0] ^ data_in[1] ^ data_in[3] ^ data_in[4] ^ data_in[6]; 
  assign p2 = data_in[0] ^ data_in[2] ^ data_in[3] ^ data_in[5] ^ data_in[6]; 
  assign p4 = data_in[1] ^ data_in[2] ^ data_in[3] ^ data_in[7]; 
  assign p8 = data_in[4] ^ data_in[5] ^ data_in[6] ^ data_in[7]; 
  assign p0 = p1 ^ p2 ^ p4 ^ p8 ^ data_in[0] ^ data_in[1] ^ data_in[2] ^ data_in[3] ^ data_in[4] ^ data_in[5] ^ data_in[6] ^ data_in[7]; 
 
   
  always@(posedge clk, negedge reset_n) 
    begin 
      if(!reset_n) 
        code_out <= 13'd0; 
      else 	 
        code_out <= { 
       				 p0,             // bit 12 -> position 13 
        			 data_in[7],     // bit 11 -> position 12 
        			 data_in[6],     // bit 10 -> position 11 
        			 data_in[5],     // bit  9 -> position 10 
         			 data_in[4],     // bit  8 -> position  9 
        			 p8,             // bit  7 -> position  8 
        			 data_in[3],     // bit  6 -> position  7 
        			 data_in[2],     // bit  5 -> position  6 
        			 data_in[1],     // bit  4 -> position  5 
        			 p4,             // bit  3 -> position  4 
        			 data_in[0],     // bit  2 -> position  3 
        			 p2,             // bit  1 -> position  2 
        			 p1              // bit  0 -> position  1 
   					}; 
    end 
   
endmodule 
       
       
module ecc_hamming_decoder #( 
  parameter DATA_WIDTH = 8,        // Hamming (13,8) parity bits 
  parameter BUS_WIDTH = 13         // Hamming (13,8) parity bits 
)( 
  input wire clk, 
  input wire reset_n, 
  input wire [BUS_WIDTH-1:0] code_in, 
  output reg [DATA_WIDTH-1:0] data_out, 
  output reg single_err, 
  output reg double_err, 
  output reg err_corrected 
); 
   
  wire p1, p2, p4, p8, p0;                //Parity bits in the incoming data from DRAM 
  wire d0, d1, d2, d3, d4, d5, d6, d7;    //Data bits in the incoming data from DRAM 
  wire par1, par2, par4, par8, par0;      //Parity newly calculated                
  wire [3:0] syndrome;                     //Calculated syndrome between the 2 ECC paritys 
  wire s0;                               
   
  assign p1 = code_in[0];                //Assigning the received code into individual bits - parity/data
  assign p2 = code_in[1]; 
  assign d0 = code_in[2]; 
  assign p4 = code_in[3]; 
  assign d1 = code_in[4]; 
  assign d2 = code_in[5]; 
  assign d3 = code_in[6]; 
  assign p8 = code_in[7]; 
  assign d4 = code_in[8]; 
  assign d5 = code_in[9]; 
  assign d6 = code_in[10]; 
  assign d7 = code_in[11]; 
  assign p0 = code_in[12]; 
 
  assign par1 = d0 ^ d1 ^ d3 ^ d4 ^ d6;    //Calculating new parity
  assign par2 = d0 ^ d2 ^ d3 ^ d5 ^ d6; 
  assign par4 = d1 ^ d2 ^ d3 ^ d7; 
  assign par8 = d4 ^ d5 ^ d6 ^ d7; 
   
  assign syndrome[0] = p1 ^ par1;         //Comparing the pre-existing parity from the received code with the newly generated parity
  assign syndrome[1] = p2 ^ par2;         
  assign syndrome[2] = p4 ^ par4;              
  assign syndrome[3] = p8 ^ par8; 
  assign s0 = p0 ^ p1 ^ p2 ^ p4 ^ p8 ^ d0 ^ d1 ^ d2 ^ d3 ^ d4 ^ d5 ^ d6 ^ d7;   //For the overall parity bit 
   
  reg [12:0] corrected_code; 
 
  always @(posedge clk or negedge reset_n) begin 
    if (!reset_n) begin 
      corrected_code <= 0; 
      single_err   <= 1'b0; 
      double_err   <= 1'b0; 
      data_out       <= 8'b0; 
      err_corrected <= 1'b0; 
    end  
    else begin 
      if (syndrome != 4'b0000)  
        begin  
        if (s0 == 1'b1)  
          begin                                     //Odd parity, hence single bit error 
          if (syndrome <= 4'd12)  
            begin  
              corrected_code <= code_in; 
              corrected_code[syndrome - 1] <= ~code_in[syndrome - 1];     
              single_err <= 1'b1; 
              double_err <= 1'b0; 
              err_corrected <= 1'b1;                   
            end    
          else                                     //If no single bit error, then assuming there is some problem - Double bit or more error
            begin 
              single_err <= 1'b0; 
              double_err <= 1'b1;   
              err_corrected <= 1'b0;                   
              corrected_code <= code_in;                  
            end 
          end 
        else                                      // If s0=0, and syndrome !=0, then doible bit error 
          begin 
            single_err <= 1'b0; 
            double_err <= 1'b1;   
            err_corrected <= 1'b0;                   
            corrected_code <= code_in;                   
          end 
        end 
      else  
        begin                                     // no errors - default state 
          corrected_code <= code_in;    
          single_err   <= 1'b0;   
          double_err   <= 1'b0; 
          err_corrected <= 1'b0;  
        end 
     
    // Extract corrected data from corrected_code 
      data_out <= { 
                corrected_code[11], // d7 (position 12) 
                corrected_code[10], // d6 (position 11) 
                corrected_code[9],  // d5 (position 10) 
                corrected_code[8],  // d4 (position  9) 
                corrected_code[6],  // d3 (position  7) 
                corrected_code[5],  // d2 (position  6) 
                corrected_code[4],  // d1 (position  5) 
                corrected_code[2]   // d0 (position  3) 
      }; 
	end
     
    end 
 
 
endmodule 

