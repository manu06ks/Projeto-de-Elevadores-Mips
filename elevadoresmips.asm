# Sistema de Controle de Elevadores com Teclado Digital Lab Sim
# 
# INSTRUÇÕES DE USO:
# 1. Digite o número do andar desejado (0-7) no teclado hexadecimal
# 2. Pressione C para chamar elevador para SUBIR
# 3. Pressione B para chamar elevador para DESCER
# 4. O elevador mais próximo será enviado
# 5. Os displays mostram a posição atual de cada elevador
#    - Display direito: Elevador A
#    - Display esquerdo: Elevador B
#
# NOTAS:
# - Se ambos elevadores estão à mesma distância, o elevador A tem prioridade
# - O sistema impede chamadas inválidas (ex: pedir para descer do andar 0)
# - Cada elevador move um andar por vez com delay

.data
    # Posições dos elevadores (0-7)
    elevator_a_pos: .word 0
    elevator_b_pos: .word 0
    
    # Destinos dos elevadores (-1 = sem destino)
    elevator_a_dest: .word -1
    elevator_b_dest: .word -1
    
    # Estado do sistema
    current_floor: .word -1    # Andar selecionado
    waiting_direction: .word 0  # 1 = esperando direção
    
    # Mensagens do sistema
    msg_floor_prompt: .asciiz "\r\nAndar (0-7): "
    msg_direction_prompt: .asciiz "\r\nDirecao (C/B): "
    msg_elevator_a: .asciiz "\r\nElevador A: "
    msg_elevator_b: .asciiz "\r\nElevador B: "
    msg_to_floor: .asciiz " -> "
    msg_arrived: .asciiz "\r\nChegou! Andar "
    msg_invalid_floor: .asciiz "\r\nAndar invalido!"
    msg_invalid_call: .asciiz "\r\nChamada invalida!"
    msg_going_up: .asciiz " (SUBINDO)"
    msg_going_down: .asciiz " (DESCENDO)"
    msg_invalid_key: .asciiz "\r\nTecla invalida!"
    msg_key_pressed: .asciiz "\r\nTecla: "
    
    # Tabela para display de 7 segmentos
    display7seg: .byte 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07

.text
.globl main

main:
    # Inicializar displays
    jal update_displays
    
    # Mostrar prompt inicial
    li $v0, 4
    la $a0, msg_floor_prompt
    syscall
    
main_loop:
    # Ler tecla do teclado
    jal read_keyboard
    
    # Se não há tecla pressionada, continuar
    beqz $v0, check_elevators
    
    # Debug: mostrar tecla pressionada
    move $s7, $v0  # Salvar tecla
    
    # Verificar estado atual
    lw $t0, waiting_direction
    bnez $t0, process_direction
    
    # Estado: esperando andar
    # Verificar se é tecla numérica (0-7) baseado no mapeamento da imagem
    li $t0, 0x11    # tecla 0
    beq $s7, $t0, floor_0
    li $t0, 0x21    # tecla 1
    beq $s7, $t0, floor_1
    li $t0, 0x41    # tecla 2
    beq $s7, $t0, floor_2
    li $t0, 0x81    # tecla 3
    beq $s7, $t0, floor_3
    li $t0, 0x12    # tecla 4
    beq $s7, $t0, floor_4
    li $t0, 0x22    # tecla 5
    beq $s7, $t0, floor_5
    li $t0, 0x42    # tecla 6
    beq $s7, $t0, floor_6
    li $t0, 0x82    # tecla 7
    beq $s7, $t0, floor_7
    
    # Tecla inválida
    j invalid_key

floor_0:
    li $t0, 0
    j set_floor
floor_1:
    li $t0, 1
    j set_floor
floor_2:
    li $t0, 2
    j set_floor
floor_3:
    li $t0, 3
    j set_floor
floor_4:
    li $t0, 4
    j set_floor
floor_5:
    li $t0, 5
    j set_floor
floor_6:
    li $t0, 6
    j set_floor
floor_7:
    li $t0, 7

set_floor:
    sw $t0, current_floor
    
    # Mostrar andar selecionado
    li $v0, 1
    move $a0, $t0
    syscall
    
    # Mostrar prompt de direção
    li $v0, 4
    la $a0, msg_direction_prompt
    syscall
    
    # Mudar estado para esperar direção
    li $t0, 1
    sw $t0, waiting_direction
    
    # Aguardar tecla ser liberada
    jal wait_key_release
    
    j check_elevators

