.intel_syntax noprefix
.text
.globl MagicKeyTransformA1644
.def MagicKeyTransformA1644; .scl 2; .type 32; .endef
MagicKeyTransformA1644:
    cmp edx, 9
    jb .done

    movzx eax, byte ptr [rcx]
    mov r8d, eax
    and r8d, 0x33

    mov r9d, eax
    and r9d, 0x44
    shl r9d, 1
    or r8d, r9d

    mov r9d, eax
    and r9d, 0x88
    shr r9d, 1
    or r8d, r9d

    movzx eax, byte ptr [rcx + 8]
    test al, 0x02
    jz .no_fn
    or r8b, 0x01
.no_fn:
    mov byte ptr [rcx], r8b

    test al, 0x01
    jz .clear_special

    lea r10, [rcx + 2]
    mov r11d, 6
.find_slot:
    cmp byte ptr [r10], 0
    je .put_delete
    inc r10
    dec r11d
    jnz .find_slot
    jmp .clear_special
.put_delete:
    mov byte ptr [r10], 0x4c

.clear_special:
    and byte ptr [rcx + 8], 0xfc
.done:
    ret
