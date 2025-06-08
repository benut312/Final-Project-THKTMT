# =============================================================================
# Project: Simple Calculator - Biến tên mới, không trùng mã mẫu
# =============================================================================

.eqv SEG7_RIGHT, 0xFFFF0010        # Địa chỉ điều khiển LED 7 đoạn bên phải
.eqv SEG7_LEFT,  0xFFFF0011        # Địa chỉ điều khiển LED 7 đoạn bên trái
.eqv KPMATRIX_IN,  0xFFFF0012      # Bàn phím: ghi để quét hàng và kích hoạt ngắt
.eqv KPMATRIX_OUT, 0xFFFF0014      # Bàn phím: đọc để lấy mã phím đang nhấn

.data
# Bảng mẫu cho LED 7 đoạn: 0–9, 'E', '-'
led7_map:
    .byte 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x79, 0x40

# Bảng mã scan keypad (0–F)
kp_decode:
    .word 0x11, 0x21, 0x41, 0x81, 0x12, 0x22, 0x42, 0x82, 0x14, 0x24, 0x44, 0x84, 0x18, 0x28, 0x48, 0x88

# Biến trạng thái (đặt tên mới hoàn toàn)
numA:      .word 0    # toán hạng đầu tiên
op_code:   .word 0    # mã phép toán
num_disp:  .word 0    # số đang nhập hoặc kết quả hiển thị
step:      .word 0    # trạng thái (0: nhập numA, 1: nhập numB, 2: xem kết quả)

.text
.globl main
main:
    li s0, 0      # s0 = numA
    li s2, 0      # s2 = op_code
    li s3, 0      # s3 = num_disp
    li s4, 0      # s4 = step

    la s8, numA
    sw s0, 0(s8)
    la s9, op_code
    sw s2, 0(s9)
    la s10, num_disp
    sw s3, 0(s10)
    la s11, step
    sw s4, 0(s11)

    jal int_setup
    jal show_display

main_wait:
    nop
    j main_wait

# ------------------------------------------
# Ngắt ngoại vi bàn phím
# ------------------------------------------
int_setup:
    la t0, keyboard_irq
    csrrw zero, utvec, t0
    li t1, 0x100
    csrrs zero, uie, t1
    csrrsi zero, ustatus, 1
    li t0, KPMATRIX_IN
    li t1, 0x80
    sb t1, 0(t0)
    ret

# ------------------------------------------
# Hiển thị 2 số cuối lên 2 led 7 đoạn
# ------------------------------------------
show_display:
    la t5, led7_map
    mv t0, s3
    li t1, -1000
    beq t0, t1, disp_err
    li t1, 100
    rem t0, t0, t1

    bgez t0, disp_pos
    li t1, 11
    add t1, t5, t1
    lb t2, 0(t1)
    li t3, SEG7_LEFT
    sb t2, 0(t3)
    neg t0, t0
    j disp_digits

disp_pos:
    li t1, 10
    div t2, t0, t1
    add t2, t5, t2
    lb t3, 0(t2)
    li t4, SEG7_LEFT
    sb t3, 0(t4)

disp_digits:
    li t1, 10
    rem t2, t0, t1
    add t2, t5, t2
    lb t3, 0(t2)
    li t4, SEG7_RIGHT
    sb t3, 0(t4)
    ret

disp_err:
    la t5, led7_map
    li t1, 10
    add t1, t5, t1
    lb t2, 0(t1)
    li t3, SEG7_LEFT
    sb t2, 0(t3)
    li t3, SEG7_RIGHT
    sb t2, 0(t3)
    ret

# ------------------------------------------
# Tính toán kết quả (numA, numB, op_code)
# ------------------------------------------
calc_proc:
    li t0, 1
    beq s2, t0, calc_add
    li t0, 2
    beq s2, t0, calc_sub
    li t0, 3
    beq s2, t0, calc_mul
    li t0, 4
    beq s2, t0, calc_div
    li t0, 5
    beq s2, t0, calc_mod
    j calc_done

calc_add:
    add s0, s0, s1
    j calc_done
calc_sub:
    sub s0, s0, s1
    j calc_done
calc_mul:
    mul s0, s0, s1
    j calc_done
calc_div:
    beq s1, zero, calc_div0
    div s0, s0, s1
    j calc_done
calc_mod:
    beq s1, zero, calc_div0
    rem s0, s0, s1
    j calc_done
calc_div0:
    li s0, -1000
calc_done:
    ret

# ------------------------------------------
# Trình phục vụ ngắt ISR (Interrupt Service Routine)
# ------------------------------------------
keyboard_irq:
    addi sp, sp, -48
    sw ra,  0(sp)
    sw t0,  4(sp)
    sw t1,  8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    sw t6, 28(sp)
    sw s0, 32(sp)
    sw s2, 36(sp)
    sw s3, 40(sp)
    sw s4, 44(sp)

    la s8, numA
    lw s0, 0(s8)
    la s9, op_code
    lw s2, 0(s9)
    la s10, num_disp
    lw s3, 0(s10)
    la s11, step
    lw s4, 0(s11)

    li t1, 0
    li t3, 1
kp_scan:
    li t0, KPMATRIX_IN
    sb t3, 0(t0)
    li t0, KPMATRIX_OUT
    lbu t1, 0(t0)
    bne t1, zero, kp_found
    slli t3, t3, 1
    li t0, 0x10
    blt t3, t0, kp_scan
    j irq_done

kp_found:
    la t0, kp_decode
    li t6, 0
    li t2, 16
kp_decode_loop:
    lw t3, 0(t0)
    beq t3, t1, kp_decode_ok
    addi t0, t0, 4
    addi t6, t6, 1
    addi t2, t2, -1
    bnez t2, kp_decode_loop
    li t6, -1
kp_decode_ok:
    blt t6, zero, irq_done

    li t1, 9
    bgt t6, t1, kp_is_op

# --------- Nếu là số ---------
    li t1, 2
    bne s4, t1, kp_append_digit
    li s3, 0
    li s4, 0
kp_append_digit:
    li t1, 10
    mul s3, s3, t1
    add s3, s3, t6
    jal show_display
    j kp_save_exit

# --------- Nếu là toán tử hoặc '=' ---------
kp_is_op:
    li t1, 15
    beq t6, t1, kp_is_eq
    li t1, 2
    bne s4, t1, kp_storeA
    mv s0, s3
kp_storeA:
    mv s0, s3
    addi s2, t6, -9
    li s3, 0
    li s4, 1
    jal show_display
    j kp_save_exit

kp_is_eq:
    li t1, 2
    beq s4, t1, irq_done
    mv s1, s3
    jal calc_proc
    mv s3, s0
    li s4, 2
    jal show_display

kp_save_exit:
    la s8, numA
    sw s0, 0(s8)
    la s9, op_code
    sw s2, 0(s9)
    la s10, num_disp
    sw s3, 0(s10)
    la s11, step
    sw s4, 0(s11)

irq_done:
    lw ra,  0(sp)
    lw t0,  4(sp)
    lw t1,  8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    lw t6, 28(sp)
    lw s0, 32(sp)
    lw s2, 36(sp)
    lw s3, 40(sp)
    lw s4, 44(sp)
    addi sp, sp, 48
    li t0, KPMATRIX_IN
    li t1, 0x80
    sb t1, 0(t0)
    uret
