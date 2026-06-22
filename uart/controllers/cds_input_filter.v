`timescale 1ns / 1ps

// cds_input_filter.v
// ------------------------------------------------------------
// CdS 외부 회로 출력을 FPGA Clock에 동기화하는 모듈이다.
//
// 외부 회로 기준은 다음으로 고정한다.
// 밝음 / 낮  -> 외부 회로 출력 1
// 어두움 / 밤 -> 외부 회로 출력 0
//
// 따라서 FPGA 내부 기준도 직관적으로 맞춘다.
// cds_is_light = 1 -> 밝음 / 낮
// cds_is_light = 0 -> 어두움 / 밤
//
// 입력 반전은 FPGA 내부에서 처리하지 않는다.
// 필요한 반전은 외부 회로에서 처리한다.
// ------------------------------------------------------------

module cds_input_filter(
    // 시스템 Clock이다.
    input  wire clk,

    // Active-high 동기 Reset이다.
    input  wire reset,

    // 외부 CdS 회로에서 들어오는 비동기 입력이다.
    input  wire cds_sw_raw,

    // 2-FF 동기화가 끝난 CdS 입력이다.
    output wire cds_sw_sync,

    // 최종 밝음 판단 결과이다.
    // 1이면 낮 / 밝음 상태이다.
    // 0이면 밤 / 어두움 상태이다.
    output wire cds_is_light
);

    // 외부 입력은 FPGA Clock과 동기화되어 있지 않다.
    // 따라서 2단 Flip-Flop으로 동기화한다.
    reg cds_meta;
    reg cds_sync_reg;

    always @(posedge clk) begin
        if (reset) begin
            cds_meta     <= 1'b0;
            cds_sync_reg <= 1'b0;
        end else begin
            cds_meta     <= cds_sw_raw;
            cds_sync_reg <= cds_meta;
        end
    end

    assign cds_sw_sync  = cds_sync_reg;
    assign cds_is_light = cds_sync_reg;

endmodule
