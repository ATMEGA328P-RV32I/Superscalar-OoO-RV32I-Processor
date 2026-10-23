`timescale 1ns/1ps
module tb_superscalar_core_top;
  parameter N=4;
  parameter DATA_W=32;
  logic clk;
  logic rst;
  superscalar_core_top #(.N(N),.DATA_W(DATA_W)) dut(.clk(clk),.rst(rst));
  string disasm[0:4095];
  initial begin
    for(int i=0; i<4096; i++) disasm[i]="NOP / PADDING";
    disasm[12'h000]="LUI   x0, 0xDEADB";
    disasm[12'h004]="ADDI  x0, x0, 0xFF";
    disasm[12'h008]="AUIPC x0, 0";
    disasm[12'h00C]="LW    x0, 0(x1)";
    disasm[12'h010]="JAL   x0, +4";
    disasm[12'h014]="ADDI  x2, x0, 0";
    disasm[12'h018]="BNE   x2, x0, _trap";
    disasm[12'h01C]="LUI   x3, 1";
    disasm[12'h020]="ADDI  x3, x3, 1";
    disasm[12'h024]="SLLI  x3, x3, 1";
    disasm[12'h028]="XORI  x3, x3, 15";
    disasm[12'h02C]="SRLI  x3, x3, 1";
    disasm[12'h030]="OR    x3, x3, x0";
    disasm[12'h034]="AND   x3, x3, x3";
    disasm[12'h038]="SUB   x3, x3, x0";
    disasm[12'h03C]="ADD   x3, x3, x3";
    disasm[12'h040]="SRAI  x3, x3, 1";
    disasm[12'h044]="ADDI  x4, x3, 0";
    disasm[12'h048]="LUI   x3, 0x1000";
    disasm[12'h04C]="ADDI  x5, x3, 0";
    disasm[12'h050]="LUI   x3, 0x2000";
    disasm[12'h054]="ADDI  x6, x3, 0";
    disasm[12'h058]="ADDI  x10, x0, 1";
    disasm[12'h05C]="ADD   x11, x10, x10";
    disasm[12'h060]="ADD   x12, x11, x11";
    disasm[12'h064]="ADD   x13, x12, x12";
    disasm[12'h068]="ADD   x14, x13, x13";
    disasm[12'h06C]="ADD   x15, x14, x14";
    disasm[12'h070]="ADD   x16, x15, x15";
    disasm[12'h074]="ADD   x17, x16, x16";
    disasm[12'h078]="ADD   x18, x17, x17";
    disasm[12'h07C]="ADD   x19, x18, x18";
    disasm[12'h080]="ADD   x20, x19, x19";
    disasm[12'h084]="ADD   x21, x20, x20";
    disasm[12'h088]="ADD   x22, x21, x21";
    disasm[12'h08C]="ADD   x23, x22, x22";
    disasm[12'h090]="ADD   x24, x23, x23";
    disasm[12'h094]="ADD   x25, x24, x24";
    disasm[12'h098]="ADD   x26, x25, x25";
    disasm[12'h09C]="LUI   x1, 0x10";
    disasm[12'h0A0]="SW    x26, 0(x1)";
    disasm[12'h0A4]="LW    x27, 0(x1)";
    disasm[12'h0A8]="BNE   x26, x27, _trap";
    disasm[12'h0AC]="LUI   x28, 0x12345";
    disasm[12'h0B0]="ADDI  x28, x28, 0x678";
    disasm[12'h0B4]="SW    x28, 4(x1)";
    disasm[12'h0B8]="LB    x29, 4(x1)";
    disasm[12'h0BC]="LBU   x30, 5(x1)";
    disasm[12'h0C0]="LH    x31, 6(x1)";
    disasm[12'h0C4]="ADD   x2, x1, x10";
    disasm[12'h0C8]="SW    x31, 0(x2)";
    disasm[12'h0CC]="LW    x3, -1(x2)";
    disasm[12'h0D0]="ADDI  x5, x0, 10";
    disasm[12'h0D4]="ADDI  x5, x5, -1";
    disasm[12'h0D8]="BEQ   x5, x0, _bht_exit";
    disasm[12'h0DC]="BNE   x5, x0, _bht_loop";
    disasm[12'h0E0]="ADDI  x31, x0, 0";
    disasm[12'h0E4]="JAL   x1, _func_01";
    disasm[12'h0E8]="ADDI  x30, x0, 10";
    disasm[12'h0EC]="BNE   x31, x30, _trap";
    disasm[12'h0F0]="JAL   x0, _stress_test";
    disasm[12'h0F4]="ADDI  x31, x31, 1";
    disasm[12'h0F8]="JAL   x2, _func_02";
    disasm[12'h0FC]="JALR  x0, 0(x1)";
    disasm[12'h100]="ADDI  x31, x31, 1";
    disasm[12'h104]="JAL   x3, _func_03";
    disasm[12'h108]="JALR  x0, 0(x2)";
    disasm[12'h10C]="ADDI  x31, x31, 1";
    disasm[12'h110]="JAL   x4, _func_04";
    disasm[12'h114]="JALR  x0, 0(x3)";
    disasm[12'h118]="ADDI  x31, x31, 1";
    disasm[12'h11C]="JAL   x5, _func_05";
    disasm[12'h120]="JALR  x0, 0(x4)";
    disasm[12'h124]="ADDI  x31, x31, 1";
    disasm[12'h128]="JAL   x6, _func_06";
    disasm[12'h12C]="JALR  x0, 0(x5)";
    disasm[12'h130]="ADDI  x31, x31, 1";
    disasm[12'h134]="JAL   x7, _func_07";
    disasm[12'h138]="JALR  x0, 0(x6)";
    disasm[12'h13C]="ADDI  x31, x31, 1";
    disasm[12'h140]="JAL   x8, _func_08";
    disasm[12'h144]="JALR  x0, 0(x7)";
    disasm[12'h148]="ADDI  x31, x31, 1";
    disasm[12'h14C]="JAL   x9, _func_09";
    disasm[12'h150]="JALR  x0, 0(x8)";
    disasm[12'h154]="ADDI  x31, x31, 1";
    disasm[12'h158]="JAL   x10, _func_10";
    disasm[12'h15C]="JALR  x0, 0(x9)";
    disasm[12'h160]="ADDI  x31, x31, 1";
    disasm[12'h164]="JALR  x0, 0(x10)";
    disasm[12'h168]="J     _trap";
    disasm[12'h170]="ADDI  x23, x0, 0";
    disasm[12'h174]="ADDI  x24, x0, 0";
    disasm[12'h178]="LUI   x20, 0x10";
    disasm[12'h17C]="SW    x0, 12(x20)";
    disasm[12'h180]="LW    x21, 12(x20)";
    disasm[12'h184]="ADDI  x21, x21, 1";
    disasm[12'h188]="ADD   x21, x21, x21";
    disasm[12'h18C]="ADD   x21, x21, x21";
    disasm[12'h190]="ADD   x21, x21, x21";
    disasm[12'h194]="ADDI  x22, x0, 8";
    disasm[12'h198]="BEQ   x21, x22, _stress_pass"; 
    disasm[12'h19C]="ADDI  x23, x0, 100";
    disasm[12'h1A0]="BNE   x23, x0, +8";
    disasm[12'h1A4]="ADDI  x23, x23, 1";
    disasm[12'h1A8]="ADDI  x24, x0, 200";
    disasm[12'h1AC]="BNE   x24, x0, +8";
    disasm[12'h1B0]="ADDI  x24, x24, 1";
    disasm[12'h1B4]="JAL   x0, _trap";
    disasm[12'h1B8]="ADD   x25, x23, x24";
    disasm[12'h1BC]="BNE   x25, x0, _trap";
    disasm[12'h1C0]="ADDI  x30, x0, -1";
    disasm[12'h1C4]="SW    x30, 0(x1)";
    disasm[12'h1C8]="LB    x31, 0(x1)";
    disasm[12'h1CC]="ADDI  x29, x0, -1";
    disasm[12'h1D0]="BNE   x31, x29, _trap";
    disasm[12'h1D4]="JAL   x0, _final_halt";
    disasm[12'h200]="BEQ   x0, x0, 0 (HALT)";
  end
  initial begin
    clk=0;
    forever #5 clk=~clk; 
  end
  initial begin
    rst=1;
    #20 rst=0;
    #5000;
    $display("[%0t] [SIM] Timeout reached.",$time);
    $finish;
  end
  always @(posedge clk) begin
    if(!rst) begin
      $display("[%0t] [FETCH] PC=0x%0h",$time,dut.fetch_pc);
      if(dut.dispatch_stall) $display("[%0t] [STALL] Dispatch blocked",$time);
      for(int i=0; i<N; i++) begin
        automatic logic vld=(i==3)?dut.lsq_cdb_valid:dut.ex_cdb_valid[i];
        automatic logic [5:0] rob=(i==3)?dut.lsq_cdb_rob_idx:dut.ex_cdb_rob_idx[i];
        automatic logic [31:0] dt=(i==3)?dut.lsq_cdb_data:dut.ex_cdb_data[i];
        automatic logic [6:0] tag=(i==3)?dut.lsq_cdb_tag:dut.ex_cdb_tag[i]; 
        if(vld) begin
          automatic logic [31:0] pc_val=dut.inst_info_ram[rob].pc;
          automatic logic is_ctl=dut.inst_info_ram[rob].is_jump||dut.inst_info_ram[rob].is_branch;
          if(i==3&&dut.inst_info_ram[rob].is_store) $display("[%0t] [EXEC_MEM] PC=0x%0h (%s) Store captured",$time,pc_val,disasm[pc_val[11:0]]);
          else if(i==3) $display("[%0t] [EXEC_MEM] PC=0x%0h (%s) Load=%0d -> P%0d",$time,pc_val,disasm[pc_val[11:0]],dt,tag);
          else if(is_ctl) $display("[%0t] [EXEC_ALU] PC=0x%0h (%s) Target=0x%0h Link=%0d -> P%0d",$time,pc_val,disasm[pc_val[11:0]],dut.ex_cdb_branch_target[i],dt,tag);
          else $display("[%0t] [EXEC_ALU] PC=0x%0h (%s) Val=%0d -> P%0d",$time,pc_val,disasm[pc_val[11:0]],dt,tag);
        end
      end
      for(int i=0; i<N; i++) begin
        if(dut.commit_valid[i]) begin
          automatic logic [31:0] pc_val=dut.inst_info_ram[dut.commit_rob_idx[i]].pc;
          if(dut.commit_is_store[i]) $display("[%0t] [RETIRE_ST] PC=0x%0h (%s)",$time,pc_val,disasm[pc_val[11:0]]);
          else if(dut.inst_info_ram[dut.commit_rob_idx[i]].is_jump) begin
            $display("[%0t] [RETIRE_JMP] PC=0x%0h (%s) x%0d=%0d [Free P%0d]",$time,pc_val,disasm[pc_val[11:0]],dut.commit_rd_arch[i],dut.prf.prf_sram_core.mem[dut.commit_rd_phys[i]],dut.commit_stale_phys[i]);
            if(pc_val[11:0]==12'h200) $finish;
          end else if(dut.inst_info_ram[dut.commit_rob_idx[i]].is_branch) begin
            $display("[%0t] [RETIRE_BR] PC=0x%0h (%s)",$time,pc_val,disasm[pc_val[11:0]]);
            if(pc_val[11:0]==12'h200) $finish;
          end else $display("[%0t] [RETIRE_REG] PC=0x%0h (%s) x%0d=%0d [Free P%0d]",$time,pc_val,disasm[pc_val[11:0]],dut.commit_rd_arch[i],dut.prf.prf_sram_core.mem[dut.commit_rd_phys[i]],dut.commit_stale_phys[i]);
        end
      end
    end
  end
endmodule
