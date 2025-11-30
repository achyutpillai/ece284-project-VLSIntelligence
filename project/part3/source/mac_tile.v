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
    .c(c_q),    // In WS, c_q is input psum. In OS, c_q is accumulator.
    .out(mac_out)
);

assign out_e = a_q;
assign inst_e = inst_q;

// --- CRITICAL CHANGE: South Output Mux ---
// WS Mode: Output the calculated Psum (mac_out)
// OS Mode: Output the Weight (b_q) to pass it to the row below
assign out_s = mode ? {{ (psum_bw-bw){1'b0} }, b_q} : mac_out;

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
        
        // 1. C_Q (Accumulator/Psum) Logic
        if (mode == 1'b1) begin
            // OS Mode: Accumulate in place during execute
            if (inst_w[1]) begin
                c_q <= mac_out;
            end
            // Note: To drain OS psums, you will switch to WS mode later
        end
        else begin
            // WS Mode: Capture Psum from North to add to it
            c_q <= in_n;
        end
        
        // 2. A_Q (Activation) Logic
        if (mode == 1'b1) begin
            // OS Mode: Update during execute
            if (inst_w[1]) a_q <= in_w;
        end
        else begin
            // WS Mode: Update during load or execute
            if (inst_w[1] | inst_w[0]) a_q <= in_w;
        end
        
        // 3. B_Q (Weight) Logic - CRITICAL CHANGE
        if (mode == 1'b1) begin
            // OS Mode: Weights stream! Update every execute cycle.
            if (inst_w[1]) begin
                b_q <= weight_from_n;
            end
        end 
        else begin
             // WS Mode: Weights are stationary. Load once then hold.
            if (inst_w[0] & load_ready_q) begin
                b_q <= in_w;
                load_ready_q <= 1'b0;
            end
        end

        // Reset load flag logic (Same as original)
        if (inst_w[0] == 0) load_ready_q <= 1'b1;
        
        if (load_ready_q == 1'b0) begin
            inst_q[0] <= inst_w[0];
        end
    end
end

endmodule