// Simple test to verify OS mode accumulation works
`timescale 1ns/1ps

module test_os_simple;

parameter bw = 4;
parameter psum_bw = 16;

reg clk = 0;
reg reset = 1;
reg mode = 1;  // OS mode
reg [1:0] inst_w = 0;
reg [bw-1:0] in_w = 0;
reg [psum_bw-1:0] in_n = 0;

wire [psum_bw-1:0] out_s;
wire [bw-1:0] out_e;
wire [1:0] inst_e;

// Internal register to check
wire [psum_bw-1:0] c_q_value;

mac_tile #(
    .bw(bw),
    .psum_bw(psum_bw)
) dut (
    .clk(clk),
    .reset(reset),
    .mode(mode),
    .inst_w(inst_w),
    .in_w(in_w),
    .in_n(in_n),
    .out_s(out_s),
    .out_e(out_e),
    .inst_e(inst_e)
);

// Access internal c_q for debugging
assign c_q_value = dut.c_q;

always #0.5 clk = ~clk;

integer errors = 0;

initial begin
    $dumpfile("test_os_simple.vcd");
    $dumpvars(0, test_os_simple);
    
    $display("\n========== OS MODE ACCUMULATION TEST ==========\n");
    
    // Reset
    #5 reset = 0;
    $display("After reset: c_q=%d, out_s=%d", c_q_value, out_s);
    
    // Load weight = 3
    #1 inst_w = 2'b01; in_w = 4'd3;
    #1; // Wait for clock edge
    $display("After load weight=3: b_q=%d", dut.b_q);
    
    // Stop loading
    #1 inst_w = 2'b00;
    #1;
    
    // Execute cycle 1: activation=2, should compute 2*3+0=6
    $display("\n--- Execute Cycle 1 ---");
    $display("Before: a_q=%d, b_q=%d, c_q=%d", dut.a_q, dut.b_q, c_q_value);
    inst_w = 2'b10; in_w = 4'd2;
    #1; // Wait for clock edge
    $display("After:  a_q=%d, b_q=%d, c_q=%d, out_s=%d", dut.a_q, dut.b_q, c_q_value, out_s);
    $display("Expected: out_s=6 (2*3+0)");
    if (out_s != 16'd6) begin
        $display("ERROR: Expected 6, got %d", out_s);
        errors = errors + 1;
    end
    
    // Execute cycle 2: activation=4, should compute 4*3+6=18
    $display("\n--- Execute Cycle 2 ---");
    $display("Before: a_q=%d, b_q=%d, c_q=%d", dut.a_q, dut.b_q, c_q_value);
    in_w = 4'd4;
    #1; // Wait for clock edge
    $display("After:  a_q=%d, b_q=%d, c_q=%d, out_s=%d", dut.a_q, dut.b_q, c_q_value, out_s);
    $display("Expected: out_s=18 (4*3+6)");
    if (out_s != 16'd18) begin
        $display("ERROR: Expected 18, got %d", out_s);
        errors = errors + 1;
    end
    
    // Execute cycle 3: activation=5, should compute 5*3+18=33
    $display("\n--- Execute Cycle 3 ---");
    $display("Before: a_q=%d, b_q=%d, c_q=%d", dut.a_q, dut.b_q, c_q_value);
    in_w = 4'd5;
    #1; // Wait for clock edge
    $display("After:  a_q=%d, b_q=%d, c_q=%d, out_s=%d", dut.a_q, dut.b_q, c_q_value, out_s);
    $display("Expected: out_s=33 (5*3+18)");
    if (out_s != 16'd33) begin
        $display("ERROR: Expected 33, got %d", out_s);
        errors = errors + 1;
    end
    
    $display("\n--- Final accumulated value: %d (should be 2*3 + 4*3 + 5*3 = 33) ---", out_s);
    
    // Now test flush: switch to WS mode
    $display("\n========== FLUSH TEST (OS -> WS transition) ==========\n");
    mode = 0;  // Switch to WS mode
    inst_w = 2'b10;  // Keep executing
    in_w = 0;  // No new data
    in_n = 0;  // Nothing from north
    
    $display("Before flush: mode=%d, c_q=%d, out_s=%d", mode, c_q_value, out_s);
    #1; // Wait for clock edge
    $display("After flush:  mode=%d, c_q=%d, out_s=%d", dut.mode, c_q_value, out_s);
    $display("Expected: out_s should still be 33 (or close, since input is 0)");
    
    #5;
    
    if (errors == 0) begin
        $display("\n========== ALL TESTS PASSED ==========\n");
    end else begin
        $display("\n========== %d ERRORS DETECTED ==========\n", errors);
    end
    
    $finish;
end

endmodule