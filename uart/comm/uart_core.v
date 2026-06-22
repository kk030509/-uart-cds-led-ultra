`timescale 1ns / 1ps

// uart_core.v
// 표준 Byte Stream 입출력으로 재정의한 UART Core임.
// 별도 Adapter 없이 Controller와 직접 연결할 수 있도록 구성함.
// RX Stream: rx_out_data / rx_out_valid / rx_out_ready
// TX Stream: tx_in_data / tx_in_valid / tx_in_ready

module uart_core #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 9600,
    parameter RX_OVERSAMPLE = 16,
    parameter CLKS_PER_SAMPLE = CLK_FREQ / (BAUD_RATE * RX_OVERSAMPLE),
    parameter CLKS_PER_BIT = CLK_FREQ / BAUD_RATE,

    parameter FIFO_DEPTH = 256,
    parameter FIFO_ADDR_WIDTH = 8
)(
    input  wire       clk,
    input  wire       reset,

    // UART 물리 직렬 신호
    input  wire       rx_serial,
    output wire       tx_serial,

    // =========================================================
    // 표준 RX Byte Stream 출력
    // =========================================================
    output wire [7:0] rx_out_data,
    output wire       rx_out_valid,
    input  wire       rx_out_ready,

    // RX 상태 출력
    output wire       rx_empty,
    output wire       rx_full,
    input  wire       rx_fifo_clear,
    output wire [FIFO_ADDR_WIDTH:0] rx_count,
    output wire       frame_error,
    output wire       overrun_error,

    // =========================================================
    // 표준 TX Byte Stream 입력
    // =========================================================
    input  wire [7:0] tx_in_data,
    input  wire       tx_in_valid,
    output wire       tx_in_ready,

    // TX 상태 출력
    output wire       tx_empty,
    output wire       tx_full,
    output wire [FIFO_ADDR_WIDTH:0] tx_count,
    output wire       tx_busy,
    output wire       tx_done
);

    // 기존 TX Core는 wr_en / wr_data / full 구조를 사용함.
    // uart_core 외부에는 표준 valid / ready 구조만 보이도록 변환함.
    wire       tx_wr_en;
    wire [7:0] tx_wr_data;

    assign tx_in_ready = !tx_full;
    assign tx_wr_en    = tx_in_valid && tx_in_ready;
    assign tx_wr_data  = tx_in_data;

    uart_rx_core #(
        .CLKS_PER_SAMPLE(CLKS_PER_SAMPLE),
        .FIFO_DEPTH(FIFO_DEPTH),
        .FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) u_uart_rx_core (
        .clk           (clk),
        .reset         (reset),
        .rx            (rx_serial),
        .fifo_clear    (rx_fifo_clear),
        .rx_data       (rx_out_data),
        .rx_valid      (rx_out_valid),
        .rx_ready      (rx_out_ready),
        .rx_empty      (rx_empty),
        .rx_full       (rx_full),
        .rx_count      (rx_count),
        .frame_error   (frame_error),
        .overrun_error (overrun_error)
    );

    uart_tx_core #(
        .CLKS_PER_BIT(CLKS_PER_BIT),
        .FIFO_DEPTH(FIFO_DEPTH),
        .FIFO_ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) u_uart_tx_core (
        .clk        (clk),
        .reset      (reset),
        .tx_wr_en   (tx_wr_en),
        .tx_wr_data (tx_wr_data),
        .tx_full    (tx_full),
        .tx_empty   (tx_empty),
        .tx_count   (tx_count),
        .tx_busy    (tx_busy),
        .tx_done    (tx_done),
        .tx_serial  (tx_serial)
    );

endmodule
