`timescale 1ns / 1ps
// basys3_uart_led_pwm_cds_ultra_fnd_top.v
//
// UART Register Map 기반 LED PWM + CdS + 초음파 거리계 Top 모듈이다.
//
// 기존 uart_core는 그대로 사용한다.
// Top은 보드 핀 연결과 모듈 연결만 담당한다.
//
// UART 입력 포맷:
//
// 1st Byte : CMD
// 2nd Byte : ADDR
// 3rd Byte : DATA
module basys3_uart_led_pwm_cds_ultra_fnd_top #(parameter CLK_FREQ = 100_000_000,
                                               parameter BAUD_RATE = 9600,
                                               parameter FIFO_DEPTH = 256,
                                               parameter FIFO_ADDR_WIDTH = 8)
                                             (input wire clk,
                                               input wire btnU,
                                               input wire RsRx,
                                               input wire cds_in,
                                               input wire us_echo,
                                               output wire us_trig,
                                               output wire RsTx,
                                               output wire [15:0] led,
                                               output wire [6:0] seg,
                                               output wire [3:0] an,
                                               output wire dp);
    wire reset;
    assign reset = btnU;
    wire [7:0] rx_stream_data;
    wire rx_stream_valid;
    wire rx_stream_ready;
    wire [7:0] tx_stream_data;
    wire tx_stream_valid;
    wire tx_stream_ready;
    assign tx_stream_data  = 8'h00;
    assign tx_stream_valid = 1'b0;
    wire rx_empty;
    wire rx_full;
    wire [FIFO_ADDR_WIDTH:0] rx_count;
    wire tx_empty;
    wire tx_full;
    wire [FIFO_ADDR_WIDTH:0] tx_count;
    wire tx_busy;
    wire tx_done;
    wire frame_error;
    wire overrun_error;
    wire reg_wr_en;
    wire [7:0] reg_wr_addr;
    wire [7:0] reg_wr_data;
    wire [7:0] ctrl_reg;
    wire [7:0] pwm_value_reg;
    wire [7:0] dist_limit_cm_reg;
    wire [7:0] spi0_ctrl_reg;
    wire [7:0] i2c0_ctrl_reg;
    wire reg_error;
    wire [1:0] byte_index;
    wire [7:0] last_cmd;
    wire cmd_error;
    wire cds_sw_sync;
    wire cds_is_light;
    wire cds_en;
    wire dist_en;
    assign cds_en  = ctrl_reg[1];
    assign dist_en = ctrl_reg[2];
    wire [9:0] distance_cm;
    wire [11:0] distance_bcd;
    wire distance_valid;
    wire distance_busy;
    wire distance_timeout;
    wire [3:0] fnd_status_code;
    wire [11:0] fnd_value_bcd;
    wire fnd_status_valid;
    wire fnd_value_valid;
    assign fnd_status_valid = cds_en || dist_en;
    assign fnd_status_code = 
    cds_en ? (cds_is_light ? 4'hA : 4'hB) :
    4'hC;
    assign fnd_value_bcd = 
    dist_en ? distance_bcd : 12'h000;
    assign fnd_value_valid = 
    dist_en && distance_valid;
    uart_core #(
    .CLK_FREQ (CLK_FREQ),
    .BAUD_RATE (BAUD_RATE),
    .FIFO_DEPTH (FIFO_DEPTH),
    .FIFO_ADDR_WIDTH (FIFO_ADDR_WIDTH)
    ) u_uart_core (
    .clk (clk),
    .reset (reset),
    .rx_serial (RsRx),
    .tx_serial (RsTx),
    .rx_out_data (rx_stream_data),
    .rx_out_valid (rx_stream_valid),
    .rx_out_ready (rx_stream_ready),
    .rx_empty (rx_empty),
    .rx_full (rx_full),
    .rx_fifo_clear (1'b0),
    .rx_count (rx_count),
    .frame_error (frame_error),
    .overrun_error (overrun_error),
    .tx_in_data (tx_stream_data),
    .tx_in_valid (tx_stream_valid),
    .tx_in_ready (tx_stream_ready),
    .tx_empty (tx_empty),
    .tx_full (tx_full),
    .tx_count (tx_count),
    .tx_busy (tx_busy),
    .tx_done (tx_done)
    );
    uart_reg_write_controller u_uart_reg_write_controller (
    .clk (clk),
    .reset (reset),
    .in_data (rx_stream_data),
    .in_valid (rx_stream_valid),
    .in_ready (rx_stream_ready),
    .reg_wr_en (reg_wr_en),
    .reg_wr_addr (reg_wr_addr),
    .reg_wr_data (reg_wr_data),
    .byte_index (byte_index),
    .last_cmd (last_cmd),
    .cmd_error (cmd_error)
    );
    simple_register_map u_simple_register_map (
    .clk (clk),
    .reset (reset),
    .reg_wr_en (reg_wr_en),
    .reg_wr_addr (reg_wr_addr),
    .reg_wr_data (reg_wr_data),
    .ctrl_reg (ctrl_reg),
    .pwm_value_reg (pwm_value_reg),
    .dist_limit_cm_reg (dist_limit_cm_reg),
    .spi0_ctrl_reg (spi0_ctrl_reg),
    .i2c0_ctrl_reg (i2c0_ctrl_reg),
    .reg_error (reg_error)
    );
    led_pwm_controller #(
    .PWM_PRESCALE(390)
    ) u_led_pwm_controller (
    .clk (clk),
    .reset (reset),
    .ctrl_reg (ctrl_reg),
    .pwm_value (pwm_value_reg),
    .led (led)
    );
    cds_input_filter u_cds_input_filter (
    .clk (clk),
    .reset (reset),
    .cds_sw_raw (cds_in),
    .cds_sw_sync (cds_sw_sync),
    .cds_is_light (cds_is_light)
    );
    ultrasonic_distance_meter u_ultrasonic_distance_meter (
    .clk (clk),
    .reset (reset),
    .enable (dist_en),
    .echo (us_echo),
    .trig (us_trig),
    .distance_cm (distance_cm),
    .distance_bcd (distance_bcd),
    .distance_valid (distance_valid),
    .busy (distance_busy),
    .timeout_error (distance_timeout)
    );
    fnd_status_3digit_display #(
    .CLK_FREQ_HZ (CLK_FREQ),
    .SCAN_HZ (1000)
    ) u_fnd_status_3digit_display (
    .clk (clk),
    .reset (reset),
    .status_valid (fnd_status_valid),
    .status_code (fnd_status_code),
    .value_bcd (fnd_value_bcd),
    .value_valid (fnd_value_valid),
    .seg (seg),
    .an (an),
    .dp (dp)
    );
endmodule
