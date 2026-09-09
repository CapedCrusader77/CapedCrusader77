$ErrorActionPreference = "Stop"
$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class TelemetryCardsSuite {
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

    public static void SetHighQuality(Graphics g) {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
    }

    public static void DrawCornerBrackets(Graphics g, float x, float y, float w, float h, Color color, float len) {
        using (var p = new Pen(color, 1.4f)) {
            g.DrawLines(p, new PointF[] { new PointF(x, y + len), new PointF(x, y), new PointF(x + len, y) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - len, y), new PointF(x + w, y), new PointF(x + w, y + len) });
            g.DrawLines(p, new PointF[] { new PointF(x, y + h - len), new PointF(x, y + h), new PointF(x + len, y + h) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - len, y + h), new PointF(x + w, y + h), new PointF(x + w, y + h - len) });
        }
    }

    public static Bitmap[] GenerateCardFrames(
        string bgImagePath,
        int cardIndex,
        string tagCategory,
        string statusText,
        Color statusColor,
        string title,
        string subtitle,
        string description,
        string[] tags,
        Color accent,
        float cropRatio,
        int totalFrames = 30
    ) {
        int w = 274, h = 340;
        var frames = new Bitmap[totalFrames];
        Image bgImg = File.Exists(bgImagePath) ? Image.FromFile(bgImagePath) : null;

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // 1. SOLID DEEP CYBER OBSIDIAN BASE
                using (var b = new SolidBrush(Color.FromArgb(4, 7, 12))) {
                    g.FillRectangle(b, 0, 0, w, h);
                }

                // 2. PROJECT BACKGROUND IMAGE (Top showcase)
                int targetArtH = 192;
                if (bgImg != null) {
                    int srcW = bgImg.Width;
                    int srcH = (int)(srcW * ((float)targetArtH / w));

                    int srcY = Math.Max(0, (int)((bgImg.Height - srcH) * cropRatio));
                    if (srcY + srcH > bgImg.Height) srcH = bgImg.Height - srcY;

                    Rectangle srcRect = new Rectangle(0, srcY, srcW, srcH);
                    Rectangle dstRect = new Rectangle(2, 2, w - 4, targetArtH);
                    g.DrawImage(bgImg, dstRect, srcRect, GraphicsUnit.Pixel);

                    // Scrim gradient overlay: seamless transition into obsidian black
                    using (var scrim = new LinearGradientBrush(
                        new Rectangle(0, 0, w, targetArtH + 6),
                        Color.Transparent,
                        Color.FromArgb(255, 4, 7, 12),
                        90f)) {
                        var cb = new ColorBlend(4);
                        cb.Colors = new Color[] {
                            Color.FromArgb(25, 4, 7, 12),
                            Color.FromArgb(60, 4, 7, 12),
                            Color.FromArgb(215, 4, 7, 12),
                            Color.FromArgb(255, 4, 7, 12)
                        };
                        cb.Positions = new float[] { 0f, 0.38f, 0.76f, 1f };
                        scrim.InterpolationColors = cb;
                        g.FillRectangle(scrim, 2, 2, w - 4, targetArtH + 6);
                    }
                }

                // Subtle Holographic Scan Beam over Artwork (sweeps downward)
                float scanY = 16 + ((t + (cardIndex * 0.28f)) % 1f) * (targetArtH - 32);
                using (var pScan = new Pen(Color.FromArgb(45, accent), 1f)) {
                    g.DrawLine(pScan, 2, scanY, w - 4, scanY);
                }
                using (var bScan = new LinearGradientBrush(
                    new RectangleF(2, scanY - 6, w - 4, 12),
                    Color.Transparent, Color.Transparent, 0f)) {
                    var cbS = new ColorBlend(3);
                    cbS.Colors = new Color[] { Color.Transparent, Color.FromArgb(32, accent), Color.Transparent };
                    cbS.Positions = new float[] { 0f, 0.5f, 1f };
                    bScan.InterpolationColors = cbS;
                    g.FillRectangle(bScan, 2, scanY - 6, w - 4, 12);
                }

                // 3. CARD OUTER BORDER & CORNER ACCENTS
                using (var pBorder = new Pen(Color.FromArgb(65, accent.R, accent.G, accent.B), 1f)) {
                    g.DrawRectangle(pBorder, 2, 2, w - 5, h - 5);
                }
                DrawCornerBrackets(g, 2, 2, w - 4, h - 4, accent, 10f);

                // Top Accent Stripe + Continuous Laser Beam Pulse (1 full pass per cycle)
                using (var bTop = new SolidBrush(Color.FromArgb(175, accent))) {
                    g.FillRectangle(bTop, 2, 2, w - 4, 2);
                }
                float beamX = t * (w + 60) - 30;
                using (var brushBeam = new LinearGradientBrush(
                    new RectangleF(beamX - 25, 2, 50, 2), Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, Color.White, Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    brushBeam.InterpolationColors = cb;
                    g.FillRectangle(brushBeam, beamX - 25, 2, 50, 2);
                }

                // 4. TOP BAR: INDEX TAG & LIVE STATUS BEACON
                int tagX = 12, tagY = 12;
                using (var bTagBg = new SolidBrush(Color.FromArgb(220, 3, 6, 12)))
                using (var pTagBorder = new Pen(Color.FromArgb(95, accent), 1f))
                using (var fTag = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var bTagText = new SolidBrush(accent)) {
                    g.FillRectangle(bTagBg, tagX, tagY, 112, 18);
                    g.DrawRectangle(pTagBorder, tagX, tagY, 112, 18);
                    g.DrawString(String.Format("0{0} // {1}", cardIndex, tagCategory), fTag, bTagText, tagX + 6, tagY + 3);
                }

                // Status Beacon pill
                float pulse = 0.65f + 0.35f * (float)Math.Sin((t + (cardIndex * 0.33f)) * Math.PI * 2f);
                int dotA = (int)(255 * pulse);
                int pillW = 60, pillH = 18;
                int pillX = w - pillW - 12, pillY = 12;
                using (var bPill = new SolidBrush(Color.FromArgb(220, 3, 6, 12)))
                using (var pPill = new Pen(Color.FromArgb(95, statusColor), 1f))
                using (var bDotGlow = new SolidBrush(Color.FromArgb((int)(dotA * 0.28f), statusColor)))
                using (var bDot = new SolidBrush(Color.FromArgb(dotA, statusColor)))
                using (var fStatus = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var bStatusText = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                    g.FillRectangle(bPill, pillX, pillY, pillW, pillH);
                    g.DrawRectangle(pPill, pillX, pillY, pillW, pillH);
                    g.FillEllipse(bDotGlow, pillX + 4, pillY + 4, 10, 10);
                    g.FillEllipse(bDot, pillX + 6, pillY + 6, 6, 6);
                    g.DrawString(statusText, fStatus, bStatusText, pillX + 16, pillY + 3);
                }

                // 5. DETAILS SECTION (Clean, permanently crisp)
                // Left accent vertical bar next to title
                using (var bBar = new SolidBrush(accent)) {
                    g.FillRectangle(bBar, 12, 172, 3, 16);
                }

                // Title
                using (var fTitle = new Font("Segoe UI", 12.2f, FontStyle.Bold))
                using (var bTitle = new SolidBrush(Color.White)) {
                    g.DrawString(title, fTitle, bTitle, 19, 169);
                }

                // Subtitle
                using (var fSub = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var bSub = new SolidBrush(accent)) {
                    g.DrawString(subtitle, fSub, bSub, 13, 195);
                }

                // Description
                using (var fDesc = new Font("Segoe UI", 8.4f, FontStyle.Regular))
                using (var bDesc = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString(description, fDesc, bDesc, new RectangleF(12, 218, w - 24, 60));
                }

                // 6. FOOTER PILLS & UPLINK
                float px = 12f;
                int py = 296;
                using (var fTagPill = new Font("Consolas", 7.0f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, fTagPill);
                        int pw = (int)sz.Width + 8;
                        int ph = 20;
                        using (var bP = new SolidBrush(Color.FromArgb(180, 8, 14, 24)))
                        using (var pP = new Pen(Color.FromArgb(80, 100, 116, 139), 1f))
                        using (var bT = new SolidBrush(Color.FromArgb(224, 242, 254))) {
                            g.FillRectangle(bP, px, py, pw, ph);
                            g.DrawRectangle(pP, px, py, pw, ph);
                            g.DrawString(tag, fTagPill, bT, px + 4, py + 3);
                        }
                        px += pw + 5f;
                    }
                }

                // Right arrow / uplink indicator
                using (var fArrow = new Font("Consolas", 9f, FontStyle.Bold))
                using (var bArrow = new SolidBrush(accent)) {
                    g.DrawString("VIEW ->", fArrow, bArrow, w - 62, py + 3);
                }
            }
            frames[f] = bmp;
        }

        if (bgImg != null) bgImg.Dispose();
        return frames;
    }

    public static void CombineAndSaveRow(string outputGifPath, Bitmap[] f1, Bitmap[] f2, Bitmap[] f3, int delayMs) {
        int w = 840, h = 360;
        int totalFrames = f1.Length;
        var rowFrames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                g.Clear(Color.FromArgb(7, 9, 14));
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.SmoothingMode = SmoothingMode.AntiAlias;

                g.DrawImage(f1[f], 4, 10, 274, 340);
                g.DrawImage(f2[f], 284, 10, 274, 340);
                g.DrawImage(f3[f], 564, 10, 274, 340);
            }
            rowFrames[f] = bmp;
        }

        Console.WriteLine("Encoding Combined Telemetry Row GIF: " + outputGifPath);
        SaveGif(outputGifPath, rowFrames, delayMs);

        string outputPngPath = outputGifPath.Replace(".gif", ".png");
        rowFrames[0].Save(outputPngPath, ImageFormat.Png);
        Console.WriteLine("Saved Row Preview PNG: " + outputPngPath);

        for (int f = 0; f < totalFrames; f++) rowFrames[f].Dispose();
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing"

