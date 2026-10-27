//Copyright 2026 Atul Kumar
module mshr #(
  parameter DATA_W=32,
  parameter TAG_W=7,
  parameter ROB_W=6
)(
  input logic clk,
  input logic rst,
  input logic exception_flush,

  input logic early_flush,
  input logic [ROB_W-1:0] early_flush_rob_idx,
  input logic [ROB_W-1:0] rob_head,
  input logic lsq_cdb_valid,

  input logic req_valid,
  input logic [DATA_W-1:0] req_addr,
  input logic [TAG_W-1:0] req_rd_tag,
  input logic [ROB_W-1:0] req_rob_idx,
  input logic [1:0] req_mem_size,      
  input logic req_mem_unsigned,  
  output logic mshr_ready,

  output logic dcache_req_valid,
  output logic [DATA_W-1:0] dcache_req_addr,
  input logic dcache_resp_valid,
  input logic [DATA_W-1:0] dcache_resp_data,

  output logic cdb_valid,
  output logic [TAG_W-1:0] cdb_tag,
  output logic [DATA_W-1:0] cdb_data,
  output logic [ROB_W-1:0] cdb_rob_idx
);

  logic active;
  logic squashed;     
  logic result_held;  
  logic [DATA_W-1:0] held_data;

  logic [TAG_W-1:0] pending_tag;
  logic [ROB_W-1:0] pending_rob;
  logic [1:0] pending_size;
  logic pending_unsign;
  logic [1:0] pending_addr_lsb;

  assign mshr_ready=!active&&!result_held&&!cdb_valid;

  assign dcache_req_valid=(req_valid&&mshr_ready);
  assign dcache_req_addr=req_addr; 

  function automatic logic is_younger(input logic [ROB_W-1:0] check_idx,branch_idx,h);
    logic [ROB_W-1:0] age_check=check_idx-h;
    logic [ROB_W-1:0] age_branch=branch_idx-h;
    return age_check>age_branch;
  endfunction

  always_ff @(posedge clk) begin
    if(rst||exception_flush) begin
      active<=1'b0;
      cdb_valid<=1'b0;
      squashed<=1'b0;
      result_held<=1'b0;
    end else begin
      cdb_valid<=1'b0; 
      
      if(req_valid&&mshr_ready) begin
        active<=1'b1;
        squashed<=1'b0;
        result_held<=1'b0;
        pending_tag<=req_rd_tag;
        pending_rob<=req_rob_idx;
        pending_size<=req_mem_size;
        pending_unsign<=req_mem_unsigned;
        pending_addr_lsb<=req_addr[1:0];
      end

      if(active&&early_flush&&is_younger(pending_rob,early_flush_rob_idx,rob_head)) begin
        squashed<=1'b1;
      end

      if(result_held) begin
        if(early_flush&&is_younger(pending_rob,early_flush_rob_idx,rob_head)) begin
          result_held<=1'b0; 
        end else if(!lsq_cdb_valid) begin
          cdb_valid<=1'b1;
          cdb_data<=held_data;
          cdb_tag<=pending_tag;
          cdb_rob_idx<=pending_rob;
          result_held<=1'b0;
        end
      end else if(active&&dcache_resp_valid) begin
        logic [31:0] shifted_resp;
        logic [31:0] formatted_resp;
        logic is_squashed_now;
        
        shifted_resp=dcache_resp_data>>(pending_addr_lsb*8);
        if(pending_size==2'b00) begin 
          formatted_resp=pending_unsign?{24'b0,shifted_resp[7:0]}:{{24{shifted_resp[7]}},shifted_resp[7:0]};
        end else if(pending_size==2'b01) begin 
          formatted_resp=pending_unsign?{16'b0,shifted_resp[15:0]}:{{16{shifted_resp[15]}},shifted_resp[15:0]};
        end else begin 
          formatted_resp=dcache_resp_data;
        end
        
        is_squashed_now=squashed||(early_flush&&is_younger(pending_rob,early_flush_rob_idx,rob_head));

        if(is_squashed_now) begin
          active<=1'b0; 
        end else if(lsq_cdb_valid) begin
          result_held<=1'b1;
          held_data<=formatted_resp;
          active<=1'b0;
        end else begin
          cdb_valid<=1'b1;
          cdb_tag<=pending_tag;
          cdb_data<=formatted_resp;
          cdb_rob_idx<=pending_rob;
          active<=1'b0; 
        end
      end
    end
  end
endmodule
