INCLUDE masm_macros.inc
INCLUDE wincomobj.inc
INCLUDE resrc.inc

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

EXTERN D3D12GetDebugInterface:PROC
EXTERN CreateDXGIFactory1:PROC
EXTERN D3D12CreateDevice:PROC
EXTERN D3D12SerializeRootSignature:PROC

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

VERTEX3D STRUCT
	x REAL4 ?
	y REAL4 ?
	z REAL4 ?
	u REAL4 ?
	v REAL4 ?
	nx REAL4 ?
	ny REAL4 ?
	nz REAL4 ?
VERTEX3D ENDS

D3D12_VIEWPORT STRUCT
	_TopLeftX REAL4 ?
	_TopLeftY REAL4 ?
	_Width REAL4 ?
	_Height REAL4 ?
	_MinDepth REAL4 ?
	_MaxDepth REAL4 ?
D3D12_VIEWPORT ENDS

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

local_dxDebug QWORD 0
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
local_dxDepthDescriptorHeap QWORD 0
local_dxDepthDescriptorHandleIncrementSize QWORD 0
local_dxRTVHandle0 QWORD 0
local_dxRTVHandle1 QWORD 0
local_dxRTVBuffer0 QWORD 0
local_dxRTVBuffer1 QWORD 0
local_dxDepthBuffer QWORD 0
local_dxRootSignature QWORD 0
local_dxDefault3DPipelineState QWORD 0

local_testBuffer QWORD 0


local_dxBackBufferIndex DWORD 0 

local_lastFrameTime QWORD 0

.CONST

local_windowClassName WORD 'd','x','a','s','m',0
local_windowTitle WORD 'D','X','A','S','M',0

local_clearColour REAL4 0.0, 0.2, 0.4, 1.0

local_semanticPosition BYTE 'POSITION', 0
local_semanticTexcoord BYTE 'TEXCOORD', 0
local_semanticNormal BYTE 'NORMAL', 0

local_float4_one REAL4 1.0, 1.0, 1.0, 1.0
local_float4_negone REAL4 -1.0, -1.0, -1.0, -1.0


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

	lea rcx, IID_ID3D12Debug
	lea rdx, local_dxDebug
	call D3D12GetDebugInterface

	mov rcx, local_dxDebug
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Debug_EnableDebugLayer]

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

	lea rdx, [rsp + 028h]
	mov dword ptr [rdx], 3 ; D3D12_DESCRIPTOR_HEAP_TYPE_DSV
	mov dword ptr [rdx + 4], 1 ; NumDescriptors
	mov dword ptr [rdx + 8], 0 ; Flags
	mov dword ptr [rdx + 0Ch], 0 ; NodeMask
	mov rcx, local_dxDevice
	lea r8, IID_ID3D12DescriptorHeap
	lea r9, local_dxDepthDescriptorHeap
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateDescriptorHeap]
	test eax, eax
	jns _success_created3d12depthdescriptorheap
	int 3

_success_created3d12depthdescriptorheap:

	mov rcx, local_dxDevice
	mov edx, 3 ; D3D12_DESCRIPTOR_HEAP_TYPE_DSV
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_GetDescriptorHandleIncrementSize]
	mov local_dxDepthDescriptorHandleIncrementSize, rax
	

	call winDX12CreateSwapChainResources

	lea rax, [rsp + 58h]
	mov dword ptr [rax + 0h], 1 ; ParameterType : D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS
	mov dword ptr [rax + 08h], 0 ; ShaderRegister : b0
	mov dword ptr [rax + 08h + 04h], 0 ; RegisterSpace : 0
	mov dword ptr [rax + 08h + 08h], 1 ; Num32BitValues : 1
	mov dword ptr [rax + 18h], 0 ; ShaderVisibility : D3D12_SHADER_VISIBILITY_ALL

	lea rcx, [rsp + 028h] ; D3D12_ROOT_SIGNATURE_DESC
	mov dword ptr [rcx + 0h], 1 ; NumParameters
	mov qword ptr [rcx + 8h], rax ; pParameters
	mov dword ptr [rcx + 10h], 0 ; NumStaticSamplers
	mov qword ptr [rcx + 18h], 0 ; pStaticSamplers
	mov dword ptr [rcx + 20h], 1 ; Flags : D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT
	mov edx, 1 ; D3D_ROOT_SIGNATURE_VERSION_1
	lea r8, [rsp + 028h + 028h] ; ppBlob
	mov qword ptr [r8], 0 ; 
	xor r9d, r9d ; ppErrorBlob
	call D3D12SerializeRootSignature

	; get blob ptr
	mov rcx, qword ptr [rsp + 028h + 028h] ; ppBlob
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D10Blob_GetBufferPointer]
	; store it into the stack somewhere!
	mov qword ptr [rsp + 028h + 030h], rax

	; likewise length
	mov rcx, qword ptr [rsp + 028h + 028h] ; ppBlob
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D10Blob_GetBufferSize]
	mov qword ptr [rsp + 028h + 038h], rax

	mov rcx, local_dxDevice
	xor edx, edx ; NodeMask
	mov r8, qword ptr [rsp + 028h + 030h] ; 
	mov r9, qword ptr [rsp + 028h + 038h] ; 
	lea rax, IID_ID3D12RootSignature
	mov qword ptr [rsp + 020h], rax ; riid
	lea rax, local_dxRootSignature
	mov qword ptr [rsp + 028h], rax ; ppRootSignature
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateRootSignature]

	; gotta release the blob
	mov rcx, qword ptr [rsp + 028h + 028h] ; ppBlob
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	

	call winDX12CreatePipelineStates
	
	add rsp, 88h
	ret
