// Corelet contains the MAC array, L0, output FIFO and SFP.
module corelet #(
    parameter row     = 8,
    parameter col     = 8,
    parameter psum_bw = 16,
    parameter bw      = 4
)(
    input  clk,
    input  reset,
    input  [34:0]               inst,  // CHANGED: Extended to 35 bits
    input  [bw*row-1:0]         data_in,
    input  [psum_bw*col-1:0]    data_in_acc,
    output [psum_bw*col-1:0]    data_out,
    output [psum_bw*col-1:0]    sfp_data_out,
    output                      ofifo_valid
);

    wire mode = inst[34];


    // Note: Both L0 and IFIFO share same data bus. Which one gets used is set by read/write pins.

    // L0 FIFO
    wire [bw*row-1:0] L0_out;
    wire              L0_o_full; // Unused
    wire              L0_o_ready; // Unused
    wire L0_wr = inst[2];
    wire L0_rd = inst[3];
    wire [bw*row-1:0] L0_data_in = data_in;

    // Weight IFIFO
    wire [bw*col-1:0] IFIFO_out;
    wire IFIFO_wr = inst[5];
    wire IFIFO_rd = inst[4];
    wire [bw*col-1:0] IFIFO_data_in = data_in;
    wire IFIFO_o_full; // Unused
    wire IFIFO_o_ready; // Unused

    wire [psum_bw*col-1:0] mac_in_n_os;
    genvar j;
    generate
        for (j = 0; j < col; j = j + 1) begin
            assign mac_in_n_os[psum_bw*(j+1)-1:psum_bw*j] = {{(psum_bw-bw){1'b0}}, IFIFO_out[bw*(j+1)-1:bw*j]};
        end
    endgenerate


    l0 #(
        .row(row),
        .bw(bw)
    ) L0_inst (
        .clk    (clk),
        .wr     (L0_wr),    // l0_wr
        .rd     (L0_rd),    // l0 and ififo rd
        .reset  (reset),
        .in     (L0_data_in),
        .out    (L0_out),
        .o_full (L0_o_full),
        .o_ready(L0_o_ready)
    );

    l0 #(
        .row(col),
        .bw(bw)
    ) ififo_inst (
        .clk    (clk),
        .wr     (IFIFO_wr),
        .rd     (IFIFO_rd), 
        .reset  (reset),
        .in     (IFIFO_data_in),
        .out    (IFIFO_out),
        .o_full (IFIFO_o_full),
        .o_ready(IFIFO_o_ready)
    );

    // MAC_array 
    wire [psum_bw*col-1:0] mac_out_s;
    wire [col-1:0]         mac_valid;

    mac_array #(
        .bw     (bw),
        .psum_bw(psum_bw),
        .col    (col),
        .row    (row)
    ) mac_array_inst (
        .clk   (clk),
        .reset (reset),
        .out_s (mac_out_s),
        .in_w  (L0_out),          
        .in_n  (mac_in_n_os), 
        .inst_w(inst[1:0]),       // {execute, load}
        .mode  (mode),        // NEW: Pass mode bit
        .valid (mac_valid)
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