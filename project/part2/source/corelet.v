// Corelet contains the MAC array, L0, output FIFO and SFP.
module corelet #(
    parameter row     = 8,
    parameter col     = 8,
    parameter psum_bw = 16,
    parameter bw      = 4
)(
    input  clk,
    input  reset,
    input  [34:0]               inst,
    input  [bw*row-1:0]         data_in,
    input  [psum_bw*col-1:0]    data_in_acc,
    output [psum_bw*col-1:0]    data_out,
    output [psum_bw*col-1:0]    sfp_data_out,
    output                      ofifo_valid
);

    // L0 FIFO
    wire [bw*row-1:0] L0_out;
    wire              L0_o_full;
    wire              L0_o_ready;

    l0 #(
        .row(row),
        .bw(bw)
    ) L0_inst (
        .clk    (clk),
        .wr     (inst[2]),    // l0_wr
        .rd     (inst[3]),    // l0_rd
        .reset  (reset),
        .in     (data_in),
        .out    (L0_out),
        .o_full (L0_o_full),
        .o_ready(L0_o_ready)
    );

    // MAC_array 
    wire [psum_bw*col-1:0] mac_out_s;
    wire [col-1:0]         mac_valid;

    mac_array_simd #(
        .bw     (bw),
        .psum_bw(psum_bw),
        .col    (col),
        .row    (row)
    ) mac_array_inst (
        .clk   (clk),
        .reset (reset),
        .out_s (mac_out_s),
        .in_w  (L0_out),          // weights and inputs from L0
        .in_n  ({psum_bw*col{1'b0}}), // unused 
        .inst_w(inst[1:0]),       // {execute, load}
        .valid (mac_valid),
        .mode_2b(inst[34])
    );

    // OFIFO 
    wire [psum_bw*col-1:0] ofifo_out;
    wire                   ofifo_o_ready;
    wire                   ofifo_o_full;
    wire                   ofifo_o_valid;

    ofifo #(
        .col    (col),
        .bw(psum_bw)
    ) ofifo_inst (
        .clk   (clk),
        .reset (reset),
        .wr    (mac_valid),
        .rd    (inst[6]),
        .in    (mac_out_s),
        .out   (ofifo_out),
        .o_full(ofifo_o_full),
        .o_ready(ofifo_o_ready),
        .o_valid(ofifo_o_valid)
    );

    assign data_out    = ofifo_out;
    assign ofifo_valid = ofifo_o_valid;

    // SFP per columns
    wire [psum_bw*col-1:0] sfp_out;

    genvar i;
	generate
    for (i = 0; i < col; i = i + 1) begin : sfp_num
        sfp #(
            .psum_bw(psum_bw)
        ) sfp_inst (
            .clk  (clk),
            .acc  (inst[33]),   // accumulate enable
            .reset(reset),
            .data_in   (data_in_acc[psum_bw*(i+1)-1 : psum_bw*i]),
            .data_out  (sfp_out[psum_bw*(i+1)-1 : psum_bw*i])
        );
    end
	endgenerate

    assign sfp_data_out = sfp_out;

endmodule