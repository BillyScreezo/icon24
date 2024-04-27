// —————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
// ———————————————————————————————————————————————————————————————————————————————————— liteic_icon_top
// —————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————
module liteic_icon_top
	import liteic_pkg::IC_NUM_MASTER_SLOTS						;
	import liteic_pkg::IC_NUM_SLAVE_SLOTS						;
	import liteic_pkg::AXI_ADDR_WIDTH							;
	import liteic_pkg::AXI_DATA_WIDTH							;
	import liteic_pkg::AXI_RESP_WIDTH							;
	import liteic_pkg::IC_ARADDR_WIDTH							;
	import liteic_pkg::IC_RDATA_WIDTH							;
	import liteic_pkg::IC_AWADDR_WIDTH							;
	import liteic_pkg::IC_WDATA_WIDTH							;
	import liteic_pkg::IC_BRESP_WIDTH							;
	import liteic_pkg::IC_RD_CONNECTIVITY						;
	import liteic_pkg::IC_WR_CONNECTIVITY						;
	import liteic_pkg::IC_SLAVE_REGION_BASE						;
	import liteic_pkg::IC_SLAVE_REGION_SIZE						;
(
	input logic					clk_i							,
	input logic					rstn_i							,
	axi_lite_if.sp				mst_axil[IC_NUM_MASTER_SLOTS]	,
	axi_lite_if.mp				slv_axil[IC_NUM_SLAVE_SLOTS]
);
// —————————————————————————————————————————————————————————————
// ————————————— internal
// —————————————————————————————————————————————————————————————
wire clk					  =	clk_i							;
wire rst					  =	rstn_i							;
axi_lite_if #(32, 32, 2)		m[20]						  ();
axi_lite_if #(32, 32, 2)		s[12]						  ();
// —————————————————————————————————————————————————————————————
// ————————————— mnr
// —————————————————————————————————————————————————————————————
struct															{
// additional
	logic	[11:0]				ar_ready						;
	logic	[19:0]				ar_valid						;
	logic	[19:0]				r_ready							;
	logic	[11:0]				r_valid							;
	logic	[31:0]				ar_addr					  [19:0];
	logic	[3:0]				ar_qos					  [19:0];
	logic	[31:0]				r_data					  [11:0];
	logic	[1:0]				r_resp					  [11:0];
// main
	logic	[4:0]				msel 							;
	logic	[4:0]				msel_r 							;
	logic	[3:0]				ssel							;
	logic	[3:0]				ssel_r							;
	logic	[31:0]				addr 							;
	logic	[31:0]				data 							;
	logic	[1:0]				resp 							;
	logic						busy							;
	logic						busy_r 							;
} shared_read_0 												;

for (genvar mi = 0; mi < 20; mi++) begin : shared_read_0_ar_valid$
	assign shared_read_0.ar_addr[mi] = m[mi].ar_addr			;
	assign shared_read_0.ar_valid[mi] = m[mi].ar_valid 			;
	assign shared_read_0.r_ready[mi] = m[mi].r_ready 			;
	assign shared_read_0.ar_qos[mi] = m[mi].ar_qos				;
end
for (genvar si = 0; si < 12; si++) begin : shared_read_0_ar_valid$$
	assign shared_read_0.r_valid[si] = s[si].r_valid 			;
	assign shared_read_0.ar_ready[si] = s[si].ar_ready 			;
	assign shared_read_0.r_data[si] = s[si].r_data				;
	assign shared_read_0.r_resp[si] = s[si].r_resp				;
end

always @(*) begin : shared_read_0_rqst_sel
	shared_read_0.msel = '0										;
	shared_read_0.ssel = '0										;
	shared_read_0.busy = '0										;
	for (int i = 0; i < 20; i = i + 1) begin : shared_red_0_rqst_gen
		if (shared_read_0.ar_valid[i]) begin
			shared_read_0.msel=	i								;
			shared_read_0.ssel= shared_read_0.ar_addr[i][23:20]	;
			shared_read_0.busy = '1								;
			disable shared_read_0_rqst_sel						;
		end
	end
