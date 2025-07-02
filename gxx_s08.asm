# Dinh nghia dia chi thiet bi ngoai vi
.eqv LED_RIGHT_ADDR     0xFFFF0010  # Dia chi LED 7 thanh ben phai
.eqv LED_LEFT_ADDR      0xFFFF0011  # Dia chi LED 7 thanh ben trai
.eqv KEYPAD_INPUT       0xFFFF0012  # Dia chi dau vao keypad
.eqv KEYPAD_OUTPUT      0xFFFF0014  # Dia chi dau ra keypad

# Dinh nghia cac hang so
.eqv ERROR_CODE         -1000       # Ma loi khi chia cho 0
.eqv MODE_INPUT_FIRST   0           # Che do nhap so thu nhat
.eqv MODE_INPUT_SECOND  1           # Che do nhap so thu hai
.eqv MODE_SHOW_RESULT   2           # Che do hien thi ket qua
.eqv KEYPAD_ENABLE      0x80        # Gia tri kich hoat keypad

.data
# Bang ma hoa LED 7 thanh cho cac chu so va ky hieu
led_patterns:    .byte 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x79, 0x40
# Chi so: 0='0', 1='1', 2='2', 3='3', 4='4', 5='5', 6='6', 7='7', 8='8', 9='9', 10='E'(loi), 11='-'(am)

# Bang tra cuu ma phim keypad theo thu tu 0-F (phim 0 den phim F)
key_matrix:      .word 0x11, 0x21, 0x41, 0x81, 0x12, 0x22, 0x42, 0x82, 0x14, 0x24, 0x44, 0x84, 0x18, 0x28, 0x48, 0x88

# Cau truc du lieu luu tru trang thai may tinh
calculator_state:
    first_operand:   .word 0     # Toan hang dau tien
    operation_code:  .word 0     # Ma phep toan (1:+, 2:-, 3:*, 4:/, 5:%)
    display_value:   .word 0     # Gia tri hien thi hien tai tren LED
    calc_mode:       .word 0     # Che do hoat dong cua may tinh

.text
.globl main


main:
   
    jal init_calculator      # Khoi tao trang thai ban dau
    jal init_keypad_interrupt # Thiet lap ngat ban phim
    jal refresh_display      # Cap nhat hien thi LED

main_loop:
    wfi           # Cho ngat (wait for interrupt)
    j main_loop   # Lap vo han de cho ngat xay ra


init_calculator:
    la t0, calculator_state  # Lay dia chi cau truc trang thai
    sw zero, 0(t0)          # first_operand = 0
    sw zero, 4(t0)          # operation_code = 0
    sw zero, 8(t0)          # display_value = 0
    sw zero, 12(t0)         # calc_mode = 0
    ret


init_keypad_interrupt:
    la t0, interrupt_handler    # Lay dia chi ham xu ly ngat
    csrrw zero, utvec, t0       # Dat dia chi ISR vao thanh ghi ngat
    li t1, 0x100                # Mask cho ngat timer
    csrrs zero, uie, t1         # Bat ngat timer
    csrrsi zero, ustatus, 1     # Bat ngat toan cuc
    
    # Kich hoat che do quet keypad
    li t0, KEYPAD_INPUT         # Lay dia chi dau vao keypad
    li t1, KEYPAD_ENABLE        # Gia tri kich hoat
    sb t1, 0(t0)               # Gui tin hieu kich hoat
    ret


refresh_display:
    la t0, calculator_state     # Lay dia chi trang thai may tinh
    lw t1, 8(t0)               # Lay gia tri display_value
    
    # Kiem tra ma loi chia cho 0
    li t2, ERROR_CODE          # Lay ma loi
    beq t1, t2, show_error     # Neu co loi thi hien thi "EE"
    
    # Chuan bi hien thi so binh thuong
    la t3, led_patterns        # Lay dia chi bang ma LED
    li t4, 100                 # Chia lay du 100
    rem t1, t1, t4             # Chi lay 2 chu so cuoi cung
    
    # Xu ly so am
    bgez t1, display  # Neu so duong thi bo qua
    
    # Hien thi dau '-' cho so am
    li t5, 11                  # Chi so cua dau '-' trong bang
    add t5, t3, t5             
    lb t6, 0(t5)               # Lay ma LED cua dau '-'
    li t5, LED_LEFT_ADDR       
    sb t6, 0(t5)               # Hien thi dau '-' tren LED trai
    neg t1, t1                 
    j display_units           
    
