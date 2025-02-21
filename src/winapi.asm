INCLUDE masm_macros.inc
INCLUDE wincomobj.inc

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
EXTERN GetClientRect: PROC
EXTERN DefWindowProcW: PROC
EXTERN DestroyWindow: PROC
EXTERN PeekMessageW: PROC
EXTERN TranslateMessage: PROC
EXTERN DispatchMessageW: PROC
EXTERN PostQuitMessage: PROC

EXTERN CreateDXGIFactory1:PROC
EXTERN D3D12CreateDevice:PROC

EXTERN CreateEventW:PROC
EXTERN WaitForSingleObject:PROC

MM_SHARED_USER_DATA_VA EQU 07FFE0000h 


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

RECT STRUCT
	left DWORD ?
	top DWORD ?
	right DWORD ?
	bottom DWORD ?
RECT ENDS

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

local_windowRect RECT <>

local_heapHandle QWORD 0

local_dxFactory QWORD 0
local_dxAdapter QWORD 0
local_dxDevice QWORD 0
local_dxCommandQueue QWORD 0
local_dxCommandAllocator QWORD 0
local_dxCommandList QWORD 0
local_dxFence QWORD 0
local_fenceEventHandle QWORD 0
local_dxFenceValue DWORD 0
local_dxSwapChain QWORD 0
local_dxRTVDescriptorHeap QWORD 0
local_dxRTVDescriptorHandleIncrementSize QWORD 0
local_dxRTVHandle0 QWORD 0
local_dxRTVHandle1 QWORD 0
local_dxRTVBuffer0 QWORD 0
local_dxRTVBuffer1 QWORD 0


local_dxBackBufferIndex DWORD 0 

local_lastFrameTime QWORD 0

.CONST

local_windowClassName WORD 'd','x','a','s','m',0
local_windowTitle WORD 'D','X','A','S','M',0

local_clearColour REAL4 0.0, 0.2, 0.4, 1.0

; 10000000.0
local_interruptFrequency REAL8 10000000.0, 10000000.0

.CODE

winHighPrecisionTime PROC
	
_modified:
	mov eax, dword ptr [MM_SHARED_USER_DATA_VA + 0320h + 4h] ; High1Time
	mov ecx, dword ptr [MM_SHARED_USER_DATA_VA + 0320h + 0h] ; LowPart
	mov edx, dword ptr [MM_SHARED_USER_DATA_VA + 0320h + 8h] ; High2Time
	cmp edx, eax
	jne _modified

	shl rax, 32
	or rax, rcx

	ret
winHighPrecisionTime ENDP

winHighPrecisionTimeToSeconds PROC
	cvtsi2sd xmm0, rcx
	movq xmm1, local_interruptFrequency
	divsd xmm0, xmm1
	ret
winHighPrecisionTimeToSeconds ENDP

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

	call winHighPrecisionTime
	mov local_lastFrameTime, rax

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

	; get window rect
	mov rcx, global_windowHandle
	lea rdx, local_windowRect
	call GetClientRect


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

	call winDX12Frame

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
	sub rsp, 088h

	mov dword ptr [rsp+08h], 0 ; adapter index



	lea rcx, IID_IDXGIFactory1
	lea rdx, local_dxFactory
	call CreateDXGIFactory1
	test eax, eax
	jns _success_createdxgifactory1
	int 3

_success_createdxgifactory1:

	


_enum_adapter1_start:
	mov rcx, local_dxFactory
	mov edx, dword ptr [rsp+028h]
	lea r8, local_dxAdapter
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IDXGIFactory1_EnumAdapters1]
	test eax, eax
	jns _enum_adapter1_success
	int 3

_enum_adapter1_success:
	mov rcx, local_dxAdapter
	mov edx, 0b000h ; D3D_FEATURE_LEVEL_11_0
	lea r8, IID_ID3D12Device
	xor r9d, r9d
	call D3D12CreateDevice
	test eax, eax
	jns _enum_adapter1_device_success

	inc dword ptr [rsp+028h]

	mov rcx, local_dxAdapter
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxAdapter, 0
	jmp _enum_adapter1_start
	
_enum_adapter1_device_success:

	mov rcx, local_dxAdapter
	mov edx, 0b000h ; D3D_FEATURE_LEVEL_11_0
	lea r8, IID_ID3D12Device
	lea r9, local_dxDevice
	call D3D12CreateDevice
	test eax, eax
	jns _success_created3d12device
	int 3

