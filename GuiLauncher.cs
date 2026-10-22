using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
internal static class GuiLauncher {
 [STAThread] static void Main() {
  try {
   string root=AppDomain.CurrentDomain.BaseDirectory;
   string script=Path.Combine(root,"LucyMcpGui.ps1");
   if(!File.Exists(script))throw new FileNotFoundException("Extraia o ZIP inteiro antes de abrir o aplicativo.");
   string shell=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"WindowsPowerShell\\v1.0\\powershell.exe");
   ProcessStartInfo start=new ProcessStartInfo(shell,"-NoProfile -STA -ExecutionPolicy Bypass -File \""+script+"\"");
   start.WorkingDirectory=root;start.UseShellExecute=false;start.CreateNoWindow=true;
   start.EnvironmentVariables["PSModulePath"]=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"WindowsPowerShell\\v1.0\\Modules")+";"+Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),"WindowsPowerShell\\Modules");
   Process.Start(start);
  }catch(Exception error){MessageBox.Show(error.Message,"Lucy MCP",MessageBoxButtons.OK,MessageBoxIcon.Error);}
 }
}