$assetsDir = "e:\Projects\Readme\assets"

Write-Host "Rendering Autonomous Systems Telemetry Cards (30 frames @ 40ms = 25 FPS)..."

# Card 1: Perception
Write-Host "1. Rendering Perception (telemetry_perception.gif)..."
$pFrames = [TelemetryCardsSuite]::GenerateCardFrames(
    "$assetsDir\telemetry_perception_bg.jpg",
    1,
    "PERCEPTION",
    "LIVE",
    [System.Drawing.Color]::FromArgb(52, 211, 153),
    "PERCEPTION",
    "SENSOR FUSION",
    "Turns camera and depth input into stable landmarks.",
    @("Vision", "WASM", "6-DoF"),
    [System.Drawing.Color]::FromArgb(0, 240, 255),
    0.18,
    30
)
$pFrames[0].Save("e:\Projects\Readme\telemetry_card_1_preview.png", [System.Drawing.Imaging.ImageFormat]::Png)
$pFrames[0].Save("$assetsDir\telemetry_perception.png", [System.Drawing.Imaging.ImageFormat]::Png)
[TelemetryCardsSuite]::SaveGif("$assetsDir\telemetry_perception.gif", $pFrames, 40)
Write-Host "Perception card done."

# Card 2: Reasoning
Write-Host "2. Rendering Reasoning (telemetry_reasoning.gif)..."
$rFrames = [TelemetryCardsSuite]::GenerateCardFrames(
    "$assetsDir\telemetry_reasoning_bg.jpg",
    2,
    "REASONING",
    "LIVE",
    [System.Drawing.Color]::FromArgb(52, 211, 153),
    "REASONING",
    "CAUSAL MODEL",
    "Traces cause and effect across a changing system.",
    @("Graph", "Policy", "Trace"),
    [System.Drawing.Color]::FromArgb(192, 132, 252),
    0.16,
    30
)
$rFrames[0].Save("e:\Projects\Readme\telemetry_card_2_preview.png", [System.Drawing.Imaging.ImageFormat]::Png)
$rFrames[0].Save("$assetsDir\telemetry_reasoning.png", [System.Drawing.Imaging.ImageFormat]::Png)
[TelemetryCardsSuite]::SaveGif("$assetsDir\telemetry_reasoning.gif", $rFrames, 40)
Write-Host "Reasoning card done."

