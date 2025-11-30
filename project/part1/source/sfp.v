module sfp #(
    parameter psum_bw = 16,
    parameter kij = 9
)(
input clk,
input acc,
input reset,
input signed [psum_bw-1:0] data_in,
output signed [psum_bw-1:0] data_out
);

localparam counter_width = $clog2(kij);
reg signed [psum_bw-1:0] psum_q;
reg [counter_width-1:0] counter;


always @(posedge clk) begin
    if (reset) begin
        psum_q <= 0;
        counter <= 0;
    end else if (acc) begin
        if (counter == kij-1) begin
            if (psum_q + data_in > 0)
                psum_q = psum_q + data_in;
            else
                psum_q <= 0;
            counter <= 0;
        end else begin
            psum_q <= psum_q + data_in;
            counter <= counter + 1;
        end 
    end
end

assign data_out = psum_q;

endmodule