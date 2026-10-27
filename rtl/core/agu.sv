//Copyright 2026 Atul Kumar
module agu #(
  parameter DATA_W=32
)(
  input logic [DATA_W-1:0] rs1_base,
  input logic [DATA_W-1:0] imm_offset,
  output logic [DATA_W-1:0] calc_addr
);

  always_comb begin
    calc_addr=rs1_base+imm_offset;
  end

endmodule
