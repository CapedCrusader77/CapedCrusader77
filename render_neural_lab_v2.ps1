$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class SimpleGif {
    public static void CreateAnimatedGif(string outputPath, Bitmap[] frames, int delayMs) {
        using (var fs = new FileStream(outputPath, FileMode.Create, FileAccess.Write)) {
            int delay100th = delayMs / 10;
            byte delayLo = (byte)(delay100th & 0xFF);
            byte delayHi = (byte)((delay100th >> 8) & 0xFF);

            for (int i = 0; i < frames.Length; i++) {
                using (var ms = new MemoryStream()) {
                    frames[i].Save(ms, ImageFormat.Gif);
                    byte[] bytes = ms.ToArray();

                    if (i == 0) {
                        fs.Write(bytes, 0, 13);
                        int gctSize = 0;
                        if ((bytes[10] & 0x80) != 0) {
                            int count = 1 << ((bytes[10] & 7) + 1);
                            gctSize = 3 * count;
                            fs.Write(bytes, 13, gctSize);
                        }

                        // Netscape 2.0 Loop Extension
                        byte[] netscape = new byte[] {
                            0x21, 0xFF, 0x0B,
                            (byte)'N', (byte)'E', (byte)'T', (byte)'S', (byte)'C', (byte)'A', (byte)'P', (byte)'E', (byte)'2', (byte)'.', (byte)'0',
                            0x03, 0x01, 0x00, 0x00, 0x00
                        };
                        fs.Write(netscape, 0, netscape.Length);

                        byte[] gce = new byte[] { 0x21, 0xF9, 0x04, 0x00, delayLo, delayHi, 0x00, 0x00 };
                        fs.Write(gce, 0, gce.Length);

                        int imgStart = 13 + gctSize;
                        if (bytes[imgStart] == 0x21 && bytes[imgStart + 1] == 0xF9) imgStart += 8;
                        fs.Write(bytes, imgStart, bytes.Length - imgStart - 1);
                    } else {
                        byte[] gce = new byte[] { 0x21, 0xF9, 0x04, 0x00, delayLo, delayHi, 0x00, 0x00 };
                        fs.Write(gce, 0, gce.Length);

                        int imgStart = 13;
                        if ((bytes[10] & 0x80) != 0) {
                            int count = 1 << ((bytes[10] & 7) + 1);
                            imgStart += 3 * count;
                        }
                        if (bytes[imgStart] == 0x21 && bytes[imgStart + 1] == 0xF9) imgStart += 8;

                        if (bytes[imgStart] == 0x2C) {
                            if ((bytes[10] & 0x80) != 0) {
                                byte[] imgDesc = new byte[10];
                                Array.Copy(bytes, imgStart, imgDesc, 0, 10);
                                imgDesc[9] = (byte)(0x80 | (bytes[10] & 0x07));
                                fs.Write(imgDesc, 0, 10);

                                int count = 1 << ((bytes[10] & 7) + 1);
                                fs.Write(bytes, 13, 3 * count);

                                fs.Write(bytes, imgStart + 10, bytes.Length - (imgStart + 10) - 1);
                            } else {
                                fs.Write(bytes, imgStart, bytes.Length - imgStart - 1);
                            }
                        }
                    }
                }
            }
            fs.WriteByte(0x3B);
        }
    }
}

public class NeuralLabRendererV2 {
    private static Bitmap operativeImg = null;

    public static void LoadOperative(string path) {
        if (File.Exists(path)) {
            using (var src = Image.FromFile(path)) {
                operativeImg = new Bitmap(src);
            }
        }
    }

