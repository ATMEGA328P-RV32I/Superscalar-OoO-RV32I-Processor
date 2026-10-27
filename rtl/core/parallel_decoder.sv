//Copyright 2026 Atul Kumar
import rv32i_types_pkg::*;

module parallel_decoder #(
  parameter FETCH_WIDTH=4
)(
  input logic [(FETCH_WIDTH*32)-1:0] fq_data,
  input logic [FETCH_WIDTH-1:0] fq_valid_mask,
  output decoded_inst_t decoded_insts[FETCH_WIDTH]
);
  genvar i;
  generate
    for(i=0;i<FETCH_WIDTH;i++) begin : gen_decoders
      rv32i_full_decoder single_dec(
        .raw_inst(fq_data[(i*32)+:32]),
        .inst_valid(fq_valid_mask[i]),
        .dec(decoded_insts[i])
      );
    end
  endgenerate
endmodule
