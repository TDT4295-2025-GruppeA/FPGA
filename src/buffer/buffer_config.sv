package buffer_config_pkg;

    typedef struct {
        int width;
        int height;
        int data_width;
        int addr_width;
    } buffer_config_t;

    localparam buffer_config_t BUFFER_160x120x12 = '{
        width: 160,
        height: 120,
        data_width: 12,
        addr_width: $clog2(160 * 120)
    };

    localparam buffer_config_t BUFFER_320x240x12 = '{
        width: 320,
        height: 240,
        data_width: 12,
        addr_width: $clog2(320 * 240)
    };

    localparam buffer_config_t BUFFER_640x480x12 = '{
        width: 640,
        height: 480,
        data_width: 12,
        addr_width: $clog2(640 * 480)
    };

endpackage