end

enum logic [1:0] {
	R0_IDLE														,
	R0_AR														,
	R0_R
} shared_read_0_state											;

always @(posedge clk or negedge rst) begin
	if (!rst) begin
		shared_read_0.ssel_r 		<= '0						;
		shared_read_0.msel_r 		<= '0 						;
		shared_read_0.busy_r	 	<= '0 						;
		shared_read_0_state			<= R0_IDLE					;
	end else begin
		case (shared_read_0_state)
		R0_IDLE: begin
			if (shared_read_0.busy) begin
				shared_read_0.ssel_r 		<= shared_read_0.ssel;
				shared_read_0.msel_r 		<= shared_read_0.msel;
				shared_read_0.busy_r		<= '1;
				shared_read_0_state			<= R0_AR;
			end
		end
		R0_AR: begin
			if (shared_read_0.ar_valid[shared_read_0.msel_r] && shared_read_0.ar_ready[shared_read_0.ssel_r]) begin
				shared_read_0_state			<= R0_R;
			end
		end
		R0_R: begin
			if (shared_read_0.r_valid[shared_read_0.ssel_r] & shared_read_0.r_ready[shared_read_0.msel_r]) begin
				shared_read_0.busy_r	 	<= '0				;
				shared_read_0_state			<= R0_IDLE			;
				if (shared_read_0.busy) begin
					shared_read_0.ssel_r 	<= shared_read_0.ssel;
					shared_read_0.msel_r 	<= shared_read_0.msel;
					shared_read_0.busy_r	<= '1;
					shared_read_0_state		<= R0_AR;
				end
			end
		end
		endcase
	end
end

for (genvar mi = 0; mi < 20; mi++) begin : blabdflbdflgl
	assign m[mi].r_valid	  =	shared_read_0.busy_r && mi == shared_read_0.msel_r ? shared_read_0.r_valid[shared_read_0.ssel_r] : '0;
	assign m[mi].ar_ready	  =	shared_read_0.busy_r && mi == shared_read_0.msel_r ? shared_read_0.ar_ready[shared_read_0.ssel_r] : '0;
end

for (genvar si = 0; si < 12; si++) begin : sgfghghj
	assign s[si].ar_valid	  =	shared_read_0_state == R0_AR && si == shared_read_0.ssel_r ? shared_read_0.ar_valid[shared_read_0.msel_r] : '0;
	assign s[si].r_ready	  =	shared_read_0.busy_r && si == shared_read_0.ssel_r ? shared_read_0.r_ready[shared_read_0.msel_r] : '0;
end

assign shared_read_0.addr	  =	shared_read_0.ar_addr[shared_read_0.msel_r];
assign shared_read_0.data	  =	shared_read_0.r_data[shared_read_0.ssel_r];
assign shared_read_0.resp	  =	shared_read_0.r_resp[shared_read_0.ssel_r];	

assign s[00].ar_addr		  =	shared_read_0.addr				;
assign s[01].ar_addr		  =	shared_read_0.addr				;
assign s[02].ar_addr		  =	shared_read_0.addr				;
assign s[03].ar_addr		  =	shared_read_0.addr				;
assign s[04].ar_addr		  =	shared_read_0.addr				;
assign s[05].ar_addr		  =	shared_read_0.addr				;
assign s[06].ar_addr		  =	shared_read_0.addr				;
assign s[07].ar_addr		  =	shared_read_0.addr				;
assign s[08].ar_addr		  =	shared_read_0.addr				;
assign s[09].ar_addr		  =	shared_read_0.addr				;
assign s[10].ar_addr		  =	shared_read_0.addr				;
assign s[11].ar_addr		  =	shared_read_0.addr				;

