//Copyright 2026 Atul Kumar
module active_rat #(
  parameter ARCH_REGS=32,
  parameter TAG_WIDTH=7,
  parameter N=4,
  parameter PRF_ENTRIES=96,
  parameter ROB_W=6
)(
  input logic clk,
  input logic rst,
  
  input logic [4:0] read_rs1[N],
  input logic [4:0] read_rs2[N],
  output logic [TAG_WIDTH-1:0] phys_rs1[N],
  output logic [TAG_WIDTH-1:0] phys_rs2[N],
  
  input logic [4:0] read_rd[N],
  output logic [TAG_WIDTH-1:0] stale_rd[N],
  
  input logic write_en[N],
  input logic [4:0] write_rd[N],
  input logic [TAG_WIDTH-1:0] write_phys[N],
  
  input logic write_chkpt_en[N],
  input logic [ROB_W-1:0] write_chkpt_rob[N],
  input logic early_flush,
  input logic [ROB_W-1:0] early_flush_rob_idx,
  
  input logic commit_valid[N],
  input logic [4:0] commit_rd_arch[N],
  input logic [TAG_WIDTH-1:0] commit_rd_phys[N],
  
  input logic mispredict_flush,
  output logic [PRF_ENTRIES-1:0] committed_tags_mask
);

  logic [TAG_WIDTH-1:0] spec_rat[0:ARCH_REGS-1];
  logic [TAG_WIDTH-1:0] arch_rat[0:ARCH_REGS-1];
  logic [TAG_WIDTH-1:0] next_arch_rat[0:ARCH_REGS-1];
  
  logic [TAG_WIDTH-1:0] chkpt_rat[0:(1<<ROB_W)-1][0:ARCH_REGS-1];
  
  logic [TAG_WIDTH-1:0] rat_cascade[N+1][0:ARCH_REGS-1];
  
  always_comb begin
    next_arch_rat=arch_rat;
    for(int i=0;i<N;i++) begin
      if(commit_valid[i]&&(commit_rd_arch[i]!=5'd0)) begin
        next_arch_rat[commit_rd_arch[i]]=commit_rd_phys[i];
      end
    end
    
    committed_tags_mask='0;
    committed_tags_mask[0]=1'b1; 
    for(int i=0;i<ARCH_REGS;i++) begin
      committed_tags_mask[next_arch_rat[i]]=1'b1;
    end
  end
  
  always_comb begin
    rat_cascade[0]=spec_rat;
    for(int i=0;i<N;i++) begin
      rat_cascade[i+1]=rat_cascade[i];
      if(write_en[i]&&write_rd[i]!=5'd0) begin
        rat_cascade[i+1][write_rd[i]]=write_phys[i];
      end
    end
  end
  
  always_comb begin
    for(int i=0;i<N;i++) begin
      phys_rs1[i]=(read_rs1[i]==5'd0)?'0:rat_cascade[i][read_rs1[i]];
      phys_rs2[i]=(read_rs2[i]==5'd0)?'0:rat_cascade[i][read_rs2[i]];
      stale_rd[i]=(read_rd[i]==5'd0)?'0:rat_cascade[i][read_rd[i]];
    end
  end
  
  always_ff @(posedge clk) begin
    if(rst) begin
      for(int i=0;i<ARCH_REGS;i++) begin
        spec_rat[i]<=i[TAG_WIDTH-1:0];
        arch_rat[i]<=i[TAG_WIDTH-1:0];
      end
    end else begin
      arch_rat<=next_arch_rat;
      
      if(mispredict_flush) begin
        spec_rat<=next_arch_rat;
      end else if(early_flush) begin
        spec_rat<=chkpt_rat[early_flush_rob_idx];
      end else begin
        spec_rat<=rat_cascade[N];
      end
      
      for(int i=0;i<N;i++) begin
        if(write_chkpt_en[i]) begin
          for(int r=0;r<ARCH_REGS;r++) begin
            chkpt_rat[write_chkpt_rob[i]][r]<=rat_cascade[i+1][r];
          end
        end
      end
    end
  end
endmodule
