module reorder_buffer #(
  parameter ROB_ENTRIES=64,
  parameter N=4,
  parameter TAG_W=7,
  parameter ARCH_REGS=32
)(
  input logic clk,
  input logic rst,
  
  input logic dispatch_valid[N],
  input logic [4:0] dispatch_rd_arch[N],
  input logic [TAG_W-1:0] dispatch_rd_phys[N],
  input logic [TAG_W-1:0] dispatch_stale_phys[N],
  input logic dispatch_is_store[N],
  input logic dispatch_is_mem[N], 
  
  output logic [$clog2(ROB_ENTRIES)-1:0] rob_tail_ptr,
  output logic [$clog2(ROB_ENTRIES)-1:0] rob_head_ptr,
  output logic [$clog2(ROB_ENTRIES):0] rob_spaces_free, 
  output logic [(1<<$clog2(ROB_ENTRIES))-1:0] rob_valid_mask,
  
  input logic cdb_valid[N],
  input logic [$clog2(ROB_ENTRIES)-1:0] cdb_rob_idx[N],
  input logic [31:0] cdb_branch_target[N],
  input logic cdb_exception[N],
  
  input logic early_flush,
  input logic [$clog2(ROB_ENTRIES)-1:0] early_flush_rob_idx,
  
  output logic commit_valid[N],
  output logic [4:0] commit_rd_arch[N],
  output logic [TAG_W-1:0] commit_rd_phys[N],
  output logic [TAG_W-1:0] commit_stale_phys[N],
  output logic commit_is_store[N],
  output logic [$clog2(ROB_ENTRIES)-1:0] commit_rob_idx[N], 
  
  output logic exception_flush,
  output logic [31:0] commit_recovery_pc 
);

  localparam ROB_IDX_W=$clog2(ROB_ENTRIES);

  typedef struct packed {
    logic valid;
    logic done;
    logic exception;
    logic [4:0] rd_arch;
    logic [TAG_W-1:0] rd_phys;
    logic [TAG_W-1:0] stale_phys;
    logic is_store;
    logic is_mem; 
    logic [31:0] recovery_target;
  } rob_entry_t;

  rob_entry_t rob_mem[0:ROB_ENTRIES-1];
  logic [ROB_IDX_W:0] head_ptr,tail_ptr,current_occupancy;
  
  assign current_occupancy=tail_ptr-head_ptr;
  assign rob_spaces_free=$bits(rob_spaces_free)'(ROB_ENTRIES)-current_occupancy;
  assign rob_tail_ptr=tail_ptr[ROB_IDX_W-1:0];
  assign rob_head_ptr=head_ptr[ROB_IDX_W-1:0];
  
  always_comb begin
    for(int i=0;i<ROB_ENTRIES;i++) rob_valid_mask[i]=rob_mem[i].valid;
  end
  
  logic [N-1:0] can_commit,hit_exception;
  logic [3:0] commit_count,dispatch_count;
  logic [ROB_IDX_W-1:0] alloc_idx[N];
  int mem_commits_this_cycle; 
  
  function automatic logic is_younger(input logic [ROB_IDX_W-1:0] check_idx,branch_idx,head_idx);
    logic [ROB_IDX_W-1:0] age_check=check_idx-head_idx;
    logic [ROB_IDX_W-1:0] age_branch=branch_idx-head_idx;
    return age_check>age_branch;
  endfunction
  
  always_comb begin
    logic [ROB_IDX_W-1:0] head_idx0,head_idx_i;
    head_idx0=head_ptr[ROB_IDX_W-1:0];
    mem_commits_this_cycle=0;
    
    if(rob_mem[head_idx0].valid&rob_mem[head_idx0].done) begin
      can_commit[0]=1'b1;
      if(rob_mem[head_idx0].is_mem) mem_commits_this_cycle++;
    end else can_commit[0]=1'b0;
    
    hit_exception[0]=can_commit[0]&rob_mem[head_idx0].exception;
    
    for(int i=1;i<N;i++) begin
      head_idx_i=(head_ptr+i)%ROB_ENTRIES;
      if(rob_mem[head_idx_i].is_mem&&mem_commits_this_cycle>=1) can_commit[i]=1'b0;
      else begin
        can_commit[i]=can_commit[i-1]&!hit_exception[i-1]&rob_mem[head_idx_i].valid&rob_mem[head_idx_i].done;
        if(can_commit[i]&&rob_mem[head_idx_i].is_mem) mem_commits_this_cycle++;
      end
      hit_exception[i]=can_commit[i]&rob_mem[head_idx_i].exception;
    end
    
    exception_flush=1'b0;
    commit_count=0;
    commit_recovery_pc='0;
    
    for(int i=0;i<N;i++) begin
      head_idx_i=(head_ptr+i)%ROB_ENTRIES;
      commit_valid[i]=can_commit[i]; 
      commit_rd_arch[i]=rob_mem[head_idx_i].rd_arch;
      commit_rd_phys[i]=rob_mem[head_idx_i].rd_phys;
      commit_stale_phys[i]=rob_mem[head_idx_i].stale_phys;
      commit_is_store[i]=rob_mem[head_idx_i].is_store;
      commit_rob_idx[i]=head_idx_i; 
      
      if(commit_valid[i]) commit_count=commit_count+1;
      
      if(hit_exception[i]) begin
        exception_flush=1'b1;
        commit_recovery_pc=rob_mem[head_idx_i].recovery_target;
      end
    end
  end

  always_comb begin
    logic [3:0] current_offset;
    current_offset=0;
    dispatch_count=0;
    for(int i=0;i<N;i++) begin
      alloc_idx[i]=(tail_ptr+current_offset)%ROB_ENTRIES;
      if(dispatch_valid[i]) begin
        current_offset=current_offset+1;
        dispatch_count=dispatch_count+1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if(rst||exception_flush) begin
      head_ptr<='0; tail_ptr<='0;
      for(int i=0;i<ROB_ENTRIES;i++) rob_mem[i]<='0;
    end else begin
      head_ptr<=head_ptr+commit_count;
      for(int i=0;i<N;i++) begin
        if(commit_valid[i]) rob_mem[(head_ptr+i)%ROB_ENTRIES].valid<=1'b0;
      end

      for(int i=0;i<N;i++) begin
        if(cdb_valid[i]) begin
          rob_mem[cdb_rob_idx[i]].done<=1'b1;
          rob_mem[cdb_rob_idx[i]].exception<=cdb_exception[i];
          rob_mem[cdb_rob_idx[i]].recovery_target<=cdb_branch_target[i];
        end
      end

      if(early_flush) begin
        logic phase_bit;
        phase_bit=(early_flush_rob_idx>=head_ptr[ROB_IDX_W-1:0])?head_ptr[ROB_IDX_W]:!head_ptr[ROB_IDX_W];
        tail_ptr<={phase_bit,early_flush_rob_idx}+1;
        
        for(int i=0;i<ROB_ENTRIES;i++) begin
          if(rob_mem[i].valid&&is_younger(i[ROB_IDX_W-1:0],early_flush_rob_idx,head_ptr[ROB_IDX_W-1:0])) begin
            rob_mem[i].valid<=1'b0;
          end
        end
      end else begin
        tail_ptr<=tail_ptr+dispatch_count;
        for(int i=0;i<N;i++) begin
          if(dispatch_valid[i]) begin
            rob_mem[alloc_idx[i]].valid<=1'b1;
            rob_mem[alloc_idx[i]].done<=1'b0; 
            rob_mem[alloc_idx[i]].exception<=1'b0;
            rob_mem[alloc_idx[i]].rd_arch<=dispatch_rd_arch[i];
            rob_mem[alloc_idx[i]].rd_phys<=dispatch_rd_phys[i];
            rob_mem[alloc_idx[i]].stale_phys<=dispatch_stale_phys[i];
            rob_mem[alloc_idx[i]].is_store<=dispatch_is_store[i];
            rob_mem[alloc_idx[i]].is_mem<=dispatch_is_mem[i]; 
            rob_mem[alloc_idx[i]].recovery_target<='0;
          end
        end
      end
    end
  end
endmodule