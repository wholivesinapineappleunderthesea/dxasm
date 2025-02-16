INCLUDE masm_macros.inc

EXTERN GetProcAddress: PROC
EXTERN GetModuleHandleW: PROC
EXTERN GetModuleFileNameW: PROC
EXTERN ExitProcess: PROC

EXTERN GetProcessHeap: PROC
EXTERN HeapAlloc: PROC
EXTERN HeapFree: PROC

EXTERN RegisterClassExW: PROC
EXTERN CreateWindowExW: PROC
EXTERN ShowWindow: PROC
EXTERN UpdateWindow: PROC
EXTERN DefWindowProcW: PROC
EXTERN DestroyWindow: PROC
EXTERN PeekMessageW: PROC
EXTERN TranslateMessage: PROC
EXTERN DispatchMessageW: PROC
EXTERN PostQuitMessage: PROC



POINT STRUCT
	x SDWORD ?
	y SDWORD ?
POINT ENDS

WNDCLASSEXW STRUCT
	cbSize DWORD ?
	style DWORD ?
	lpfnWndProc QWORD ?
	cbClsExtra DWORD ?
	cbWndExtra DWORD ?
	hInstance QWORD ?
	hIcon QWORD ?
	hCursor QWORD ?
	hbrBackground QWORD ?
	lpszMenuName QWORD ?
	lpszClassName QWORD ?
	hIconSm QWORD ?
WNDCLASSEXW ENDS

MSG STRUCT
	hwnd QWORD ?
	message DWORD ?
	wParam QWORD ?
	lParam QWORD ?
	time DWORD ?
	pt POINT <>
	lPrivate DWORD ?
MSG ENDS

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
	sub rsp, 28h
	xor ecx, ecx ; uExitCode
	call ExitProcess
	int 3
	; add rsp, 28h
	; ret
winExit ENDP

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

;
; windowing funcs
;

winWndProc PROC
	sub rsp, (28h + 8h + 8h + 8h + 8h)
	mov qword ptr [rsp + 28h], rcx ; hWnd
	mov dword ptr [rsp + 30h], edx ; uMsg
	mov qword ptr [rsp + 38h], r8 ; wParam
	mov qword ptr [rsp + 40h], r9 ; lParam

	; WM_DESTROY
	cmp edx, 02h ; WM_DESTROY
	jne _not_wm_destroy
	xor ecx, ecx ; uExitCode
	call PostQuitMessage

	xor eax, eax
	jmp _wndproc_handled
_not_wm_destroy:

	jmp _call_defwndproc
_wndproc_handled:
	add rsp, (28h + 8h + 8h + 8h + 8h)
	ret
_call_defwndproc:
	mov rcx, qword ptr [rsp + 28h] ; hWnd
	mov edx, dword ptr [rsp + 30h] ; uMsg
	mov r8, qword ptr [rsp + 38h] ; wParam
	mov r9, qword ptr [rsp + 40h] ; lParam
	add rsp, (28h + 8h + 8h + 8h + 8h)
	jmp DefWindowProcW
winWndProc ENDP

winCreateWindow PROC
	; 80h is enough for CreateWindowExW i think
	sub rsp, (28h + ALIGN_TO_16(sizeof WNDCLASSEXW) + 80h) 

	lea rcx, [rsp + 28h]
	mov dword ptr [rcx + WNDCLASSEXW.cbSize], sizeof WNDCLASSEXW
	mov dword ptr [rcx + WNDCLASSEXW.style], 03h ; CS_HREDRAW | CS_VREDRAW
	lea rax, winWndProc
	mov qword ptr [rcx + WNDCLASSEXW.lpfnWndProc], rax
	mov dword ptr [rcx + WNDCLASSEXW.cbClsExtra], 0
	mov dword ptr [rcx + WNDCLASSEXW.cbWndExtra], 0	
	mov rax, global_moduleBaseAddr
	mov qword ptr [rcx + WNDCLASSEXW.hInstance], rax
	mov qword ptr [rcx + WNDCLASSEXW.hIcon], 0
	mov qword ptr [rcx + WNDCLASSEXW.hCursor], 0
	mov qword ptr [rcx + WNDCLASSEXW.hbrBackground], 6 ; COLOR_WINDOW
	mov qword ptr [rcx + WNDCLASSEXW.lpszMenuName], 0
	lea rax, local_windowClassName
	mov qword ptr [rcx + WNDCLASSEXW.lpszClassName], rax
	mov qword ptr [rcx + WNDCLASSEXW.hIconSm], 0

	call RegisterClassExW
	test eax, eax
	jnz _success_classname
	int 3

