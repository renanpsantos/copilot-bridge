using System;
using System.IO;
using System.IO.MemoryMappedFiles;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Windows.Forms;

public sealed class LucySingleInstance : IDisposable {
 readonly Mutex mutex;
 readonly EventWaitHandle activation;
 MemoryMappedFile owner;
 public bool IsPrimary { get; private set; }
 [DllImport("user32.dll")] static extern bool AllowSetForegroundWindow(uint processId);
 [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
 [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr window, int command);
 readonly string name;
 public LucySingleInstance(string dataDirectory) {
  string identity=WindowsIdentity.GetCurrent().User.Value+"|"+Path.GetFullPath(dataDirectory).TrimEnd('\\').ToUpperInvariant();
  using(SHA256 hash=SHA256.Create()) {
   name="Local\\LucyMcp.Gui."+BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes(identity))).Replace("-","");
  }
  activation=new EventWaitHandle(false,EventResetMode.AutoReset,name+".activate");
  mutex=new Mutex(false,name+".mutex");
  try { IsPrimary=mutex.WaitOne(0); } catch(AbandonedMutexException) { IsPrimary=true; }
  if(IsPrimary) {
   owner=MemoryMappedFile.CreateOrOpen(name+".owner",4);
   using(MemoryMappedViewAccessor view=owner.CreateViewAccessor()) { view.Write(0,System.Diagnostics.Process.GetCurrentProcess().Id); }
  }
 }
 public void ActivateExisting() {
  // Let the existing GUI take foreground focus on behalf of this user launch.
  DateTime deadline=DateTime.UtcNow.AddSeconds(3);
  do {
   try {
    using(MemoryMappedFile map=MemoryMappedFile.OpenExisting(name+".owner"))
    using(MemoryMappedViewAccessor view=map.CreateViewAccessor()) {
     int pid=view.ReadInt32(0);
     if(pid>0) { AllowSetForegroundWindow((uint)pid); break; }
    }
   } catch(FileNotFoundException) { }
   Thread.Sleep(50);
  } while(DateTime.UtcNow<deadline);
  activation.Set();
 }
 public bool HasActivation() { return activation.WaitOne(0); }
 public void ShowExisting(Form form) {
  if(form.IsDisposed)return;
  if(form.WindowState==FormWindowState.Minimized)ShowWindow(form.Handle,9);
  form.Show();form.BringToFront();form.Activate();SetForegroundWindow(form.Handle);
 }
 public void Dispose() {
  if(owner!=null)owner.Dispose();
  if(IsPrimary) { mutex.ReleaseMutex();IsPrimary=false; }
  mutex.Dispose();activation.Dispose();
 }
}
