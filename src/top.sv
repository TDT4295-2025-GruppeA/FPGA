`timescale 1ns / 1ps

module Top (
    input  wire logic clk_100m,     // 100 MHz clock
    input  wire logic btn_rst_n,    // reset button
    output      logic vga_hsync,    // VGA horizontal sync
    output      logic vga_vsync,    // VGA vertical sync
    output      logic [3:0] vga_r,  // 4-bit VGA red
    output      logic [3:0] vga_g,  // 4-bit VGA green
    output      logic [3:0] vga_b   // 4-bit VGA blue
    );

    // generate pixel clock
    logic clk_pix;
    logic clk_pix_locked;
    clock_480p clock_pix_inst (
       .clk_100m,
       .rst(btn_rst_n),
       .clk_pix,
       .clk_pix_5x(),  // not used for VGA output
       .clk_pix_locked
    );

    // display sync signals and coordinates
    localparam CORDW = 16;  // screen coordinate width in bits
    logic [CORDW-1:0] sx, sy;
    logic hsync, vsync, de;
    simple_480p display_inst (
        .clk_pix,
        .rst_pix(!clk_pix_locked),  // wait for clock lock
        .sx,
        .sy,
        .hsync,
        .vsync,
        .de
    );

    // logic [31:0] counter = 32'h0;
    // logic [15:0] pos = 16'h0;
        
    // always_ff @(posedge clk_pix) begin
    //     if (counter < 25000000) begin
    //         counter += 1;
    //     end else begin
    //         counter = 0;
            
    //         if (pos < 255) begin
    //             pos += 1;
    //         end else begin
    //             pos = 0;
    //         end
    //     end
    // end

    // // define a square with screen coordinates
    // logic square;
    // always_comb begin
    //     square = (sx > (220 + pos) && sx < (420 + pos)) && (sy > (sx-pos) && sy < 340);
    // end

    // paint colour: white inside square, blue outside
    logic [3:0] paint_r, paint_g, paint_b;
    always_comb begin
        paint_r =   sx; // (square) ? 4'hF : 4'h0;
        paint_g =   sy; // (square) ? 4'hF : 4'h0;
        paint_b = 4'hF; // (square) ? 4'hF : 4'h0;
    end

    // display colour: paint colour but black in blanking interval
    logic [3:0] display_r, display_g, display_b;
    always_comb begin
        display_r = (de) ? paint_r : 4'h0;
        display_g = (de) ? paint_g : 4'h0;
        display_b = (de) ? paint_b : 4'h0;
    end

    // VGA Pmod output
    always_ff @(posedge clk_pix) begin
        vga_hsync <= hsync;
        vga_vsync <= vsync;
        vga_r <= display_r;
        vga_g <= display_g;
        vga_b <= display_b;
    end
endmodule