// Corelet contains the MAC array, L0, output FIFO and SFP.
module corelet #(
    parameter row     = 8,
    parameter col     = 8,
    parameter psum_bw = 16,
    parameter bw      = 4
)(
    input  clk,
    input  reset,
    input  [34:0]                inst,   // [34] is mode
    input  [bw*row-1:0]          data_in,
    input  [psum_bw*col-1:0]     data_in_acc,
    output [psum_bw*col-1:0]     data_out,
    output [psum_bw*col-1:0]     sfp_data_out,
    output                       ofifo_valid
);

    wire mode = inst[34];

    // --- L0 FIFO ---
    wire [bw*row-1:0] L0_out;
    wire              L0_o_full;
    wire              L0_o_ready;
    wire L0_wr = inst[2];
    wire L0_rd = inst[3];
    wire [bw*row-1:0] L0_data_in = data_in;

    l0 #(
        .row(row),
        .bw(bw)
    ) L0_inst (
        .clk    (clk),
        .wr     (L0_wr), 
        .rd     (L0_rd), 
        .reset  (reset),
        .in     (L0_data_in),
        .out    (L0_out),
        .o_full (L0_o_full),
        .o_ready(L0_o_ready)
    );

    // --- Weight IFIFO (New for Part 3) ---
    wire [bw*col-1:0] IFIFO_out;
    wire IFIFO_wr = inst[5];
    wire IFIFO_rd = inst[4];
    wire [bw*col-1:0] IFIFO_data_in = data_in; // Shares data bus with L0
    wire IFIFO_o_full;
    wire IFIFO_o_ready;

    l0 #(
        .row(col), // Note: Depth/Width might differ, reusing l0 module for simplicity
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

    // --- Input Muxing Logic ---
    wire [psum_bw*col-1:0] mac_in_n_os;
    genvar j;
    generate
        for (j = 0; j < col; j = j + 1) begin : north_input_gen
            // CRITICAL FIX: If mode=0 (WS), force North input to 0. 
            // If mode=1 (OS), take from IFIFO and zero-pad to 16 bits.
            assign mac_in_n_os[psum_bw*(j+1)-1:psum_bw*j] = (mode) ? 
                {{(psum_bw-bw){1'b0}}, IFIFO_out[bw*(j+1)-1:bw*j]} : 
                {psum_bw{1'b0}};
        end
    endgenerate

    // --- MAC Array ---
    wire [psum_bw*col-1:0] mac_out_s;
    wire [col-1:0]         mac_valid; // Output valid from array

    mac_array #(
        .bw      (bw),
        .psum_bw (psum_bw),
        .col     (col),
        .row     (row)
    ) mac_array_inst (
        .clk    (clk),
        .reset  (reset),
        .out_s  (mac_out_s),
        .in_w   (L0_out),          
        .in_n   (mac_in_n_os), 
        .inst_w (inst[1:0]),      // {execute, load}
        .mode   (mode),           // Pass mode to array
        .valid  (mac_valid)       // Array generates valid signal for OFIFO
    );

    // --- OFIFO ---
    wire [psum_bw*col-1:0] ofifo_out;
    wire                   ofifo_o_ready;
    wire                   ofifo_o_full;
    wire                   ofifo_o_valid;

    // We use the valid signal from mac_array to trigger OFIFO write
    ofifo #(
        .col (col),
        .bw  (psum_bw)
    ) ofifo_inst (
        .clk    (clk),
        .reset  (reset),
        .wr     (mac_valid), // Write when data exits array
        .rd     (inst[6]),
        .in     (mac_out_s),
        .out    (ofifo_out),
        .o_full (ofifo_o_full),
        .o_ready(ofifo_o_ready),
        .o_valid(ofifo_o_valid)
    );

    assign data_out    = ofifo_out;
    assign ofifo_valid = ofifo_o_valid;

    // --- SFP (Special Function Processor) ---
    wire [psum_bw*col-1:0] sfp_out;

    genvar i;
    generate
    for (i = 0; i < col; i = i + 1) begin : sfp_num
        sfp #(
            .psum_bw(psum_bw)
        ) sfp_inst (
            .clk   (clk),
            .acc   (inst[33]),    // accumulate enable
            .reset (reset),
            .data_in   (data_in_acc[psum_bw*(i+1)-1 : psum_bw*i]),
            .data_out  (sfp_out[psum_bw*(i+1)-1 : psum_bw*i])
        );
    end
    endgenerate

    assign sfp_data_out = sfp_out;

endmodule