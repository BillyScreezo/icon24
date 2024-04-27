module liteic_slave_node_read
    import liteic_pkg::IC_NUM_MASTER_SLOTS;
    import liteic_pkg::IC_ARADDR_WIDTH;
    import liteic_pkg::IC_RDATA_WIDTH;
    import liteic_pkg::IC_RD_CONNECTIVITY;

(
    input logic                                clk_i,
    input logic                                rstn_i,

    // interconnect i/o
    axi_lite_if_20bit_addr                     slv_axil,

    // node matrix i/o
    input  logic [ IC_ARADDR_WIDTH-13    : 0 ] cbar_reqst_data_i  [ IC_NUM_MASTER_SLOTS ],
    input  logic [ IC_NUM_MASTER_SLOTS-1 : 0 ] cbar_reqst_val_i,
    output logic [ IC_NUM_MASTER_SLOTS-1 : 0 ] cbar_reqst_rdy_o,

    input  logic [ IC_NUM_MASTER_SLOTS-1 : 0 ] cbar_resp_rdy_i,
    output logic [ IC_NUM_MASTER_SLOTS-1 : 0 ] cbar_resp_val_o,
    output logic [ IC_RDATA_WIDTH-1      : 0 ] cbar_resp_data_o
);


//-------------------------------------------------------------------------------
// localparams
//-------------------------------------------------------------------------------

function int unsigned count_master_slots();
    count_master_slots = 0;
    for(int i = 0; i < IC_NUM_MASTER_SLOTS; i++) begin
        if(IC_RD_CONNECTIVITY[i])
            count_master_slots++;
    end
endfunction

// get n-th non-zero position in connectivity vector
function int unsigned get_connectivity_idx(int n);
    int connectivity_idx;
    connectivity_idx = 0;
    for(int i = 0; i < IC_NUM_MASTER_SLOTS; i++) begin
        if(IC_RD_CONNECTIVITY[i]) begin
            if (connectivity_idx == n)
                return i;
            else
                connectivity_idx++;
        end
    end
endfunction

// determine node's master slots number
localparam NODE_NUM_MASTER_SLOTS   = count_master_slots();
localparam NODE_MASTER_ID_WIDTH   = (NODE_NUM_MASTER_SLOTS == 1) ? 1 : $clog2(NODE_NUM_MASTER_SLOTS);

//-------------------------------------------------------------------------------
// signals & interfaces
//-------------------------------------------------------------------------------

// Handling node's connectivity to interconnect crossbar matrix
logic [ IC_ARADDR_WIDTH-13      : 0  ] node_araddr_w [ NODE_NUM_MASTER_SLOTS ];
logic [ NODE_NUM_MASTER_SLOTS-1 : 0  ] node_arvalid_w;
logic [ NODE_NUM_MASTER_SLOTS-1 : 0  ] node_arready_w;
logic [ NODE_NUM_MASTER_SLOTS-1 : 0  ] node_rready_w;
logic [ NODE_NUM_MASTER_SLOTS-1 : 0  ] node_rvalid_w;
logic [ IC_RDATA_WIDTH-1        : 0  ] node_rdata_w;
// IDs of masters, which sent requests
logic [ NODE_NUM_MASTER_SLOTS-1 : 0 ] mst_id_reqst_onehot;
logic [ NODE_NUM_MASTER_SLOTS-1 : 0 ] mst_id_reqst_prior_onehot;
logic [ NODE_NUM_MASTER_SLOTS-1 : 0 ] mst_id_reqst_prior_onehot_r;

logic [ NODE_MASTER_ID_WIDTH-1 : 0 ] mst_id_reqst;
logic [ NODE_MASTER_ID_WIDTH-1 : 0 ] mst_id_reqst_prior;
logic [ NODE_MASTER_ID_WIDTH-1 : 0 ] mst_id_reqst_prior_r;


// Signals from/to AXI master
logic [ IC_ARADDR_WIDTH-13     : 0 ] slv_araddr_wo;
logic                                slv_arvalid_wo;
logic                                slv_arready_wi;

logic [ IC_RDATA_WIDTH-1       : 0 ] slv_rdata_wi;
logic                                slv_rvalid_wi;
logic                                slv_rready_wo;

// Flags
logic node_busy;
logic ar_success;
logic ar_success_r;

