module liteic_slave_node_write
    import liteic_pkg::IC_NUM_MASTER_SLOTS;
    import liteic_pkg::IC_AWADDR_WIDTH;
    import liteic_pkg::IC_WDATA_WIDTH;
    import liteic_pkg::IC_BRESP_WIDTH;
    import liteic_pkg::IC_WR_CONNECTIVITY;
(
    input logic clk_i,
    input logic rstn_i,

    // interconnect i/o
    axi_lite_if_20bit_addr slv_axil,

    // node matrix i/o
    input  logic [ IC_WDATA_WIDTH-1      : 0 ] cbar_w_reqst_data_i  [ IC_NUM_MASTER_SLOTS ],
    input  logic [ IC_NUM_MASTER_SLOTS-1 : 0 ] cbar_w_reqst_val_i,
    output logic [ IC_NUM_MASTER_SLOTS-1 : 0 ] cbar_w_reqst_rdy_o,

    input  logic [ IC_AWADDR_WIDTH-13    : 0 ] cbar_aw_reqst_data_i  [ IC_NUM_MASTER_SLOTS ],
    input  logic [ IC_NUM_MASTER_SLOTS-1 : 0 ] cbar_aw_reqst_val_i,
    output logic [ IC_NUM_MASTER_SLOTS-1 : 0 ] cbar_aw_reqst_rdy_o,

    input  logic [ IC_NUM_MASTER_SLOTS-1 : 0 ] cbar_resp_rdy_i,
    output logic [ IC_NUM_MASTER_SLOTS-1 : 0 ] cbar_resp_val_o,
    output logic [ IC_BRESP_WIDTH-1      : 0 ] cbar_resp_data_o
);


//-------------------------------------------------------------------------------
// localparams
//-------------------------------------------------------------------------------

// Find count of already connected master slots in interconnect
function int unsigned count_master_slots();
    count_master_slots = 0;
    for(int i = 0; i < IC_NUM_MASTER_SLOTS; i++) begin
        if(IC_WR_CONNECTIVITY[i])
            count_master_slots++;
    end
endfunction

// determine node's master slots number
localparam NODE_NUM_MASTER_SLOTS   = count_master_slots();

// get n-th non-zero position in connectivity vector
function int unsigned get_connectivity_idx(int n);
    int connectivity_idx;
    connectivity_idx = 0;
    for(int i = 0; i < IC_NUM_MASTER_SLOTS; i++) begin
        if(IC_WR_CONNECTIVITY[i]) begin
            if (connectivity_idx == n)
                return i;
            else
                connectivity_idx++;
        end
    end
endfunction

localparam NODE_MASTER_ID_WIDTH   = $clog2(NODE_NUM_MASTER_SLOTS);

//-------------------------------------------------------------------------------
// signals & interfaces
//-------------------------------------------------------------------------------

// Handling node's connectivity to interconnect crossbar matrix
logic [ IC_WDATA_WIDTH-1        : 0 ] node_wdata_w              [ NODE_NUM_MASTER_SLOTS ] ;
logic [ NODE_NUM_MASTER_SLOTS-1 : 0 ] node_wvalid_w;
logic [ NODE_NUM_MASTER_SLOTS-1 : 0 ] node_wready_w;
logic [ IC_AWADDR_WIDTH-13      : 0 ] node_awaddr               [ NODE_NUM_MASTER_SLOTS ] ;
logic [ NODE_NUM_MASTER_SLOTS-1 : 0 ] node_awvalid_w;
logic [ NODE_NUM_MASTER_SLOTS-1 : 0 ] node_awready_w;
logic [ NODE_NUM_MASTER_SLOTS-1 : 0 ] node_bready_w;
logic [ NODE_NUM_MASTER_SLOTS-1 : 0 ] node_bvalid_w;
logic [ IC_BRESP_WIDTH-1        : 0 ] node_bresp_w;

