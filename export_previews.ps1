Add-Type -AssemblyName System.Drawing

$files = @("card_slam.gif", "card_vision.gif", "card_mpc.gif", "telemetry.gif", "contrib.gif", "stack.gif")
foreach ($f in $files) {
    $src = "e:\Projects\Readme\assets\$f"
    $dst = "e:\Projects\Readme\assets\" + $f.Replace(".gif", "_frame.png")
    $img = [System.Drawing.Image]::FromFile($src)
    $img.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
    $img.Dispose()
    Write-Host "Exported $dst"
}
