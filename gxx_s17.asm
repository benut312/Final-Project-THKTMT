.eqv IN_ADDRESS_HEXA_KEYBOARD 0xFFFF0012 # ??a ch? phát hi?n phím
.eqv OUT_ADDRESS_HEXA_KEYBOARD 0xFFFF0014
.eqv SEVENSEG_LEFT 0xFFFF0011 # hi?n th? ohims lên keyboard
.eqv SEVENSEG_RIGHT 0xFFFF0010

.data
A: .byte 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F # dùng ?? hi?n th? ?úng s? lên thi?t b? keyboard
B: .word 31,28,31,30,31,30,31,31,30,31,30,31 # s? ngày trong tháng
newline:.asciz "\n"

.text
main:
    li a7,30 # l?y ra th?i gian th?c t? h? th?ng tính b?ng ms
    ecall
    addi s0,a0,0 # s0 dùng ?? l?y ra 32 bit th?p
    addi s1,a1,0 # s1 dùng ?? l?y ra 32 bit cao
    slli t0, a0,16 # t0 l?u 16 bit ??u tiên c?a a0
    srli t0,t0,16
    srli t1,s0,16 # t1 l?u 16 bit ti?p theo c?a a0
    slli t2,a1,16 # t2 l?u 16 bit ??u tiên c?a a1
    srli t2,t2,16
    srli t3,s1,16 # t3 l?u 16 bit ti?p theo c?a a1
    li t4,0
    li t5,65536 # 2^16
    li t6,1000 # chia cho 1000 ?? chuy?n v? th?i gian s

    mul s2,t4,t5
    add s2,s2,t3
    div t3,s2,t6
    rem t4,s2,t6
    mul s2,t4,t5
    
    add s2,s2,t2
    div t2,s2,t6
    rem t4,s2,t6
    mul s2,t4,t5
    
    add s2,s2,t1
    div t1,s2,t6
    rem t4,s2,t6
    mul s2,t4,t5

    add s2,s2,t0
    div t0,s2,t6
    rem t4,s2,t6
    
    slli t1,t1,16 # d?ch trái 16 ??n v? ?? có th? l?y ra t1+t2 b?ng s? s t? 1/1/1970 ??n hi?n t?i
    add t2,t1,t0 # ghi tong so s
    li s2,1970 # s? n?m bat dau 1970
    li s3,31536000 # so s trong 1 nam
    li s4,4 # ?? bi?t n?m nhu?n hay không
    li s5,86400 # th?i gian 1 ngày
    la a3,B # ??a ch? m?ng B ghi so ngay trong 1 thang
    li s6,1 # thang
    li a6,1
    li s11,2

loop_year: # dem so nam
    blt t2,s3,month # neu thoi con lai ma nho hon nam thi xu li thang
    sub t2,t2,s3 # tru di thoi gian mot nam
    addi s2,s2,1 # tang nam
    rem t5,s2,s4 # chia cho 4 de biet nam nhuan hay khong
    beq t5,zero,xuli # nam nhuan nhay den xuli
    j loop_year

xuli:
    sub t2,t2,s5 # tru thoi gian di them 1 ngay nua
    j loop_year

month:
    lw t3,0(a3) # load so ngay trong 1 thang
    mul t6,t3,s5 # nhan thoi gian so ngay trong 1 thang voi so giay trong mot ngay
    blt t2,t6,day # neu thoi gian nho hon so giay trong 1 ngay thi xu li ngay
    sub t2,t2,t6 # tru di so s trong mot ngya
    addi a3,a3,4 # con tro tro den thang tiep theo
    addi s6,s6,1 # tang thang len
    beq s6,s11,check # check xem nam nhuan
    j month

check: # neu la nam nhuan
    rem s10,s2,s4
    beq s10,zero,check1
    j month

check1: # tru thoi gian di them 1 ngay nua
    sub t2,t2,t6
    j month

day:
    blt t2,s5,hour # thoi gian nho hon 1 ngay thi xu li h
    sub t2,t2,s5 # tru di so ngay
    addi a6,a6,1 # tang ngay len
    j day

hour:
    li t3,3600 # 1 gi? = 3600 giây
    li s7,0 # bi?n l?u gi?

hour_loop:
    blt t2,t3,minute # neu nho hon so s thi se xu li phut
    sub t2,t2,t3 # tru di so giay trong 1 h
    addi s7,s7,1 # tang bien h len
    j hour_loop

minute:
    addi s7,s7,7 # cong them h cho 7 bi lech so voi h viet nam 7 tieng
    li t3,60 # 1 phút = 60 giây
    li t4,0 # bi?n l?u phút

minute_loop:
    blt t2,t3,second
    sub t2,t2,t3
    addi t4,t4,1
    j minute_loop

second:
    mv t5,t2 # t2 luu dia chi cua s

# s2: n?m
# s6 : tháng
# a6 ngày
# s7 : h
# t4 : p
# t2 :s
    li a2,10
    li s8,100
    rem s2,s2,s8 # lay ra 2 so cuoi cua nam
    li s9,0

check_second: # phat am thanh neu 60s thi se phat 1 lan
    beqz t2, sound
    li t3, 59
    beq t2, t3, sound

polling:
    li t1, IN_ADDRESS_HEXA_KEYBOARD
    li t5, OUT_ADDRESS_HEXA_KEYBOARD
    li t3,0x01 # dong dau tien trong ma tran keyboard
    sb t3,0(t1)
    lb s9,0(t5)
    bne s9,zero,print
    li t3,0x02 # dong thu 2 trong ma tran keyboard
    sb t3,0(t1)
    lb s9,0(t5)
    bne s9,zero,print
    j main

print:
    li a3,0x21 # so 1 thi se hien h
    beq s9,a3,print_hour
    li a3,0x41 # so 2 thi se hien phut
    beq s9,a3,print_minute
    li a3,0xffffff81 # so 3 thi se hien s
    beq s9,a3,print_s
    li a3,0x12 # so 4 thi se hien ngay
    beq s9,a3,print_day
    li a3,0x22 # so 5 thi se hien thang
    beq s9,a3,print_month
    li a3,0x42 # so 6 thi se hien nam
    beq s9,a3,print_year
    li t0, SEVENSEG_LEFT
    li t1, SEVENSEG_RIGHT
    li t2, 0x00
    sb t2, 0(t0)
    sb t2, 0(t1)
    j main

# tat ca deu xu dung thanh ghi a4
print_hour:
    addi a4,s7,0
    j display

print_minute:
    addi a4,t4,0
    j display

print_s:
    addi a4,t2,0
    j display

print_day:
    addi a4,a6,0
    j display

print_month:
    addi a4,s6,0
    j display

print_year:
    addi a4,s2,0
    j display

display:
    rem a5,a4,a2 # so hang don vi
    div a4,a4,a2 # so hang chuc
    la t0,A
    add t0,t0,a4
    lb a0,0(t0)
    jal SHOW_7SEG_LEFT # show
    la t0,A
    add t0,t0,a5
    lb a0,0(t0)
    jal SHOW_7SEG_RIGHT # show
    j main

SHOW_7SEG_LEFT:
    li t0, SEVENSEG_LEFT
    sb a0, 0(t0)
    jr ra

SHOW_7SEG_RIGHT:
    li t0, SEVENSEG_RIGHT
    sb a0, 0(t0)
    jr ra

sound:
    li a7, 33
    ecall
    j polling