    public static void DrawCornerBrackets(Graphics g, float x, float y, float w, float h, Color color, float len = 10f) {
        using (var p = new Pen(color, 1.4f)) {
            g.DrawLines(p, new PointF[] { new PointF(x, y + len), new PointF(x, y), new PointF(x + len, y) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - len, y), new PointF(x + w, y), new PointF(x + w, y + len) });
            g.DrawLines(p, new PointF[] { new PointF(x, y + h - len), new PointF(x, y + h), new PointF(x + len, y + h) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - len, y + h), new PointF(x + w, y + h), new PointF(x + w, y + h - len) });
        }
    }

    // u is normalized loop progress from 0.0 to 1.0 (seamless continuous loop)
    public static void RenderSingleFrame(Graphics g, int W, int H, float u) {
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;

        float sx = (float)W / 840.0f;
        float sy = (float)H / 350.0f;
        float theta = (float)(u * Math.PI * 2.0);

        // 1. DEEP RICH OBSIDIAN BACKGROUND (No grid!)
        using (var brushBg = new SolidBrush(Color.FromArgb(7, 9, 15))) {
            g.FillRectangle(brushBg, 0, 0, W, H);
        }

        // 2. LUXURY ATMOSPHERIC AURORA NEBULA GLOWS (Replaces harsh grids with smooth, modern lighting)
        // Cyan bloom behind typography
        using (var pather = new GraphicsPath()) {
            pather.AddEllipse(-80 * sx, 30 * sy, 460 * sx, 320 * sy);
            using (var pgb = new PathGradientBrush(pather)) {
                pgb.CenterColor = Color.FromArgb(32, 0, 210, 255);
                pgb.SurroundColors = new Color[] { Color.FromArgb(0, 7, 9, 15) };
                g.FillPath(pgb, pather);
            }
        }

        // Deep royal violet/indigo bloom in center
        using (var pather2 = new GraphicsPath()) {
            pather2.AddEllipse(260 * sx, 80 * sy, 440 * sx, 280 * sy);
            using (var pgb2 = new PathGradientBrush(pather2)) {
                pgb2.CenterColor = Color.FromArgb(26, 139, 92, 246);
                pgb2.SurroundColors = new Color[] { Color.FromArgb(0, 7, 9, 15) };
                g.FillPath(pgb2, pather2);
            }
        }

        // Deep electric blue glow under workspace
        using (var pather3 = new GraphicsPath()) {
            pather3.AddEllipse(520 * sx, 160 * sy, 340 * sx, 220 * sy);
            using (var pgb3 = new PathGradientBrush(pather3)) {
                pgb3.CenterColor = Color.FromArgb(20, 14, 165, 233);
                pgb3.SurroundColors = new Color[] { Color.FromArgb(0, 7, 9, 15) };
                g.FillPath(pgb3, pather3);
            }
        }

        // 3. ELEGANT AMBIENT FLOATING STARDUST (Harmonic seamless loop)
        var rand = new Random(77);
        for (int i = 0; i < 36; i++) {
            float seedX = (float)(rand.NextDouble() * 840.0);
            float seedY = (float)(rand.NextDouble() * 350.0);
            float speed = 0.6f + (float)(rand.NextDouble() * 1.4);
            float pRadius = 0.8f + (float)(rand.NextDouble() * 1.8);

            // Harmonic drift
            float px = (seedX + (float)Math.Sin(theta * speed + i * 1.2f) * 14.0f) * sx;
            float py = (seedY + (float)Math.Cos(theta * speed + i * 0.8f) * 10.0f) * sy;

            // Breathing pulse
            float pulse = (float)(0.30f + 0.40f * Math.Sin(theta * 2.0f + i * 1.7f));
            int pAlpha = (int)(255 * Math.Max(0.10f, Math.Min(0.80f, pulse)));

            Color pColor = (i % 3 == 0) 
                ? Color.FromArgb(pAlpha, 0, 240, 255) 
                : (i % 3 == 1) 
                    ? Color.FromArgb(pAlpha, 168, 85, 247) 
                    : Color.FromArgb((int)(pAlpha * 0.85), 224, 242, 254);

            // Soft halo for larger particles
            if (pRadius > 1.8f) {
                using (var halo = new SolidBrush(Color.FromArgb((int)(pAlpha * 0.25f), pColor.R, pColor.G, pColor.B))) {
                    g.FillEllipse(halo, px - pRadius * sx, py - pRadius * sy, pRadius * 4 * sx, pRadius * 4 * sy);
                }
            }

            using (var brushP = new SolidBrush(pColor)) {
                g.FillEllipse(brushP, px, py, pRadius * 2 * sx, pRadius * 2 * sy);
            }
        }

        // 4. RIGHT SIDE: LO-FI DEVELOPER WORKSPACE (Seamless edge blending)
        if (operativeImg != null) {
            float vpX = 405f * sx;
            float vpY = 20f * sy;
            float vpW = 415f * sx;
            float vpH = 308f * sy;

            int srcW = operativeImg.Width;
            int srcH = operativeImg.Height;
            int cropX = (int)(srcW * 0.08f);
            int cropY = (int)(srcH * 0.02f);
            int cropW = (int)(srcW * 0.84f);
            int cropH = (int)(cropW * (vpH / vpW));

            Rectangle srcRect = new Rectangle(cropX, cropY, cropW, cropH);
            RectangleF dstRect = new RectangleF(vpX, vpY, vpW, vpH);

            g.DrawImage(operativeImg, dstRect, srcRect, GraphicsUnit.Pixel);

            // Soft seamless gradients blending image completely into background
            using (var lFade = new LinearGradientBrush(new RectangleF(vpX - 1, vpY - 1, 95 * sx, vpH + 2), Color.FromArgb(7, 9, 15), Color.Transparent, 0f)) {
                g.FillRectangle(lFade, vpX - 1, vpY - 1, 95 * sx, vpH + 2);
            }
            using (var rFade = new LinearGradientBrush(new RectangleF(vpX + vpW - 65 * sx, vpY - 1, 66 * sx, vpH + 2), Color.Transparent, Color.FromArgb(7, 9, 15), 0f)) {
                g.FillRectangle(rFade, vpX + vpW - 65 * sx, vpY - 1, 66 * sx, vpH + 2);
            }
            using (var bFade = new LinearGradientBrush(new RectangleF(vpX - 1, vpY + vpH - 55 * sy, vpW + 2, 56 * sy), Color.Transparent, Color.FromArgb(7, 9, 15), 90f)) {
                g.FillRectangle(bFade, vpX - 1, vpY + vpH - 55 * sy, vpW + 2, 56 * sy);
            }
            using (var tFade = new LinearGradientBrush(new RectangleF(vpX - 1, vpY - 1, vpW + 2, 45 * sy), Color.FromArgb(7, 9, 15), Color.Transparent, 90f)) {
                g.FillRectangle(tFade, vpX - 1, vpY - 1, vpW + 2, 45 * sy);
            }

            // Equalizer Waveform Bars (Lo-Fi beats aesthetic)
            float eqX = vpX + 40 * sx;
            float eqY = vpY + vpH - 42 * sy;
            float eqW = vpW - 60 * sx;
            float eqH = 22 * sy;

            int numBars = 32;
            float barW = (eqW / numBars) - 2.5f * sx;
            for (int b = 0; b < numBars; b++) {
                float bx = eqX + b * (barW + 2.5f * sx);
                float normB = (float)b / numBars;

                float barMag = (float)(0.36f 
                    + 0.35f * Math.Sin(theta * 2.0f + normB * 6.283f) 
                    + 0.20f * Math.Cos(theta * 3.0f + normB * 12.566f)
                    + 0.12f * Math.Sin(theta * 4.0f - normB * 9.424f));
                barMag = Math.Max(0.12f, Math.Min(1.0f, barMag));
                float currH = barMag * (eqH - 4f * sy);
                float by = eqY + eqH - currH;

                int rCol = (int)(normB * 120);
                int gCol = (int)(240 - normB * 50);
                Color bColor = Color.FromArgb(240, rCol, gCol, 255);

                using (var barBrush = new SolidBrush(bColor)) {
                    g.FillRectangle(barBrush, bx, by, barW, currH);
                }
                using (var capBrush = new SolidBrush(Color.FromArgb(255, 255, 255, 255))) {
                    g.FillRectangle(capBrush, bx, by, barW, Math.Max(1.0f, 1.5f * sy));
                }
            }
        }

        // 5. LEFT HERO TYPOGRAPHY: PURE, ICONIC GOKUL A
        using (var fontTitle = new Font("Segoe UI", 58 * sx, FontStyle.Bold)) {
            float titleX = 65 * sx;
            float titleY = 125 * sy;

            // Ambient cyan glow bloom
            using (var brushOuter = new SolidBrush(Color.FromArgb(40, 0, 240, 255))) {
                g.DrawString("GOKUL A", fontTitle, brushOuter, titleX - 2.5f * sx, titleY);
                g.DrawString("GOKUL A", fontTitle, brushOuter, titleX + 2.5f * sx, titleY);
                g.DrawString("GOKUL A", fontTitle, brushOuter, titleX, titleY - 2.5f * sy);
                g.DrawString("GOKUL A", fontTitle, brushOuter, titleX, titleY + 2.5f * sy);
            }
            using (var brushGlow = new SolidBrush(Color.FromArgb(130, 0, 240, 255))) {
                g.DrawString("GOKUL A", fontTitle, brushGlow, titleX + 1.8f * sx, titleY + 1.8f * sy);
            }
            // Crisp, brilliant white foreground
            using (var brushMain = new SolidBrush(Color.FromArgb(255, 255, 255, 255))) {
                g.DrawString("GOKUL A", fontTitle, brushMain, titleX, titleY);
            }

            // Sleek Gradient Accent Underline
            float lineY = titleY + 86 * sy;
            float lineW = 290 * sx;
            using (var lineBrush = new LinearGradientBrush(
                new RectangleF(titleX, lineY, lineW, 3f),
                Color.FromArgb(255, 0, 240, 255), Color.Transparent, 0f)) {
                g.FillRectangle(lineBrush, titleX, lineY, lineW, 3f);
            }

            // Pulsing accent orb at start of line
            float orbPulse = (float)(0.7f + 0.3f * Math.Sin(theta * 2.0f));
            int orbAlpha = (int)(255 * orbPulse);
            using (var brushOrbGlow = new SolidBrush(Color.FromArgb((int)(orbAlpha * 0.45f), 0, 240, 255)))
            using (var brushOrb = new SolidBrush(Color.FromArgb(orbAlpha, 255, 255, 255))) {
                g.FillEllipse(brushOrbGlow, titleX - 4 * sx, lineY - 3f * sy, 9 * sx, 9 * sy);
                g.FillEllipse(brushOrb, titleX - 2 * sx, lineY - 1.2f * sy, 5.5f * sx, 5.5f * sy);
            }
        }
    }

    public static void RenderGif(string outputPath, string operativePath, int width, int height, int totalFrames, int delayMs) {
        Console.WriteLine("Loading Operative Image: " + operativePath);
        LoadOperative(operativePath);

        Console.WriteLine("Rendering Gokul A Neural Lab GIF (" + width + "x" + height + ", " + totalFrames + " frames, " + delayMs + "ms delay)...");
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float u = (float)f / totalFrames; // normalized loop progress [0, 1)
            var bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                RenderSingleFrame(g, width, height, u);
            }
            frames[f] = bmp;
            if (f % 10 == 0) Console.WriteLine("Progress: " + f + " / " + totalFrames);
        }

        Console.WriteLine("Encoding Animated GIF...");
        SimpleGif.CreateAnimatedGif(outputPath, frames, delayMs);
        for (int f = 0; f < totalFrames; f++) frames[f].Dispose();

        var fi = new FileInfo(outputPath);
        Console.WriteLine("Done! Saved: " + outputPath + " (" + (fi.Length / 1024.0 / 1024.0).ToString("F2") + " MB)");
    }

    public static void SavePreviewFrame(string outputPath, string operativePath, int width, int height, float u) {
        LoadOperative(operativePath);
        using (var bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
            using (var g = Graphics.FromImage(bmp)) {
                RenderSingleFrame(g, width, height, u);
            }
            bmp.Save(outputPath, ImageFormat.Png);
        }
        Console.WriteLine("Saved preview frame to: " + outputPath);
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing"

$optGif = "e:\Projects\Readme\capedcrusader77-neural-lab.gif"
$heroGif = "e:\Projects\Readme\assets\hero.gif"
$heroCoreGif = "e:\Projects\Readme\assets\hero_core.gif"
$heroMainGif = "e:\Projects\Readme\assets\hero_main.gif"
$heroCleanGif = "e:\Projects\Readme\assets\hero_clean.gif"
$heroAuroraGif = "e:\Projects\Readme\assets\hero_aurora.gif"
$previewPng = "e:\Projects\Readme\assets\hero_preview.png"
$operativePath = "e:\Projects\Readme\assets\cyber_operative.jpg"

# 36 frames * 50ms delay = 20 FPS (Silky smooth, continuous alive HUD loop, 840x350 px, strictly under 4.5MB)
[NeuralLabRendererV2]::RenderGif($optGif, $operativePath, 840, 350, 36, 50)

# Save sample frame for PNG inspection
[NeuralLabRendererV2]::SavePreviewFrame($previewPng, $operativePath, 840, 350, 0.25)

# Copy to assets/hero.gif, hero_core.gif, hero_main.gif, hero_clean.gif, and hero_aurora.gif
Copy-Item $optGif $heroGif -Force
Copy-Item $optGif $heroCoreGif -Force
Copy-Item $optGif $heroMainGif -Force
Copy-Item $optGif $heroCleanGif -Force
Copy-Item $optGif $heroAuroraGif -Force
Write-Host "Copied $optGif to assets"

$heroItem = Get-Item $heroAuroraGif
Write-Output "=== COMPLETE HERO EXPORT REPORT ==="
Write-Output "GIF Size: $([math]::Round($heroItem.Length / 1MB, 2)) MB ($($heroItem.Length) bytes)"
if ($heroItem.Length -lt 5000000) {
    Write-Output "VERIFIED: Under 5MB Camo limit! ($([math]::Round($heroItem.Length / 1MB, 2)) MB < 5.00 MB)"
} else {
    Write-Output "WARNING: Over 5MB limit!"
}