assign m[00].r_data			  =	shared_read_0.data				;
assign m[01].r_data			  =	shared_read_0.data				;
assign m[02].r_data			  =	shared_read_0.data				;
assign m[03].r_data			  =	shared_read_0.data				;
assign m[04].r_data			  =	shared_read_0.data				;
assign m[05].r_data			  =	shared_read_0.data				;
assign m[06].r_data			  =	shared_read_0.data				;
assign m[07].r_data			  =	shared_read_0.data				;
assign m[08].r_data			  =	shared_read_0.data				;
assign m[09].r_data			  =	shared_read_0.data				;
assign m[10].r_data			  =	shared_read_0.data				;
assign m[11].r_data			  =	shared_read_0.data				;
assign m[12].r_data			  =	shared_read_0.data				;
assign m[13].r_data			  =	shared_read_0.data				;
assign m[14].r_data			  =	shared_read_0.data				;
assign m[15].r_data			  =	shared_read_0.data				;
assign m[16].r_data			  =	shared_read_0.data				;
assign m[17].r_data			  =	shared_read_0.data				;
assign m[18].r_data			  =	shared_read_0.data				;
assign m[19].r_data			  =	shared_read_0.data				;

assign m[00].r_resp			  =	shared_read_0.resp				;
assign m[01].r_resp			  =	shared_read_0.resp				;
assign m[02].r_resp			  =	shared_read_0.resp				;
assign m[03].r_resp			  =	shared_read_0.resp				;
assign m[04].r_resp			  =	shared_read_0.resp				;
assign m[05].r_resp			  =	shared_read_0.resp				;
assign m[06].r_resp			  =	shared_read_0.resp				;
assign m[07].r_resp			  =	shared_read_0.resp				;
assign m[08].r_resp			  =	shared_read_0.resp				;
assign m[09].r_resp			  =	shared_read_0.resp				;
assign m[10].r_resp			  =	shared_read_0.resp				;
assign m[11].r_resp			  =	shared_read_0.resp				;
assign m[12].r_resp			  =	shared_read_0.resp				;
assign m[13].r_resp			  =	shared_read_0.resp				;
assign m[14].r_resp			  =	shared_read_0.resp				;
assign m[15].r_resp			  =	shared_read_0.resp				;
assign m[16].r_resp			  =	shared_read_0.resp				;
assign m[17].r_resp			  =	shared_read_0.resp				;
assign m[18].r_resp			  =	shared_read_0.resp				;
assign m[19].r_resp			  =	shared_read_0.resp				;
// —————————————————————————————————————————————————————————————
// ————————————— mnw
// —————————————————————————————————————————————————————————————
struct															{
// additional
	logic	[11:0]				aw_ready						;
	logic	[19:0]				aw_valid						;
	logic	[11:0]				w_ready							;
	logic	[19:0]				w_valid							;
	logic	[19:0]				b_ready							;
	logic	[11:0]				b_valid							;
	logic	[31:0]				aw_addr					  [19:0];
	logic	[3:0]				aw_qos					  [19:0];
	logic	[31:0]				w_data					  [19:0];
	logic	[1:0]				b_resp					  [11:0];
	logic	[3:0]				w_strb					  [19:0];
// main
	logic	[4:0]				msel 							;
	logic	[4:0]				msel_r 							;
	logic	[3:0]				ssel							;
	logic	[3:0]				ssel_r							;
	logic	[31:0]				addr 							;
	logic	[31:0]				data 							;
	logic	[1:0]				resp 							;
	logic	[3:0]				strb							;
	logic						busy							;
	logic						busy_r 							;
} shared_write_0 												;

for (genvar mi = 0; mi < 20; mi++) begin : shared_write_0_ar_valid$
	assign shared_write_0.aw_addr[mi] = m[mi].aw_addr			;
	assign shared_write_0.aw_valid[mi] = m[mi].aw_valid 		;
	assign shared_write_0.aw_qos[mi] = m[mi].aw_qos				;
	assign shared_write_0.b_ready[mi] = m[mi].b_ready			;
	assign shared_write_0.w_valid[mi] = m[mi].w_valid 			;
	assign shared_write_0.w_strb[mi] = m[mi].w_strb 			;
	assign shared_write_0.w_data[mi] = m[mi].w_data				;
