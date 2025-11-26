// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] out_s;
input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
output [bw-1:0] out_e; 
input  [1:0] inst_w;
output [1:0] inst_e;
input  [psum_bw-1:0] in_n;
input  clk;
input  reset;

//a = activation, b = weight, c = psum
wire  [psum_bw-1:0]   mac_out;
wire                  a_en, b_en; 
wire  [bw-1:0]        a_d, b_d; 
reg   [bw-1:0]        a_q, b_q; 
reg   [psum_bw-1:0]   c_q; 
wire  [psum_bw-1:0]   c_d; 
reg   [1:0]           inst_q; 
wire  [1:0]           inst_d; 
reg                   load_ready_q; 
wire                  load_ready_d; 


mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .a(a_q), 
        .b(b_q),
        .c(c_q),
	.out(mac_out)
); 

always @ (posedge clk) begin
	if (reset) begin 
            a_q <= 'b0;
            b_q <= 'b0;
            c_q <= 'b0;
            inst_q <= 'b0;
            load_ready_q <= 'b1;
        end 
	else begin
            a_q <= a_d;
            b_q <= a_d;
            c_q <= c_d;
            inst_q <= inst_d;
            load_ready_q <= load_ready_d;
	end
end

//Load weight into PE 
assign b_d          = (inst_w[0] & load_ready_q) ? inst_w : b_q; 
assign load_ready_d = (inst_w[0] & load_ready_q) ? 1'b0 : load_ready_q; 

assign a_d          = |inst_w ? in_w : a_q; 
assign b_d          = (inst_w[0] & load_ready_q) ? in_w : b_q; 
assign c_d          = in_n; 

assign inst_d[0]    = ~load_ready_q ? inst_w[0] : inst_q;// if load done latch new kernel load signal
assign inst_d[1]    = inst_w[1];

//Connect to outputs
assign inst_e = inst_q & {1'b1, ~load_ready_q};
assign out_e  = a_q;
assign out_s  = mac_out;
endmodule
