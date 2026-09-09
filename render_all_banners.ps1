Add-Type -AssemblyName System.Drawing

$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class FastGifEncoder {
    public static void SaveGif(string outputPath, Bitmap[] frames, int delayMs) {
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

public class UnifiedBannerRenderer {
    public static void RenderBanner(string outputPath, string title, string subtitle, string tag, Color accent, int totalFrames = 24, int delayMs = 60) {
        int w = 840, h = 42;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float progress = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                g.SmoothingMode = SmoothingMode.HighQuality;
                g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;

                // 1. Solid deep background
                using (var brushBg = new SolidBrush(Color.FromArgb(7, 9, 15))) {
                    g.FillRectangle(brushBg, 0, 0, w, h);
                }
                // Subtle dark outer border
                using (var penBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawRectangle(penBorder, 0, 0, w - 1, h - 1);
                }

                using (var fontTitle = new Font("Segoe UI", 11.0f, FontStyle.Bold))
                using (var fontSub = new Font("Consolas", 8.8f, FontStyle.Regular))
                using (var fontTag = new Font("Consolas", 8.5f, FontStyle.Bold)) {

                    // Measure title for dynamic, perfect chamfer badge width
                    var szTitle = g.MeasureString(title, fontTitle);
                    int chamferW = (int)szTitle.Width + 28;
                    int slant = 14;

                    // Angled chamfer polygon
                    var pts = new PointF[] {
                        new PointF(0, 0),
                        new PointF(chamferW, 0),
                        new PointF(chamferW - slant, h),
                        new PointF(0, h)
                    };

                    // Badge fill
                    using (var brushBadge = new SolidBrush(Color.FromArgb(13, 18, 28))) {
                        g.FillPolygon(brushBadge, pts);
                    }

                    // Badge outline
                    using (var penAccent = new Pen(accent, 1.4f)) {
                        g.DrawLine(penAccent, 0, 0, chamferW, 0);
                        g.DrawLine(penAccent, chamferW, 0, chamferW - slant, h);
                        g.DrawLine(penAccent, 0, h - 1, chamferW - slant, h - 1);
                        g.DrawLine(penAccent, 0, 0, 0, h);
                    }

                    // Title Text inside badge
                    float titleY = (h - szTitle.Height) / 2.0f;
                    using (var brushTitle = new SolidBrush(Color.FromArgb(248, 250, 252))) {
                        g.DrawString(title, fontTitle, brushTitle, 16, titleY);
                    }

                    // Subtitle Text - cleanly spaced after the angled chamfer
                    var szSub = g.MeasureString(subtitle, fontSub);
                    float subX = chamferW + 16;
                    float subY = (h - szSub.Height) / 2.0f + 0.5f;
                    using (var brushSub = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString(subtitle, fontSub, brushSub, subX, subY);
                    }

                    // Top Traveling Laser Light Beam
                    float beamX = progress * (w + 140) - 70;
                    using (var beamBrush = new LinearGradientBrush(
                        new RectangleF(beamX - 60, 0, 120, 2),
                        Color.Transparent, Color.Transparent, 0f)) {
                        var cb = new ColorBlend(3);
                        cb.Colors = new Color[] { Color.Transparent, accent, Color.Transparent };
                        cb.Positions = new float[] { 0f, 0.5f, 1f };
                        beamBrush.InterpolationColors = cb;
                        g.FillRectangle(beamBrush, beamX - 60, 0, 120, 2);
                    }

                    // Right Status Tag & Pulsing Indicator Pip
                    var szTag = g.MeasureString(tag, fontTag);
                    float tagX = w - szTag.Width - 18;
                    float tagY = (h - szTag.Height) / 2.0f;
                    float dotX = tagX - 14;
                    float dotY = h / 2.0f - 4;

                    float pulse = 0.65f + 0.35f * (float)Math.Sin(progress * Math.PI * 2);
                    int dotA = (int)(255 * pulse);
                    using (var brushDotGlow = new SolidBrush(Color.FromArgb((int)(dotA * 0.4f), accent.R, accent.G, accent.B)))
                    using (var brushDot = new SolidBrush(Color.FromArgb(dotA, accent.R, accent.G, accent.B))) {
                        g.FillEllipse(brushDotGlow, dotX - 2, dotY - 2, 12, 12);
                        g.FillEllipse(brushDot, dotX, dotY, 8, 8);
                    }

                    using (var brushTag = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                        g.DrawString(tag, fontTag, brushTag, tagX, tagY);
                    }
                }
            }
            frames[f] = bmp;
        }

        FastGifEncoder.SaveGif(outputPath, frames, delayMs);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
        Console.WriteLine("Rendered: " + outputPath);
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing"

$assetsDir = "e:\Projects\Readme\assets"

Write-Host "Rendering all 4 section banners with unified, proper, consistent design..."

# 1. banner_work.gif (SELECTED BUILDS)
$workGif = "$assetsDir\banner_work.gif"
$workV2Gif = "$assetsDir\banner_work_v2.gif"
[UnifiedBannerRenderer]::RenderBanner($workGif, ">> SELECTED BUILDS", "// 3 AUTONOMOUS PRODUCTION SYSTEMS", "[ACTIVE BUILDS]", [System.Drawing.Color]::FromArgb(0, 240, 255))
Copy-Item $workGif $workV2Gif -Force

# 2. banner_telemetry.gif (CORE DOMAINS)
$telemGif = "$assetsDir\banner_telemetry.gif"
$telemV2Gif = "$assetsDir\banner_telemetry_v2.gif"
[UnifiedBannerRenderer]::RenderBanner($telemGif, ">> CORE DOMAINS", "// COMPUTER VISION, AI AGENTS & SYSTEMS SECURITY", "[ACTIVE RESEARCH]", [System.Drawing.Color]::FromArgb(0, 240, 255))
Copy-Item $telemGif $telemV2Gif -Force

# 3. banner_stack.gif (TECHNICAL ARSENAL)
$stackGif = "$assetsDir\banner_stack.gif"
$stackV2Gif = "$assetsDir\banner_stack_v2.gif"
[UnifiedBannerRenderer]::RenderBanner($stackGif, ">> TECHNICAL ARSENAL", "// VERIFIED TOOLING & ARCHITECTURAL STACK", "[VERIFIED]", [System.Drawing.Color]::FromArgb(168, 85, 247))
Copy-Item $stackGif $stackV2Gif -Force

# 4. banner_contact.gif (CONTROL UPLINK)
$contactGif = "$assetsDir\banner_contact.gif"
$contactV2Gif = "$assetsDir\banner_contact_v2.gif"
[UnifiedBannerRenderer]::RenderBanner($contactGif, ">> CONTROL UPLINK", "// SECURE COMMS & TRANSMISSION CHANNELS", "[ACTIVE]", [System.Drawing.Color]::FromArgb(0, 240, 255))
Copy-Item $contactGif $contactV2Gif -Force

Write-Host "All 4 banners generated successfully!"
Get-ChildItem "$assetsDir\banner_*.gif" | Select-Object Name, Length
