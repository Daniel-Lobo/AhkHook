#include <memlib\memlib>
#include <shell>
SetWorkingDir %A_ScriptDir%  
OnMessage(0x4a, "WM_COPYDATA") 

if !A_iscompiled
	runwait, Ahk2Exe.exe /in %A_scriptName% /out ahkhook.exe /mpress 0	

FileInstall, HookClass.txt, ?Dummy
compileScript("HookClass.ahk")

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
	g_ahkpath :=  A_scriptdir "\AutoHotkey.dll" 
	g_peixotopath := A_scriptdir "\ahkhook.dll" 
		
	dllcall("LoadLibraryW", str, g_ahkpath) ?: Quit(1, A_lasterror)
	dllcall("LoadLibraryW", str, g_peixotopath) ?: Quit(2, A_lasterror)	
	
	SplitPath, target, name, dir
	__args := (no_argv0) ? "" : """" target """ "
	__args .= args
	if ! isobject( (proc := CreateIdleProcess(target, dir, __args)) )
		quit(3, proc)
	
	(err := dllcallEx(proc.hProcess, "Kernel32.dll", "LoadLibraryW", g_ahkpath)) ? Quit(4, err)	
	(err := dllcallEx(proc.hProcess, "Kernel32.dll", "LoadLibraryW", g_peixotopath)) ? Quit(5, err)	
		
	success := dllcallEx(proc.hProcess, "autohotkey.dll", "ahktextdll", LoadResource("HookClass.txt", A_iscompiled ? "": "ahkhook.exe") "`n" script "`nresume()")
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

LoadResource(resource, module = "")
{
	if not module
		hModule := dllcall("GetModuleHandle", uint,  0)
	else FreeLater := hModule := dllcall("LoadLibraryW", str, module, uint, 0, uint, (LOAD_LIBRARY_AS_DATAFILE := 0x00000002))
	HRSRC := dllcall("FindResourceW", uint, hModule, str, resource, ptr, 10)
	hResource := dllcall("LoadResource", uint, hModule, uint, HRSRC)
	DataSize := DllCall("SizeofResource", ptr, hModule, ptr, HRSRC, uint)
	pResData := dllcall("LockResource", uint, hResource, ptr)
	ret := strget(pResData, DataSize, "UTF-8")
	;dllcall("FreeResource", uint, hResource) 
	FreeLater ? dllcall("FreeLibrary", uint, hModule)
	return ret
}