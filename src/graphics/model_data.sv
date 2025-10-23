package model_data_pkg;
    import types_pkg::*;
    import fixed_pkg::*;

    localparam int TRIANGLE_COUNT = 3;

    localparam triangle_t triangles[TRIANGLE_COUNT] = '{
        '{
            v0: '{
                position: '{ x: rtof(-0.3), y: rtof(-0.3), z: rtof(0.0) },
                color: 'hF00
            },
            v1: '{
                position: '{ x: rtof(0.2), y: rtof(-0.4), z: rtof(0.0) },
                color: 'h0F0
            },
            v2: '{
                position: '{ x: rtof(0.0), y: rtof(0.0), z: rtof(1.0) },
                color: 'hFFF
            }
        },
        '{
            v0: '{
                position: '{ x: rtof(0.0), y: rtof(0.0), z: rtof(1.0) },
                color: 'hFFF
            },
            v1: '{
                position: '{ x: rtof(0.1), y: rtof(0.4), z: rtof(0.0) },
                color: 'h00F
            },
            v2: '{
                position: '{ x: rtof(-0.3), y: rtof(-0.3), z: rtof(0.0) },
                color: 'hF00
            }
        },
        '{
            v0: '{
                position: '{ x: rtof(0.0), y: rtof(0.0), z: rtof(1.0) },
                color: 'hFFF
            },
            v1: '{
                position: '{ x: rtof(0.2), y: rtof(-0.4), z: rtof(0.0) },
                color: 'h0F0
            },
            v2: '{
                position: '{ x: rtof(0.1), y: rtof(0.4), z: rtof(0.0) },
                color: 'h00F
            }
        }
    };
endpackage
