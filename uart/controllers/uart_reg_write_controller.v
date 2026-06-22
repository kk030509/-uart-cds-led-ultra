`timescale 1ns / 1ps

// uart_reg_write_controller.v
//
// 기존 uart_core의 RX Byte Stream을 받아서
// 3 Byte 고정 포맷의 Register Write 요청으로 변환하는 모듈이다.
//
// 입력 포맷은 다음과 같다.
//
// CMD ADDR DATA
//
// CMD  : 명령 Byte
// ADDR : Register 주소 Byte
// DATA : Register에 쓸 데이터 Byte
//
// 이번 단계에서는 CMD = 0x01인 Register Write만 지원한다.
//
// 이 모듈은 문자열 Parser가 아니다.
// ASCII 문자를 해석하지 않는다.
// 공백 문자를 처리하지 않는다.
// Hex 문자 '8', '0'을 0x80으로 변환하지 않는다.
//
// uart_core에서 이미 1 Byte 단위로 복원된 데이터를
// 정해진 순서대로 CMD, ADDR, DATA로 저장한 뒤,
// DATA까지 수신되면 Register Write Pulse를 만든다.

module uart_reg_write_controller #(
    parameter CMD_WRITE = 8'h01
)(
    input  wire       clk,
    input  wire       reset,

    // uart_core에서 출력되는 수신 Byte이다.
    // 이미 UART 직렬 신호가 8-bit 데이터로 복원된 상태이다.
    input  wire [7:0] in_data,

    // in_data가 유효함을 나타내는 신호이다.
    // in_valid가 1이면 in_data에 새 Byte가 들어와 있다는 뜻이다.
    input  wire       in_valid,

    // 이 모듈이 새 Byte를 받을 수 있음을 나타내는 신호이다.
    // 이번 단계에서는 항상 받을 수 있으므로 1로 고정한다.
    output wire       in_ready,

    // Register Write 요청 Pulse이다.
    // DATA Byte까지 정상 수신되면 1 Clock 동안 1이 된다.
    output reg        reg_wr_en,

    // Write할 Register 주소이다.
    // 입력 포맷의 ADDR Byte가 이 신호로 전달된다.
    output reg [7:0]  reg_wr_addr,

    // Write할 Register 데이터이다.
    // 입력 포맷의 DATA Byte가 이 신호로 전달된다.
    output reg [7:0]  reg_wr_data,

    // 현재 몇 번째 Byte를 기다리는지 확인하기 위한 상태 출력이다.
    // 0이면 CMD 위치, 1이면 ADDR 위치, 2이면 DATA 위치이다.
    output reg [1:0]  byte_index,

    // 마지막으로 수신한 CMD 값을 확인하기 위한 디버그 출력이다.
    output reg [7:0]  last_cmd,

    // 지원하지 않는 CMD가 들어왔을 때 1 Clock 동안 1이 된다.
    output reg        cmd_error
);

    // 첫 번째 Byte로 받은 CMD를 저장하는 Register이다.
    reg [7:0] cmd_reg;

    // 두 번째 Byte로 받은 ADDR을 저장하는 Register이다.
    reg [7:0] addr_reg;

    // 이번 단계에서는 뒤쪽 회로가 항상 데이터를 받을 수 있다고 가정한다.
    // 따라서 uart_core의 RX FIFO에서 데이터가 있으면 바로 소비한다.
    assign in_ready = 1'b1;

    always @(posedge clk) begin
        if (reset) begin
            // Reset 시 다음 입력을 CMD부터 받도록 초기화한다.
            byte_index <= 2'd0;

            // 저장용 Register를 초기화한다.
            cmd_reg  <= 8'd0;
            addr_reg <= 8'd0;
            last_cmd <= 8'd0;

            // Register Write 출력 신호를 초기화한다.
            reg_wr_en   <= 1'b0;
            reg_wr_addr <= 8'd0;
            reg_wr_data <= 8'd0;

            // CMD 오류 표시를 초기화한다.
            cmd_error <= 1'b0;
        end else begin
            // reg_wr_en은 1 Clock Pulse로만 사용한다.
            // 따라서 매 Clock 기본값은 0으로 둔다.
            reg_wr_en <= 1'b0;

            // cmd_error도 오류가 발생한 순간만 1 Clock 표시한다.
            cmd_error <= 1'b0;

            // uart_core에서 유효한 Byte가 들어오고,
            // 현재 모듈이 받을 준비가 되어 있을 때만 처리한다.
            if (in_valid && in_ready) begin
                case (byte_index)

                    2'd0: begin
                        // 1번째 Byte는 CMD이다.
                        // 이 값을 cmd_reg에 저장해 두었다가
                        // 3번째 DATA Byte가 들어왔을 때 Write 명령인지 확인한다.
                        cmd_reg <= in_data;

                        // 디버깅을 위해 마지막 CMD 값을 별도로 저장한다.
                        last_cmd <= in_data;

                        // 다음 Byte는 ADDR이므로 byte_index를 1로 이동한다.
                        byte_index <= 2'd1;
                    end

                    2'd1: begin
                        // 2번째 Byte는 ADDR이다.
                        // 이 값은 나중에 reg_wr_addr로 출력된다.
                        addr_reg <= in_data;

                        // 다음 Byte는 DATA이므로 byte_index를 2로 이동한다.
                        byte_index <= 2'd2;
                    end

                    2'd2: begin
                        // 3번째 Byte는 DATA이다.
                        // 이 시점에 CMD, ADDR, DATA가 모두 준비된다.

                        if (cmd_reg == CMD_WRITE) begin
                            // CMD가 Register Write이면
                            // Register Map으로 보낼 Write Pulse를 만든다.
                            reg_wr_en <= 1'b1;

                            // 앞에서 저장한 ADDR을 Write Address로 출력한다.
                            reg_wr_addr <= addr_reg;

                            // 현재 들어온 DATA Byte를 Write Data로 출력한다.
                            reg_wr_data <= in_data;
                        end else begin
                            // 지원하지 않는 CMD이면 Register Write는 발생시키지 않는다.
                            // 대신 cmd_error만 1 Clock 표시한다.
                            cmd_error <= 1'b1;
                        end

                        // 3 Byte 처리가 끝났으므로
                        // 다음 입력은 다시 CMD부터 받는다.
                        byte_index <= 2'd0;
                    end

                    default: begin
                        // 예외적으로 byte_index가 잘못된 값이 되면
                        // 다시 CMD 위치로 복귀한다.
                        byte_index <= 2'd0;
                    end
                endcase
            end
        end
    end

endmodule
