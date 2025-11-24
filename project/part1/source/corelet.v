// corelet.v
// Verilog wrapper of `core` that includes everything except the SRAM instantiations.
// Memory IO signals are exposed as module ports.

module corelet #(
    parameter bw = 4,
    parameter col = 8,
    parameter row = 8
)(
    input clk,
    input [33:0] inst,
    output ofifo_valid,
    // D_xmem is used as the data input to L0 FIFO. It is loaded with either activation or kernel data
    input [bw*row-1:0] D_xmem,
    output [col*16-1:0] sfp_out,
    input reset,

    // PSUM memory interface (connected to sram_32b_w2048 in original core)
    output [col*16-1:0] psum_mem_din,
    input  [col*16-1:0] psum_mem_dout,
    output [10:0]      psum_mem_addr,
    output             psum_mem_cen,
    output             psum_mem_wen,

    // XMEM (activation/kernel) memory interface
    output [bw*row-1:0] xmem_din,
    input  [bw*row-1:0] xmem_dout,
    output [10:0]       xmem_addr,
    output              xmem_cen,
    output              xmem_wen
);

    // Internal wires for interconnects
    wire [bw*row-1:0] l0_macarray_data;
    wire l0_full, l0_ready;
    wire [col*16-1:0] mac_ofifo_wdata;
    wire [col-1:0] mac_ofifo_wvalid;
    wire [col*16-1:0] ofifo_psum_data;
    wire ofifo_full, ofifo_ready;

    // SFP valid wire
    wire sfp_valid;

    // Instantiate SFP
    sfp #(
        .col(col),
        .ksize(9),
        .psum_bw(16)
    ) sfp_inst (
        .clk(clk),
        .reset(reset),
        .acc(inst[33]),            // accumulate enable comes from inst[33]
        .data_in(psum_mem_dout),   // use partial-sum memory output as input to SFP
        .data_out(sfp_out),        
        .valid_out(sfp_valid)
    );

    // L0 FIFO instantiation
    l0 #(
        .row(row),
        .bw(bw)
    ) l0_inst (
        .clk(clk),
        .reset(reset),
        .in(xmem_dout),
        .out(l0_macarray_data),
        .rd(inst[3]),    // l0_rd
        .wr(inst[2]),    // l0_wr
        .o_full(l0_full),
        .o_ready(l0_ready)
    );

    // MAC array instantiation
    mac_array #(
        .bw(bw),
        .psum_bw(16),
        .col(col),
        .row(row)
    ) mac_array_inst (
        .clk(clk),
        .reset(reset),
        .out_s(mac_ofifo_wdata),
        .in_w(l0_macarray_data),
        .in_n(128'b0), 
        .inst_w(inst[1:0]),    // inst[1]: execute, inst[0]: kernel loading
        .valid(mac_ofifo_wvalid) // write to output fifo whenever valid is high
    );

    // OFIFO instantiation
    ofifo #(
        .col(col),
        .bw(16)
    ) ofifo_inst (
        .clk(clk),
        .reset(reset),
        .in(mac_ofifo_wdata),
        .out(ofifo_psum_data),
        .rd(inst[6]),         // ofifo_rd
        .wr(mac_ofifo_wvalid),
        .o_full(ofifo_full),
        .o_ready(ofifo_ready),
        .o_valid(ofifo_valid)
    );

    // Connect OFIFO output to psum memory data input (module output)
    assign psum_mem_din  = ofifo_psum_data;
    assign psum_mem_cen  = inst[32];
    assign psum_mem_wen  = inst[31];
    assign psum_mem_addr = inst[30:20];

    // Connect D_xmem to xmem data input (module output)
    assign xmem_din   = D_xmem;
    assign xmem_cen   = inst[19];
    assign xmem_wen   = inst[18];
    assign xmem_addr  = inst[17:7];

endmodule