// IDs of masters, which sent requests
logic [ NODE_NUM_MASTER_SLOTS-1:0 ] mst_id_reqst_onehot;
logic [ NODE_NUM_MASTER_SLOTS-1:0 ] mst_id_reqst_prior_onehot;
logic [ NODE_NUM_MASTER_SLOTS-1:0 ] mst_id_reqst_prior_onehot_r;

logic [ NODE_MASTER_ID_WIDTH-1 :0 ] mst_id_reqst;
logic [ NODE_MASTER_ID_WIDTH-1 :0 ] mst_id_reqst_prior;
logic [ NODE_MASTER_ID_WIDTH-1 :0 ] mst_id_reqst_prior_r;

// Signals from/to AXI slave
logic [ IC_WDATA_WIDTH-1 : 0   ] slv_wdata_wo;
logic                            slv_wvalid_wo;
logic                            slv_wready_wi;

logic [ IC_AWADDR_WIDTH-13: 0  ] slv_awaddr_wo;
logic                            slv_awvalid_wo;
logic                            slv_awready_wi;

logic [ IC_BRESP_WIDTH-1   : 0 ] slv_bresp_wi;
logic                            slv_bvalid_wi;
logic                            slv_bready_wo;

// Flags
logic aw_success;
logic w_success;
logic aw_success_r;
logic w_success_r;
logic node_busy;

//-------------------------------------------------------------------------------
// = Reconnect and combine interfaces
//-------------------------------------------------------------------------------

assign slv_wready_wi                      = slv_axil.w_ready;
assign slv_axil.w_valid                   = slv_wvalid_wo;
assign {slv_axil.w_strb, slv_axil.w_data} = slv_wdata_wo;

assign slv_axil.aw_addr                   = slv_awaddr_wo;
assign slv_axil.aw_valid                  = slv_awvalid_wo ;
assign slv_awready_wi                     = slv_axil.aw_ready;

assign slv_bresp_wi                       = slv_axil.b_resp;
assign slv_bvalid_wi                      = slv_axil.b_valid;
assign slv_axil.b_ready                   = slv_bready_wo;

//-------------------------------------------------------------------------------
// Reconnect crossbar, if nodes has no connection
//-------------------------------------------------------------------------------

assign cbar_resp_data_o = node_bresp_w;
generate
    for (genvar node_mst_slot_idx = 0; node_mst_slot_idx < NODE_NUM_MASTER_SLOTS; node_mst_slot_idx++) begin
        localparam ic_mst_slot_idx = get_connectivity_idx(node_mst_slot_idx);

        assign node_wdata_w[node_mst_slot_idx]      = cbar_w_reqst_data_i[ic_mst_slot_idx];
        assign node_wvalid_w [node_mst_slot_idx]    = cbar_w_reqst_val_i [ic_mst_slot_idx];
        assign cbar_w_reqst_rdy_o[ic_mst_slot_idx]  = node_wready_w[node_mst_slot_idx];

        assign node_awaddr[node_mst_slot_idx]       = cbar_aw_reqst_data_i[ic_mst_slot_idx];
        assign node_awvalid_w [node_mst_slot_idx]   = cbar_aw_reqst_val_i [ic_mst_slot_idx];
        assign cbar_aw_reqst_rdy_o[ic_mst_slot_idx] = node_awready_w[node_mst_slot_idx];

        assign node_bready_w  [node_mst_slot_idx]   = cbar_resp_rdy_i  [ic_mst_slot_idx];
        assign cbar_resp_val_o [ic_mst_slot_idx]    = node_bvalid_w [node_mst_slot_idx];
    end
endgenerate

//-------------------------------------------------------------------------------
// AXI signal management
//-------------------------------------------------------------------------------

// Define mst id, from which the request came
assign mst_id_reqst        = (!node_busy) ? mst_id_reqst_prior : mst_id_reqst_prior_r;
// The same, but onehot
assign mst_id_reqst_onehot = (!node_busy) ? mst_id_reqst_prior_onehot : mst_id_reqst_prior_onehot_r;

