`timescale 1ns / 1ps

// simple_register_map.v
//
// 이번 과제에서 사용하는 최소 Register Map 모듈이다.
//
// 지원 Register는 2개이다.
//
// 0x00 : CTRL
// 0x01 : PWM_VALUE
//
// CTRL Register는 LED PWM 기능을 켜고 끄는 용도이다.
// PWM_VALUE Register는 LED 밝기값을 저장하는 용도이다.
//
// CdS 입력 방향은 외부 회로에서 맞춘다.
// FPGA 내부에서는 반전 Register를 두지 않는다.

module simple_register_map(input wire clk,
                           input wire reset,
                           input wire reg_wr_en,
                           input wire [7:0] reg_wr_addr,
                           input wire [7:0] reg_wr_data,
                           output reg [7:0] ctrl_reg,
                           output reg [7:0] pwm_value_reg,
                           output reg [7:0] dist_limit_cm_reg,
                           output reg [7:0] spi0_ctrl_reg,
                           output reg [7:0] i2c0_ctrl_reg,
                           output reg reg_error);
    
    localparam ADDR_CTRL          = 8'h00;
    localparam ADDR_PWM_VALUE     = 8'h01;
    localparam ADDR_DIST_LIMIT_CM = 8'h02;
    localparam ADDR_SPI0_CTRL     = 8'h10;
    localparam ADDR_I2C0_CTRL     = 8'h20;
    
    always @(posedge clk) begin
        if (reset) begin
            ctrl_reg          <= 8'h00;
            pwm_value_reg     <= 8'h00;
            dist_limit_cm_reg <= 8'h00;
            spi0_ctrl_reg     <= 8'h00;
            i2c0_ctrl_reg     <= 8'h00;
            reg_error         <= 1'b0;
            end else begin
            reg_error <= 1'b0;
            
            if (reg_wr_en) begin
                case (reg_wr_addr)
                    
                    ADDR_DIST_LIMIT_CM: begin
                        // 현 과제에서는 저장만 한다.
                        // 향후 L298 모터 제어에서 거리 기준값으로 사용한다.
                        dist_limit_cm_reg <= reg_wr_data;
                    end
                    
                    ADDR_SPI0_CTRL: begin
                        // SPI0 제어용 예약 Register이다.
                        // 현 과제에서는 실제 동작에 연결하지 않는다.
                        spi0_ctrl_reg <= reg_wr_data;
                    end
                    
                    ADDR_I2C0_CTRL: begin
                        // I2C0 제어용 예약 Register이다.
                        // 현 과제에서는 실제 동작에 연결하지 않는다.
                        i2c0_ctrl_reg <= reg_wr_data;
                    end
                    
                    ADDR_CTRL: begin
                        ctrl_reg <= reg_wr_data;
                    end
                    
                    ADDR_PWM_VALUE: begin
                        pwm_value_reg <= reg_wr_data;
                    end
                    
                    default: begin
                        reg_error <= 1'b1;
                    end
                endcase
            end
        end
    end
    
endmodule
