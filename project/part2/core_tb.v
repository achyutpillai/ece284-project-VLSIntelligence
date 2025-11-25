`timescale 1ns/1ps

module core_tb;

parameter bw = 4;
parameter psum_bw = 16;
parameter len_kij = 9;
parameter len_onij = 16;
parameter col = 8;
parameter row = 8;
parameter len_nij = 36;
parameter len_itile = 1;
parameter len_otile = 1;

reg clk = 0;
reg reset = 1;

wire [33:0] inst_q; 

reg [1:0]  inst_w_q = 0; 
reg [bw*row-1:0] D_xmem_q = 0;
reg CEN_xmem = 1;
reg WEN_xmem = 1;
reg [10:0] A_xmem = 0;
reg CEN_xmem_q = 1;
reg WEN_xmem_q = 1;
reg [10:0] A_xmem_q = 0;
reg CEN_pmem = 1;
reg WEN_pmem = 1;
reg [10:0] A_pmem = 0;
reg CEN_pmem_q = 1;
reg WEN_pmem_q = 1;
reg [10:0] A_pmem_q = 0;
reg ofifo_rd_q = 0;
reg ififo_wr_q = 0;
reg ififo_rd_q = 0;
reg l0_rd_q = 0;
reg l0_wr_q = 0;
reg execute_q = 0;
reg load_q = 0;
reg acc_q = 0;
reg acc = 0;

// NEW: Mode register for reconfigurability
// 0 = 4-bit (Vanilla), 1 = 2-bit (SIMD)
reg mode = 0;
reg mode_q = 0;

reg [1:0]  inst_w; 
reg [bw*row-1:0] D_xmem;
reg [psum_bw*col-1:0] answer;


reg ofifo_rd;
reg ififo_wr;
reg ififo_rd;
reg l0_rd;
reg l0_wr;
reg execute;
reg load;

// String variables for dynamic filenames
reg [8*64:1] w_file_name;
reg [8*64:1] x_file_name;
reg [8*30:1] out_file_name;
reg [8*30:1] acc_file_name;
reg [8*30:1] input_dir;
reg [8*5:1]  mode_prefix;

wire ofifo_valid;
wire [col*psum_bw-1:0] sfp_out;

integer x_file, x_scan_file ; // file_handler
integer w_file, w_scan_file ; // file_handler
integer acc_file, acc_scan_file ; // file_handler
integer out_file, out_scan_file ; // file_handler
integer captured_data; 
integer t, i, j, k, kij;
integer error;
integer run_iter; // Loop variable for reconfigurability


assign inst_q[33] = acc_q;
assign inst_q[32] = CEN_pmem_q;
assign inst_q[31] = WEN_pmem_q;
assign inst_q[30:20] = A_pmem_q;
assign inst_q[19]   = CEN_xmem_q;
assign inst_q[18]   = WEN_xmem_q;

assign inst_q[17:9] = A_xmem_q[10:2];
assign inst_q[8]    = mode_q; // Mode bit
assign inst_q[7]    = A_xmem_q[0];    // Map LSB address bit

assign inst_q[6]   = ofifo_rd_q;
assign inst_q[5]   = ififo_wr_q;
assign inst_q[4]   = ififo_rd_q;
assign inst_q[3]   = l0_rd_q;
assign inst_q[2]   = l0_wr_q;
assign inst_q[1]   = execute_q; 
assign inst_q[0]   = load_q; 


core  #(.bw(bw), .col(col), .row(row)) core_instance (
    .clk(clk), 
    .inst(inst_q),
    .ofifo_valid(ofifo_valid),
    .D_xmem(D_xmem_q), 
    .sfp_out(sfp_out), 
    .reset(reset)); 


initial begin 
  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  input_dir = "./data_files";

  inst_w   = 0; 
  D_xmem   = 0;
  CEN_xmem = 1;
  WEN_xmem = 1;
  A_xmem   = 0;
  ofifo_rd = 0;
  ififo_wr = 0;
  ififo_rd = 0;
  l0_rd    = 0;
  l0_wr    = 0;
  execute  = 0;
  load     = 0;
  mode     = 0; // Default 4 bit mode

  // -------------------------------------------------------------
  // RECONFIGURABILITY LOOP
  // Iteration 0: Run 2-bit Mode
  // Iteration 1: Run 4-bit Mode
  // -------------------------------------------------------------
  for (run_iter = 0; run_iter < 2; run_iter = run_iter + 1) begin

    // Configuration Phase
    if (run_iter == 0) begin
        $display("#########################################################");
        $display("### CONFIGURING FOR 2-BIT MODE (SIMD) ###");
        $display("#########################################################");
        mode = 1; // Enable SIMD/2-bit mode
        mode_prefix = "2b"; // Expects files like "2b_activation_tile0.txt"
    end else begin
        $display("#########################################################");
        $display("### CONFIGURING FOR 4-BIT MODE (VANILLA) ###");
        $display("#########################################################");
        mode = 0; // Disable SIMD/Enable Vanilla 4-bit
        mode_prefix = "4b"; // Expects files like "4b_activation_tile0.txt"
    end

    // Open Activation File based on mode
    $sformat(x_file_name, "%s/%s_activation_tile0.txt", input_dir, mode_prefix);
    x_file = $fopen(x_file_name, "r");
    if (x_file == 0) begin
        $display("Error: Could not open %s", x_file_name);
        $finish;
    end

    // Remove headers
    x_scan_file = $fscanf(x_file,"%s", captured_data);
    x_scan_file = $fscanf(x_file,"%s", captured_data);
    x_scan_file = $fscanf(x_file,"%s", captured_data);

    // //////// Reset core /////////
    // Note: We reset at the start of EVERY mode change to ensure clean state
    #0.5 clk = 1'b0;   reset = 1;
    #0.5 clk = 1'b1; 

    for (i=0; i<10 ; i=i+1) begin
      #0.5 clk = 1'b0;
      #0.5 clk = 1'b1;  
    end

    #0.5 clk = 1'b0;   reset = 0;
    #0.5 clk = 1'b1; 

    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
    // /////////////////////////

    // /////// Activation data writing to memory ///////
    for (t=0; t<len_nij; t=t+1) begin  
      #0.5 clk = 1'b0;  x_scan_file = $fscanf(x_file,"%32b", D_xmem); WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1;
      #0.5 clk = 1'b1;   
    end

    #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
    #0.5 clk = 1'b1; 

    $fclose(x_file);
    // /////////////////////////////////////////////////


    // WEIGHT LOADING LOOP
    for (kij=0; kij<len_kij; kij=kij+1) begin  

      // Select weight file based on mode
      $sformat(w_file_name, "%s/%s_weight_itile0_otile0_kij%0d.txt", input_dir, mode_prefix, kij);
      w_file = $fopen(w_file_name, "r");
      
      if (w_file == 0) begin
         $display("Error: Could not open %s", w_file_name);
         $finish;
      end

      w_scan_file = $fscanf(w_file,"%s", captured_data);
      w_scan_file = $fscanf(w_file,"%s", captured_data);
      w_scan_file = $fscanf(w_file,"%s", captured_data);

      // Reset
      #0.5 clk = 1'b0;   reset = 1;
      #0.5 clk = 1'b1; 

      for (i=0; i<10 ; i=i+1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;  
      end

      #0.5 clk = 1'b0;   reset = 0;
      #0.5 clk = 1'b1; 

      #0.5 clk = 1'b0;   
      #0.5 clk = 1'b1;   

      // /////// Kernel data writing to memory ///////
      A_xmem = 11'b10000000000;

      for (t=0; t<col; t=t+1) begin  
        #0.5 clk = 1'b0;  w_scan_file = $fscanf(w_file,"%32b", D_xmem); WEN_xmem = 0; CEN_xmem = 0; if (t>0) A_xmem = A_xmem + 1; 
        #0.5 clk = 1'b1;  
      end

      #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0;
      #0.5 clk = 1'b1; 
      $fclose(w_file); // Close weight file after reading
      // /////////////////////////////////////


      // /////// Kernel data writing to L0 ///////
      A_xmem = 11'b10000000000; 
      CEN_xmem = 0;
      WEN_xmem = 1;
      l0_wr = 1;

      for (t=0; t<col; t=t+1) begin
        #0.5 clk = 1'b0; if(t > 0) A_xmem = A_xmem + 1;
        #0.5 clk = 1'b1;
      end

      #0.5 clk = 1'b0; l0_wr = 0; CEN_xmem = 0; 
      #0.5 clk = 1'b1;
      // /////////////////////////////////////


      // /////// Kernel loading to PEs ///////
      // This logic remains the same for both 2-bit and 4-bit
      // The content of the weight files handles the packing
      CEN_xmem = 1; WEN_xmem = 1;

      #0.5 clk = 1'b0; load = 1'b1; l0_rd = 1'b1; execute = 1'b0; 

      for (t = 0; t < col; t = t + 1) begin 
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
      end

      #0.5 clk = 1'b0; load = 1'b0; l0_rd = 1'b0;
      #0.5 clk = 1'b1;
      // /////////////////////////////////////
    

      // ////// Intermission /////
      #0.5 clk = 1'b0;  load = 0; l0_rd = 0;
      #0.5 clk = 1'b1;  
    
      for (i=0; i<10 ; i=i+1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;  
      end
      // /////////////////////////////////////


      // /////// Activation data writing to L0 ///////
      #0.5 clk = 1'b0; l0_wr = 1;  CEN_xmem = 0; WEN_xmem = 1; A_xmem = 0; 

      for (t=0; t<len_nij; t=t+1) begin
        #0.5 clk = 1'b0; if(t > 0) A_xmem = A_xmem + 1;
        #0.5 clk = 1'b1;
      end

      #0.5 clk = 1'b0; l0_wr = 0; CEN_xmem = 1; 
      #0.5 clk = 1'b1;
      // /////////////////////////////////////


      // /////// Execution ///////
      #0.5 clk = 1'b0; 
        l0_rd    = 1'b1;   
        ififo_wr = 1'b1;   
        execute  = 1'b0;   
        ififo_rd = 1'b0;
      #0.5 clk = 1'b1;

      for (t = 0; t < len_nij; t = t + 1) begin
        #0.5 clk = 1'b0; 
        #0.5 clk = 1'b1;
      end

      #0.5 clk = 1'b0;
        l0_rd    = 1'b0;
        ififo_wr = 1'b0;
      #0.5 clk = 1'b1;

      #0.5 clk = 1'b0;
        execute  = 1'b1;   
        ififo_rd = 1'b1;   
      #0.5 clk = 1'b1;

      for (t = 0; t < len_nij + col + row; t = t + 1) begin
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;
      end

      #0.5 clk = 1'b0;
        execute  = 1'b0;
        ififo_rd = 1'b0;
      #0.5 clk = 1'b1;
    
      // /////////////////////////////////////


      // //////// OFIFO READ ////////
      for (t = 0; t < len_onij; t = t + 1) begin
        #0.5 clk = 1'b0;
          ofifo_rd = 1'b1;       
        #0.5 clk = 1'b1;
      end

      #0.5 clk = 1'b0;
        ofifo_rd = 1'b0;
      #0.5 clk = 1'b1;
      // /////////////////////////////////////


    end  // end of kij loop


    // ////////// Accumulation & Verification /////////
    $sformat(out_file_name, "%s/%s_out.txt", input_dir, mode_prefix);
    $sformat(acc_file_name, "%s/%s_acc.txt", input_dir, mode_prefix);

    out_file = $fopen(out_file_name, "r");  
    acc_file = $fopen(acc_file_name, "r"); 

    if (out_file == 0 || acc_file == 0) begin
        $display("Error: Could not open output or acc files for %s", mode_prefix);
        $finish;
    end

    out_scan_file = $fscanf(out_file,"%s", answer); 
    out_scan_file = $fscanf(out_file,"%s", answer); 
    out_scan_file = $fscanf(out_file,"%s", answer); 

    error = 0;

    $display("############ Verification Start for %s mode #############", mode_prefix); 

    for (i=0; i<len_onij+1; i=i+1) begin 

      #0.5 clk = 1'b0; 
      #0.5 clk = 1'b1; 

      if (i>0) begin
       out_scan_file = $fscanf(out_file,"%128b", answer); 
         if (sfp_out == answer)
           $display("%2d-th output featuremap Data matched! :D", i); 
         else begin
           $display("%2d-th output featuremap Data ERROR!!", i); 
           $display("sfpout: %128b", sfp_out);
           $display("answer: %128b", answer);
           error = 1;
         end
      end
     
      #0.5 clk = 1'b0; reset = 1;
      #0.5 clk = 1'b1;  
      #0.5 clk = 1'b0; reset = 0; 
      #0.5 clk = 1'b1;  

      for (j=0; j<len_kij+1; j=j+1) begin 
        #0.5 clk = 1'b0;    
          if (j<len_kij) begin CEN_pmem = 0; WEN_pmem = 1; acc_scan_file = $fscanf(acc_file,"%11b", A_pmem); end
                         else  begin CEN_pmem = 1; WEN_pmem = 1; end

          if (j>0)  acc = 1;  
        #0.5 clk = 1'b1;    
      end

      #0.5 clk = 1'b0; acc = 0;
      #0.5 clk = 1'b1; 
    end


    if (error == 0) begin
      $display("############ No error detected for %s mode ##############", mode_prefix); 
    end else begin
      $display("############ FAILED: Errors in %s mode ##############", mode_prefix); 
    end

    $fclose(acc_file);
    $fclose(out_file);
    // //////////////////////////////////

  end // END OF RECONFIGURABILITY LOOP

  $display("########### TB Completed ############"); 
  
  for (t=0; t<10; t=t+1) begin  
    #0.5 clk = 1'b0;  
    #0.5 clk = 1'b1;  
  end

  #10 $finish;

end

always @ (posedge clk) begin
   inst_w_q   <= inst_w; 
   D_xmem_q   <= D_xmem;
   CEN_xmem_q <= CEN_xmem;
   WEN_xmem_q <= WEN_xmem;
   A_pmem_q   <= A_pmem;
   CEN_pmem_q <= CEN_pmem;
   WEN_pmem_q <= WEN_pmem;
   A_xmem_q   <= A_xmem;
   ofifo_rd_q <= ofifo_rd;
   acc_q      <= acc;
   ififo_wr_q <= ififo_wr;
   ififo_rd_q <= ififo_rd;
   l0_rd_q    <= l0_rd;
   l0_wr_q    <= l0_wr ;
   execute_q  <= execute;
   load_q     <= load;
   mode_q     <= mode; // Propagate mode bit
end


endmodule
