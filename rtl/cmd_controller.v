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
       
      