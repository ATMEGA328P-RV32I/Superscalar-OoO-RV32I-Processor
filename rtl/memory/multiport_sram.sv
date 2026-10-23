module multiport_sram #(
  parameter DATA_WIDTH=32,
  parameter DEPTH=64,
  parameter READ_PORTS=4,
  parameter WRITE_PORTS=2
)(
  input logic clk,
  input logic [$clog2(DEPTH)-1:0] rd_addr[READ_PORTS],
  output logic [DATA_WIDTH-1:0] rd_data[READ_PORTS],
  input logic wr_en[WRITE_PORTS],
  input logic [$clog2(DEPTH)-1:0] wr_addr[WRITE_PORTS],
  input logic [DATA_WIDTH-1:0] wr_data[WRITE_PORTS]
);
  logic [DATA_WIDTH-1:0] mem[0:DEPTH-1];

  initial begin
    for(int k=0;k<DEPTH;k++) begin
      mem[k]='0;
    end
  end

  genvar i;
  generate
    for(i=0;i<READ_PORTS;i++) begin : gen_rd
      assign rd_data[i]=mem[rd_addr[i]];
    end
  endgenerate

  integer j;
  always_ff @(posedge clk) begin
    for(j=0;j<WRITE_PORTS;j++) begin
      if(wr_en[j]) begin
        mem[wr_addr[j]]<=wr_data[j];
      end
    end
  end
endmodule