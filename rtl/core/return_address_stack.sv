module return_address_stack #(
  parameter DEPTH_LOG2=4, 
  parameter PC_WIDTH=32
)(
  input logic clk,
  input logic rst,
  
  input logic spec_push,       
  input logic spec_pop,        
  input logic [PC_WIDTH-1:0] push_addr,        
  output logic [PC_WIDTH-1:0] pop_addr,        
  output logic [DEPTH_LOG2-1:0] tos_snapshot,   
  
  input logic mispredict_flush,
  input logic [DEPTH_LOG2-1:0] recovery_tos   
);

  localparam DEPTH=1<<DEPTH_LOG2;
  (* ram_style="distributed" *) logic [PC_WIDTH-1:0] stack[0:DEPTH-1];
  logic [DEPTH_LOG2-1:0] tos;
  
  assign tos_snapshot=tos;
  assign pop_addr=stack[tos];

  always_ff @(posedge clk) begin
    if(rst) begin
      tos<='0;
      for(int i=0;i<DEPTH;i++) stack[i]<='0; 
    end else if(mispredict_flush) begin
      tos<=recovery_tos;
    end else begin
      if(spec_push&&!spec_pop) begin
        stack[tos+1]<=push_addr;
        tos<=tos+1;
      end else if(spec_pop&&!spec_push) begin
        tos<=tos-1;
      end else if(spec_push&&spec_pop) begin
        stack[tos]<=push_addr; 
      end
    end
  end
endmodule