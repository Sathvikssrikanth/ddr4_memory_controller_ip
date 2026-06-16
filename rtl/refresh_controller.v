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
 
           
    