winDX12Init ENDP

winDX12CreatePipelineStates PROC
	; float3 pos : POSITION;
	; float2 uv : TEXCOORD;
	; float3 normal : NORMAL;
	; rsp + 28h : D3D12_INPUT_ELEMENT_DESC[4]
	; rsp + 28h + (20h*4) : D3D12_GRAPHICS_PIPELINE_STATE_DESC
	sub rsp, (28h + (20h*4) + 2b0h)

	; init stack to 0
	xor eax, eax
	lea rcx, [rsp + 28h]
_cont_wipe_stack:
	mov qword ptr [rcx+rax], 0
	add rax, 8
	cmp rax, (20h*4) + 2b0h
	jne _cont_wipe_stack




	; POSITION
	lea rcx, local_semanticPosition
	mov qword ptr [rsp + 28h + 0h], rcx ; SemanticName
	mov dword ptr [rsp + 28h + 8h], 0 ; SemanticIndex
	mov dword ptr [rsp + 28h + 0Ch], 6 ; Format : DXGI_FORMAT_R32G32B32_FLOAT
	mov dword ptr [rsp + 28h + 10h], 0 ; InputSlot
	mov dword ptr [rsp + 28h + 14h], 0 ; AlignedByteOffset
	mov dword ptr [rsp + 28h + 18h], 0 ; InputSlotClass : D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
	mov dword ptr [rsp + 28h + 1Ch], 0 ; InstanceDataStepRate

	; TEXCOORD
	lea rcx, local_semanticTexcoord
	mov qword ptr [rsp + 28h + 20h], rcx ; SemanticName
	mov dword ptr [rsp + 28h + 28h], 0 ; SemanticIndex
	mov dword ptr [rsp + 28h + 2Ch], 16 ; Format : DXGI_FORMAT_R32G32_FLOAT
	mov dword ptr [rsp + 28h + 30h], 0 ; InputSlot
	mov dword ptr [rsp + 28h + 34h], 12 ; AlignedByteOffset
	mov dword ptr [rsp + 28h + 38h], 0 ; InputSlotClass : D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
	mov dword ptr [rsp + 28h + 3Ch], 0 ; InstanceDataStepRate

	; NORMAL
	lea rcx, local_semanticNormal
	mov qword ptr [rsp + 28h + 40h], rcx ; SemanticName
	mov dword ptr [rsp + 28h + 48h], 0 ; SemanticIndex
	mov dword ptr [rsp + 28h + 4Ch], 6 ; Format : DXGI_FORMAT_R32G32B32_FLOAT
	mov dword ptr [rsp + 28h + 50h], 0 ; InputSlot
	mov dword ptr [rsp + 28h + 54h], 20 ; AlignedByteOffset
	mov dword ptr [rsp + 28h + 58h], 0 ; InputSlotClass : D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA
	mov dword ptr [rsp + 28h + 5Ch], 0 ; InstanceDataStepRate

	mov rax, local_dxRootSignature
	mov qword ptr [rsp + 28h + (20h*4)], rax ; pRootSignature
	lea rax, resrc__shader__def_vs_bin
	mov qword ptr [rsp + 28h + (20h*4) + 8h], rax ; VS.pShaderBytecode
	mov qword ptr [rsp + 28h + (20h*4) + 10h], resrc__shader__def_vs_bin_SIZE ; VS.pShaderBytecodeLength
	lea rax, resrc__shader__def_ps_bin
	mov qword ptr [rsp + 28h + (20h*4) + 18h], rax ; PS.pShaderBytecode
	mov qword ptr [rsp + 28h + (20h*4) + 20h], resrc__shader__def_ps_bin_SIZE ; PS.pShaderBytecodeLength
	mov qword ptr [rsp + 28h + (20h*4) + 28h], 0 ; DS.pShaderBytecode
	mov qword ptr [rsp + 28h + (20h*4) + 30h], 0 ; DS.pShaderBytecodeLength
	mov qword ptr [rsp + 28h + (20h*4) + 38h], 0 ; HS.pShaderBytecode
	mov qword ptr [rsp + 28h + (20h*4) + 40h], 0 ; HS.pShaderBytecodeLength
	mov qword ptr [rsp + 28h + (20h*4) + 48h], 0 ; GS.pShaderBytecode
	mov qword ptr [rsp + 28h + (20h*4) + 50h], 0 ; GS.pShaderBytecodeLength
	mov qword ptr [rsp + 28h + (20h*4) + 58h], 0 ; StreamOutput.pSODeclaration
	mov qword ptr [rsp + 28h + (20h*4) + 58h + 8h], 0 ; StreamOutput.NumEntries
	mov qword ptr [rsp + 28h + (20h*4) + 58h + 10h], 0 ; StreamOutput.pBufferStrides
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 18h], 0 ; StreamOutput.NumStrides
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 1Ch], 0 ; StreamOutput.RasterizedStream
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h], 0 ; BlendState.AlphaToCoverageEnable
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h + 4h], 0 ; BlendState.IndependentBlendEnable
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h + 8h], 0 ; BlendState.RenderTarget[0].BlendEnable
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h + 8h + 4h], 0 ; BlendState.RenderTarget[0].LogicOpEnable
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h + 8h + 8h], 2 ; BlendState.RenderTarget[0].SrcBlend : D3D12_BLEND_ONE
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h + 8h + 0Ch], 1 ; BlendState.RenderTarget[0].DestBlend : D3D12_BLEND_ZERO
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h + 8h + 10h], 1 ; BlendState.RenderTarget[0].BlendOp : D3D12_BLEND_OP_ADD
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h + 8h + 14h], 2 ; BlendState.RenderTarget[0].SrcBlendAlpha : D3D12_BLEND_ONE
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h + 8h + 18h], 1 ; BlendState.RenderTarget[0].DestBlendAlpha : D3D12_BLEND_ZERO
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h + 8h + 1Ch], 1 ; BlendState.RenderTarget[0].BlendOpAlpha : D3D12_BLEND_OP_ADD
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h + 8h + 20h], 4 ; BlendState.RenderTarget[0].LogicOp : D3D12_LOGIC_OP_NOOP
	mov dword ptr [rsp + 28h + (20h*4) + 58h + 20h + 8h + 24h], 15 ; BlendState.RenderTarget[0].RenderTargetWriteMask : D3D12_COLOR_WRITE_ENABLE_ALL

	mov dword ptr [rsp + 28h + (20h*4) + 01C0h], 0FFFFFFFFh ; SampleMask

	mov dword ptr [rsp + 28h + (20h*4) + 01C4h], 3 ; RasterizerState.FillMode : D3D12_FILL_MODE_SOLID
	;; TODO: CULLING BACKFACE:
	mov dword ptr [rsp + 28h + (20h*4) + 01C4h + 4h], 1 ; RasterizerState.CullMode : D3D12_CULL_MODE_NONE
	mov dword ptr [rsp + 28h + (20h*4) + 01C4h + 8h], 0 ; RasterizerState.FrontCounterClockwise
	mov dword ptr [rsp + 28h + (20h*4) + 01C4h + 0Ch], 0 ; RasterizerState.DepthBias : D3D12_DEFAULT_DEPTH_BIAS
	mov dword ptr [rsp + 28h + (20h*4) + 01C4h + 10h], 0 ; RasterizerState.DepthBiasClamp : D3D12_DEFAULT_DEPTH_BIAS_CLAMP
	mov dword ptr [rsp + 28h + (20h*4) + 01C4h + 14h], 0 ; RasterizerState.SlopeScaledDepthBias : D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS
	mov dword ptr [rsp + 28h + (20h*4) + 01C4h + 18h], 1 ; RasterizerState.DepthClipEnable
	mov dword ptr [rsp + 28h + (20h*4) + 01C4h + 1Ch], 0 ; RasterizerState.MultisampleEnable
	mov dword ptr [rsp + 28h + (20h*4) + 01C4h + 20h], 0 ; RasterizerState.AntialiasedLineEnable
	mov dword ptr [rsp + 28h + (20h*4) + 01C4h + 24h], 0 ; RasterizerState.ForcedSampleCount
	mov dword ptr [rsp + 28h + (20h*4) + 01C4h + 28h], 0 ; RasterizerState.ConservativeRaster : D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF

	mov dword ptr [rsp + 28h + (20h*4) + 01F0h], 1 ; DepthStencilState.DepthEnable
	mov dword ptr [rsp + 28h + (20h*4) + 01F0h + 4h], 1 ; DepthStencilState.DepthWriteMask : D3D12_DEPTH_WRITE_MASK_ALL
	mov dword ptr [rsp + 28h + (20h*4) + 01F0h + 8h], 4 ; DepthStencilState.DepthFunc : D3D12_COMPARISON_FUNC_LESS
	mov dword ptr [rsp + 28h + (20h*4) + 01F0h + 0Ch], 0 ; DepthStencilState.StencilEnable
	mov byte ptr [rsp + 28h + (20h*4) + 01F0h + 10h], 0 ; DepthStencilState.StencilReadMask
	mov byte ptr [rsp + 28h + (20h*4) + 01F0h + 11h], 0 ; DepthStencilState.StencilWriteMask
	mov dword ptr [rsp + 28h + (20h*4) + 01F0h + 14h], 1 ; DepthStencilState.FrontFace.StencilFailOp : D3D12_STENCIL_OP_KEEP
	mov dword ptr [rsp + 28h + (20h*4) + 01F0h + 18h], 1 ; DepthStencilState.FrontFace.StencilDepthFailOp : D3D12_STENCIL_OP_KEEP
	mov dword ptr [rsp + 28h + (20h*4) + 01F0h + 1Ch], 1 ; DepthStencilState.FrontFace.StencilPassOp : D3D12_STENCIL_OP_KEEP
	mov dword ptr [rsp + 28h + (20h*4) + 01F0h + 20h], 1 ; DepthStencilState.FrontFace.StencilFunc : D3D12_COMPARISON_FUNC_NEVER
	mov dword ptr [rsp + 28h + (20h*4) + 01F0h + 24h], 1 ; DepthStencilState.BackFace.StencilFailOp : D3D12_STENCIL_OP_KEEP
	mov dword ptr [rsp + 28h + (20h*4) + 01F0h + 28h], 1 ; DepthStencilState.BackFace.StencilDepthFailOp : D3D12_STENCIL_OP_KEEP
	mov dword ptr [rsp + 28h + (20h*4) + 01F0h + 2Ch], 1 ; DepthStencilState.BackFace.StencilPassOp : D3D12_STENCIL_OP_KEEP
	mov dword ptr [rsp + 28h + (20h*4) + 01F0h + 30h], 1 ; DepthStencilState.BackFace.StencilFunc : D3D12_COMPARISON_FUNC_NEVER

	lea rax, [rsp + 28h]
	mov qword ptr [rsp + 28h + (20h*4) + 0228h], rax ; InputLayout.pInputElementDescs
	mov dword ptr [rsp + 28h + (20h*4) + 0230h], 3 ; InputLayout.NumElements

	mov dword ptr [rsp + 28h + (20h*4) + 0238h], 0 ; IBStripCutValue : D3D12_INDEX_BUFFER_STRIP_CUT_VALUE_DISABLED
	mov dword ptr [rsp + 28h + (20h*4) + 023Ch], 3 ; PrimitiveTopologyType : D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE
	mov dword ptr [rsp + 28h + (20h*4) + 0240h], 1 ; NumRenderTargets
	mov dword ptr [rsp + 28h + (20h*4) + 0244h], 28 ; RTVFormats[0] : DXGI_FORMAT_R8G8B8A8_UNORM
	mov dword ptr [rsp + 28h + (20h*4) + 0248h], 0 ; RTVFormats[1] : DXGI_FORMAT_UNKNOWN
	mov dword ptr [rsp + 28h + (20h*4) + 024Ch], 0 ; RTVFormats[2] : DXGI_FORMAT_UNKNOWN
	mov dword ptr [rsp + 28h + (20h*4) + 0250h], 0 ; RTVFormats[3] : DXGI_FORMAT_UNKNOWN
	mov dword ptr [rsp + 28h + (20h*4) + 0254h], 0 ; RTVFormats[4] : DXGI_FORMAT_UNKNOWN
	mov dword ptr [rsp + 28h + (20h*4) + 0258h], 0 ; RTVFormats[5] : DXGI_FORMAT_UNKNOWN
	mov dword ptr [rsp + 28h + (20h*4) + 025Ch], 0 ; RTVFormats[6] : DXGI_FORMAT_UNKNOWN
	mov dword ptr [rsp + 28h + (20h*4) + 0260h], 0 ; RTVFormats[7] : DXGI_FORMAT_UNKNOWN
	mov dword ptr [rsp + 28h + (20h*4) + 0264h], 40 ; DSVFormat : DXGI_FORMAT_D32_FLOAT
	;mov dword ptr [rsp + 28h + (20h*4) + 0264h], 0 ; DSVFormat

	mov dword ptr [rsp + 28h + (20h*4) + 0268h], 1 ; SampleDesc.Count
	mov dword ptr [rsp + 28h + (20h*4) + 026Ch], 0 ; SampleDesc.Quality

	mov dword ptr [rsp + 28h + (20h*4) + 0270h], 1 ; NodeMask

	mov qword ptr [rsp + 28h + (20h*4) + 0278h], 0 ; CachedPSO.pCachedBlob
	mov dword ptr [rsp + 28h + (20h*4) + 0280h], 0 ; CachedPSO.CachedBlobSize

	mov dword ptr [rsp + 28h + (20h*4) + 0288h], 0 ; Flags : D3D12_PIPELINE_STATE_FLAG_NONE

	mov rcx, local_dxDevice
	lea rdx, [rsp + 28h + (20h*4)]
	lea r8, IID_ID3D12PipelineState
	lea r9, local_dxDefault3DPipelineState
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateGraphicsPipelineState]
	test eax, eax
	jns _success_created3dpipelinestate
	int 3

