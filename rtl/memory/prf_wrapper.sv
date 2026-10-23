module prf_wrapper #(
  parameter DATA_WIDTH=32,
  parameter PRF_ENTRIES=96,
  parameter TAG_WIDTH=7,
  parameter N=4
)(
  input logic clk,
  input logic [TAG_WIDTH-1:0] read_addr_rs1[N],
  input logic [TAG_WIDTH-1:0] read_addr_rs2[N],
  output logic [DATA_WIDTH-1:0] read_data_rs1[N],
  output logic [DATA_WIDTH-1:0] read_data_rs2[N],
  
  input logic write_en[N],
  input logic [TAG_WIDTH-1:0] write_addr[N],
  input logic [DATA_WIDTH-1:0] write_data[N]
);

  localparam READ_PORTS=N*2; 
  localparam WRITE_PORTS=N;     
  
  logic [TAG_WIDTH-1:0] sram_rd_addr[READ_PORTS];
  logic [DATA_WIDTH-1:0] sram_rd_data[READ_PORTS];
  
  logic wr_en_g[N];
  always_comb begin
    for(int i=0;i<N;i++) begin
      wr_en_g[i]=write_en[i]&&(write_addr[i]!='0);
    end
  end
  
  always_comb begin
    for(int i=0;i<N;i++) begin
      sram_rd_addr[i*2]=read_addr_rs1[i];
      sram_rd_addr[(i*2)+1]=read_addr_rs2[i];
      
      read_data_rs1[i]=(read_addr_rs1[i]==7'd0)?'0:sram_rd_data[i*2];
      read_data_rs2[i]=(read_addr_rs2[i]==7'd0)?'0:sram_rd_data[(i*2)+1];
    end
  end
  
  multiport_sram #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(PRF_ENTRIES),
    .READ_PORTS(READ_PORTS),
    .WRITE_PORTS(WRITE_PORTS)
  ) prf_sram_core(
    .clk(clk),
    .rd_addr(sram_rd_addr),
    .rd_data(sram_rd_data),
    .wr_en(wr_en_g), 
    .wr_addr(write_addr),
    .wr_data(write_data)
  );
endmodule