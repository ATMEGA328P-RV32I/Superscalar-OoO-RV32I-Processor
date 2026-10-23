module nwide_fetch_unit #(
  parameter PC_WIDTH=32,
  parameter FETCH_WIDTH=4,
  parameter BHT_W=8
)(
  input logic clk,
  input logic rst,
  input logic dispatch_stall,
  input logic mispredict_flush,
  
  input logic early_flush,
  input logic [PC_WIDTH-1:0] early_flush_pc,
  
  input logic [PC_WIDTH-1:0] recovery_pc,
  
  output logic [PC_WIDTH-1:0] icache_addr,
  input logic [(FETCH_WIDTH*32)-1:0] icache_data,
  input logic icache_valid,
  
  input logic pred_taken_in[FETCH_WIDTH],
  input logic [PC_WIDTH-1:0] pred_target_in[FETCH_WIDTH],
  input logic [BHT_W-1:0] current_bhr_in,
  input logic [BHT_W-1:0] recovered_bhr_in, 
  input logic [3:0] recovered_tos_in, 
  
  output logic fq_push,
  output logic [(FETCH_WIDTH*32)-1:0] fq_data,
  output logic [PC_WIDTH-1:0] fq_pc,
  output logic [FETCH_WIDTH-1:0] fq_valid_mask,
  output logic fq_pred_taken[FETCH_WIDTH],     
  output logic [PC_WIDTH-1:0] fq_pred_target[FETCH_WIDTH],
  output logic [BHT_W-1:0] fq_pred_bhr[FETCH_WIDTH],
  output logic [3:0] fq_tos[FETCH_WIDTH],         
  output logic [BHT_W-1:0] spec_bhr_out 
);

  logic [PC_WIDTH-1:0] pc,s1_pc;
  logic s1_valid;
  logic [(FETCH_WIDTH*32)-1:0] s1_data; 
  logic s1_pred_taken[FETCH_WIDTH];
  logic [PC_WIDTH-1:0] s1_pred_target[FETCH_WIDTH];
  logic [BHT_W-1:0] s1_pred_bhr[FETCH_WIDTH];
  logic [3:0] s1_tos[FETCH_WIDTH];
  
  assign icache_addr={pc[31:4],4'b0000}; 

  logic fetch_redirect;
  logic [PC_WIDTH-1:0] redirect_target;
  logic [FETCH_WIDTH-1:0] fetch_valid_mask;
  
  logic spec_push_cmb;
  logic spec_pop_cmb;
  logic [PC_WIDTH-1:0] push_addr_cmb;
  logic [PC_WIDTH-1:0] ras_pop_addr;
  logic [3:0] current_tos;
  logic [PC_WIDTH-1:0] final_pred_target[FETCH_WIDTH];
  logic final_pred_taken[FETCH_WIDTH];

  always_comb begin
    fetch_redirect=1'b0;
    redirect_target='0;
    spec_push_cmb=1'b0;
    spec_pop_cmb=1'b0;
    push_addr_cmb='0;
    
    for(int i=0;i<FETCH_WIDTH;i++) begin : predecode_loop
      logic [31:0] inst;
      logic [6:0] op;
      logic [4:0] rd,rs1;
      logic [31:0] inst_pc;
      logic is_call,is_ret;

      final_pred_target[i]=pred_target_in[i];
      final_pred_taken[i]=pred_taken_in[i];
      fetch_valid_mask[i]=({pc[31:4],4'b0000}+(i*4))>=pc;
      
      if(fetch_valid_mask[i]&&!fetch_redirect&&icache_valid) begin
        inst=icache_data[i*32+:32];
        op=inst[6:0];
        rd=inst[11:7];
        rs1=inst[19:15];
        inst_pc={pc[31:4],4'b0000}+(i*4);
        
        is_call=(op==7'b1101111||op==7'b1100111)&&(rd!=5'd0);
        is_ret=(op==7'b1100111)&&(rd==5'd0)&&(rs1!=5'd0);
        
        if(is_ret) begin
          final_pred_taken[i]=1'b1;
          final_pred_target[i]=(ras_pop_addr=='0)?(inst_pc+4):ras_pop_addr; 
          fetch_redirect=1'b1;
          redirect_target=final_pred_target[i];
          spec_pop_cmb=1'b1;
        end else begin
          if(is_call) begin
            spec_push_cmb=1'b1;
            push_addr_cmb=inst_pc+4;
          end
          if(pred_taken_in[i]) begin
            fetch_redirect=1'b1;
            redirect_target=pred_target_in[i];
          end
        end
      end
    end
  end
  
  logic halt_seen,halt_latch;

  return_address_stack #(.DEPTH_LOG2(4),.PC_WIDTH(PC_WIDTH)) ras_inst(
    .clk(clk),.rst(rst),
    .spec_push(spec_push_cmb&&!dispatch_stall&&icache_valid&&!halt_seen&&!halt_latch),
    .spec_pop(spec_pop_cmb&&!dispatch_stall&&icache_valid&&!halt_seen&&!halt_latch),
    .push_addr(push_addr_cmb),.pop_addr(ras_pop_addr),
    .tos_snapshot(current_tos),
    .mispredict_flush(mispredict_flush||early_flush),
    .recovery_tos(recovered_tos_in)
  );

  logic [BHT_W-1:0] spec_bhr;
  assign spec_bhr_out=spec_bhr; 

  always_ff @(posedge clk) begin
    if(rst) begin
      s1_pc<='0; s1_valid<=1'b0; s1_data<='0; spec_bhr<='0; 
      for(int i=0;i<FETCH_WIDTH;i++) begin
        s1_pred_taken[i]<='0; s1_pred_target[i]<='0; s1_pred_bhr[i]<='0; s1_tos[i]<='0;
      end
    end else if(mispredict_flush||early_flush) begin
      s1_pc<='0; s1_valid<=1'b0; s1_data<='0; 
      spec_bhr<=recovered_bhr_in; 
      for(int i=0;i<FETCH_WIDTH;i++) begin
        s1_pred_taken[i]<='0; s1_pred_target[i]<='0; s1_pred_bhr[i]<='0; s1_tos[i]<='0;
      end
    end else if(!dispatch_stall) begin
      logic updated; updated=1'b0;
      s1_pc<=pc; s1_valid<=icache_valid; s1_data<=icache_data; 
      for(int i=0;i<FETCH_WIDTH;i++) begin
        s1_pred_taken[i]<=final_pred_taken[i]; s1_pred_target[i]<=final_pred_target[i];
        s1_pred_bhr[i]<=spec_bhr; s1_tos[i]<=current_tos; 
        if(icache_valid&&(({pc[31:4],4'b0000}+(i*4))>=pc)&&!updated) begin
          if(icache_data[i*32+:7]==7'b1100011||icache_data[i*32+:7]==7'b1101111) begin
            spec_bhr<={spec_bhr[BHT_W-2:0],pred_taken_in[i]};
            updated=1'b1;
          end
        end
      end
    end
  end

  logic branch_seen;
  logic [FETCH_WIDTH-1:0] fq_valid_mask_raw;
  
  always_comb begin
    halt_seen=1'b0; branch_seen=1'b0;
    for(int i=0;i<FETCH_WIDTH;i++) begin
      fq_valid_mask_raw[i]=({s1_pc[31:4],4'b0000}+(i*4))>=s1_pc;
      if(halt_seen||branch_seen) fq_valid_mask[i]=1'b0; 
      else fq_valid_mask[i]=fq_valid_mask_raw[i];
      
      if(s1_valid&&fq_valid_mask_raw[i]) begin
        if(s1_data[i*32+:32]==32'h00000063) halt_seen=1'b1;
        if(s1_pred_taken[i]) branch_seen=1'b1;
      end
    end
  end
  
  always_ff @(posedge clk) begin
    if(rst||mispredict_flush||early_flush) halt_latch<=1'b0;
    else if(halt_seen&&!dispatch_stall) halt_latch<=1'b1;
  end

  assign fq_push=s1_valid&&!dispatch_stall&&!mispredict_flush&&!early_flush&&!halt_latch;
  assign fq_data=s1_data;        
  assign fq_pc=s1_pc;
  assign fq_pred_taken=s1_pred_taken;
  assign fq_pred_target=s1_pred_target;
  assign fq_pred_bhr=s1_pred_bhr;
  assign fq_tos=s1_tos; 
  
  logic [PC_WIDTH-1:0] next_aligned_pc;
  assign next_aligned_pc={pc[31:4],4'b0000}+16; 

  always_ff @(posedge clk) begin
    if(rst) pc<='0;
    else if(mispredict_flush) pc<=recovery_pc; 
    else if(early_flush) pc<=early_flush_pc; 
    else if(!dispatch_stall&&icache_valid&&!halt_seen&&!halt_latch) begin
      if(fetch_redirect) pc<=redirect_target;
      else pc<=next_aligned_pc;
    end
  end
endmodule