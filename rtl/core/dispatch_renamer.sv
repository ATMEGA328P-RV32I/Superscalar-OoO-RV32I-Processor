//Copyright 2026 Atul Kumar
import rv32i_types_pkg::*;

module dispatch_renamer #(
  parameter FETCH_WIDTH=4,
  parameter TAG_WIDTH=7
)(
  input decoded_inst_t dec_insts[FETCH_WIDTH],
  input logic dispatch_stall,
  
  output logic [FETCH_WIDTH-1:0] fl_pop_req,
  input logic [TAG_WIDTH-1:0] fl_allocated_tags[FETCH_WIDTH],
  
  input logic [TAG_WIDTH-1:0] rat_read_rs1[FETCH_WIDTH],
  input logic [TAG_WIDTH-1:0] rat_read_rs2[FETCH_WIDTH],
  output logic [FETCH_WIDTH-1:0] rat_write_en,
  output logic [4:0] rat_write_arch[FETCH_WIDTH],
  output logic [TAG_WIDTH-1:0] rat_write_phys[FETCH_WIDTH],
  
  output logic [FETCH_WIDTH-1:0] dispatch_valid,
  output logic [TAG_WIDTH-1:0] phys_rs1[FETCH_WIDTH],
  output logic [TAG_WIDTH-1:0] phys_rs2[FETCH_WIDTH],
  output logic [TAG_WIDTH-1:0] phys_rd[FETCH_WIDTH]
);

  always_comb begin
    for(int i=0;i<FETCH_WIDTH;i++) begin
      dispatch_valid[i]=dec_insts[i].valid&&!dispatch_stall;
      fl_pop_req[i]=dispatch_valid[i]&&dec_insts[i].uses_rd;
    end
  end

  always_comb begin
    for(int i=0;i<FETCH_WIDTH;i++) begin
      phys_rs1[i]=rat_read_rs1[i];
      phys_rs2[i]=rat_read_rs2[i];
      
      for(int j=0;j<i;j++) begin
        if(dec_insts[j].valid&&dec_insts[j].uses_rd) begin
          if(dec_insts[i].uses_rs1&&(dec_insts[i].rs1_arch==dec_insts[j].rd_arch)) begin
            phys_rs1[i]=fl_allocated_tags[j]; 
          end
          if(dec_insts[i].uses_rs2&&(dec_insts[i].rs2_arch==dec_insts[j].rd_arch)) begin
            phys_rs2[i]=fl_allocated_tags[j]; 
          end
        end
      end
      
      phys_rd[i]=fl_pop_req[i]?fl_allocated_tags[i]:'0;
      
      rat_write_en[i]=fl_pop_req[i];
      rat_write_arch[i]=dec_insts[i].rd_arch;
      rat_write_phys[i]=phys_rd[i];
    end
  end
endmodule
