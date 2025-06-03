.eqv KEYPAD_ROW_PORT   0xFFFF0012
.eqv KEYPAD_READ_PORT  0xFFFF0014
.eqv SEVENSEG_LEFT     0xFFFF0011
.eqv SEVENSEG_RIGHT    0xFFFF0010

.data
led7seg_digit:  .byte 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F # 0-9

.text
.globl main

main:
    li s0, 0      # op1
    li s1, 0      # op2
    li s2, 0      # phép toán: 0=none, 1=+, 2=-, 3=*, 4=/, 5=%
    li s3, 0      # trạng thái: 0=nhập op1, 1=nhập op2

main_loop:
    jal read_keypad      # a0 = mã phím (0 nếu không nhấn)
    beqz a0, sleep

    jal decode_key       # a0 = 0-9 nếu là phím số, 0xFE... nếu là phép toán, 0xFF nếu không hợp lệ

    # ---- Nếu là số ----
    li t1, 0x00
    li t2, 0x09
    blt a0, t1, check_op # Nếu < 0 → không phải số, kiểm tra phép toán
    bgt a0, t2, check_op # Nếu > 9 → không phải số, kiểm tra phép toán

    # Nếu là phím số:
    li t3, 10
    li t4, 0           # t4 = trạng thái nhập op1 hay op2
    beq s3, t4, input_op1
    # Nhập vào op2
    mul s1, s1, t3
    add s1, s1, a0
    mv a0, s1
    jal display
    j sleep

input_op1:
    mul s0, s0, t3
    add s0, s0, a0
    mv a0, s0
    jal display
    j sleep

check_op:
    # ---- Nếu là phép toán ----
    # a0 = 0xA0: + ; 0xB0: - ; 0xC0: * ; 0xD0: / ; 0xE0: % ; 0xF0: =
    li t1, 0xA0
    beq a0, t1, select_add
    li t1, 0xB0
    beq a0, t1, select_sub
    li t1, 0xC0
    beq a0, t1, select_mul
    li t1, 0xD0
    beq a0, t1, select_div
    li t1, 0xE0
    beq a0, t1, select_rem
    li t1, 0xF0
    beq a0, t1, do_equal
    # Nếu không phải gì cả, bỏ qua

    j sleep

select_add:
    li s2, 1
    li s3, 1     # Chuyển trạng thái sang nhập op2
    li s1, 0     # Reset op2
    j sleep
select_sub:
    li s2, 2
    li s3, 1
    li s1, 0
    j sleep
select_mul:
    li s2, 3
    li s3, 1
    li s1, 0
    j sleep
select_div:
    li s2, 4
    li s3, 1
    li s1, 0
    j sleep
select_rem:
    li s2, 5
    li s3, 1
    li s1, 0
    j sleep

do_equal:
    jal calc      # Thực hiện phép toán, kết quả lưu vào s0
    li s3, 0      # Quay về trạng thái nhập op1 mới
    li s2, 0      # Reset phép toán
    li s1, 0      # Reset op2
    mv a0, s0     # Hiển thị kết quả lên LED
    jal display
    j sleep

sleep:
    li a0, 120    # Delay chống rung phím
    j main_loop

# ---------------------------------------
# Hàm đọc keypad (polling), trả về a0: mã phím (hex)
read_keypad:
    li t0, KEYPAD_ROW_PORT
    li t1, KEYPAD_READ_PORT
    li t2, 0x01
    sb t2, 0(t0)
    lb t3, 0(t1)
    bnez t3, found_key
    li t2, 0x02
    sb t2, 0(t0)
    lb t3, 0(t1)
    bnez t3, found_key
    li t2, 0x04
    sb t2, 0(t0)
    lb t3, 0(t1)
    bnez t3, found_key
    li t2, 0x08
    sb t2, 0(t0)
    lb t3, 0(t1)
    bnez t3, found_key
    li a0, 0
    jr ra
found_key:
    mv a0, t3
    jr ra

