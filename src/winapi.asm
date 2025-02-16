EXTERN GetProcAddress: PROC
EXTERN GetModuleHandleW: PROC
EXTERN GetModuleFileNameW: PROC
EXTERN ExitProcess: PROC

EXTERN GetProcessHeap: PROC
EXTERN HeapAlloc: PROC
EXTERN HeapFree: PROC

.DATA

global_moduleSize DWORD 0
PUBLIC global_moduleSize
global_moduleBaseAddr QWORD 0
PUBLIC global_moduleBaseAddr

global_moduleFolderPath WORD 512 DUP(0)
PUBLIC global_moduleFolderPath
global_moduleFolderPathLen WORD 0
PUBLIC global_moduleFolderPathLen

global_moduleFileName QWORD 0
PUBLIC global_moduleFileName
global_moduleFileNameLen WORD 0
PUBLIC global_moduleFileNameLen

global_windowHandle QWORD 0
PUBLIC global_windowHandle



local_heapHandle QWORD 0

.CONST

local_windowClassName WORD 'd','x','a','s','m',0
local_windowTitle WORD 'D','X','A','S','M',0

.CODE

winInit PROC
	sub rsp, 28h

	; set global_moduleBaseAddr
	xor rcx, rcx
	call GetModuleHandleW
	mov global_moduleBaseAddr, rax

	; set global_moduleSize
	mov ecx, dword ptr [rax + 3Ch] ; e_lfanew
	mov eax, dword ptr [rax + rcx + 50h] ; SizeOfImage
	mov global_moduleSize, eax

	; get global_moduleFolderPath
	xor rcx, rcx
	lea rdx, global_moduleFolderPath
	mov r8, 512
	call GetModuleFileNameW
	mov edx, eax 

	; walk back to the last '\'
	lea rcx, global_moduleFolderPath
_cont_walk_backslash:
	dec edx
	mov r8w, word ptr [rcx+rdx*2]
	cmp r8w, '\'
	jne _cont_walk_backslash

	lea rcx, [rcx+rdx*2]
	mov word ptr [rcx], 0 ; null-term at the backslash
	sub eax, edx

	dec eax
	mov global_moduleFileNameLen, ax
	mov global_moduleFolderPathLen, dx
	
	lea rcx, global_moduleFolderPath
	lea rcx, [rcx+rdx*2]
	add rcx, 2
	mov global_moduleFileName, rcx

	call GetProcessHeap
	mov local_heapHandle, rax

	add rsp, 28h
	ret
winInit ENDP

winExit PROC
	ret
winExit ENDP

winTerm PROC
	sub rsp, 28h
	xor ecx, ecx ; uExitCode
	call ExitProcess
	int 3
	; add rsp, 28h
	; ret
winTerm ENDP

winHeapAlloc PROC
	mov r8d, ecx ; dwBytes
	mov edx, 8 ; dwFlags : HEAP_ZERO_MEMORY
	mov rcx, local_heapHandle ; hHeap
	jmp HeapAlloc
winHeapAlloc ENDP

winHeapFree PROC
	mov r8, rcx ; lpMem
	xor edx, edx ; dwFlags
	mov rcx, local_heapHandle ; hHeap
	jmp HeapFree
winHeapFree ENDP




END