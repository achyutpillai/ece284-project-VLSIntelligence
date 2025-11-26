// A mock core just used to get testbench to run
module core #(
    parameter integer bw      = 4,
    parameter integer psum_bw = 16,
    parameter integer col     = 16,
    parameter integer row     = 16
)(
    input  wire                      clk,
    input  wire                      reset,
    input  wire [35:0]               inst,      
    input  wire [bw*row-1:0]         D_xmem,
    output reg                       ofifo_valid,
    output reg [col*psum_bw-1:0]     sfp_out
);

    reg [33:0]           inst_q;
    reg                  reset_q;
    reg [bw*row-1:0]     D_xmem_q;

    always @(posedge clk) begin
        inst_q   <= inst;
        reset_q  <= reset;
        D_xmem_q <= D_xmem;

        ofifo_valid <= 1'b0;
        sfp_out     <= {col*psum_bw{1'b0}};
    end

endmodule