# Card 3: Action
Write-Host "3. Rendering Action (telemetry_action.gif)..."
$aFrames = [TelemetryCardsSuite]::GenerateCardFrames(
    "$assetsDir\telemetry_action_bg.jpg",
    3,
    "ACTION",
    "LIVE",
    [System.Drawing.Color]::FromArgb(52, 211, 153),
    "ACTION",
    "SPATIAL CONTROL",
    "Maps distance, heading, and the next safe move.",
    @("LiDAR", "Nav", "Control"),
    [System.Drawing.Color]::FromArgb(183, 241, 106),
    0.15,
    30
)
$aFrames[0].Save("e:\Projects\Readme\telemetry_card_3_preview.png", [System.Drawing.Imaging.ImageFormat]::Png)
$aFrames[0].Save("$assetsDir\telemetry_action.png", [System.Drawing.Imaging.ImageFormat]::Png)
[TelemetryCardsSuite]::SaveGif("$assetsDir\telemetry_action.gif", $aFrames, 40)
Write-Host "Action card done."

# Combined 840px Showcase Row
Write-Host "4. Rendering Combined 840px Telemetry Row..."
[TelemetryCardsSuite]::CombineAndSaveRow("$assetsDir\telemetry.gif", $pFrames, $rFrames, $aFrames, 40)
Copy-Item "$assetsDir\telemetry.gif" "$assetsDir\telemetry_cards.gif" -Force
Copy-Item "$assetsDir\telemetry.png" "$assetsDir\telemetry_cards.png" -Force
Copy-Item "$assetsDir\telemetry.png" "$assetsDir\telemetry_frame.png" -Force
Copy-Item "$assetsDir\telemetry.png" "e:\Projects\Readme\telemetry_cards_preview.png" -Force

if ($null -ne $pFrames) { foreach ($b in $pFrames) { if ($b) { $b.Dispose() } } }
if ($null -ne $rFrames) { foreach ($b in $rFrames) { if ($b) { $b.Dispose() } } }
if ($null -ne $aFrames) { foreach ($b in $aFrames) { if ($b) { $b.Dispose() } } }

Write-Host "All telemetry cards and combined showcase row generated and saved successfully!"
Get-ChildItem $assetsDir\telemetry*.gif | Select-Object Name, Length
