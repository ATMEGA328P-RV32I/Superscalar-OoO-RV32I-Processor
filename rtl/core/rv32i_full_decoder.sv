import rv32i_types_pkg::*;

module rv32i_full_decoder (
  input logic [31:0] raw_inst,
  input logic inst_valid,
  output decoded_inst_t dec
);
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  always_comb begin
    dec='0;
    dec.valid=inst_valid;
    
    opcode=raw_inst[6:0];
    funct3=raw_inst[14:12];
    funct7=raw_inst[31:25];
    
    dec.rd_arch=raw_inst[11:7];
    dec.rs1_arch=raw_inst[19:15];
    dec.rs2_arch=raw_inst[24:20];

    case(opcode)
      7'b0110111: begin 
        dec.imm={raw_inst[31:12],12'b0};
        dec.uses_rd=1'b1; dec.is_alu_imm=1'b1;
        dec.alu_op=ALU_ADD; dec.uses_rs1=1'b0;
      end
      7'b0010111: begin 
        dec.imm={raw_inst[31:12],12'b0};
        dec.uses_rd=1'b1; dec.is_alu_imm=1'b1; dec.alu_op=ALU_ADD; 
      end
      7'b1101111: begin 
        dec.imm={{12{raw_inst[31]}},raw_inst[19:12],raw_inst[20],raw_inst[30:21],1'b0};
        dec.uses_rd=1'b1; dec.is_jump=1'b1;
      end
      7'b1100111: begin 
        dec.imm={{20{raw_inst[31]}},raw_inst[31:20]};
        dec.uses_rs1=1'b1; dec.uses_rd=1'b1; dec.is_jump=1'b1;
      end
      7'b1100011: begin 
        dec.imm={{20{raw_inst[31]}},raw_inst[7],raw_inst[30:25],raw_inst[11:8],1'b0};
        dec.uses_rs1=1'b1; dec.uses_rs2=1'b1; dec.is_branch=1'b1;
        dec.rd_arch=5'd0; 
        case(funct3)
          3'b000: dec.br_op=BR_BEQ;
          3'b001: dec.br_op=BR_BNE;
          3'b100: dec.br_op=BR_BLT;
          3'b101: dec.br_op=BR_BGE;
          3'b110: dec.br_op=BR_BLTU;
          3'b111: dec.br_op=BR_BGEU;
          default: dec.valid=1'b0;
        endcase
      end
      7'b0000011: begin 
        dec.imm={{20{raw_inst[31]}},raw_inst[31:20]};
        dec.uses_rs1=1'b1; dec.uses_rd=1'b1; dec.is_load=1'b1;
        case(funct3)
          3'b000: begin dec.mem_size=MEM_B; dec.mem_unsigned=1'b0; end
          3'b001: begin dec.mem_size=MEM_H; dec.mem_unsigned=1'b0; end
          3'b010: begin dec.mem_size=MEM_W; dec.mem_unsigned=1'b0; end
          3'b100: begin dec.mem_size=MEM_B; dec.mem_unsigned=1'b1; end
          3'b101: begin dec.mem_size=MEM_H; dec.mem_unsigned=1'b1; end
          default: dec.valid=1'b0;
        endcase
      end
      7'b0100011: begin 
        dec.imm={{20{raw_inst[31]}},raw_inst[31:25],raw_inst[11:7]};
        dec.uses_rs1=1'b1; dec.uses_rs2=1'b1; dec.is_store=1'b1;
        dec.rd_arch=5'd0; 
        case(funct3)
          3'b000: dec.mem_size=MEM_B;
          3'b001: dec.mem_size=MEM_H;
          3'b010: dec.mem_size=MEM_W;
          default: dec.valid=1'b0;
        endcase
      end
      7'b0010011: begin 
        dec.imm={{20{raw_inst[31]}},raw_inst[31:20]};
        dec.uses_rs1=1'b1; dec.uses_rd=1'b1; dec.is_alu_imm=1'b1;
        case(funct3)
          3'b000: dec.alu_op=ALU_ADD;
          3'b010: dec.alu_op=ALU_SLT;
          3'b011: dec.alu_op=ALU_SLTU;
          3'b100: dec.alu_op=ALU_XOR;
          3'b110: dec.alu_op=ALU_OR;
          3'b111: dec.alu_op=ALU_AND;
          3'b001: dec.alu_op=ALU_SLL; 
          3'b101: dec.alu_op=(funct7[5])?ALU_SRA:ALU_SRL;
        endcase
      end
      7'b0110011: begin 
        dec.uses_rs1=1'b1; dec.uses_rs2=1'b1; dec.uses_rd=1'b1; dec.is_alu_reg=1'b1;
        case(funct3)
          3'b000: dec.alu_op=(funct7[5])?ALU_SUB:ALU_ADD;
          3'b001: dec.alu_op=ALU_SLL;
          3'b010: dec.alu_op=ALU_SLT;
          3'b011: dec.alu_op=ALU_SLTU;
          3'b100: dec.alu_op=ALU_XOR;
          3'b101: dec.alu_op=(funct7[5])?ALU_SRA:ALU_SRL;
          3'b110: dec.alu_op=ALU_OR;
          3'b111: dec.alu_op=ALU_AND;
        endcase
      end
      default: dec.valid=1'b0;
    endcase

    if(!dec.uses_rs1) dec.rs1_arch=5'd0;
    if(!dec.uses_rs2) dec.rs2_arch=5'd0;
    if(dec.rd_arch==5'd0) dec.uses_rd=1'b0;
  end
endmodule