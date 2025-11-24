module sfp #(
    parameter col = 8,
    parameter ksize = 9,
    parameter psum_bw = 16
)(
    input clk,
    input reset,
    input acc, // accumulate enable, triggers accumulation of one input
    input [col*psum_bw-1:0] data_in,
    output reg [col*psum_bw-1:0] data_out,
    output reg valid_out
);

    reg [psum_bw-1:0] acc_reg [0:col-1];
    reg [3:0] count;
    wire relu_flag;
    integer i;

    // next-state (combinational) signals (renamed _n -> _d)
    // acc_data is assigned inside always @* so declare it as reg
    reg [psum_bw-1:0] acc_data [0:col-1];
    reg [psum_bw-1:0] acc_reg_d [0:col-1];
    reg [3:0]         count_d;
    reg [col*psum_bw-1:0] data_out_d;
    reg               valid_out_d;
     
    assign relu_flag =  count == 4'd8;
    // Combinational next-state logic
    always @* begin
        // default: carry current state forward
        for (i = 0; i < col; i = i + 1) begin
            acc_reg_d[i] = acc_reg[i];
        end
        count_d      = count;
        data_out_d   = data_out;
        valid_out_d  = 1'b0;

        if (acc) begin
            //normal accumulation
            for (i = 0; i < col; i = i + 1) begin
                // Use indexed part-select so `i` can be used in the slice
                acc_data[i]  = acc_reg[i] + data_in[psum_bw*i +: psum_bw];
                acc_reg_d[i] = relu_flag ? {psum_bw{1'b0}} : acc_data[i]; 
            end
            count_d = count + 1;
            // If relu_flag is asserted, accumuate last value and perform (ReLU) and clear accumulators
            if (relu_flag) begin
                for (i = 0; i < col; i = i + 1) begin
                    // ReLU: if MSB (signed negative) then zero, else pass
                    if (acc_reg_d[i][psum_bw-1]) begin
                        data_out_d[psum_bw*i +: psum_bw] = {psum_bw{1'b0}};
                    end else begin
                        data_out_d[psum_bw*i +: psum_bw] = acc_reg_d[i];
                    end
                end
                valid_out_d = 1'b1;
                count_d = 0;
            end
        end
    end

    // Sequential registers update (state)
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < col; i = i + 1) begin
                acc_reg[i] <= {psum_bw{1'b0}};
            end
            count     <= 0;
            data_out  <= {col{ {psum_bw{1'b0}} }};
            valid_out <= 1'b0;
        end else begin
            for (i = 0; i < col; i = i + 1) begin
                acc_reg[i] <= acc_reg_d[i];
            end
            count     <= count_d;
            data_out  <= data_out_d;
            valid_out <= valid_out_d;
        end
    end

endmodule
