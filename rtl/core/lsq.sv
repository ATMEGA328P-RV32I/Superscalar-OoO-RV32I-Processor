//Copyright 2026 Atul Kumar
module lsq #(
  parameter LSQ_ENTRIES=16,
  parameter DATA_W=32,
  parameter TAG_W=7,
  parameter ROB_W=6,
  parameter N=4
)(
  input logic clk,rst,exception_flush,
  
  input logic early_flush,
  input logic [ROB_W-1:0] early_flush_rob_idx,
  input logic [3:0] early_flush_lsq_tail,
  input logic [ROB_W-1:0] rob_head,

  input logic disp_valid[N],
  input logic disp_is_store[N],
  input logic [ROB_W-1:0] disp_rob_idx[N],
  output logic [4:0] lsq_spaces_free,
  output logic [3:0] lsq_alloc_idx,

  input logic issue_valid,
  input logic [3:0] issue_lsq_idx,
  input logic issue_is_store,
  input logic [1:0] issue_mem_size,      
  input logic issue_mem_unsigned,  
  input logic [DATA_W-1:0] rs1_base,
  input logic [DATA_W-1:0] rs2_data,
  input logic [DATA_W-1:0] imm,
  input logic [TAG_W-1:0] rd_tag,
  input logic [ROB_W-1:0] rob_idx,

  output logic cdb_valid,
  output logic [TAG_W-1:0] cdb_tag,
  output logic [DATA_W-1:0] cdb_data,
  output logic [ROB_W-1:0] cdb_rob_idx,

  input logic commit_valid[N],
  input logic [ROB_W-1:0] commit_rob_idx[N],
  input logic commit_is_store[N], 

  output logic dcache_req_valid,
  output logic [DATA_W-1:0] dcache_req_addr,
  input logic dcache_resp_valid,
  input logic [DATA_W-1:0] dcache_resp_data,
  
  output logic dcache_st_valid,
  output logic [3:0] dcache_st_we,        
  output logic [DATA_W-1:0] dcache_st_addr,
  output logic [DATA_W-1:0] dcache_st_data,

  output logic mshr_ready_out
);

  logic [LSQ_ENTRIES-1:0] lsq_valid,lsq_is_store,lsq_addr_valid;
  logic [ROB_W-1:0] lsq_rob_idx[LSQ_ENTRIES];
  logic [DATA_W-1:0] lsq_addr[LSQ_ENTRIES],lsq_data[LSQ_ENTRIES];
  logic [1:0] lsq_mem_size[LSQ_ENTRIES];     
  logic lsq_mem_unsigned[LSQ_ENTRIES]; 

  logic [3:0] head,tail;
  logic [4:0] count;
  
  assign lsq_spaces_free=LSQ_ENTRIES-count;
  assign lsq_alloc_idx=tail;

  logic [3:0] disp_count;
  always_comb begin
    disp_count=0;
    for(int i=0;i<N;i++) if(disp_valid[i]) disp_count++;
  end

  logic [DATA_W-1:0] calc_addr;
  agu #(.DATA_W(DATA_W)) agu_inst(.rs1_base(rs1_base),.imm_offset(imm),.calc_addr(calc_addr));

  logic [3:0] issue_idx_eff;
  logic issue_idx_found;

  always_comb begin
    issue_idx_eff=issue_lsq_idx; 
    issue_idx_found=1'b0;
    for(int e=0;e<LSQ_ENTRIES;e++) begin
      if(lsq_valid[e]&&(lsq_rob_idx[e]==rob_idx)) begin
        issue_idx_eff=e[3:0];
        issue_idx_found=1'b1;
      end
    end
  end

  function automatic logic is_younger(input logic [ROB_W-1:0] check_idx,branch_idx,h);
    logic [ROB_W-1:0] age_check=check_idx-h;
    logic [ROB_W-1:0] age_branch=branch_idx-h;
    return age_check>age_branch;
  endfunction

  logic forward_match;
  logic [DATA_W-1:0] forward_data;
  store_forwarding_cam #(.LSQ_ENTRIES(LSQ_ENTRIES),.DATA_W(DATA_W)) cam_inst(
    .issue_valid(issue_valid),.issue_is_store(issue_is_store),
    .issue_lsq_idx(issue_idx_eff), 
    .calc_addr(calc_addr),.lsq_head(head),
    .lsq_valid(lsq_valid),.lsq_is_store(lsq_is_store),.lsq_addr_valid(lsq_addr_valid),
    .lsq_addr(lsq_addr),.lsq_data(lsq_data),.forward_match(forward_match),.forward_data(forward_data)
  );

  logic mshr_ready,mshr_cdb_valid,mshr_dcache_req_valid;
  logic [TAG_W-1:0] mshr_cdb_tag;
  logic [DATA_W-1:0] mshr_cdb_data,mshr_dcache_req_addr;
  logic [ROB_W-1:0] mshr_cdb_rob;

  assign mshr_ready_out=mshr_ready;
  logic mshr_req_valid;
  assign mshr_req_valid=issue_valid&&!issue_is_store&&!forward_match&&mshr_ready;

  logic lsq_cdb_valid;
  logic [TAG_W-1:0] lsq_cdb_tag;
  logic [DATA_W-1:0] lsq_cdb_data;
  logic [ROB_W-1:0] lsq_cdb_rob;

  mshr #(.DATA_W(DATA_W),.TAG_W(TAG_W),.ROB_W(ROB_W)) mshr_inst(
    .clk(clk),.rst(rst),.exception_flush(exception_flush),
    .early_flush(early_flush),.early_flush_rob_idx(early_flush_rob_idx),.rob_head(rob_head),
    .lsq_cdb_valid(lsq_cdb_valid),
    .req_valid(mshr_req_valid),.req_addr(calc_addr),.req_rd_tag(rd_tag),.req_rob_idx(rob_idx), 
    .req_mem_size(issue_mem_size),.req_mem_unsigned(issue_mem_unsigned), 
    .mshr_ready(mshr_ready),.dcache_req_valid(mshr_dcache_req_valid),.dcache_req_addr(mshr_dcache_req_addr),
    .dcache_resp_valid(dcache_resp_valid),.dcache_resp_data(dcache_resp_data),
    .cdb_valid(mshr_cdb_valid),.cdb_tag(mshr_cdb_tag),.cdb_data(mshr_cdb_data),.cdb_rob_idx(mshr_cdb_rob)
  );

  assign cdb_valid=lsq_cdb_valid|mshr_cdb_valid;
  assign cdb_tag=lsq_cdb_valid?lsq_cdb_tag:mshr_cdb_tag;
  assign cdb_data=lsq_cdb_valid?lsq_cdb_data:mshr_cdb_data;
  assign cdb_rob_idx=lsq_cdb_valid?lsq_cdb_rob:mshr_cdb_rob;

  logic pop_lsq;
  always_comb begin
    pop_lsq=1'b0;
    for(int i=0;i<N;i++) begin
      if(commit_valid[i]&&lsq_valid[head]&&(lsq_rob_idx[head]==commit_rob_idx[i])) pop_lsq=1'b1;
    end
  end

  logic st_commit_hit;
  logic [3:0] st_commit_idx;
  always_comb begin
    st_commit_hit=1'b0; st_commit_idx='0;
    for(int i=0;i<N;i++) begin
      for(int e=0;e<LSQ_ENTRIES;e++) begin
        if(commit_valid[i]&&lsq_valid[e]&&lsq_is_store[e]&&
          lsq_addr_valid[e]&&(lsq_rob_idx[e]==commit_rob_idx[i])) begin
          st_commit_hit=1'b1; st_commit_idx=e[3:0];
        end
      end
    end
  end

  assign dcache_req_valid=mshr_dcache_req_valid;
  assign dcache_req_addr=mshr_dcache_req_addr;
  
  assign dcache_st_valid=st_commit_hit;
  assign dcache_st_addr=lsq_addr[st_commit_idx];

  always_comb begin
    dcache_st_we=4'b0000;
    dcache_st_data=lsq_data[st_commit_idx];
    if(st_commit_hit) begin
      logic [1:0] s_size=lsq_mem_size[st_commit_idx];
      logic [1:0] s_lsb=lsq_addr[st_commit_idx][1:0];
      logic [31:0] s_raw=lsq_data[st_commit_idx];
      if(s_size==2'b00) begin
        dcache_st_we=4'b0001<<s_lsb;
        dcache_st_data={4{s_raw[7:0]}}; 
      end else if(s_size==2'b01) begin
        dcache_st_we=4'b0011<<s_lsb;
        dcache_st_data={2{s_raw[15:0]}};
      end else begin
        dcache_st_we=4'b1111;
        dcache_st_data=s_raw;
      end
    end
  end

  function automatic logic [31:0] format_load(logic [31:0] raw,logic [1:0] sz,logic uns,logic [1:0] lsb);
    logic [31:0] shifted=raw>>(lsb*8);
    if(sz==2'b00) return uns?{24'b0,shifted[7:0]}:{{24{shifted[7]}},shifted[7:0]};
    if(sz==2'b01) return uns?{16'b0,shifted[15:0]}:{{16{shifted[15]}},shifted[15:0]};
    return raw;
  endfunction

  always_ff @(posedge clk) begin
    if(rst||exception_flush) begin
      head<='0; tail<='0; count<='0;
      lsq_valid<='0; lsq_addr_valid<='0;
      lsq_cdb_valid<=1'b0; lsq_cdb_data<='0; lsq_cdb_tag<='0;
    end else begin
      automatic logic [4:0] next_count=count;
      lsq_cdb_valid<=1'b0; 
      
      if(early_flush) begin
        automatic int killed=0; 
        tail<=early_flush_lsq_tail;
        
        for(int i=0;i<LSQ_ENTRIES;i++) begin
          if(lsq_valid[i]&&is_younger(lsq_rob_idx[i],early_flush_rob_idx,rob_head)) begin
            lsq_valid[i]<=1'b0;
            lsq_addr_valid[i]<=1'b0;
            killed++;
          end
        end
        count<=count-5'(killed)-(pop_lsq?5'd1:5'd0);
      end else begin
        if(disp_count>0&&lsq_spaces_free>=disp_count) begin
          automatic logic [4:0] cur_tail=tail; 
          for(int i=0;i<N;i++) begin
            if(disp_valid[i]) begin
              lsq_valid[cur_tail[3:0]]<=1'b1; 
              lsq_is_store[cur_tail[3:0]]<=disp_is_store[i];
              lsq_rob_idx[cur_tail[3:0]]<=disp_rob_idx[i]; 
              lsq_addr_valid[cur_tail[3:0]]<=1'b0;
              cur_tail++;
            end
          end
          tail<=tail+disp_count; 
          next_count=next_count+disp_count;
        end
      end

      if(issue_valid) begin 
        if(issue_is_store) begin
          lsq_addr_valid[issue_idx_eff]<=1'b1; 
          lsq_addr[issue_idx_eff]<=calc_addr;
          lsq_data[issue_idx_eff]<=rs2_data; 
          lsq_mem_size[issue_idx_eff]<=issue_mem_size;
          lsq_mem_unsigned[issue_idx_eff]<=issue_mem_unsigned;
          
          lsq_cdb_valid<=1'b1;
          lsq_cdb_tag<=rd_tag; lsq_cdb_rob<=rob_idx;
          lsq_cdb_data<='0; 
        end else begin
          if(forward_match) begin
            lsq_cdb_valid<=1'b1; 
            lsq_cdb_tag<=rd_tag;
            lsq_cdb_rob<=rob_idx; 
            lsq_cdb_data<=format_load(forward_data,issue_mem_size,issue_mem_unsigned,calc_addr[1:0]);
          end
        end
      end

      if(pop_lsq) begin
        lsq_valid[head]<=1'b0; 
        head<=head+1; 
        if(!early_flush) next_count=next_count-1;
      end
      
      if(!early_flush) count<=next_count;
    end
  end
endmodule
