$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class IconHandle { [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr handle); }
'@
$bitmap=New-Object Drawing.Bitmap(128,128)
$graphics=[Drawing.Graphics]::FromImage($bitmap)
$background=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#14354d'))
$mint=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#36d3c4'))
$blue=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#62b8ff'))
$pen=New-Object Drawing.Pen([Drawing.ColorTranslator]::FromHtml('#e6f6ff'),9)
$shape=New-Object Drawing.Drawing2D.GraphicsPath
try{
 $graphics.SmoothingMode='AntiAlias'
 $shape.AddArc(4,4,60,60,180,90);$shape.AddArc(64,4,60,60,270,90)
 $shape.AddArc(64,64,60,60,0,90);$shape.AddArc(4,64,60,60,90,90);$shape.CloseFigure()
 $graphics.FillPath($background,$shape)
 $pen.StartCap='Round';$pen.EndCap='Round';$pen.LineJoin='Round'
 $graphics.DrawLine($pen,36,42,64,70);$graphics.DrawLine($pen,64,70,94,40);$graphics.DrawLine($pen,64,70,64,94)
 $graphics.FillEllipse($mint,24,30,24,24);$graphics.FillEllipse($blue,82,28,24,24)
 $graphics.FillEllipse($mint,52,82,24,24);$graphics.FillEllipse([Drawing.Brushes]::White,54,60,20,20)
 $bitmap.Save((Join-Path $PSScriptRoot 'logo.png'),[Drawing.Imaging.ImageFormat]::Png)
 $small=New-Object Drawing.Bitmap($bitmap,64,64)
 try{
  $handle=$small.GetHicon()
  try{
   $icon=[Drawing.Icon]::FromHandle($handle)
   $stream=[IO.File]::Create((Join-Path $PSScriptRoot 'logo.ico'))
   try{$icon.Save($stream)}finally{$stream.Dispose();$icon.Dispose()}
  }finally{[void][IconHandle]::DestroyIcon($handle)}
 }finally{$small.Dispose()}
}finally{$graphics.Dispose();$bitmap.Dispose();$background.Dispose();$mint.Dispose();$blue.Dispose();$pen.Dispose();$shape.Dispose()}