process_direction:
    # Estado: esperando direção (B ou C)
    # C está em 0x18 (linha 4, coluna 1)
    li $t0, 0x18    # tecla C (subir)
    beq $s7, $t0, dir_up
    
    # B está em 0x84 (linha 3, coluna 4)
    li $t0, 0x84    # tecla B (descer)
    beq $s7, $t0, dir_down
    
    # Tecla inválida para direção
    li $v0, 4
    la $a0, msg_invalid_key
    syscall
    
    # Aguardar tecla ser liberada
    jal wait_key_release
    j check_elevators

dir_up:
    li $s1, 1       # Direção subir
    j validate_call
    
dir_down:
    li $s1, -1      # Direção descer

validate_call:
    lw $s0, current_floor
    
    # Validar chamada
    li $t0, 7
    beq $s0, $t0, check_up
    beqz $s0, check_down
    j process_call
    
check_up:
    li $t0, 1
    beq $s1, $t0, invalid_call
    j process_call
    
check_down:
    li $t0, -1
    beq $s1, $t0, invalid_call
    j process_call

process_call:
    # Resetar estado
    sw $zero, waiting_direction
    li $t0, -1
    sw $t0, current_floor
    
    # Determinar qual elevador enviar
    jal find_closest_elevator
    
    # $v0 = 0 para elevador A, 1 para elevador B
    beqz $v0, send_elevator_a
    j send_elevator_b

send_elevator_a:
    # Atualizar destino do elevador A
    sw $s0, elevator_a_dest
    
    # Mostrar mensagem
    li $v0, 4
    la $a0, msg_elevator_a
    syscall
    
    li $v0, 1
    lw $a0, elevator_a_pos
    syscall
    
    li $v0, 4
    la $a0, msg_to_floor
    syscall
    
    li $v0, 1
    move $a0, $s0
    syscall
    
    # Mostrar direção
    li $v0, 4
    li $t0, 1
    beq $s1, $t0, show_up_a
    la $a0, msg_going_down
    j print_dir_a
show_up_a:
    la $a0, msg_going_up
print_dir_a:
    syscall
    
    # Aguardar tecla ser liberada
    jal wait_key_release
    
    # Mostrar novo prompt
    li $v0, 4
    la $a0, msg_floor_prompt
    syscall
    
    j check_elevators

send_elevator_b:
    # Atualizar destino do elevador B
    sw $s0, elevator_b_dest
    
    # Mostrar mensagem
    li $v0, 4
    la $a0, msg_elevator_b
    syscall
    
    li $v0, 1
    lw $a0, elevator_b_pos
    syscall
    
    li $v0, 4
    la $a0, msg_to_floor
    syscall
    
    li $v0, 1
    move $a0, $s0
    syscall
    
    # Mostrar direção
    li $v0, 4
    li $t0, 1
    beq $s1, $t0, show_up_b
    la $a0, msg_going_down
    j print_dir_b
show_up_b:
    la $a0, msg_going_up
print_dir_b:
    syscall
    
    # Aguardar tecla ser liberada
    jal wait_key_release
    
    # Mostrar novo prompt
    li $v0, 4
    la $a0, msg_floor_prompt
    syscall

check_elevators:
    # Verificar se há elevadores em movimento
    lw $t0, elevator_a_dest
    lw $t1, elevator_b_dest
    li $t2, -1
    bne $t0, $t2, move_elevators
    bne $t1, $t2, move_elevators
    
    # Pequeno delay
    li $t0, 10000
delay_loop:
    addi $t0, $t0, -1
    bnez $t0, delay_loop
    
    j main_loop

move_elevators:
    # Mover elevadores
    jal move_elevator_step
    
    # Atualizar displays
    jal update_displays
    
    # Delay maior para movimento
    li $t0, 100000
move_delay:
    addi $t0, $t0, -1
    bnez $t0, move_delay
    
    j main_loop

invalid_key:
    li $v0, 4
    la $a0, msg_invalid_key
    syscall
    
    # Aguardar tecla ser liberada
    jal wait_key_release
    j check_elevators

invalid_call:
    # Resetar estado
    sw $zero, waiting_direction
    li $t0, -1
    sw $t0, current_floor
    
    li $v0, 4
    la $a0, msg_invalid_call
    syscall
    
    # Aguardar tecla ser liberada
    jal wait_key_release
    
    # Mostrar novo prompt
    li $v0, 4
    la $a0, msg_floor_prompt
    syscall
    
    j check_elevators

read_keyboard:
    # Endereços do teclado
    lui $t0, 0xFFFF
    ori $t1, $t0, 0x0012    # comando linha
    ori $t2, $t0, 0x0014    # leitura tecla
    
    # Varrer cada linha
    li $t3, 0x01            # linha 1
    li $t4, 4               # 4 linhas
    
