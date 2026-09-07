$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class GitSafeRenderer {
    // 48 frames * 166ms = 8.0s loop
    public const int TOTAL_FRAMES = 48;
    public const int DELAY_MS = 166;
    public const int TARGET_W = 800;
    public const int TARGET_H = 334;

    public static void RenderGitSafe(string outputPath) {
        Console.WriteLine("Rendering GitHub-Safe GIF (under 5MB)...");
        var frames = new Bitmap[TOTAL_FRAMES];

        for (int f = 0; f < TOTAL_FRAMES; f++) {
            float t = (float)f / TOTAL_FRAMES * 8.0f;
            var bmp = new Bitmap(TARGET_W, TARGET_H, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                NeuralLabRendererV2.RenderSingleFrame(g, TARGET_W, TARGET_H, t);
            }
            frames[f] = bmp;
        }

        SimpleGif.CreateAnimatedGif(outputPath, frames, DELAY_MS);
        for (int f = 0; f < TOTAL_FRAMES; f++) frames[f].Dispose();

        var fi = new FileInfo(outputPath);
        Console.WriteLine("Saved: " + outputPath + " | Size: " + fi.Length + " bytes (" + (fi.Length / 1024.0 / 1024.0).ToString("F2") + " MB)");
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing"

$outFile = "e:\Projects\Readme\capedcrusader77-neural-lab.gif"
[GitSafeRenderer]::RenderGitSafe($outFile)

$item = Get-Item $outFile
Write-Output "RESULT: $($item.Length) bytes ($([math]::Round($item.Length / 1MB, 2)) MB)"
if ($item.Length -lt 5000000) {
    Write-Output "SUCCESS: Safely under GitHub Camo 5MB limit!"
} else {
    Write-Output "WARNING: Still over 5MB, needs more reduction."
}
