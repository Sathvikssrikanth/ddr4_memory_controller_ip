module ddr4_memory_controller #(
    parameter USER_DATA_WIDTH = 8, 
    parameter BUS_DATA_WIDTH  = 16, 
    parameter ADDRESS_WIDTH   = 32, 
    parameter BANK_GROUP_WIDTH= 1,    
    parameter BANK_WIDTH      = 2,    
    parameter integer CLK_FREQ = 100000000 
)( 
    input  wire                        clk, 
    input  wire                        reset_n, 
 
    // User interface 
    input  wire [ADDRESS_WIDTH-1:0]    user_addr, 
    input  wire [USER_DATA_WIDTH-1:0]  user_write_data, 
    input  wire                        user_read_req, 
    input  wire                        user_write_req, 
    output wire [USER_DATA_WIDTH-1:0]  user_read_data, 
 
    // ECC status  
    output reg                        ecc_single_err,       // latched single-bit error flag 
    output reg                        ecc_double_err,       // latched double-bit error flag 
    output reg                        err_corrected,        // high only when single-bit was corrected 
 
    // DRAM interface  
    output reg  [ADDRESS_WIDTH-1:0]      ddr4_addr, 
    output reg  [BANK_GROUP_WIDTH-1:0]   ddr4_bank_group, 
    output reg  [BANK_WIDTH-1:0]         ddr4_banks, 
    output reg                           ddr4_cs_n, 
    output reg                           ddr4_act_n, 
    inout  wire [BUS_DATA_WIDTH-1:0]     ddr4_dq, 
    output reg                           ddr4_data_strobe 
); 
 
  //Complete 32-bit address split   
  reg ras_n;                               //A16 (Part of ddr4_addr)
  reg cas_n;                               //A15 (Part of ddr4_addr)
  reg we_n;                                //A14 (Part of ddr4_addr)
  reg auto_pre;                            //A10 - Auto Precharge 
  wire [9:0] col_addr;                     //A0-A9 - Column Address 
  wire [1:0] bank_addr;                    //BA0-BA1 - Bank Address 
  wire bgroup_addr;                        //BG0 - Bank Group 
  wire [13:0] row_addr;                    //14 bits - Row Address 
   
  assign col_addr = user_addr[9:0];            //A0-A9 - Column Address 
  assign bank_addr = user_addr[11:10];         //BA0-BA1 - Bank Address 
  assign bgroup_addr = user_addr[12];          //BG0 - Bank Group 
  assign row_addr = user_addr[26:13];          //14 bits - Row Address 

  //Internal wires declaration 
  wire [1:0]  refresh_req; 
  wire [2:0]  cmd; 
  wire [7:0]  cmd_schedule; 
  wire        dram_busy; 
  wire [12:0] code_out;              // encoder output to DRAM(13 bits) 
  wire [7:0]  data_out;              // decoder corrected data back to the user 
  wire        single_err_wire; 
  wire        double_err_wire; 
  wire        err_corrected_wire; 
   
 
 
  refresh_controller #(.CLK_FREQ(CLK_FREQ), .tREFI(7800), .tRFC(260)) u_refresh ( 
        .clk          (clk), 
        .reset_n      (reset_n), 
        .refresh_req  (refresh_req) 
    ); 
 
    cmd_controller u_cmdgen ( 
        .clk         (clk), 
        .reset_n     (reset_n), 
        .user_read   (user_read_req), 
        .user_write  (user_write_req), 
        .cmd         (cmd) 
    ); 
 
    cmd_scheduler u_scheduler ( 
        .clk            (clk), 
        .reset_n        (reset_n), 
        .cmd            (cmd), 
        .refresh_req    (refresh_req), 
        .cmd_schedule  (cmd_schedule) 
    ); 
 
    timing_controller #(.tRCD(0), .tRAS(0)) u_timing ( 
        .clk           (clk), 
        .reset_n       (reset_n), 
        .cmd_schedule  (cmd_schedule), 
        .dram_busy     (dram_busy) 
    ); 

    ecc_hamming_encoder #(.DATA_WIDTH(8), .BUS_WIDTH(13))  u_ecc_enc ( 
        .clk      (clk), 
        .reset_n  (reset_n), 
        .data_in  (user_write_data), 
        .code_out (code_out) 
    ); 
 
    ecc_hamming_decoder #(.DATA_WIDTH(8), .BUS_WIDTH(13)) u_ecc_dec ( 
        .clk        (clk), 
        .reset_n    (reset_n), 
        .code_in    (ddr4_dq[12:0]),         // lower 13 bits of the 16-bit data that comes from DRAM 
        .data_out   (data_out), 
        .single_err (single_err_wire), 
        .double_err (double_err_wire), 
        .err_corrected(err_corrected_wire) 
    ); 
                        
 // ECC status outputs directly from decoder, whenever user_read_req is HIGH
    always@(posedge clk, negedge reset_n) begin
        if(!reset_n) begin
           ecc_single_err <= 1'b0;
           ecc_double_err <= 1'b0;
           err_corrected <= 1'b0;
          end
        else if(user_read_req) begin
           ecc_single_err <= single_err_wire;
           ecc_double_err <= double_err_wire;
           err_corrected <= err_corrected_wire;
	end
	else begin
	   ecc_single_err <= 1'b0;
           ecc_double_err <= 1'b0;
           err_corrected <= 1'b0; 
	end
    end

 
   //Main Block driving all the outputs to DRAM                     
    always @(posedge clk or negedge reset_n) begin 
        if (!reset_n) begin 
            ddr4_cs_n     <= 1'b1; 
            ddr4_act_n    <= 1'b1; 
            ras_n         <= 1'b1; 
            cas_n         <= 1'b1; 
            we_n          <= 1'b1; 
            auto_pre      <= 1'b0; 
            ddr4_banks      <= 2'b0; 
            ddr4_bank_group <= 1'b0; 
            ddr4_addr      <= 32'd0; 
        end  
        else begin 
          if (dram_busy) begin 
            ddr4_cs_n  <= ddr4_cs_n; 
            ddr4_act_n <= ddr4_act_n; 
            ras_n <= ras_n; 
            cas_n <= cas_n; 
            we_n  <= we_n; 
            auto_pre <= auto_pre; 
            ddr4_banks      <= bank_addr; 
            ddr4_bank_group <= bgroup_addr; 
            ddr4_addr  <= ddr4_addr; 
          end 
          else begin            
            if(cmd_schedule != 8'b0) begin 
              case (cmd_schedule[7:4]) 
                    4'hF: begin              //REFRESH 
                        ddr4_cs_n  <= 1'b0; 
                        ddr4_act_n <= 1'b1; 
                        ras_n <= 1'b0; 
                        cas_n <= 1'b0; 
                        we_n  <= 1'b1; 
                        auto_pre <= 1'b0; 
                        ddr4_banks      <= bank_addr; 
                        ddr4_bank_group <= bgroup_addr; 
                        ddr4_addr  <= {15'd0, ras_n, cas_n, we_n, 3'd0, auto_pre, 10'd0}; 
                    end 
 
                    4'hA: begin            //USER COMMANDS 
                      case (cmd_schedule[2:0]) 
                            3'b001: begin              // READ 
                                ddr4_cs_n  <= 1'b0; 
                                ddr4_act_n <= 1'b1; 
                                ras_n <= 1'b1; 
                                cas_n <= 1'b0; 
                                we_n  <= 1'b1; 
                                auto_pre <= 1'b1; 
                                ddr4_addr  <= {15'd0, ras_n, cas_n, we_n, 3'd0, auto_pre, col_addr}; 
                            end 
                            3'b010: begin              // WRITE 
                                ddr4_cs_n  <= 1'b0; 
                                ddr4_act_n <= 1'b1; 
                                ras_n <= 1'b1; 
                                cas_n <= 1'b0; 
                                we_n  <= 1'b0; 
                                auto_pre <= 1'b1; 
                                ddr4_addr  <= {15'd0, ras_n, cas_n, we_n, 3'd0, auto_pre, col_addr}; 
                            end  
                            3'b011: begin              // ACTIVATE 
                                ddr4_cs_n  <= 1'b0; 
                                ddr4_act_n <= 1'b0; 
                                ras_n <= 1'b1; 
                                cas_n <= 1'b1; 
                                we_n  <= 1'b1; 
                                auto_pre <= 1'b0; 
                              ddr4_addr  <= {18'd0, row_addr}; 
                            end 
                            3'b100: begin              // PRECHARGE 
                                ddr4_cs_n  <= 1'b0; 
                                ddr4_act_n <= 1'b1; 
                                ras_n <= 1'b0; 
                                cas_n <= 1'b1; 
                                we_n  <= 1'b0; 
                                auto_pre <= 1'b0; 
                                ddr4_addr  <= {15'd0, ras_n, cas_n, we_n, 3'd0, auto_pre, 10'd0}; 
                            end 
                            default: begin 
                                ddr4_cs_n  <= 1'b1; 
                                ddr4_act_n <= 1'b1; 
                                ras_n <= 1'b1; 
                                cas_n <= 1'b1; 
                                we_n  <= 1'b1; 
                                auto_pre <= 1'b0; 
                                ddr4_addr <= 32'd0; 
                            end 
                        endcase 
 
                        ddr4_bank_group <= bgroup_addr;   
                        ddr4_banks      <= bank_addr;     
                    end 
 
                    default: begin 
                        ddr4_cs_n  <= 1'b1; 
                        ddr4_act_n <= 1'b1; 
                        ras_n <= 1'b1; 
                        cas_n <= 1'b1; 
                        we_n  <= 1'b1; 
                        auto_pre <= 1'b0; 
                        ddr4_addr <= 32'd0; 
                    end 
                endcase 
            end 
            else begin 
                ddr4_cs_n  <= 1'b1; 
                ddr4_act_n <= 1'b1; 
                ras_n <= 1'b1; 
                cas_n <= 1'b1; 
                we_n  <= 1'b1; 
                auto_pre <= 1'b0; 
                ddr4_banks      <= bank_addr; 
                ddr4_bank_group <= bgroup_addr; 
                ddr4_addr <= 32'd0; 
              end 
            end 
        end 
    end 
 
 

  reg oe;            //Output enable to work as a tristate logic for the inout port - ddr4_dq
  reg [15:0] dq;     //Registering the data coming from DRAM during read 
  assign ddr4_dq = oe ? dq : {BUS_DATA_WIDTH{1'bz}};    //Required tristate logic - Works during Write
                      
  reg [USER_DATA_WIDTH-1:0]   user_read_data_reg;       //Registering the user_read_data output                          
  assign user_read_data  = user_read_data_reg; 

    //Read and write getting assigned to its busses 
    //This always block is mainly to drive the inout ddr4_dq bus 
    always @(posedge clk or negedge reset_n) begin 
      if (!reset_n) begin 
            dq <= {BUS_DATA_WIDTH{1'b0}}; 
            user_read_data_reg <= {USER_DATA_WIDTH{1'b0}}; 
	    oe <= 1'b0;
        end  
      else begin 
          if (user_write_req && !dram_busy) begin      //WRITE 
            dq <= {3'b000, code_out}; 
	    oe <= 1'b1;
            end 
          else if (user_read_req && !dram_busy) begin   //READ 
                user_read_data_reg <= data_out; 
	        oe <= 1'b0;
            end 
	  else
		oe <= 1'b0;
        end 
    end 
 
    //Data strobe toggle logic 
    reg dqs_toggle; 
    always @(posedge clk or negedge reset_n) begin 
        if (!reset_n) begin 
            ddr4_data_strobe <= 1'b0; 
            dqs_toggle       <= 1'b0; 
        end else begin 
            if (user_write_req || user_read_req) begin 
                dqs_toggle       <= ~dqs_toggle; 
                ddr4_data_strobe <= dqs_toggle; 
            end else begin 
                dqs_toggle       <= 1'b0; 
                ddr4_data_strobe <= 1'b0; 
            end 
        end 
    end 
 
endmodule 
 



 
module refresh_controller #( 
  parameter integer CLK_FREQ = 100000000, 
  parameter integer tREFI = 7800,             //Refresh Interval (ns) - Amt of tine Memory is working 
  parameter integer tRFC = 260               //Refresh Cycle (ns) - Amt of time it stays in refresh 
)( 
  input wire clk, 
  input wire reset_n,	 
   
  output reg [1:0] refresh_req     //Mostly 2 bits for 2 bank groups 
); 
  //Memory cycle = When memory is working (read/write/etc)
  //Refresh cycle = Whole DRAM starts refreshing, stops all work
  localparam integer MEMORY_CYCLES = ((tREFI * CLK_FREQ)/1000000000);        // 780 - (tREFI/1000000000)/(1/CLK_FREQ) 
  localparam integer REFRESH_CYCLES = ((tRFC * CLK_FREQ)/1000000000);        // 26 
   
  reg [$clog2(MEMORY_CYCLES+1)-1:0] memory_count; 
  reg [$clog2(REFRESH_CYCLES+1)-1:0] refresh_count; 
   
  always@(posedge clk, negedge reset_n) 
    begin 
      if(!reset_n) 
        begin 
          refresh_req <= 2'b00; 
          refresh_count <= 0; 
          memory_count <= 0; 
        end 
      else if(refresh_count != 0)                             //In between the Refresh cycle - Memory is refreshing
        begin 
          refresh_req <= 2'b11; 
          memory_count <= 0; 
          refresh_count <= refresh_count -1; 
        end 
      else begin 
        if(memory_count >= MEMORY_CYCLES)                     // As soon as Memory cycle is done and refresh needs to start here
          begin 
          	refresh_req <= 2'b11; 
          	memory_count <= 0; 
          	refresh_count <= REFRESH_CYCLES; 
          end 
        else                                                 //During Memory cycle
          begin 
            refresh_req <= 2'b00;               
          	memory_count <= memory_count+1; 
          	refresh_count <= 0; 
          end 
      end 
    end 
endmodule 
 
           
       
  module cmd_controller( 
  input wire clk, 
  input wire reset_n, 
  input wire user_read, 
  input wire user_write, 
  output reg [2:0] cmd 
); 
   
  localparam IDLE = 3'b000;              //Different states
  localparam READ = 3'b001; 
  localparam WRITE = 3'b010; 
  localparam ACTIVATE = 3'b011; 
  localparam PRECHARGE = 3'b100; 
   
  reg [2:0] cs, ns; 
         
           
  always@(cs, user_read, user_write) 
    begin 
      case(cs) 
        IDLE: begin 
          cmd <= 3'b000;               //IDLE 
          if(user_read || user_write) 
            ns <= ACTIVATE; 
          else 
            ns <= cs; 
        end 
         
        ACTIVATE: begin 
          cmd <= 3'b011;              //ACTIVATE 
          if(user_read) 
            ns <= READ; 
          else if(user_write) 
            ns <= WRITE; 
          else 
            ns <= cs; 
        end        
         
        READ: begin                  //READ 
          cmd <= 3'b001; 
          ns <= PRECHARGE; 
        end 
         
        WRITE: begin                  //WRITE 
          cmd <= 3'b010; 
          ns <= PRECHARGE; 
        end  
         
        PRECHARGE: begin              //PRECHARGE 
          cmd <= 3'b100; 
          ns <= IDLE; 
        end 
         
        default: ns <= IDLE; 
      endcase 
    end 
       
           
   always@(posedge clk, negedge reset_n) 
    begin 
      if(!reset_n) 
        cs <= IDLE; 
      else 
        cs <= ns; 
    end 
      
         
endmodule 
       
       
module cmd_scheduler( 
  input wire clk, 
  input wire reset_n, 
  input wire [2:0] cmd, 
  input wire [1:0] refresh_req, 
  output reg [7:0] cmd_schedule    //MSB 4 bits = CMD ID , LSB 4 bits = CMD 
); 
   
  //Assigning Command IDs (CMD ID) 
  localparam [3:0] NOP_SCHEDULE = 4'h0; 
  localparam [3:0] REFRESH_SCHEDULE = 4'hF;    // For refresh command 
  localparam [3:0] USER_SCHEDULE = 4'hA;       // For user commands like read/write 
   
   always@(posedge clk, negedge reset_n) 
    begin 
      if (!reset_n) 
        cmd_schedule <= 8'b0; 
      else if (refresh_req == 2'b11) 
        cmd_schedule <= {REFRESH_SCHEDULE , 2'b00, refresh_req};     
      else if(cmd != 3'b000) 
        cmd_schedule <= {USER_SCHEDULE , {1'b0, cmd}};      
      else 
        cmd_schedule <= {NOP_SCHEDULE , 4'b0000}; 
    end 
   
       
endmodule 
       

module timing_controller #( 
  parameter integer tRCD = 1,     // row->col delay (cycles) = 12.5ns precisely from JEDEC 
  parameter integer tRAS = 3      // row active time = 35ns precisely from JEDEC
)(
  input wire clk, 
  input wire reset_n, 
  input wire [7:0] cmd_schedule, 
  output reg dram_busy 
); 
 
  reg [2:0] delay;                //Just a counter to count the delay required 
 
  always @(posedge clk or negedge reset_n) begin 
    if(!reset_n) begin 
        delay     <= 3'd0; 
        dram_busy <= 1'b0; 
    end 
    else begin 
        if (cmd_schedule[3:0] == 4'h2)      // WRITE 
            delay <= tRAS; 
        else if (cmd_schedule[3:0] == 4'h3) // ACTIVATE 
            delay <= tRCD; 
	else
	    delay <= 3'd0;
 
        // Delay count logic - Coded in the same block, since using 2 always
        // blocks and driving delay in both of them was generating a problem 
        if (delay > 0) begin 
            dram_busy <= 1'b1; 
            delay <= delay - 1; 
        end 
        else begin 
            dram_busy <= 1'b0; 
        end 
    end 
  end 
endmodule 
               
      
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

