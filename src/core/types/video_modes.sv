
package video_modes_pkg;
    import clock_modes_pkg::*;
    
    localparam neg = 0;
    localparam pos = 1;

    typedef struct {
        // Horizontal
        int h_resolution;
        int h_front_porch;
        int h_sync;
        int h_back_porch;
        bit h_sync_pol;

        // Vertical
        int v_resolution;
        int v_front_porch;
        int v_sync;
        int v_back_porch;
        bit v_sync_pol;

        // Clock config
        clock_config_t clock_config;
    } video_mode_t;

    // Values are fetched from https://projectf.io/posts/video-timings-vga-720p-1080p/
    // NOTE: tools/calc_display_clk_config.py is used to generate clock config.

    // TESTED
    // UNTESTED
    localparam video_mode_t VMODE_640x480p60 = '{640, 16, 96, 48, neg, 480, 10, 2, 33, neg, clock_modes_pkg::CLK_100_25_175_MHZ};
    localparam video_mode_t VMODE_800x600p60 = '{800, 40, 128, 88, pos, 600, 1, 4, 23, pos, clock_modes_pkg::CLK_100_10_MHZ};
endpackage