// = AW channel = //
 
assign slv_awvalid_wo   = ((|(node_awvalid_w)) && (!aw_success_r));
assign node_awready_w = (slv_awready_wi ) ? mst_id_reqst_onehot : '0;
assign slv_awaddr_wo    = node_awaddr[mst_id_reqst];    // !

// logic [IC_AWADDR_WIDTH-13:0] tmp_mux1_1 [5];
// logic [IC_AWADDR_WIDTH-13:0] tmp_mux2_1;

// always_comb begin
//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1_1[0] = node_awaddr[0];
//         2'b01:   tmp_mux1_1[0] = node_awaddr[1];
//         2'b10:   tmp_mux1_1[0] = node_awaddr[2];
//         default: tmp_mux1_1[0] = node_awaddr[3];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1_1[1] = node_awaddr[4];
//         2'b01:   tmp_mux1_1[1] = node_awaddr[5];
//         2'b10:   tmp_mux1_1[1] = node_awaddr[6];
//         default: tmp_mux1_1[1] = node_awaddr[7];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1_1[2] = node_awaddr[8];
//         2'b01:   tmp_mux1_1[2] = node_awaddr[9];
//         2'b10:   tmp_mux1_1[2] = node_awaddr[10];
//         default: tmp_mux1_1[2] = node_awaddr[11];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1_1[3] = node_awaddr[12];
//         2'b01:   tmp_mux1_1[3] = node_awaddr[13];
//         2'b10:   tmp_mux1_1[3] = node_awaddr[14];
//         default: tmp_mux1_1[3] = node_awaddr[15];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1_1[4] = node_awaddr[16];
//         2'b01:   tmp_mux1_1[4] = node_awaddr[17];
//         2'b10:   tmp_mux1_1[4] = node_awaddr[18];
//         default: tmp_mux1_1[4] = node_awaddr[19];
//     endcase
// end

// always_comb begin
//     unique case ( mst_id_reqst[3:2] )
//         2'b00:   tmp_mux2 = tmp_mux1_1[0];
//         2'b01:   tmp_mux2 = tmp_mux1_1[1];
//         2'b10:   tmp_mux2 = tmp_mux1_1[2];
//         default: tmp_mux2 = tmp_mux1_1[3];
//     endcase
// end

// assign slv_awaddr_wo = mst_id_reqst[4] ? tmp_mux1_1[4] : tmp_mux2;

// = W channel = //

assign slv_wvalid_wo  = (|(mst_id_reqst_onehot & node_wvalid_w)) && (!w_success_r);
assign node_wready_w  = (slv_wready_wi ) ? mst_id_reqst_onehot : '0;
assign slv_wdata_wo   = node_wdata_w[mst_id_reqst];     // !

// logic [IC_WDATA_WIDTH-1:0] tmp_mux1_2 [5];
// logic [IC_WDATA_WIDTH-1:0] tmp_mux2_2;

// always_comb begin
//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1_2[0] = node_wdata_w[0];
//         2'b01:   tmp_mux1_2[0] = node_wdata_w[1];
//         2'b10:   tmp_mux1_2[0] = node_wdata_w[2];
//         default: tmp_mux1_2[0] = node_wdata_w[3];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1_2[1] = node_wdata_w[4];
//         2'b01:   tmp_mux1_2[1] = node_wdata_w[5];
//         2'b10:   tmp_mux1_2[1] = node_wdata_w[6];
//         default: tmp_mux1_2[1] = node_wdata_w[7];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1_2[2] = node_wdata_w[8];
//         2'b01:   tmp_mux1_2[2] = node_wdata_w[9];
//         2'b10:   tmp_mux1_2[2] = node_wdata_w[10];
//         default: tmp_mux1_2[2] = node_wdata_w[11];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1_2[3] = node_wdata_w[12];
//         2'b01:   tmp_mux1_2[3] = node_wdata_w[13];
//         2'b10:   tmp_mux1_2[3] = node_wdata_w[14];
//         default: tmp_mux1_2[3] = node_wdata_w[15];
//     endcase

