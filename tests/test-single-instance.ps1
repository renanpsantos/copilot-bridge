$ErrorActionPreference='Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WindowProbe {
 delegate bool EnumCallback(IntPtr handle,IntPtr state);
 [DllImport("user32.dll")] static extern bool EnumWindows(EnumCallback callback,IntPtr state);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr handle,out uint pid);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr handle,System.Text.StringBuilder title,int capacity);
 public static IntPtr Find(int target) {
  IntPtr result=IntPtr.Zero;
  EnumWindows(delegate(IntPtr handle,IntPtr state) {
   uint pid;GetWindowThreadProcessId(handle,out pid);
   var title=new System.Text.StringBuilder(256);GetWindowText(handle,title,title.Capacity);
   if(pid==target && title.ToString().StartsWith("Lucy MCP v")) { result=handle;return false; }
   return true;
  },IntPtr.Zero);
  return result;
 }
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr handle,int command);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr handle);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr handle,uint message,IntPtr wParam,IntPtr lParam);
}
'@
$source=Split-Path $PSScriptRoot -Parent
$root=Join-Path (Split-Path $source -Parent) ('work\instance-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$profile=Join-Path $root 'profile';$other=Join-Path $root 'other-install'
[void](New-Item -ItemType Directory -Force -Path $profile,$other)
Copy-Item (Join-Path $source 'LucyMcpGui.ps1'),(Join-Path $source 'SingleInstance.cs') -Destination $other
$shell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
function Launch([string]$Script,[string]$Label){
 $child=Start-Process -FilePath $shell -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+$Script+'"'),'-DataDirectory',('"'+$profile+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $root ($Label+'.out')) -RedirectStandardError (Join-Path $root ($Label+'.err'))
 [void]$child.Handle
 return $child
}
$first=$null;$second=$null;$reopened=$null
try{
 $first=Launch (Join-Path $source 'LucyMcpGui.ps1') 'first'
 $deadline=[DateTime]::UtcNow.AddSeconds(30)
 do{$first.Refresh();if($first.HasExited){throw ('GUI failed: '+(Get-Content (Join-Path $root 'first.err') -Raw))};$handle=[WindowProbe]::Find($first.Id);if($handle -ne [IntPtr]::Zero){break};Start-Sleep -Milliseconds 100}while([DateTime]::UtcNow -lt $deadline)
 if($handle -eq [IntPtr]::Zero){throw 'GUI window did not appear'}
 [void][WindowProbe]::ShowWindow($handle,6)
 if(![WindowProbe]::IsIconic($handle)){throw 'Fixture was not minimized'}
 $second=Launch (Join-Path $other 'LucyMcpGui.ps1') 'second'
 if(!$second.WaitForExit(30000)){throw 'Duplicate instance did not exit'}
 if($second.ExitCode -ne 0){throw ('Duplicate instance failed (exit '+$second.ExitCode+'): '+(Get-Content (Join-Path $root 'second.err') -Raw))}
 $deadline=[DateTime]::UtcNow.AddSeconds(8)
 while([WindowProbe]::IsIconic($handle) -and [DateTime]::UtcNow -lt $deadline){Start-Sleep -Milliseconds 100}
 $first.Refresh()
 if($first.HasExited -or [WindowProbe]::IsIconic($handle)){throw 'Existing GUI was not restored'}
 Write-Output ('PASS: second launch from another installation exited and restored the existing window. Foreground observed: '+([WindowProbe]::GetForegroundWindow() -eq $handle))
 [void][WindowProbe]::PostMessage($handle,16,[IntPtr]::Zero,[IntPtr]::Zero)
 if(!$first.WaitForExit(15000)){throw 'First GUI did not close'}
 $reopened=Launch (Join-Path $source 'LucyMcpGui.ps1') 'reopened'
 $deadline=[DateTime]::UtcNow.AddSeconds(30)
 do{$reopened.Refresh();if($reopened.HasExited){throw 'Reopen failed'};if([WindowProbe]::Find($reopened.Id) -ne [IntPtr]::Zero){break};Start-Sleep -Milliseconds 100}while([DateTime]::UtcNow -lt $deadline)
 if([WindowProbe]::Find($reopened.Id) -eq [IntPtr]::Zero){throw 'Mutex was not released on close'}
 Write-Output 'PASS: app reopened after closing. No MCP publication or tunnel started.'
}finally{
 foreach($process in @($first,$second,$reopened)){
  if($process){$process.Refresh();if(!$process.HasExited){$window=[WindowProbe]::Find($process.Id);if($window -ne [IntPtr]::Zero){[void][WindowProbe]::PostMessage($window,16,[IntPtr]::Zero,[IntPtr]::Zero)};if(!$process.WaitForExit(5000)){$process.Kill()}};$process.Dispose()}
 }
}
