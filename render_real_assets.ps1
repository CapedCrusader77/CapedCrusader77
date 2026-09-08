$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class GifMaker {
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

public class RealAssetGenerator {
    private static Image imgFaceTrack = null;
    private static Image imgSkillguard = null;
    private static Image imgRootcause = null;

    public static void LoadProjectImages(string ftPath, string sgPath, string rcPath) {
        if (imgFaceTrack != null) imgFaceTrack.Dispose();
        if (imgSkillguard != null) imgSkillguard.Dispose();
        if (imgRootcause != null) imgRootcause.Dispose();
        if (File.Exists(ftPath)) imgFaceTrack = Image.FromFile(ftPath);
        if (File.Exists(sgPath)) imgSkillguard = Image.FromFile(sgPath);
        if (File.Exists(rcPath)) imgRootcause = Image.FromFile(rcPath);
    }

    public static void SetHighQuality(Graphics g) {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
    }

    public static void DrawCornerBrackets(Graphics g, float x, float y, float w, float h, Color color, float len = 8f) {
        using (var p = new Pen(color, 1.4f)) {
            g.DrawLines(p, new PointF[] { new PointF(x, y + len), new PointF(x, y), new PointF(x + len, y) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - len, y), new PointF(x + w, y), new PointF(x + w, y + len) });
            g.DrawLines(p, new PointF[] { new PointF(x, y + h - len), new PointF(x, y + h), new PointF(x + len, y + h) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - len, y + h), new PointF(x + w, y + h), new PointF(x + w, y + h - len) });
        }
    }

    // 1. Section Banner Generator
    public static void RenderBanner(string outputPath, string title, string subtitle, string tag, Color accent, int totalFrames = 20) {
        int w = 840, h = 46;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float progress = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var brush = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }
                using (var pen = new Pen(Color.FromArgb(24, 32, 45), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                int chamferW = 185;
                var pts = new PointF[] {
                    new PointF(0, 0),
                    new PointF(chamferW, 0),
                    new PointF(chamferW - 14, h),
                    new PointF(0, h)
                };
                using (var brush = new SolidBrush(Color.FromArgb(10, 15, 24))) {
                    g.FillPolygon(brush, pts);
                }
                using (var pen = new Pen(accent, 1.5f)) {
                    g.DrawLine(pen, 0, 0, chamferW, 0);
                    g.DrawLine(pen, chamferW, 0, chamferW - 14, h);
                    g.DrawLine(pen, 0, h - 1, chamferW - 14, h - 1);
                    g.DrawLine(pen, 0, 0, 0, h);
                }

                using (var font = new Font("Segoe UI", 11.5f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(245, 248, 252))) {
                    g.DrawString(title, font, brush, 18, 12);
                }

                using (var font = new Font("Consolas", 9.5f, FontStyle.Regular))
                using (var brush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString(subtitle, font, brush, chamferW + 16, 14);
                }

                // Laser traveling beam on top edge
                float beamX = progress * (w + 100) - 50;
                using (var brush = new LinearGradientBrush(
                    new RectangleF(beamX - 60, 0, 120, 2),
                    Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, accent, Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    brush.InterpolationColors = cb;
                    g.FillRectangle(brush, beamX - 60, 0, 120, 2);
                }

                // Pulsing Online Status Pip
                float pulse = 0.6f + 0.4f * (float)Math.Sin(progress * Math.PI * 2);
                int r = (int)(accent.R * pulse);
                int gr = (int)(accent.G * pulse);
                int b = (int)(accent.B * pulse);
                using (var dotBrush = new SolidBrush(Color.FromArgb(r, gr, b))) {
                    g.FillEllipse(dotBrush, w - 160, 18, 9, 9);
                }
                using (var font = new Font("Consolas", 9.0f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString(tag, font, brush, w - 144, 14);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 2. Horizontal Project Card 1: FaceTrack-AI (Clean Developer Card)
    public static void RenderCardFaceTrack(string outputPath, int totalFrames = 20) {
        int w = 274, h = 248;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(0, 240, 255); // Cyan
        Color borderColor = Color.FromArgb(28, 46, 68);

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Pure Black Canvas
                using (var brush = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }

                // Attractive Dark Ambient Gradient Background
                using (var gradBrush = new LinearGradientBrush(
                    new Rectangle(0, 0, w, h),
                    Color.FromArgb(8, 16, 26), Color.FromArgb(2, 4, 8), 90f)) {
                    g.FillRectangle(gradBrush, 0, 0, w, h);
                }

                // Subtle Micro Technical Grid (Dot Matrix)
                using (var dotBrush = new SolidBrush(Color.FromArgb(24, 0, 240, 255))) {
                    for (int gy = 14; gy < h; gy += 14) {
                        for (int gx = 14; gx < w; gx += 14) {
                            g.FillRectangle(dotBrush, gx, gy, 1f, 1f);
                        }
                    }
                }

                // Outer Card Border
                using (var pen = new Pen(borderColor, 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // Left Accent Stripe
                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 3, h);
                }

                // Top Traveling Laser Edge Highlight
                float beamX = t * (w + 80) - 40;
                using (var beamBrush = new LinearGradientBrush(
                    new RectangleF(beamX - 35, 0, 70, 2),
                    Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, accent, Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    beamBrush.InterpolationColors = cb;
                    g.FillRectangle(beamBrush, beamX - 35, 0, 70, 2);
                }

                // Header Row: Category & Status Badge
                using (var catFont = new Font("Consolas", 8f, FontStyle.Bold))
                using (var catBrush = new SolidBrush(accent)) {
                    g.DrawString("01 // COMPUTER_VISION", catFont, catBrush, 12, 10);
                }

                // Status Badge with live pulse
                float pulse = 0.5f + 0.5f * (float)Math.Sin(t * Math.PI * 2f);
                int pulseAlpha = (int)(160 + 95 * pulse);
                using (var stFont = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(10, 24, 38)))
                using (var stBorder = new Pen(Color.FromArgb(20, 60, 88), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                    g.FillRectangle(stBg, w - 96, 9, 84, 16);
                    g.DrawRectangle(stBorder, w - 96, 9, 84, 16);
                    using (var dotBr = new SolidBrush(Color.FromArgb(pulseAlpha, 52, 211, 153))) {
                        g.FillEllipse(dotBr, w - 90, 14, 5, 5);
                    }
                    g.DrawString("60 FPS // RT", stFont, stText, w - 81, 11);
                }

                // Title & Subtitle
                using (var titleFont = new Font("Consolas", 13.5f, FontStyle.Bold))
                using (var titleBrush = new SolidBrush(Color.FromArgb(248, 250, 252))) {
                    g.DrawString("FaceTrack-AI", titleFont, titleBrush, 12, 30);
                }
                using (var subFont = new Font("Segoe UI", 8.2f, FontStyle.Bold))
                using (var subBrush = new SolidBrush(accent)) {
                    g.DrawString("Real-time CV & 6-DoF FaceMesh", subFont, subBrush, 12, 52);
                }

                // Description
                using (var descFont = new Font("Segoe UI", 7.6f, FontStyle.Regular))
                using (var descBrush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("High-frequency perception pipeline with dense\nlandmark tracking & client WebAssembly inference.", descFont, descBrush, 12, 69);
                }

                // Technical Console / Specs Box
                int conX = 12, conY = 100, conW = w - 24, conH = 68;
                using (var conBg = new SolidBrush(Color.FromArgb(2, 6, 12))) {
                    g.FillRectangle(conBg, conX, conY, conW, conH);
                }
                using (var conPen = new Pen(Color.FromArgb(22, 38, 56), 1f)) {
                    g.DrawRectangle(conPen, conX, conY, conW, conH);
                }
                // Console header bar
                using (var headBg = new SolidBrush(Color.FromArgb(8, 18, 30))) {
                    g.FillRectangle(headBg, conX, conY, conW, 16);
                }
                using (var headFont = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var headText = new SolidBrush(Color.FromArgb(125, 211, 252))) {
                    g.FillEllipse(new SolidBrush(Color.FromArgb(52, 211, 153)), conX + 8, conY + 5, 5, 5);
                    g.DrawString("SPECS // TELEMETRY", headFont, headText, conX + 18, conY + 2);
                }

                // Console rows
                using (var rowFont = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var rowBrush = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString("> INFERENCE : WebGL / WASM (1.2ms)", rowFont, rowBrush, conX + 8, conY + 20);
                    g.DrawString("> TOPOLOGY  : 468 Dense Landmarks", rowFont, rowBrush, conX + 8, conY + 34);
                    g.DrawString("> PRECISION : 99.8% Multi-Pose Lock", rowFont, rowBrush, conX + 8, conY + 48);
                }

                // GitHub Language Distribution Bar
                int barX = 12, barY = 176, barW = w - 24, barH = 5;
                // Background track
                using (var trkBr = new SolidBrush(Color.FromArgb(15, 23, 42))) {
                    g.FillRectangle(trkBr, barX, barY, barW, barH);
                }
                // TypeScript (85%)
                int tsW = (int)(barW * 0.85f);
                using (var tsBr = new SolidBrush(Color.FromArgb(49, 120, 198))) {
                    g.FillRectangle(tsBr, barX, barY, tsW, barH);
                }
                // JavaScript (15%)
                using (var jsBr = new SolidBrush(Color.FromArgb(247, 223, 30))) {
                    g.FillRectangle(jsBr, barX + tsW, barY, barW - tsW, barH);
                }

                // Language Legend
                using (var legFont = new Font("Segoe UI", 6.8f, FontStyle.Bold)) {
                    using (var dot1 = new SolidBrush(Color.FromArgb(49, 120, 198)))
                    using (var dot2 = new SolidBrush(Color.FromArgb(247, 223, 30)))
                    using (var legText = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.FillEllipse(dot1, barX + 2, barY + 9, 5, 5);
                        g.DrawString("TypeScript 85%", legFont, legText, barX + 10, barY + 6);

                        g.FillEllipse(dot2, barX + 90, barY + 9, 5, 5);
                        g.DrawString("JavaScript 15%", legFont, legText, barX + 98, barY + 6);
                    }
                }

                // Tech Stack Pills
                string[] tags = new string[] { "TypeScript", "TF.js", "OpenCV" };
                float tagX = 12;
                using (var tagFont = new Font("Consolas", 7.4f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        using (var bgBrush = new SolidBrush(Color.FromArgb(12, 22, 34))) {
                            g.FillRectangle(bgBrush, tagX, 198, sz.Width + 6, 16);
                        }
                        using (var borderPen = new Pen(Color.FromArgb(28, 48, 70), 1f)) {
                            g.DrawRectangle(borderPen, tagX, 198, sz.Width + 6, 16);
                        }
                        using (var textBrush = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                            g.DrawString(tag, tagFont, textBrush, tagX + 3, 200);
                        }
                        tagX += sz.Width + 10;
                    }
                }

                // Footer Bar
                using (var linePen = new Pen(Color.FromArgb(22, 36, 52), 1f)) {
                    g.DrawLine(linePen, 12, 224, w - 12, 224);
                }
                using (var footFont = new Font("Consolas", 7.2f, FontStyle.Bold)) {
                    using (var leftText = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                        g.DrawString("PUBLIC REPO", footFont, leftText, 12, 230);
                    }
                    float arrowShift = (float)Math.Sin(t * Math.PI * 2f) * 2f;
                    using (var rightText = new SolidBrush(accent)) {
                        g.DrawString("VIEW CODE ->", footFont, rightText, w - 86 + arrowShift, 230);
                    }
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 3. Horizontal Project Card 2: skillguard-oss (Clean Developer Card)
    public static void RenderCardSkillguard(string outputPath, int totalFrames = 20) {
        int w = 274, h = 248;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(167, 139, 250); // Electric Violet
        Color borderColor = Color.FromArgb(44, 32, 64);

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Pure Black Canvas
                using (var brush = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }

                // Attractive Dark Ambient Gradient Background
                using (var gradBrush = new LinearGradientBrush(
                    new Rectangle(0, 0, w, h),
                    Color.FromArgb(16, 10, 26), Color.FromArgb(3, 2, 8), 90f)) {
                    g.FillRectangle(gradBrush, 0, 0, w, h);
                }

                // Subtle Micro Technical Grid (Dot Matrix)
                using (var dotBrush = new SolidBrush(Color.FromArgb(24, 167, 139, 250))) {
                    for (int gy = 14; gy < h; gy += 14) {
                        for (int gx = 14; gx < w; gx += 14) {
                            g.FillRectangle(dotBrush, gx, gy, 1f, 1f);
                        }
                    }
                }

                // Outer Card Border
                using (var pen = new Pen(borderColor, 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // Left Accent Stripe
                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 3, h);
                }

                // Top Traveling Laser Edge Highlight
                float beamX = t * (w + 80) - 40;
                using (var beamBrush = new LinearGradientBrush(
                    new RectangleF(beamX - 35, 0, 70, 2),
                    Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, accent, Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    beamBrush.InterpolationColors = cb;
                    g.FillRectangle(beamBrush, beamX - 35, 0, 70, 2);
                }

                // Header Row: Category & Status Badge
                using (var catFont = new Font("Consolas", 8f, FontStyle.Bold))
                using (var catBrush = new SolidBrush(accent)) {
                    g.DrawString("02 // SECURITY_AUDIT", catFont, catBrush, 12, 10);
                }

                // Status Badge with live pulse
                float pulse = 0.5f + 0.5f * (float)Math.Sin(t * Math.PI * 2f);
                int pulseAlpha = (int)(160 + 95 * pulse);
                using (var stFont = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(28, 18, 44)))
                using (var stBorder = new Pen(Color.FromArgb(64, 42, 94), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(221, 214, 254))) {
                    g.FillRectangle(stBg, w - 96, 9, 84, 16);
                    g.DrawRectangle(stBorder, w - 96, 9, 84, 16);
                    using (var dotBr = new SolidBrush(Color.FromArgb(pulseAlpha, 192, 132, 252))) {
                        g.FillEllipse(dotBr, w - 90, 14, 5, 5);
                    }
                    g.DrawString("OSS AUDIT", stFont, stText, w - 79, 11);
                }

                // Title & Subtitle
                using (var titleFont = new Font("Consolas", 13.5f, FontStyle.Bold))
                using (var titleBrush = new SolidBrush(Color.FromArgb(248, 250, 252))) {
                    g.DrawString("skillguard-oss", titleFont, titleBrush, 12, 30);
                }
                using (var subFont = new Font("Segoe UI", 8.2f, FontStyle.Bold))
                using (var subBrush = new SolidBrush(accent)) {
                    g.DrawString("AI Agent Security & AST Audit", subFont, subBrush, 12, 52);
                }

                // Description
                using (var descFont = new Font("Segoe UI", 7.6f, FontStyle.Regular))
                using (var descBrush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Automated capability audit engine analyzing\nAST syntaxes, sandboxes & permission guards.", descFont, descBrush, 12, 69);
                }

                // Technical Console / Specs Box
                int conX = 12, conY = 100, conW = w - 24, conH = 68;
                using (var conBg = new SolidBrush(Color.FromArgb(8, 4, 16))) {
                    g.FillRectangle(conBg, conX, conY, conW, conH);
                }
                using (var conPen = new Pen(Color.FromArgb(36, 22, 54), 1f)) {
                    g.DrawRectangle(conPen, conX, conY, conW, conH);
                }
                // Console header bar
                using (var headBg = new SolidBrush(Color.FromArgb(20, 12, 36))) {
                    g.FillRectangle(headBg, conX, conY, conW, 16);
                }
                using (var headFont = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var headText = new SolidBrush(Color.FromArgb(221, 214, 254))) {
                    g.FillEllipse(new SolidBrush(Color.FromArgb(52, 211, 153)), conX + 8, conY + 5, 5, 5);
                    g.DrawString("SPECS // AUDIT_ENGINE", headFont, headText, conX + 18, conY + 2);
                }

                // Console rows
                using (var rowFont = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var rowBrush = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString("> SANDBOX   : Subprocess Isolation", rowFont, rowBrush, conX + 8, conY + 20);
                    g.DrawString("> RULESET   : 140+ Capability Checks", rowFont, rowBrush, conX + 8, conY + 34);
                    g.DrawString("> VULN SCAN : 0 Critical // Verified", rowFont, rowBrush, conX + 8, conY + 48);
                }

                // GitHub Language Distribution Bar
                int barX = 12, barY = 176, barW = w - 24, barH = 5;
                // Background track
                using (var trkBr = new SolidBrush(Color.FromArgb(15, 23, 42))) {
                    g.FillRectangle(trkBr, barX, barY, barW, barH);
                }
                // Python (92%)
                int pyW = (int)(barW * 0.92f);
                using (var pyBr = new SolidBrush(Color.FromArgb(53, 114, 165))) {
                    g.FillRectangle(pyBr, barX, barY, pyW, barH);
                }
                // Shell (8%)
                using (var shBr = new SolidBrush(Color.FromArgb(137, 224, 81))) {
                    g.FillRectangle(shBr, barX + pyW, barY, barW - pyW, barH);
                }

                // Language Legend
                using (var legFont = new Font("Segoe UI", 6.8f, FontStyle.Bold)) {
                    using (var dot1 = new SolidBrush(Color.FromArgb(53, 114, 165)))
                    using (var dot2 = new SolidBrush(Color.FromArgb(137, 224, 81)))
                    using (var legText = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.FillEllipse(dot1, barX + 2, barY + 9, 5, 5);
                        g.DrawString("Python 92%", legFont, legText, barX + 10, barY + 6);

                        g.FillEllipse(dot2, barX + 90, barY + 9, 5, 5);
                        g.DrawString("Shell 8%", legFont, legText, barX + 98, barY + 6);
                    }
                }

                // Tech Stack Pills
                string[] tags = new string[] { "Python", "AST", "Security" };
                float tagX = 12;
                using (var tagFont = new Font("Consolas", 7.4f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        using (var bgBrush = new SolidBrush(Color.FromArgb(24, 14, 38))) {
                            g.FillRectangle(bgBrush, tagX, 198, sz.Width + 6, 16);
                        }
                        using (var borderPen = new Pen(Color.FromArgb(56, 36, 84), 1f)) {
                            g.DrawRectangle(borderPen, tagX, 198, sz.Width + 6, 16);
                        }
                        using (var textBrush = new SolidBrush(Color.FromArgb(221, 214, 254))) {
                            g.DrawString(tag, tagFont, textBrush, tagX + 3, 200);
                        }
                        tagX += sz.Width + 10;
                    }
                }

                // Footer Bar
                using (var linePen = new Pen(Color.FromArgb(38, 24, 56), 1f)) {
                    g.DrawLine(linePen, 12, 224, w - 12, 224);
                }
                using (var footFont = new Font("Consolas", 7.2f, FontStyle.Bold)) {
                    using (var leftText = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                        g.DrawString("OPEN SOURCE", footFont, leftText, 12, 230);
                    }
                    float arrowShift = (float)Math.Sin(t * Math.PI * 2f) * 2f;
                    using (var rightText = new SolidBrush(accent)) {
                        g.DrawString("VIEW CODE ->", footFont, rightText, w - 86 + arrowShift, 230);
                    }
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 4. Horizontal Project Card 3: rootcause-iq (Clean Developer Card)
    public static void RenderCardRootcause(string outputPath, int totalFrames = 20) {
        int w = 274, h = 248;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(56, 189, 248); // Sky Blue
        Color borderColor = Color.FromArgb(26, 48, 70);

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Pure Black Canvas
                using (var brush = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }

                // Attractive Dark Ambient Gradient Background
                using (var gradBrush = new LinearGradientBrush(
                    new Rectangle(0, 0, w, h),
                    Color.FromArgb(6, 18, 28), Color.FromArgb(2, 5, 10), 90f)) {
                    g.FillRectangle(gradBrush, 0, 0, w, h);
                }

                // Subtle Micro Technical Grid (Dot Matrix)
                using (var dotBrush = new SolidBrush(Color.FromArgb(24, 56, 189, 248))) {
                    for (int gy = 14; gy < h; gy += 14) {
                        for (int gx = 14; gx < w; gx += 14) {
                            g.FillRectangle(dotBrush, gx, gy, 1f, 1f);
                        }
                    }
                }

                // Outer Card Border
                using (var pen = new Pen(borderColor, 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // Left Accent Stripe
                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 3, h);
                }

                // Top Traveling Laser Edge Highlight
                float beamX = t * (w + 80) - 40;
                using (var beamBrush = new LinearGradientBrush(
                    new RectangleF(beamX - 35, 0, 70, 2),
                    Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, accent, Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    beamBrush.InterpolationColors = cb;
                    g.FillRectangle(beamBrush, beamX - 35, 0, 70, 2);
                }

                // Header Row: Category & Status Badge
                using (var catFont = new Font("Consolas", 8f, FontStyle.Bold))
                using (var catBrush = new SolidBrush(accent)) {
                    g.DrawString("03 // CAUSAL_SYSTEMS", catFont, catBrush, 12, 10);
                }

                // Status Badge with live pulse
                float pulse = 0.5f + 0.5f * (float)Math.Sin(t * Math.PI * 2f);
                int pulseAlpha = (int)(160 + 95 * pulse);
                using (var stFont = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(12, 28, 44)))
                using (var stBorder = new Pen(Color.FromArgb(30, 64, 94), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                    g.FillRectangle(stBg, w - 96, 9, 84, 16);
                    g.DrawRectangle(stBorder, w - 96, 9, 84, 16);
                    using (var dotBr = new SolidBrush(Color.FromArgb(pulseAlpha, 52, 211, 153))) {
                        g.FillEllipse(dotBr, w - 90, 14, 5, 5);
                    }
                    g.DrawString("AUTO-HEAL", stFont, stText, w - 80, 11);
                }

                // Title & Subtitle
                using (var titleFont = new Font("Consolas", 13.5f, FontStyle.Bold))
                using (var titleBrush = new SolidBrush(Color.FromArgb(248, 250, 252))) {
                    g.DrawString("rootcause-iq", titleFont, titleBrush, 12, 30);
                }
                using (var subFont = new Font("Segoe UI", 8.2f, FontStyle.Bold))
                using (var subBrush = new SolidBrush(accent)) {
                    g.DrawString("Diagnostic & Root-Cause Engine", subFont, subBrush, 12, 52);
                }

                // Description
                using (var descFont = new Font("Segoe UI", 7.6f, FontStyle.Regular))
                using (var descBrush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Intelligent failure tracing correlating distributed\nerror propagations & automated recovery paths.", descFont, descBrush, 12, 69);
                }

                // Technical Console / Specs Box
                int conX = 12, conY = 100, conW = w - 24, conH = 68;
                using (var conBg = new SolidBrush(Color.FromArgb(2, 8, 14))) {
                    g.FillRectangle(conBg, conX, conY, conW, conH);
                }
                using (var conPen = new Pen(Color.FromArgb(20, 42, 62), 1f)) {
                    g.DrawRectangle(conPen, conX, conY, conW, conH);
                }
                // Console header bar
                using (var headBg = new SolidBrush(Color.FromArgb(10, 22, 36))) {
                    g.FillRectangle(headBg, conX, conY, conW, 16);
                }
                using (var headFont = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var headText = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                    g.FillEllipse(new SolidBrush(Color.FromArgb(52, 211, 153)), conX + 8, conY + 5, 5, 5);
                    g.DrawString("SPECS // CAUSAL_DAG", headFont, headText, conX + 18, conY + 2);
                }

                // Console rows
                using (var rowFont = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var rowBrush = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString("> TRACING   : OpenTelemetry Causal DAG", rowFont, rowBrush, conX + 8, conY + 20);
                    g.DrawString("> RESOLUTION: Autonomous Routing", rowFont, rowBrush, conX + 8, conY + 34);
                    g.DrawString("> RECOVERY  : < 200ms // Zero Downtime", rowFont, rowBrush, conX + 8, conY + 48);
                }

                // GitHub Language Distribution Bar
                int barX = 12, barY = 176, barW = w - 24, barH = 5;
                // Background track
                using (var trkBr = new SolidBrush(Color.FromArgb(15, 23, 42))) {
                    g.FillRectangle(trkBr, barX, barY, barW, barH);
                }
                // TypeScript (76%)
                int tsW = (int)(barW * 0.76f);
                using (var tsBr = new SolidBrush(Color.FromArgb(49, 120, 198))) {
                    g.FillRectangle(tsBr, barX, barY, tsW, barH);
                }
                // Python (24%)
                using (var pyBr = new SolidBrush(Color.FromArgb(53, 114, 165))) {
                    g.FillRectangle(pyBr, barX + tsW, barY, barW - tsW, barH);
                }

                // Language Legend
                using (var legFont = new Font("Segoe UI", 6.8f, FontStyle.Bold)) {
                    using (var dot1 = new SolidBrush(Color.FromArgb(49, 120, 198)))
                    using (var dot2 = new SolidBrush(Color.FromArgb(53, 114, 165)))
                    using (var legText = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.FillEllipse(dot1, barX + 2, barY + 9, 5, 5);
                        g.DrawString("TypeScript 76%", legFont, legText, barX + 10, barY + 6);

                        g.FillEllipse(dot2, barX + 90, barY + 9, 5, 5);
                        g.DrawString("Python 24%", legFont, legText, barX + 98, barY + 6);
                    }
                }

                // Tech Stack Pills
                string[] tags = new string[] { "TypeScript", "Graph", "Next.js" };
                float tagX = 12;
                using (var tagFont = new Font("Consolas", 7.4f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        using (var bgBrush = new SolidBrush(Color.FromArgb(12, 26, 40))) {
                            g.FillRectangle(bgBrush, tagX, 198, sz.Width + 6, 16);
                        }
                        using (var borderPen = new Pen(Color.FromArgb(28, 54, 80), 1f)) {
                            g.DrawRectangle(borderPen, tagX, 198, sz.Width + 6, 16);
                        }
                        using (var textBrush = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                            g.DrawString(tag, tagFont, textBrush, tagX + 3, 200);
                        }
                        tagX += sz.Width + 10;
                    }
                }

                // Footer Bar
                using (var linePen = new Pen(Color.FromArgb(20, 38, 58), 1f)) {
                    g.DrawLine(linePen, 12, 224, w - 12, 224);
                }
                using (var footFont = new Font("Consolas", 7.2f, FontStyle.Bold)) {
                    using (var leftText = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                        g.DrawString("SYSTEM CORE", footFont, leftText, 12, 230);
                    }
                    float arrowShift = (float)Math.Sin(t * Math.PI * 2f) * 2f;
                    using (var rightText = new SolidBrush(accent)) {
                        g.DrawString("VIEW CODE ->", footFont, rightText, w - 86 + arrowShift, 230);
                    }
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 5. Divider Generator: GOKUL A // AUTONOMOUS_CORE
    public static void RenderDivider(string outputPath, int totalFrames = 20) {
        int w = 840, h = 24;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float progress = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var linePen = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawLine(linePen, 0, h / 2, w, h / 2);
                }

                int bw = 260, bh = 18;
                int bx = (w - bw) / 2;
                int by = (h - bh) / 2;
                using (var bgBrush = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(bgBrush, bx, by, bw, bh);
                }
                using (var borderPen = new Pen(Color.FromArgb(36, 48, 68), 1f)) {
                    g.DrawRectangle(borderPen, bx, by, bw, bh);
                }

                using (var font = new Font("Consolas", 8.5f, FontStyle.Bold))
                using (var textBrush = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    var str = "[ GOKUL A // AUTONOMOUS_CORE ]";
                    var sz = g.MeasureString(str, font);
                    g.DrawString(str, font, textBrush, bx + (bw - sz.Width) / 2, by + 2);
                }

                // Laser Traveling Beam
                float beamX = progress * (w + 120) - 60;
                using (var brush = new LinearGradientBrush(
                    new RectangleF(beamX - 40, h / 2 - 1, 80, 3),
                    Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, Color.FromArgb(0, 240, 255), Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    brush.InterpolationColors = cb;
                    g.FillRectangle(brush, beamX - 40, h / 2 - 1, 80, 3);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 60);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 6. REAL Telemetry Dual Console
    public static void RenderTelemetry(string outputPath, int totalFrames = 24) {
        int w = 840, h = 240;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var brush = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }

                // ================= LEFT TERMINAL: STATS =================
                int t1X = 0, t1Y = 0, t1W = 412, t1H = h;
                using (var tBg = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(tBg, t1X, t1Y, t1W, t1H);
                }
                using (var tBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawRectangle(tBorder, t1X, t1Y, t1W - 1, t1H - 1);
                }
                using (var hBg = new SolidBrush(Color.FromArgb(15, 21, 32))) {
                    g.FillRectangle(hBg, t1X, t1Y, t1W, 28);
                }
                using (var hBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawLine(hBorder, t1X, t1Y + 28, t1X + t1W, t1Y + 28);
                }
                g.FillEllipse(new SolidBrush(Color.FromArgb(255, 95, 86)), t1X + 12, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(254, 188, 46)), t1X + 28, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(39, 201, 63)), t1X + 44, 9, 10, 10);
                using (var fTitle = new Font("Consolas", 9f, FontStyle.Regular))
                using (var bTitle = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("~/stats $ ./metrics --live", fTitle, bTitle, t1X + 64, 7);
                }

                // REAL Numbers: 5 stars, 15 repos, 25 followers
                using (var numFont = new Font("Consolas", 18f, FontStyle.Bold))
                using (var lblFont = new Font("Consolas", 8.5f, FontStyle.Regular)) {
                    g.DrawString("5", numFont, new SolidBrush(Color.FromArgb(0, 240, 255)), t1X + 36, 42);
                    g.DrawString("stars *", lblFont, new SolidBrush(Color.FromArgb(148, 163, 184)), t1X + 32, 70);

                    g.DrawString("15", numFont, new SolidBrush(Color.FromArgb(167, 139, 250)), t1X + 160, 42);
                    g.DrawString("repositories", lblFont, new SolidBrush(Color.FromArgb(148, 163, 184)), t1X + 154, 70);

                    g.DrawString("25", numFont, new SolidBrush(Color.FromArgb(56, 189, 248)), t1X + 290, 42);
                    g.DrawString("followers", lblFont, new SolidBrush(Color.FromArgb(148, 163, 184)), t1X + 288, 70);
                }

                using (var fSub = new Font("Consolas", 8.5f, FontStyle.Bold))
                using (var bSub = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("// real language breakdown", fSub, bSub, t1X + 24, 96);
                }

                // REAL Languages: typescript (45%), python (30%), javascript (15%), shell/other (10%)
                string[] langs = new string[] { "typescript", "python", "javascript", "shell/other" };
                int[] pcts = new int[] { 45, 30, 15, 10 };
                Color[] barColors = new Color[] {
                    Color.FromArgb(0, 240, 255),
                    Color.FromArgb(167, 139, 250),
                    Color.FromArgb(56, 189, 248),
                    Color.FromArgb(52, 211, 153)
                };

                for (int l = 0; l < 4; l++) {
                    int ly = 116 + l * 22;
                    using (var fLang = new Font("Consolas", 8.5f, FontStyle.Regular))
                    using (var bLang = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                        g.DrawString(langs[l], fLang, bLang, t1X + 24, ly);
                    }

                    int bx = t1X + 115, bw = 220, bh = 11;
                    using (var bgBar = new SolidBrush(Color.FromArgb(20, 28, 42))) {
                        g.FillRectangle(bgBar, bx, ly + 2, bw, bh);
                    }

                    float fillW = bw * (pcts[l] / 100f);
                    using (var fillBar = new SolidBrush(barColors[l])) {
                        g.FillRectangle(fillBar, bx, ly + 2, fillW, bh);
                    }

                    if (l == 0) {
                        var prevClip = g.Clip;
                        g.SetClip(new Rectangle(bx, ly + 2, (int)fillW, bh));
                        float shimX = bx + (t * (bw + 60) - 30);
                        using (var shimBrush = new LinearGradientBrush(
                            new RectangleF(shimX - 20, ly + 2, 40, bh),
                            Color.Transparent, Color.Transparent, 0f)) {
                            var cb = new ColorBlend(3);
                            cb.Colors = new Color[] { Color.Transparent, Color.FromArgb(180, 255, 255, 255), Color.Transparent };
                            cb.Positions = new float[] { 0f, 0.5f, 1f };
                            shimBrush.InterpolationColors = cb;
                            g.FillRectangle(shimBrush, shimX - 20, ly + 2, 40, bh);
                        }
                        g.Clip = prevClip;
                    }

                    using (var fPct = new Font("Consolas", 8f, FontStyle.Bold))
                    using (var bPct = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString(pcts[l] + "%", fPct, bPct, bx + bw + 10, ly);
                    }
                }

                // Terminal 1 footer: Real data
                using (var fFoot = new Font("Consolas", 8f, FontStyle.Regular))
                using (var bFoot = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("[SYNC] live metrics  //  264 contributions  //  Pro account", fFoot, bFoot, t1X + 24, 214);
                }

                // ================= RIGHT TERMINAL: REAL OPS LOG =================
                int t2X = 428, t2Y = 0, t2W = 412, t2H = h;
                using (var tBg = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(tBg, t2X, t2Y, t2W, t2H);
                }
                using (var tBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawRectangle(tBorder, t2X, t2Y, t2W - 1, t2H - 1);
                }
                using (var hBg = new SolidBrush(Color.FromArgb(15, 21, 32))) {
                    g.FillRectangle(hBg, t2X, t2Y, t2W, 28);
                }
                using (var hBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawLine(hBorder, t2X, t2Y + 28, t2X + t2W, t2Y + 28);
                }
                g.FillEllipse(new SolidBrush(Color.FromArgb(255, 95, 86)), t2X + 12, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(254, 188, 46)), t2X + 28, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(39, 201, 63)), t2X + 44, 9, 10, 10);
                using (var fTitle = new Font("Consolas", 9f, FontStyle.Regular))
                using (var bTitle = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("gokul@neural-core:~/ops $ tail -f activity.log", fTitle, bTitle, t2X + 64, 7);
                }

                // REAL REPOSITORY ACTIVITY (featuring Gokul A)
                string[] logs = new string[] {
                    "[09-08] Gokul A // Neural Core [main] (System Online)",
                    "[08-30] repo FaceTrack-AI (Computer Vision / FaceMesh)",
                    "[08-28] repo rootcause-iq (AI failure diagnostics)",
                    "[08-23] repo skillguard-oss 1* (agent audit engine)",
                    "[08-20] repo TRIVANA_CTF_WRITEUPS 1*",
                    "[08-15] repo CARBONX (emissions intelligence)",
                    "[08-10] repo ZeroDayHeist_CTF_Writeups (17 flags)",
                    "[08-04] repo Stock-Market-Predictor 1*"
                };

                using (var logFont = new Font("Consolas", 8.5f, FontStyle.Regular)) {
                    for (int m = 0; m < logs.Length; m++) {
                        int ly = 38 + m * 20;
                        Color textC = Color.FromArgb(148, 163, 184);
                        if (logs[m].Contains("Gokul A") || logs[m].Contains("FaceTrack")) textC = Color.FromArgb(0, 240, 255);
                        if (logs[m].Contains("rootcause") || logs[m].Contains("CARBONX")) textC = Color.FromArgb(167, 139, 250);
                        if (logs[m].Contains("1*") || logs[m].Contains("17 flags") || logs[m].Contains("Online")) textC = Color.FromArgb(56, 189, 248);

                        using (var bText = new SolidBrush(textC)) {
                            g.DrawString(logs[m], logFont, bText, t2X + 16, ly);
                        }
                    }

                    if ((int)(t * 6) % 2 == 0) {
                        using (var cursorBrush = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                            g.FillRectangle(cursorBrush, t2X + 16 + 325, 38 + 7 * 20, 7, 13);
                        }
                    }
                }

                using (var fFoot = new Font("Consolas", 8f, FontStyle.Regular))
                using (var bFoot = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                    g.DrawString("[OK] live stream  //  all 15 repositories public", fFoot, bFoot, t2X + 16, 214);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 7. REAL Contribution Scanner (Loaded with exact 366 days matrix)
    public static void RenderRealContrib(string outputPath, string matrixFile, int totalFrames = 26) {
        int w = 840, h = 180;
        var frames = new Bitmap[totalFrames];

        // Load real matrix
        int weeks = 53, days = 7;
        int[,] grid = new int[weeks, days];
        if (File.Exists(matrixFile)) {
            string content = File.ReadAllText(matrixFile);
            string[] cols = content.Split(';');
            for (int c = 0; c < Math.Min(weeks, cols.Length); c++) {
                string[] vals = cols[c].Split(',');
                for (int r = 0; r < Math.Min(days, vals.Length); r++) {
                    int val;
                    if (int.TryParse(vals[r], out val)) {
                        grid[c, r] = val;
                    }
                }
            }
        }

        Color[] tileColors = new Color[] {
            Color.FromArgb(15, 23, 34),   // 0: no commits
            Color.FromArgb(14, 68, 48),   // 1: low
            Color.FromArgb(16, 110, 70),  // 2: med
            Color.FromArgb(20, 160, 95),  // 3: high
            Color.FromArgb(0, 240, 150)   // 4: max
        };

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var brush = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }
                using (var pen = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                using (var hBg = new SolidBrush(Color.FromArgb(15, 21, 32))) {
                    g.FillRectangle(hBg, 0, 0, w, 28);
                }
                using (var hBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawLine(hBorder, 0, 28, w, 28);
                }
                g.FillEllipse(new SolidBrush(Color.FromArgb(255, 95, 86)), 12, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(254, 188, 46)), 28, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(39, 201, 63)), 44, 9, 10, 10);

                using (var fTitle = new Font("Consolas", 9f, FontStyle.Regular))
                using (var bTitle = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("~/contrib $ ./scan --year", fTitle, bTitle, 64, 7);
                }
                // REAL CONTRIBUTION COUNT: 264
                using (var fStat = new Font("Consolas", 9f, FontStyle.Bold))
                using (var bStat = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.DrawString("264 CONTRIBUTIONS // IN THE LAST YEAR", fStat, bStat, w - 325, 7);
                }

                string[] months = new string[] { "sep", "oct", "nov", "dec", "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug" };
                using (var mFont = new Font("Consolas", 8f, FontStyle.Regular))
                using (var mBrush = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    for (int mi = 0; mi < months.Length; mi++) {
                        g.DrawString(months[mi], mFont, mBrush, 55 + mi * 62, 36);
                    }
                }

                using (var dFont = new Font("Consolas", 8f, FontStyle.Regular))
                using (var dBrush = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("mon", dFont, dBrush, 22, 64);
                    g.DrawString("wed", dFont, dBrush, 22, 90);
                    g.DrawString("fri", dFont, dBrush, 22, 116);
                }

                int startX = 55, startY = 52, tileSize = 11, tileGap = 3;
                float laserX = startX + t * (weeks * (tileSize + tileGap));

                for (int x = 0; x < weeks; x++) {
                    int tx = startX + x * (tileSize + tileGap);
                    for (int y = 0; y < days; y++) {
                        int ty = startY + y * (tileSize + tileGap);
                        int level = grid[x, y];
                        Color col = tileColors[level];

                        float dist = Math.Abs(tx - laserX);
                        if (dist < 22f && level > 0) {
                            float boost = 1f - (dist / 22f);
                            int r = Math.Min(255, (int)(col.R + boost * 100));
                            int gr = Math.Min(255, (int)(col.G + boost * 150));
                            int b = Math.Min(255, (int)(col.B + boost * 120));
                            col = Color.FromArgb(r, gr, b);
                        }

                        using (var tileBrush = new SolidBrush(col)) {
                            g.FillRectangle(tileBrush, tx, ty, tileSize, tileSize);
                        }
                    }
                }

                int beamH = days * (tileSize + tileGap) + 4;
                using (var beamBrush = new LinearGradientBrush(
                    new RectangleF(laserX - 25, startY - 2, 50, beamH),
                    Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, Color.FromArgb(120, 0, 255, 170), Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    beamBrush.InterpolationColors = cb;
                    g.FillRectangle(beamBrush, laserX - 25, startY - 2, 50, beamH);
                }
                using (var laserLine = new Pen(Color.FromArgb(230, 216, 255, 240), 1.6f)) {
                    g.DrawLine(laserLine, laserX, startY - 4, laserX, startY + beamH + 2);
                }

                using (var lFont = new Font("Consolas", 8f, FontStyle.Regular))
                using (var lBrush = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("less", lFont, lBrush, w - 160, h - 22);
                    g.DrawString("more", lFont, lBrush, w - 46, h - 22);
                }
                for (int li = 0; li < 5; li++) {
                    using (var legBrush = new SolidBrush(tileColors[li])) {
                        g.FillRectangle(legBrush, w - 128 + li * 15, h - 22, 11, 11);
                    }
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 8. REAL Tech Stack Card
    public static void RenderRealStack(string outputPath, int totalFrames = 20) {
        int w = 840, h = 180;
        var frames = new Bitmap[totalFrames];

        string[] colTitles = new string[] { "01 // LANGUAGES", "02 // AI & DATA SCI", "03 // SECURITY & AUDIT", "04 // WEB & PLATFORMS" };
        string[][] colItems = new string[][] {
            new string[] { "Python 3.11+", "TypeScript", "JavaScript (ES6+)", "PowerShell / Bash" },
            new string[] { "TensorFlow / PyTorch", "Scikit-Learn", "Computer Vision (CV)", "Pandas & NumPy" },
            new string[] { "CTF Forensics & RE", "AST Static Analysis", "Capability Auditing", "Sandboxed Runtimes" },
            new string[] { "Next.js & React", "Node.js Runtimes", "REST & WebSockets", "Git & CI/CD Actions" }
        };
        Color[] colAccents = new Color[] {
            Color.FromArgb(0, 240, 255),
            Color.FromArgb(167, 139, 250),
            Color.FromArgb(56, 189, 248),
            Color.FromArgb(52, 211, 153)
        };

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var brush = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }
                using (var pen = new Pen(Color.FromArgb(24, 32, 45), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                int colW = 196, colH = 156;
                for (int c = 0; c < 4; c++) {
                    int cx = 14 + c * (colW + 8);
                    int cy = 12;

                    using (var cBg = new SolidBrush(Color.FromArgb(12, 17, 27))) {
                        g.FillRectangle(cBg, cx, cy, colW, colH);
                    }
                    using (var cBorder = new Pen(Color.FromArgb(28, 40, 58), 1f)) {
                        g.DrawRectangle(cBorder, cx, cy, colW, colH);
                    }

                    using (var cAccent = new SolidBrush(colAccents[c])) {
                        g.FillRectangle(cAccent, cx, cy, colW, 3);
                    }

                    using (var hFont = new Font("Consolas", 8.5f, FontStyle.Bold))
                    using (var hBrush = new SolidBrush(colAccents[c])) {
                        g.DrawString(colTitles[c], hFont, hBrush, cx + 8, cy + 12);
                    }

                    using (var sepPen = new Pen(Color.FromArgb(24, 34, 50), 1f)) {
                        g.DrawLine(sepPen, cx + 8, cy + 30, cx + colW - 8, cy + 30);
                    }

                    using (var itemFont = new Font("Segoe UI", 8.5f, FontStyle.Regular))
                    using (var itemBrush = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                        for (int r = 0; r < colItems[c].Length; r++) {
                            int ry = cy + 42 + r * 26;

                            float pulse = 0.5f + 0.5f * (float)Math.Sin((t + c * 0.25f + r * 0.2f) * Math.PI * 2f);
                            int alpha = (int)(pulse * 255);
                            using (var dotBr = new SolidBrush(Color.FromArgb(alpha, colAccents[c]))) {
                                g.FillEllipse(dotBr, cx + 10, ry + 4, 5, 5);
                            }

                            g.DrawString(colItems[c][r], itemFont, itemBrush, cx + 22, ry);
                        }
                    }
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 90);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing"

$assetsDir = "e:\Projects\Readme\assets"
if (!(Test-Path $assetsDir)) { New-Item -ItemType Directory -Path $assetsDir }

Write-Host "=========================================================="
Write-Host "Generating Upgraded Cyber GIF Suite for Gokul A"
Write-Host "=========================================================="

Write-Host "Rendering banner_work.gif..."
[RealAssetGenerator]::RenderBanner("$assetsDir\banner_work.gif", ">> SELECTED BUILDS", "// VERIFIED PRODUCTION REPOSITORIES", "[3 ACTIVE BUILDS]", [System.Drawing.Color]::FromArgb(0, 240, 255))

Write-Host "Loading 3D project images for FaceTrack-AI, skillguard-oss, and rootcause-iq..."
[RealAssetGenerator]::LoadProjectImages("$assetsDir\project_facetrack.jpg", "$assetsDir\project_skillguard.jpg", "$assetsDir\project_rootcause.jpg")

Write-Host "Rendering card_slam.gif (FaceTrack-AI Biometric HUD)..."
[RealAssetGenerator]::RenderCardFaceTrack("$assetsDir\card_slam.gif")

Write-Host "Rendering card_vision.gif (skillguard-oss Security Shield)..."
[RealAssetGenerator]::RenderCardSkillguard("$assetsDir\card_vision.gif")

Write-Host "Rendering card_mpc.gif (rootcause-iq Causal Trace)..."
[RealAssetGenerator]::RenderCardRootcause("$assetsDir\card_mpc.gif")

Write-Host "Rendering divider.gif (Gokul A // Autonomous Core)..."
[RealAssetGenerator]::RenderDivider("$assetsDir\divider.gif")

Write-Host "Rendering banner_telemetry.gif..."
[RealAssetGenerator]::RenderBanner("$assetsDir\banner_telemetry.gif", ">> LIVE TELEMETRY", "// REAL-TIME GITHUB AUDIT & ACTIVITY FEED", "[ONLINE]", [System.Drawing.Color]::FromArgb(56, 189, 248))

Write-Host "Rendering telemetry.gif (Gokul A Real Stats & Repo Log)..."
[RealAssetGenerator]::RenderTelemetry("$assetsDir\telemetry.gif")

Write-Host "Rendering contrib.gif (Real 264 Contributions & Matrix)..."
[RealAssetGenerator]::RenderRealContrib("$assetsDir\contrib.gif", "e:\Projects\Readme\real_contrib_matrix.txt")

Write-Host "Rendering banner_stack.gif..."
[RealAssetGenerator]::RenderBanner("$assetsDir\banner_stack.gif", ">> TECHNICAL ARSENAL", "// VERIFIED TOOLING & ARCHITECTURAL STACK", "[VERIFIED]", [System.Drawing.Color]::FromArgb(167, 139, 250))

Write-Host "Rendering stack.gif (Real Languages, AI, Security, Web)..."
[RealAssetGenerator]::RenderRealStack("$assetsDir\stack.gif")

Write-Host "Rendering banner_contact.gif..."
[RealAssetGenerator]::RenderBanner("$assetsDir\banner_contact.gif", ">> CONTROL UPLINK", "// SECURE COMMS & TRANSMISSION CHANNELS", "[ACTIVE]", [System.Drawing.Color]::FromArgb(0, 240, 255))

Write-Host "=========================================================="
Write-Host "All Cyber GIF assets for Gokul A rendered successfully!"
Get-ChildItem $assetsDir\*.gif | Select-Object Name, Length
