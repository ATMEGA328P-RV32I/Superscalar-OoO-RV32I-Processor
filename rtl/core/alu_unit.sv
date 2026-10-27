//Copyright 2026 Atul Kumar
module alu_unit #(
  parameter DATA_W=32,
  parameter TAG_W=7,
  parameter ROB_W=6
)(
  input logic clk,
  input logic rst,
  input logic exception_flush,
  
  input logic issue_valid,
  input logic [DATA_W-1:0] rs1_data,
  input logic [DATA_W-1:0] rs2_data,
  input logic [3:0] alu_ctrl,
  input logic [TAG_W-1:0] rd_tag,
  input logic [ROB_W-1:0] rob_idx,
  
  output logic fu_ready,
  
  output logic cdb_valid,
  output logic [TAG_W-1:0] cdb_tag,
  output logic [DATA_W-1:0] cdb_data,
  output logic [ROB_W-1:0] cdb_rob_idx,
  output logic cdb_exception
);

  assign fu_ready=1'b1; 

  logic [DATA_W-1:0] alu_result;
  
  always_comb begin
    alu_result='0;
    case(alu_ctrl)
      4'd0: alu_result=rs1_data+rs2_data;                             
      4'd1: alu_result=rs1_data-rs2_data;                             
      4'd2: alu_result=rs1_data<<rs2_data[4:0];                        
      4'd3: alu_result={31'b0,($signed(rs1_data)<$signed(rs2_data))};
      4'd4: alu_result={31'b0,(rs1_data<rs2_data)};                  
      4'd5: alu_result=rs1_data^rs2_data;                             
      4'd6: alu_result=rs1_data>>rs2_data[4:0];                        
      4'd7: alu_result=$signed(rs1_data)>>>rs2_data[4:0];              
      4'd8: alu_result=rs1_data|rs2_data;                             
      4'd9: alu_result=rs1_data&rs2_data;                             
      default: alu_result='0;
    endcase
  end

  always_ff @(posedge clk) begin
    if(rst||exception_flush) begin
      cdb_valid<=1'b0;
      cdb_tag<='0;
      cdb_data<='0;
      cdb_rob_idx<='0;
      cdb_exception<=1'b0; 
    end else begin
      cdb_valid<=issue_valid;
      cdb_tag<=rd_tag;
      cdb_data<=alu_result;
      cdb_rob_idx<=rob_idx;
      cdb_exception<=1'b0;
    end
  end
endmodule
