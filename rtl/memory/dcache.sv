module dcache #(
  parameter DATA_W=32,
  parameter DEPTH=2048
)(
  input logic clk,
  input logic rst,

  input logic req_valid,
  input logic [DATA_W-1:0] req_addr,
  output logic resp_valid,
  output logic [DATA_W-1:0] resp_data,
  
  input logic st_valid,
  input logic [3:0] st_we,         
  input logic [DATA_W-1:0] st_addr,
  input logic [DATA_W-1:0] st_data
);

  logic [DATA_W-1:0] memory[0:DEPTH-1];

  initial begin
    for(int i=0;i<DEPTH;i++) memory[i]=32'h00000000;
  end

  always_ff @(posedge clk) begin
    resp_valid<=1'b0;
    if(rst) begin
      resp_data<='0;
    end else begin
      if(st_valid) begin
        logic [31:0] word_idx;
        word_idx=(st_addr[31:2])&(DEPTH-1);
        if(st_we[0]) memory[word_idx][7:0]<=st_data[7:0];
        if(st_we[1]) memory[word_idx][15:8]<=st_data[15:8];
        if(st_we[2]) memory[word_idx][23:16]<=st_data[23:16];
        if(st_we[3]) memory[word_idx][31:24]<=st_data[31:24];
      end
      
      if(req_valid) begin
        logic [31:0] word_idx;
        logic [31:0] raw_mem;
        word_idx=(req_addr[31:2])&(DEPTH-1);
        raw_mem=memory[word_idx];
        
        if(st_valid&&(st_addr[31:2]==req_addr[31:2])) begin
          if(st_we[0]) raw_mem[7:0]=st_data[7:0];
          if(st_we[1]) raw_mem[15:8]=st_data[15:8];
          if(st_we[2]) raw_mem[23:16]=st_data[23:16];
          if(st_we[3]) raw_mem[31:24]=st_data[31:24];
        end
        
        resp_data<=raw_mem;
        resp_valid<=1'b1;
      end
    end
  end
endmodule