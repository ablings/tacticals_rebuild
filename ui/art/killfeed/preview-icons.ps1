Add-Type -AssemblyName System.Drawing
$files = @(Get-ChildItem -Filter '*.png' | Where-Object { $_.Name -match '^(kf_|w_)' } | Sort-Object Name)
$rows = [int][Math]::Ceiling($files.Count / 4)
$sheet = New-Object System.Drawing.Bitmap(1000,($rows * 150))
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::FromArgb(30,34,42))
$font = New-Object System.Drawing.Font('Arial',10)
for ($i = 0; $i -lt $files.Count; $i++) {
    $img = [System.Drawing.Image]::FromFile($files[$i].FullName)
    $x = ($i % 4) * 250
    $y = [int][Math]::Floor($i / 4) * 150
    $scale = [Math]::Min(220 / $img.Width,90 / $img.Height)
    $w = [int]($img.Width*$scale)
    $h = [int]($img.Height*$scale)
    $g.DrawImage($img,($x+[int]((250-$w)/2)),($y+5),$w,$h)
    $g.DrawString($files[$i].Name,$font,[System.Drawing.Brushes]::White,($x+12),($y+100))
    $g.DrawImage($img,($x+12),($y+122),([int](20*$img.Width/$img.Height)),20)
    $img.Dispose()
}
$g.Dispose()
$font.Dispose()
$sheet.Save((Join-Path $PWD 'icon-preview.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
