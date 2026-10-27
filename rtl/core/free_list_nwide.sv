//Copyright 2026 Atul Kumar
module free_list_nwide #(
  parameter PRF_ENTRIES=96,
  parameter ARCH_REGS=32,
  parameter TAG_WIDTH=7,
  parameter N=4,
  parameter ROB_W=6
)(
  input logic clk,
  input logic rst,
  
  input logic [N-1:0] pop_req_mask,
  output logic pop_success,
  output logic [TAG_WIDTH-1:0] allocated_tags[N],
  output logic [6:0] free_count_out, 
  
  input logic [3:0] push_count,
  input logic [TAG_WIDTH-1:0] freed_tags[N],
  
  input logic write_chkpt_en[N],
  input logic [ROB_W-1:0] write_chkpt_rob[N],
  input logic early_flush,
  input logic [ROB_W-1:0] early_flush_rob_idx,
  
  input logic mispredict_flush,
  input logic [PRF_ENTRIES-1:0] committed_tags_mask
);

  logic [TAG_WIDTH-1:0] fifo_mem[0:PRF_ENTRIES-1];
  logic [$clog2(PRF_ENTRIES):0] head_ptr,tail_ptr;
  logic [$clog2(PRF_ENTRIES):0] current_free_count;
  
  logic [$clog2(PRF_ENTRIES):0] chkpt_head[0:(1<<ROB_W)-1];
  
  logic [$clog2(PRF_ENTRIES):0] head_cascade[N+1];
  logic [$clog2(PRF_ENTRIES):0] next_head,next_tail;
  
  logic [3:0] pop_count;
  logic [3:0] safe_push_count;
  logic [TAG_WIDTH-1:0] safe_freed_tags[N];

  always_comb begin
    pop_count=0;
    for(int i=0;i<N;i++) if(pop_req_mask[i]) pop_count++;

    safe_push_count=0;
    for(int i=0;i<N;i++) safe_freed_tags[i]='0;
    for(int i=0;i<N;i++) begin
      if(i<push_count&&freed_tags[i]!=0) begin
        safe_freed_tags[safe_push_count]=freed_tags[i];
        safe_push_count++;
      end
    end
  end
  
  assign current_free_count=(tail_ptr>=head_ptr)?(tail_ptr-head_ptr):(PRF_ENTRIES+tail_ptr-head_ptr);
  assign free_count_out=current_free_count[6:0]; 
  assign pop_success=(current_free_count>=$bits(current_free_count)'(pop_count));

  always_comb begin
    head_cascade[0]=head_ptr;
    for(int i=0;i<N;i++) begin
      head_cascade[i+1]=(head_cascade[i]+(pop_req_mask[i]?1:0))%PRF_ENTRIES;
      allocated_tags[i]=fifo_mem[(head_cascade[i])%PRF_ENTRIES];
    end
    
    next_head=head_ptr;
    next_tail=tail_ptr;
    if(pop_success&&pop_count>0) next_head=head_cascade[N];
    if(safe_push_count>0) next_tail=(tail_ptr+safe_push_count)%PRF_ENTRIES;
  end

  always_ff @(posedge clk) begin
    if(rst) begin
      for(int j=0;j<(PRF_ENTRIES-ARCH_REGS);j++) begin
        fifo_mem[j]<=TAG_WIDTH'(ARCH_REGS+j);
      end
      head_ptr<='0;
      tail_ptr<=$bits(tail_ptr)'(PRF_ENTRIES-ARCH_REGS); 
    end else if(mispredict_flush) begin
      automatic int p=0;
      for(int i=1;i<PRF_ENTRIES;i++) begin
        if(!committed_tags_mask[i]) begin
          fifo_mem[p]<=i[TAG_WIDTH-1:0];
          p++;
        end
      end
      head_ptr<='0;
      tail_ptr<=p;
    end else begin
      if(early_flush) head_ptr<=chkpt_head[early_flush_rob_idx];
      else head_ptr<=next_head;
      
      tail_ptr<=next_tail;
      
      if(safe_push_count>0) begin
        for(int k=0;k<N;k++) begin
          if(k<safe_push_count) begin
            fifo_mem[(tail_ptr+k)%PRF_ENTRIES]<=safe_freed_tags[k];
          end
        end
      end
      
      for(int i=0;i<N;i++) begin
        if(write_chkpt_en[i]) begin
          chkpt_head[write_chkpt_rob[i]]<=head_cascade[i+1];
        end
      end
    end
  end
endmodule
