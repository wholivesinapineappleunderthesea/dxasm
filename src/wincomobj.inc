VTBL_IUnknown_QueryInterface EQU 0h
VTBL_IUnknown_AddRef EQU 08h
VTBL_IUnknown_Release EQU 010h

; MIDL_INTERFACE("aec22fb8-76f3-4639-9be0-28eb43a67a2e")
EXTERN GUID_IDXGIObject:BYTE
VTBL_IDXGIObject_SetPrivateData EQU 018h
VTBL_IDXGIObject_SetPrivateDataInterface EQU 020h
VTBL_IDXGIObject_GetPrivateData EQU 028h
VTBL_IDXGIObject_GetParent EQU 030h

; MIDL_INTERFACE("7b7166ec-21c7-44ae-b21a-c9ae321ae369")
EXTERN GUID_IDXGIDeviceSubObject:BYTE
VTBL_IDXGIFactory_EnumAdapters EQU 038h
VTBL_IDXGIFactory_MakeWindowAssociation EQU 040h
VTBL_IDXGIFactory_GetWindowAssociation EQU 048h
VTBL_IDXGIFactory_CreateSwapChain EQU 050h
VTBL_IDXGIFactory_CreateSoftwareAdapter EQU 058h

; MIDL_INTERFACE("770aae78-f26f-4dba-a829-253c83d1b387")
EXTERN GUID_IDXGIAdapter:BYTE
VTBL_IDXGIFactory1_EnumAdapters1 EQU 060h
VTBL_IDXGIFactory1_IsCurrent EQU 068h