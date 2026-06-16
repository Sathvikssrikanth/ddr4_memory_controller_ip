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
       