//-------------------------------------------------------------------------------
// = Reconnect interfaces and combine from interfaces
//-------------------------------------------------------------------------------
assign slv_axil.ar_valid = slv_arvalid_wo; 
assign slv_axil.ar_addr  = slv_araddr_wo;
assign slv_arready_wi    = slv_axil.ar_ready;

assign slv_axil.r_ready = slv_rready_wo;
assign slv_rdata_wi     = {slv_axil.r_data, slv_axil.r_resp};
assign slv_rvalid_wi    = slv_axil.r_valid; 

//-------------------------------------------------------------------------------
// Reconnect crossbar, if nodes has no connection
//-------------------------------------------------------------------------------

assign cbar_resp_data_o = node_rdata_w;
generate 
    for (genvar node_mst_slot_idx = 0; node_mst_slot_idx < NODE_NUM_MASTER_SLOTS; node_mst_slot_idx++) begin
        localparam ic_mst_slot_idx = get_connectivity_idx(node_mst_slot_idx);

        assign node_araddr_w[node_mst_slot_idx] = cbar_reqst_data_i[ic_mst_slot_idx];
        assign node_arvalid_w [node_mst_slot_idx] = cbar_reqst_val_i [ic_mst_slot_idx];
        assign node_rready_w  [node_mst_slot_idx] = cbar_resp_rdy_i  [ic_mst_slot_idx];

        assign cbar_reqst_rdy_o[ic_mst_slot_idx]  = node_arready_w[node_mst_slot_idx];
        assign cbar_resp_val_o [ic_mst_slot_idx]  = node_rvalid_w [node_mst_slot_idx];
    end
endgenerate


//-------------------------------------------------------------------------------
// AXI signal management
//-------------------------------------------------------------------------------

// Define mst id, from which the request came
assign mst_id_reqst        = (!node_busy) ? mst_id_reqst_prior : mst_id_reqst_prior_r;
// The same, but onehot
assign mst_id_reqst_onehot = (!node_busy) ? mst_id_reqst_prior_onehot : mst_id_reqst_prior_onehot_r;


// = AR channel = //

assign  slv_arvalid_wo = ((|(node_arvalid_w)) && (!ar_success_r));
assign node_arready_w  = (slv_arready_wi) ? mst_id_reqst_onehot : '0;
assign  slv_araddr_wo  = node_araddr_w[mst_id_reqst];   // !

// logic [IC_ARADDR_WIDTH-13:0] tmp_mux1 [3];
// logic [IC_ARADDR_WIDTH-13:0] tmp_mux2;

// always_comb begin
//     unique case ( mst_id_reqst[2:0] )
//         3'b000:  tmp_mux1[0] = node_araddr_w[0];
//         3'b001:  tmp_mux1[0] = node_araddr_w[1];
//         3'b010:  tmp_mux1[0] = node_araddr_w[2];
//         3'b011:  tmp_mux1[0] = node_araddr_w[3];
//         3'b100:  tmp_mux1[0] = node_araddr_w[4];
//         3'b101:  tmp_mux1[0] = node_araddr_w[5];
//         3'b110:  tmp_mux1[0] = node_araddr_w[6];
//         default: tmp_mux1[0] = node_araddr_w[7];
//     endcase

//     unique case ( mst_id_reqst[2:0] )
//         3'b000:  tmp_mux1[1] = node_araddr_w[8];
//         3'b001:  tmp_mux1[1] = node_araddr_w[9];
//         3'b010:  tmp_mux1[1] = node_araddr_w[10];
//         3'b011:  tmp_mux1[1] = node_araddr_w[11];
//         3'b100:  tmp_mux1[1] = node_araddr_w[12];
//         3'b101:  tmp_mux1[1] = node_araddr_w[13];
//         3'b110:  tmp_mux1[1] = node_araddr_w[14];
//         default: tmp_mux1[1] = node_araddr_w[15];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1[2] = node_araddr_w[16];
//         2'b01:   tmp_mux1[2] = node_araddr_w[17];
//         2'b10:   tmp_mux1[2] = node_araddr_w[18];
//         default: tmp_mux1[2] = node_araddr_w[19];
//     endcase
// end

// assign tmp_mux2 = mst_id_reqst[3] ? tmp_mux1[1] : tmp_mux1[0];

// assign slv_araddr_wo = mst_id_reqst[4] ? tmp_mux1[2] : tmp_mux2;

////////////////////////////////////////////////////////////////////////////////////////////////////

// logic [IC_ARADDR_WIDTH-13:0] tmp_mux1 [5];
// logic [IC_ARADDR_WIDTH-13:0] tmp_mux2;

