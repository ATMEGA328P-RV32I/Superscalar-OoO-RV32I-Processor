//Copyright 2026 Atul Kumar
module execution_engine #(
  parameter DATA_W=32,
  parameter TAG_W=7,
  parameter ROB_W=6,
  parameter N=4
)(
  input logic clk,rst,exception_flush,
  input logic issue_valid[N],
  input logic [DATA_W-1:0] rs1_data[N],rs2_data[N],pc[N],imm[N],
  input logic [3:0] alu_ctrl[N],
  input logic [2:0] branch_type[N],
  input logic is_jump[N],is_jalr[N],is_call[N],is_ret[N],
  input logic pred_taken[N],
  input logic [DATA_W-1:0] pred_target[N],
  input logic [7:0] pred_bhr[N],
  input logic [3:0] tos_snapshot[N],
  input logic [TAG_W-1:0] rd_tag[N],
  input logic [ROB_W-1:0] rob_idx[N],
  
  output logic fu_ready[N],
  output logic cdb_valid[N],
  output logic [TAG_W-1:0] cdb_tag[N],
  output logic [DATA_W-1:0] cdb_data[N],
  output logic [DATA_W-1:0] cdb_branch_target[N],
  output logic [ROB_W-1:0] cdb_rob_idx[N],
  output logic cdb_exception[N],
  output logic cdb_actual_taken[N],

  output logic [7:0] cdb_recovery_bhr, 
  output logic [3:0] cdb_recovery_tos
);

  alu_unit #(.DATA_W(DATA_W),.TAG_W(TAG_W),.ROB_W(ROB_W)) alu0(
    .clk(clk),.rst(rst),.exception_flush(exception_flush),
    .issue_valid(issue_valid[0]),.rs1_data(rs1_data[0]),.rs2_data(rs2_data[0]),
    .alu_ctrl(alu_ctrl[0]),.rd_tag(rd_tag[0]),.rob_idx(rob_idx[0]),
    .fu_ready(fu_ready[0]),.cdb_valid(cdb_valid[0]),.cdb_tag(cdb_tag[0]), 
    .cdb_data(cdb_data[0]),.cdb_rob_idx(cdb_rob_idx[0]),.cdb_exception(cdb_exception[0])
  );
  assign cdb_branch_target[0]='0;
  assign cdb_actual_taken[0]=1'b0;

  alu_unit #(.DATA_W(DATA_W),.TAG_W(TAG_W),.ROB_W(ROB_W)) alu1(
    .clk(clk),.rst(rst),.exception_flush(exception_flush),
    .issue_valid(issue_valid[1]),.rs1_data(rs1_data[1]),.rs2_data(rs2_data[1]),
    .alu_ctrl(alu_ctrl[1]),.rd_tag(rd_tag[1]),.rob_idx(rob_idx[1]),
    .fu_ready(fu_ready[1]),.cdb_valid(cdb_valid[1]),.cdb_tag(cdb_tag[1]), 
    .cdb_data(cdb_data[1]),.cdb_rob_idx(cdb_rob_idx[1]),.cdb_exception(cdb_exception[1])
  );
  assign cdb_branch_target[1]='0;
  assign cdb_actual_taken[1]=1'b0;

  branch_unit #(.DATA_W(DATA_W),.TAG_W(TAG_W),.ROB_W(ROB_W)) branch0(
    .clk(clk),.rst(rst),.exception_flush(exception_flush),
    .issue_valid(issue_valid[2]),.rs1_data(rs1_data[2]),.rs2_data(rs2_data[2]),
    .pc(pc[2]),.imm(imm[2]),.branch_type(branch_type[2]), 
    .is_jump(is_jump[2]),.is_jalr(is_jalr[2]), 
    .is_call(is_call[2]),.is_ret(is_ret[2]), 
    .pred_taken(pred_taken[2]),.pred_target(pred_target[2]), 
    .pred_bhr(pred_bhr[2]),.tos_snapshot(tos_snapshot[2]),
    .rd_tag(rd_tag[2]),.rob_idx(rob_idx[2]),
    .fu_ready(fu_ready[2]),.cdb_valid(cdb_valid[2]),.cdb_tag(cdb_tag[2]), 
    .cdb_data(cdb_data[2]),.cdb_branch_target(cdb_branch_target[2]), 
    .cdb_rob_idx(cdb_rob_idx[2]),.cdb_exception(cdb_exception[2]),
    .cdb_actual_taken(cdb_actual_taken[2]),
    .recovery_bhr(cdb_recovery_bhr),.recovery_tos(cdb_recovery_tos)
  );

  assign fu_ready[3]=1'b1;
  assign cdb_valid[3]=1'b0;
  assign cdb_tag[3]='0;
  assign cdb_data[3]='0;
  assign cdb_branch_target[3]='0;
  assign cdb_rob_idx[3]='0;
  assign cdb_exception[3]=1'b0;
  assign cdb_actual_taken[3]=1'b0;
endmodule
