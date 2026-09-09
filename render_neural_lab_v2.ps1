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

        float sx = (float)W / 960.0f;
        float sy = (float)H / 400.0f;
        float theta = (float)(u * Math.PI * 2.0);

        // 1. SOLID DEEP CYBER BACKGROUND
        using (var brushBg = new SolidBrush(Color.FromArgb(6, 8, 14))) {
            g.FillRectangle(brushBg, 0, 0, W, H);
        }

        // 2. DELICATE CYBER GRID
        using (var penGrid = new Pen(Color.FromArgb(12, 0, 240, 255), 1)) {
            int stepX = (int)(32 * sx);
            int stepY = (int)(32 * sy);
            for (int x = 0; x <= W; x += stepX) g.DrawLine(penGrid, x, 0, x, H);
            for (int y = 0; y <= H; y += stepY) g.DrawLine(penGrid, 0, y, W, y);
        }

        // Subtle decorative border marks
        using (var brushTick = new SolidBrush(Color.FromArgb(35, 0, 240, 255))) {
            for (int x = (int)(64 * sx); x < W - (int)(64 * sx); x += (int)(64 * sx)) {
                g.FillRectangle(brushTick, x, 0, 1, 3);
            }
        }

        // Ambient cyber sparks
        var rand = new Random(77);
        for (int i = 0; i < 16; i++) {
            float px0 = 480.0f + (float)(rand.NextDouble() * 460.0);
            float py0 = (float)(rand.NextDouble() * 320.0);
            float freq = (i % 2 == 0) ? 1.0f : 2.0f;
            float px = (px0 + (float)Math.Sin(theta * freq + i * 1.4f) * 10.0f) * sx;
            float py = (py0 + (float)Math.Cos(theta * freq + i * 0.9f) * 8.0f) * sy;
            float pAlpha = (float)(0.25f + 0.25f * Math.Sin(theta * 2.0f + i));
            int alphaVal = (int)(255 * Math.Max(0.1f, Math.Min(0.6f, pAlpha)));
            Color pColor = (i % 2 == 0) ? Color.FromArgb(alphaVal, 0, 240, 255) : Color.FromArgb(alphaVal, 139, 92, 246);
            using (var brushP = new SolidBrush(pColor)) {
                g.FillEllipse(brushP, px, py, 2.0f * sx, 2.0f * sy);
            }
        }

        // =========================================================================
        // 3. RIGHT SIDE: CYBER AI OPERATIVE WITH HOLOGRAPHIC HUD
        // =========================================================================
        if (operativeImg != null) {
            float vpX = 460f * sx;
            float vpY = 16f * sy;
            float vpW = 475f * sx;
            float vpH = 300f * sy;

            int srcW = operativeImg.Width;
            int srcH = operativeImg.Height;
            int cropX = (int)(srcW * 0.08f);
            int cropY = (int)(srcH * 0.02f);
            int cropW = (int)(srcW * 0.84f);
            int cropH = (int)(cropW * (vpH / vpW));

            Rectangle srcRect = new Rectangle(cropX, cropY, cropW, cropH);
            RectangleF dstRect = new RectangleF(vpX, vpY, vpW, vpH);

            g.DrawImage(operativeImg, dstRect, srcRect, GraphicsUnit.Pixel);

            // Soft seamless gradients
            using (var lFade = new LinearGradientBrush(new RectangleF(vpX - 1, vpY, 70 * sx, vpH), Color.FromArgb(6, 8, 14), Color.Transparent, 0f)) {
                g.FillRectangle(lFade, vpX - 1, vpY, 70 * sx, vpH);
            }
            using (var rFade = new LinearGradientBrush(new RectangleF(vpX + vpW - 35 * sx, vpY, 36 * sx, vpH), Color.Transparent, Color.FromArgb(6, 8, 14), 0f)) {
                g.FillRectangle(rFade, vpX + vpW - 35 * sx, vpY, 36 * sx, vpH);
            }
            using (var bFade = new LinearGradientBrush(new RectangleF(vpX, vpY + vpH - 55 * sy, vpW, 56 * sy), Color.Transparent, Color.FromArgb(6, 8, 14), 90f)) {
                g.FillRectangle(bFade, vpX, vpY + vpH - 55 * sy, vpW, 56 * sy);
            }
            using (var tFade = new LinearGradientBrush(new RectangleF(vpX, vpY - 1, vpW, 25 * sy), Color.FromArgb(6, 8, 14), Color.Transparent, 90f)) {
                g.FillRectangle(tFade, vpX, vpY - 1, vpW, 25 * sy);
            }

            // Clean Frame Corner Reticles
            DrawCornerBrackets(g, vpX + 30 * sx, vpY + 10 * sy, vpW - 40 * sx, vpH - 25 * sy, Color.FromArgb(200, 0, 240, 255), 14f);

            // Top Label
            using (var fontTag = new Font("Consolas", 8.2f * sx, FontStyle.Bold))
            using (var hBg = new SolidBrush(Color.FromArgb(220, 8, 12, 20)))
            using (var hBorder = new Pen(Color.FromArgb(140, 0, 240, 255), 1f))
            using (var hText = new SolidBrush(Color.FromArgb(240, 0, 240, 255))) {
                g.FillRectangle(hBg, vpX + 50 * sx, vpY + 4 * sy, 210 * sx, 18 * sy);
                g.DrawRectangle(hBorder, vpX + 50 * sx, vpY + 4 * sy, 210 * sx, 18 * sy);
                g.DrawString("// DEVELOPER WORKSPACE // FOCUS", fontTag, hText, vpX + 56 * sx, vpY + 6 * sy);
            }

            // Equalizer Waveform Bars (Lo-Fi beats aesthetic)
            float eqX = vpX + 45 * sx;
            float eqY = vpY + vpH - 46 * sy;
            float eqW = vpW - 60 * sx;
            float eqH = 20 * sy;

            int numBars = 36;
            float barW = (eqW / numBars) - 2.5f * sx;
            for (int b = 0; b < numBars; b++) {
                float bx = eqX + b * (barW + 2.5f * sx);
                float normB = (float)b / numBars;

                float barMag = (float)(0.38f 
                    + 0.35f * Math.Sin(theta * 2.0f + normB * 6.283f) 
                    + 0.20f * Math.Cos(theta * 3.0f + normB * 12.566f)
                    + 0.12f * Math.Sin(theta * 4.0f - normB * 9.424f));
                barMag = Math.Max(0.12f, Math.Min(1.0f, barMag));
                float currH = barMag * (eqH - 4f * sy);
                float by = eqY + eqH - currH;

                int rCol = (int)(normB * 110);
                int gCol = (int)(240 - normB * 60);
                Color bColor = Color.FromArgb(255, rCol, gCol, 255);

                using (var barBrush = new SolidBrush(bColor)) {
                    g.FillRectangle(barBrush, bx, by, barW, currH);
                }
                using (var capBrush = new SolidBrush(Color.FromArgb(255, 255, 255, 255))) {
                    g.FillRectangle(capBrush, bx, by, barW, Math.Max(1.0f, 1.5f * sy));
                }
            }

            // Caption under equalizer
            using (var statFont = new Font("Consolas", 7.2f * sx, FontStyle.Bold))
            using (var statBrush = new SolidBrush(Color.FromArgb(210, 0, 240, 255))) {
                g.DrawString("LO-FI CODING SESSION  //  BUILDING IN PUBLIC", statFont, statBrush, eqX, eqY + eqH + 5 * sy);
            }
        }

        // =========================================================================
        // 4. LEFT HERO TYPOGRAPHY - CLEAN, PROMINENT & BALANCED
        // =========================================================================
        using (var fontTitle = new Font("Segoe UI", 48 * sx, FontStyle.Bold))
        using (var fontTag = new Font("Consolas", 8.4f * sx, FontStyle.Bold)) {

            // Top Affiliation Tag
            float pillX = 50 * sx;
            float pillY = 80 * sy;
            string topTag = "DATA SCIENCE & AI  //  IIT MADRAS";
            var topTagSize = g.MeasureString(topTag, fontTag);
            float pillW = topTagSize.Width + 26 * sx;
            float pillH = 22 * sy;

            using (var brushPillBg = new SolidBrush(Color.FromArgb(180, 10, 16, 28)))
            using (var penPillBorder = new Pen(Color.FromArgb(140, 0, 240, 255), 1.0f))
            using (var brushDot = new SolidBrush(Color.FromArgb(255, 0, 240, 255)))
            using (var brushTag = new SolidBrush(Color.FromArgb(235, 190, 220, 255))) {
                g.FillRectangle(brushPillBg, pillX, pillY, pillW, pillH);
                g.DrawRectangle(penPillBorder, pillX, pillY, pillW, pillH);
                g.FillEllipse(brushDot, pillX + 8 * sx, pillY + 8.5f * sy, 5 * sx, 5 * sy);
                g.DrawString(topTag, fontTag, brushTag, pillX + 18 * sx, pillY + 4.5f * sy);
            }

            // PRIMARY TITLE: GOKUL A (Hero focal point)
            float titleX = 50 * sx;
            float titleY = 118 * sy;
            using (var brushCyanGlow = new SolidBrush(Color.FromArgb(90, 0, 240, 255))) {
                g.DrawString("GOKUL A", fontTitle, brushCyanGlow, titleX + 1.5f * sx, titleY + 1.5f * sy);
            }
            using (var brushMain = new SolidBrush(Color.FromArgb(255, 255, 255, 255))) {
                g.DrawString("GOKUL A", fontTitle, brushMain, titleX, titleY);
            }

            // Sleek Gradient Accent Line
            float lineY = 194 * sy;
            using (var lineBrush = new LinearGradientBrush(
                new RectangleF(50 * sx, lineY, 280 * sx, 2.5f),
                Color.FromArgb(240, 0, 240, 255), Color.Transparent, 0f)) {
                g.FillRectangle(lineBrush, 50 * sx, lineY, 280 * sx, 2.5f);
            }
        }

        // =========================================================================
        // 5. STATUS BAR FOOTER
        // =========================================================================
        using (var brushBar = new SolidBrush(Color.FromArgb(245, 5, 7, 12)))
        using (var penBar = new Pen(Color.FromArgb(90, 30, 41, 59), 1)) {
            g.FillRectangle(brushBar, 0, H - 32, W, 32);
            g.DrawLine(penBar, 0, H - 32, W, H - 32);
        }

        // Live status pip
        using (var brushDotGlow = new SolidBrush(Color.FromArgb(90, 52, 211, 153)))
        using (var brushDot = new SolidBrush(Color.FromArgb(255, 52, 211, 153))) {
            g.FillEllipse(brushDotGlow, 50 * sx, H - 22, 10 * sx, 10 * sy);
            g.FillEllipse(brushDot, 52 * sx, H - 20, 6 * sx, 6 * sy);
        }

        using (var fontHud = new Font("Consolas", 8.2f * sx, FontStyle.Regular))
        using (var fontHudBold = new Font("Consolas", 8.2f * sx, FontStyle.Bold))
        using (var brushStatus = new SolidBrush(Color.FromArgb(255, 52, 211, 153)))
        using (var brushMuted = new SolidBrush(Color.FromArgb(160, 148, 163, 184))) {
            g.DrawString("ONLINE", fontHudBold, brushStatus, 64 * sx, H - 20);

            string telemString = "  //   IIT MADRAS (DATA SCIENCE)   //   CHENNAI, INDIA   //   GITHUB: CAPEDCRUSADER77";
            g.DrawString(telemString, fontHud, brushMuted, 115 * sx, H - 20);
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
$previewPng = "e:\Projects\Readme\assets\hero_preview.png"
$operativePath = "e:\Projects\Readme\assets\cyber_operative.jpg"

# 36 frames * 50ms delay = 20 FPS (Silky smooth, continuous alive HUD loop, 840x350 px, strictly under 4.5MB)
[NeuralLabRendererV2]::RenderGif($optGif, $operativePath, 840, 350, 36, 50)

# Save sample frame for PNG inspection
[NeuralLabRendererV2]::SavePreviewFrame($previewPng, $operativePath, 840, 350, 0.25)

# Copy to assets/hero.gif, hero_core.gif, hero_main.gif, and fresh hero_clean.gif
Copy-Item $optGif $heroGif -Force
Copy-Item $optGif $heroCoreGif -Force
Copy-Item $optGif $heroMainGif -Force
Copy-Item $optGif $heroCleanGif -Force
Write-Host "Copied $optGif to $heroGif, $heroCoreGif, $heroMainGif, and $heroCleanGif"

$heroItem = Get-Item $heroCleanGif
Write-Output "=== COMPLETE HERO EXPORT REPORT ==="
Write-Output "GIF Size: $([math]::Round($heroItem.Length / 1MB, 2)) MB ($($heroItem.Length) bytes)"
if ($heroItem.Length -lt 5000000) {
    Write-Output "VERIFIED: Under 5MB Camo limit! ($([math]::Round($heroItem.Length / 1MB, 2)) MB < 5.00 MB)"
} else {
    Write-Output "WARNING: Over 5MB limit!"
}
