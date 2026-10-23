module gshare_predictor #(
  parameter BHT_W=8,
  parameter BTB_W=6,
  parameter N=4
)(
  input logic clk,
  input logic rst,

  input logic [31:0] read_pc[N],
  input logic [BHT_W-1:0] read_bhr, 
  output logic pred_taken[N],
  output logic [31:0] pred_target[N],
  output logic [BHT_W-1:0] current_bhr, 

  input logic train_valid,
  input logic [31:0] train_pc,
  input logic train_taken,
  input logic [31:0] train_target,
  input logic train_mispredicted,
  input logic [BHT_W-1:0] train_bhr,
  input logic train_actual_taken
);
  localparam BHT_ENTRIES=1<<BHT_W;
  localparam BTB_ENTRIES=1<<BTB_W;

  logic [1:0] pht[BHT_ENTRIES];
  logic [31:0] btb_tag[BTB_ENTRIES];
  logic [31:0] btb_target[BTB_ENTRIES];
  logic btb_valid[BTB_ENTRIES];
  logic [BHT_W-1:0] bhr;

  assign current_bhr=bhr;

  always_comb begin
    for(int i=0;i<N;i++) begin
      automatic logic [BHT_W-1:0] pht_idx=read_pc[i][BHT_W+1:2]^read_bhr;
      automatic logic [BTB_W-1:0] btb_idx=read_pc[i][BTB_W+1:2];

      if(btb_valid[btb_idx]&&btb_tag[btb_idx]==read_pc[i]) begin
        pred_taken[i]=pht[pht_idx][1];
        pred_target[i]=btb_target[btb_idx];
      end else begin
        pred_taken[i]=1'b0;
        pred_target[i]='0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if(rst) begin
      bhr<='0;
      for(int i=0;i<BHT_ENTRIES;i++) pht[i]<=2'b01; 
      for(int i=0;i<BTB_ENTRIES;i++) btb_valid[i]<=1'b0;
    end else if(train_valid) begin
      automatic logic [BHT_W-1:0] train_pht_idx=train_pc[BHT_W+1:2]^train_bhr;
      automatic logic [BTB_W-1:0] train_btb_idx=train_pc[BTB_W+1:2];

      if(train_actual_taken) begin
        btb_valid[train_btb_idx]<=1'b1;
        btb_tag[train_btb_idx]<=train_pc;
        btb_target[train_btb_idx]<=train_target;
      end

      if(train_taken) begin
        if(pht[train_pht_idx]!=2'b11) pht[train_pht_idx]<=pht[train_pht_idx]+1;
      end else begin
        if(pht[train_pht_idx]!=2'b00) pht[train_pht_idx]<=pht[train_pht_idx]-1;
      end

      if(train_mispredicted) begin
        bhr<={train_bhr[BHT_W-2:0],train_taken};
      end else begin
        bhr<={bhr[BHT_W-2:0],train_taken};
      end
    end
  end
endmodule