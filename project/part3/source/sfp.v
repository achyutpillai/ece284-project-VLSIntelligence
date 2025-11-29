module sfp #(
    parameter psum_bw = 16
)(
input clk,
input acc,
input reset,
input signed [psum_bw-1:0] data_in,
output signed [psum_bw-1:0] data_out
);

reg signed [psum_bw-1:0] psum_q;

always @(posedge clk) begin
    if (reset == 1)
        psum_q <= 0;
    else begin
        if (acc == 1)
        psum_q <= psum_q + data_in;
        else
        psum_q <= psum_q;
    end
        
end

assign data_out = psum_q;

endmodule