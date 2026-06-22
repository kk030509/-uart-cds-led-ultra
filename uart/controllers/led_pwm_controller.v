`timescale 1ns / 1ps

// led_pwm_controller.v
//
// 8-bit PWM으로 LED 16개의 밝기를 제어하는 모듈이다.
//
// LED 디밍 주파수는 실무형 기준으로
// PWM Prescaler를 포함한다.
//
// Basys3 기본 Clock은 100 MHz이다.
// 8-bit PWM은 256 Step을 사용한다.
// PWM_PRESCALE = 390이면 PWM 주파수는 약 1 kHz가 된다.
//
// 계산식은 다음과 같다.
//
// PWM 주파수 = 100 MHz / (PWM_PRESCALE × 256)
//            = 100,000,000 / (390 × 256)
//            ≒ 1001.6 Hz
//
// ctrl_reg[0] = 1이면 PWM 출력이 활성화된다.
// ctrl_reg[0] = 0이면 LED는 모두 꺼진다.
//
// pwm_value는 0~255 범위의 밝기값이다.
//
// pwm_value = 0x00이면 LED OFF에 가깝다.
// pwm_value = 0x80이면 약 50% 밝기이다.
// pwm_value = 0xFF이면 최대 밝기에 가깝다.

module led_pwm_controller #(
    // 100 MHz Clock 기준 약 1 kHz PWM을 만들기 위한 분주값이다.
    // 100 MHz / (390 × 256) ≒ 1001.6 Hz
    parameter PWM_PRESCALE = 390
)(
    input  wire       clk,
    input  wire       reset,

    // Register Map에서 넘어온 CTRL 값이다.
    // 0x01일 때만 PWM 기능을 활성화한다.
    input  wire [7:0] ctrl_reg,

    // Register Map에서 넘어온 PWM 밝기값이다.
    // 8-bit PWM Counter와 비교된다.
    input  wire [7:0] pwm_value,

    // Basys3 LED 16개 출력이다.
    output reg [15:0] led
);

    // 8-bit PWM Counter이다.
    // 0부터 255까지 반복 증가한다.
    // 이 Counter는 매 Clock마다 증가하지 않고,
    // prescale_counter가 PWM_PRESCALE에 도달할 때만 1씩 증가한다.
    reg [7:0] pwm_counter;

    // PWM Counter 증가 속도를 낮추기 위한 Prescaler Counter이다.
    // 100 MHz Clock을 바로 PWM Counter에 넣으면 PWM 주파수가 너무 높아진다.
    // 이 Counter를 사용하여 PWM 주파수를 약 1 kHz로 낮춘다.
    reg [15:0] prescale_counter;

    // PWM 기능 활성화 여부이다.
    // CTRL Register가 0x01일 때만 1이 된다.
    wire pwm_enable;

    // 현재 PWM Counter 값이 pwm_value보다 작으면 LED ON 구간이다.
    wire pwm_active;

    // Prescaler Counter가 마지막 값에 도달했는지 확인하는 신호이다.
    wire prescale_tick;

    // CTRL Register의 bit0이 1이면 PWM 기능을 켠다.
    assign pwm_enable = ctrl_reg[0];

    // PWM 비교기이다.
    // pwm_counter가 pwm_value보다 작으면 ON,
    // 크거나 같으면 OFF가 된다.
    assign pwm_active = (pwm_counter < pwm_value);

    // PWM Counter를 1 Step 증가시킬 시점을 만든다.
    // PWM_PRESCALE이 390이면 390 Clock마다 1번 tick이 발생한다.
    assign prescale_tick = (prescale_counter == (PWM_PRESCALE - 1));

    always @(posedge clk) begin
        if (reset) begin
            // Reset 시 Prescaler Counter를 0으로 초기화한다.
            prescale_counter <= 16'd0;

            // Reset 시 PWM Counter를 0으로 초기화한다.
            pwm_counter <= 8'd0;
        end else begin
            if (prescale_tick) begin
                // Prescaler가 지정된 값에 도달하면 다시 0으로 초기화한다.
                prescale_counter <= 16'd0;

                // Prescaler tick이 발생한 순간에만 PWM Counter를 1 증가시킨다.
                // 8-bit이므로 255 다음에는 자동으로 0으로 돌아간다.
                pwm_counter <= pwm_counter + 8'd1;
            end else begin
                // Prescaler tick이 아니면 Prescaler Counter만 증가시킨다.
                prescale_counter <= prescale_counter + 16'd1;
            end
        end
    end

    always @(*) begin
        if (pwm_enable) begin
            // PWM 기능이 켜진 상태에서는
            // pwm_active 값에 따라 LED 16개를 모두 같은 밝기로 제어한다.
            led = {16{pwm_active}};
        end else begin
            // PWM 기능이 꺼진 상태에서는 LED를 모두 OFF한다.
            led = 16'h0000;
        end
    end

endmodule
