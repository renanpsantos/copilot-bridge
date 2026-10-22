using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
internal static class LegacyLauncher {
 [STAThread] static void Main() {
  try {
   string executable=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"CopilotBridge.exe");
   if(!File.Exists(executable))throw new FileNotFoundException("Extraia o pacote completo e abra CopilotBridge.exe.");
   Process.Start(new ProcessStartInfo(executable) { UseShellExecute=false,WorkingDirectory=AppDomain.CurrentDomain.BaseDirectory });
  } catch(Exception error) { MessageBox.Show(error.Message,"Copilot Bridge",MessageBoxButtons.OK,MessageBoxIcon.Error); }
 }
}
