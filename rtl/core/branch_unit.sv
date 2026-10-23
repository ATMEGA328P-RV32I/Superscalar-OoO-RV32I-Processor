module branch_unit #(
  parameter DATA_W=32,TAG_W=7,ROB_W=6
)(
  input logic clk,rst,exception_flush,
  input logic issue_valid,
  input logic [DATA_W-1:0] rs1_data,rs2_data,pc,imm,
  input logic [2:0] branch_type,
  input logic is_jump,is_jalr,is_call,is_ret,
  input logic pred_taken,
  input logic [DATA_W-1:0] pred_target,
  input logic [7:0] pred_bhr,
  input logic [3:0] tos_snapshot,
  input logic [TAG_W-1:0] rd_tag,
  input logic [ROB_W-1:0] rob_idx,
  
  output logic fu_ready,cdb_valid,
  output logic [TAG_W-1:0] cdb_tag,
  output logic [DATA_W-1:0] cdb_data,cdb_branch_target,
  output logic [ROB_W-1:0] cdb_rob_idx,
  output logic cdb_exception, 
  output logic cdb_actual_taken,
  
  output logic [7:0] recovery_bhr,
  output logic [3:0] recovery_tos
);

  assign fu_ready=1'b1; 
  logic branch_taken_cond,actual_taken,target_mismatch;
  logic [DATA_W-1:0] target_pc;
  
  always_comb begin
    branch_taken_cond=1'b0;
    case(branch_type)
      3'b000: branch_taken_cond=(rs1_data==rs2_data);
      3'b001: branch_taken_cond=(rs1_data!=rs2_data);
      3'b100: branch_taken_cond=($signed(rs1_data)<$signed(rs2_data));
      3'b101: branch_taken_cond=($signed(rs1_data)>=$signed(rs2_data));
      3'b110: branch_taken_cond=(rs1_data<rs2_data);
      3'b111: branch_taken_cond=(rs1_data>=rs2_data);
      default: branch_taken_cond=1'b0;
    endcase
    
    actual_taken=is_jump|branch_taken_cond;
    target_pc=is_jalr?((rs1_data+imm)&~32'b1):(pc+imm); 
    target_mismatch=actual_taken&&(target_pc!=pred_target);
    
    recovery_bhr={pred_bhr[6:0],actual_taken};
    if(is_call) recovery_tos=tos_snapshot+1;
    else if(is_ret) recovery_tos=tos_snapshot-1;
    else recovery_tos=tos_snapshot;
  end

  always_ff @(posedge clk) begin
    if(rst||exception_flush) begin
      cdb_valid<=1'b0; cdb_tag<='0; cdb_data<='0;
      cdb_branch_target<='0; cdb_rob_idx<='0; cdb_exception<=1'b0;
      cdb_actual_taken<=1'b0;
    end else begin
      cdb_valid<=issue_valid;
      cdb_tag<=rd_tag;
      cdb_data<=pc+4;        
      
      cdb_branch_target<=actual_taken?target_pc:pc+4; 
      cdb_actual_taken<=actual_taken;
      cdb_rob_idx<=rob_idx;
      
      cdb_exception<=issue_valid&((actual_taken!==pred_taken)||target_mismatch); 
    end
  end
endmodule