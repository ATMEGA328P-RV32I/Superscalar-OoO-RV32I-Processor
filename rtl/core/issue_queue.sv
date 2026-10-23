module issue_queue #(
  parameter IQ_ENTRIES=16, 
  parameter N=4,
  parameter TAG_W=7,
  parameter ROB_W=6
)(
  input logic clk,rst,exception_flush, 
  input logic early_flush,
  input logic [ROB_W-1:0] early_flush_rob_idx,
  input logic lsq_ready, 
  input logic [ROB_W-1:0] rob_head, 
  
  input logic disp_valid[N],
  input logic [TAG_W-1:0] disp_rs1_phys[N],
  input logic disp_rs1_ready[N], 
  input logic [TAG_W-1:0] disp_rs2_phys[N],
  input logic disp_rs2_ready[N],
  input logic [TAG_W-1:0] disp_rd_phys[N],
  input logic [ROB_W-1:0] disp_rob_idx[N],
  input logic [1:0] disp_fu_type[N], 
  
  output logic [$clog2(IQ_ENTRIES):0] iq_spaces_free,
  input logic cdb_valid[N],
  input logic [TAG_W-1:0] cdb_tag[N],
  
  output logic issue_valid[N],
  output logic [TAG_W-1:0] issue_rs1_phys[N],
  output logic [TAG_W-1:0] issue_rs2_phys[N],
  output logic [TAG_W-1:0] issue_rd_phys[N],
  output logic [ROB_W-1:0] issue_rob_idx[N]
);

  typedef struct packed {
    logic valid;
    logic [TAG_W-1:0] rs1_tag;
    logic rs1_ready;
    logic [TAG_W-1:0] rs2_tag;
    logic rs2_ready;
    logic [TAG_W-1:0] rd_tag;
    logic [ROB_W-1:0] rob_idx;
    logic [1:0] fu_type;
  } iq_entry_t;

  iq_entry_t iq[0:IQ_ENTRIES-1];
  logic [IQ_ENTRIES-1:0] rs1_match_matrix,rs2_match_matrix;
  logic mem_sel_d;
  
  always_ff @(posedge clk) begin
    if(rst||exception_flush) mem_sel_d<=1'b0;
    else mem_sel_d<=selected_valid[3];
  end
  
  always_comb begin
    rs1_match_matrix='0; rs2_match_matrix='0;
    for(int i=0;i<IQ_ENTRIES;i++) begin
      if(iq[i].valid) begin
        for(int c=0;c<N;c++) begin
          if(cdb_valid[c]&&(cdb_tag[c]==iq[i].rs1_tag)) rs1_match_matrix[i]=1'b1;
          if(cdb_valid[c]&&(cdb_tag[c]==iq[i].rs2_tag)) rs2_match_matrix[i]=1'b1;
        end
      end
    end
  end

  logic [IQ_ENTRIES-1:0] ready_to_issue,mask_alu,mask_branch,mask_mem;
  logic [$clog2(IQ_ENTRIES)-1:0] selected_idx[N];
  logic selected_valid[N];

  function automatic logic older(input logic [ROB_W-1:0] a,b,h);
    logic [ROB_W-1:0] da,db;
    da=a-h; db=b-h;
    return da<db;
  endfunction
  
  function automatic logic is_younger(input logic [ROB_W-1:0] check_idx,branch_idx,h);
    logic [ROB_W-1:0] age_check=check_idx-h;
    logic [ROB_W-1:0] age_branch=branch_idx-h;
    return age_check>age_branch;
  endfunction
  
  logic oldest_mem_v; 
  logic [$clog2(IQ_ENTRIES)-1:0] oldest_mem_i;

  always_comb begin
    for(int i=0;i<IQ_ENTRIES;i++) begin
      ready_to_issue[i]=iq[i].valid&(iq[i].rs1_ready|rs1_match_matrix[i])&(iq[i].rs2_ready|rs2_match_matrix[i]);
      mask_alu[i]=ready_to_issue[i]&(iq[i].fu_type==2'd0);
      mask_branch[i]=ready_to_issue[i]&(iq[i].fu_type==2'd1);
      mask_mem[i]=iq[i].valid&(iq[i].fu_type==2'd2); 
    end
    
    selected_valid[0]=0; selected_idx[0]=0;
    for(int i=0;i<IQ_ENTRIES;i++) begin
      if(mask_alu[i]) begin
        if(!selected_valid[0]||older(iq[i].rob_idx,iq[selected_idx[0]].rob_idx,rob_head)) begin
          selected_valid[0]=1; selected_idx[0]=i[$clog2(IQ_ENTRIES)-1:0];
        end
      end
    end

    selected_valid[1]=0; selected_idx[1]=0;
    for(int i=0;i<IQ_ENTRIES;i++) begin
      if(mask_alu[i]&&!(selected_valid[0]&&selected_idx[0]==i[$clog2(IQ_ENTRIES)-1:0])) begin
        if(!selected_valid[1]||older(iq[i].rob_idx,iq[selected_idx[1]].rob_idx,rob_head)) begin
          selected_valid[1]=1; selected_idx[1]=i[$clog2(IQ_ENTRIES)-1:0];
        end
      end
    end

    selected_valid[2]=0; selected_idx[2]=0;
    for(int i=0;i<IQ_ENTRIES;i++) begin
      if(mask_branch[i]) begin 
        if(!selected_valid[2]||older(iq[i].rob_idx,iq[selected_idx[2]].rob_idx,rob_head)) begin
          selected_valid[2]=1; selected_idx[2]=i[$clog2(IQ_ENTRIES)-1:0]; 
        end
      end
    end

    oldest_mem_v=0; oldest_mem_i=0;
    for(int i=0;i<IQ_ENTRIES;i++) begin
      if(mask_mem[i]) begin
        if(!oldest_mem_v||older(iq[i].rob_idx,iq[oldest_mem_i].rob_idx,rob_head)) begin
          oldest_mem_v=1; oldest_mem_i=i[$clog2(IQ_ENTRIES)-1:0];
        end
      end
    end
    selected_valid[3]=oldest_mem_v&&lsq_ready&&!mem_sel_d&&ready_to_issue[oldest_mem_i];
    selected_idx[3]=oldest_mem_i;
  end

  logic [IQ_ENTRIES-1:0] free_slots,current_free_mask;
  logic [$clog2(IQ_ENTRIES)-1:0] alloc_idx[N];
  logic alloc_valid[N];
  logic [4:0] count;
  logic [$clog2(IQ_ENTRIES)-1:0] free_idx[N]; 
  logic free_vld[N];

  always_comb begin
    int rank; count=0;
    for(int i=0;i<IQ_ENTRIES;i++) begin 
      free_slots[i]=!iq[i].valid; 
      if(!iq[i].valid) count++; 
    end
    iq_spaces_free=count;
    
    current_free_mask=free_slots;
    for(int k=0;k<N;k++) begin
      free_vld[k]=0; free_idx[k]=0;
      for(int i=0;i<IQ_ENTRIES;i++) begin
        if(current_free_mask[i]) begin
          free_vld[k]=1; free_idx[k]=i[$clog2(IQ_ENTRIES)-1:0]; 
          break;
        end
      end
      if(free_vld[k]) current_free_mask[free_idx[k]]=1'b0;
    end
    
    rank=0;
    for(int d=0;d<N;d++) begin
      alloc_valid[d]=0; alloc_idx[d]='0;
      if(disp_valid[d]) begin 
        alloc_valid[d]=free_vld[rank]; 
        alloc_idx[d]=free_idx[rank]; 
        rank++; 
      end
    end
  end

  always_ff @(posedge clk) begin
    if(rst||exception_flush) begin
      for(int i=0;i<IQ_ENTRIES;i++) iq[i]<='0;
      for(int p=0;p<N;p++) issue_valid[p]<=1'b0;
    end else begin
      for(int port=0;port<N;port++) begin
        if(selected_valid[port]) begin
          issue_valid[port]<=1'b1;
          issue_rs1_phys[port]<=iq[selected_idx[port]].rs1_tag;
          issue_rs2_phys[port]<=iq[selected_idx[port]].rs2_tag;
          issue_rd_phys[port]<=iq[selected_idx[port]].rd_tag;
          issue_rob_idx[port]<=iq[selected_idx[port]].rob_idx;
          iq[selected_idx[port]].valid<=1'b0;
        end else begin
          issue_valid[port]<=1'b0;
        end
      end
      
      for(int i=0;i<IQ_ENTRIES;i++) begin
        if(iq[i].valid) begin
          if(rs1_match_matrix[i]) iq[i].rs1_ready<=1'b1;
          if(rs2_match_matrix[i]) iq[i].rs2_ready<=1'b1;
        end
      end
      
      if(early_flush) begin
        for(int i=0;i<IQ_ENTRIES;i++) begin
          if(iq[i].valid&&is_younger(iq[i].rob_idx,early_flush_rob_idx,rob_head)) begin
            iq[i].valid<=1'b0;
          end
        end
      end else begin
        for(int d=0;d<N;d++) begin
          if(disp_valid[d]&&alloc_valid[d]) begin
            iq[alloc_idx[d]].valid<=1'b1; iq[alloc_idx[d]].fu_type<=disp_fu_type[d];
            iq[alloc_idx[d]].rs1_tag<=disp_rs1_phys[d]; iq[alloc_idx[d]].rs2_tag<=disp_rs2_phys[d];
            iq[alloc_idx[d]].rd_tag<=disp_rd_phys[d]; iq[alloc_idx[d]].rob_idx<=disp_rob_idx[d];
            
            iq[alloc_idx[d]].rs1_ready<=disp_rs1_ready[d]| 
              (cdb_valid[0]&&cdb_tag[0]==disp_rs1_phys[d])|(cdb_valid[1]&&cdb_tag[1]==disp_rs1_phys[d])|
              (cdb_valid[2]&&cdb_tag[2]==disp_rs1_phys[d])|(cdb_valid[3]&&cdb_tag[3]==disp_rs1_phys[d]);
                                                                                                    
            iq[alloc_idx[d]].rs2_ready<=disp_rs2_ready[d]| 
              (cdb_valid[0]&&cdb_tag[0]==disp_rs2_phys[d])|(cdb_valid[1]&&cdb_tag[1]==disp_rs2_phys[d])|
              (cdb_valid[2]&&cdb_tag[2]==disp_rs2_phys[d])|(cdb_valid[3]&&cdb_tag[3]==disp_rs2_phys[d]);
          end
        end
      end
    end
  end
endmodule