# ---------------------------------------
# Hàm giải mã phím keypad
# a0: mã phím đầu vào (hex)
# Trả về:
#  - 0..9: phím số
#  - 0xA0: +
#  - 0xB0: -
#  - 0xC0: *
#  - 0xD0: /
#  - 0xE0: %
#  - 0xF0: =
#  - 0xFF: không hợp lệ
decode_key:
    # Mapping cho ma trận bàn phím mẫu này!
    # Bạn đổi mã ở đây cho đúng keypad thực tế của bạn
    li t1, 0x11
     beq a0, t1, key0
    li t1, 0x21
     beq a0, t1, key1
    li t1, 0x41
     beq a0, t1, key2
    li t1, 0x81
    beq a0, t1, key3
    li t1, 0x12
     beq a0, t1, key4
    li t1, 0x22
     beq a0, t1, key5
    li t1, 0x42
     beq a0, t1, key6
    li t1, 0x82
     beq a0, t1, key7
    li t1, 0x14
     beq a0, t1, key8
    li t1, 0x24
     beq a0, t1, key9

    # Mapping phép toán, bạn đổi lại đúng mã phím a,b,c,d,e,f trên sim của bạn!
    li t1, 0x44
     beq a0, t1, key_add    # a
    li t1, 0x84
     beq a0, t1, key_sub    # b
    li t1, 0x18
     beq a0, t1, key_mul    # c
    li t1, 0x28
     beq a0, t1, key_div    # d
    li t1, 0x48
     beq a0, t1, key_rem    # e
    li t1, 0x88
     beq a0, t1, key_eq     # f (=)
    li a0, 0xFF
    jr ra
key0: li a0, 0
 jr ra
key1: li a0, 1
jr ra
key2: li a0, 2
 jr ra
key3: li a0, 3
 jr ra
key4: li a0, 4
jr ra
key5: li a0, 5
jr ra
key6: li a0, 6
jr ra
key7: li a0, 7
 jr ra
key8: li a0, 8
 jr ra
key9: li a0, 9
jr ra
key_add: li a0, 0xA0
 jr ra
key_sub: li a0, 0xB0
 jr ra
key_mul: li a0, 0xC0
 jr ra
key_div: li a0, 0xD0
 jr ra
key_rem: li a0, 0xE0
 jr ra
key_eq:  li a0, 0xF0
 jr ra

# ---------------------------------------
# Hàm thực hiện phép toán
# s0: op1, s1: op2, s2: phép toán (1=+, 2=-, 3=*, 4=/, 5=%)
calc:
    li t0, 1
    beq s2, t0, do_add
    li t0, 2
    beq s2, t0, do_sub
    li t0, 3
    beq s2, t0, do_mul
    li t0, 4
    beq s2, t0, do_div
    li t0, 5
    beq s2, t0, do_rem
    jr ra
do_add:
    add s0, s0, s1
    jr ra
do_sub:
    sub s0, s0, s1
    jr ra
do_mul:
    mul s0, s0, s1
    jr ra
do_div:
    beqz s1, calc_end  # Chia 0, không làm gì
    div s0, s0, s1
    jr ra
do_rem:
    beqz s1, calc_end  # Chia 0, không làm gì
    rem s0, s0, s1
    jr ra
calc_end:
    jr ra

# ---------------------------------------
# Hàm hiển thị số lên 2 LED 7 đoạn
# a0 = số muốn hiển thị (0–99, chỉ lấy 2 số cuối)
display:
    li t0, 100        # Giới hạn 2 số cuối
    remu a0, a0, t0

    li t0, 10
    divu t1, a0, t0   # t2 = hàng chục
    remu t2, a0, t0  # t3 = hàng đơn vị

    la t3, led7seg_digit
    add t4, t3, t1
    lb t5, 0(t4)
    li t6, SEVENSEG_LEFT
    sb t5, 0(t6)
    
    add t4, t3, t2
    lb t5, 0(t4)
    li t6, SEVENSEG_RIGHT
    sb t5, 0(t6)
    jr ra   