end
for (genvar si = 0; si < 12; si++) begin : shared_write_0_ar_valid$$
	assign shared_write_0.w_ready[si] = s[si].w_ready 			;
	assign shared_write_0.aw_ready[si] = s[si].aw_ready 		;
	assign shared_write_0.b_resp[si] = s[si].b_resp				;
	assign shared_write_0.b_valid[si] = s[si].b_valid			;
end

logic [19:0] msel_next_allowed									;
always @(*) begin : shared_write_0_rqst_sel
	shared_write_0.msel = '0									;
	shared_write_0.ssel = '0									;
	shared_write_0.busy = '0									;
	for (logic [4:0] i = 0; i < 20; i = i + 1) begin : shared_write_0_rqst_gen
		if (shared_write_0.aw_valid[i] && msel_next_allowed[i]) begin
			shared_write_0.msel=	i							;
			shared_write_0.ssel= shared_write_0.aw_addr[i][23:20];
			shared_write_0.busy = '1							;
			disable shared_write_0_rqst_sel						;
		end
	end
end

enum logic [1:0] {
	W0_IDLE														,
	W0_AW														,
	W0_W														,
	W0_B
} shared_write_0_state											;

always @(posedge clk or negedge rst) begin
	if (!rst) begin
		shared_write_0.ssel_r 		<= '0						;
		shared_write_0.msel_r 		<= '0 						;
		shared_write_0.busy_r	 	<= '0 						;
		shared_write_0_state		<= W0_IDLE					;
		msel_next_allowed			<= '1						;
	end else begin
		case (shared_write_0_state)
		W0_IDLE: begin
			if (shared_write_0.busy) begin
				shared_write_0.ssel_r 	<= shared_write_0.ssel;
				shared_write_0.msel_r 	<= shared_write_0.msel;
				shared_write_0.busy_r	<= '1;
				shared_write_0_state	<= W0_AW;
				for (int i = 0; i < 20; i = i + 1)
					msel_next_allowed[i] = shared_write_0.msel == 19 ? 1 : i > shared_write_0.msel ? 1 : 0;
			end
		end
		W0_AW: begin
			if (shared_write_0.aw_valid[shared_write_0.msel_r] && shared_write_0.aw_ready[shared_write_0.ssel_r]) begin
				shared_write_0_state	<= W0_W;
			end
		end
		W0_W: begin
			if (shared_write_0.w_valid[shared_write_0.msel_r] & shared_write_0.w_ready[shared_write_0.ssel_r]) begin
				shared_write_0_state	<= W0_B					;
			end
		end
		W0_B: begin
			if (shared_write_0.b_valid[shared_write_0.ssel_r] & shared_write_0.b_ready[shared_write_0.msel_r]) begin
				shared_write_0.busy_r 	<= '0					;
				shared_write_0_state	<= W0_IDLE				;
				if (shared_write_0.busy) begin
					shared_write_0.ssel_r 	<= shared_write_0.ssel;
					shared_write_0.msel_r 	<= shared_write_0.msel;
					shared_write_0.busy_r	<= '1;
					shared_write_0_state	<= W0_AW;
					for (int i = 0; i < 20; i = i + 1)
						msel_next_allowed[i] = shared_write_0.msel == 19 ? 1 : i > shared_write_0.msel ? 1 : 0;
				end
			end
		end
		endcase
	end
end

for (genvar mi = 0; mi < 20; mi++) begin : blabdflbdflglfgh
	assign m[mi].aw_ready	  =	shared_write_0.busy_r && mi == shared_write_0.msel_r ? shared_write_0.aw_ready[shared_write_0.ssel_r] : '0;
	assign m[mi].w_ready	  =	shared_write_0.busy_r && mi == shared_write_0.msel_r ? shared_write_0.w_ready[shared_write_0.ssel_r] : '0;
	assign m[mi].b_valid	  =	shared_write_0.busy_r && mi == shared_write_0.msel_r ? shared_write_0.b_valid[shared_write_0.ssel_r] : '0;
