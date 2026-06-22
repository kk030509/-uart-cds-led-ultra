`timescale 1ns / 1ps

// uart_tx_fifo.v
// UART TX 송신 대기 데이터를 저장하는 FIFO임.
// 기존 16Byte FIFO 구조와 외부 타이밍은 유지하고, 저장 깊이만 256Byte로 확장함.
// //(삭제) BRAM FIFO 방식은 사용하지 않음. 기존 Fall-through 방식 rd_data 출력을 유지함.

module uart_tx_fifo #(
    // FIFO 깊이를 16Byte에서 256Byte로 확장함.
    parameter FIFO_DEPTH = 256,

    // 256개 주소를 표현하기 위해 주소 폭을 8비트로 함.
    parameter ADDR_WIDTH = 8
)(
    // uart_tx_core에서 넘겨받는 100 MHz 시스템 Clock임.
    input  wire       clk,

    // uart_tx_core에서 넘겨받는 Active-high 동기 Reset임.
    input  wire       reset,

    // uart_tx_core 앞단 로직에서 넘어온 FIFO Write 요청임.
    input  wire       wr_en,

    // uart_tx_core 앞단 로직에서 넘어온 FIFO Write 데이터임.
    input  wire [7:0] wr_data,

    // 뒤단 uart_tx_sender에서 넘어오는 FIFO Read 요청임.
    input  wire       rd_en,

    // FIFO가 뒤단 uart_tx_sender로 넘기는 Read 데이터임.
    output wire [7:0] rd_data,

    // FIFO가 가득 찼을 때 1이 되는 상태 신호임.
    output wire       full,

    // FIFO가 비어 있을 때 1이 되는 상태 신호임.
    output wire       empty,

    // FIFO에 저장된 데이터 개수임. 0~256 표현을 위해 9비트임.
    output wire [ADDR_WIDTH:0] count
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

    // //(추가) FIFO_DEPTH를 count_reg와 같은 폭으로 비교하기 위한 상수임.
    localparam [ADDR_WIDTH:0] FIFO_DEPTH_VALUE = FIFO_DEPTH;

    // Write 가능 조건임.
    wire write_ok;

    // Read 가능 조건임.
    wire read_ok;

    assign write_ok = wr_en && !full;
    assign read_ok  = rd_en && !empty;

    // 기존 TX Sender가 기대하는 Fall-through 방식 출력임.
    // empty가 0이면 rd_data에 현재 rd_ptr 데이터가 이미 보이는 구조임.
    assign rd_data = mem[rd_ptr];

    // 저장 개수를 출력함.
    assign count = count_reg;

    // 저장 개수가 256이면 Full임.
    assign full = (count_reg == FIFO_DEPTH_VALUE);

    // 저장 개수가 0이면 Empty임.
    assign empty = (count_reg == {(ADDR_WIDTH+1){1'b0}});

    always @(posedge clk) begin
        // Reset이면 FIFO 내부 상태를 초기화함.
        if (reset) begin
            wr_ptr    <= {ADDR_WIDTH{1'b0}};
            rd_ptr    <= {ADDR_WIDTH{1'b0}};
            count_reg <= {(ADDR_WIDTH+1){1'b0}};
        end

        // Reset이 아니면 Write와 Read 요청을 처리함.
        else begin
            case ({write_ok, read_ok})

                // Write만 수행함.
                2'b10: begin
                    mem[wr_ptr] <= wr_data;
                    wr_ptr      <= wr_ptr + 1'b1;
                    count_reg   <= count_reg + 1'b1;
                end

                // Read만 수행함.
                2'b01: begin
                    rd_ptr    <= rd_ptr + 1'b1;
                    count_reg <= count_reg - 1'b1;
                end

                // Write와 Read를 동시에 수행함.
                2'b11: begin
                    mem[wr_ptr] <= wr_data;
                    wr_ptr      <= wr_ptr + 1'b1;
                    rd_ptr      <= rd_ptr + 1'b1;
                    count_reg   <= count_reg;
                end

                // Write도 Read도 없으면 현재 상태를 유지함.
                default: begin
                    wr_ptr    <= wr_ptr;
                    rd_ptr    <= rd_ptr;
                    count_reg <= count_reg;
                end
            endcase
        end
    end

endmodule
