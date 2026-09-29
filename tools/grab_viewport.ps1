# Studio 뷰포트 영역만 잘라 PNG 로 저장. 좌표는 스크린샷(1456x819) 기준
param([string]$out)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$k = $b.Width / 1456.0
$x = [int](165 * $k); $y = [int](64 * $k); $w = [int](946 * $k); $h = [int](619 * $k)
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.X + $x, $b.Y + $y, 0, 0, (New-Object System.Drawing.Size $w, $h))
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
"$($b.Width)x$($b.Height) -> $out"