display:
    # Hien thi chu so hang chuc
    li t4, 10                  
    div t5, t1, t4             # Lay chu so hang chuc
    add t5, t3, t5             
    lb t6, 0(t5)              
    li t5, LED_LEFT_ADDR       
    sb t6, 0(t5)               # Hien thi tren LED trai
    
display_units:
    # Hien thi chu so hang don vi
    li t4, 10                  
    rem t5, t1, t4             # Lay chu so hang don vi
    add t5, t3, t5            
    lb t6, 0(t5)               # Lay ma LED
    li t5, LED_RIGHT_ADDR     
    sb t6, 0(t5)               
    ret

show_error:
    # Hien thi "EE" khi co loi
    la t3, led_patterns        # Lay dia chi bang ma LED
    li t4, 10                  # Chi so cua chu 'E'
    add t4, t3, t4             # Tinh dia chi pattern chu 'E'
    lb t5, 0(t4)               # Lay ma LED cua chu 'E'
    li t6, LED_LEFT_ADDR       # Dia chi LED trai
    sb t5, 0(t6)               # Hien thi 'E' tren LED trai
    li t6, LED_RIGHT_ADDR      # Dia chi LED phai
    sb t5, 0(t6)               # Hien thi 'E' tren LED phai
    ret
    
perform_calculation:
    la t0, calculator_state    # Lay dia chi trang thai may tinh
    lw t1, 0(t0)              # Lay first_operand
    lw t2, 4(t0)              # Lay operation_code
    lw t3, 8(t0)              # Lay display_value (toan hang thu 2)
    
    # Kiem tra tung phep toan bang cach so sanh operation_code
    li t4, 1                  # Ma phep cong
    beq t2, t4, do_add        # Neu la phep cong
    li t4, 2                  # Ma phep tru
    beq t2, t4, do_sub        # Neu la phep tru
    li t4, 3                  # Ma phep nhan
    beq t2, t4, do_mul        # Neu la phep nhan
    li t4, 4                  # Ma phep chia
    beq t2, t4, do_div        # Neu la phep chia
    li t4, 5                  # Ma phep chia lay du
    beq t2, t4, do_mod        # Neu la phep chia lay du
    j calc_end                # Khong co phep toan nao

do_add:
    add t1, t1, t3            # Thuc hien phep cong
    j calc_end
do_sub:
    sub t1, t1, t3            # Thuc hien phep tru
    j calc_end
do_mul:
    mul t1, t1, t3            # Thuc hien phep nhan
    j calc_end
do_div:
    beq t3, zero, calc_error  # Kiem tra chia cho 0
    div t1, t1, t3            # Thuc hien phep chia
    j calc_end
do_mod:
    beq t3, zero, calc_error  # Kiem tra chia cho 0
    rem t1, t1, t3            # Thuc hien phep chia lay du
    j calc_end
calc_error:
    li t1, ERROR_CODE         # Gan ma loi
calc_end:
    # Luu ket qua vao display_value
    la t0, calculator_state   # Lay dia chi trang thai
    sw t1, 8(t0)             # Cap nhat display_value
    ret


interrupt_handler:
    # Luu context (cac thanh ghi dang su dung)
    addi sp, sp, -32          # Tao khong gian tren stack
    sw ra, 0(sp)              # Luu return address
    sw t0, 4(sp)              # Luu cac thanh ghi tam
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw t3, 16(sp)
    sw t4, 20(sp)
    sw t5, 24(sp)
    sw t6, 28(sp)

    # Quet va giai ma phim duoc nhan
    jal scan_keypad           # Goi ham quet keypad
    bltz t0, exit_interrupt   # Neu khong co phim nao thi thoat
    
    # Phan loai phim: so (0-9) hay toan tu (A-F)
    li t1, 9                  # Nguong phan chia
    ble t0, t1, handle_digit  # Neu <= 9 thi la phim so
    j handle_operator         # Nguoc lai la phim toan tu

# Xu ly phim so (0-9)
handle_digit:
    la t1, calculator_state   # Lay dia chi trang thai
    lw t2, 12(t1)            # Lay calc_mode
    
    # Neu dang o che do hien thi ket qua, reset de nhap so moi
    li t3, MODE_SHOW_RESULT   # Ma che do hien thi ket qua
    bne t2, t3, add_digit_to_display  # Neu khong phai che do ket qua
    sw zero, 8(t1)           # Reset display_value = 0
    sw zero, 12(t1)          # Chuyen ve che do nhap so dau tien
    
add_digit_to_display:
    lw t2, 8(t1)             # Lay gia tri hien tai tren display
    li t3, 10                # Nhan voi 10
    mul t2, t2, t3           # Dich cac chu so sang trai
    add t2, t2, t0           # Them chu so moi vao cuoi
    sw t2, 8(t1)             # Cap nhat display_value
    j refresh_and_exit       # Cap nhat hien thi va thoat

