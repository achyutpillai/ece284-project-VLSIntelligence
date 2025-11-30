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

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
    .a(a_q), 
    .b(b_q),
    .c(c_q),
    .out(mac_out)
);

assign out_e = a_q;
assign inst_e = inst_q;
assign out_s = mac_out;


wire [bw-1:0] weight_from_n = in_n[bw-1:0];

always @ (posedge clk) begin
    if (reset == 1) begin
        inst_q <= 0;
        load_ready_q <= 1'b1;
        a_q <= 0;
        b_q <= 0;
        c_q <= 0;
    end
    else begin
        inst_q[1] <= inst_w[1];
        
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
            // WS Mode: Always flow from north (original part1 behavior)
            c_q <= in_n;
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
            // WS Mode: Update during load OR execute (original part1 behavior)
            if (inst_w[1] | inst_w[0]) begin
                a_q <= in_w;
            end
        end
        // ═══════════════════════════════════════════════════════════════
        
        // b_q logic: Mode-dependent weight loading
        if (inst_w[0] & load_ready_q) begin
            if (mode == 1'b1) begin
                // OS Mode: Load weight from north (IFIFO)
                b_q <= weight_from_n;
            end
            else begin
                // WS Mode: Load weight from west (original behavior)
                b_q <= in_w;
            end
            load_ready_q <= 1'b0;
        end

        if (load_ready_q == 1'b0) begin
            inst_q[0] <= inst_w[0];
        end
    end
end

endmodule