/* This script serves the dual purpose of launching ahkhook.exe and also of being injected in the target application. 
 * If you intend to distribute your script to others that don't have auohotkey in their computer, the task of 
 * launching ahkhook.exe can be carried out by a batch script or another compiled ahk script.
 * You also should note that i use an old autohotkey.dll version because the new ones depend on Visual c++ 2010.
 * The one included here depends on Visual C++ 2008, just as ahkhook.exe
 */
 
#NoEnv
SetWorkingDir %A_ScriptDir%  
#SingleInstance Ignore

if ! A_isdll
{
	/* This script needs to run as administrator if we want to check the exitcode from ahkhook.exe for errors
	 */
	if not A_isadmin 
	{
		Loop, %0%  
			params .=  A_Space . """" %A_Index% """"
		
		ShellExecute := A_IsUnicode ? "shell32\ShellExecute" : "shell32\ShellExecuteA"
		A_IsCompiled
			? DllCall(ShellExecute, uint, 0, str, "RunAs", str, A_ScriptFullPath, str, params, str, A_WorkingDir, int, 1)
			: DllCall(ShellExecute, uint, 0, str, "RunAs", str, A_AhkPath, str, """" . A_ScriptFullPath . """" . A_Space . params
			, str, A_WorkingDir, int, 1)
		ExitApp	
	}
		
	target=%1%
	if not target 
	{
		msgbox, 16, , Drag and drop the taget application over the script !
		ExitApp
	}
	
	/*  These are the command switches accepted by ahkhook.exe:
	 *	-t  the full path of application that should be started and in which this script will be injected
	 *	-s  the full path of the script to be injected
	 *	-a commanline arguments that must be passed to the target application
	 *	-e a string that can be passed to the injected script through the enviroment variable: remote_settings
	 *	-n if this switch is used, ahkhook.exe doesn't add the path of the target application as the first command line argument
	 */

	run ..\ahkhook.exe -t "%target%" -s "%A_scriptfullpath%" -a """"commandline argument with quotes"""" -e "settings test", , ,ProcessID
	hProcess := DllCall("OpenProcess", "Int", 0x0008 | 0x0010 | 0x0020 |  0x0400, "char", 0, "uint", ProcessID, "uint")	
	process, waitclose, %ProcessID%
	dllcall("GetExitCodeProcess", uint, hProcess, "uint*", exitcode)
	if exitcode
	{
		/*  You can use the exit code from ahkhook.exe to check for any errors.
		 *	Here's what those code mean
		 *
		 *	Hiword 1 or 2: Failure to load autohotkey.dll or ahkhook.dll respectivelly. These dlls must be in the same directory as ahkhook.exe.
		 *	The lowword contains the error code set by the LoadLibrary function
		 *
		 *	Hiword 3: Failure calling CreateProcess. The lowword contains the error code set by that function
		 *
		 *	Hiword 4, 5, 6: Failure injecting autohotkey.dll or ahkhook.dll respectivelly, or calling the ahktextdll function in the injected autohotkey.dll 
		 *  The lowword codes are similar for all 3 codes, since loading the dlls is similar to calling the ahktextdll function in the injected
 		 *  autohotkey.dll, because what we do is to call LoadLibrary in the Kernel32.dll running in the target application. The lowword codes are
		 *	1. Failure to retrieve the address of the target procedure (LoadLibrary or ahktextdll) in ahkhook.exe
		 *	2. Failure calling VirtualAllocEx
		 *	3. Failure calling WriteProcessMemory
		 *	4. Failure calling CreateRemoteThread
		 */
		msgbox % " Hiword: " (exitcode>>16) & 0xffff " -  Lowword: " exitcode & 0xffff 
				
	}
	exitapp
}

/* The code from now on runs if A_isdll = 1. In other words, this is the code 
 * that runs in the target application.
 *
 * VERY IMPORTANT: never return from the autoexecute section in the code that gets injected, 
 * or ahkhook.exe won't resume the target aplication, which is started in paused state
 */

envget, my_settings, remote_settings
msgbox % "Testing the ""-e"" command, the string passed was: """ my_settings """"

/* The parameters to create a hook object are:
 * The name of the autohotkey hook function
 * The dll that exports the function to be hooked
 * The function to be hooked
 * Options passed to the registercallback function, default: "F"
 */
 
global msgbox_hook := new Hook("MessageBoxW", "User32.dll", "MessageBoxW")

/* Check if the contructor returns an object. If not, it will return a string
 * or a minhook numerical error code
 */

MessageBoxW(p1, p2, p3, p4)
{
	r := dllcall(msgbox_hook.Trampoline, uint, p1, uint, p2, str, "This Messagebox was hooked", uint, p4)	
	/* Unhook a function just by deleting the hook object. You will note that in the supplyed MesageBox test propgram, 
	 * only the first message box is hooked
	 */
	msgbox_hook := ""
	return r
}
