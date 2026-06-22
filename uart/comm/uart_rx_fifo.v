`timescale 1ns / 1ps

// uart_rx_fifo.v
// UART RX 수신 데이터를 저장하는 FIFO임.
// 기존 16Byte FIFO 구조와 외부 타이밍은 유지하고, 저장 깊이만 256Byte로 확장함.
// //(삭제) 별도 BRAM Line Buffer 저장 구조는 사용하지 않음.
// //(삭제) BRAM FIFO 방식도 사용하지 않음. 기존 Fall-through 방식 rd_data 출력을 유지함.

module uart_rx_fifo #(
    // FIFO 깊이를 16Byte에서 256Byte로 확장함.
    parameter FIFO_DEPTH = 256,

    // 256개 주소를 표현하기 위해 주소 폭을 8비트로 함.
    parameter ADDR_WIDTH = 8
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       clear,

    input  wire       wr_en,
    input  wire [7:0] wr_data,

    input  wire       rd_en,
    output wire [7:0] rd_data,

    output wire       empty,
    output wire       full,
    output wire       valid,

    // //(추가) RX FIFO에 저장된 데이터 개수임. 0~256 표현을 위해 9비트임.
    output wire [ADDR_WIDTH:0] count,

    output wire       overrun_error
);

    // 기존 내부 reg array 메모리 방식을 유지하되 깊이만 256Byte로 확장함.
    // //(삭제) (* ram_style = "block" *) BRAM 강제 추론 속성은 사용하지 않음.
    reg [7:0] mem [0:FIFO_DEPTH-1];

    // 256Byte FIFO용 Write Pointer임.
    reg [ADDR_WIDTH-1:0] wr_ptr;

    // 256Byte FIFO용 Read Pointer임.
    reg [ADDR_WIDTH-1:0] rd_ptr;

    // 0~256까지 저장 개수를 표현하는 Count Register임.
    reg [ADDR_WIDTH:0] count_reg;

    // FIFO Full 상태에서 Write가 발생한 이력임.
    reg overrun_reg;

    // //(추가) FIFO_DEPTH를 count_reg와 같은 폭으로 비교하기 위한 상수임.
    localparam [ADDR_WIDTH:0] FIFO_DEPTH_VALUE = FIFO_DEPTH;

    // 실제 Write 가능 조건임.
    wire write_ok;

    // 실제 Read 가능 조건임.
    wire read_ok;

    assign empty = (count_reg == {(ADDR_WIDTH+1){1'b0}});
    assign full  = (count_reg == FIFO_DEPTH_VALUE);
    assign valid = !empty;
    assign count = count_reg;

    assign write_ok = wr_en && !full;
    assign read_ok  = rd_en && !empty;

    // 기존 후단 로직이 기대하는 Fall-through 방식 출력임.
    assign rd_data = mem[rd_ptr];

    always @(posedge clk) begin
        // Reset 또는 Clear 시 FIFO 상태를 초기화함.
        if (reset || clear) begin
            wr_ptr      <= {ADDR_WIDTH{1'b0}};
            rd_ptr      <= {ADDR_WIDTH{1'b0}};
            count_reg   <= {(ADDR_WIDTH+1){1'b0}};
            overrun_reg <= 1'b0;
        end

        // Reset이 아니면 Write/Read를 처리함.
        else begin
            // Full 상태에서 Write 요청이 오면 Overrun을 저장함.
            if (wr_en && full) begin
                overrun_reg <= 1'b1;
            end
            else begin
                overrun_reg <= overrun_reg;
            end

            // Write 가능하면 현재 wr_ptr 위치에 저장함.
            if (write_ok) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 1'b1;
            end

            // Read 가능하면 rd_ptr을 다음 위치로 이동함.
            if (read_ok) begin
                rd_ptr <= rd_ptr + 1'b1;
            end

            // Count 갱신함.
            case ({write_ok, read_ok})
                2'b10: count_reg <= count_reg + 1'b1;
                2'b01: count_reg <= count_reg - 1'b1;
                default: count_reg <= count_reg;
            endcase
        end
    end

    assign overrun_error = overrun_reg;

endmodule