_success_classname:
	mov ecx, 80000000h ; CW_USEDEFAULT
	mov dword ptr [rsp + 20h + 0h], ecx ; x
	mov dword ptr [rsp + 20h + 8h], ecx ; y
	mov dword ptr [rsp + 20h + 10h], ecx ; nWidth
	mov dword ptr [rsp + 20h + 18h], ecx ; nHeight
	mov qword ptr [rsp + 20h + 20h], 0 ; hWndParent
	mov qword ptr [rsp + 20h + 28h], 0 ; hMenu
	mov rcx, global_moduleBaseAddr
	mov qword ptr [rsp + 20h + 30h], rcx ; hInstance
	mov qword ptr [rsp + 20h + 38h], 0 ; lpParam

	mov ecx, 0 ; dwExStyle	
	lea rdx, local_windowClassName ; lpClassName
	lea r8, local_windowTitle ; lpWindowName
	mov r9d, 0CF0000h ; dwStyle : WS_OVERLAPPEDWINDOW

	call CreateWindowExW
	mov global_windowHandle, rax
	test rax, rax
	jnz _success_createwindow
	int 3

_success_createwindow:
	mov rcx, rax
	mov edx, 5 ; nCmdShow : SW_SHOW
	call ShowWindow

	mov rcx, global_windowHandle
	call UpdateWindow



	add rsp, (28h +  ALIGN_TO_16(sizeof WNDCLASSEXW) + 80h)
	jmp winDispatchMessageQueue
winCreateWindow ENDP

winDispatchMessageQueue PROC
	; 8h PeekMessageW wRemoveMsg
	sub rsp, (28h + ALIGN_TO_16(SIZEOF MSG) + 8h)

	push rsi
	xor sil, sil
_peek_loop:
	lea rcx, [rsp + 28h] ; msg
	; zero out MSG
	mov qword ptr [rcx + MSG.hwnd], 0
	mov dword ptr [rcx + MSG.message], 0
	mov qword ptr [rcx + MSG.wParam], 0
	mov qword ptr [rcx + MSG.lParam], 0
	mov dword ptr [rcx + MSG.time], 0
	mov dword ptr [rcx + MSG.pt.x], 0
	mov dword ptr [rcx + MSG.pt.y], 0
	mov dword ptr [rcx + MSG.lPrivate], 0

	; peek message
	xor edx, edx ; hWnd
	mov r8, 0 ; wMsgFilterMin
	mov r9, 0 ; wMsgFilterMax
	mov dword ptr [rsp + 20h], 1 ; wRemoveMsg
	call PeekMessageW
	test eax, eax
	jz _peek_loop_end

	; translate message
	lea rcx, [rsp + 28h] ; lpMsg
	call TranslateMessage

	; dispatch message
	lea rcx, [rsp + 28h] ; lpMsg
	call DispatchMessageW

	; test if exit message
	mov eax, dword ptr [rsp + 28h + MSG.message]
	cmp eax, 12h ; WM_QUIT
	sete al
	or sil, al

	jmp _peek_loop

_peek_loop_end:
	mov al, sil
	pop rsi
	add rsp, (28h + ALIGN_TO_16(SIZEOF MSG) + 8h)
	ret
winDispatchMessageQueue ENDP

winMessageLoop PROC
	sub rsp, 28h

_continue_window:

	;
	; frame stuff here i guess
	;

	call winDispatchMessageQueue
	test al, al
	jz _continue_window

	add rsp, 28h
	ret
winMessageLoop ENDP

winDestroyWindow PROC
	mov rcx, global_windowHandle
	mov global_windowHandle, 0
	jmp DestroyWindow
winDestroyWindow ENDP

;
; dx12 functions
;

winDX12Init PROC
	
	ret
winDX12Init ENDP

winDX12Exit PROC
	
	ret
winDX12Exit ENDP




END
