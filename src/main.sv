import video_mode_pkg::*;

module Top (
    input [2:0] btn,
    input [3:0] sw,
    output [3:0] led,

    input logic clk_ext, // 100MHz for now
    input logic reset,

    // DDR3 interface
    // input logic [13:0] ddr3_addr,
    // input logic [2:0] ddr3_ba,
    // input logic ddr3_cas_n,
    // input logic [0:0] ddr3_ck_n,
    // input logic [0:0] ddr3_ck_p,
    // input logic [0:0] ddr3_cke,
    // input logic ddr3_ras_n,
    // input logic ddr3_reset_n,
    // input logic ddr3_we_n,
    // input logic [15:0] ddr3_dq,
    // input logic [1:0] ddr3_dqs_n,
    // input logic [1:0] ddr3_dqs_p,
    // input logic [0:0] ddr3_cs_n,
    // input logic [1:0] ddr3_dm,
    // input logic [0:0] ddr3_odt,

    // VGA control
    output logic vga_hsync,
    output logic vga_vsync,
    output logic[3:0] vga_red,
    output logic[3:0] vga_green,
    output logic[3:0] vga_blue
);
    logic rstn;

    assign led = btn;
    assign rstn = ~reset;

    // Enter clock into fpga fabric
    logic clk_100m;
    BUFG clock_buf(
        .I(clk_ext),
        .O(clk_100m)
    );

    mig_ddr3 u_mig_ddr3 (
        // Application interface ports
        .app_addr                       (app_addr),             // input [27:0]     app_addr
        .app_cmd                        (app_cmd),              // input [2:0]      app_cmd
        .app_en                         (app_en),               // input            app_en
        .app_wdf_data                   (app_wdf_data),         // input [127:0]    app_wdf_data
        .app_wdf_end                    (app_wdf_end),          // input            app_wdf_end
        .app_wdf_wren                   (app_wdf_wren),         // input            app_wdf_wren
        .app_rd_data                    (app_rd_data),          // output [127:0]   app_rd_data
        .app_rd_data_end                (app_rd_data_end),      // output           app_rd_data_end
        .app_rd_data_valid              (app_rd_data_valid),    // output           app_rd_data_valid
        .app_rdy                        (app_rdy),              // output           app_rdy
        .app_wdf_rdy                    (app_wdf_rdy),          // output           app_wdf_rdy
        .app_sr_req                     (app_sr_req),           // input            app_sr_req
        .app_ref_req                    (app_ref_req),          // input            app_ref_req
        .app_zq_req                     (app_zq_req),           // input            app_zq_req
        .app_sr_active                  (app_sr_active),        // output           app_sr_active
        .app_ref_ack                    (app_ref_ack),          // output           app_ref_ack
        .app_zq_ack                     (app_zq_ack),           // output           app_zq_ack
        .ui_clk                         (ui_clk),               // output           ui_clk
        .ui_clk_sync_rst                (ui_clk_sync_rst),      // output           ui_clk_sync_rst
        .app_wdf_mask                   (app_wdf_mask),         // input [15:0]     app_wdf_mask
        // System Clock Ports
        .sys_clk_i                      (clk_ext),
        // Reference Clock Ports
        .clk_ref_i                      (clk_est),
        .sys_rst                        (rstn) // input sys_rst
    );

    Display #(
        .VIDEO_MODE(VMODE_640x480p60)
    ) display (
        .clk_100m(clk_100m),
        .rstn(rstn),

        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue)
    );

endmodule


        // Memory interface ports
        // .ddr3_addr                      (ddr3_addr),  // output [13:0]       ddr3_addr
        // .ddr3_ba                        (ddr3_ba),  // output [2:0]      ddr3_ba
        // .ddr3_cas_n                     (ddr3_cas_n),  // output         ddr3_cas_n
        // .ddr3_ck_n                      (ddr3_ck_n),  // output [0:0]        ddr3_ck_n
        // .ddr3_ck_p                      (ddr3_ck_p),  // output [0:0]        ddr3_ck_p
        // .ddr3_cke                       (ddr3_cke),  // output [0:0]     ddr3_cke
        // .ddr3_ras_n                     (ddr3_ras_n),  // output         ddr3_ras_n
        // .ddr3_reset_n                   (ddr3_reset_n),  // output           ddr3_reset_n
        // .ddr3_we_n                      (ddr3_we_n),  // output          ddr3_we_n
        // .ddr3_dq                        (ddr3_dq),  // inout [15:0]      ddr3_dq
        // .ddr3_dqs_n                     (ddr3_dqs_n),  // inout [1:0]        ddr3_dqs_n
        // .ddr3_dqs_p                     (ddr3_dqs_p),  // inout [1:0]        ddr3_dqs_p
        // .init_calib_complete            (init_calib_complete),  // output            init_calib_complete
        // .ddr3_cs_n                      (ddr3_cs_n),  // output [0:0]        ddr3_cs_n
        // .ddr3_dm                        (ddr3_dm),  // output [1:0]      ddr3_dm
        // .ddr3_odt                       (ddr3_odt),  // output [0:0]     ddr3_odt