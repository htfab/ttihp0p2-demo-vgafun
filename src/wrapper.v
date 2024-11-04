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

reg [31:0] lfsr;
always @(posedge clk) begin
    if(!rst_n) begin
        lfsr <= -1;
    end else begin
        lfsr <= {lfsr[30:0], lfsr[31]^lfsr[29]^lfsr[25]^lfsr[24]};
    end
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

wire [4:0] r_diff = {1'b0, r_target[3:0]} - {1'b0, r_target[7:4]};
wire [4:0] g_diff = {1'b0, g_target[3:0]} - {1'b0, g_target[7:4]};
wire [4:0] b_diff = {1'b0, b_target[3:0]} - {1'b0, b_target[7:4]};

wire r_bump = (r_diff != 0) && (r_diff[3:0] >= lfsr[19:16]);
wire g_bump = (g_diff != 0) && (g_diff[3:0] >= lfsr[11:8]);
wire b_bump = (b_diff != 0) && (b_diff[3:0] >= lfsr[3:0]);

wire [3:0] red   = r_target[7:4] - r_diff[4] + r_bump;
wire [3:0] green = g_target[7:4] - g_diff[4] + g_bump;
wire [3:0] blue  = b_target[7:4] - b_diff[4] + b_bump;

wire hsync = project_uo_out[7];
wire vsync = project_uo_out[3];

assign uo_out = {blue, red};
assign uio_out = {2'b00, vsync, hsync, green};

wire _unused = &{uio_in, project_uio_out, project_uio_oe, 1'b0};

endmodule
