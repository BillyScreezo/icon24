
module liteic_icon_top
    import liteic_pkg::IC_NUM_MASTER_SLOTS;
    import liteic_pkg::IC_NUM_SLAVE_SLOTS;
    import liteic_pkg::AXI_ADDR_WIDTH;
    import liteic_pkg::AXI_DATA_WIDTH;
    import liteic_pkg::AXI_RESP_WIDTH;
    import liteic_pkg::IC_ARADDR_WIDTH;
    import liteic_pkg::IC_RDATA_WIDTH;
    import liteic_pkg::IC_AWADDR_WIDTH;
    import liteic_pkg::IC_WDATA_WIDTH;
    import liteic_pkg::IC_BRESP_WIDTH;
    import liteic_pkg::IC_RD_CONNECTIVITY;
    import liteic_pkg::IC_WR_CONNECTIVITY;
    import liteic_pkg::IC_SLAVE_REGION_BASE;
    import liteic_pkg::IC_SLAVE_REGION_SIZE;
(
    input logic         clk_i,
    input logic         rstn_i,

    // axil interfaces
    axi_lite_if.sp      mst_axil [ IC_NUM_MASTER_SLOTS ],
    axi_lite_if.mp      slv_axil [ IC_NUM_SLAVE_SLOTS  ]
);

//-------------------------------------------------------------------------------
// functions
//-------------------------------------------------------------------------------

typedef bit [IC_NUM_SLAVE_SLOTS-1:0] connectivity_t [IC_NUM_MASTER_SLOTS];

function [IC_NUM_MASTER_SLOTS-1:0] get_column(int column, connectivity_t matrix);
    get_column = '0;
    for (int mst_idx = 0; mst_idx < IC_NUM_MASTER_SLOTS; mst_idx++) begin
        get_column[mst_idx] = matrix[mst_idx][column];
    end
endfunction

function bit check_region_overlap(int i, int j);
    check_region_overlap = 0;
    // check for overlap of i-th region with j-th one
    //  First check:    |  Second check:
    //  [---j---]       |      [---j---]
    //      [---i---]   |  [---i---]
    // First check
    if( ( IC_SLAVE_REGION_BASE[j] <= IC_SLAVE_REGION_BASE[i]                                                      ) &&
        (                            IC_SLAVE_REGION_BASE[i] <= (IC_SLAVE_REGION_BASE[j]+IC_SLAVE_REGION_SIZE[j]-1) )
    ) check_region_overlap = 1;

    // Second check
    if( ( IC_SLAVE_REGION_BASE[j] <= (IC_SLAVE_REGION_BASE[i]+IC_SLAVE_REGION_SIZE[i]-1)                            ) &&
        (                            (IC_SLAVE_REGION_BASE[i]+IC_SLAVE_REGION_SIZE[i]-1) <= (IC_SLAVE_REGION_BASE[j]+IC_SLAVE_REGION_SIZE[j]-1) )
    ) check_region_overlap = 1;
endfunction

//-------------------------------------------------------------------------------
// parameters checking
//-------------------------------------------------------------------------------

generate // regions overlap check
    for (genvar i = 0; i < IC_NUM_SLAVE_SLOTS; i++) begin
        for (genvar j = 0; j < IC_NUM_SLAVE_SLOTS; j++) begin
            if((i != j) && check_region_overlap(i, j)) begin : regions_overlap_check
                //$error($sformatf("Found overlapping regions! Overlap between region #%0d and #%0d", i, j));
                $error($sformatf("Found overlapping regions! Overlap between region #%0d[%0d:%0d] and #%0d[%0d:%0d]", i, IC_SLAVE_REGION_BASE[i], IC_SLAVE_REGION_BASE[i] + IC_SLAVE_REGION_SIZE[i],  j, IC_SLAVE_REGION_BASE[j], IC_SLAVE_REGION_BASE[j] + IC_SLAVE_REGION_SIZE[j]));

            end
        end
    end
endgenerate

//-------------------------------------------------------------------------------
// External decoding:
//-------------------------------------------------------------------------------

    logic [IC_NUM_SLAVE_SLOTS-1:0] rgn_select_aw [IC_NUM_MASTER_SLOTS]; // region select
    logic [IC_NUM_SLAVE_SLOTS-1:0] rgn_select_ar [IC_NUM_MASTER_SLOTS]; // region select

