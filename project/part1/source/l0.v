// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module l0 (clk, in, out, rd, wr, o_full, reset, o_ready);

  parameter row  = 8;
  parameter bw = 4;

  input  clk;
  input  wr;
  input  rd;
  input  reset;
  input  [row*bw-1:0] in;
  output [row*bw-1:0] out;
  output o_full;
  output o_ready;

  wire [row-1:0] empty;
  wire [row-1:0] full;
  reg [row-1:0] rd_en;
  
  genvar i;

  assign o_ready = &(!full);
  assign o_full  = |(full) ;

  generate
  for (i=0; i<row ; i=i+1) begin : row_num
      fifo_depth64 #(.bw(bw)) fifo_instance (
	 .rd_clk(clk),
	 .wr_clk(clk),
	 .rd(rd_en[i]),
	 .wr(wr),
         .o_empty(empty[i]),
         .o_full(full[i]),
	 .in(in[(bw*(i+1)-1): bw*i]),
	 .out(out[(bw*(i+1)-1): bw*i]),
         .reset(reset));
  end
  endgenerate

  integer j;
  always @ (posedge clk) begin
    if (reset) begin
      rd_en <= {row{1'b0}};
    end
    else begin
      // Read 1 row a time
      rd_en[0] <= rd;
      for (j=1; j<row; j=j+1) begin : rowwise_read_en
          rd_en[j] <= rd_en[j-1];
      end
    end
  end


endmodule
