// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_array (clk, reset, out_s, in_w, in_n, inst_w, valid, mode_2b);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input  clk, reset;
  output [psum_bw*col-1:0] out_s;
  input  [row*bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input  [psum_bw*col-1:0] in_n;
  output [col-1:0] valid;
  input mode_2b;


  reg    [2*row-1:0] inst_w_temp;
  wire   [psum_bw*col*(row+1)-1:0] temp;
  wire   [row*col-1:0] valid_temp;


  genvar i;
 
  // output selection
  assign out_s = temp[psum_bw*col*(row+1)-1 : psum_bw*col*row];
  
  // top row input
  assign temp[psum_bw*col*1-1 : psum_bw*col*0] = 0;

  // valid signal
  assign valid = valid_temp[row*col-1 : row*col-col];

  for (i=1; i < row+1 ; i=i+1) begin : row_num
      mac_row #(.bw(bw), .psum_bw(psum_bw), .col(col)) mac_row_instance (
         .clk(clk),
         .reset(reset),
         .mode_2b(mode_2b), 
         .in_w(in_w[bw*i-1:bw*(i-1)]),
         .inst_w(inst_w_temp[2*i-1:2*(i-1)]),
         .in_n(temp[psum_bw*col*i-1:psum_bw*col*(i-1)]),
         .valid(valid_temp[col*i-1:col*(i-1)]),
         .out_s(temp[psum_bw*col*(i+1)-1:psum_bw*col*(i)])
      );
  end

  // generalize for any number of rows
  always @ (posedge clk) begin
    if (reset) begin
      inst_w_temp[1:0] <= 2'b0; 
    end else begin
      inst_w_temp[1:0] <= inst_w; 
    end
  end

  genvar j;
  generate
    for (j = 1; j < row; j = j + 1) begin : shift_inst
      always @ (posedge clk) begin
        if (reset) begin
           inst_w_temp[2*(j+1)-1 : 2*j] <= 2'b0;
        end else begin
           inst_w_temp[2*(j+1)-1 : 2*j] <= inst_w_temp[2*j-1 : 2*(j-1)];
        end
      end
    end
  endgenerate

  // // debug print
  // always @ (posedge clk) begin
  //   if (!reset) begin
  //     if (inst_w_temp[2*row-1]) begin
  //       $display("T=%0t MAC_ARRAY dbg: out_s = %h valid = %b", $time, out_s, valid);
  //     end
  //   end
  // end
// always @(posedge clk) begin
//     if (valid != 0)
//         $display("T=%0t  MAC_ARRAY: valid=%b out_s=%h", 
//                  $time, valid, out_s);
// end
endmodule