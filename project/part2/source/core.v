module core #(
    parameter row = 8,
    parameter col = 8,
    parameter psum_bw = 16,
    parameter bw = 4
)(
    input clk,
    input reset,    
    input [34:0] inst,
    input [bw*row-1:0] D_xmem,
    output ofifo_valid,
    output [psum_bw*col-1:0] sfp_out
);

wire [bw*row-1:0] corelet_data_in;
wire [psum_bw*col-1:0] corelet_data_in_acc;
wire [psum_bw*col-1:0] corelet_data_out;
wire [psum_bw*col-1:0] corelet_sfp_data_out;

assign corelet_data_in_acc = pmem_data_out;
assign corelet_data_in = xmem_data_out;
assign sfp_out = corelet_sfp_data_out;

/////////// added for 2-bit mode ////////////
wire mode_2b;
assign mode_2b = inst[34];

corelet #(
    .row(row),
    .col(col),
    .psum_bw(psum_bw),
    .bw(bw)
) corelet_insts (
    .clk(clk),
    .reset(reset),
    .inst(inst),
    .data_in(corelet_data_in),
    .data_in_acc(corelet_data_in_acc),
    .data_out(corelet_data_out),
    .sfp_data_out(corelet_sfp_data_out),
    .ofifo_valid(ofifo_valid),
    .mode_2b(mode_2b)
);

wire xmem_chip_en;
wire xmem_wr_en;
wire [10:0] xmem_addr_in;
wire [31:0] xmem_data_in;
wire [31:0] xmem_data_out;

assign xmem_chip_en = inst[19];
assign xmem_wr_en = inst[18];
/////TODO: TEST HERE/////
assign xmem_addr_in = inst[17:7];

// reconstruct address for XMEM ignoring mode bit
// assign xmem_addr_in = {inst[17:9], inst[7]};  // {A_xmem[10:2], A_xmem[0]}
assign xmem_data_in = D_xmem;

sram_32b_w2048 #(
    .num(2048),
    .width(bw * row)
) Xmemory_inst (
    .CLK(clk),
    .D(xmem_data_in),
    .Q(xmem_data_out),
    .CEN(xmem_chip_en),
    .WEN(xmem_wr_en),
    .A(xmem_addr_in)
);

wire [psum_bw*col-1:0] pmem_data_in;
wire [psum_bw*col-1:0] pmem_data_out;
wire pmem_chip_en;
wire pmem_wr_en;
wire [10:0] pmem_addr_in;

assign pmem_data_in = corelet_data_out;
assign pmem_chip_en = inst[32];
assign pmem_wr_en = inst[31];
assign pmem_addr_in = inst[30:20];

genvar i;
sram_32b_w2048 #(
    .num(2048),
    .width(psum_bw*col)
) Pmemory_inst (
    .CLK(clk),
    .D(pmem_data_in),
    .Q(pmem_data_out),
    .CEN(pmem_chip_en),
    .WEN(pmem_wr_en),
    .A(pmem_addr_in)
);

endmodule
