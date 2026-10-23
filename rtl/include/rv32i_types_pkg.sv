package rv32i_types_pkg;
  localparam ALU_ADD=4'd0;
  localparam ALU_SUB=4'd1;
  localparam ALU_SLL=4'd2;
  localparam ALU_SLT=4'd3;
  localparam ALU_SLTU=4'd4;
  localparam ALU_XOR=4'd5;
  localparam ALU_SRL=4'd6;
  localparam ALU_SRA=4'd7;
  localparam ALU_OR=4'd8;
  localparam ALU_AND=4'd9;

  localparam BR_BEQ=3'd0;
  localparam BR_BNE=3'd1;
  localparam BR_BLT=3'd2;
  localparam BR_BGE=3'd3;
  localparam BR_BLTU=3'd4;
  localparam BR_BGEU=3'd5;

  localparam MEM_B=2'd0;
  localparam MEM_H=2'd1;
  localparam MEM_W=2'd2;

  typedef struct packed {
    logic valid;
    logic [4:0] rs1_arch;
    logic [4:0] rs2_arch;
    logic [4:0] rd_arch;
    logic uses_rs1;
    logic uses_rs2;
    logic uses_rd;
    logic [31:0] imm;
    logic [3:0] alu_op;
    logic [2:0] br_op;
    logic [1:0] mem_size;
    logic mem_unsigned;
    logic is_branch;
    logic is_jump;
    logic is_load;
    logic is_store;
    logic is_alu_imm;
    logic is_alu_reg;
  } decoded_inst_t;
endpackage