// always_comb begin
//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1[0] = node_araddr_w[0];
//         2'b01:   tmp_mux1[0] = node_araddr_w[1];
//         2'b10:   tmp_mux1[0] = node_araddr_w[2];
//         default: tmp_mux1[0] = node_araddr_w[3];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1[1] = node_araddr_w[4];
//         2'b01:   tmp_mux1[1] = node_araddr_w[5];
//         2'b10:   tmp_mux1[1] = node_araddr_w[6];
//         default: tmp_mux1[1] = node_araddr_w[7];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1[2] = node_araddr_w[8];
//         2'b01:   tmp_mux1[2] = node_araddr_w[9];
//         2'b10:   tmp_mux1[2] = node_araddr_w[10];
//         default: tmp_mux1[2] = node_araddr_w[11];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1[3] = node_araddr_w[12];
//         2'b01:   tmp_mux1[3] = node_araddr_w[13];
//         2'b10:   tmp_mux1[3] = node_araddr_w[14];
//         default: tmp_mux1[3] = node_araddr_w[15];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1[4] = node_araddr_w[16];
//         2'b01:   tmp_mux1[4] = node_araddr_w[17];
//         2'b10:   tmp_mux1[4] = node_araddr_w[18];
//         default: tmp_mux1[4] = node_araddr_w[19];
//     endcase
// end

// always_comb begin
//     unique case ( mst_id_reqst[3:2] )
//         2'b00:   tmp_mux2 = tmp_mux1[0];
//         2'b01:   tmp_mux2 = tmp_mux1[1];
//         2'b10:   tmp_mux2 = tmp_mux1[2];
//         default: tmp_mux2 = tmp_mux1[3];
//     endcase
// end

// assign slv_araddr_wo = mst_id_reqst[4] ? tmp_mux1[4] : tmp_mux2;

// = R channel = //

assign node_rvalid_w = (slv_rvalid_wi) ? mst_id_reqst_prior_onehot_r : '0; 
assign slv_rready_wo = |(mst_id_reqst_prior_onehot_r & node_rready_w);
assign node_rdata_w  = slv_rdata_wi;

//-------------------------------------------------------------------------------
// Save id of master, which sent the reqst
//-------------------------------------------------------------------------------

always_ff @(posedge clk_i)
if      (!rstn_i)                      mst_id_reqst_prior_onehot_r <= '0;
else if (slv_arvalid_wo && !node_busy) mst_id_reqst_prior_onehot_r <= mst_id_reqst_prior_onehot;

always_ff @(posedge clk_i)
if      (!rstn_i)                      mst_id_reqst_prior_r <= '0;
else if (slv_arvalid_wo && !node_busy) mst_id_reqst_prior_r <= mst_id_reqst_prior;

//-------------------------------------------------------------------------------
// Flags of busy node
//-------------------------------------------------------------------------------

always_ff @(posedge clk_i)
if      (!rstn_i)                       node_busy <= 'b0;
else if (slv_rvalid_wi & slv_rready_wo) node_busy <= 'b0;
else if (|node_arvalid_w              ) node_busy <= 'b1;

//-------------------------------------------------------------------------------
// Flags of success transactions
//-------------------------------------------------------------------------------


always_ff @(posedge clk_i)
if      (!rstn_i)                         ar_success_r <= 'b0;
else begin
    if (slv_rvalid_wi & slv_rready_wo)   ar_success_r <= 'b0;
    if (slv_arvalid_wo & slv_arready_wi) ar_success_r <= 'b1;
end


//assign ar_success   = slv_arvalid_wo & slv_arready_wi;
//always_ff @(posedge clk_i)
//if      (!rstn_i)                       ar_success_r <= 'b0;
//else if (slv_rvalid_wi & slv_rready_wo) ar_success_r <= 'b0;
//else                                    ar_success_r <= ar_success_r | ar_success;


//-------------------------------------------------------------------------------
// initializations units
//-------------------------------------------------------------------------------

liteic_priority_cd_s #(.IN_WIDTH(NODE_NUM_MASTER_SLOTS), .OUT_WIDTH(NODE_MASTER_ID_WIDTH)) 
master_reqst_priority_cd (
    .in     (node_arvalid_w           ),
    .onehot (mst_id_reqst_prior_onehot),
    .out    (mst_id_reqst_prior       )
); 
endmodule
