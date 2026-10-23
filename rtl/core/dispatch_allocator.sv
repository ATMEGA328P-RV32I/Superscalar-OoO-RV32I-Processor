import rv32i_types_pkg::*;

module dispatch_allocator #(
  parameter FETCH_WIDTH=4,
  parameter ROB_IDX_W=6,
  parameter LSQ_IDX_W=5
)(
  input decoded_inst_t dec_insts[FETCH_WIDTH],
  
  input logic [6:0] free_list_available,
  input logic [6:0] rob_spaces_free,     
  input logic [4:0] iq_spaces_free,
  input logic [4:0] lsq_spaces_free,
  
  input logic [ROB_IDX_W-1:0] rob_tail_ptr,
  input logic [LSQ_IDX_W-1:0] lsq_tail_ptr,
  
  output logic dispatch_stall,
  
  output logic [FETCH_WIDTH-1:0] rob_alloc_en,
  output logic [ROB_IDX_W-1:0] rob_alloc_idx[FETCH_WIDTH],
  output logic [FETCH_WIDTH-1:0] iq_alloc_en,
  output logic [FETCH_WIDTH-1:0] lsq_alloc_en,
  output logic [LSQ_IDX_W-1:0] lsq_alloc_idx[FETCH_WIDTH]
);

  logic [3:0] valid_count,rename_count,lsq_count;
  
  always_comb begin
    valid_count=0; rename_count=0; lsq_count=0;
    for(int i=0;i<FETCH_WIDTH;i++) begin
      if(dec_insts[i].valid) begin
        valid_count++;
        if(dec_insts[i].uses_rd) rename_count++;
        if(dec_insts[i].is_load||dec_insts[i].is_store) lsq_count++;
      end
    end
    
    dispatch_stall=(valid_count>rob_spaces_free)|| 
             (valid_count>iq_spaces_free)|| 
             (rename_count>free_list_available)|| 
             (lsq_count>lsq_spaces_free);
  end

  always_comb begin
    logic [ROB_IDX_W-1:0] cur_rob;
    logic [LSQ_IDX_W-1:0] cur_lsq;
    cur_rob=rob_tail_ptr;
    cur_lsq=lsq_tail_ptr;
    
    for(int i=0;i<FETCH_WIDTH;i++) begin
      rob_alloc_en[i]=1'b0; iq_alloc_en[i]=1'b0; lsq_alloc_en[i]=1'b0;
      rob_alloc_idx[i]=cur_rob; lsq_alloc_idx[i]=cur_lsq;
      
      if(dec_insts[i].valid&&!dispatch_stall) begin
        rob_alloc_en[i]=1'b1; iq_alloc_en[i]=1'b1;
        cur_rob=cur_rob+1;
        
        if(dec_insts[i].is_load||dec_insts[i].is_store) begin
          lsq_alloc_en[i]=1'b1; cur_lsq=cur_lsq+1;
        end
      end
    end
  end
endmodule