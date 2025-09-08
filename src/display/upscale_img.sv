// upscale.sv

package upscale_img_pkg;
    import video_mode_pkg::*;

    // Function to calculate the upscaled buffer address
    function automatic int get_upscaled_address(
        input int display_x,
        input int display_y,
        input int buffer_width,
        input int buffer_height,
        input video_mode_t video_mode
    );
        int up_scale_factor;

        // Determine the upscaling factor
        if ((buffer_width * 4 == video_mode.h_resolution) &&
            (buffer_height * 4 == video_mode.v_resolution)) begin
            up_scale_factor = 4;
        end else if ((buffer_width * 2 == video_mode.h_resolution) &&
                     (buffer_height * 2 == video_mode.v_resolution)) begin
            up_scale_factor = 2;
        end else begin
            up_scale_factor = 1;
        end

        // Calculate the address based on the factor
        case (up_scale_factor)
            4: return ((display_y >> 2) * buffer_width) + (display_x >> 2);
            2: return ((display_y >> 1) * buffer_width) + (display_x >> 1);
            default: return (display_y * buffer_width) + display_x;
        endcase
    endfunction
endpackage