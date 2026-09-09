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
    public static void RenderLuxuryBanner(Graphics g, int w, int h, string title, string subtitle, string tag, Color accent, float progress) {
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;

        // 1. Deep atmospheric gradient background
        using (var bgBrush = new LinearGradientBrush(
            new RectangleF(0, 0, w, h),
            Color.FromArgb(10, 14, 22), Color.FromArgb(6, 8, 14), 0f)) {
            g.FillRectangle(bgBrush, 0, 0, w, h);
        }

        // Faint ambient glow behind the left badge
        using (var glowPather = new GraphicsPath()) {
            glowPather.AddEllipse(-30, -15, 260, h + 30);
            using (var pgb = new PathGradientBrush(glowPather)) {
                pgb.CenterColor = Color.FromArgb(30, accent.R, accent.G, accent.B);
                pgb.SurroundColors = new Color[] { Color.Transparent };
                g.FillPath(pgb, glowPather);
            }
        }

        // Outer sleek container border
        using (var penBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
            g.DrawRectangle(penBorder, 0, 0, w - 1, h - 1);
        }

        // Corner framing micro-accents on the right
        using (var penFrame = new Pen(Color.FromArgb(90, accent.R, accent.G, accent.B), 1.2f)) {
            g.DrawLine(penFrame, w - 1, 0, w - 1, 6);
            g.DrawLine(penFrame, w - 7, 0, w - 1, 0);
            g.DrawLine(penFrame, w - 1, h - 7, w - 1, h - 1);
            g.DrawLine(penFrame, w - 7, h - 1, w - 1, h - 1);
        }

        using (var fontTitle = new Font("Segoe UI", 11.0f, FontStyle.Bold))
        using (var fontSub = new Font("Consolas", 8.8f, FontStyle.Regular))
        using (var fontTag = new Font("Consolas", 8.2f, FontStyle.Bold)) {

            // Measure title for dynamic chamfer badge width
            var szTitle = g.MeasureString(title, fontTitle);
            int chamferW = (int)szTitle.Width + 34;
            int slant = 14;

            // Angled chamfer polygon
            var pts = new PointF[] {
                new PointF(0, 0),
                new PointF(chamferW, 0),
                new PointF(chamferW - slant, h),
                new PointF(0, h)
            };

            // Badge fill with dark gradient
            using (var badgeBrush = new LinearGradientBrush(
                new RectangleF(0, 0, chamferW, h),
                Color.FromArgb(20, 26, 40), Color.FromArgb(12, 16, 26), 0f)) {
                g.FillPolygon(badgeBrush, pts);
            }

            // Cyber diagonal hash texture inside the badge
            using (var penHash = new Pen(Color.FromArgb(16, accent.R, accent.G, accent.B), 1f)) {
                for (int hx = -h; hx < chamferW; hx += 10) {
                    float x1 = Math.Max(0, hx);
                    float y1 = hx < 0 ? -hx : 0;
                    float x2 = hx + h;
                    float y2 = h;
                    if (x2 < chamferW - slant) {
                        g.DrawLine(penHash, x1, y1, x2, y2);
                    }
                }
            }

            // Left anchor block (3px solid accent)
            using (var brushAnchor = new SolidBrush(accent)) {
                g.FillRectangle(brushAnchor, 0, 0, 3, h);
            }

            // Badge outline
            using (var penAccent = new Pen(accent, 1.4f)) {
                g.DrawLine(penAccent, 0, 0, chamferW, 0);
                g.DrawLine(penAccent, 0, h - 1, chamferW - slant, h - 1);
            }

            // Neon glow bloom along the slant edge
            using (var penSlantGlow = new Pen(Color.FromArgb(80, accent.R, accent.G, accent.B), 3.5f)) {
                g.DrawLine(penSlantGlow, chamferW, 0, chamferW - slant, h);
            }
            using (var penSlant = new Pen(Color.FromArgb(255, accent.R, accent.G, accent.B), 1.6f)) {
                g.DrawLine(penSlant, chamferW, 0, chamferW - slant, h);
            }

            // Secondary parallel micro-accent tick along the slant
            using (var penSlantTick = new Pen(Color.FromArgb(140, accent.R, accent.G, accent.B), 1f)) {
                g.DrawLine(penSlantTick, chamferW + 4, 0, chamferW + 4 - (slant * 0.45f), h * 0.45f);
            }

            // Title Text: Separate ">>" in accent color with glowing aura, followed by title in bright white
            float titleY = (h - szTitle.Height) / 2.0f;
            string prefix = ">> ";
            string mainTitle = title.StartsWith(prefix) ? title.Substring(prefix.Length) : title;
            var szPrefix = g.MeasureString(prefix, fontTitle);

            float startX = 16f;
            // Draw prefix with accent glow
            using (var brushPrefixGlow = new SolidBrush(Color.FromArgb(140, accent.R, accent.G, accent.B)))
            using (var brushPrefix = new SolidBrush(accent)) {
                g.DrawString(prefix, fontTitle, brushPrefixGlow, startX - 0.5f, titleY);
                g.DrawString(prefix, fontTitle, brushPrefix, startX, titleY);
            }

            // Draw main title text in crisp white with subtle aura
            float textX = startX + szPrefix.Width - 4;
            using (var brushTitleGlow = new SolidBrush(Color.FromArgb(60, accent.R, accent.G, accent.B)))
            using (var brushTitle = new SolidBrush(Color.FromArgb(250, 252, 255))) {
                g.DrawString(mainTitle, fontTitle, brushTitleGlow, textX + 0.5f, titleY + 0.5f);
                g.DrawString(mainTitle, fontTitle, brushTitle, textX, titleY);
            }

            // Subtitle Text: cleanly separated with colored "//"
            var szSub = g.MeasureString(subtitle, fontSub);
            float subX = chamferW + 18;
            float subY = (h - szSub.Height) / 2.0f + 0.5f;

            string cleanSub = subtitle;
            if (cleanSub.StartsWith("// ")) {
                cleanSub = cleanSub.Substring(3);
            } else if (cleanSub.StartsWith("//")) {
                cleanSub = cleanSub.Substring(2).TrimStart();
            }

            using (var brushSlashGlow = new SolidBrush(Color.FromArgb(120, accent.R, accent.G, accent.B)))
            using (var brushSlash = new SolidBrush(accent))
            using (var brushSub = new SolidBrush(Color.FromArgb(170, 185, 205))) {
                g.DrawString("//", fontSub, brushSlashGlow, subX - 0.5f, subY);
                g.DrawString("//", fontSub, brushSlash, subX, subY);
                float slashW = g.MeasureString("//", fontSub).Width;
                g.DrawString(cleanSub, fontSub, brushSub, subX + slashW, subY);
            }

            // Top Traveling Laser Light Beam with radiant flare
            float beamX = progress * (w + 160) - 80;
            using (var beamBrush = new LinearGradientBrush(
                new RectangleF(beamX - 75, 0, 150, 2),
                Color.Transparent, Color.Transparent, 0f)) {
                var cb = new ColorBlend(3);
                cb.Colors = new Color[] { Color.Transparent, accent, Color.Transparent };
                cb.Positions = new float[] { 0f, 0.5f, 1f };
                beamBrush.InterpolationColors = cb;
                g.FillRectangle(beamBrush, beamX - 75, 0, 150, 2);
            }
            // Radiant white spark flare at the beam center
            using (var brushSpark = new SolidBrush(Color.FromArgb(240, 255, 255, 255))) {
                g.FillRectangle(brushSpark, beamX - 4, 0, 8, 2);
            }

            // Right Status Capsule Pill Badge
            var szTag = g.MeasureString(tag, fontTag);
            float pillW = szTag.Width + 28;
            float pillH = 22;
            float pillX = w - pillW - 16;
            float pillY = (h - pillH) / 2.0f;

            // Cut-corner chamfered cyber capsule path
            float cCut = 4f;
            var capsulePath = new GraphicsPath();
            capsulePath.AddLine(pillX + cCut, pillY, pillX + pillW - cCut, pillY);
            capsulePath.AddLine(pillX + pillW, pillY + cCut, pillX + pillW, pillY + pillH - cCut);
            capsulePath.AddLine(pillX + pillW - cCut, pillY + pillH, pillX + cCut, pillY + pillH);
            capsulePath.AddLine(pillX, pillY + pillH - cCut, pillX, pillY + cCut);
            capsulePath.CloseFigure();

            // Capsule background & subtle accent border
            using (var brushPill = new SolidBrush(Color.FromArgb(16, 22, 34)))
            using (var penPill = new Pen(Color.FromArgb(80, accent.R, accent.G, accent.B), 1.1f)) {
                g.FillPath(brushPill, capsulePath);
                g.DrawPath(penPill, capsulePath);
            }

            // Pulsing status dot with animated radar ping ring
            float pulse = (float)(0.65f + 0.35f * Math.Sin(progress * Math.PI * 2));
            int dotA = (int)(255 * pulse);
            float dotCenterX = pillX + 11.5f;
            float dotCenterY = pillY + (pillH / 2.0f);

            // Expanding radar ripple ring
            float ripplePhase = (progress * 2) % 1.0f;
            float rippleR = 4f + ripplePhase * 6.5f;
            int rippleA = (int)(110 * (1f - ripplePhase));
            if (rippleA > 0) {
                using (var penRipple = new Pen(Color.FromArgb(rippleA, accent.R, accent.G, accent.B), 1f)) {
                    g.DrawEllipse(penRipple, dotCenterX - rippleR, dotCenterY - rippleR, rippleR * 2, rippleR * 2);
                }
            }

            // Core dot & halo
            using (var brushDotGlow = new SolidBrush(Color.FromArgb((int)(dotA * 0.45f), accent.R, accent.G, accent.B)))
            using (var brushDot = new SolidBrush(Color.FromArgb(dotA, accent.R, accent.G, accent.B))) {
                g.FillEllipse(brushDotGlow, dotCenterX - 5.5f, dotCenterY - 5.5f, 11, 11);
                g.FillEllipse(brushDot, dotCenterX - 3.5f, dotCenterY - 3.5f, 7, 7);
            }

            // Status tag text
            using (var brushTag = new SolidBrush(Color.FromArgb(235, 242, 250))) {
                g.DrawString(tag, fontTag, brushTag, pillX + 21, pillY + (pillH - szTag.Height) / 2.0f + 0.5f);
            }
        }
    }

    public static void RenderBanner(string outputPath, string title, string subtitle, string tag, Color accent, int totalFrames = 24, int delayMs = 60) {
        int w = 840, h = 42;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float progress = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                RenderLuxuryBanner(g, w, h, title, subtitle, tag, accent, progress);
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

Write-Host "Rendering all 4 section banners with state-of-the-art cyber luxury design..."

# 1. banner_work_v3.gif (SELECTED BUILDS)
$workGif = "$assetsDir\banner_work.gif"
$workV2Gif = "$assetsDir\banner_work_v2.gif"
$workV3Gif = "$assetsDir\banner_work_v3.gif"
[UnifiedBannerRenderer]::RenderBanner($workV3Gif, ">> SELECTED BUILDS", "// 3 AUTONOMOUS PRODUCTION SYSTEMS", "ACTIVE BUILDS", [System.Drawing.Color]::FromArgb(0, 240, 255))
Copy-Item $workV3Gif $workGif -Force
Copy-Item $workV3Gif $workV2Gif -Force

# 2. banner_telemetry_v3.gif (CORE DOMAINS)
$telemGif = "$assetsDir\banner_telemetry.gif"
$telemV2Gif = "$assetsDir\banner_telemetry_v2.gif"
$telemV3Gif = "$assetsDir\banner_telemetry_v3.gif"
[UnifiedBannerRenderer]::RenderBanner($telemV3Gif, ">> CORE DOMAINS", "// COMPUTER VISION, AI AGENTS & SYSTEMS SECURITY", "ACTIVE RESEARCH", [System.Drawing.Color]::FromArgb(0, 240, 255))
Copy-Item $telemV3Gif $telemGif -Force
Copy-Item $telemV3Gif $telemV2Gif -Force

# 3. banner_contrib_v3.gif (LIVE TELEMETRY / CONTRIBUTIONS)
$contribBannerGif = "$assetsDir\banner_contrib.gif"
$contribBannerV2Gif = "$assetsDir\banner_contrib_v2.gif"
$contribBannerV3Gif = "$assetsDir\banner_contrib_v3.gif"
[UnifiedBannerRenderer]::RenderBanner($contribBannerV3Gif, ">> LIVE TELEMETRY", "// 264 ANNUAL COMMITS & REPOSITORY ACTIVITY MATRIX", "264 COMMITS", [System.Drawing.Color]::FromArgb(0, 240, 255))
Copy-Item $contribBannerV3Gif $contribBannerGif -Force
Copy-Item $contribBannerV3Gif $contribBannerV2Gif -Force

# 4. banner_stack_v3.gif (TECHNICAL ARSENAL)
$stackGif = "$assetsDir\banner_stack.gif"
$stackV2Gif = "$assetsDir\banner_stack_v2.gif"
$stackV3Gif = "$assetsDir\banner_stack_v3.gif"
[UnifiedBannerRenderer]::RenderBanner($stackV3Gif, ">> TECHNICAL ARSENAL", "// VERIFIED TOOLING & ARCHITECTURAL STACK", "VERIFIED", [System.Drawing.Color]::FromArgb(168, 85, 247))
Copy-Item $stackV3Gif $stackGif -Force
Copy-Item $stackV3Gif $stackV2Gif -Force

# 5. banner_contact_v3.gif (CONTROL UPLINK)
$contactGif = "$assetsDir\banner_contact.gif"
$contactV2Gif = "$assetsDir\banner_contact_v2.gif"
$contactV3Gif = "$assetsDir\banner_contact_v3.gif"
[UnifiedBannerRenderer]::RenderBanner($contactV3Gif, ">> CONTROL UPLINK", "// SECURE COMMS & TRANSMISSION CHANNELS", "ONLINE", [System.Drawing.Color]::FromArgb(0, 240, 255))
Copy-Item $contactV3Gif $contactGif -Force
Copy-Item $contactV3Gif $contactV2Gif -Force

Write-Host "All 5 luxury section banners rendered successfully!"
Get-ChildItem "$assetsDir\banner_*_v3.gif" | Select-Object Name, Length
