module liteic_priority_cd_s #(
    parameter IN_WIDTH = 32,
    parameter OUT_WIDTH = $clog2(IN_WIDTH)
)(
    input  logic [IN_WIDTH-1:0]  in,
    output logic [IN_WIDTH-1:0]  onehot,
    output logic [OUT_WIDTH-1:0] out
);
 
    logic [IN_WIDTH-1:0] reversed;
    logic [IN_WIDTH-1:0] procesed;
    logic [IN_WIDTH-1:0] mask [OUT_WIDTH-1:0];

//    assign procesed = (reversed & (reversed - 'b1)) ^ reversed;

//    for (genvar i = 0; i < IN_WIDTH; i = i + 1) begin : reverse_position_gen
//        assign reversed[i] = in[IN_WIDTH-1-i];
//        assign onehot[i] = procesed[IN_WIDTH-1-i];
//    end
    always_comb begin
    case(1'b1)
//    in[31]: onehot = (32'b1 << 31);
//    in[30]: onehot = (32'b1 << 30);
//    in[29]: onehot = (32'b1 << 29);
//    in[28]: onehot = (32'b1 << 28);
//    in[27]: onehot = (32'b1 << 27);
//    in[26]: onehot = (32'b1 << 26);
//    in[25]: onehot = (32'b1 << 25);
//    in[24]: onehot = (32'b1 << 24);
//    in[23]: onehot = (32'b1 << 23);
//    in[22]: onehot = (32'b1 << 22);
//    in[21]: onehot = (32'b1 << 21);
//    in[20]: onehot = (32'b1 << 20);
    in[19]: onehot = (32'b1 << 19);
    in[18]: onehot = (32'b1 << 18);
    in[17]: onehot = (32'b1 << 17);
    in[16]: onehot = (32'b1 << 16);
    in[15]: onehot = (32'b1 << 15);
    in[14]: onehot = (32'b1 << 14);
    in[13]: onehot = (32'b1 << 13);
    in[12]: onehot = (32'b1 << 12);
    in[11]: onehot = (32'b1 << 11);
    in[10]: onehot = (32'b1 << 10);
    in[9]: onehot = (32'b1 << 9);
    in[8]: onehot = (32'b1 << 8);
    in[7]: onehot = (32'b1 << 7);
    in[6]: onehot = (32'b1 << 6);
    in[5]: onehot = (32'b1 << 5);
    in[4]: onehot = (32'b1 << 4);
    in[3]: onehot = (32'b1 << 3);
    in[2]: onehot = (32'b1 << 2);
    in[1]: onehot = (32'b1 << 1);
    in[0]: onehot = (32'b1 << 0);
    default: onehot = '0;
    endcase
    end
    for (genvar j = 0; j < OUT_WIDTH; j = j + 1) begin : binary_out_gen
        for (genvar i = 0; i < IN_WIDTH; i = i + 1) 
            assign mask[j][i] = (i >> j) & 1;
        assign out[j] = |(onehot & mask[j]);
    end
endmodule

module liteic_priority_cd_m #(
    parameter IN_WIDTH = 32,
    parameter OUT_WIDTH = $clog2(IN_WIDTH)
)(
    input  logic [IN_WIDTH-1:0]  in,
    output logic [IN_WIDTH-1:0]  onehot,
    output logic [OUT_WIDTH-1:0] out
);
 
    logic [IN_WIDTH-1:0] mask [OUT_WIDTH-1:0];

    assign onehot = in;
    
    for (genvar j = 0; j < OUT_WIDTH; j = j + 1) begin : binary_out_gen
        for (genvar i = 0; i < IN_WIDTH; i = i + 1) 
            assign mask[j][i] = (i >> j) & 1;
        assign out[j] = |(onehot & mask[j]);
    end
endmodule