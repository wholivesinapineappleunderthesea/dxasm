INCLUDE masm_macros.inc
INCLUDE winapi.inc
.CODE

asm_entry PROC
	sub rsp, (28h)
	
	call winInit

	mov ecx, 100
	call winHeapAlloc

	mov rcx, rax
	call winHeapFree

	call winExit

	add rsp, (28h)
	ret
asm_entry ENDP

END