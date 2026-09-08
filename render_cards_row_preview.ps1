Add-Type -AssemblyName System.Drawing

$w = 840
$h = 360
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::FromArgb(7, 9, 14)) # GitHub dark theme background

# Load 3 card preview frames
$c1 = [System.Drawing.Image]::FromFile("e:\Projects\Readme\card_1_preview.png")
$c2 = [System.Drawing.Image]::FromFile("e:\Projects\Readme\card_2_preview.png")
$c3 = [System.Drawing.Image]::FromFile("e:\Projects\Readme\card_3_preview.png")

# Calculate spacing for 840px width: 274 * 3 = 822. Remaining = 18px => 9px padding on sides or 9px between
# In GitHub: <p align="center"> cards have ~4-8px inline-block margin
$x1 = 4
$x2 = $x1 + 274 + 6
$x3 = $x2 + 274 + 6
$y = 10

$g.DrawImage($c1, $x1, $y, 274, 340)
$g.DrawImage($c2, $x2, $y, 274, 340)
$g.DrawImage($c3, $x3, $y, 274, 340)

$bmp.Save("e:\Projects\Readme\cards_row_preview.png", [System.Drawing.Imaging.ImageFormat]::Png)

$c1.Dispose()
$c2.Dispose()
$c3.Dispose()
$g.Dispose()
$bmp.Dispose()

Write-Host "cards_row_preview.png created!"
