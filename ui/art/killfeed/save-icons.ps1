param([string]$Manifest = "generated-manifest.json")
Add-Type -AssemblyName System.Drawing
$entries = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
foreach ($entry in $entries) {
    $src = [System.Drawing.Bitmap]::FromFile($entry.path)
    $width = 1024
    if ($entry.name.StartsWith('kf_')) { $width = 512 }
    $out = New-Object System.Drawing.Bitmap($width,512,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $left=$src.Width; $top=$src.Height; $right=0; $bottom=0
    for ($sy=0; $sy -lt $src.Height; $sy+=3) {
        for ($sx=0; $sx -lt $src.Width; $sx+=3) {
            if ($src.GetPixel($sx,$sy).A -ge 128) {
                $left=[Math]::Min($left,$sx); $right=[Math]::Max($right,$sx)
                $top=[Math]::Min($top,$sy); $bottom=[Math]::Max($bottom,$sy)
            }
        }
    }
    $left=[Math]::Max(0,$left-3); $top=[Math]::Max(0,$top-3)
    $right=[Math]::Min($src.Width-1,$right+3); $bottom=[Math]::Min($src.Height-1,$bottom+3)
    $sw=$right-$left+1; $sh=$bottom-$top+1
    $fill=0.85
    if ($width -eq 512) { $fill=0.78 }
    $scale = [Math]::Min($width*$fill/$sw,512*$fill/$sh)
    $w = [int][Math]::Round($sw * $scale)
    $h = [int][Math]::Round($sh * $scale)
    $dest = New-Object System.Drawing.Rectangle(([int](($width-$w)/2)),([int]((512-$h)/2)),$w,$h)
    $g.DrawImage($src,$dest,$left,$top,$sw,$sh,[System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $path = Join-Path $PWD ($entry.name + '.png')
    $out.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
    $src.Dispose()
    Write-Output "$($entry.name).png ${width}x512"
}
