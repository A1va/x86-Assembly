assume cs:code,ss:stacksg
stacksg segment
    db 128 dup (0)
stacksg ends
code segment
start:
    mov ax,stacksg
    mov ss,ax
    mov sp,128

    ; 将程序粘贴到0:7E00H:(0面0道2扇区:7C00H+512)
    ; 其实只要在实模式1M内存内即可，当然最好是在第一个扇区512之后
    call COPY_BOOT

    ; 设置CS:IP为0:7E00H，进而让程序进入BOOT执行
    mov ax,0                            ; CS
    push ax
    mov ax,7E00H                        ; IP
    push ax
    retf                                ; pop IP and CS

    mov ax,4C00H
    int 21H

; 复制BOOT引导程序的内容到0:7E00H
COPY_BOOT:
    mov ax,cs
    mov ds,ax
    mov si,offset BOOT

    mov ax,0
    mov es,ax
    mov di,7E00H                        ; 0面0道2扇区

    mov cx,offset BOOT_END - offset BOOT
    cld
    rep movsb
    ret                                 ; call paired with ret

BOOT:
    jmp BOOT_START
FUNC_0          db 'Nolva  reference:Mayfly',0
FUNC_1          db '1) reset PC',0
FUNC_2          db '2) start system',0
FUNC_3          db '3) clock',0
FUNC_4          db '4) set clock',0
; FUNC_ADDR: 绝对位置
; 相减得到的是FUNC_*的相对位置，+7E00H得到绝对位置
FUNC_ADDR       dw offset FUNC_0 - offset BOOT + 7E00H      ; FUNC_ADDR[0]
                dw offset FUNC_1 - offset BOOT + 7E00H      ; FUNC_ADDR[2]
                dw offset FUNC_2 - offset BOOT + 7E00H
                dw offset FUNC_3 - offset BOOT + 7E00H
                dw offset FUNC_4 - offset BOOT + 7E00H
TIME            db 'YY/MM/DD hh:mm:ss',0
TIME_CMOS_ADDRESS    db 9,8,7,4,2,0              ; reference to Lab14
TIME_TIPS       db 'F2--change the color        ESC--return menu',0

BOOT_START:
    call INIT_BOOT
    call CLEAR_SCREEN
    call SHOW_MENU

    jmp CHOOSE_FUNC
    
    mov ax,4C00H
    int 21H

CHOOSE_FUNC:
    call CLEAR_KB_BUFFER
    ; 从键盘缓冲区获取我们输入的数据，跳转到对应的函数
    ; 16H:从键盘缓冲区中读出数据
    ; ah:扫描码，al:ASCII码
    mov ah,0
    int 16H

    cmp al,'1'
    je CHOOSE_FUNC1
    cmp al,'2'
    je CHOOSE_FUNC2
    cmp al,'3'
    je CHOOSE_FUNC3
    cmp al,'4'
    je CHOOSE_FUNC4

    ; not ret, we will jump to FUNC to execute
    jmp CHOOSE_FUNC

CHOOSE_FUNC1:
    ; test
    mov di,160*3
    mov byte ptr es:[di],'1'
    ; TODO reset pc
    jmp CHOOSE_FUNC

CHOOSE_FUNC2:
    ; test
    mov di,160*3
    mov byte ptr es:[di],'2'
    ; TODO start system
    jmp CHOOSE_FUNC

CHOOSE_FUNC3:
    call SHOW_TIME

    jmp CHOOSE_FUNC

CHOOSE_FUNC4:
    ; test
    mov di,160*3
    mov byte ptr es:[di],'4'
    ; set clock
    jmp CHOOSE_FUNC

SHOW_TIME:
    call INIT_BOOT
    call CLEAR_SCREEN
    ; 显示按键提示
    mov si, offset TIME_TIPS - offset BOOT + 7E00H
    mov di, 160*20+17*2; 第19行第16列
    call SHOW_LINE

