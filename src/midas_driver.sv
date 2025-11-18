module MidasDriver (
    input  logic       clk_pix,
    input  logic       rstn,

    output logic       disp_en,

    // TFT signals
    output logic       hsync,
    output logic       vsync,
    output logic       de,
    output logic       dclk,
    output logic [4:0] r,
    output logic [5:0] g,
    output logic [4:0] b
);
    localparam int WAIT_CYCLES = 500_000;     // 10 ms
    logic [$clog2(WAIT_CYCLES)-1:0] wait_counter = 0;

    // Default control values
    assign disp_en = (wait_counter >= WAIT_CYCLES) ? 1'b1 : 1'b0;

    // Power-up FSM
    always_ff @(posedge clk_pix or negedge rstn) begin
        if (!rstn) begin
            wait_counter <= 0;
        end else begin
            if (wait_counter < WAIT_CYCLES) begin
                wait_counter <= wait_counter + 1;
            end
        end
    end

    // ------------------------------------------------------------
    // 800×480 timing (unchanged minimal version)
    // ------------------------------------------------------------
    localparam int H_ACTIVE = 800;
    localparam int H_FP     = 40;
    localparam int H_SYNC   = 128;
    localparam int H_BP     = 88;
    localparam int H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;

    localparam int V_ACTIVE = 480;
    localparam int V_FP     = 10;
    localparam int V_SYNC   = 2;
    localparam int V_BP     = 33;
    localparam int V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;

    logic [$clog2(H_TOTAL)-1:0] hcnt = 0;
    logic [$clog2(V_TOTAL)-1:0] vcnt = 0;

    always_ff @(posedge clk_pix or negedge rstn) begin
        if (!rstn) begin
            hcnt <= 0;
            vcnt <= 0;
        end else begin
            if (hcnt == H_TOTAL-1) begin
                hcnt <= 0;
                vcnt <= (vcnt == V_TOTAL-1) ? 0 : vcnt + 1;
            end else begin
                hcnt <= hcnt + 1;
            end
        end
    end

    assign hsync = ~((hcnt >= H_ACTIVE + H_FP) &&
                     (hcnt <  H_ACTIVE + H_FP + H_SYNC));

    assign vsync = ~((vcnt >= V_ACTIVE + V_FP) &&
                     (vcnt <  V_ACTIVE + V_FP + V_SYNC));

    assign de = (hcnt < H_ACTIVE) && (vcnt < V_ACTIVE);

    // Color in different sectors.
    always_comb begin
        // Pink color when data enable is active
        if (hcnt < H_ACTIVE / 2) begin
            if (vcnt < V_ACTIVE / 2) begin
                // RED
                r = 5'h1F;
                g = 6'h00;
                b = 5'h00;
            end else begin
                // GREEN
                r = 5'h00;
                g = 6'h3F;
                b = 5'h00;
            end
        end else begin
            if (vcnt < V_ACTIVE / 2) begin
                // BLUE
                r = 5'h00;
                g = 6'h00;
                b = 5'h1F;
            end else begin
                if (vcnt[0] == 1'b1) begin
                    // WHITE
                    r = 5'h1F;
                    g = 6'h3F;
                    b = 5'h1F;
                end else begin
                    // BLACK
                    r = 5'h00;
                    g = 6'h00;
                    b = 5'h00;
                end
            end
        end
    end

    assign dclk = clk_pix;

endmodule
