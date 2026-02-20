; If you want to learn how make a Assembly cursor, this project is for you

[BITS 16]
[ORG 0x7C00]

start:
    ; Configuration
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; VGA mode config
    mov ax, 0x0013
    int 0x10

    ; Start mouse
    call InitMouse
    call EnableMouse

    ; Infinity loop
    main_idle:
        hlt             ; Don't use much of your CPU
        jmp main_idle

; --- Constants ---
%define WCURSOR 8
%define HCURSOR 11

; MOUSE FUNCTIONS

InitMouse:
    mov ax, 0xC205
    mov bh, 0x03
    int 0x15
    jc mouse_error
    
    mov ax, 0xC203
    mov bh, 0x03
    int 0x15
    ret

EnableMouse:
    mov ax, 0xC207
    mov bx, MouseCallback
    int 0x15

    ; This part activate mouse
    mov ax, 0xC200
    mov bh, 0x01
    int 0x15
    ret

; CALLBACK, made with Gemini. If you don't understand portuguese, use your transatle
MouseCallback:
    push bp
    mov bp, sp
    pusha
    push ds
    push es

    xor ax, ax
    mov ds, ax          ; DS = 0

    call HideCursor     ; Apaga o cursor na posição antiga

    ; --- Ler Dados da Pilha ---
    ; [bp+12] = Status (Botões e Sinais)
    ; [bp+10] = Delta X
    ; [bp+8]  = Delta Y

    mov al, [bp + 12]   ; Byte de status
    mov bl, al          ; Salva status em BL

    ; --- Processar Eixo X ---
    mov ax, [bp + 10]   ; Pega Delta X
    and ax, 0x00FF      ; Garante que AX só tem o byte baixo
    test bl, 0x10       ; Testa o bit de sinal de X (bit 4)
    jz .x_pos
    or ax, 0xFF00       ; Se era negativo, preenche o byte alto com 1s
.x_pos:
    add [MouseX], ax

    ; --- Processar Eixo Y ---
    mov ax, [bp + 8]    ; Pega Delta Y
    and ax, 0x00FF      ; Garante que AX só tem o byte baixo
    test bl, 0x20       ; Testa o bit de sinal de Y (bit 5)
    jz .y_pos
    or ax, 0xFF00       ; Se era negativo, preenche o byte alto com 1s
.y_pos:
    sub [MouseY], ax    ; PS/2 Y é invertido em relação à tela

    ; --- Clipping (Garantir que não saia da tela 320x200) ---
    ; Limite X
    cmp word [MouseX], 0
    jg .not_min_x
    mov word [MouseX], 0
.not_min_x:
    cmp word [MouseX], 312
    jl .not_max_x
    mov word [MouseX], 312
.not_max_x:

    ; Limite Y
    cmp word [MouseY], 0
    jg .not_min_y
    mov word [MouseY], 0
.not_min_y:
    cmp word [MouseY], 188
    jl .not_max_y
    mov word [MouseY], 188
.not_max_y:

    ; --- Desenhar Novo Cursor ---
    mov si, mousebmp
    mov al, 0x0F        ; Branco
    call DrawCursor

    pop es
    pop ds
    popa
    pop bp
    retf

DrawCursor:
    pusha
    mov ah, 0x0C        ; BIOS Write Pixel
    mov bh, 0x00        ; Page 0
    mov dx, [MouseY]    ; Inital line

    mov si, mousebmp    ; Bitmap
    mov di, 0           ; DI is our counter

    .loopY:
        push si         ; Save cursor bitmap
        add si, di      ; SI now, in inital line
        mov bl, [si]    ; Loads the actual byte
        pop si          ; This part restarts SI

        mov cx, [MouseX] ; The initial column
        
        mov bp, 8        ; 8 bits per byte, cursor size
        .loopX:
            test bl, 0x80
            jz .skip
            int 0x10
        .skip:
            inc cx
            shl bl, 1
            dec bp
            jnz .loopX

        inc dx 
        inc di
        cmp di, HCURSOR
        jne .loopY

    popa
    ret

HideCursor:
    pusha
    mov si, mousebmp
    mov al, 0x00        ; Black color
    call DrawCursor
    popa
    ret

mouse_error:
    mov ax, 0x0E45
    int 0x10
    jmp $

; --- Data ---
MouseX: dw 160
MouseY: dw 100
mousebmp:
    db 0b10000000, 0b11000000, 0b11100000, 0b11110000
    db 0b11111000, 0b11111100, 0b11111110, 0b11111000
    db 0b11011100, 0b10001110, 0b00000110

; --- BOOTLOADER ---
times 510-($-$$) db 0
dw 0xAA55