_success_created3dpipelinestate:

	mov eax, local_float4_one
	mov ecx, local_float4_negone
	; pos: -1.0, -1.0, 0.0
	mov dword ptr [rsp + 28h + 80h + VERTEX3D.x], ecx ; -1.0
	mov dword ptr [rsp + 28h + 80h + VERTEX3D.y], ecx ; -1.0
	mov dword ptr [rsp + 28h + 80h + VERTEX3D.z], 0 ; 0.0
	; uv: 0, 0
	mov dword ptr [rsp + 28h + 80h + VERTEX3D.u], 0 ; 0.0
	mov dword ptr [rsp + 28h + 80h + VERTEX3D.v], 0 ; 0.0
	; normal: 0, 0, 1
	mov dword ptr [rsp + 28h + 80h + VERTEX3D.nx], 0 ; 0.0
	mov dword ptr [rsp + 28h + 80h + VERTEX3D.ny], 0 ; 0.0
	mov dword ptr [rsp + 28h + 80h + VERTEX3D.nz], eax ; 1.0

	

	; pos: 1.0, 1.0, 0.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D) + VERTEX3D.x], eax ; 1.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D) + VERTEX3D.y], eax ; 1.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D) + VERTEX3D.z], 0 ; 0.0
	; uv: 1, 1
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D) + VERTEX3D.u], eax ; 1.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D) + VERTEX3D.v], eax ; 1.0
	; normal: 0, 0, 1
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D) + VERTEX3D.nx], 0 ; 0.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D) + VERTEX3D.ny], 0 ; 0.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D) + VERTEX3D.nz], eax ; 1.0

	; pos: 1.0, -1.0, 0.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D)*2 + VERTEX3D.x], eax ; 1.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D)*2 + VERTEX3D.y], ecx ; -1.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D)*2 + VERTEX3D.z], 0 ; 0.0
	; uv: 1, 0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D)*2 + VERTEX3D.u], eax ; 1.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D)*2 + VERTEX3D.v], 0 ; 0.0
	; normal: 0, 0, 1
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D)*2 + VERTEX3D.nx], 0 ; 0.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D)*2 + VERTEX3D.ny], 0 ; 0.0
	mov dword ptr [rsp + 28h + 80h + (SIZEOF VERTEX3D)*2 + VERTEX3D.nz], eax ; 1.0

	lea rcx, [rsp + 28h + 80h]
	mov rdx, (SIZEOF VERTEX3D)*3
	call winDX12CreateUploadResource

	mov local_testBuffer, rax


	add rsp, (28h + (20h*4) + 2b0h)
	ret
