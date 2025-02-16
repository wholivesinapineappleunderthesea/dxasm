EXTERN global_moduleSize : DWORD
EXTERN global_moduleBaseAddr : QWORD

EXTERN global_moduleFolderPath:WORD ; 512
EXTERN global_moduleFolderPathLen:WORD
EXTERN global_moduleFileName:QWORD ; a.exe, ptr into global_moduleFolderPath
EXTERN global_moduleFileNameLen:WORD

; window
EXTERN global_windowHandle:QWORD

;
; win functions
;

; NOPARAM
EXTERN winInit:PROC
; NOPARAM
EXTERN winExit:PROC
; NOPARAM
EXTERN winTerm:PROC

;
; heap functions
;

; 
; ECX : byte count
EXTERN winHeapAlloc:PROC

; RCX : address
EXTERN winHeapFree:PROC