#NoEnv 
#persistent  
#notrayicon  
#KeyHistory 0
#MaxThreads 1
critical, 0xFFFFFFFF
ListLines Off
SetBatchLines, -1

resume()  
{
	envget, injector_hwnd, injector_hwnd
	StringToSend := "resume"
	VarSetCapacity(CopyDataStruct, 3*A_PtrSize, 0)  
	SizeInBytes := (StrLen(StringToSend) + 1) * (A_IsUnicode ? 2 : 1)
	NumPut(SizeInBytes, CopyDataStruct, A_PtrSize)
	NumPut(&StringToSend, CopyDataStruct, 2*A_PtrSize)
	return dllcall("SendMessageW", uint, injector_hwnd, uint, 0x4a, uint, 0, uint, &CopyDataStruct) 	 
}

class Hook {

__new(hook, dll, function2hook, callback_options = "F")
{
	if ! (hModule := dllcall("GetModuleHandle", "str", "ahkhook.dll", ptr) )
		return "Failed to get a handle to peixoto.dll with error " A_lasterror
	if ! (sethooks := dllcall("GetProcAddress", "ptr", hModule, "astr", "sethook", ptr)	)		
		return "Failed to get the address of the sethook procedure with error " A_lasterror	
	if ! (this.unhook := dllcall("GetProcAddress", "ptr", hModule, "astr", "unhook", ptr)	)		
		return "Failed to get the address of the unhook procedure with error " A_lasterror		
	
	if ! (this.hook_callback := registercallback(hook, callback_options) )
		return "Failed to register the autohotkey callback"	
				
	if ! (hHookedModule := dllcall("GetModuleHandle", "str", dll, ptr) )
		return "Failed to get a handle to dll that exports the function to be hooked with error " A_lasterror
	if ! (function2hook_add := dllcall("GetProcAddress", "ptr", hHookedModule, "astr", function2hook, ptr) )			
		return "Failed to get the address of the function to hook with error " A_lasterror	
	
	this.OriginalPtr :=	function2hook_add
	r := dllcall(sethooks, "Ptr*", function2hook_add, "Ptr", this.hook_callback, int)
	if r
		return r	
	this.Trampoline  := function2hook_add	
}

__delete()
{
	if ! (dllcall(this.unhook, "Ptr*", This.OriginalPtr, "Ptr", this.Trampoline))
		DllCall("GlobalFree", "Ptr", this.hook_callback, "Ptr")
}

}