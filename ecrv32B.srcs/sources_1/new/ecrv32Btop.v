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
clk_wiz_0 sysclockgen(.clk_in1(CLK12MHZ), .reset(reset), .locked(clocklocked), .sysclock200(sysclock200) );
wire sys_rst = reset | ~clocklocked; // DO NOT use for MIG or driver

// DDR3
reg [27:0] app_addr = 28'd0;
reg [2:0] app_cmd = 3'd001;
reg app_en = 0;
reg [63:0] last_read_data = 64'h0000000000000000;
reg [63:0] app_wdf_data = 64'h0000000000000000;
reg app_wdf_end = 1;
reg app_wdf_wren = 0;
reg app_sr_req = 0;
reg app_ref_req = 0;
reg app_zq_req = 0;
reg [7:0] app_wdf_mask = 8'h00;
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

// Driver
reg [1:0] memstate = 2'b00;
always @(posedge(ui_clk)) begin
	if (ui_clk_sync_rst) begin
		app_addr <= 28'd0;
		app_cmd <= 3'd001; // 001:READ 000:WRITE 
		app_wdf_data <= 64'h0000000000000000;
		last_read_data <= 64'h0000000000000000;
		app_wdf_end <= 1'b1;
		app_wdf_wren <= 1'b0;
		app_sr_req <= 1'b0;
		app_ref_req <= 1'b0; // Refresh request
		app_zq_req <= 1'b0;
		app_wdf_mask <= 8'h00;
		app_en <= 1'b0;
		memstate <= 2'b00; // IDLE
		//initialclock <= 1'b1;
	end else begin
		if (init_calib_complete) begin
			// https://numato.com/kb/simple-ddr3-interfacing-on-skoll-using-xilinx-mig-7/?_ga=2.42867877.1012392398.1617151619-950527600.1616094746
			if (memstate == 2'b00) begin // WRITE
				if (app_rdy & app_wdf_rdy) begin
					app_en <= 1'b1;
					app_wdf_wren <= 1'b1;
					app_addr <= 0;
					app_cmd <= 3'b000;
					app_wdf_data <= 64'hCAFEBABEDEADBEEF;
					memstate <= 2'b01; // ENDWRITE
				end
			end
			if (memstate == 2'b01) begin // ENDWRITE
				if (app_rdy & app_en) begin
					app_en <= 1'b0;
				end
				if (app_wdf_rdy & app_wdf_wren) begin
					app_wdf_wren <= 1'b0;
				end
				if (~app_en & ~app_wdf_wren) begin
					memstate <= 2'b10; // READ
				end
			end
			/*if (memstate == 2'b10) begin // READ
				app_en <= 1'b1;
				app_addr <= 0;
				app_cmd <= 3'b001;
				memstate <= 2'b11; // ENDREAD
			end
			if (memstate == 2'b11) begin // ENDREAD
				if (app_rdy & app_en) begin
          			app_en <= 0;
        		end
        		if (app_rd_data_valid) begin
					last_read_data <= app_rd_data;
          			state <= ???;
        		end
			end*/
		end
	end
end

// DDR3 reset logic
 reg [9:0] negresetcountdown = 1023;
 always @ (posedge sysclock200) begin
   if (negresetcountdown) begin
     negresetcountdown <= negresetcountdown - 1 ;
   end
 end
 wire ddrresetn = (negresetcountdown == 0);

// DDR3 Controller
mig_7series_0 DDR3Controller (
	.ddr3_addr				(ddr3_addr), // These are the physical wires to the DDR3 chip
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

	.app_addr				(app_addr),            // 28 bit memory address
	.app_cmd				(app_cmd),             // 001 for read, 000 for write
	.app_en					(app_en),              // Strobe high to send command, retry command until app_rdy is high
	.app_wdf_data			(app_wdf_data),        // Write data
	.app_wdf_end			(app_wdf_end),         // Mark end of write package
	.app_wdf_mask			(app_wdf_mask),        // Write byte select
	.app_wdf_wren			(app_wdf_wren),        // Strobe high for wdf_data
	.app_sr_req				(app_sr_req),          // Reserved, must be zero
	.app_ref_req			(app_ref_req),         // Refresh request when high
	.app_zq_req				(app_zq_req),          // ZQ calibration request when high

	.app_rd_data			(app_rd_data),         // Read data
	.app_rd_data_end		(app_rd_data_end),     // Marks last cycle of read data
	.app_rd_data_valid		(app_rd_data_valid),   // Read data available
	.app_rdy				(app_rdy),             // UI ready to accept commands (can't make it go high in simulation)
	.app_wdf_rdy			(app_wdf_rdy),         // Write fifo is ready for more data
	.app_sr_active			(app_sr_active),       // Reserved, don't touch
	.app_ref_ack			(app_ref_ack),         // Refresh request acknowledge
	.app_zq_ack				(app_zq_ack),          // Calibration request acknowledge
	.ui_clk					(ui_clk),              // Must be 1/4th of the DRAM clock (use this in driver instead of system clock)
	.ui_clk_sync_rst		(ui_clk_sync_rst),     // Reset out post-init of this device (use this in driver instead of system reset)
	.init_calib_complete	(init_calib_complete), // Calibration done signal
	
	.device_temp			(device_temp),         // Doesn't work in simulation

	.sys_clk_i				(CLK100MHZ),           // Memory clock - has to be raw input from FPGA pin (100Mhz as set up in MIG)
	.clk_ref_i				(sysclock200),         // Reference clock (200MHz)
	.sys_rst				(ddrresetn) );         // Active low reset

// If you successfully wrote to memory, LEDs should be (from left to right): OFF(sys reset) OFF(unused) ON(write ok) ON(calibrated)
assign led = {sys_rst, 1'b0, memstate == 2'b10 ? 1'b1:1'b0, init_calib_complete}; 

endmodule
