package clock_modes_pkg;
    import fixed_pkg::*;
    
    // We put the include here because typedef's are package-local
    // apparently

    // The reason we use fixed is because verilator complains when reals
    // are used in structs, because verilator does not support unpacked
    // structs (and reals do not have bitwidth).
    // our fixed-values are really just integers so therefore they work.

    typedef struct {
        fixed clk_input_period; // period of input clock
        fixed master_mul; // Master multiplier (float 2.000 - 64.000) (step 0.125)
        int master_div; // Master divisor (uint 1 - 106)
        fixed clk_div_f; // Divisor (clock 0) (float 1.000 - 128.000)
    } clock_config_t;

    localparam clock_config_t CLK_100_100_MHZ    = '{rtof(10.0), rtof(6.0), 1, rtof(6.0)};
    localparam clock_config_t CLK_100_50_MHZ     = '{rtof(10.0), rtof(6.0), 1, rtof(12.0)};
    localparam clock_config_t CLK_100_40_MHZ     = '{rtof(10.0), rtof(6.0), 1, 15};
    localparam clock_config_t CLK_100_25_175_MHZ = '{rtof(10.0), rtof(9.0), 1, rtof(35.75)};
endpackage