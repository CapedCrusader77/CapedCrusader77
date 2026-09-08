$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class NewCardsSuite {
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

    // Generic Modern Card Renderer with Ultra-Smooth 25 FPS Loop
    public static Bitmap[] GenerateCardFrames(
        string bgImagePath,
        int cardIndex,
        string tagCategory,
        string statusText,
        Color statusColor,
        string title,
        string subtitle,
        string description,
        string telemetryHeader,
        Func<float, string> getTelemetryValue,
        string[] tags,
        Color accent,
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
                if (bgImg != null) {
                    int targetArtH = 192;
                    int srcW = bgImg.Width;
                    int srcH = (int)(srcW * ((float)targetArtH / w));
                    
                    float cropRatio = 0.20f;
                    if (cardIndex == 2) cropRatio = 0.17f; // Skillguard shield
                    if (cardIndex == 3) cropRatio = 0.22f; // Rootcause graph

                    int srcY = Math.Max(0, (int)((bgImg.Height - srcH) * cropRatio));
                    if (srcY + srcH > bgImg.Height) srcH = bgImg.Height - srcY;

                    Rectangle srcRect = new Rectangle(0, srcY, srcW, srcH);
                    Rectangle dstRect = new Rectangle(2, 2, w - 4, targetArtH);
                    g.DrawImage(bgImg, dstRect, srcRect, GraphicsUnit.Pixel);

                    // Scrim gradient overlay: transparent at upper focal zone, softly fading into obsidian black
                    using (var scrim = new LinearGradientBrush(
                        new Rectangle(0, 0, w, targetArtH + 6),
                        Color.Transparent,
                        Color.FromArgb(255, 4, 7, 12),
                        90f)) {
                        var cb = new ColorBlend(4);
                        cb.Colors = new Color[] {
                            Color.FromArgb(30, 4, 7, 12),
                            Color.FromArgb(65, 4, 7, 12),
                            Color.FromArgb(215, 4, 7, 12),
                            Color.FromArgb(255, 4, 7, 12)
                        };
                        cb.Positions = new float[] { 0f, 0.38f, 0.76f, 1f };
                        scrim.InterpolationColors = cb;
                        g.FillRectangle(scrim, 2, 2, w - 4, targetArtH + 6);
                    }

                    // Gentle ambient holographic scanline with smooth sine fade
                    float scanY = 25f + t * (targetArtH - 45f);
                    float scanAlpha = (float)Math.Sin(t * Math.PI) * 45f;
                    using (var scanPen = new Pen(Color.FromArgb((int)scanAlpha, accent), 1.2f)) {
                        g.DrawLine(scanPen, 10, scanY, w - 10, scanY);
                    }
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
                    g.FillRectangle(bTagBg, tagX, tagY, 100, 18);
                    g.DrawRectangle(pTagBorder, tagX, tagY, 100, 18);
                    g.DrawString(String.Format("0{0} // {1}", cardIndex, tagCategory), fTag, bTagText, tagX + 6, tagY + 3);
                }

                // Status Beacon pill
                float pulse = 0.65f + 0.35f * (float)Math.Sin((t + (cardIndex * 0.33f)) * Math.PI * 2f);
                int dotA = (int)(255 * pulse);
                int pillW = 66, pillH = 18;
                int pillX = w - pillW - 12, pillY = 12;
                using (var bPill = new SolidBrush(Color.FromArgb(220, 3, 6, 12)))
                using (var pPill = new Pen(Color.FromArgb(95, statusColor), 1f))
                using (var bDot = new SolidBrush(Color.FromArgb(dotA, statusColor)))
                using (var fStatus = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var bStatusText = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                    g.FillRectangle(bPill, pillX, pillY, pillW, pillH);
                    g.DrawRectangle(pPill, pillX, pillY, pillW, pillH);
                    g.FillEllipse(bDot, pillX + 6, pillY + 6, 6, 6);
                    g.DrawString(statusText, fStatus, bStatusText, pillX + 16, pillY + 3);
                }

                // Subtle visual HUD Reticle over the 3D art (Custom per card)
                float crossX = w / 2f;
                float crossY = 94f;
                if (cardIndex == 1) {
                    using (var pReticle = new Pen(Color.FromArgb(42, accent), 1f)) {
                        pReticle.DashStyle = DashStyle.Dot;
                        g.DrawEllipse(pReticle, crossX - 42, crossY - 42, 84, 84);
                        g.DrawLine(pReticle, crossX - 50, crossY, crossX - 44, crossY);
                        g.DrawLine(pReticle, crossX + 44, crossY, crossX + 50, crossY);
                        g.DrawLine(pReticle, crossX, crossY - 50, crossX, crossY - 44);
                        g.DrawLine(pReticle, crossX, crossY + 44, crossX, crossY + 50);
                    }
                } else if (cardIndex == 2) {
                    using (var pReticle = new Pen(Color.FromArgb(42, accent), 1f)) {
                        pReticle.DashStyle = DashStyle.Dot;
                        PointF[] hex = new PointF[6];
                        for (int k = 0; k < 6; k++) {
                            float ang = k * 60f * (float)Math.PI / 180f;
                            hex[k] = new PointF(crossX + 46f * (float)Math.Cos(ang), crossY + 46f * (float)Math.Sin(ang));
                        }
                        g.DrawPolygon(pReticle, hex);
                    }
                } else {
                    using (var pReticle = new Pen(Color.FromArgb(42, accent), 1f)) {
                        pReticle.DashStyle = DashStyle.Dot;
                        g.DrawEllipse(pReticle, crossX - 48, crossY - 48, 96, 96);
                        float rot = t * (float)Math.PI * 2f;
                        float node1X = crossX + 48f * (float)Math.Cos(rot);
                        float node1Y = crossY + 48f * (float)Math.Sin(rot);
                        using (var bNode = new SolidBrush(Color.FromArgb(130, accent))) {
                            g.FillEllipse(bNode, node1X - 3, node1Y - 3, 6, 6);
                        }
                    }
                }

                // 5. PROJECT DETAILS SECTION (Permanently Stagnant & Crisp)
                // Left accent vertical bar next to title
                using (var bBar = new SolidBrush(accent)) {
                    g.FillRectangle(bBar, 12, 172, 3, 16);
                }

                // Project Title
                using (var fTitle = new Font("Segoe UI", 12.2f, FontStyle.Bold))
                using (var bTitle = new SolidBrush(Color.White)) {
                    g.DrawString(title, fTitle, bTitle, 19, 169);
                }

                // Subtitle / Architecture Role
                using (var fSub = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var bSub = new SolidBrush(accent)) {
                    g.DrawString(subtitle, fSub, bSub, 13, 195);
                }

                // Clean Concise Description
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

                // Right arrow / link indicator
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

        Console.WriteLine("Encoding Combined Row GIF: " + outputGifPath);
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

Write-Host "Rendering all 3 cards with 30 frames @ 40ms (25 FPS)..."

# Card 1: FaceTrack-AI
Write-Host "Rendering FaceTrack-AI (card_slam.gif)..."
$ftFrames = [NewCardsSuite]::GenerateCardFrames(
    "$assetsDir\project_facetrack_bg.jpg",
    1,
    "CV-CORE",
    "ACTIVE",
    [System.Drawing.Color]::FromArgb(52, 211, 153),
    "FaceTrack-AI",
    "REAL-TIME 6-DOF FACEMESH",
    "High-frequency 3D facial landmark mesh & gaze vector tensor pipeline via WebAssembly.",
    "TELEMETRY // SIMD WASM PIPELINE",
    [Func[float, string]]{ param($t) "POSE: YAW " + [string]::Format("{0:+0.0;-0.0}", [Math]::Sin($t * [Math]::PI * 2.0) * 6.2) + " deg | 60 FPS | 11.2ms" },
    @("TypeScript", "WASM", "OpenCV"),
    [System.Drawing.Color]::FromArgb(0, 240, 255),
    30
)
$ftFrames[0].Save("e:\Projects\Readme\card_1_preview.png", [System.Drawing.Imaging.ImageFormat]::Png)
[NewCardsSuite]::SaveGif("$assetsDir\card_slam.gif", $ftFrames, 40)
Write-Host "Card 1 done."

# Card 2: SkillGuard-OSS
Write-Host "Rendering SkillGuard-OSS (card_vision.gif)..."
$sgFrames = [NewCardsSuite]::GenerateCardFrames(
    "$assetsDir\project_skillguard_bg.jpg",
    2,
    "SEC-AST",
    "ACTIVE",
    [System.Drawing.Color]::FromArgb(52, 211, 153),
    "SkillGuard-OSS",
    "ZERO-TRUST AST SECURITY AUDIT",
    "Static AST capability inspection engine detecting permission leaks & supply-chain threats.",
    "SECURITY // 4,820 AST NODES AUDITED",
    [Func[float, string]]{ param($t) "POLICY: STRICT | ZERO LEAKS | PASS" },
    @("TypeScript", "AST", "Security"),
    [System.Drawing.Color]::FromArgb(192, 132, 252),
    30
)
$sgFrames[0].Save("e:\Projects\Readme\card_2_preview.png", [System.Drawing.Imaging.ImageFormat]::Png)
[NewCardsSuite]::SaveGif("$assetsDir\card_vision.gif", $sgFrames, 40)
Write-Host "Card 2 done."

# Card 3: RootCause-IQ
Write-Host "Rendering RootCause-IQ (card_mpc.gif)..."
$rcFrames = [NewCardsSuite]::GenerateCardFrames(
    "$assetsDir\project_rootcause_bg.jpg",
    3,
    "CAUSAL",
    "ONLINE",
    [System.Drawing.Color]::FromArgb(56, 189, 248),
    "RootCause-IQ",
    "AUTOMATED DIAGNOSTIC ENGINE",
    "Distributed trace graph reconstruction & deterministic causal root-cause localization.",
    "TRACE // DISTRIBUTED DAG RECONSTRUCTION",
    [Func[float, string]]{ param($t) "DAG: 18 NODES | LATENCY: 1.2ms | OK" },
    @("Python", "OTel", "Causal-AI"),
    [System.Drawing.Color]::FromArgb(56, 189, 248),
    30
)
$rcFrames[0].Save("e:\Projects\Readme\card_3_preview.png", [System.Drawing.Imaging.ImageFormat]::Png)
[NewCardsSuite]::SaveGif("$assetsDir\card_mpc.gif", $rcFrames, 40)
Write-Host "Card 3 done."

# Combined 840px Showcase Row
Write-Host "Rendering Combined 840px Showcase Row (cards_row.gif)..."
[NewCardsSuite]::CombineAndSaveRow("$assetsDir\cards_row.gif", $ftFrames, $sgFrames, $rcFrames, 40)
Copy-Item "$assetsDir\cards_row.png" "e:\Projects\Readme\cards_row_preview.png" -Force

for ($i = 0; $i -lt 30; $i++) {
    $ftFrames[$i].Dispose()
    $sgFrames[$i].Dispose()
    $rcFrames[$i].Dispose()
}

Write-Host "All cards and combined showcase row generated and saved successfully!"
Get-ChildItem $assetsDir\card*.gif | Select-Object Name, Length
