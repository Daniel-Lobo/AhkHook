#include <memlib\memlib>
#include <shell>
SetWorkingDir %A_ScriptDir%  
OnMessage(0x4a, "WM_COPYDATA") 

if !A_iscompiled
	runwait, Ahk2Exe.exe /in %A_scriptName% /out ahkhook64.exe /bin "C:\Program Files\AutoHotkey\Compiler\Unicode 64-bit.bin" /mpress 0	

global proc
global target   := GetCommandLineValueB("-t")
global script   := GetCommandLineValueB("-s")
global no_argv0 := instr(dllcall("GetCommandLine", str), "-n")
global args     := GetCommandLineValueB("-a")
global env      := GetCommandLineValueB("-e")
fileread, script, %script%

launchTarget(target)
launchTarget(target)
{
	if env
		envset, remote_settings, %env%	
	
	envset, injector_hwnd, %A_scripthwnd%	
	g_ahkpath := A_scriptdir "\AutoHotkey64.dll"
	g_peixotopath := A_scriptdir "\ahkhook64.dll" 
		
	dllcall("LoadLibraryW", str, g_ahkpath) ?: Quit(1, A_lasterror)
	dllcall("LoadLibraryW", str, g_peixotopath) ?: Quit(2, A_lasterror)	
	
	SplitPath, target, name, dir
	__args := (no_argv0) ? "" : """" target """ "
	__args .= args
	if ! isobject( (proc := CreateIdleProcess(target, dir, __args)) )
		quit(3, proc)
	
	(err := dllcallEx(proc.hProcess, "Kernel32.dll", "LoadLibraryW", g_ahkpath)) ? Quit(4, err)	
	(err := dllcallEx(proc.hProcess, "Kernel32.dll", "LoadLibraryW", g_peixotopath)) ? Quit(5, err)	
		
	success := dllcallEx(proc.hProcess, "AutoHotkey64.dll", "ahktextdll", LoadResource("HookClass.txt") "`n" script "`nresume()")
	success ? quit(6, success)
	
	id := proc.Process_id
	process, waitclose, %id%	
	exitapp
}

quit(level, lasterror)
{	
	exitcode := (level<<16) | lasterror
	ExitApp, %exitcode%
}

WM_COPYDATA(wParam, lParam)
{	
	ResumeProcess(proc.hThread)
}

compileScript(script)
{
	if A_iscompiled 
		return	
	splitpath, script, , , ,script_name	
	runwait, Ahk2Exe.exe /in %script% /out %script_name%.exe 							
	script_txt := LoadResource(">AUTOHOTKEY SCRIPT<", script_name ".exe")
	filedelete, %script_name%.txt
	fileappend, %script_txt%, %script_name%.txt
}	

LoadResource(resource, module = "ahkhook.exe")
{
	if not module
		hModule := dllcall("GetModuleHandle", uint,  0, ptr)
	else FreeLater := hModule := dllcall("LoadLibraryExW", str, A_scriptdir "\ahkhook.exe", uint, 0, uint, (LOAD_LIBRARY_AS_DATAFILE := 0x00000002), ptr)
	HRSRC := dllcall("FindResourceW", ptr, hModule, str, resource, ptr, 10)
	hResource := dllcall("LoadResource", ptr, hModule, uint, HRSRC)
	DataSize := DllCall("SizeofResource", ptr, hModule, ptr, HRSRC, uint)
	pResData := dllcall("LockResource", ptr, hResource, ptr)
	ret := strget(pResData, DataSize, "UTF-8")
	FreeLater ? dllcall("FreeLibrary", uint, hModule)
	return ret
}