`default_nettype none

module tt_um_algofoogle_vga_fun_wrapper (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

wire [7:0] project_uo_out;
wire [7:0] project_uio_out;
wire [7:0] project_uio_oe;
wire [7:0] r;
wire [7:0] g;
wire [7:0] b;

reg [7:0] project_ui_in;
reg project_rst_n;
wire rst_vga_mask = rst_n;

tt_um_algofoogle_tt08_vga_fun i_project(
    .ui_in(project_ui_in),
    .uo_out(project_uo_out),
    .uio_in({rst_vga_mask, 7'b0}),
    .uio_out(project_uio_out),
    .uio_oe(project_uio_oe),
    .ena(1'b1),
    .clk(clk),
    .rst_n(project_rst_n),
    .r,
    .g,
    .b
);

reg [31:0] counter;
always @(posedge clk) begin
    if(!rst_n) begin
        counter <= 0;
    end else begin
        counter <= counter + 1;
    end
end

reg [2:0] depth;
always @(posedge clk) begin
    if(ui_in[7]) begin
        depth <= ui_in[6:4];
        project_ui_in[7:4] <= ui_in[3:0];
    end else begin
        depth <= counter[26:24];
        case(counter[29:27])
            0: project_ui_in[7:4] <= 4'b0001;
            1: project_ui_in[7:4] <= 4'b0100;
            2: project_ui_in[7:4] <= 4'b0011;
            3: project_ui_in[7:4] <= 4'b0101;
            4: project_ui_in[7:4] <= 4'b0010;
            5: project_ui_in[7:4] <= 4'b0100;
            6: project_ui_in[7:4] <= 4'b0111;
            7: project_ui_in[7:4] <= 4'b0110;
        endcase
    end
    project_rst_n <= (counter[26:0] != 0);
    project_ui_in[3:0] <= {counter[31:30], 2'b00};
end

reg [7:0] r_target;
reg [7:0] g_target;
reg [7:0] b_target;

always_comb begin
    case(depth)
    0: begin
        r_target = {(8){r[7]}};
        g_target = {(8){g[7]}};
        b_target = {(8){b[7]}};
    end
    1: begin
        r_target = {(4){r[7:6]}};
        g_target = {(4){g[7:6]}};
        b_target = {(4){b[7:6]}};
    end
    2: begin
        r_target = {{(2){r[7:5]}}, r[7:6]};
        g_target = {{(2){g[7:5]}}, g[7:6]};
        b_target = {{(2){b[7:5]}}, b[7:6]};
    end
    3: begin
        r_target = {(2){r[7:4]}};
        g_target = {(2){g[7:4]}};
        b_target = {(2){b[7:4]}};
    end
    4: begin
        r_target = {r[7:3], r[7:5]};
        g_target = {g[7:3], g[7:5]};
        b_target = {b[7:3], b[7:5]};
    end
    5: begin
        r_target = {r[7:2], r[7:6]};
        g_target = {g[7:2], g[7:6]};
        b_target = {b[7:2], b[7:6]};
    end
    6: begin
        r_target = {r[7:1], r[7]};
        g_target = {g[7:1], g[7]};
        b_target = {b[7:1], b[7]};
    end
    7: begin
        r_target = r;
        g_target = g;
        b_target = b;
    end
    endcase
end

reg [1:0] frame_counter;
reg prev_vsync;
wire new_frame = (vsync == project_ui_in[7] && prev_vsync != project_ui_in[7]);
always @(posedge clk) begin
    if(!rst_n) begin
        frame_counter <= 0;
        prev_vsync <= 0;
    end else begin
        prev_vsync <= vsync;
        if (new_frame) begin
            frame_counter <= frame_counter + 1;
        end
    end
end

wire hsync = project_uo_out[7];
wire vsync = project_uo_out[3];

reg [4:0] dither_threshold;
always @(posedge clk) begin
    if(!rst_n || (new_frame && frame_counter == 0)) begin
        dither_threshold <= 0;
    end else begin
        if (dither_threshold >= 12) begin  // 5 + 12 = 17 = 8'b00010001
            dither_threshold <= dither_threshold - 12;
        end else begin
            dither_threshold <= dither_threshold + 5;
        end
    end
end

wire [3:0] r_round = r_target[7:4];
wire r_sub = r_target < {r_round, r_round};
wire [3:0] r_int = r_sub ? (r_round - 1) : r_round;
wire [4:0] r_frac = r_target - {r_int, r_int};

wire [3:0] g_round = g_target[7:4];
wire g_sub = g_target < {g_round, g_round};
wire [3:0] g_int = g_sub ? (g_round - 1) : g_round;
wire [4:0] g_frac = g_target - {g_int, g_int};

wire [3:0] b_round = b_target[7:4];
wire b_sub = b_target < {b_round, b_round};
wire [3:0] b_int = b_sub ? (b_round - 1) : b_round;
wire [4:0] b_frac = b_target - {b_int, b_int};

wire r_bump = r_frac > dither_threshold;
wire g_bump = g_frac > dither_threshold;
wire b_bump = b_frac > dither_threshold;

wire [3:0] red   = r_int + r_bump;
wire [3:0] green = g_int + g_bump;
wire [3:0] blue  = b_int + b_bump;

assign uo_out = {blue, red};
assign uio_out = {2'b00, vsync, hsync, green};
assign uio_oe = 8'b11111111;

wire _unused = &{uio_in, project_uio_out, project_uio_oe, 1'b0};

endmodule
