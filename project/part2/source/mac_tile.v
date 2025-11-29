// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Modified to support mixed precision (2-bit unsigned act, 4-bit signed weight)
// Update: Activations are Unsigned in ALL modes.
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset, mode_2b);

parameter bw = 4;
parameter psum_bw = 16;

localparam lane_bw = psum_bw/2;  // width of PSUM0 / PSUM1 lanes

output [psum_bw-1:0] out_s;     // {PSUM1, PSUM0}
input  [bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
output [bw-1:0] out_e; 
input  [1:0] inst_w;
output [1:0] inst_e;
input  [psum_bw-1:0] in_n; //{PSUM1_in, PSUM0_in}
input  clk;
input  reset;
input  mode_2b;   // 1: 2b act, 4b wgt; 0: 4b act, 4b wgt (vanilla)

reg  [bw-1:0] a_q; 
reg  [psum_bw-1:0] c_q; 
reg  [1:0] inst_q; 
reg  load_ready_q; 

// two 4-bit weight registers per PE
reg  [bw-1:0] wgt0_q, wgt1_q;     
reg  lane_sel_q;   // 0: next load -> wgt0, 1: next load -> wgt1 (2b only)

wire [bw-1:0]       a_d = |inst_w ? in_w : a_q; 
wire [psum_bw-1:0] c_d = in_n; 


wire load_ready_d = (inst_w[0] & load_ready_q) ? 1'b0 : load_ready_q; 
wire [1:0] inst_d = {inst_w[1], (~load_ready_q ? inst_w[0] : inst_q[0])};
wire load_en = inst_w[0] & load_ready_q;
wire [bw-1:0] wgt0_d, wgt1_d;

assign wgt0_d = (load_en) ? ((!mode_2b || !lane_sel_q) ? in_w : wgt0_q) : wgt0_q;
assign wgt1_d = (load_en) ? ((!mode_2b || lane_sel_q) ? in_w : wgt1_q) : wgt1_q;

wire [lane_bw-1:0] psum0_in_lane = c_q[lane_bw-1:0];
wire [lane_bw-1:0] psum1_in_lane = c_q[psum_bw-1:lane_bw];

// sign-extend each lane (Partial sums are always signed)
wire signed [psum_bw-1:0] psum0_in_ext =
    {{(psum_bw-lane_bw){psum0_in_lane[lane_bw-1]}}, psum0_in_lane};

wire signed [psum_bw-1:0] psum1_in_ext =
    {{(psum_bw-lane_bw){psum1_in_lane[lane_bw-1]}}, psum1_in_lane};

// activations
// always store a 4-bit activation in a_q
wire [1:0] act_lo_2b = a_q[1:0]; // Treated as raw bits
wire [1:0] act_hi_2b = a_q[3:2]; // Treated as raw bits

// FIX 1: act_lo must be ZERO extended. 
// Correct for 2-bit Unsigned Mode AND 4-bit lower half.
wire signed [bw-1:0] act_lo_ext = {{(bw-2){1'b0}}, act_lo_2b}; 

// FIX 2: act_hi must be ZERO extended.
// Since 4-bit acts are Unsigned, the upper 2 bits are just magnitude.
// If we used sign-extension here, a '1' in bit 3 would be treated as negative.
wire signed [bw-1:0] act_hi_ext = {{(bw-2){1'b0}}, act_hi_2b};

wire signed [bw-1:0] w0_s = wgt0_q;
wire signed [bw-1:0] w1_s = wgt1_q;

////////////////////////////////////////////////////////
// 2-bit act, 4-bit weights (mode_2b = 1)
// PSUM0_next = PSUM0_in + a_2b * wgt0
// PSUM1_next = PSUM1_in + a_2b * wgt1
wire signed [bw-1:0] act2b_ext = act_lo_ext;  // lower 2 bits are the 2-bit act (Unsigned)
wire signed [psum_bw-1:0] prod0_2b = act2b_ext * w0_s;
wire signed [psum_bw-1:0] prod1_2b = act2b_ext * w1_s;

wire signed [psum_bw-1:0] psum0_next_2b = psum0_in_ext + prod0_2b;
wire signed [psum_bw-1:0] psum1_next_2b = psum1_in_ext + prod1_2b;


////////////////////////////////////////////////////////
// 4-bit act, 4-bit weights (mode_2b = 0)
// prod_lo = act_lo * W
// prod_hi = act_hi * W
// A*W = prod_lo + (prod_hi << 2)
// psum_full_next = psum_full_in + prod_full

wire signed [psum_bw-1:0] prod_lo_4b = act_lo_ext * w0_s;
wire signed [psum_bw-1:0] prod_hi_4b = act_hi_ext * w0_s;

wire signed [psum_bw-1:0] prod_hi_4b_shifted = (prod_hi_4b <<< 2);
wire signed [psum_bw-1:0] prod_full_4b = prod_lo_4b + prod_hi_4b_shifted;

////////////////////////////////////////////////////////
// combine lane psums
wire signed [psum_bw-1:0] psum_full_in_4b = {psum1_in_lane, psum0_in_lane};
// updated full psum for 4b mode
wire signed [psum_bw-1:0] psum_full_next_4b = psum_full_in_4b + prod_full_4b;
// split back into two lanes
wire [lane_bw-1:0] psum0_next_4b_lane = psum_full_next_4b[lane_bw-1:0];
wire [lane_bw-1:0] psum1_next_4b_lane = psum_full_next_4b[psum_bw-1:lane_bw];
// select outputs based on mode
wire [lane_bw-1:0] psum0_out_lane =
    mode_2b ? psum0_next_2b[lane_bw-1:0] : psum0_next_4b_lane;

wire [lane_bw-1:0] psum1_out_lane =
    mode_2b ? psum1_next_2b[lane_bw-1:0] : psum1_next_4b_lane;

wire [psum_bw-1:0] final_psum_packed = {psum1_out_lane, psum0_out_lane};

always @ (posedge clk) begin
    if (reset) begin 
        a_q <= 'b0;
        c_q <= 'b0;
        inst_q <= 'b0;
        load_ready_q <= 'b1;
        wgt0_q <= 'b0;
        wgt1_q <= 'b0;
        lane_sel_q <= 'b0;
    end 
    else begin
        a_q <= a_d;
        c_q <= c_d;
        inst_q <= inst_d;
        load_ready_q <= load_ready_d;
        
        wgt0_q <= wgt0_d;
        wgt1_q <= wgt1_d;
        if (load_en && mode_2b)
            lane_sel_q <= ~lane_sel_q;
        else if (!mode_2b)
            lane_sel_q <= 1'b0; // reset lane index in vanilla mode
    end
end

assign inst_e = inst_q & {1'b1, ~load_ready_q};
assign out_e  = a_q;
assign out_s  = final_psum_packed;
endmodule