end

for (genvar si = 0; si < 12; si++) begin : sgfghghjdfgh
	assign s[si].aw_valid	  =	shared_write_0_state == W0_AW && si == shared_write_0.ssel_r ? shared_write_0.aw_valid[shared_write_0.msel_r] : '0;
	assign s[si].w_valid	  =	shared_write_0_state == W0_W  && si == shared_write_0.ssel_r ? shared_write_0.w_valid[shared_write_0.msel_r] : '0;
	assign s[si].b_ready	  =	shared_write_0.busy_r && si == shared_write_0.ssel_r ? shared_write_0.b_ready[shared_write_0.msel_r] : '0;
end

assign shared_write_0.addr	  =	shared_write_0.aw_addr[shared_write_0.msel_r];
assign shared_write_0.strb	  =	shared_write_0.w_strb[shared_write_0.msel_r];
assign shared_write_0.data	  =	shared_write_0.w_data[shared_write_0.msel_r];
assign shared_write_0.resp	  =	shared_write_0.b_resp[shared_write_0.ssel_r];

assign s[00].w_data			  =	shared_write_0.data				;
assign s[01].w_data			  =	shared_write_0.data				;
assign s[02].w_data			  =	shared_write_0.data				;
assign s[03].w_data			  =	shared_write_0.data				;
assign s[04].w_data			  =	shared_write_0.data				;
assign s[05].w_data			  =	shared_write_0.data				;
assign s[06].w_data			  =	shared_write_0.data				;
assign s[07].w_data			  =	shared_write_0.data				;
assign s[08].w_data			  =	shared_write_0.data				;
assign s[09].w_data			  =	shared_write_0.data				;
assign s[10].w_data			  =	shared_write_0.data				;
assign s[11].w_data			  =	shared_write_0.data				;

assign s[00].aw_addr		  =	shared_write_0.addr				;
assign s[01].aw_addr		  =	shared_write_0.addr				;
assign s[02].aw_addr		  =	shared_write_0.addr				;
assign s[03].aw_addr		  =	shared_write_0.addr				;
assign s[04].aw_addr		  =	shared_write_0.addr				;
assign s[05].aw_addr		  =	shared_write_0.addr				;
assign s[06].aw_addr		  =	shared_write_0.addr				;
assign s[07].aw_addr		  =	shared_write_0.addr				;
assign s[08].aw_addr		  =	shared_write_0.addr				;
assign s[09].aw_addr		  =	shared_write_0.addr				;
assign s[10].aw_addr		  =	shared_write_0.addr				;
assign s[11].aw_addr		  =	shared_write_0.addr				;

assign s[00].w_strb			  =	shared_write_0.strb				;
assign s[01].w_strb			  =	shared_write_0.strb				;
assign s[02].w_strb			  =	shared_write_0.strb				;
assign s[03].w_strb			  =	shared_write_0.strb				;
assign s[04].w_strb			  =	shared_write_0.strb				;
assign s[05].w_strb			  =	shared_write_0.strb				;
assign s[06].w_strb			  =	shared_write_0.strb				;
assign s[07].w_strb			  =	shared_write_0.strb				;
assign s[08].w_strb			  =	shared_write_0.strb				;
assign s[09].w_strb			  =	shared_write_0.strb				;
assign s[10].w_strb			  =	shared_write_0.strb				;
assign s[11].w_strb			  =	shared_write_0.strb				;

