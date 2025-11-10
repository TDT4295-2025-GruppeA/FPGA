package buffer_config_pkg;
    typedef struct {
        int width;
        int height;
        int size;
        int addr_width;
    } buffer_config_t;

    localparam buffer_config_t BUFFER_160x120x12 = '{
        width: 160,
        height: 120,
        size: 160 * 120,
        addr_width: $clog2(160 * 120)
    };

    localparam buffer_config_t BUFFER_320x240x12 = '{
        width: 320,
        height: 240,
        size: 320 * 240,
        addr_width: $clog2(320 * 240)
    };

    localparam buffer_config_t BUFFER_640x480x12 = '{
        width: 640,
        height: 480,
        size: 640 * 480,
        addr_width: $clog2(640 * 480)
    };
endpackage