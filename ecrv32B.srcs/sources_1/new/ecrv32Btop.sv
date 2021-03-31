`timescale 1ns / 1ps

module ecrv32Btop(
	// Clocks and reset
	input wire CLK100MHZ,
	input wire CLK12MHZ,
	input wire reset,

	// DDR3 ports    
	output [13:0]   ddr3_addr,
	output [2:0]    ddr3_ba,
	output			ddr3_cas_n,
	output [0:0]	ddr3_ck_n,
	output [0:0]	ddr3_ck_p,
	output [0:0]	ddr3_cke,
	output			ddr3_ras_n,
	output			ddr3_reset_n,
	output			ddr3_we_n,
	inout [15:0]	ddr3_dq,
	inout [1:0]		ddr3_dqs_n,
	inout [1:0]		ddr3_dqs_p,
	output [0:0]	ddr3_cs_n,
	output [1:0]	ddr3_dm,
	output [0:0]	ddr3_odt,

	// Monochrome LED outputs
	output wire [3:0] led );

// CLOCKS
wire sysclock200, clocklocked;
clk_wiz_0 sysclockgen(.clk_in1(CLK100MHZ), .reset(reset), .locked(clocklocked), .sysclock200(sysclock200) );
wire sys_rst = reset | ~clocklocked;

// DDR3
reg [27:0] app_addr;
reg [2:0] app_cmd;
reg app_en;
reg [63:0] app_wdf_data;
reg app_wdf_end;
reg app_wdf_wren;
reg app_sr_req;
reg app_ref_req;
reg app_zq_req;
reg [7:0] app_wdf_mask;
wire [63:0] app_rd_data;
wire app_rd_data_end;
wire app_rd_data_valid;
wire app_rdy;
wire app_wdf_rdy;
wire app_sr_active;
wire app_ref_ack;
wire app_zq_ack;
wire ui_clk;
wire ui_clk_sync_rst;
wire init_calib_complete;
wire [11:0] device_temp;

always @(posedge(clock)) begin
	if (sys_reset) begin
		app_addr <= 28'd0;
		app_cmd <= 3'd0;
		app_en <= 1'b1;
		app_wdf_data <= 64'h0000000000000000;
		app_wdf_end <= 1'b0;
		app_wdf_wren <= 1'b0;
		app_sr_req <= 1'b0;
		app_ref_req <= 1'b0;
		app_zq_req <= 1'b0;
		app_wdf_mask <= 8'h00;
	end else begin
		app_addr <= app_addr + 28'd1; 
	end
end

mig_7series_0 DDR3Controller (
	.ddr3_addr				(ddr3_addr),
	.ddr3_ba				(ddr3_ba),
	.ddr3_cas_n				(ddr3_cas_n),
	.ddr3_ck_n				(ddr3_ck_n),
	.ddr3_ck_p				(ddr3_ck_p),
	.ddr3_cke				(ddr3_cke),
	.ddr3_ras_n				(ddr3_ras_n),
	.ddr3_reset_n			(ddr3_reset_n),
	.ddr3_we_n				(ddr3_we_n),
	.ddr3_dq				(ddr3_dq),
	.ddr3_dqs_n				(ddr3_dqs_n),
	.ddr3_dqs_p				(ddr3_dqs_p),
	.ddr3_cs_n				(ddr3_cs_n),
	.ddr3_dm				(ddr3_dm),
	.ddr3_odt				(ddr3_odt),
	.init_calib_complete	(init_calib_complete),

	.app_addr				(app_addr),
	.app_cmd				(app_cmd),
	.app_en					(app_en),
	.app_wdf_data			(app_wdf_data),
	.app_wdf_end			(app_wdf_end),
	.app_wdf_mask			(app_wdf_mask),
	.app_wdf_wren			(app_wdf_wren),
	.app_sr_req				(app_sr_req),
	.app_ref_req			(app_ref_req),
	.app_zq_req				(app_zq_req),

	.app_rd_data			(app_rd_data),
	.app_rd_data_end		(app_rd_data_end),
	.app_rd_data_valid		(app_rd_data_valid),
	.app_rdy				(app_rdy),
	.app_wdf_rdy			(app_wdf_rdy),
	.app_sr_active			(app_sr_active),
	.app_ref_ack			(app_ref_ack),
	.app_zq_ack				(app_zq_ack),
	.ui_clk					(ui_clk),
	.ui_clk_sync_rst		(ui_clk_sync_rst),
	
	.device_temp			(device_temp),

	.sys_clk_i				(sysclock200),
	.clk_ref_i				(CLK100MHZ),
	.sys_rst				(sys_rst) );

assign led = {sys_rst, 1'b0, 1'b0, init_calib_complete}; 

endmodule
