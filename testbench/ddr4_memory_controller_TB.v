`timescale 1ns/1ps 
 
module ddr4_memory_controller_TB; 
 
  // Clock & Reset 
  reg clk = 0; 
  reg reset_n; 
 
  // User interface signals 
  reg  [31:0] user_addr; 
  reg         user_write_req; 
  reg         user_read_req; 
  reg  [7:0]  user_write_data; 
  wire [7:0]  user_read_data; 
 
  // ECC reporting signals 
  wire ecc_single_err; 
  wire ecc_double_err; 
  wire err_corrected; 
 
  // DDR command/address outputs 
  wire [31:0] ddr4_addr; 
  wire        ddr4_bank_group; 
  wire [1:0]  ddr4_banks; 
  wire        ddr4_cs_n; 
  wire        ddr4_act_n; 
  wire        ddr4_data_strobe; 
 
  // Correct DQ inout handling 
  reg         dq_oe; 
  reg [15:0]  dq_drive; 
  wire [15:0] ddr4_dq; 
  assign ddr4_dq = dq_oe ? dq_drive : 16'hzzzz; 
 
  // Instantiate DDR4 Controller DUT 
  ddr4_memory_controller dut ( 
    .clk(clk), 
    .reset_n(reset_n), 
    .user_addr(user_addr), 
    .user_write_data(user_write_data), 
    .user_read_data(user_read_data), 
    .user_write_req(user_write_req), 
    .user_read_req(user_read_req), 
    .ecc_single_err(ecc_single_err), 
    .ecc_double_err(ecc_double_err), 
    .err_corrected(err_corrected), 
    .ddr4_addr(ddr4_addr), 
    .ddr4_bank_group(ddr4_bank_group), 
    .ddr4_banks(ddr4_banks), 
    .ddr4_cs_n(ddr4_cs_n), 
    .ddr4_act_n(ddr4_act_n), 
    .ddr4_dq(ddr4_dq), 
    .ddr4_data_strobe(ddr4_data_strobe) 
  ); 
 
  // Clock Generation 
  always #5 clk = ~clk; 
 
  // Testcases
  initial begin 
    dq_oe     = 0; 
    dq_drive  = 16'h0000; 
 
    user_addr       = 32'd0; 
    user_write_req  = 0; 
    user_read_req   = 0; 
    user_write_data = 8'd0; 
 
    // Reset sequence 
    reset_n = 0; 
    #40; 
    reset_n = 1; 
    #10; 
 
    // WRITE OPERATION 
    $display("\n WRITE OPERATION "); 
    user_addr       = 32'h00FFA4A5; 
    user_write_data = 8'hAA; 
    user_write_req  = 1;      #40; 
    user_write_req = 0;       #40; 
 
    // READ OPERATION 
    $display("\n READ OPERATION "); 
    user_read_req = 1; 
    dq_oe    = 1;                      // After ACTIVATE + READ cmd, TB drives DQ bus to simulate DRAM 
    dq_drive = 16'h1A58;       #40; 
 
    user_read_req = 0; 
    dq_oe = 0;                 #40; 

    // READ OPERATION (With single bit error)
    $display("\n READ OPERATION (With Single bit error for test) "); 
    user_read_req = 1; 
    dq_oe    = 1;                    // After ACTIVATE + READ cmd, TB drives DQ bus to simulate DRAM 
    dq_drive = 16'h1A5C;       #40; 
 
    user_read_req = 0; 
    dq_oe = 0;                 #40; 

 
    $display("\nSimulation Complete."); 
    $finish; 
  end 
 
  // Waveform Dump 
  initial begin 
    $dumpfile("ddr4_memory_controller_TB.vcd"); 
    $dumpvars(0, ddr4_memory_controller_TB); 
    $dumpvars(0, dut); 
  end 
endmodule