winDX12CreatePipelineStates ENDP

; PARAM0 (RCX) : pointer to buffer
; PARAM1 (RDX) : size of buffer
; RETURN (RAX) : ID3D12Resource
winDX12CreateUploadResource PROC
	push rdi
	push rsi
	sub rsp, 0a8h
	
	mov rdi, rcx
	mov rsi, rdx

	lea rdx, [rsp + 48h]
	mov dword ptr [rdx + 0h], 2 ; Type : D3D12_HEAP_TYPE_UPLOAD
	mov dword ptr [rdx + 4h], 0 ; CPUPageProperty : D3D12_CPU_PAGE_PROPERTY_UNKNOWN
	mov dword ptr [rdx + 8h], 0 ; MemoryPoolPreference : D3D12_MEMORY_POOL_UNKNOWN
	mov dword ptr [rdx + 0Ch], 1 ; CreationNodeMask
	mov dword ptr [rdx + 10h], 1 ; VisibleNodeMask

	lea r9, [rsp + 48h + 14h]
	mov dword ptr [r9], 1 ; Dimension : D3D12_RESOURCE_DIMENSION_BUFFER
	mov qword ptr [r9 + 8h], 0 ; Alignment
	mov qword ptr [r9 + 10h], rsi ; Width
	mov dword ptr [r9 + 18h], 1 ; Height
	mov word ptr [r9 + 1Ch], 1 ; DepthOrArraySize
	mov word ptr [r9 + 1Eh], 1 ; MipLevels
	mov dword ptr [r9 + 20h], 0 ; Format : DXGI_FORMAT_UNKNOWN
	mov dword ptr [r9 + 24h], 1 ; SampleDesc.Count
	mov dword ptr [r9 + 28h], 0 ; SampleDesc.Quality
	mov dword ptr [r9 + 2Ch], 1 ; Layout : D3D12_TEXTURE_LAYOUT_ROW_MAJOR
	mov dword ptr [r9 + 30h], 0 ; Flags : D3D12_RESOURCE_FLAG_NONE
	
	mov r8d, 0 ; HeapFlags : D3D12_HEAP_FLAG_NONE
	mov dword ptr [rsp + 020h], 2755 ; InitialResourceState : D3D12_RESOURCE_STATE_GENERIC_READ
	mov qword ptr [rsp + 028h], 0 ; pOptimizedClearValue
	lea rax, IID_ID3D12Resource
	mov qword ptr [rsp + 030h], rax ; riid
	lea rax, [rsp + 040h]
	mov qword ptr [rsp + 038h], rax ; ppResource
	mov rcx, local_dxDevice
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateCommittedResource]

	mov rcx, qword ptr [rsp + 040h]
	xor edx, edx ; Subresource
	xor r8d, r8d ; pReadRange
	lea r9, [rsp + 048h]
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Resource_Map]

	mov rcx, qword ptr [rsp + 048h]
	xor edx, edx