scan_loop:
    sb $t3, 0($t1)          # enviar número da linha
    
    # Pequeno delay para estabilizar
    li $t5, 100
kb_delay:
    addi $t5, $t5, -1
    bnez $t5, kb_delay
    
    lbu $t6, 0($t2)         # ler coluna
    beqz $t6, next_line     # se zero, nenhuma tecla
    
    # Construir código da tecla (linha + coluna)
    or $v0, $t3, $t6        # combinar linha e coluna
    jr $ra
    
next_line:
    sll $t3, $t3, 1         # próxima linha (1,2,4,8)
    addi $t4, $t4, -1
    bnez $t4, scan_loop
    
    # Nenhuma tecla pressionada
    li $v0, 0
    jr $ra

wait_key_release:
    # Aguarda tecla ser liberada
    move $s6, $ra           # Salvar endereço de retorno
wait_release:
    jal read_keyboard
    bnez $v0, wait_release
    
    # Pequeno delay adicional
    li $t0, 5000
debounce:
    addi $t0, $t0, -1
    bnez $t0, debounce
    
    move $ra, $s6           # Restaurar endereço de retorno
    jr $ra

find_closest_elevator:
    # Carregar posições atuais
    lw $t0, elevator_a_pos
    lw $t1, elevator_b_pos
    
    # Verificar se elevadores estão ocupados
    lw $t2, elevator_a_dest
    lw $t3, elevator_b_dest
    li $t4, -1
    
    # Se A está ocupado mas B não, usar B
    bne $t2, $t4, check_b_busy
    beq $t3, $t4, both_free
    li $v0, 0
    jr $ra
    
check_b_busy:
    beq $t3, $t4, use_b
    
both_free:
    # Calcular distância A
    sub $t2, $s0, $t0
    bgez $t2, dist_a_positive
    sub $t2, $zero, $t2
dist_a_positive:
    
    # Calcular distância B
    sub $t3, $s0, $t1
    bgez $t3, dist_b_positive
    sub $t3, $zero, $t3
dist_b_positive:
    
    # Comparar distâncias
    blt $t2, $t3, use_a
    bgt $t2, $t3, use_b
    
use_a:
    li $v0, 0
    jr $ra
    
use_b:
    li $v0, 1
    jr $ra

move_elevator_step:
    # Mover elevador A se tem destino
    lw $t0, elevator_a_dest
    li $t1, -1
    beq $t0, $t1, check_elevator_b
    
    # Carregar posição atual de A
    lw $t2, elevator_a_pos
    
    # Verificar se chegou ao destino
    beq $t2, $t0, arrived_a
    
    # Mover elevador A
    blt $t2, $t0, move_a_up
    addi $t2, $t2, -1
    j update_a_pos
move_a_up:
    addi $t2, $t2, 1
update_a_pos:
    sw $t2, elevator_a_pos
    j check_elevator_b
    
arrived_a:
    # Elevador A chegou
    li $v0, 4
    la $a0, msg_arrived
    syscall
    
    li $v0, 1
    move $a0, $t0
    syscall
    
    # Limpar destino
    li $t1, -1
    sw $t1, elevator_a_dest

check_elevator_b:
    # Mover elevador B se tem destino
    lw $t0, elevator_b_dest
    li $t1, -1
    beq $t0, $t1, move_done
    
    # Carregar posição atual de B
    lw $t2, elevator_b_pos
    
    # Verificar se chegou ao destino
    beq $t2, $t0, arrived_b
    
    # Mover elevador B
    blt $t2, $t0, move_b_up
    addi $t2, $t2, -1
    j update_b_pos
move_b_up:
    addi $t2, $t2, 1
update_b_pos:
    sw $t2, elevator_b_pos
    j move_done
    
arrived_b:
    # Elevador B chegou
    li $v0, 4
    la $a0, msg_arrived
    syscall
    
    li $v0, 1
    move $a0, $t0
    syscall
    
    # Limpar destino
    li $t1, -1
    sw $t1, elevator_b_dest

move_done:
    jr $ra

update_displays:
    # Endereços dos displays
    lui $t0, 0xFFFF
    ori $t0, $t0, 0x0010  # Display direito
    lui $t1, 0xFFFF
    ori $t1, $t1, 0x0011  # Display esquerdo
    
    # Display A (direito)
    lw $t2, elevator_a_pos
    la $t3, display7seg
    add $t3, $t3, $t2
    lbu $t4, 0($t3)
    sb $t4, 0($t0)
    
    # Display B (esquerdo)
    lw $t2, elevator_b_pos
    la $t3, display7seg
    add $t3, $t3, $t2
    lbu $t4, 0($t3)
    sb $t4, 0($t1)
    
    jr $ra