SHOW_TIMES:
    ; 获取时间信息，并显示(将time中的未知字符替换为当前时间)
    call GET_TIME
    mov di,160*11+30*2; 时间显示在第10行第29列
    mov si, offset TIME - offset BOOT + 7E00H
    call SHOW_LINE

    ; 获取键盘缓冲区的数据
    mov ah,1
    int 16H
    ; 键盘缓冲栈为空(无按键)，就跳回SHOW_TIMES
    jz SHOW_TIMES
    ; 是否按下F2
    cmp ah,3CH
    je CHANGE_COLOR
    ; 是否按下ESC
    cmp ah,1
    je RETURN_MAIN
    ; 其他无意义的按键，清除
    cmp al,0
    jne CLEAR_KB_BUFFER2
    ; 清除后，循环显示，刷新时间
    jmp SHOW_TIMES
    
CLEAR_KB_BUFFER2:
    call CLEAR_KB_BUFFER
    jmp SHOW_TIMES

GET_TIME:
    ; 从CMOS RAM获取(年/月/日 时:分:秒) 6个数据
    mov cx,6
    ; 获取存放单元地址
    mov bx,offset TIME - offset BOOT + 7E00H
    ; 时间格式
    mov si,offset TIME_CMOS_ADDRESS - offset BOOT + 7E00H

; 与Lab14的get循环一致
SHOW_DATE:
    push cx
    mov al,ds:[si]
    out 70H,al
    in al,71H
    mov ah,al
    mov cl,4
    shr al,cl
    and ah,00001111B
    add ah,30H
    add al,30H
    mov ds:[bx],ax
    inc si
    add bx,3
    pop cx
    loop SHOW_DATE
    ret

CHANGE_COLOR:
    call CHANGE_COLOR_START
    call CLEAR_KB_BUFFER
    jmp SHOW_TIMES

CHANGE_COLOR_START:
    push bx
    push cx
 
    mov cx,2000
    mov bx,1
NEXT_COLOR:
    ; 字符属性值++，改变颜色
    inc byte ptr es:[bx]
    ; 当超出范围(0~1111H)时，重置属性值
    cmp byte ptr es:[bx],00001000B
    jne CHANGE_RET
    mov byte ptr es:[bx],1

CHANGE_RET:
    add bx,2
    loop CHANGE_RET

    pop cx
    pop bx
    ret

RETURN_MAIN:
    ; 重新打印菜单
    jmp BOOT_START
    ret

CLEAR_KB_BUFFER:
    ; 16H:1 出栈，检测键盘缓冲区是否有数据(栈是否为空)
    mov ah,1
    int 16H
    ; 如果有数据ZF!=0，没有，ZF=0跳出(栈为空则无返回并跳出)
    jz CLEAR_KB_BUFFER_RET
    ; 16H:0 入栈
    mov ah,0
    int 16H
    jmp CLEAR_KB_BUFFER
CLEAR_KB_BUFFER_RET:
    ret

SHOW_MENU:
    ; 在第9行，第29列显示菜单
    mov di,160*10+30*2
    ; 保存在直接定址表的绝对位置
    mov bx,offset FUNC_ADDR - offset BOOT + 7E00H
    ; 菜单有5行
    mov cx,5

SHOW_FUNC:
    ; 这里相当于外循环，每次一行
    ; 获取FUNC_ADDR中每行的保存位置的偏移地址
    mov si,ds:[bx]
    ; 调用内循环函数，输出一行的每个字符
    call SHOW_LINE
    ; 下一行偏移地址
    add bx,2
    ; 下一行显示
    add di,160
    loop SHOW_FUNC
    ret

SHOW_LINE:
    push ax
    push di
    push si
LINE:
    ; 获取这一行的第si个字符
    mov al,ds:[si]
    ; 判断是否到达行尾0
    cmp al,0
    je SHOW_LINE_RET
    ; 保存字符到显示缓冲区
    mov es:[di],al
    add di,2
    inc si
    jmp LINE

SHOW_LINE_RET:
    pop si
    pop di
    pop ax
    ret

; 清空整个屏幕，并把字体颜色设置为绿色
CLEAR_SCREEN:
    mov bx,0
    mov cx,2000
    mov dl,' '
    mov dh,3; 字体为绿色
CLEAR:
    mov es:[bx],dx
    add bx,2
    loop CLEAR

    ret

; 设置es:[ds] -> B800:0000
INIT_BOOT:
    mov ax,0B800H
    mov es,ax

    mov ax,0
    mov ds,ax
    ret

BOOT_END:
    nop

code ends
end start