// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
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
input  mode;  // 0=WS, 1=OS

reg [1:0] inst_q;
reg [bw-1:0] a_q;
reg [bw-1:0] b_q;
reg [psum_bw-1:0] c_q;
wire [psum_bw-1:0] mac_out;
reg load_ready_q;
reg mode_q;  // Previous cycle's mode

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
        mode_q <= 0;
    end
    else begin
        inst_q[1] <= inst_w[1];
        mode_q <= mode;  // Track previous mode
        
        // ═══════════════════════════════════════════════════════════════
        // c_q update: The core logic
        // ═══════════════════════════════════════════════════════════════
        if (mode == 1'b1) begin
            // OS Mode: Only accumulate during execute
            if (inst_w[1]) begin
                c_q <= mac_out;
            end
            // else: hold c_q value (no update)
        end
        else begin
            // WS Mode OR Flush
            // Key insight: During flush (mode=0, mode_q=1), we DON'T want c_q <= in_n
            // But in pure WS, we DO want c_q <= in_n
            // Solution: Only skip if we're executing during flush
            if (mode_q == 1'b1 && inst_w[1]) begin
                // Flush: Don't update c_q, let it drain
            end
            else begin
                // Pure WS: Always flow from north (original behavior)
                c_q <= in_n;
            end
        end
        // ═══════════════════════════════════════════════════════════════
        
        // ═══════════════════════════════════════════════════════════════
        // a_q update: Mode-dependent behavior
        // ═══════════════════════════════════════════════════════════════
        if (mode == 1'b1) begin
            // OS Mode: Only update during execute (not during load)
            if (inst_w[1]) begin
                a_q <= in_w;
            end
        end
        else begin
            // WS Mode OR Flush
            if (mode_q == 1'b1 && inst_w[1]) begin
                // Flush: Zero out a_q so mac_out = 0*b_q + c_q = c_q
                a_q <= 0;
            end
            else begin
                // Pure WS: Update during load OR execute (original behavior)
                if (inst_w[1] | inst_w[0]) begin
                    a_q <= in_w;
                end
            end
        end
        // ═══════════════════════════════════════════════════════════════
        
        // b_q logic unchanged from original
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