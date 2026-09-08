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

    public static float SmoothStep(float min, float max, float value) {
        float x = Math.Max(0.0f, Math.Min(1.0f, (value - min) / (max - min)));
        return x * x * (3.0f - 2.0f * x);
    }

    public static void DrawCornerBrackets(Graphics g, float x, float y, float w, float h, Color color, float len = 10f) {
        using (var p = new Pen(color, 1.4f)) {
            g.DrawLines(p, new PointF[] { new PointF(x, y + len), new PointF(x, y), new PointF(x + len, y) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - len, y), new PointF(x + w, y), new PointF(x + w, y + len) });
            g.DrawLines(p, new PointF[] { new PointF(x, y + h - len), new PointF(x, y + h), new PointF(x + len, y + h) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - len, y + h), new PointF(x + w, y + h), new PointF(x + w, y + h - len) });
        }
    }

    public static void RenderSingleFrame(Graphics g, int W, int H, float t) {
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;

        float sx = (float)W / 960.0f;
        float sy = (float)H / 400.0f;

        // 1. PURE SOLID PITCH BLACK CANVAS (#000000)
        using (var brushBg = new SolidBrush(Color.FromArgb(0, 0, 0))) {
            g.FillRectangle(brushBg, 0, 0, W, H);
        }

        // 2. ULTRA-DELICATE CYBER GRID GUIDE
        float gridAlpha = t < 1.0f ? SmoothStep(0.0f, 0.9f, t) : (t > 7.6f ? SmoothStep(8.0f, 7.6f, t) * 0.6f + 0.4f : 1.0f);
        int gridCol = (int)(16 * gridAlpha);
        using (var penGrid = new Pen(Color.FromArgb(gridCol, 0, 240, 255), 1)) {
            int stepX = (int)(32 * sx);
            int stepY = (int)(32 * sy);
            for (int x = 0; x <= W; x += stepX) g.DrawLine(penGrid, x, 0, x, H);
            for (int y = 0; y <= H; y += stepY) g.DrawLine(penGrid, 0, y, W, y);
        }

        // Micro ticks along borders
        using (var fontMicro = new Font("Consolas", 7.0f * sx, FontStyle.Regular))
        using (var brushTick = new SolidBrush(Color.FromArgb((int)(40 * gridAlpha), 0, 240, 255))) {
            for (int x = (int)(32 * sx); x < W - (int)(32 * sx); x += (int)(64 * sx)) {
                g.FillRectangle(brushTick, x, 3, 1, 4);
                g.FillRectangle(brushTick, x, H - 7, 1, 4);
                g.DrawString("+" + ((int)(x / sx)).ToString("D4"), fontMicro, brushTick, x - 10, 10);
            }
        }

        // Ambient cyber sparks
        var rand = new Random(77);
        for (int i = 0; i < 28; i++) {
            float px0 = (float)(rand.NextDouble() * 960.0);
            float py0 = (float)(rand.NextDouble() * 400.0);
            float spx = (float)((rand.NextDouble() - 0.5) * 14.0);
            float spy = (float)((rand.NextDouble() - 0.5) * 10.0);
            float px = ((px0 + spx * t + 960.0f) % 960.0f) * sx;
            float py = ((py0 + spy * t + 400.0f) % 400.0f) * sy;
            float pAlpha = (float)(0.25f + 0.35f * Math.Sin(t * 3.0f + i));
            int alphaVal = (int)(255 * pAlpha * gridAlpha);
            alphaVal = Math.Max(0, Math.Min(255, alphaVal));
            Color pColor = (i % 2 == 0) ? Color.FromArgb(alphaVal, 0, 240, 255) : Color.FromArgb(alphaVal, 139, 92, 246);
            using (var brushP = new SolidBrush(pColor)) {
                g.FillEllipse(brushP, px, py, 2.0f * sx, 2.0f * sy);
            }
        }

        // 3. PHOTONIC LASER SWEEP
        if (t >= 0.6f && t <= 2.0f) {
            float scanNorm = (t - 0.6f) / 1.4f;
            float beamX = scanNorm * (W + 200) - 100;

            using (var brushBeam = new LinearGradientBrush(
                new PointF(beamX - 100, 0), new PointF(beamX + 20, 0),
                Color.Transparent, Color.FromArgb(100, 0, 240, 255))) {
                g.FillRectangle(brushBeam, beamX - 100, 0, 120, H);
            }
            using (var penLaser = new Pen(Color.FromArgb(240, 255, 255, 255), 1.8f)) {
                g.DrawLine(penLaser, beamX + 20, 0, beamX + 20, H);
            }
        }

        // =========================================================================
        // 4. RIGHT SIDE: ULTRA-COOL CYBER AI OPERATIVE WITH HOLOGRAPHIC HUD
        // =========================================================================
        float opAlpha = SmoothStep(1.0f, 2.2f, t);
        if (opAlpha > 0.01f && operativeImg != null) {
            int oa = (int)(255 * opAlpha);

            float vpX = 460f * sx;
            float vpY = 16f * sy;
            float vpW = 475f * sx;
            float vpH = 300f * sy;

            // Crop operative from 1024x1024
            int srcW = operativeImg.Width;
            int srcH = operativeImg.Height;
            int cropX = (int)(srcW * 0.08f);
            int cropY = (int)(srcH * 0.02f);
            int cropW = (int)(srcW * 0.84f);
            int cropH = (int)(cropW * (vpH / vpW));

            Rectangle srcRect = new Rectangle(cropX, cropY, cropW, cropH);
            RectangleF dstRect = new RectangleF(vpX, vpY, vpW, vpH);

            // Draw operative photo
            g.DrawImage(operativeImg, dstRect, srcRect, GraphicsUnit.Pixel);

            // Soft seamless gradient fades directly into pure pitch black void
            // Left edge fade into the text side
            using (var lFade = new LinearGradientBrush(new RectangleF(vpX - 1, vpY, 70 * sx, vpH), Color.FromArgb(0, 0, 0), Color.Transparent, 0f)) {
                g.FillRectangle(lFade, vpX - 1, vpY, 70 * sx, vpH);
            }
            // Right edge fade
            using (var rFade = new LinearGradientBrush(new RectangleF(vpX + vpW - 35 * sx, vpY, 36 * sx, vpH), Color.Transparent, Color.FromArgb(0, 0, 0), 0f)) {
                g.FillRectangle(rFade, vpX + vpW - 35 * sx, vpY, 36 * sx, vpH);
            }
            // Bottom edge fade into footer
            using (var bFade = new LinearGradientBrush(new RectangleF(vpX, vpY + vpH - 55 * sy, vpW, 56 * sy), Color.Transparent, Color.FromArgb(0, 0, 0), 90f)) {
                g.FillRectangle(bFade, vpX, vpY + vpH - 55 * sy, vpW, 56 * sy);
            }
            // Top edge fade
            using (var tFade = new LinearGradientBrush(new RectangleF(vpX, vpY - 1, vpW, 25 * sy), Color.FromArgb(0, 0, 0), Color.Transparent, 90f)) {
                g.FillRectangle(tFade, vpX, vpY - 1, vpW, 25 * sy);
            }

            // HUD Frame Corner Reticles
            DrawCornerBrackets(g, vpX + 30 * sx, vpY + 10 * sy, vpW - 40 * sx, vpH - 25 * sy, Color.FromArgb(oa, 0, 240, 255), 14f);

            // HUD Top Tag
            using (var fontTag = new Font("Consolas", 8.2f * sx, FontStyle.Bold)) {
                using (var hBg = new SolidBrush(Color.FromArgb((int)(210 * opAlpha), 0, 0, 0)))
                using (var hBorder = new Pen(Color.FromArgb((int)(120 * opAlpha), 0, 240, 255), 1f))
                using (var hText = new SolidBrush(Color.FromArgb(oa, 0, 240, 255))) {
                    g.FillRectangle(hBg, vpX + 50 * sx, vpY + 4 * sy, 220 * sx, 18 * sy);
                    g.DrawRectangle(hBorder, vpX + 50 * sx, vpY + 4 * sy, 220 * sx, 18 * sy);
                    g.DrawString("// ENTITY: GOKUL_A [AI_OPERATIVE]", fontTag, hText, vpX + 56 * sx, vpY + 6 * sy);
                }
            }

            // Biometric Visor Target Lock
            float visorX = vpX + 175 * sx;
            float visorY = vpY + 85 * sy;
            float visorW = 145 * sx;
            float visorH = 125 * sy;

            float pulse = 0.5f + 0.5f * (float)Math.Sin(t * Math.PI * 2.0);
            int retAlpha = (int)(200 * opAlpha * (0.7f + 0.3f * pulse));
            DrawCornerBrackets(g, visorX, visorY, visorW, visorH, Color.FromArgb(retAlpha, 0, 240, 255), 10f);

            // Biometric lock badge
            using (var lockFont = new Font("Consolas", 7.0f * sx, FontStyle.Bold))
            using (var lockBrush = new SolidBrush(Color.FromArgb(oa, 52, 211, 153))) {
                g.DrawString("LOCK_99.8% // NEURAL_LINK: ACTIVE", lockFont, lockBrush, visorX + 4, visorY - 11 * sy);
            }

            // Animated Vertical Holographic Laser Scanline
            float scanNorm = (t * 0.42f) % 1.0f;
            float hudScanY = visorY + scanNorm * visorH;
            using (var hudScanBrush = new LinearGradientBrush(
                new RectangleF(visorX, hudScanY - 6, visorW, 12),
                Color.Transparent, Color.Transparent, 0f)) {
                var cb = new ColorBlend(3);
                cb.Colors = new Color[] { Color.Transparent, Color.FromArgb((int)(110 * opAlpha), 0, 240, 255), Color.Transparent };
                cb.Positions = new float[] { 0f, 0.5f, 1f };
                hudScanBrush.InterpolationColors = cb;
                g.FillRectangle(hudScanBrush, visorX, hudScanY - 6, visorW, 12);
            }
            using (var scanLinePen = new Pen(Color.FromArgb((int)(230 * opAlpha), 0, 240, 255), 1.2f)) {
                g.DrawLine(scanLinePen, visorX, hudScanY, visorX + visorW, hudScanY);
            }

            // Real-Time Equalizer Waveform Bars across the bottom of Operative
            float eqX = vpX + 45 * sx;
            float eqY = vpY + vpH - 42 * sy;
            float eqW = vpW - 60 * sx;
            float eqH = 24 * sy;

            int numBars = 36;
            float barW = (eqW / numBars) - 2.5f * sx;
            for (int b = 0; b < numBars; b++) {
                float bx = eqX + b * (barW + 2.5f * sx);
                float normB = (float)b / numBars;

                float barMag = (float)(0.35f + 0.45f * Math.Sin(t * 3.5f + normB * 8.0f) + 0.20f * Math.Cos(t * 2.0f + normB * 14.0f));
                barMag = Math.Max(0.12f, Math.Min(1.0f, barMag));
                float currH = barMag * (eqH - 4f * sy);
                float by = eqY + eqH - currH;

                int rCol = (int)(normB * 120);
                int gCol = (int)(240 - normB * 70);
                Color bColor = Color.FromArgb(oa, rCol, gCol, 255);

                using (var barBrush = new SolidBrush(bColor)) {
                    g.FillRectangle(barBrush, bx, by, barW, currH);
                }
            }

            // Real-time telemetry ticker
            using (var statFont = new Font("Consolas", 7.5f * sx, FontStyle.Bold))
            using (var statBrush = new SolidBrush(Color.FromArgb(oa, 0, 240, 255))) {
                g.DrawString("CUDA_THROUGHPUT: 120 FPS // LATENCY: 1.8ms // PRECISION: FP16", statFont, statBrush, eqX, vpY + vpH - 15f * sy);
            }
        }

        // =========================================================================
        // 5. LEFT HERO TYPOGRAPHY: GOKUL A (AAA Cyberpunk Styling)
        // =========================================================================
        float textAlpha = SmoothStep(1.4f, 2.6f, t);
        if (textAlpha > 0.01f) {
            int ta = (int)(255 * textAlpha);

            using (var fontTitle = new Font("Segoe UI", 40 * sx, FontStyle.Bold))
            using (var fontSub = new Font("Consolas", 10.2f * sx, FontStyle.Bold))
            using (var fontTag = new Font("Consolas", 8.2f * sx, FontStyle.Bold))
            using (var fontPipe = new Font("Consolas", 9.0f * sx, FontStyle.Bold)) {

                // Top Tag Pill
                float pillX = 52 * sx;
                float pillY = 46 * sy;
                using (var brushTag = new SolidBrush(Color.FromArgb(ta, 139, 92, 246)))
                using (var brushDot = new SolidBrush(Color.FromArgb(ta, 0, 240, 255))) {
                    g.FillEllipse(brushDot, pillX, pillY + 3 * sy, 6 * sx, 6 * sy);
                    g.DrawString("[ GOKUL A // AUTONOMOUS NEURAL CORE ]", fontTag, brushTag, pillX + 12 * sx, pillY);
                }

                // PRIMARY TITLE: GOKUL A (Layered Neon Bloom)
                // Layer 1: Electric Violet Bloom
                using (var brushGlow = new SolidBrush(Color.FromArgb((int)(90 * textAlpha), 139, 92, 246))) {
                    g.DrawString("GOKUL A", fontTitle, brushGlow, 53 * sx, 78 * sy);
                    g.DrawString("GOKUL A", fontTitle, brushGlow, 49 * sx, 82 * sy);
                }
                // Layer 2: Neon Cyan Rim
                using (var brushCyanGlow = new SolidBrush(Color.FromArgb((int)(110 * textAlpha), 0, 240, 255))) {
                    g.DrawString("GOKUL A", fontTitle, brushCyanGlow, 51 * sx, 77 * sy);
                }
                // Layer 3: Ultra-Crisp White Foreground
                using (var brushMain = new SolidBrush(Color.FromArgb(ta, 255, 255, 255))) {
                    g.DrawString("GOKUL A", fontTitle, brushMain, 50 * sx, 76 * sy);
                }

                // Cyber Accent Line Under Name
                using (var lineBrush = new LinearGradientBrush(
                    new RectangleF(50 * sx, 135 * sy, 260 * sx, 2),
                    Color.FromArgb(ta, 0, 240, 255), Color.Transparent, 0f)) {
                    g.FillRectangle(lineBrush, 50 * sx, 135 * sy, 260 * sx, 2);
                }

                // Subtitle
                using (var brushSub = new SolidBrush(Color.FromArgb(ta, 0, 240, 255))) {
                    g.DrawString("AI & SYSTEMS RESEARCH // COMPUTER VISION // AGENTS", fontSub, brushSub, 52 * sx, 146 * sy);
                }

                // Pipeline: Perception -> Reasoning -> Execution
                var stages = new[] {
                    new { Name = "PERCEPTION", Phase = 2.4f },
                    new { Name = "REASONING", Phase = 3.6f },
                    new { Name = "EXECUTION", Phase = 4.8f }
                };

                float curX = 52 * sx;
                float curY = 176 * sy;
                for (int i = 0; i < stages.Length; i++) {
                    var st = stages[i];
                    bool active = (t >= st.Phase && t <= 7.8f);
                    Color col = active ? Color.FromArgb(0, 240, 255) : Color.FromArgb(148, 163, 184);

                    using (var brushText = new SolidBrush(col)) {
                        g.DrawString(st.Name, fontPipe, brushText, curX, curY);
                    }
                    curX += g.MeasureString(st.Name, fontPipe).Width + 4 * sx;

                    if (i < stages.Length - 1) {
                        Color arrCol = (t >= st.Phase + 0.4f) ? Color.FromArgb(139, 92, 246) : Color.FromArgb(70, 148, 163, 184);
                        using (var brushArr = new SolidBrush(arrCol)) {
                            g.DrawString("->", fontPipe, brushArr, curX, curY);
                        }
                        curX += 20 * sx;
                    }
                }

                // Technical Badges
                string[] badgeTexts = new string[] {
                    "IIT MADRAS",
                    "EDGE INFERENCE",
                    "AI AGENTS",
                    "TENSOR CORE"
                };
                Color[] badgeColors = new Color[] {
                    Color.FromArgb(0, 240, 255),
                    Color.FromArgb(139, 92, 246),
                    Color.FromArgb(56, 189, 248),
                    Color.FromArgb(16, 185, 129)
                };

                float bX = 52 * sx;
                float bY = 228 * sy;
                for (int i = 0; i < badgeTexts.Length; i++) {
                    string bText = badgeTexts[i];
                    Color bCol = badgeColors[i];
                    var size = g.MeasureString(bText, fontTag);

                    using (var brushPill = new SolidBrush(Color.FromArgb(220, 0, 0, 0)))
                    using (var penPill = new Pen(Color.FromArgb(ta, bCol), 1.0f))
                    using (var brushPip = new SolidBrush(Color.FromArgb(ta, bCol)))
                    using (var brushPillText = new SolidBrush(Color.FromArgb(ta, 248, 250, 252))) {
                        g.FillRectangle(brushPill, bX, bY, size.Width + 18, 20 * sy);
                        g.DrawRectangle(penPill, bX, bY, size.Width + 18, 20 * sy);
                        g.FillEllipse(brushPip, bX + 5, bY + 7 * sy, 4 * sx, 4 * sy);
                        g.DrawString(bText, fontTag, brushPillText, bX + 13, bY + 3 * sy);
                    }
                    bX += size.Width + 18 * sx;
                }
            }
        }

        // =========================================================================
        // 6. TELEMETRY FOOTER & STATUS
        // =========================================================================
        using (var brushBar = new SolidBrush(Color.FromArgb(240, 0, 0, 0)))
        using (var penBar = new Pen(Color.FromArgb(70, 28, 38, 54), 1)) {
            g.FillRectangle(brushBar, 0, H - 32, W, 32);
            g.DrawLine(penBar, 0, H - 32, W, H - 32);
        }

        bool isOnline = (t >= 2.0f);
        Color statColor = isOnline ? Color.FromArgb(0, 240, 255) : Color.FromArgb(148, 163, 184);

        using (var brushDot = new SolidBrush(statColor)) {
            g.FillEllipse(brushDot, 52 * sx, H - 21, 6 * sx, 6 * sy);
        }

        using (var fontHud = new Font("Consolas", 8.5f * sx, FontStyle.Regular))
        using (var brushStatus = new SolidBrush(statColor))
        using (var brushTelem = new SolidBrush(Color.FromArgb(148, 163, 184))) {
            g.DrawString(isOnline ? "SYSTEM ONLINE" : "INITIALIZING CORE", fontHud, brushStatus, 64 * sx, H - 20);
            g.DrawString("|  INFERENCE: 1.8ms  |  BANDWIDTH: 100Gb/s  |  CUDA CORES: 16,384  |  PRO ACCOUNT", fontHud, brushTelem, 185 * sx, H - 20);
        }
    }

    public static void RenderGif(string outputPath, string operativePath, int width, int height, int totalFrames, int delayMs) {
        Console.WriteLine("Loading Operative Image: " + operativePath);
        LoadOperative(operativePath);

        Console.WriteLine("Rendering Gokul A Cinematic Neural Lab GIF (" + width + "x" + height + ", " + totalFrames + " frames)...");
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames * 8.0f;
            var bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                RenderSingleFrame(g, width, height, t);
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

    public static void SavePreviewFrame(string outputPath, string operativePath, int width, int height, float t) {
        LoadOperative(operativePath);
        using (var bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb)) {
            using (var g = Graphics.FromImage(bmp)) {
                RenderSingleFrame(g, width, height, t);
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
$previewPng = "e:\Projects\Readme\assets\hero_preview.png"
$operativePath = "e:\Projects\Readme\assets\cyber_operative.jpg"

# 36 frames * 222ms = 8.0s loop, 760x316 px (Ultra-clean, Camo-Safe under 5MB)
[NeuralLabRendererV2]::RenderGif($optGif, $operativePath, 760, 316, 36, 222)

# Save sample frame for PNG inspection
[NeuralLabRendererV2]::SavePreviewFrame($previewPng, $operativePath, 760, 316, 4.0)

# Copy to assets/hero.gif
Copy-Item $optGif $heroGif -Force
Write-Host "Copied $optGif to $heroGif"

$heroItem = Get-Item $heroGif
Write-Output "=== COMPLETE HERO EXPORT REPORT ==="
Write-Output "GIF Size: $([math]::Round($heroItem.Length / 1MB, 2)) MB ($($heroItem.Length) bytes)"
if ($heroItem.Length -lt 5000000) {
    Write-Output "VERIFIED: Under 5MB Camo limit! ($([math]::Round($heroItem.Length / 1MB, 2)) MB < 5.00 MB)"
} else {
    Write-Output "WARNING: Over 5MB limit!"
}
