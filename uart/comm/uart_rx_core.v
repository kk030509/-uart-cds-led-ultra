`timescale 1ns / 1ps

// uart_rx_core.v
// UART RX 상위 Core임.
// 내부에 uart_rx_sync, uart_baud_tick_gen, uart_rx_fsm, uart_rx_fifo를 포함함.
// RX FIFO는 기존 내부 메모리 방식 그대로 유지하고 깊이만 256Byte로 확장함.
// //(삭제) rx_bram_line_buffer 저장 기능은 UART Core 내부에 포함하지 않음.

module uart_rx_core #(
    parameter CLKS_PER_SAMPLE = 651,

    // //(추가) RX FIFO 깊이와 주소 폭을 parameter로 분리함.
    parameter FIFO_DEPTH = 256,
    parameter FIFO_ADDR_WIDTH = 8
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       rx,

    input  wire       fifo_clear,

    output wire [7:0] rx_data,
    output wire       rx_valid,
    input  wire       rx_ready,

    output wire       rx_empty,
    output wire       rx_full,

    // //(추가) RX FIFO 저장 개수 확인용 신호임.
    output wire [FIFO_ADDR_WIDTH:0] rx_count,

    output wire       frame_error,
    output wire       overrun_error
);

    wire rx_sync;
    wire sample_tick;
    wire [7:0] fsm_rx_data;
    wire fsm_rx_done;
    wire fsm_frame_error;

    uart_rx_sync u_uart_rx_sync (
        .clk      (clk),
        .reset    (reset),
        .rx_async (rx),
        .rx_sync  (rx_sync)
    );

    uart_baud_tick_gen #(
        .CLKS_PER_SAMPLE(CLKS_PER_SAMPLE)
    ) u_uart_baud_tick_gen (
        .clk   (clk),
        .reset (reset),
        .tick  (sample_tick)
    );

    uart_rx_fsm u_uart_rx_fsm (
        .clk         (clk),
        .reset       (reset),
        .tick        (sample_tick),
        .rx_sync     (rx_sync),
        .rx_data     (fsm_rx_data),
        .rx_done     (fsm_rx_done),
        .frame_error (fsm_frame_error)
    );

    // 기존 uart_rx_fifo를 유지하되 256Byte 내부 메모리 FIFO로 parameter를 확장함.
    // //(삭제) uart_bram_fifo 인스턴스는 사용하지 않음.
    uart_rx_fifo #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) u_uart_rx_fifo (
        .clk           (clk),
        .reset         (reset),
        .clear         (fifo_clear),
        .wr_en         (fsm_rx_done),
        .wr_data       (fsm_rx_data),
        .rd_en         (rx_ready),
        .rd_data       (rx_data),
        .empty         (rx_empty),
        .full          (rx_full),
        .valid         (rx_valid),
        .count         (rx_count),
        .overrun_error (overrun_error)
    );

    assign frame_error = fsm_frame_error;

endmodule
