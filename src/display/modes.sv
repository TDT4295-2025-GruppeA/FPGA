package video_mode_pkg;
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
        real master_mul; // (2.000 - 64.000, step 0.125)
        int master_div; // (1 - 106)
        real clk_div_f; // (1.000 - 128.000)
    } video_mode_t;

    // Values are fetched from https://projectf.io/posts/video-timings-vga-720p-1080p/
    // NOTE: tools/calc_display_clk_config.py is used to generate clock config.

    // TESTED
    // UNTESTED
    localparam video_mode_t VMODE_640x480p60 = {640, 16, 96, 48, neg, 480, 10, 2, 33, neg, 9.0, 1, 35.75};
    localparam video_mode_t VMODE_800x600p60 = {800, 40, 128, 88, pos, 600, 1, 4, 23, pos, 6.0, 1, 15.0};
endpackage
