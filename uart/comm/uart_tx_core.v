`timescale 1ns / 1ps

// uart_tx_core.v
// UART TX 상위 Core임.
// 내부에 uart_tx_fifo, uart_tx_sender, uart_tx_fsm을 포함함.
// 기존 TX Sender/TX FSM 구조는 그대로 유지하고, TX FIFO 깊이만 256Byte로 확장함.
// //(삭제) BRAM FIFO와 rd_valid 기반 송신 구조는 사용하지 않음.

module uart_tx_core #(
    parameter CLKS_PER_BIT = 10417,

    // //(추가) TX FIFO 깊이와 주소 폭을 parameter로 분리함.
    parameter FIFO_DEPTH = 256,
    parameter FIFO_ADDR_WIDTH = 8
)(
    input  wire       clk,
    input  wire       reset,

    input  wire       tx_wr_en,
    input  wire [7:0] tx_wr_data,

    output wire       tx_full,
    output wire       tx_empty,

    // 256Byte FIFO count이므로 9비트임.
    output wire [FIFO_ADDR_WIDTH:0] tx_count,

    output wire       tx_busy,
    output wire       tx_done,
    output wire       tx_serial
);

    wire [7:0] fifo_rd_data;
    wire       fifo_empty;
    wire       fifo_rd_en;
    wire [7:0] tx_data;
    wire       tx_start;

    // 기존 uart_tx_fifo를 유지하되 256Byte 내부 메모리 FIFO로 parameter를 확장함.
    // //(삭제) uart_bram_fifo 인스턴스는 사용하지 않음.
    uart_tx_fifo #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(FIFO_ADDR_WIDTH)
    ) u_uart_tx_fifo (
        .clk     (clk),
        .reset   (reset),
        .wr_en   (tx_wr_en),
        .wr_data (tx_wr_data),
        .rd_en   (fifo_rd_en),
        .rd_data (fifo_rd_data),
        .full    (tx_full),
        .empty   (fifo_empty),
        .count   (tx_count)
    );

    assign tx_empty = fifo_empty;

    // 기존에 잘 동작하던 uart_tx_sender를 그대로 사용함.
    uart_tx_sender u_uart_tx_sender (
        .clk          (clk),
        .reset        (reset),
        .fifo_rd_data (fifo_rd_data),
        .fifo_empty   (fifo_empty),
        .fifo_rd_en   (fifo_rd_en),
        .tx_data      (tx_data),
        .tx_start     (tx_start),
        .tx_busy      (tx_busy)
    );

    // 기존에 잘 동작하던 uart_tx_fsm을 그대로 사용함.
    uart_tx_fsm #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_uart_tx_fsm (
        .clk       (clk),
        .reset     (reset),
        .tx_start  (tx_start),
        .tx_data   (tx_data),
        .tx_serial (tx_serial),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done)
    );

endmodule
