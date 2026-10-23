import rv32i_types_pkg::*;

module superscalar_core_top #(
  parameter N=4,
  parameter DATA_W=32,
  parameter TAG_W=7,
  parameter ROB_W=6,
  parameter IQ_ENTRIES=16,
  parameter LSQ_ENTRIES=16,
  parameter PRF_ENTRIES=96
)(
  input logic clk,
  input logic rst
);

  logic exception_flush;
  logic dispatch_stall;
  logic [DATA_W-1:0] commit_recovery_pc; 
  
  logic early_flush;
  logic effective_early_flush;
  logic [DATA_W-1:0] early_flush_target;
  logic [ROB_W-1:0] early_flush_rob_idx;
  logic [7:0] early_flush_bhr;
  logic [3:0] early_flush_tos;

  assign effective_early_flush=early_flush&&!exception_flush;

  logic [DATA_W-1:0] fetch_pc;
  logic [DATA_W-1:0] fetched_insts_unpacked[N];
  logic [(N*32)-1:0] fetched_insts_packed;
  
  always_comb begin
    for(int i=0;i<N;i++) begin
      fetched_insts_packed[(i*32)+:32]=fetched_insts_unpacked[i];
    end
  end

  logic [(N*32)-1:0] f2d_insts;
  logic [DATA_W-1:0] f2d_pc;
  logic [N-1:0] f2d_valid_mask;
  logic f2d_pred_taken[N];
  logic [DATA_W-1:0] f2d_pred_target[N];
  logic [7:0] f2d_pred_bhr[N];      
  logic [3:0] f2d_tos[N]; 
  
  decoded_inst_t dec_insts_raw[N];
  decoded_inst_t dec_insts[N];
  
  logic [DATA_W-1:0] disp_pc[N],disp_imm[N];
  logic [3:0] disp_alu_ctrl[N];
  logic [2:0] disp_branch_type[N];
  logic [4:0] disp_rd_arch[N];
  logic disp_is_store[N],disp_is_load[N],disp_is_alu_imm[N],disp_is_mem[N]; 
  logic [1:0] disp_fu_type[N]; 
  logic disp_is_auipc[N],disp_is_jalr[N],disp_is_jump[N],disp_is_branch[N]; 
  logic disp_is_call[N],disp_is_ret[N]; 

  logic [DATA_W-1:0] aligned_decode_base;
  logic [31:0] raw_inst[N];
  logic [6:0] opcode[N];
  logic [31:0] b_imm[N],j_imm[N],s_imm[N],i_imm[N],u_imm[N];
  logic is_lui[N];

  always_comb begin
    aligned_decode_base={f2d_pc[31:4],4'b0000}; 
    for(int i=0;i<N;i++) begin
      raw_inst[i]=f2d_insts[(i*32)+:32];
      opcode[i]=raw_inst[i][6:0];
      dec_insts[i]=dec_insts_raw[i];
      
      disp_is_load[i]=(opcode[i]==7'b0000011);
      disp_is_store[i]=(opcode[i]==7'b0100011);
      disp_is_mem[i]=disp_is_load[i]|disp_is_store[i]; 
      disp_is_branch[i]=(opcode[i]==7'b1100011);
      disp_is_jalr[i]=(opcode[i]==7'b1100111);
      disp_is_jump[i]=(opcode[i]==7'b1101111)||disp_is_jalr[i];
      disp_is_auipc[i]=(opcode[i]==7'b0010111);
      is_lui[i]=(opcode[i]==7'b0110111);
      
      disp_is_call[i]=(opcode[i]==7'b1101111||opcode[i]==7'b1100111)&&(raw_inst[i][11:7]!=5'd0);
      disp_is_ret[i]=(opcode[i]==7'b1100111)&&(raw_inst[i][11:7]==5'd0)&&(raw_inst[i][19:15]!=5'd0);
      
      disp_is_alu_imm[i]=(opcode[i]==7'b0010011)||is_lui[i]||disp_is_auipc[i];

      b_imm[i]={{20{raw_inst[i][31]}},raw_inst[i][7],raw_inst[i][30:25],raw_inst[i][11:8],1'b0};
      j_imm[i]={{12{raw_inst[i][31]}},raw_inst[i][19:12],raw_inst[i][20],raw_inst[i][30:21],1'b0};
      s_imm[i]={{20{raw_inst[i][31]}},raw_inst[i][31:25],raw_inst[i][11:7]};
      i_imm[i]={{20{raw_inst[i][31]}},raw_inst[i][31:20]};
      u_imm[i]={raw_inst[i][31:12],12'b0};
      
      if(disp_is_branch[i]) disp_imm[i]=b_imm[i];
      else if(disp_is_store[i]) disp_imm[i]=s_imm[i];
      else if(opcode[i]==7'b1101111) disp_imm[i]=j_imm[i]; 
      else if(is_lui[i]||disp_is_auipc[i]) disp_imm[i]=u_imm[i];
      else disp_imm[i]=i_imm[i]; 
      
      disp_pc[i]=aligned_decode_base+(i*4); 
      disp_alu_ctrl[i]=dec_insts_raw[i].alu_op; 
      disp_branch_type[i]=raw_inst[i][14:12];
      disp_rd_arch[i]=dec_insts_raw[i].rd_arch;

      if(disp_is_store[i]||disp_is_load[i]) disp_fu_type[i]=2'd2; 
      else if(disp_is_branch[i]||disp_is_jump[i]) disp_fu_type[i]=2'd1; 
      else disp_fu_type[i]=2'd0; 
    end
  end

  logic [N-1:0] rob_alloc_en,iq_alloc_en,lsq_alloc_en;
  logic [ROB_W-1:0] rob_alloc_idx[N];
  logic [4:0] lsq_alloc_idx[N];
  logic [TAG_W-1:0] disp_rs1_phys[N],disp_rs2_phys[N],disp_rd_phys[N];
  logic [N-1:0] disp_valid_packed;
  logic disp_valid_unpacked[N];
  
  always_comb begin
    for(int i=0;i<N;i++) disp_valid_unpacked[i]=disp_valid_packed[i];
  end

  logic [ROB_W-1:0] rob_tail_ptr_wire;
  logic [ROB_W-1:0] rob_head_wire; 
  logic [3:0] lsq_tail_ptr_wire;
  logic [6:0] rob_spaces_free,fl_available; 
  logic [4:0] iq_spaces_free;
  logic [N-1:0] fl_pop_req_mask;
  logic [3:0] fl_pop_count_val,fl_push_count_val;
  logic [TAG_W-1:0] fl_allocated_tags[N],fl_freed_tags[N];

  logic [4:0] rat_read_rs1[N],rat_read_rs2[N],rat_read_rd[N];
  logic [TAG_W-1:0] rat_phys_rs1[N],rat_phys_rs2[N],rat_stale_rd[N];
  logic [N-1:0] rat_write_en_packed;
  logic rat_write_en_unpacked[N];
  logic [4:0] rat_write_arch[N];
  logic [TAG_W-1:0] rat_write_phys[N];
  
  logic write_chkpt_en[N];
  always_comb begin
    for(int i=0;i<N;i++) begin
      write_chkpt_en[i]=disp_valid_unpacked[i]&&(disp_is_branch[i]||disp_is_jump[i]);
    end
  end

  logic commit_valid[N],commit_is_store[N];
  logic [ROB_W-1:0] commit_rob_idx[N]; 
  logic [4:0] commit_rd_arch[N];
  logic [TAG_W-1:0] commit_rd_phys[N],commit_stale_phys[N];

  always_comb begin
    fl_pop_count_val=0;
    for(int i=0;i<N;i++) if(fl_pop_req_mask[i]) fl_pop_count_val++;
    for(int i=0;i<N;i++) begin
      rat_read_rs1[i]=dec_insts[i].rs1_arch;
      rat_read_rs2[i]=dec_insts[i].rs2_arch;
      rat_read_rd[i]=dec_insts[i].rd_arch;
      rat_write_en_unpacked[i]=rat_write_en_packed[i];
    end
  end

  logic [4:0] lsq_spaces_free_wire;
  logic lsq_disp_valid[N];
  logic lsq_disp_is_store[N];
  logic [ROB_W-1:0] lsq_disp_rob_idx[N];
  logic [3:0] lsq_tail_chkpt[0:(1<<ROB_W)-1];

  always_comb begin
    for(int i=0;i<N;i++) begin
      lsq_disp_valid[i]=disp_valid_unpacked[i]&&(disp_is_store[i]||disp_is_load[i]);
      lsq_disp_is_store[i]=disp_is_store[i];
      lsq_disp_rob_idx[i]=rob_alloc_idx[i];
    end
  end
  
  always_ff @(posedge clk) begin
    for(int i=0;i<N;i++) begin
      if(write_chkpt_en[i]) begin
        lsq_tail_chkpt[rob_alloc_idx[i]]<=lsq_alloc_idx[i];
      end
    end
  end

  dispatch_allocator alloc(
    .dec_insts(dec_insts),.free_list_available(fl_available),
    .rob_spaces_free(rob_spaces_free),.iq_spaces_free(iq_spaces_free),
    .lsq_spaces_free(lsq_spaces_free_wire), 
    .rob_tail_ptr(rob_tail_ptr_wire),.lsq_tail_ptr(lsq_tail_ptr_wire),
    .dispatch_stall(dispatch_stall),.rob_alloc_en(rob_alloc_en),
    .rob_alloc_idx(rob_alloc_idx),.iq_alloc_en(iq_alloc_en),
    .lsq_alloc_en(lsq_alloc_en),.lsq_alloc_idx(lsq_alloc_idx)
  );

  dispatch_renamer renamer(
    .dec_insts(dec_insts),.dispatch_stall(dispatch_stall),
    .fl_pop_req(fl_pop_req_mask),.fl_allocated_tags(fl_allocated_tags),
    .rat_read_rs1(rat_phys_rs1),.rat_read_rs2(rat_phys_rs2), 
    .rat_write_en(rat_write_en_packed),.rat_write_arch(rat_write_arch),.rat_write_phys(rat_write_phys),
    .dispatch_valid(disp_valid_packed),.phys_rs1(disp_rs1_phys),
    .phys_rs2(disp_rs2_phys),.phys_rd(disp_rd_phys)
  );

  logic [PRF_ENTRIES-1:0] committed_tags_mask;

  free_list_nwide #(.PRF_ENTRIES(PRF_ENTRIES),.ARCH_REGS(32),.TAG_WIDTH(TAG_W),.N(N),.ROB_W(ROB_W)) free_list(
    .clk(clk),.rst(rst),
    .pop_req_mask(fl_pop_req_mask),.pop_success(), 
    .allocated_tags(fl_allocated_tags),.free_count_out(fl_available),
    .push_count(fl_push_count_val),.freed_tags(fl_freed_tags),
    .write_chkpt_en(write_chkpt_en),.write_chkpt_rob(rob_alloc_idx),
    .early_flush(effective_early_flush),.early_flush_rob_idx(early_flush_rob_idx),
    .mispredict_flush(exception_flush), 
    .committed_tags_mask(committed_tags_mask) 
  );

  active_rat #(.ARCH_REGS(32),.TAG_WIDTH(TAG_W),.N(N),.PRF_ENTRIES(PRF_ENTRIES),.ROB_W(ROB_W)) rat(
    .clk(clk),.rst(rst),
    .read_rs1(rat_read_rs1),.read_rs2(rat_read_rs2),
    .phys_rs1(rat_phys_rs1),.phys_rs2(rat_phys_rs2),
    .read_rd(rat_read_rd),.stale_rd(rat_stale_rd),
    .write_en(rat_write_en_unpacked),.write_rd(rat_write_arch),.write_phys(rat_write_phys),
    .write_chkpt_en(write_chkpt_en),.write_chkpt_rob(rob_alloc_idx),
    .early_flush(effective_early_flush),.early_flush_rob_idx(early_flush_rob_idx),
    .commit_valid(commit_valid), 
    .commit_rd_arch(commit_rd_arch), 
    .commit_rd_phys(commit_rd_phys),
    .mispredict_flush(exception_flush), 
    .committed_tags_mask(committed_tags_mask) 
  );

  logic [PRF_ENTRIES-1:0] prf_ready_table;
  logic disp_rs1_ready[N],disp_rs2_ready[N];
  
  logic cdb_valid[N],ex_cdb_valid[N],lsq_cdb_valid;
  logic [TAG_W-1:0] cdb_tag[N],ex_cdb_tag[N],lsq_cdb_tag;
  logic [DATA_W-1:0] cdb_data[N],ex_cdb_data[N],lsq_cdb_data;
  logic [DATA_W-1:0] ex_cdb_branch_target[N];
  logic [ROB_W-1:0] cdb_rob_idx[N],ex_cdb_rob_idx[N],lsq_cdb_rob_idx;
  logic cdb_exception[N],ex_cdb_exception[N];
  logic ex_cdb_actual_taken[N];

  logic [(1<<ROB_W)-1:0] rob_valid_mask;

  function automatic logic is_younger_f(input logic [ROB_W-1:0] check_idx,branch_idx,h);
    logic [ROB_W-1:0] age_check=check_idx-h;
    logic [ROB_W-1:0] age_branch=branch_idx-h;
    return age_check>age_branch;
  endfunction

  assign early_flush=ex_cdb_exception[2]&&rob_valid_mask[ex_cdb_rob_idx[2]]; 
  assign early_flush_target=ex_cdb_branch_target[2];
  assign early_flush_rob_idx=ex_cdb_rob_idx[2];

  always_comb begin
    for(int i=0;i<N;i++) begin
      logic is_valid=rob_valid_mask[ex_cdb_rob_idx[i]];
      logic kill_i=effective_early_flush&&is_younger_f(ex_cdb_rob_idx[i],early_flush_rob_idx,rob_head_wire);
      cdb_valid[i]=ex_cdb_valid[i]&&is_valid&&!kill_i;
      cdb_tag[i]=ex_cdb_tag[i];
      cdb_data[i]=ex_cdb_data[i];
      cdb_rob_idx[i]=ex_cdb_rob_idx[i];
      cdb_exception[i]=(i==2)?1'b0:(ex_cdb_exception[i]&&is_valid&&!kill_i); 
    end
    if(lsq_cdb_valid) begin
      logic is_valid_lsq=rob_valid_mask[lsq_cdb_rob_idx];
      logic kill_lsq=effective_early_flush&&is_younger_f(lsq_cdb_rob_idx,early_flush_rob_idx,rob_head_wire);
      cdb_valid[3]=1'b1&&is_valid_lsq&&!kill_lsq;
      cdb_tag[3]=lsq_cdb_tag;
      cdb_data[3]=lsq_cdb_data;
      cdb_rob_idx[3]=lsq_cdb_rob_idx;
      cdb_exception[3]=1'b0;
    end
  end

  always_ff @(posedge clk) begin
    if(rst||exception_flush) begin
      prf_ready_table<={PRF_ENTRIES{1'b1}};
    end else begin
      for(int i=0;i<N;i++) begin
        if(disp_valid_unpacked[i]&&dec_insts[i].uses_rd) 
          prf_ready_table[disp_rd_phys[i]]<=1'b0;
        if(cdb_valid[i]) 
          prf_ready_table[cdb_tag[i]]<=1'b1;
      end
      prf_ready_table[0]<=1'b1; 
    end
  end

  always_comb begin
    for(int i=0;i<N;i++) begin
      disp_rs1_ready[i]=prf_ready_table[disp_rs1_phys[i]];
      disp_rs2_ready[i]=prf_ready_table[disp_rs2_phys[i]];
      for(int j=0;j<i;j++) begin
        if(disp_valid_unpacked[j]&&dec_insts[j].uses_rd) begin
          if(disp_rs1_phys[i]==disp_rd_phys[j]) disp_rs1_ready[i]=1'b0;
          if(disp_rs2_phys[i]==disp_rd_phys[j]) disp_rs2_ready[i]=1'b0;
        end
      end
    end
  end

  typedef struct packed {
    logic [DATA_W-1:0] pc;
    logic [DATA_W-1:0] imm;
    logic [3:0] alu_ctrl;
    logic [2:0] branch_type;
    logic [4:0] lsq_idx;
    logic [1:0] mem_size;     
    logic mem_unsigned; 
    logic is_store;
    logic is_alu_imm; 
    logic is_auipc; 
    logic is_lui;
    logic is_jalr; 
    logic is_jump;
    logic is_branch;        
    logic is_call;      
    logic is_ret;        
    logic pred_taken;
    logic [DATA_W-1:0] pred_target;
    logic [7:0] pred_bhr;         
    logic [3:0] tos_snapshot; 
  } inst_info_t;

  inst_info_t inst_info_ram[0:(1<<ROB_W)-1];
  inst_info_t issue_info[N];

  logic [TAG_W-1:0] issue_rs1_phys[N],issue_rs2_phys[N],issue_rd_phys[N];
  logic [ROB_W-1:0] issue_rob_idx[N];
  logic issue_valid[N];
  logic issue_valid_k[N]; 
  
  always_comb begin
    for(int i=0;i<N;i++) begin
      issue_valid_k[i]=issue_valid[i]&&
        !(effective_early_flush&&is_younger_f(issue_rob_idx[i],early_flush_rob_idx,rob_head_wire));
    end
  end

  always_ff @(posedge clk) begin
    if(!exception_flush) begin
      for(int i=0;i<N;i++) begin
        if(disp_valid_unpacked[i]) begin
          inst_info_ram[rob_alloc_idx[i]].pc<=disp_pc[i]; 
          inst_info_ram[rob_alloc_idx[i]].imm<=disp_imm[i];
          inst_info_ram[rob_alloc_idx[i]].alu_ctrl<=disp_alu_ctrl[i];
          inst_info_ram[rob_alloc_idx[i]].branch_type<=disp_branch_type[i];
          inst_info_ram[rob_alloc_idx[i]].lsq_idx<=lsq_alloc_idx[i];
          inst_info_ram[rob_alloc_idx[i]].mem_size<=dec_insts[i].mem_size;         
          inst_info_ram[rob_alloc_idx[i]].mem_unsigned<=dec_insts[i].mem_unsigned; 
          inst_info_ram[rob_alloc_idx[i]].is_store<=disp_is_store[i];
          inst_info_ram[rob_alloc_idx[i]].is_alu_imm<=disp_is_alu_imm[i]; 
          inst_info_ram[rob_alloc_idx[i]].is_auipc<=disp_is_auipc[i];
          inst_info_ram[rob_alloc_idx[i]].is_lui<=is_lui[i];             
          inst_info_ram[rob_alloc_idx[i]].is_jalr<=disp_is_jalr[i];
          inst_info_ram[rob_alloc_idx[i]].is_jump<=disp_is_jump[i];
          inst_info_ram[rob_alloc_idx[i]].is_branch<=disp_is_branch[i];             
          inst_info_ram[rob_alloc_idx[i]].is_call<=disp_is_call[i];        
          inst_info_ram[rob_alloc_idx[i]].is_ret<=disp_is_ret[i];          
          inst_info_ram[rob_alloc_idx[i]].pred_taken<=f2d_pred_taken[i];     
          inst_info_ram[rob_alloc_idx[i]].pred_target<=f2d_pred_target[i];   
          inst_info_ram[rob_alloc_idx[i]].pred_bhr<=f2d_pred_bhr[i];     
          inst_info_ram[rob_alloc_idx[i]].tos_snapshot<=f2d_tos[i];        
        end
      end
    end
  end

  always_comb begin
    for(int i=0;i<N;i++) issue_info[i]=inst_info_ram[issue_rob_idx[i]];
  end

  logic [DATA_W-1:0] prf_rs1_data[N],prf_rs2_data[N];
  logic lsq_ready_wire;

  issue_queue iq(
    .clk(clk),.rst(rst),.exception_flush(exception_flush),
    .early_flush(effective_early_flush),.early_flush_rob_idx(early_flush_rob_idx),
    .lsq_ready(lsq_ready_wire),
    .rob_head(rob_head_wire),
    .disp_valid(disp_valid_unpacked),.disp_rs1_phys(disp_rs1_phys),.disp_rs1_ready(disp_rs1_ready),
    .disp_rs2_phys(disp_rs2_phys),.disp_rs2_ready(disp_rs2_ready),
    .disp_rd_phys(disp_rd_phys),.disp_rob_idx(rob_alloc_idx),
    .disp_fu_type(disp_fu_type),
    .iq_spaces_free(iq_spaces_free),.cdb_valid(cdb_valid),.cdb_tag(cdb_tag),
    .issue_valid(issue_valid),.issue_rs1_phys(issue_rs1_phys), 
    .issue_rs2_phys(issue_rs2_phys),.issue_rd_phys(issue_rd_phys), 
    .issue_rob_idx(issue_rob_idx)
  );

  prf_wrapper prf(
    .clk(clk), 
    .read_addr_rs1(issue_rs1_phys),.read_addr_rs2(issue_rs2_phys),
    .read_data_rs1(prf_rs1_data),.read_data_rs2(prf_rs2_data),
    .write_en(cdb_valid),.write_addr(cdb_tag),.write_data(cdb_data)
  );

  logic [DATA_W-1:0] ex_pc[N],ex_imm[N],ex_rs1_actual[N],ex_rs2_actual[N];
  logic [3:0] ex_alu_ctrl[N];
  logic [2:0] ex_branch_type[N];
  logic ex_is_jump[N],ex_is_jalr[N];
  logic ex_pred_taken[N],ex_is_call[N],ex_is_ret[N];
  logic [DATA_W-1:0] ex_pred_target[N];
  logic [7:0] ex_pred_bhr[N];
  logic [3:0] ex_tos_snapshot[N];
  
  always_comb begin
    for(int i=0;i<N;i++) begin
      ex_pc[i]=issue_info[i].pc;
      ex_imm[i]=issue_info[i].imm;
      ex_alu_ctrl[i]=issue_info[i].alu_ctrl;
      ex_branch_type[i]=issue_info[i].branch_type;
      ex_is_jump[i]=issue_info[i].is_jump;
      ex_is_jalr[i]=issue_info[i].is_jalr;
      ex_is_call[i]=issue_info[i].is_call;
      ex_is_ret[i]=issue_info[i].is_ret;
      ex_pred_taken[i]=issue_info[i].pred_taken;
      ex_pred_target[i]=issue_info[i].pred_target;
      ex_pred_bhr[i]=issue_info[i].pred_bhr;
      ex_tos_snapshot[i]=issue_info[i].tos_snapshot;
      
      if(issue_info[i].is_auipc) ex_rs1_actual[i]=issue_info[i].pc;
      else if(issue_info[i].is_lui) ex_rs1_actual[i]=32'd0;
      else ex_rs1_actual[i]=prf_rs1_data[i];
      
      if(issue_info[i].is_alu_imm) ex_rs2_actual[i]=issue_info[i].imm;
      else ex_rs2_actual[i]=prf_rs2_data[i];
    end
  end

  execution_engine ex_engine(
    .clk(clk),.rst(rst),.exception_flush(exception_flush),
    .issue_valid(issue_valid_k),.rs1_data(ex_rs1_actual),.rs2_data(ex_rs2_actual), 
    .pc(ex_pc),.imm(ex_imm),.alu_ctrl(ex_alu_ctrl),.branch_type(ex_branch_type),
    .is_jump(ex_is_jump),.is_jalr(ex_is_jalr),.is_call(ex_is_call),.is_ret(ex_is_ret), 
    .pred_taken(ex_pred_taken),.pred_target(ex_pred_target),
    .pred_bhr(ex_pred_bhr),.tos_snapshot(ex_tos_snapshot),
    .rd_tag(issue_rd_phys),.rob_idx(issue_rob_idx),
    .fu_ready(),.cdb_valid(ex_cdb_valid),.cdb_tag(ex_cdb_tag),
    .cdb_data(ex_cdb_data),.cdb_branch_target(ex_cdb_branch_target), 
    .cdb_rob_idx(ex_cdb_rob_idx),.cdb_exception(ex_cdb_exception),
    .cdb_actual_taken(ex_cdb_actual_taken),
    .cdb_recovery_bhr(early_flush_bhr),.cdb_recovery_tos(early_flush_tos)
  );

  logic bp_pred_taken[N];
  logic [31:0] bp_pred_target[N];
  logic [31:0] bp_read_pc[N];
  logic [7:0] bp_current_bhr;
  logic [7:0] bp_read_bhr; 

  always_comb begin
    for(int i=0;i<N;i++) bp_read_pc[i]={fetch_pc[31:4],4'b0000}+(i*4);
  end

  logic bp_train_valid;
  logic [31:0] bp_train_pc,bp_train_target;
  logic bp_train_taken,bp_train_mispredicted;
  logic [7:0] bp_train_bhr;
  logic bp_train_actual_taken;

  always_comb begin
    logic kill_bp=effective_early_flush&&is_younger_f(ex_cdb_rob_idx[2],early_flush_rob_idx,rob_head_wire);
    
    bp_train_valid=ex_cdb_valid[2]&&rob_valid_mask[ex_cdb_rob_idx[2]]&&!kill_bp; 
    bp_train_target=ex_cdb_branch_target[2];
    bp_train_mispredicted=ex_cdb_exception[2]&&rob_valid_mask[ex_cdb_rob_idx[2]]&&!kill_bp; 
    bp_train_actual_taken=ex_cdb_actual_taken[2];
    
    if(bp_train_valid) begin
      bp_train_pc=inst_info_ram[ex_cdb_rob_idx[2]].pc;
      bp_train_taken=bp_train_actual_taken;
      bp_train_bhr=inst_info_ram[ex_cdb_rob_idx[2]].pred_bhr;
    end else begin
      bp_train_pc='0;
      bp_train_taken=1'b0;
      bp_train_bhr='0;
    end
  end

  gshare_predictor #(.BHT_W(8),.BTB_W(6),.N(N)) b_pred(
    .clk(clk),.rst(rst),
    .read_pc(bp_read_pc),.read_bhr(bp_read_bhr),.pred_taken(bp_pred_taken),.pred_target(bp_pred_target),
    .current_bhr(bp_current_bhr),
    .train_valid(bp_train_valid),.train_pc(bp_train_pc),.train_taken(bp_train_taken), 
    .train_target(bp_train_target),.train_mispredicted(bp_train_mispredicted),.train_bhr(bp_train_bhr),
    .train_actual_taken(bp_train_actual_taken) 
  );

  always_comb begin
    fl_push_count_val=0;
    for(int i=0;i<N;i++) fl_freed_tags[i]='0;
    for(int i=0;i<N;i++) begin
      if(commit_valid[i]&&(commit_stale_phys[i]!=0)) begin
        fl_freed_tags[fl_push_count_val]=commit_stale_phys[i];
        fl_push_count_val++;
      end
    end
  end

  reorder_buffer rob(
    .clk(clk),.rst(rst),
    .dispatch_valid(disp_valid_unpacked),.dispatch_rd_arch(disp_rd_arch), 
    .dispatch_rd_phys(disp_rd_phys),.dispatch_stale_phys(rat_stale_rd), 
    .dispatch_is_store(disp_is_store),.dispatch_is_mem(disp_is_mem), 
    .rob_tail_ptr(rob_tail_ptr_wire),.rob_spaces_free(rob_spaces_free),
    .rob_head_ptr(rob_head_wire),.rob_valid_mask(rob_valid_mask),
    .cdb_valid(cdb_valid),.cdb_rob_idx(cdb_rob_idx), 
    .cdb_branch_target(ex_cdb_branch_target),.cdb_exception(cdb_exception),
    .early_flush(effective_early_flush),.early_flush_rob_idx(early_flush_rob_idx),
    .commit_valid(commit_valid),.commit_rob_idx(commit_rob_idx),
    .commit_rd_arch(commit_rd_arch),.commit_rd_phys(commit_rd_phys), 
    .commit_stale_phys(commit_stale_phys),.commit_is_store(commit_is_store), 
    .exception_flush(exception_flush),.commit_recovery_pc(commit_recovery_pc)
  );

  logic dcache_req_valid,dcache_resp_valid;
  logic [DATA_W-1:0] dcache_req_addr,dcache_resp_data;
  logic dcache_st_valid;
  logic [3:0] dcache_st_we;
  logic [DATA_W-1:0] dcache_st_addr,dcache_st_data;

  lsq lsq_inst(
    .clk(clk),.rst(rst),.exception_flush(exception_flush),
    .early_flush(effective_early_flush),.early_flush_rob_idx(early_flush_rob_idx),
    .early_flush_lsq_tail(lsq_tail_chkpt[early_flush_rob_idx]),.rob_head(rob_head_wire),
    .disp_valid(lsq_disp_valid),.disp_is_store(lsq_disp_is_store),.disp_rob_idx(lsq_disp_rob_idx),
    .lsq_spaces_free(lsq_spaces_free_wire),.lsq_alloc_idx(lsq_tail_ptr_wire),
    .issue_valid(issue_valid_k[3]),.issue_is_store(issue_info[3].is_store), 
    .issue_lsq_idx(issue_info[3].lsq_idx[3:0]),
    .issue_mem_size(issue_info[3].mem_size),             
    .issue_mem_unsigned(issue_info[3].mem_unsigned),     
    .rs1_base(prf_rs1_data[3]),.rs2_data(prf_rs2_data[3]),.imm(ex_imm[3]),
    .rd_tag(issue_rd_phys[3]),.rob_idx(issue_rob_idx[3]),
    .cdb_valid(lsq_cdb_valid),.cdb_tag(lsq_cdb_tag),.cdb_data(lsq_cdb_data),.cdb_rob_idx(lsq_cdb_rob_idx), 
    .commit_valid(commit_valid),.commit_rob_idx(commit_rob_idx), 
    .commit_is_store(commit_is_store), 
    .dcache_req_valid(dcache_req_valid),.dcache_req_addr(dcache_req_addr), 
    .dcache_resp_valid(dcache_resp_valid),.dcache_resp_data(dcache_resp_data),
    .dcache_st_valid(dcache_st_valid),.dcache_st_we(dcache_st_we),.dcache_st_addr(dcache_st_addr),.dcache_st_data(dcache_st_data),
    .mshr_ready_out(lsq_ready_wire) 
  );

  iram #(.N(N),.DATA_W(DATA_W)) inst_mem(.clk(clk),.fetch_pc(fetch_pc),.inst_out(fetched_insts_unpacked));
  
  dcache #(.DATA_W(DATA_W)) data_mem(
    .clk(clk),.rst(rst),
    .req_valid(dcache_req_valid),.req_addr(dcache_req_addr), 
    .resp_valid(dcache_resp_valid),.resp_data(dcache_resp_data),
    .st_valid(dcache_st_valid),.st_we(dcache_st_we),.st_addr(dcache_st_addr),.st_data(dcache_st_data) 
  );
  
  nwide_fetch_unit #(.PC_WIDTH(DATA_W),.FETCH_WIDTH(N),.BHT_W(8)) fetch(
    .clk(clk),.rst(rst),.dispatch_stall(dispatch_stall),.mispredict_flush(exception_flush),
    .early_flush(effective_early_flush),.early_flush_pc(early_flush_target),
    .recovery_pc(commit_recovery_pc),.icache_addr(fetch_pc),.icache_data(fetched_insts_packed),.icache_valid(1'b1), 
    .pred_taken_in(bp_pred_taken),.pred_target_in(bp_pred_target),.current_bhr_in(bp_current_bhr),
    .recovered_bhr_in(early_flush_bhr), 
    .recovered_tos_in(early_flush_tos), 
    .fq_push(),.fq_data(f2d_insts),.fq_pc(f2d_pc),.fq_valid_mask(f2d_valid_mask),
    .fq_pred_taken(f2d_pred_taken),.fq_pred_target(f2d_pred_target),.fq_pred_bhr(f2d_pred_bhr),
    .fq_tos(f2d_tos), 
    .spec_bhr_out(bp_read_bhr) 
  );

  parallel_decoder #(.FETCH_WIDTH(N)) decoder(
    .fq_data(f2d_insts),.fq_valid_mask(f2d_valid_mask),.decoded_insts(dec_insts_raw)
  );
endmodule