_success_created3d12device:

	lea rdx, [rsp + 028h]
	mov dword ptr [rdx], 0 ; Type : D3D12_COMMAND_LIST_TYPE_DIRECT
	mov dword ptr [rdx + 4], 0 ; Priority
	mov dword ptr [rdx + 8], 0 ; Flags : D3D12_COMMAND_QUEUE_FLAG_NONE
	mov dword ptr [rdx + 0Ch], 0 ; NodeMask

	mov rcx, local_dxDevice
	mov rax, qword ptr [rcx]

	lea r8, IID_ID3D12CommandQueue
	lea r9, local_dxCommandQueue
	call qword ptr [rax + VTBL_ID3D12Device_CreateCommandQueue]
	test eax, eax
	jns _success_created3d12commandqueue
	int 3

_success_created3d12commandqueue:
	
	mov rcx, local_dxDevice
	xor edx, edx ; D3D12_COMMAND_LIST_TYPE_DIRECT
	lea r8, IID_ID3D12CommandAllocator
	lea r9, local_dxCommandAllocator
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateCommandAllocator]
	test eax, eax
	jns _success_created3d12commandalloc
	int 3

_success_created3d12commandalloc:

	mov rcx, local_dxDevice
	xor edx, edx ; NodeMask
	xor r8d, r8d ; D3D12_COMMAND_LIST_TYPE_DIRECT
	mov r9, local_dxCommandAllocator
	mov qword ptr [rsp + 020h], 0 ; pInitialState
	lea rax, IID_ID3D12GraphicsCommandList
	mov qword ptr [rsp + 028h], rax ; riid
	lea rax, local_dxCommandList
	mov qword ptr [rsp + 030h], rax ; ppCommandList
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateCommandList]
	test eax, eax
	jns _success_created3d12commandlist
	int 3

_success_created3d12commandlist:

	mov rcx, local_dxCommandList
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_Close]

	mov rcx, local_dxDevice
	xor edx, edx ; InitialValue
	xor r8d, r8d ; FenceFlags : D3D12_FENCE_FLAG_NONE
	lea r9, IID_ID3D12Fence
	lea rax, local_dxFence
	mov qword ptr [rsp + 020h], rax ; ppFence
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateFence]
	test eax, eax
	jns _success_created3d12fence
	int 3

_success_created3d12fence:

	xor ecx, ecx ; lpEventAttributes
	xor edx, edx ; bManualReset
	xor r8d, r8d ; bInitialState
	xor r9d, r9d ; lpName
	call CreateEventW
	mov local_fenceEventHandle, rax
	

	lea r8, [rsp + 028h]
	mov eax, local_windowRect.right
	sub eax, local_windowRect.left
	mov dword ptr [r8], eax ; BufferDesc.Width
	mov eax, local_windowRect.bottom
	sub eax, local_windowRect.top
	mov dword ptr [r8 + 4], eax ; BufferDesc.Height
	mov dword ptr [r8 + 8], 0 ; BufferDesc.RefreshRate.Numerator
	mov dword ptr [r8 + 0Ch], 0 ; BufferDesc.RefreshRate.Denominator
	mov dword ptr [r8 + 10h], 28 ; BufferDesc.Format : DXGI_FORMAT_R8G8B8A8_UNORM
	mov dword ptr [r8 + 14h], 0 ; BufferDesc.ScanlineOrdering : DXGI_MODE_SCANLINE_ORDER_UNSPECIFIED
	mov dword ptr [r8 + 18h], 0 ; BufferDesc.Scaling : DXGI_MODE_SCALING_UNSPECIFIED
	mov dword ptr [r8 + 1Ch], 1 ; SampleDesc.Count
	mov dword ptr [r8 + 20h], 0 ; SampleDesc.Quality
	mov dword ptr [r8 + 24h], 32 ; BufferUsage : DXGI_USAGE_RENDER_TARGET_OUTPUT
	mov dword ptr [r8 + 28h], 2 ; BufferCount
	mov rax, global_windowHandle
	mov qword ptr [r8 + 30h], rax ; OutputWindow
	mov dword ptr [r8 + 38h], 1 ; Windowed
	mov dword ptr [r8 + 3Ch], 4 ; SwapEffect : DXGI_SWAP_EFFECT_FLIP_DISCARD
	mov dword ptr [r8 + 40h], 0 ; Flags 
	mov rcx, local_dxFactory
	mov rdx, local_dxCommandQueue
	lea r9, local_dxSwapChain
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IDXGIFactory_CreateSwapChain]
	test eax, eax
	jns _success_createdxgiswapchain
	int 3

