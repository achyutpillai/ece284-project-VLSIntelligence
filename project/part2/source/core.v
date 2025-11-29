module core #(
    parameter bw = 4,
    parameter col = 8,
    parameter row = 8
)(
    clk,
    inst,
    ofifo_valid,
    D_xmem,
    sfp_out,
    reset
);

input clk;
input [34:0] inst;
wire  mode_2b = inst[34]; // 1 = 2-bit, 0 = vanilla 4-bit
output ofifo_valid;
// D_xmem is used as the data input to L0 FIFO. It is loaded with either activation or kernel data from external memory.
input [bw*row-1:0] D_xmem;
output [col*16-1:0] sfp_out; // 16 is psum_bw from testbench
input reset;

// Internal wires for interconnects
wire [bw*row-1:0] l0_macarray_data;
wire l0_full, l0_ready;
wire [col*16-1:0] mac_ofifo_wdata;
wire [col-1:0] mac_ofifo_wvalid;
wire [col*16-1:0] ofifo_psum_data;
wire ofifo_full, ofifo_ready;

// Partial sum memory (SRAM) signals
wire [col*16-1:0] psum_mem_din;
wire [col*16-1:0] psum_mem_dout;
wire  [10:0] psum_mem_addr;     
wire         psum_mem_cen;
wire         psum_mem_wen;

// Activation memory (SRAM) signals
wire [bw*row-1:0] xmem_din;
wire [bw*row-1:0] xmem_dout;
wire [10:0] xmem_addr;
wire       xmem_cen;
wire       xmem_wen;

wire sfp_valid;

reg [10:0] psum_mem_w_addr;
wire ofifo_pop = inst[6];

always @ (posedge clk) begin
    if (reset) begin
        psum_mem_w_addr <= 11'b0;
    end else if (ofifo_valid && ofifo_pop) begin
        psum_mem_w_addr <= psum_mem_w_addr + 1'b1;
    end
end

wire is_read_op = inst[31];
wire auto_write_en = ofifo_valid && ofifo_pop;

assign psum_mem_cen = is_read_op ? inst[32] :
                       auto_write_en ? 1'b0 :
                       inst[32];

assign psum_mem_wen = is_read_op ? 1'b1 : // read
                      auto_write_en ? 1'b0 : // write
                      inst[31];

assign psum_mem_addr = is_read_op ? inst[30:20] :
                       auto_write_en ? psum_mem_w_addr :
                       inst[30:20];
assign psum_mem_din  = ofifo_psum_data;

// debug prints


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

genvar i;

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
    .in_n({col*16{1'b0}}),     // top row psums = 0, internal chaining in mac_array
    .inst_w(inst[1:0]),    // inst[1]: execute, inst[0]: kernel loading
    .valid(mac_ofifo_wvalid), // write to output fifo whenever valid is high
    .mode_2b(mode_2b)
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

// SRAM (partial sum memory) instantiation using sram_32b_w2048
// Each psum is 16 bits, so one 32-bit word holds 2 psums
for (i = 0; i < col/2; i = i + 1) begin : psum_mem_instantiation
    sram_32b_w2048 psum_mem_inst (
        .CLK(clk),
        .D(psum_mem_din[32*(i+1)-1:32*i]),
        .Q(psum_mem_dout[32*(i+1)-1:32*i]),
        .CEN(psum_mem_cen),
        .WEN(psum_mem_wen),
        .A(psum_mem_addr)
    );
end

// Connect D_xmem to xmem data input
assign xmem_din   = D_xmem;
assign xmem_cen   = inst[19];
assign xmem_wen   = inst[18];
assign xmem_addr = inst[17:7];

// Instantiate xmem (activation/kernel memory, bw*row bits wide, using sram_32b_w2048 banks)
for (i = 0; i < (bw*row+31)/32; i = i + 1) begin : xmem_instantiation
    sram_32b_w2048 xmem_inst (
        .CLK(clk),
        .D(xmem_din[32*(i+1)-1:32*i]),
        .Q(xmem_dout[32*(i+1)-1:32*i]),
        .CEN(xmem_cen),
        .WEN(xmem_wen),
        .A(xmem_addr)
    );
end

//Alpha: psum_mem control logic 
//always @ (posedge clk) begin
//    if (reset) begin
//        psum_mem_cen  <= 1'b1;
//        psum_mem_wen  <= 1'b1;
//        psum_mem_addr <= 11'b0;
//    end else begin
//        // Example: Write to psum_mem when ofifo_valid is high
//        psum_mem_cen  = ~ofifo_valid;
//        psum_mem_wen  = ~ofifo_valid;
//        if (psum_mem_wen) begin: // ofifo_rd
//            psum_mem_w_addr <= psum_mem_addr + 1'b1;
//        end
//        else begin
//            psum_mem_addr <= 'b0;
//        end 
//    end
//end

endmodule