//     unique case ( mst_id_reqst[1:0] )
//         2'b00:   tmp_mux1_2[4] = node_wdata_w[16];
//         2'b01:   tmp_mux1_2[4] = node_wdata_w[17];
//         2'b10:   tmp_mux1_2[4] = node_wdata_w[18];
//         default: tmp_mux1_2[4] = node_wdata_w[19];
//     endcase
// end

// always_comb begin
//     unique case ( mst_id_reqst[3:2] )
//         2'b00:   tmp_mux2 = tmp_mux1_2[0];
//         2'b01:   tmp_mux2 = tmp_mux1_2[1];
//         2'b10:   tmp_mux2 = tmp_mux1_2[2];
//         default: tmp_mux2 = tmp_mux1_2[3];
//     endcase
// end

// assign slv_wdata_wo = mst_id_reqst[4] ? tmp_mux1_2[4] : tmp_mux2;


// = B channel = //

assign node_bvalid_w = (slv_bvalid_wi) ? mst_id_reqst_prior_onehot_r : '0;
assign slv_bready_wo = |(mst_id_reqst_prior_onehot_r & node_bready_w);
assign node_bresp_w  = slv_bresp_wi;

//-------------------------------------------------------------------------------
// Save id of master, which sent the reqst
//-------------------------------------------------------------------------------

always_ff @(posedge clk_i)
if      (!rstn_i)                      mst_id_reqst_prior_onehot_r <= '0;
else if (slv_awvalid_wo && !node_busy) mst_id_reqst_prior_onehot_r <= mst_id_reqst_prior_onehot;

always_ff @(posedge clk_i)
if      (!rstn_i)                      mst_id_reqst_prior_r <= '0;
else if (slv_awvalid_wo && !node_busy) mst_id_reqst_prior_r <= mst_id_reqst_prior;

//-------------------------------------------------------------------------------
// Flags of busy node
//-------------------------------------------------------------------------------

always_ff @(posedge clk_i)
if      (!rstn_i)                       node_busy <= 'b0;
else if (slv_bvalid_wi & slv_bready_wo) node_busy <= 'b0;
else if (|node_awvalid_w              ) node_busy <= 'b1;

//-------------------------------------------------------------------------------
// Flags of success transactions
//-------------------------------------------------------------------------------

//assign aw_success   = slv_awvalid_wo && slv_awready_wi;
always_ff @(posedge clk_i)
if      (!rstn_i)                       aw_success_r <= 'b0;
else begin
    if (slv_bvalid_wi & slv_bready_wo) aw_success_r <= 'b0;
    if(slv_awvalid_wo && slv_awready_wi) aw_success_r <= 'b1;
end

//assign  w_success   =  slv_wvalid_wo &&  slv_wready_wi;
always_ff @(posedge clk_i)
if      (!rstn_i)                       w_success_r <= 'b0;
else begin
    if (slv_bvalid_wi & slv_bready_wo) w_success_r <= 'b0;
    if(slv_wvalid_wo & slv_wready_wi) w_success_r <= 'b1;
end

//-------------------------------------------------------------------------------
// initializations units
//-------------------------------------------------------------------------------

liteic_priority_cd_s #(.IN_WIDTH(NODE_NUM_MASTER_SLOTS), .OUT_WIDTH(NODE_MASTER_ID_WIDTH)) 
master_aw_reqst_priority_cd (
    .in     (node_awvalid_w            ) ,
    .onehot (mst_id_reqst_prior_onehot ) ,
    .out    (mst_id_reqst_prior        )
);

endmodule