_move_next_byte:
	mov al, byte ptr [rdi+rdx]
	mov byte ptr [rcx+rdx], al
	inc rdx
	dec rsi
	jnz _move_next_byte

	mov rcx, qword ptr [rsp + 040h]
	xor edx, edx ; Subresource
	xor r8d, r8d ; pWrittenRange
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Resource_Unmap]

	mov rax, qword ptr [rsp + 040h]
	add rsp, 0a8h
	pop rsi
	pop rdi
	ret
winDX12CreateUploadResource ENDP

winDX12CreateSwapChainResources PROC
	sub rsp, 0d0h
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

	; depth stencil buffer
	; local_dxDepthBuffer

	; D3D12_HEAP_PROPERTIES
	lea rdx, [rsp + 058h]
	mov dword ptr [rdx + 0h], 1 ; Type : D3D12_HEAP_TYPE_DEFAULT
	mov dword ptr [rdx + 4h], 0 ; CPUPageProperty : D3D12_CPU_PAGE_PROPERTY_UNKNOWN
	mov dword ptr [rdx + 8h], 0 ; MemoryPoolPreference : D3D12_MEMORY_POOL_UNKNOWN
	mov dword ptr [rdx + 0Ch], 1 ; CreationNodeMask
	mov dword ptr [rdx + 10h], 1 ; VisibleNodeMask

	; D3D12_RESOURCE_DESC
	lea r9, [rsp + 58h + 18h]
	mov dword ptr [r9], 3 ; Dimension : D3D12_RESOURCE_DIMENSION_TEXTURE2D
	mov qword ptr [r9 + 8h], 0 ; Alignment
	mov eax, local_windowRect.right
	sub eax, local_windowRect.left
	mov qword ptr [r9 + 10h], rax ; Width
	mov eax, local_windowRect.bottom
	sub eax, local_windowRect.top
	mov dword ptr [r9 + 18h], eax ; Height
	mov word ptr [r9 + 1Ch], 1 ; DepthOrArraySize
	mov word ptr [r9 + 1Eh], 1 ; MipLevels
	mov dword ptr [r9 + 20h], 40 ; Format : DXGI_FORMAT_D32_FLOAT
	mov dword ptr [r9 + 24h], 1 ; SampleDesc.Count
	mov dword ptr [r9 + 28h], 0 ; SampleDesc.Quality
	mov dword ptr [r9 + 2Ch], 0 ; Layout : D3D12_TEXTURE_LAYOUT_UNKNOWN
	mov dword ptr [r9 + 30h], 2 ; Flags : D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL

	xor r8d, r8d ; D3D12_HEAP_FLAG_NONE

	lea rax, [rsp + 0A8h]
	mov dword ptr [rax + 0h], 40 ; Format : DXGI_FORMAT_D32_FLOAT
	mov dword ptr [rax + 4h], 03f800000h ; Depth
	mov dword ptr [rax + 8h], 0 ; Stencil

	mov dword ptr [rsp + 020h], 16; InitialResourceState : D3D12_RESOURCE_STATE_DEPTH_WRITE
	mov qword ptr [rsp + 028h], rax ; pOptimizedClearValue
	lea rax, IID_ID3D12Resource
	mov qword ptr [rsp + 030h], rax ; riid
	lea rax, local_dxDepthBuffer
	mov qword ptr [rsp + 038h], rax ; ppResource
	mov rcx, local_dxDevice
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateCommittedResource]
	test eax, eax
	jns _success_createddepthbuffer
	int 3