_success_createdxgiswapchain:

	mov rcx, local_dxFactory
	mov rdx, global_windowHandle
	mov r8d, 2 ; DXGI_MWA_NO_ALT_ENTER
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IDXGIFactory_MakeWindowAssociation]

	lea rdx, [rsp + 028h]
	mov dword ptr [rdx], 2 ; D3D12_DESCRIPTOR_HEAP_TYPE_RTV
	mov dword ptr [rdx + 4], 2 ; NumDescriptors
	mov dword ptr [rdx + 8], 0 ; Flags
	mov dword ptr [rdx + 0Ch], 0 ; NodeMask
	mov rcx, local_dxDevice
	lea r8, IID_ID3D12DescriptorHeap
	lea r9, local_dxRTVDescriptorHeap
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateDescriptorHeap]
	test eax, eax
	jns _success_created3d12descriptorheap
	int 3

_success_created3d12descriptorheap:

	mov rcx, local_dxDevice
	mov edx, 2 ; D3D12_DESCRIPTOR_HEAP_TYPE_RTV
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_GetDescriptorHandleIncrementSize]
	mov local_dxRTVDescriptorHandleIncrementSize, rax

	call winDX12CreateSwapChainResources


	
	
	add rsp, 88h
	ret
winDX12Init ENDP

winDX12CreateSwapChainResources PROC
	sub rsp, 30h
	push rsi

	mov rcx, local_dxRTVDescriptorHeap
	lea rdx, [rsp + 028h]
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart]
	mov rsi, qword ptr [rsp + 028h]

	; buffer 0

	mov rcx, local_dxSwapChain
	xor edx, edx ; Buffer
	lea r8, IID_ID3D12Resource
	lea r9, local_dxRTVBuffer0
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IDXGISwapChain_GetBuffer]

	mov local_dxRTVHandle0, rsi
	mov rcx, local_dxDevice
	mov rdx, local_dxRTVBuffer0 ; pResource
	xor r8d, r8d ; pDesc
	mov r9, rsi ; DestDescriptor
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateRenderTargetView]
	
	; buffer 1

	mov rcx, local_dxSwapChain
	mov edx, 1 ; Buffer
	lea r8, IID_ID3D12Resource
	lea r9, local_dxRTVBuffer1
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IDXGISwapChain_GetBuffer]

	add rsi, local_dxRTVDescriptorHandleIncrementSize
	mov local_dxRTVHandle1, rsi
	mov rcx, local_dxDevice
	mov rdx, local_dxRTVBuffer1 ; pResource
	xor r8d, r8d ; pDesc
	mov r9, rsi ; DestDescriptor
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateRenderTargetView]

	pop rsi
	add rsp, 30h
	ret
winDX12CreateSwapChainResources ENDP