assign m[00].b_resp			  =	shared_write_0.resp				;
assign m[01].b_resp			  =	shared_write_0.resp				;
assign m[02].b_resp			  =	shared_write_0.resp				;
assign m[03].b_resp			  =	shared_write_0.resp				;
assign m[04].b_resp			  =	shared_write_0.resp				;
assign m[05].b_resp			  =	shared_write_0.resp				;
assign m[06].b_resp			  =	shared_write_0.resp				;
assign m[07].b_resp			  =	shared_write_0.resp				;
assign m[08].b_resp			  =	shared_write_0.resp				;
assign m[09].b_resp			  =	shared_write_0.resp				;
assign m[10].b_resp			  =	shared_write_0.resp				;
assign m[11].b_resp			  =	shared_write_0.resp				;
assign m[12].b_resp			  =	shared_write_0.resp				;
assign m[13].b_resp			  =	shared_write_0.resp				;
assign m[14].b_resp			  =	shared_write_0.resp				;
assign m[15].b_resp			  =	shared_write_0.resp				;
assign m[16].b_resp			  =	shared_write_0.resp				;
assign m[17].b_resp			  =	shared_write_0.resp				;
assign m[18].b_resp			  =	shared_write_0.resp				;
assign m[19].b_resp			  =	shared_write_0.resp				;
// —————————————————————————————————————————————————————————————
// ————————————— inout
// —————————————————————————————————————————————————————————————
generate
	for(genvar mi = 0; mi < 20; mi++) begin
		assign m[mi].ar_addr  = mst_axil[mi].ar_addr  ;
		assign m[mi].ar_valid = mst_axil[mi].ar_valid ;
		assign m[mi].r_ready  = mst_axil[mi].r_ready  ;
		assign m[mi].aw_addr  = mst_axil[mi].aw_addr  ;
		assign m[mi].aw_valid = mst_axil[mi].aw_valid ;
		assign m[mi].w_data   = mst_axil[mi].w_data   ;
		assign m[mi].w_strb   = mst_axil[mi].w_strb   ;
		assign m[mi].w_valid  = mst_axil[mi].w_valid  ;
		assign m[mi].b_ready  = mst_axil[mi].b_ready  ;

		assign mst_axil[mi].ar_ready = m[mi].ar_ready ;
		assign mst_axil[mi].r_data   = m[mi].r_data   ;
		assign mst_axil[mi].r_resp   = m[mi].r_resp   ;
		assign mst_axil[mi].r_valid  = m[mi].r_valid  ;
		assign mst_axil[mi].aw_ready = m[mi].aw_ready ;
		assign mst_axil[mi].w_ready  = m[mi].w_ready  ;
		assign mst_axil[mi].b_resp   = m[mi].b_resp   ;
		assign mst_axil[mi].b_valid  = m[mi].b_valid  ;
	end
	for(genvar si = 0; si < 12; si++) begin
		assign slv_axil[si].ar_addr  = s[si].ar_addr  ;
		assign slv_axil[si].ar_valid = s[si].ar_valid ;
		assign slv_axil[si].r_ready  = s[si].r_ready  ;
		assign slv_axil[si].aw_addr  = s[si].aw_addr  ;
		assign slv_axil[si].aw_valid = s[si].aw_valid ;
		assign slv_axil[si].w_data   = s[si].w_data   ;
		assign slv_axil[si].w_strb   = s[si].w_strb   ;
		assign slv_axil[si].w_valid  = s[si].w_valid  ;
		assign slv_axil[si].b_ready  = s[si].b_ready  ;

		assign s[si].ar_ready = slv_axil[si].ar_ready ;
		assign s[si].r_data   = slv_axil[si].r_data   ;
		assign s[si].r_resp   = slv_axil[si].r_resp   ;
		assign s[si].r_valid  = slv_axil[si].r_valid  ;
		assign s[si].aw_ready = slv_axil[si].aw_ready ;
		assign s[si].w_ready  = slv_axil[si].w_ready  ;
		assign s[si].b_resp   = slv_axil[si].b_resp   ;
		assign s[si].b_valid  = slv_axil[si].b_valid  ;
	end
endgenerate
endmodule
