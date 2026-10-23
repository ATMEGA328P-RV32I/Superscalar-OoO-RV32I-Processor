module store_forwarding_cam #(
  parameter LSQ_ENTRIES=16,   
  parameter DATA_W=32
)(
  input logic issue_valid,
  input logic issue_is_store,
  input logic [3:0] issue_lsq_idx,
  input logic [DATA_W-1:0] calc_addr,
  input logic [3:0] lsq_head,
  
  input logic [LSQ_ENTRIES-1:0] lsq_valid,
  input logic [LSQ_ENTRIES-1:0] lsq_is_store,
  input logic [LSQ_ENTRIES-1:0] lsq_addr_valid,
  input logic [DATA_W-1:0] lsq_addr[LSQ_ENTRIES],
  input logic [DATA_W-1:0] lsq_data[LSQ_ENTRIES],

  output logic forward_match,
  output logic [DATA_W-1:0] forward_data
);
  logic [3:0] dist_issue,best_dist;

  always_comb begin
    forward_match=1'b0;
    forward_data='0;
    best_dist=4'd0;
    dist_issue=issue_lsq_idx-lsq_head;   

    if(issue_valid&&!issue_is_store) begin
      for(int e=0;e<LSQ_ENTRIES;e++) begin
        logic [3:0] d;
        d=4'(e)-lsq_head;               
        if(lsq_valid[e]&&lsq_is_store[e]&&lsq_addr_valid[e]&&
          (lsq_addr[e][31:2]==calc_addr[31:2])&&(d<dist_issue)) begin 
          if(!forward_match||d>best_dist) begin   
            forward_match=1'b1;
            forward_data=lsq_data[e];
            best_dist=d;
          end
        end
      end
    end
  end
endmodule