for (genvar m = 0; m < IC_NUM_MASTER_SLOTS; m++) begin : master_range_sel
    for (genvar s = 0; s < IC_NUM_SLAVE_SLOTS; s++) begin : slave_range_sel
        assign rgn_select_ar[m][s] = (mst_axil[m].ar_addr[23:20] == IC_SLAVE_REGION_BASE[s][23:20]) && (~|mst_axil[m].ar_addr[31:24]);
        assign rgn_select_aw[m][s] = (mst_axil[m].aw_addr[23:20] == IC_SLAVE_REGION_BASE[s][23:20]) && (~|mst_axil[m].aw_addr[31:24]);
    end
end

    logic [IC_NUM_MASTER_SLOTS-1:0] illegal_addr_aw; // llegal address flag
    logic [IC_NUM_MASTER_SLOTS-1:0] illegal_addr_ar; // llegal address flag

for (genvar m = 0; m < IC_NUM_MASTER_SLOTS; m++) begin : master_range_ill
    assign illegal_addr_aw[m] = ~|( rgn_select_aw[m] );
    assign illegal_addr_ar[m] = ~|( rgn_select_ar[m] );
end

//-------------------------------------------------------------------------------
// NODE AXIL Interfaces
//-------------------------------------------------------------------------------

// Create axil_if for every node
axi_lite_if_20bit_addr #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_RESP_WIDTH) mnode_axil_if [IC_NUM_MASTER_SLOTS]();
axi_lite_if_20bit_addr #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_RESP_WIDTH) snode_axil_if [IC_NUM_SLAVE_SLOTS] ();

// Split interconnect's axilite interfaces with 'sp' and 'mp' modports into
// node's axilite interfaces with corresponding channel modport,
// which depends on node's type (mst/slv) and node's channel (read/write)
// Splitting is needed to avoid multidriving of an interface from different nodes
generate
    for(genvar mst_idx = 0; mst_idx < IC_NUM_MASTER_SLOTS; mst_idx++) begin
//        always_ff @(posedge clk_i) begin
//         mnode_axil_if[mst_idx].ar_addr  <= mst_axil[mst_idx].ar_addr  ;
//         mnode_axil_if[mst_idx].ar_valid <= mst_axil[mst_idx].ar_valid ;
//         mnode_axil_if[mst_idx].r_ready  <= mst_axil[mst_idx].r_ready  ;
//         mnode_axil_if[mst_idx].aw_addr  <= mst_axil[mst_idx].aw_addr  ;
//         mnode_axil_if[mst_idx].aw_valid <= mst_axil[mst_idx].aw_valid ;
//         mnode_axil_if[mst_idx].w_data   <= mst_axil[mst_idx].w_data   ;
//         mnode_axil_if[mst_idx].w_strb   <= mst_axil[mst_idx].w_strb   ;
//         mnode_axil_if[mst_idx].w_valid  <= mst_axil[mst_idx].w_valid  ;
//         mnode_axil_if[mst_idx].b_ready  <= mst_axil[mst_idx].b_ready  ;

