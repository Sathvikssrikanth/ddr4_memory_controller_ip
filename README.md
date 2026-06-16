# ddr4_memory_controller_ip
DDR4 memory Controller IP

Technical Specification :
The DDR4 controller has been designed with a set of hardware and functional specifications that govern its speed, interface configuration, memory addressing, and error handling capabilities. These parameters ensure correct operation with the targeted DDR4 DRAM device and optimal system performance.

• Target Clock frequency: 100 MHz [Max: 1.8 GHz]
• User Data Bus width: 8 bits
• User Address width: 32 bits
• Designed to access a 2 GB DRAM Memory (2 Bank Groups, 4 Banks each)
• Controller designed for x16 configuration of DDR4 DRAM Memory (16-bit DQ)
• 16-bit Read/Write DQ Bus implemented
• ECC Hamming (13,8) implemented for parity/error correction
• Supports Single Error Correction (SEC)andDouble Error Detection (DED) to maintain data integrity
• Read/Write operations executed based on input User Flags
• Auto-Prechargecommandassertedtothememorycompulsorily after every Read/Write operation
• Periodic Memory Refresh performed to maintain DRAM data integrity (Entire memory refreshed at once)
• As per DDR4 Specification, to support dual data rate, the controller should work on differential clock inputs (CK t, CK c). But, we have implemented a high level DDR4 Memory Controller (commands, timing, refresh, ECC) and considered a single clock for the ease of implementation.