winDX12Frame PROC
	sub rsp, 50h
	push rsi

	call winHighPrecisionTime
	mov rsi, rax

	mov rcx, local_dxCommandAllocator
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12CommandAllocator_Reset]

	mov rcx, local_dxCommandList
	mov rdx, local_dxCommandAllocator
	xor r8d, r8d ; pInitialState
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_Reset]

	lea r8, [rsp + 28h]
	mov dword ptr [r8], 0 ; Type : D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
	mov dword ptr [r8 + 4], 0 ; Flags : D3D12_RESOURCE_BARRIER_FLAG_NONE
	mov ecx, local_dxBackBufferIndex
	lea rax, local_dxRTVBuffer0
	lea rax, [rax + rcx*8]
	mov rax, qword ptr [rax]
	mov qword ptr [r8 + 8], rax ; pResource
	mov dword ptr [r8 + 10h], 0ffffffffh ; Subresource : D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
	mov dword ptr [r8 + 14h], 0 ; StateBefore : D3D12_RESOURCE_STATE_PRESENT
	mov dword ptr [r8 + 18h], 4 ; StateAfter : D3D12_RESOURCE_STATE_RENDER_TARGET
	mov rcx, local_dxCommandList
	mov edx, 1 ; NumBarriers
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_ResourceBarrier]

	mov ecx, local_dxBackBufferIndex
	lea rax, local_dxRTVHandle0
	lea rax, [rax + rcx*8]
	mov rcx, local_dxCommandList
	mov rdx, qword ptr [rax]
	
	lea r8, local_clearColour

	xor r9d, r9d ; NumRects
	mov qword ptr [rsp+020h], 0 ; pRects
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_ClearRenderTargetView]






	lea r8, [rsp + 28h]
	mov dword ptr [r8], 0 ; Type : D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
	mov dword ptr [r8 + 4], 0 ; Flags : D3D12_RESOURCE_BARRIER_FLAG_NONE
	mov ecx, local_dxBackBufferIndex
	lea rax, local_dxRTVBuffer0
	lea rax, [rax + rcx*8]
	mov rax, qword ptr [rax]
	mov qword ptr [r8 + 8], rax ; pResource
	mov dword ptr [r8 + 10h], 0ffffffffh ; Subresource
	mov dword ptr [r8 + 14h], 4 ; StateBefore : D3D12_RESOURCE_STATE_PRESENT
	mov dword ptr [r8 + 18h], 0 ; StateAfter : D3D12_RESOURCE_STATE_RENDER_TARGET
	mov rcx, local_dxCommandList
	mov edx, 1 ; NumBarriers
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_ResourceBarrier]

	mov rcx, local_dxCommandList
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_Close]

	lea r8, [rsp + 28h]
	mov rax, local_dxCommandList
	mov qword ptr [r8], rax
	mov rcx, local_dxCommandQueue
	mov edx, 1 ; NumCommandLists
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12CommandQueue_ExecuteCommandLists]

	mov rcx, local_dxSwapChain
	mov rax, qword ptr [rcx]
	xor edx, edx ; SyncInterval
	xor r8d, r8d ; Flags
	call qword ptr [rax + VTBL_IDXGISwapChain_Present]

	call winDX12SyncAndWaitFence

	; flip back buffer index
	mov eax, local_dxBackBufferIndex
	xor eax, 1
	mov local_dxBackBufferIndex, eax

	mov local_lastFrameTime, rsi

	pop rsi
	add rsp, 50h
	ret
winDX12Frame ENDP

winDX12SyncAndWaitFence PROC
	sub rsp, 28h
	inc local_dxFenceValue

	mov rcx, local_dxCommandQueue
	mov rdx, local_dxFence
	mov r8d, local_dxFenceValue
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12CommandQueue_Signal]

	mov rcx, local_dxFence
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Fence_GetCompletedValue]
	cmp eax, local_dxFenceValue
	jge _wait_completed

	mov rcx, local_dxFence
	mov edx, local_dxFenceValue
	mov r8, local_fenceEventHandle
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Fence_SetEventOnCompletion]

	mov rcx, local_fenceEventHandle
	mov r8d, 0ffffffffh ; INFINITE
	call WaitForSingleObject


_wait_completed:

	add rsp, 28h
	ret
winDX12SyncAndWaitFence ENDP

winDX12ReleaseSwapChainResources PROC
	sub rsp, 28h

	mov rcx, local_dxRTVBuffer1
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxRTVBuffer1, 0

	mov rcx, local_dxRTVBuffer0
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxRTVBuffer0, 0

	add rsp, 28h
	ret
winDX12ReleaseSwapChainResources ENDP

winDX12Exit PROC
	sub rsp, 28h

	mov rcx, local_dxRTVDescriptorHeap
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxRTVDescriptorHeap, 0

	mov rcx, local_dxFence
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxFence, 0

	mov rcx, local_dxCommandList
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxCommandList, 0

	mov rcx, local_dxCommandAllocator
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxCommandAllocator, 0

	
			 
	mov rcx, local_dxCommandQueue
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxCommandQueue, 0
	
	mov rcx, local_dxDevice
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxDevice, 0

	mov rcx, local_dxAdapter
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxAdapter, 0

	mov rcx, local_dxFactory
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxFactory, 0



	add rsp, 28h
	ret
winDX12Exit ENDP




END
