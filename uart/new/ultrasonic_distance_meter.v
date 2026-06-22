`timescale 1ns / 1ps
// ultrasonic_distance_meter.v
//
// 초음파 거리계를 위한 단일 모듈이다.
//
// 이 파일 안에 1us Tick 생성, TRIG 생성, ECHO 측정,
// 거리 계산, BCD 변환, Timeout 처리를 모두 포함한다.
//
// 거리 계산 기준:
//
// distance_cm = echo_high_time_us / 58
//
// Echo 입력은 외부 센서에서 들어오는 비동기 입력이다.
// 따라서 내부에서 2-FF 동기화를 수행한다.
//
// HC-SR04 Echo 출력은 보통 5V이다.
// Basys3 입력은 3.3V 기준이므로 반드시 레벨 변환 후 연결한다.
module ultrasonic_distance_meter #(parameter CLK_FREQ_HZ = 100_000_000,
                                   parameter MEASURE_GAP_US = 60_000,
                                   parameter TRIG_PULSE_US = 10,
                                   parameter ECHO_TIMEOUT_US = 30_000)
                                  (input wire clk,
                                   input wire reset,
                                   input wire enable,
                                   input wire echo,
                                   output reg trig,
                                   output reg [9:0] distance_cm,
                                   output reg [11:0] distance_bcd,
                                   output reg distance_valid,
                                   output reg busy,
                                   output reg timeout_error);
    localparam integer CYCLES_PER_US = CLK_FREQ_HZ / 1_000_000;
    localparam S_IDLE                = 3'd0;
    localparam S_TRIG                = 3'd1;
    localparam S_WAIT_ECHO_HIGH      = 3'd2;
    localparam S_MEASURE_ECHO        = 3'd3;
    reg [2:0] state;
    // 1us Tick 생성을 위한 Clock 분주 Counter이다.
    reg [31:0] us_div_cnt;
    reg tick_1us;
    // 측정 간격, Trigger 시간, Echo 시간을 세는 Counter이다.
    reg [31:0] gap_us_cnt;
    reg [31:0] trig_us_cnt;
    reg [31:0] wait_us_cnt;
    reg [31:0] echo_us_cnt;
    // Echo 입력 동기화 Register이다.
    reg echo_meta;
    reg echo_sync;
    // Echo 시간을 cm로 변환한 값이다.
    // 32-bit로 먼저 계산한 뒤, 999cm를 초과하면 999로 제한한다.
    // 이렇게 분리하면 합성/시뮬레이션 경고를 줄이고 의미가 명확해진다.
    wire [31:0] calc_distance_cm_wide;
    wire [9:0] calc_distance_cm;
    assign calc_distance_cm_wide = echo_us_cnt / 32'd58;
    assign calc_distance_cm = 
    (calc_distance_cm_wide > 32'd999) ? 10'd999 :calc_distance_cm_wide[9:0];
    // Binary 거리값을 FND용 BCD 3자리로 변환한다.
    function [11:0] bin_to_bcd3;
        input [9:0] bin;
        integer hundreds;
        integer tens;
        integer ones;
        begin
            hundreds = bin / 100;
            tens     = (bin % 100) / 10;
            ones     = bin % 10;
            bin_to_bcd3 = {
            hundreds[3:0],
            tens[3:0],
            ones[3:0]
            };
        end
    endfunction
    // Echo 입력 2-FF 동기화
    always @(posedge clk) begin
        if (reset) begin
            // Reset이면 Echo 동기화 Register를 초기화한다.
            echo_meta <= 1'b0;
            echo_sync <= 1'b0;
            end else begin
            // 외부 Echo 입력을 FPGA Clock에 맞춘다.
            echo_meta <= echo;
            echo_sync <= echo_meta;
        end
    end
    // 1us Tick 생성
    always @(posedge clk) begin
        if (reset) begin
            // Reset이면 분주 Counter를 초기화한다.
            us_div_cnt <= 32'd0;
            tick_1us   <= 1'b0;
            end else begin
            // tick_1us는 1 Clock Pulse로 사용한다.
            tick_1us <= 1'b0;
            if (!enable) begin
                // Enable이 꺼져 있으면 1us Tick도 정지한다.
                us_div_cnt <= 32'd0;
                end else begin
                if (us_div_cnt >= CYCLES_PER_US - 1) begin
                    // 1us가 되면 tick_1us를 1 Clock 동안 발생시킨다.
                    us_div_cnt <= 32'd0;
                    tick_1us   <= 1'b1;
                    end else begin
                    // 아직 1us가 아니면 Clock 수를 계속 센다.
                    us_div_cnt <= us_div_cnt + 32'd1;
                end
            end
        end
    end
    // 초음파 거리 측정 FSM
    always @(posedge clk) begin
        if (reset) begin
            // Reset이면 모든 출력과 상태를 초기화한다.
            state          <= S_IDLE;
            trig           <= 1'b0;
            busy           <= 1'b0;
            distance_cm    <= 10'd0;
            distance_bcd   <= 12'h000;
            distance_valid <= 1'b0;
            timeout_error  <= 1'b0;
            gap_us_cnt     <= MEASURE_GAP_US;
            trig_us_cnt    <= 32'd0;
            wait_us_cnt    <= 32'd0;
            echo_us_cnt    <= 32'd0;
            end else begin
            // timeout_error는 1 Clock Pulse로 사용한다.
            timeout_error <= 1'b0;
            if (!enable) begin
                // Enable이 꺼지면 초음파 측정을 멈춘다.
                state          <= S_IDLE;
                trig           <= 1'b0;
                busy           <= 1'b0;
                distance_cm    <= 10'd0;
                distance_bcd   <= 12'h000;
                distance_valid <= 1'b0;
                gap_us_cnt     <= MEASURE_GAP_US;
                trig_us_cnt    <= 32'd0;
                wait_us_cnt    <= 32'd0;
                echo_us_cnt    <= 32'd0;
                end else begin
                case (state)
                    S_IDLE: begin
                        // 측정 대기 상태이다.
                        trig <= 1'b0;
                        busy <= 1'b0;
                        if (tick_1us) begin
                            if (gap_us_cnt >= MEASURE_GAP_US) begin
                                // 측정 간격이 되었으면 TRIG Pulse를 시작한다.
                                gap_us_cnt  <= 32'd0;
                                trig_us_cnt <= 32'd0;
                                state       <= S_TRIG;
                                busy        <= 1'b1;
                                
                                end else begin
                                    // 아직 측정 간격이 아니면 대기 시간을 증가시킨다.
                                    gap_us_cnt <= gap_us_cnt + 32'd1;
                                end
                            end
                        end
                        S_TRIG: begin
                            // 초음파 센서에 Trigger Pulse를 출력한다.
                            busy <= 1'b1;
                            trig <= 1'b1;
                            if (tick_1us) begin
                                if (trig_us_cnt >= TRIG_PULSE_US - 1) begin
                                // Trigger Pulse가 끝나면 Echo High를기다린다.
                                trig        <= 1'b0;
                                wait_us_cnt <= 32'd0;
                                state       <= S_WAIT_ECHO_HIGH;
                                
                                end else begin
                                    // Trigger Pulse 시간을 1us씩 증가시킨
                                    trig_us_cnt <= trig_us_cnt + 32'd1;
                                end
                            end
                        end
                        S_WAIT_ECHO_HIGH: begin
                            // Echo가 1이 되기를 기다린다.
                            busy <= 1'b1;
                            trig <= 1'b0;
                            if (echo_sync) begin
                                // Echo가 1이 되면 High 시간 측정을 시작한다.
                                // 1부터 세면 짧은 Echo에서도 0cm가 되는 문제를 줄일 수 있다.
                                echo_us_cnt <= 32'd1;
                                
                                state <= S_MEASURE_ECHO;
                                end else if (tick_1us) begin
                                    if (wait_us_cnt >= ECHO_TIMEOUT_US) begin
                                        // Echo가 들어오지 않으면 Timeout 처리한다.
                                        timeout_error  <= 1'b1;
                                        distance_valid <= 1'b0;
                                        busy           <= 1'b0;
                                        state          <= S_IDLE;
                                        
                                        end else begin
                                            // Echo 대기 시간을 1us씩 증가시킨다.
                                            wait_us_cnt <= wait_us_cnt + 32'd1;
                                        end
                                    end
                                end
                                S_MEASURE_ECHO: begin
                                    // Echo가 1인 시간을 측정한다.
                                    busy <= 1'b1;
                                    trig <= 1'b0;
                                    if (!echo_sync) begin
                                        // Echo가 0으로 떨어지면 거리 계산을 수행한다.
                                        distance_cm    <= calc_distance_cm;
                                        distance_bcd   <= bin_to_bcd3(calc_distance_cm);
                                        distance_valid <= 1'b1;
                                        busy           <= 1'b0;
                                        state          <= S_IDLE;
                                        end else if (tick_1us) begin
                                            if (echo_us_cnt >= ECHO_TIMEOUT_US) begin
                                                // Echo가 너무 오래 유지되면 Timeout 처리한다.
                                                timeout_error  <= 1'b1;
                                                distance_valid <= 1'b0;
                                                busy           <= 1'b0;
                                                state          <= S_IDLE;
                                                
                                                end else begin
                                                    // Echo High 시간을 1us씩 증가시킨다.
                                                    echo_us_cnt <= echo_us_cnt + 32'd1;
                                                end
                                            end
                                        end
                                        default: begin
                                            // 예외 상태에서는 안전하게 IDLE로 복귀한다.
                                            state <= S_IDLE;
                                            trig  <= 1'b0;
                                            busy  <= 1'b0;
                                            
                                        end
                endcase
            end
        end
    end
endmodule
