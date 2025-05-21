module button_debouncer 
(
   input      clk,              
   input      unfiltered, 
   output reg filtered
);

   parameter HIGHBIT = 14;
   
   reg [HIGHBIT:0] count;
   reg button_state;

   reg [2:0] input_sampling; 

   always @(posedge clk) begin
      input_sampling <= {input_sampling[1:0], unfiltered};
      
      if (~filtered) begin
         if (~input_sampling[2]) begin 
            count <= 'd0;
         end else if (~count[HIGHBIT]) begin
            count <= count + 1;
         end
         if (count[HIGHBIT]) begin
            filtered <= 1'b1;
            count <= 'd0;
         end
      end else begin
         if (input_sampling[2]) begin 
            count <= 'd0;
         end else if (~count[HIGHBIT]) begin
            count <= count + 1;
         end
         if (count[HIGHBIT]) begin
            filtered <= 1'b0;
            count <= 'd0;
         end
      end
      
   end

endmodule