_success_createddepthbuffer:

	mov dword ptr [rsp + 38h], 40 ; Format : DXGI_FORMAT_D32_FLOAT
	mov dword ptr [rsp + 38h + 4h], 3 ; ViewDimension : D3D12_DSV_DIMENSION_TEXTURE2D
	mov dword ptr [rsp + 38h + 8h], 0 ; Flags : D3D12_DSV_FLAG_NONE
	mov dword ptr [rsp + 38h + 0Ch], 0
	mov qword ptr [rsp + 38h + 010h], 0
	mov qword ptr [rsp + 38h + 018h], 0

	mov rcx, local_dxDepthDescriptorHeap
	lea rdx, [rsp + 28h]
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart]
	
	mov rcx, local_dxDevice
	mov rdx, local_dxDepthBuffer ; pResource
	lea r8, [rsp + 38h] ; pDesc
	mov r9, qword ptr [rsp + 28h] ; DestDescriptor
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Device_CreateDepthStencilView]


	pop rsi
	add rsp, 0d0h
	ret
winDX12CreateSwapChainResources ENDP

winDX12Frame PROC
	push rsi
	sub rsp, 80h
	

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

	mov dword ptr [rsp +30h + D3D12_VIEWPORT._TopLeftX], 0
	mov dword ptr [rsp +30h + D3D12_VIEWPORT._TopLeftY], 0

	mov eax, local_windowRect.right
	sub eax, local_windowRect.left
	; convert to float
	movd xmm0, eax
	cvtdq2ps xmm0, xmm0
	movd dword ptr [rsp +30h + D3D12_VIEWPORT._Width], xmm0

	mov eax, local_windowRect.bottom
	sub eax, local_windowRect.top
	; convert to float
	movd xmm0, eax
	cvtdq2ps xmm0, xmm0
	movd dword ptr [rsp +30h + D3D12_VIEWPORT._Height], xmm0

	mov dword ptr [rsp +30h + D3D12_VIEWPORT._MinDepth], 0
	mov eax, local_float4_one
	mov dword ptr [rsp +30h + D3D12_VIEWPORT._MaxDepth], eax
	
	mov rcx, local_dxCommandList
	mov edx, 1
	lea r8, [rsp + 30h]
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_RSSetViewports]

	mov rcx, local_dxCommandList
	mov edx, 1
	lea r8, local_windowRect
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_RSSetScissorRects]

	mov rcx, local_dxDepthDescriptorHeap
	lea rdx, [rsp + 48h]
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart]



	; set render target
	mov ecx, local_dxBackBufferIndex
	lea rax, local_dxRTVHandle0
	mov rax, qword ptr [rax + rcx*8]
	mov qword ptr [rsp + 28h], rax
	mov rcx, local_dxCommandList
	mov edx, 1 ; NumRenderTargetDescriptors
	lea r8, [rsp + 28h] ; pDescriptors
	xor r9d, r9d ; RTsSingleHandleToDescriptorRange
	lea rax, [rsp + 48h]
	mov qword ptr [rsp + 20h], rax ; pDepthStencilDescriptor
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_OMSetRenderTargets]

	mov rcx, local_dxCommandList
	mov rdx, qword ptr [rsp + 48h]
	mov r8d, 1 ; ClearFlags : D3D12_CLEAR_FLAG_DEPTH
	mov r9d, 03f800000h ; Depth
	movd xmm3, r9d
	mov qword ptr [rsp + 20h], 0 ; 
	mov qword ptr [rsp + 28h], 0 ; 
	mov qword ptr [rsp + 30h], 0 ; 
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_ClearDepthStencilView]



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



	


	mov rcx, local_dxCommandList
	mov rdx, local_dxRootSignature
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_SetGraphicsRootSignature]

	mov rcx, local_dxCommandList
	mov rdx, local_dxDefault3DPipelineState
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_SetPipelineState]

	mov rcx, local_dxCommandList
	xor edx, edx ; RootParameterIndex
	mov r8d, 03f000000h ; SrcData
	xor r9d, r9d ; DestOffsetIn32BitValues
	
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_SetGraphicsRoot32BitConstant]


	mov rcx, local_dxCommandList
	mov edx, 4 ; PrimitiveTopology : D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_IASetPrimitiveTopology]

	mov rcx, local_testBuffer
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12Resource_GetGPUVirtualAddress]
	mov qword ptr [rsp + 28h], rax ; BufferLocation
	mov dword ptr [rsp + 28h + 8], SIZEOF VERTEX3D * 3 ; SizeInBytes
	mov dword ptr [rsp + 28h + 0Ch], SIZEOF VERTEX3D ; StrideInBytes


	

	mov rcx, local_dxCommandList
	xor edx, edx ; StartSlot
	mov r8d, 1 ; NumViews
	lea r9, [rsp + 28h] ; pViews
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_IASetVertexBuffers]

	mov rcx, local_dxCommandList
	mov edx, 3 ; VertexCountPerInstance
	mov r8d, 1 ; InstanceCount
	xor r9d, r9d ; StartVertexLocation
	mov dword ptr [rsp + 20h], 0 ; StartInstanceLocation
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_ID3D12GraphicsCommandList_DrawInstanced]



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

	
	add rsp, 80h
	pop rsi
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
	test rcx, rcx
	jz _skip_rtv_buffer1
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxRTVBuffer1, 0
_skip_rtv_buffer1:

	mov rcx, local_dxRTVBuffer0
	test rcx, rcx
	jz _skip_rtv_buffer0
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxRTVBuffer0, 0
_skip_rtv_buffer0:

	mov rcx, local_dxDepthBuffer
	test rcx, rcx
	jz _skip_depth_buffer
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxDepthBuffer, 0
_skip_depth_buffer:

	add rsp, 28h
	ret