# Xu ly phim toan tu (A-F)
handle_operator:
    li t1, 15                # Ma phim F (dau =)
    beq t0, t1, handle_equals # Neu la phim = thi xu ly rieng
    
    # Xu ly cac phim toan tu (A, B, C, D, E)
    la t1, calculator_state   # Lay dia chi trang thai
    lw t2, 12(t1)            # Lay calc_mode
    
    # Neu da co phep toan truoc do, tinh ket qua truoc khi luu phep toan moi
    li t3, MODE_INPUT_SECOND  # Ma che do nhap so thu hai
    bne t2, t3, store_operation # Neu chua co phep toan truoc
    jal perform_calculation   # Tinh ket qua phep toan truoc
    
store_operation:
    la t1, calculator_state   # Lay dia chi trang thai
    lw t2, 8(t1)             # Lay gia tri hien thi
    sw t2, 0(t1)             # Luu vao first_operand
    addi t3, t0, -9          # Chuyen doi A-E (10-14) thanh 1-5
    sw t3, 4(t1)             # Luu operation_code
    sw zero, 8(t1)           # Reset display_value
    li t3, MODE_INPUT_SECOND  # Chuyen sang che do nhap so thu hai
    sw t3, 12(t1)            # Cap nhat calc_mode
    j refresh_and_exit       # Cap nhat hien thi va thoat

handle_equals:
    la t1, calculator_state   # Lay dia chi trang thai
    lw t2, 12(t1)            # Lay calc_mode
    li t3, MODE_SHOW_RESULT   # Ma che do hien thi ket qua
    beq t2, t3, refresh_and_exit # Neu da o che do ket qua thi bo qua
    
    jal perform_calculation   # Thuc hien phep tinh
    la t1, calculator_state   # Lay dia chi trang thai
    li t2, MODE_SHOW_RESULT   # Chuyen sang che do hien thi ket qua
    sw t2, 12(t1)            # Cap nhat calc_mode

refresh_and_exit:
    jal refresh_display       # Cap nhat hien thi LED

exit_interrupt:
    # Khoi phuc context (cac thanh ghi da luu)
    lw ra, 0(sp)             # Khoi phuc return address
    lw t0, 4(sp)             # Khoi phuc cac thanh ghi tam
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw t3, 16(sp)
    lw t4, 20(sp)
    lw t5, 24(sp)
    lw t6, 28(sp)
    addi sp, sp, 32          # Tra lai khong gian stack
    
    # Tai kich hoat che do quet keypad
    li t0, KEYPAD_INPUT      # Dia chi dau vao keypad
    li t1, KEYPAD_ENABLE     # Gia tri kich hoat
    sb t1, 0(t0)            # Gui tin hieu kich hoat lai
    uret                     # Tro ve tu ngat


scan_keypad:
    li t1, 1                 # Bit mask bat dau (0000 0001)
    li t2, 0                 # Chi so hien tai
    
scan_loop:
    li t0, KEYPAD_INPUT      # Dia chi dau vao keypad
    sb t1, 0(t0)            # Gui tin hieu quet hang/cot hien tai
    li t0, KEYPAD_OUTPUT     # Dia chi dau ra keypad
    lbu t3, 0(t0)           # Doc ket qua quet
    bnez t3, key_found      # Neu co phim duoc nhan
    
    slli t1, t1, 1          # Dich bit mask sang trai (0001 -> 0010 -> 0100...)
    addi t2, t2, 1          # Tang chi so
    li t0, 16               # Tong so vi tri quet
    blt t2, t0, scan_loop   # Lap lai neu chua quet het
    
    li t0, -1               # Khong tim thay phim nao
    ret

key_found:
    # Giai ma phim dua tren bang key_matrix
    la t4, key_matrix       # Lay dia chi bang tra cuu
    li t5, 0                # Bo dem cho vong lap
    
decode_loop:
    lw t6, 0(t4)            # Lay pattern tu bang
    beq t3, t6, decode_found # So sanh voi ket qua doc duoc
    addi t4, t4, 4          # Chuyen den phan tu tiep theo trong bang
    addi t5, t5, 1          # Tang bo dem
    li t6, 16               # Tong so phan tu trong bang
    blt t5, t6, decode_loop # Lap lai neu chua kiem tra het
    
    li t0, -1               # Khong tim thay trong bang
    ret

decode_found:
    mv t0, t5               # Tra ve chi so cua phim (0-15)
    ret
