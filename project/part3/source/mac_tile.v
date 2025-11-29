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
reg was_os_mode;  // Track if we were EVER in OS mode since last reset

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
        was_os_mode <= 0;
    end
    else begin
        inst_q[1] <= inst_w[1];
        
        // Track if we've been in OS mode
        if (mode == 1'b1) begin
            was_os_mode <= 1'b1;
        end
        
        // ═══════════════════════════════════════════════════════════════
        // c_q update logic
        // ═══════════════════════════════════════════════════════════════
        if (mode == 1'b1) begin
            // OS Mode: accumulate during execute only
            if (inst_w[1]) begin
                c_q <= mac_out;
            end
        end
        else if (was_os_mode) begin
            // Flush phase: We're in WS mode but were previously in OS mode
            // Don't update c_q - let accumulated value drain
        end
        else begin
            // Pure WS Mode (never been in OS): flow from north
            c_q <= in_n;
        end
        // ═══════════════════════════════════════════════════════════════
        
        // ═══════════════════════════════════════════════════════════════
        // a_q update logic - CRITICAL FIX FOR FLUSH
        // ═══════════════════════════════════════════════════════════════
        if (mode == 1'b1) begin
            // OS Mode: only update during execute
            if (inst_w[1]) begin
                a_q <= in_w;
            end
        end
        else if (was_os_mode) begin
            // Flush phase: DON'T update a_q!
            // Keep a_q at whatever value it has
            // Since L0 is not reading (l0_rd=0), we want a_q to stay constant
            // or better yet, become 0 so mac_out = 0*b + c = c
            // Let's zero it out on first flush cycle
            if (inst_w[1]) begin
                a_q <= 0;  // Zero out a_q during flush
            end
        end
        else begin
            // Pure WS Mode: update during load OR execute
            if (inst_w[1] | inst_w[0]) begin
                a_q <= in_w;
            end
        end
        // ═══════════════════════════════════════════════════════════════
        
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