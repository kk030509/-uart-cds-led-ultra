`timescale 1ns / 1ps
// tb_basys3_uart_led_pwm_cds_ultra_fnd_top.v
//
// UART Register Map 기반 LED PWM + CdS + 초음파 거리계 Top 테스트벤치이
//
// 실제 초음파 센서를 사용하지 않는다.
// us_echo 신호를 테스트벤치에서 강제로 만들어 거리값을 검증한다.
//
// 검증 흐름:
//
// 1. Reset 확인
// 2. CTRL = 0x04로 초음파만 ON
// 3. Echo High 시간을 만들어 거리 계산 확인
// 4. CTRL = 0x06으로 CdS + 초음파 ON
// 5. CdS 밝음 / 어두움 상태 확인
// 6. CTRL = 0x00으로 전체 OFF 확인
module tb_basys3_uart_led_pwm_cds_ultra_fnd_top; 
parameter CLK_FREQ = 100_000_000; 
parameter BAUD_RATE = 1_000_000; 
parameter CLK_PERIOD_NS = 10; 
parameter BIT_PERIOD_NS = 1_000_000_000 / BAUD_RATE; 
reg clk; 
reg btnU; 
reg RsRx; 
reg cds_in; 
reg us_echo; 
wire us_trig; 
wire RsTx; 
wire [15:0] led; 
wire [6:0] seg; 
wire [3:0] an; 
wire dp; basys3_uart_led_pwm_cds_ultra_fnd_top #(
    .CLK_FREQ (CLK_FREQ) , 
    .BAUD_RATE (BAUD_RATE))
    dut (.clk (clk), 
    .btnU (btnU), 
    .RsRx (RsRx), 
    .cds_in (cds_in), 
    .us_echo (us_echo), 
    .us_trig (us_trig), 
    .RsTx (RsTx), 
    .led (led), 
    .seg (seg), 
    .an (an), 
    .dp (dp));
    initial begin
        clk = 1'b0;
        // 100 MHz Clock 생성이다.
        forever #(CLK_PERIOD_NS / 2) clk = ~clk;
    end
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // UART Idle 상태는 1이다.
            RsRx = 1'b1;
            #(BIT_PERIOD_NS);
            // Start bit는 0이다.
            RsRx = 1'b0;
            #(BIT_PERIOD_NS);
            // UART는 LSB first로 전송한다.
            for (i = 0; i < 8; i = i + 1) begin
                RsRx = data[i];
                #(BIT_PERIOD_NS);
            end
            // Stop bit는 1이다.
            RsRx = 1'b1;
            #(BIT_PERIOD_NS);
        end
    endtask
    task uart_send_write_packet;
        input [7:0] addr;
        input [7:0] data;
        begin
            // 1st Byte는 CMD이다.
            // 0x01은 Register Write 명령이다.
            uart_send_byte(8'h01);
            // 2nd Byte는 Register 주소이다.
            uart_send_byte(addr);
            // 3rd Byte는 Register에 쓸 데이터이다.
            uart_send_byte(data);
        end
    endtask
    task send_echo_after_trig;
        input integer echo_high_us;
        begin
            // TRIG가 1이 될 때까지 기다린다.
            wait (us_trig == 1'b1);
            // TRIG가 0으로 끝날 때까지 기다린다.
            wait (us_trig == 1'b0);
            // 실제 센서 반응 지연을 간단히 표현한다.
            #(2_000);
            // Echo High 구간을 만든다.
            us_echo = 1'b1;
            #(echo_high_us * 1000);
            us_echo = 1'b0;
        end
    endtask
    task check_distance_range;
        input [9:0] min_cm;
        input [9:0] max_cm;
        begin
            if (dut.distance_cm < min_cm || dut.distance_cm > max_cm)
            begin
                $display("ERROR: distance_cm out of range. distance_cm = %0d",
                dut.distance_cm);
                $finish;
            end
        end
    endtask
    initial begin
        // 초기 상태이다.
        RsRx    = 1'b1;
        cds_in  = 1'b0;
        us_echo = 1'b0;
        btnU    = 1'b1;
        #(CLK_PERIOD_NS * 20);
        // Reset 해제이다.
        btnU = 1'b0;
        #(BIT_PERIOD_NS * 5);
        // -----------------------------------------------------
        // 1. CTRL = 0x04
        // 초음파 거리계만 ON한다.
        // FND는 -xxx 형식이 된다.
        // -----------------------------------------------------
        uart_send_write_packet(8'h00, 8'h04);
        #(BIT_PERIOD_NS * 5);
        if (dut.u_simple_register_map.ctrl_reg !== 8'h04) begin
            $display("ERROR: CTRL 0x04 write failed. ctrl_reg = %h",
            dut.u_simple_register_map.ctrl_reg);
            $finish;
        end
        // Echo High 5800us는 약 100cm에 해당한다.
        send_echo_after_trig(5800);
        #(20_000);
        if (dut.distance_valid !== 1'b1) begin
            $display("ERROR: distance_valid is not high.");
            $finish;
        end
        check_distance_range(10'd95, 10'd105);
        // 2. CTRL = 0x00
        // 초음파 내부 상태를 초기화한다.
        // -----------------------------------------------------
        uart_send_write_packet(8'h00, 8'h00);
        #(BIT_PERIOD_NS * 5);
        // -----------------------------------------------------
        // 3. CTRL = 0x06
        // CdS + 초음파 거리계를 ON한다.
        // -----------------------------------------------------
        cds_in = 1'b1;
        uart_send_write_packet(8'h00, 8'h06);
        #(BIT_PERIOD_NS * 5);
        if (dut.u_simple_register_map.ctrl_reg !== 8'h06) begin
            $display("ERROR: CTRL 0x06 write failed. ctrl_reg = %h",
            dut.u_simple_register_map.ctrl_reg);
            $finish;
        end
        // Echo High 580us는 약 10cm에 해당한다.
        send_echo_after_trig(580);
        #(20_000);
        check_distance_range(10'd8, 10'd12);
        if (dut.cds_is_light !== 1'b1) begin
            $display("ERROR: CdS light state failed.");
            $finish;
        end
            if (dut.fnd_status_code !== 4'hA) begin
                $display("ERROR: FND status should be L.");
                $finish;
            end
        // -----------------------------------------------------
        // 4. CdS 어두움 상태 확인
        // 초음파 측정값은 유지되고 상위 문자만 d가 된다.
        // -----------------------------------------------------
        cds_in = 1'b0;
        #(CLK_PERIOD_NS * 10);
        if (dut.cds_is_light !== 1'b0) begin
            $display("ERROR: CdS dark state failed.");
            $finish;
        end
            if (dut.fnd_status_code !== 4'hB) begin
                $display("ERROR: FND status should be d.");
                $finish;
            end
        // -----------------------------------------------------
        // 5. DIST_LIMIT_CM 예약 Register 저장 확인
        // 현 과제에서는 동작에는 사용하지 않는다.
        // -----------------------------------------------------
        uart_send_write_packet(8'h02, 8'h1E);
        #(BIT_PERIOD_NS * 5);
        if (dut.u_simple_register_map.dist_limit_cm_reg !== 8'h1E) begin
        $display("ERROR: DIST_LIMIT_CM write failed. dist_limit_cm_reg = %h",
        dut.u_simple_register_map.dist_limit_cm_reg);
        $finish;
    end
    // -----------------------------------------------------
    // 6. CTRL = 0x00
    // 전체 OFF 상태를 확인한다.
    // -----------------------------------------------------
    uart_send_write_packet(8'h00, 8'h00);
    #(BIT_PERIOD_NS * 5);
    if (dut.u_simple_register_map.ctrl_reg !== 8'h00) begin
        $display("ERROR: CTRL 0x00 write failed. ctrl_reg = %h",
        dut.u_simple_register_map.ctrl_reg);
        $finish;
    end
        if (led !== 16'h0000) begin
            $display("ERROR: LED off failed. led = %h", led);
            $finish;
        end
    $display("PASS: UART Register Map LED PWM + CdS + Ultrasonictest completed.");
    $finish;
    end
endmodule