//         mst_axil[mst_idx].ar_ready <= mnode_axil_if[mst_idx].ar_ready ;
//         mst_axil[mst_idx].r_data   <= mnode_axil_if[mst_idx].r_data   ;
//         mst_axil[mst_idx].r_resp   <= mnode_axil_if[mst_idx].r_resp   ;
//         mst_axil[mst_idx].r_valid  <= mnode_axil_if[mst_idx].r_valid  ;
//         mst_axil[mst_idx].aw_ready <= mnode_axil_if[mst_idx].aw_ready ;
//         mst_axil[mst_idx].w_ready  <= mnode_axil_if[mst_idx].w_ready  ;
//         mst_axil[mst_idx].b_resp   <= mnode_axil_if[mst_idx].b_resp   ;
//         mst_axil[mst_idx].b_valid  <= mnode_axil_if[mst_idx].b_valid  ;
//        end

        assign mnode_axil_if[mst_idx].ar_addr  = mst_axil[mst_idx].ar_addr[19:0]  ;
        assign mnode_axil_if[mst_idx].ar_valid = mst_axil[mst_idx].ar_valid       ;
        assign mnode_axil_if[mst_idx].r_ready  = mst_axil[mst_idx].r_ready        ;
        assign mnode_axil_if[mst_idx].aw_addr  = mst_axil[mst_idx].aw_addr[19:0]  ;
        assign mnode_axil_if[mst_idx].aw_valid = mst_axil[mst_idx].aw_valid       ;
        assign mnode_axil_if[mst_idx].w_data   = mst_axil[mst_idx].w_data         ;
        assign mnode_axil_if[mst_idx].w_strb   = mst_axil[mst_idx].w_strb         ;
        assign mnode_axil_if[mst_idx].w_valid  = mst_axil[mst_idx].w_valid        ;
        assign mnode_axil_if[mst_idx].b_ready  = mst_axil[mst_idx].b_ready        ;

        assign mst_axil[mst_idx].ar_ready = mnode_axil_if[mst_idx].ar_ready       ;
        assign mst_axil[mst_idx].r_data   = mnode_axil_if[mst_idx].r_data         ;
        assign mst_axil[mst_idx].r_resp   = mnode_axil_if[mst_idx].r_resp         ;
        assign mst_axil[mst_idx].r_valid  = mnode_axil_if[mst_idx].r_valid        ;
        assign mst_axil[mst_idx].aw_ready = mnode_axil_if[mst_idx].aw_ready       ;
        assign mst_axil[mst_idx].w_ready  = mnode_axil_if[mst_idx].w_ready        ;
        assign mst_axil[mst_idx].b_resp   = mnode_axil_if[mst_idx].b_resp         ;
        assign mst_axil[mst_idx].b_valid  = mnode_axil_if[mst_idx].b_valid        ;
    end

    for(genvar slv_idx = 0; slv_idx < IC_NUM_SLAVE_SLOTS; slv_idx++) begin
        assign slv_axil[slv_idx].ar_addr  = {8'b0,IC_SLAVE_REGION_BASE[slv_idx][23:20],snode_axil_if[slv_idx].ar_addr[19:0]}  ;
        assign slv_axil[slv_idx].ar_valid = snode_axil_if[slv_idx].ar_valid       ;
        assign slv_axil[slv_idx].r_ready  = snode_axil_if[slv_idx].r_ready        ;
        assign slv_axil[slv_idx].aw_addr  = {8'b0,IC_SLAVE_REGION_BASE[slv_idx][23:20],snode_axil_if[slv_idx].aw_addr[19:0]}  ;
        assign slv_axil[slv_idx].aw_valid = snode_axil_if[slv_idx].aw_valid       ;
        assign slv_axil[slv_idx].w_data   = snode_axil_if[slv_idx].w_data         ;
        assign slv_axil[slv_idx].w_strb   = snode_axil_if[slv_idx].w_strb         ;
        assign slv_axil[slv_idx].w_valid  = snode_axil_if[slv_idx].w_valid        ;
        assign slv_axil[slv_idx].b_ready  = snode_axil_if[slv_idx].b_ready        ;

        assign snode_axil_if[slv_idx].ar_ready = slv_axil[slv_idx].ar_ready       ;
        assign snode_axil_if[slv_idx].r_data   = slv_axil[slv_idx].r_data         ;
        assign snode_axil_if[slv_idx].r_resp   = slv_axil[slv_idx].r_resp         ;
        assign snode_axil_if[slv_idx].r_valid  = slv_axil[slv_idx].r_valid        ;
        assign snode_axil_if[slv_idx].aw_ready = slv_axil[slv_idx].aw_ready       ;
        assign snode_axil_if[slv_idx].w_ready  = slv_axil[slv_idx].w_ready        ;
        assign snode_axil_if[slv_idx].b_resp   = slv_axil[slv_idx].b_resp         ;
        assign snode_axil_if[slv_idx].b_valid  = slv_axil[slv_idx].b_valid        ;
    end
endgenerate

//-------------------------------------------------------------------------------
// READ CROSSBAR
//-------------------------------------------------------------------------------

// Defines read crossbar for interconnect
// Data tranfers when rdy(ready) and val(valid) on both sides is high(1)

// Define read arrays of data bus for crossbar
logic [IC_ARADDR_WIDTH-13    : 0] rnode_reqst_data [IC_NUM_MASTER_SLOTS];
logic [IC_RDATA_WIDTH-1      : 0] rnode_resp_data  [IC_NUM_SLAVE_SLOTS ];

// Define read master node request ports of crossbar 
logic [IC_NUM_SLAVE_SLOTS-1  : 0] rmnode_reqst_rdy_i [IC_NUM_MASTER_SLOTS];
logic [IC_NUM_SLAVE_SLOTS-1  : 0] rmnode_reqst_val_o [IC_NUM_MASTER_SLOTS];
// Define read slave node request ports of crossbar 
logic [IC_NUM_MASTER_SLOTS-1 : 0] rsnode_reqst_val_i [IC_NUM_SLAVE_SLOTS];
logic [IC_NUM_MASTER_SLOTS-1 : 0] rsnode_reqst_rdy_o [IC_NUM_SLAVE_SLOTS];

// Define read master node response ports of crossbar 
logic [IC_NUM_SLAVE_SLOTS-1  : 0] rmnode_resp_val_i  [IC_NUM_MASTER_SLOTS];
logic [IC_NUM_SLAVE_SLOTS-1  : 0] rmnode_resp_rdy_o  [IC_NUM_MASTER_SLOTS];
// Define read slave node response ports of crossbar
logic [IC_NUM_MASTER_SLOTS-1 : 0] rsnode_resp_val_o  [IC_NUM_SLAVE_SLOTS];
logic [IC_NUM_MASTER_SLOTS-1 : 0] rsnode_resp_rdy_i  [IC_NUM_SLAVE_SLOTS];

// Connect request and response ports
generate
    for(genvar mst_idx = 0; mst_idx < IC_NUM_MASTER_SLOTS; mst_idx++) begin : rnode_matrix_mst
        for(genvar slv_idx = 0; slv_idx < IC_NUM_SLAVE_SLOTS; slv_idx++) begin : rnode_matrix_slv
        
            always_ff @(posedge clk_i) begin
                 // Connect request read ports
                 rsnode_reqst_val_i[slv_idx][mst_idx] = rmnode_reqst_val_o[mst_idx][slv_idx];
                 rmnode_reqst_rdy_i[mst_idx][slv_idx] = rsnode_reqst_rdy_o[slv_idx][mst_idx];
            end
        
//            // Connect request read ports
//            assign rsnode_reqst_val_i[slv_idx][mst_idx] = rmnode_reqst_val_o[mst_idx][slv_idx];
//            assign rmnode_reqst_rdy_i[mst_idx][slv_idx] = rsnode_reqst_rdy_o[slv_idx][mst_idx];
            
//            always_ff @(posedge clk_i) begin
//                  // Connect response read ports
//                 rmnode_resp_val_i[mst_idx][slv_idx]  = rsnode_resp_val_o[slv_idx][mst_idx];
//                 rsnode_resp_rdy_i[slv_idx][mst_idx]  = rmnode_resp_rdy_o[mst_idx][slv_idx];
//            end
            
            // Connect response read ports
            assign rmnode_resp_val_i[mst_idx][slv_idx]  = rsnode_resp_val_o[slv_idx][mst_idx];
            assign rsnode_resp_rdy_i[slv_idx][mst_idx]  = rmnode_resp_rdy_o[mst_idx][slv_idx];
        end
    end


//-------------------------------------------------------------------------------
// READ NODES
//-------------------------------------------------------------------------------

for(genvar mst_idx = 0; mst_idx < IC_NUM_MASTER_SLOTS; mst_idx++) begin : rd_mst_node_read
    liteic_master_node_read node_wrap (
        .clk_i             (clk_i                          ),
        .rstn_i            (rstn_i                         ),
        .mst_axil          (mnode_axil_if[mst_idx].sp_read ),
        .rgn_select_i      (rgn_select_ar         [mst_idx]),
        .illegal_addr_i    (illegal_addr_ar       [mst_idx]),
        .cbar_reqst_rdy_i  (rmnode_reqst_rdy_i    [mst_idx]),
        .cbar_reqst_val_o  (rmnode_reqst_val_o    [mst_idx]),
        .cbar_reqst_data_o (rnode_reqst_data      [mst_idx]),
        .cbar_resp_data_i  (rnode_resp_data                ),
        .cbar_resp_val_i   (rmnode_resp_val_i     [mst_idx]),
        .cbar_resp_rdy_o   (rmnode_resp_rdy_o     [mst_idx])
    );
end

for(genvar slv_idx = 0; slv_idx < IC_NUM_SLAVE_SLOTS; slv_idx++) begin : rd_slv_node_read
    liteic_slave_node_read node_wrap (
        .clk_i             (clk_i                          ),
        .rstn_i            (rstn_i                         ),
        .slv_axil          (snode_axil_if[slv_idx].mp_read ),
        .cbar_reqst_data_i (rnode_reqst_data               ),
        .cbar_reqst_val_i  (rsnode_reqst_val_i    [slv_idx]),
        .cbar_reqst_rdy_o  (rsnode_reqst_rdy_o    [slv_idx]),
        .cbar_resp_rdy_i   (rsnode_resp_rdy_i     [slv_idx]),
        .cbar_resp_val_o   (rsnode_resp_val_o     [slv_idx]),
        .cbar_resp_data_o  (rnode_resp_data       [slv_idx])
    );
end
endgenerate

//-------------------------------------------------------------------------------
// WRITE CROSSBAR
//-------------------------------------------------------------------------------

// Defines write crossbar for interconnect
// Data tranfers when rdy(ready) and val(valid) on both sides is high(1)

// Define write arrays of data bus for crossbar
logic [IC_WDATA_WIDTH-1      : 0] wnode_w_reqst_data  [IC_NUM_MASTER_SLOTS];
logic [IC_AWADDR_WIDTH-13    : 0] wnode_aw_reqst_data [IC_NUM_MASTER_SLOTS];
logic [IC_BRESP_WIDTH-1      : 0] wnode_resp_data     [IC_NUM_SLAVE_SLOTS ];

// Define data write master node request ports of crossbar 
logic [IC_NUM_SLAVE_SLOTS-1  : 0] wmnode_w_reqst_rdy_i [IC_NUM_MASTER_SLOTS];
logic [IC_NUM_SLAVE_SLOTS-1  : 0] wmnode_w_reqst_val_o [IC_NUM_MASTER_SLOTS];
// Define data write slave node request ports of crossbar 
logic [IC_NUM_MASTER_SLOTS-1 : 0] wsnode_w_reqst_val_i [IC_NUM_SLAVE_SLOTS];
logic [IC_NUM_MASTER_SLOTS-1 : 0] wsnode_w_reqst_rdy_o [IC_NUM_SLAVE_SLOTS];

// Define address write master node request ports of crossbar 
logic [IC_NUM_SLAVE_SLOTS-1  : 0] wmnode_aw_reqst_rdy_i [IC_NUM_MASTER_SLOTS];
logic [IC_NUM_SLAVE_SLOTS-1  : 0] wmnode_aw_reqst_val_o [IC_NUM_MASTER_SLOTS];
// Define address write slave node request ports of crossbar 
logic [IC_NUM_MASTER_SLOTS-1 : 0] wsnode_aw_reqst_val_i [IC_NUM_SLAVE_SLOTS];
logic [IC_NUM_MASTER_SLOTS-1 : 0] wsnode_aw_reqst_rdy_o [IC_NUM_SLAVE_SLOTS];


// Define write master node response ports of crossbar 
logic [IC_NUM_SLAVE_SLOTS-1  : 0] wmnode_resp_val_i  [IC_NUM_MASTER_SLOTS];
logic [IC_NUM_SLAVE_SLOTS-1  : 0] wmnode_resp_rdy_o  [IC_NUM_MASTER_SLOTS];
// Define write slave node response ports of crossbar
logic [IC_NUM_MASTER_SLOTS-1 : 0] wsnode_resp_val_o  [IC_NUM_SLAVE_SLOTS];
logic [IC_NUM_MASTER_SLOTS-1 : 0] wsnode_resp_rdy_i  [IC_NUM_SLAVE_SLOTS];

// Connect request and response ports
generate
    for(genvar mst_idx = 0; mst_idx < IC_NUM_MASTER_SLOTS; mst_idx++) begin : wnode_matrix_mst
        for(genvar slv_idx = 0; slv_idx < IC_NUM_SLAVE_SLOTS; slv_idx++) begin : wnode_matrix_slv

            always_ff @(posedge clk_i) begin
                // Connect request address write ports
                wsnode_aw_reqst_val_i[slv_idx][mst_idx] <= wmnode_aw_reqst_val_o[mst_idx][slv_idx];
                wmnode_aw_reqst_rdy_i[mst_idx][slv_idx] <= wsnode_aw_reqst_rdy_o[slv_idx][mst_idx];
            end
            // Connect request address write ports
//            assign wsnode_aw_reqst_val_i[slv_idx][mst_idx] = wmnode_aw_reqst_val_o[mst_idx][slv_idx];
//            assign wmnode_aw_reqst_rdy_i[mst_idx][slv_idx] = wsnode_aw_reqst_rdy_o[slv_idx][mst_idx];
            
//            always_ff @(posedge clk_i) begin
//            // Connect response write ports
//             wmnode_resp_val_i[mst_idx][slv_idx]  <= wsnode_resp_val_o[slv_idx][mst_idx];
//             wsnode_resp_rdy_i[slv_idx][mst_idx]  <= wmnode_resp_rdy_o[mst_idx][slv_idx];
//            end
            
            // Connect response write ports
            assign wmnode_resp_val_i[mst_idx][slv_idx]  = wsnode_resp_val_o[slv_idx][mst_idx];
            assign wsnode_resp_rdy_i[slv_idx][mst_idx]  = wmnode_resp_rdy_o[mst_idx][slv_idx];
            
            
            always_ff @(posedge clk_i) begin
            // Connect request data write ports
             wsnode_w_reqst_val_i[slv_idx][mst_idx] <= wmnode_w_reqst_val_o[mst_idx][slv_idx];
             wmnode_w_reqst_rdy_i[mst_idx][slv_idx] <= wsnode_w_reqst_rdy_o[slv_idx][mst_idx];
            end
            
    // Connect request data write ports
    //            assign wsnode_w_reqst_val_i[slv_idx][mst_idx] = wmnode_w_reqst_val_o[mst_idx][slv_idx];
    //            assign wmnode_w_reqst_rdy_i[mst_idx][slv_idx] = wsnode_w_reqst_rdy_o[slv_idx][mst_idx];
        end
    end

//-------------------------------------------------------------------------------
// WRITE NODES
//-------------------------------------------------------------------------------

for(genvar mst_idx = 0; mst_idx < IC_NUM_MASTER_SLOTS; mst_idx++) begin : wr_mst_node_write
    liteic_master_node_write node_wrap (
        .clk_i                (clk_i                           ),
        .rstn_i               (rstn_i                          ),
        .mst_axil             (mnode_axil_if[mst_idx].sp_write ),
        .rgn_select_i         (rgn_select_aw         [mst_idx] ),
        .illegal_addr_i       (illegal_addr_aw       [mst_idx] ),
        .cbar_w_reqst_rdy_i   (wmnode_w_reqst_rdy_i  [mst_idx] ),
        .cbar_w_reqst_val_o   (wmnode_w_reqst_val_o  [mst_idx] ),
        .cbar_w_reqst_data_o  (wnode_w_reqst_data    [mst_idx] ),
        .cbar_aw_reqst_rdy_i  (wmnode_aw_reqst_rdy_i [mst_idx] ),
        .cbar_aw_reqst_val_o  (wmnode_aw_reqst_val_o [mst_idx] ),
        .cbar_aw_reqst_data_o (wnode_aw_reqst_data   [mst_idx] ),
        .cbar_resp_data_i     (wnode_resp_data                 ),
        .cbar_resp_val_i      (wmnode_resp_val_i     [mst_idx] ),
        .cbar_resp_rdy_o      (wmnode_resp_rdy_o     [mst_idx] )
    );
end

for(genvar slv_idx = 0; slv_idx < IC_NUM_SLAVE_SLOTS; slv_idx++) begin : wr_slv_node_write
    liteic_slave_node_write node_wrap (
        .clk_i                (clk_i                           ),
        .rstn_i               (rstn_i                          ),
        .slv_axil             (snode_axil_if[slv_idx].mp_write ),
        .cbar_w_reqst_data_i  (wnode_w_reqst_data              ),
        .cbar_w_reqst_val_i   (wsnode_w_reqst_val_i  [slv_idx] ),
        .cbar_w_reqst_rdy_o   (wsnode_w_reqst_rdy_o  [slv_idx] ),
        .cbar_aw_reqst_data_i (wnode_aw_reqst_data             ),
        .cbar_aw_reqst_val_i  (wsnode_aw_reqst_val_i [slv_idx] ),
        .cbar_aw_reqst_rdy_o  (wsnode_aw_reqst_rdy_o [slv_idx] ),
        .cbar_resp_rdy_i      (wsnode_resp_rdy_i     [slv_idx] ),
        .cbar_resp_val_o      (wsnode_resp_val_o     [slv_idx] ),
        .cbar_resp_data_o     (wnode_resp_data       [slv_idx] )
    );
end
endgenerate

endmodule
