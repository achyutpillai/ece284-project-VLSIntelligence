// mac_tile.v - ANNOTATED WITH REQUIRED CHANGES
// Lines with "// ← CHANGE X:" show where to make modifications

module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, mode, reset);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w;
output [bw-1:0] out_e; 
input  [1:0] inst_w;
output [1:0] inst_e;
input  [psum_bw-1:0] in_n;
input  clk;
input  reset;
input  mode;

reg [1:0] inst_q;
reg [bw-1:0] a_q;
reg [bw-1:0] b_q;
reg [psum_bw-1:0] c_q;
wire [psum_bw-1:0] mac_out;
reg load_ready_q;
reg mode_q;  // ← CHANGE 1: ADD THIS LINE

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
    .a(a_q), 
    .b(b_q),
    .c(c_q),
    .out(mac_out)
);

assign out_e = a_q;
assign inst_e = inst_q;
assign out_s = mac_out;

always @ (posedge clk) begin
    if (reset == 1) begin
        inst_q <= 0;
        load_ready_q <= 1'b1;
        a_q <= 0;
        b_q <= 0;
        c_q <= 0;
        mode_q <= 0;  // ← CHANGE 2: ADD THIS LINE
    end
    else begin
        inst_q[1] <= inst_w[1];
        mode_q <= mode;  // ← CHANGE 3: ADD THIS LINE
        
        // ═══════════════════════════════════════════════════════════════
        // ← CHANGE 4: REPLACE THE BLOCK BELOW (lines 50-59 in original)
        // ═══════════════════════════════════════════════════════════════
        if (inst_w[1]) begin  // Only update during execute
            if (mode == 1'b1) begin
                // Output Stationary: accumulate in place
                c_q <= mac_out;
            end 
            else if (mode == 1'b0 && mode_q == 1'b1) begin
                // ← THIS IS THE KEY FIX!
                // Flush phase: transitioning from OS→WS
                // Don't overwrite accumulated value from north
                c_q <= c_q;  // Keep accumulated value
            end
            else begin
                // Normal Weight Stationary: take from north
                c_q <= in_n;
            end
        end
        // ═══════════════════════════════════════════════════════════════
        
        if (inst_w[1] | inst_w[0]) begin
            a_q <= in_w;
        end
        if (inst_w[0] & load_ready_q) begin
            b_q <= in_w;
            load_ready_q <= 1'b0;
        end
        if (load_ready_q == 1'b0) begin
            inst_q[0] <= inst_w[0];
        end
    end
end

endmodule

// ═══════════════════════════════════════════════════════════════════════
// SUMMARY: 4 simple changes fix the bug
// ═══════════════════════════════════════════════════════════════════════
// 1. Add "reg mode_q;" after line 23
// 2. Add "mode_q <= 0;" in reset block after line 42
// 3. Add "mode_q <= mode;" after line 45
// 4. Replace c_q update logic (lines 50-59) with the version shown above
// ═══════════════════════════════════════════════════════════════════════