winDX12ReleaseSwapChainResources ENDP

winDX12Exit PROC
	sub rsp, 28h

	mov rcx, local_testBuffer
	test rcx, rcx
	jz _skip_test_buffer
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_testBuffer, 0
_skip_test_buffer:

	mov rcx, local_dxDefault3DPipelineState
	test rcx, rcx
	jz _skip_default3dpipelinestate
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxDefault3DPipelineState, 0
_skip_default3dpipelinestate:

	mov rcx, local_dxRootSignature
	test rcx, rcx
	jz _skip_root_signature
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxRootSignature, 0
_skip_root_signature:

	call winDX12ReleaseSwapChainResources

	mov rcx, local_dxRTVDescriptorHeap
	test rcx, rcx
	jz _skip_rtv_descriptor_heap
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxRTVDescriptorHeap, 0
_skip_rtv_descriptor_heap:

	mov rcx, local_dxDepthDescriptorHeap
	test rcx, rcx
	jz _skip_depth_descriptor_heap
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxDepthDescriptorHeap, 0
_skip_depth_descriptor_heap:


	mov rcx, local_dxFence
	test rcx, rcx
	jz _skip_fence
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxFence, 0
_skip_fence:

	mov rcx, local_dxSwapChain
	test rcx, rcx
	jz _skip_swap_chain
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxSwapChain, 0
_skip_swap_chain:


	mov rcx, local_dxCommandList
	test rcx, rcx
	jz _skip_command_list
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxCommandList, 0
_skip_command_list:


	mov rcx, local_dxCommandAllocator
	test rcx, rcx
	jz _skip_command_allocator
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxCommandAllocator, 0
_skip_command_allocator:

	
			 
	mov rcx, local_dxCommandQueue
	test rcx, rcx
	jz _skip_command_queue
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxCommandQueue, 0
_skip_command_queue:
	
	mov rcx, local_dxDevice
	test rcx, rcx
	jz _skip_device
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxDevice, 0
_skip_device:

	mov rcx, local_dxAdapter
	test rcx, rcx
	jz _skip_adapter
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxAdapter, 0
_skip_adapter:

	mov rcx, local_dxFactory
	test rcx, rcx
	jz _skip_factory
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxFactory, 0
_skip_factory:

	mov rcx, local_dxDebug
	test rcx, rcx
	jz _skip_debug
	mov rax, qword ptr [rcx]
	call qword ptr [rax + VTBL_IUnknown_Release]
	mov local_dxDebug, 0
_skip_debug:

;335178
;; const CLayeredObject<class NDebug::CDevice>::CContainedObject::`vftable'{for `IDXGIDebugProducer'}
;.rdata:0000000180335178 ??_7CContainedObject@?$CLayeredObject@VCDevice@NDebug@@@@6BIDXGIDebugProducer@@@ dq offset ?QueryInterface@CContainedObject@?$CLayeredObject@VCDevice@NDebug@@@@WHI@EAAJAEBU_GUID@@PEAPEAX@Z

	add rsp, 28h
	ret
winDX12Exit ENDP




END
