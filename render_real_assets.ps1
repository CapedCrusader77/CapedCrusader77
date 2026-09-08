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

    // Card 1: FaceTrack-AI (Superb Cyber Biometric Background)
    public static void RenderCardFaceTrack(string outputPath, int totalFrames = 24) {
        int w = 274, h = 188;
        Color accent = Color.FromArgb(0, 240, 255); // Cyan
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // 1. SOLID BLACK BASE
                using (var b = new SolidBrush(Color.FromArgb(4, 6, 10))) g.FillRectangle(b, 0, 0, w, h);

                // 2. SUPERB BACKGROUND IMAGE
                if (imgFaceTrack != null) {
                    int cropW = (int)(imgFaceTrack.Width * 0.75f);
                    int cropH = (int)(cropW * ((float)h / w));
                    int cropX = (imgFaceTrack.Width - cropW) / 2;
                    int cropY = (int)(imgFaceTrack.Height * 0.08f);

                    Rectangle srcRect = new Rectangle(cropX, cropY, cropW, cropH);
                    Rectangle dstRect = new Rectangle(2, 2, w - 4, h - 4);
                    g.DrawImage(imgFaceTrack, dstRect, srcRect, GraphicsUnit.Pixel);

                    // Glass overlay for extreme contrast and readability
                    using (var glassBrush = new LinearGradientBrush(
                        new Rectangle(0, 0, w, h),
                        Color.FromArgb(190, 6, 9, 15),
                        Color.FromArgb(225, 4, 6, 10),
                        90f)) {
                        g.FillRectangle(glassBrush, 2, 2, w - 4, h - 4);
                    }
                    // Radial cyan glow
                    using (var path = new GraphicsPath()) {
                        path.AddEllipse(w * 0.5f - 80, h * 0.4f - 60, 160, 120);
                        using (var pgb = new PathGradientBrush(path)) {
                            pgb.CenterColor = Color.FromArgb(35, accent.R, accent.G, accent.B);
                            pgb.SurroundColors = new Color[] { Color.Transparent };
                            g.FillPath(pgb, path);
                        }
                    }
                }

                // 3. CYBER FRAME & CORNER BRACKETS
                using (var p = new Pen(Color.FromArgb(80, accent.R, accent.G, accent.B), 1f)) g.DrawRectangle(p, 2, 2, w - 5, h - 5);
                DrawCornerBrackets(g, 2, 2, w - 4, h - 4, accent, 10f);

                // Top accent stripe with laser beam pulse
                using (var b = new SolidBrush(accent)) g.FillRectangle(b, 2, 2, w - 4, 3);
                float beamX = ((t * 1.5f) % 1.0f) * (w + 80) - 40;
                using (var brushBeam = new LinearGradientBrush(
                    new RectangleF(beamX - 30, 2, 60, 3), Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, Color.FromArgb(255, 255, 255, 255), Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    brushBeam.InterpolationColors = cb;
                    g.FillRectangle(brushBeam, beamX - 30, 2, 60, 3);
                }

                // 4. ROW 1: INDEX & TITLE
                using (var font = new Font("Consolas", 9.8f, FontStyle.Bold))
                using (var b = new SolidBrush(accent)) {
                    g.DrawString("01 // FACETRACK-AI", font, b, 12, 12);
                }

                // Status Pill
                float pulse = 0.65f + 0.35f * (float)Math.Sin(t * Math.PI * 2f);
                int dotA = (int)(255 * pulse);
                int pillW = 66, pillH = 18;
                int pillX = w - pillW - 12, pillY = 11;
                using (var bPill = new SolidBrush(Color.FromArgb(220, 6, 9, 16)))
                using (var pPill = new Pen(Color.FromArgb(120, accent.R, accent.G, accent.B), 1f))
                using (var bDot = new SolidBrush(Color.FromArgb(dotA, 52, 211, 153)))
                using (var fStatus = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var bStatusText = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                    g.FillRectangle(bPill, pillX, pillY, pillW, pillH);
                    g.DrawRectangle(pPill, pillX, pillY, pillW, pillH);
                    g.FillEllipse(bDot, pillX + 6, pillY + 6, 6, 6);
                    g.DrawString("ACTIVE", fStatus, bStatusText, pillX + 16, pillY + 3);
                }

                // Separator Line
                using (var p = new Pen(Color.FromArgb(60, 255, 255, 255), 1f)) g.DrawLine(p, 12, 34, w - 12, 34);

                // Headline (Pure White Bold)
                using (var font = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(255, 255, 255, 255))) {
                    g.DrawString("Real-time 6-DoF Perception Engine", font, b, 12, 40);
                }

                // Description (2 lines)
                using (var font = new Font("Segoe UI", 7.8f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                    g.DrawString("High-frequency 3D facial landmark mesh", font, b, 12, 60);
                    g.DrawString("Client WebAssembly tensor pipeline.", font, b, 12, 75);
                }

                // Telemetry Inset Box (Glass HUD Inset)
                int tx = 12, ty = 98, tw = w - 24, th = 48;
                using (var b = new SolidBrush(Color.FromArgb(225, 4, 7, 13))) g.FillRectangle(b, tx, ty, tw, th);
                using (var p = new Pen(Color.FromArgb(90, accent.R, accent.G, accent.B), 1f)) g.DrawRectangle(p, tx, ty, tw, th);
                DrawCornerBrackets(g, tx, ty, tw, th, accent, 5f);

                // Live Telemetry Readout
                float yaw = (float)Math.Sin(t * Math.PI * 2f) * 6f;
                using (var font = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var b = new SolidBrush(accent)) {
                    g.DrawString("TELEMETRY // 60 FPS | SIMD WASM", font, b, tx + 8, ty + 7);
                }
                using (var font = new Font("Consolas", 7.0f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString(String.Format("POSE: YAW {0:+0.0;-0.0}deg | LATENCY: 11.2ms", yaw), font, b, tx + 8, ty + 24);
                }

                // Animated traveling sensor indicator on right side of inset
                float radarCx = tx + tw - 20;
                float radarCy = ty + th / 2f;
                float radarRing = 4f + 8f * ((t * 2.0f) % 1.0f);
                int radarA = (int)(255 * (1f - ((t * 2.0f) % 1.0f)));
                using (var rp = new Pen(Color.FromArgb(radarA, accent), 1.2f))
                using (var rCenter = new SolidBrush(accent)) {
                    g.DrawEllipse(rp, radarCx - radarRing, radarCy - radarRing, radarRing * 2, radarRing * 2);
                    g.FillEllipse(rCenter, radarCx - 2.5f, radarCy - 2.5f, 5, 5);
                }

                // Footer Tags Row (y: 158)
                string[] tags = new string[] { "TypeScript", "WASM", "OpenCV" };
                float tagX = 12f;
                int tagY = 158;
                using (var tagFont = new Font("Consolas", 7f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        int bw = (int)sz.Width + 10;
                        int bh = 18;
                        using (var b = new SolidBrush(Color.FromArgb(220, 8, 12, 20))) g.FillRectangle(b, tagX, tagY, bw, bh);
                        using (var p = new Pen(Color.FromArgb(70, 148, 163, 184), 1f)) g.DrawRectangle(p, tagX, tagY, bw, bh);
                        using (var b = new SolidBrush(Color.FromArgb(224, 242, 254))) {
                            g.DrawString(tag, tagFont, b, tagX + 5, tagY + 3);
                        }
                        tagX += bw + 6f;
                    }
                }

                // Right Arrow
                using (var font = new Font("Consolas", 10f, FontStyle.Bold))
                using (var b = new SolidBrush(accent)) {
                    g.DrawString("->", font, b, w - 24, tagY + 1);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 60);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // Card 2: skillguard-oss (Superb Cyber Security Shield Background)
    public static void RenderCardSkillguard(string outputPath, int totalFrames = 24) {
        int w = 274, h = 188;
        Color accent = Color.FromArgb(167, 139, 250); // Violet
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // 1. SOLID BLACK BASE
                using (var b = new SolidBrush(Color.FromArgb(4, 6, 10))) g.FillRectangle(b, 0, 0, w, h);

                // 2. SUPERB BACKGROUND IMAGE
                if (imgSkillguard != null) {
                    int cropW = (int)(imgSkillguard.Width * 0.75f);
                    int cropH = (int)(cropW * ((float)h / w));
                    int cropX = (imgSkillguard.Width - cropW) / 2;
                    int cropY = (int)(imgSkillguard.Height * 0.08f);

                    Rectangle srcRect = new Rectangle(cropX, cropY, cropW, cropH);
                    Rectangle dstRect = new Rectangle(2, 2, w - 4, h - 4);
                    g.DrawImage(imgSkillguard, dstRect, srcRect, GraphicsUnit.Pixel);

                    // Glass overlay for extreme contrast and readability
                    using (var glassBrush = new LinearGradientBrush(
                        new Rectangle(0, 0, w, h),
                        Color.FromArgb(190, 8, 7, 18),
                        Color.FromArgb(225, 5, 4, 12),
                        90f)) {
                        g.FillRectangle(glassBrush, 2, 2, w - 4, h - 4);
                    }
                    // Radial violet glow
                    using (var path = new GraphicsPath()) {
                        path.AddEllipse(w * 0.5f - 80, h * 0.4f - 60, 160, 120);
                        using (var pgb = new PathGradientBrush(path)) {
                            pgb.CenterColor = Color.FromArgb(35, accent.R, accent.G, accent.B);
                            pgb.SurroundColors = new Color[] { Color.Transparent };
                            g.FillPath(pgb, path);
                        }
                    }
                }

                // 3. CYBER FRAME & CORNER BRACKETS
                using (var p = new Pen(Color.FromArgb(80, accent.R, accent.G, accent.B), 1f)) g.DrawRectangle(p, 2, 2, w - 5, h - 5);
                DrawCornerBrackets(g, 2, 2, w - 4, h - 4, accent, 10f);

                // Top accent stripe with laser beam pulse
                using (var b = new SolidBrush(accent)) g.FillRectangle(b, 2, 2, w - 4, 3);
                float beamX = ((t * 1.5f) % 1.0f) * (w + 80) - 40;
                using (var brushBeam = new LinearGradientBrush(
                    new RectangleF(beamX - 30, 2, 60, 3), Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, Color.FromArgb(255, 255, 255, 255), Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    brushBeam.InterpolationColors = cb;
                    g.FillRectangle(brushBeam, beamX - 30, 2, 60, 3);
                }

                // 4. ROW 1: INDEX & TITLE
                using (var font = new Font("Consolas", 9.8f, FontStyle.Bold))
                using (var b = new SolidBrush(accent)) {
                    g.DrawString("02 // SKILLGUARD-OSS", font, b, 12, 12);
                }

                // Status Pill
                float pulse = 0.65f + 0.35f * (float)Math.Sin((t + 0.33f) * Math.PI * 2f);
                int dotA = (int)(255 * pulse);
                int pillW = 66, pillH = 18;
                int pillX = w - pillW - 12, pillY = 11;
                using (var bPill = new SolidBrush(Color.FromArgb(220, 10, 8, 20)))
                using (var pPill = new Pen(Color.FromArgb(120, accent.R, accent.G, accent.B), 1f))
                using (var bDot = new SolidBrush(Color.FromArgb(dotA, accent)))
                using (var fStatus = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var bStatusText = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                    g.FillRectangle(bPill, pillX, pillY, pillW, pillH);
                    g.DrawRectangle(pPill, pillX, pillY, pillW, pillH);
                    g.FillEllipse(bDot, pillX + 6, pillY + 6, 6, 6);
                    g.DrawString("ACTIVE", fStatus, bStatusText, pillX + 16, pillY + 3);
                }

                // Separator Line
                using (var p = new Pen(Color.FromArgb(60, 255, 255, 255), 1f)) g.DrawLine(p, 12, 34, w - 12, 34);

                // Headline (Pure White Bold)
                using (var font = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(255, 255, 255, 255))) {
                    g.DrawString("Zero-Trust Security Audit", font, b, 12, 40);
                }

                // Description (2 lines)
                using (var font = new Font("Segoe UI", 7.8f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                    g.DrawString("Static AST capability inspection engine", font, b, 12, 60);
                    g.DrawString("Sandbox boundaries & permission guards.", font, b, 12, 75);
                }

                // Telemetry Inset Box (Glass HUD Inset)
                int tx = 12, ty = 98, tw = w - 24, th = 48;
                using (var b = new SolidBrush(Color.FromArgb(225, 7, 5, 15))) g.FillRectangle(b, tx, ty, tw, th);
                using (var p = new Pen(Color.FromArgb(90, accent.R, accent.G, accent.B), 1f)) g.DrawRectangle(p, tx, ty, tw, th);
                DrawCornerBrackets(g, tx, ty, tw, th, accent, 5f);

                // Live Telemetry Readout
                using (var font = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var b = new SolidBrush(accent)) {
                    g.DrawString("SECURITY AUDIT // 4,820 AST NODES", font, b, tx + 8, ty + 7);
                }
                using (var font = new Font("Consolas", 7.0f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString("POLICY: STRICT | PERMISSIONS: PASS", font, b, tx + 8, ty + 24);
                }

                // Animated shield indicator on right side of inset
                float sx = tx + tw - 20;
                float sy = ty + th / 2f;
                PointF[] shield = new PointF[] {
                    new PointF(sx - 8, sy - 8), new PointF(sx + 8, sy - 8),
                    new PointF(sx + 8, sy + 2), new PointF(sx, sy + 10), new PointF(sx - 8, sy + 2)
                };
                using (var sp = new Pen(accent, 1.3f)) g.DrawPolygon(sp, shield);
                float shieldPing = 4f + 8f * ((t * 2.0f) % 1.0f);
                int shieldA = (int)(255 * (1f - ((t * 2.0f) % 1.0f)));
                using (var spGlow = new Pen(Color.FromArgb(shieldA, accent), 1.0f)) {
                    g.DrawEllipse(spGlow, sx - shieldPing, sy - shieldPing, shieldPing * 2, shieldPing * 2);
                }

                // Footer Tags Row (y: 158)
                string[] tags = new string[] { "TypeScript", "AST", "Security" };
                float tagX = 12f;
                int tagY = 158;
                using (var tagFont = new Font("Consolas", 7f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        int bw = (int)sz.Width + 10;
                        int bh = 18;
                        using (var b = new SolidBrush(Color.FromArgb(220, 14, 10, 24))) g.FillRectangle(b, tagX, tagY, bw, bh);
                        using (var p = new Pen(Color.FromArgb(70, accent.R, accent.G, accent.B), 1f)) g.DrawRectangle(p, tagX, tagY, bw, bh);
                        using (var b = new SolidBrush(Color.FromArgb(243, 232, 255))) {
                            g.DrawString(tag, tagFont, b, tagX + 5, tagY + 3);
                        }
                        tagX += bw + 6f;
                    }
                }

                // Right Arrow
                using (var font = new Font("Consolas", 10f, FontStyle.Bold))
                using (var b = new SolidBrush(accent)) {
                    g.DrawString("->", font, b, w - 24, tagY + 1);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 60);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // Card 3: rootcause-iq (Superb Quantum Compute Causal Graph Background)
    public static void RenderCardRootcause(string outputPath, int totalFrames = 24) {
        int w = 274, h = 188;
        Color accent = Color.FromArgb(56, 189, 248); // Sky Blue
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // 1. SOLID BLACK BASE
                using (var b = new SolidBrush(Color.FromArgb(4, 6, 10))) g.FillRectangle(b, 0, 0, w, h);

                // 2. SUPERB BACKGROUND IMAGE
                if (imgRootcause != null) {
                    int cropW = (int)(imgRootcause.Width * 0.75f);
                    int cropH = (int)(cropW * ((float)h / w));
                    int cropX = (imgRootcause.Width - cropW) / 2;
                    int cropY = (int)(imgRootcause.Height * 0.08f);

                    Rectangle srcRect = new Rectangle(cropX, cropY, cropW, cropH);
                    Rectangle dstRect = new Rectangle(2, 2, w - 4, h - 4);
                    g.DrawImage(imgRootcause, dstRect, srcRect, GraphicsUnit.Pixel);

                    // Glass overlay for extreme contrast and readability
                    using (var glassBrush = new LinearGradientBrush(
                        new Rectangle(0, 0, w, h),
                        Color.FromArgb(190, 5, 8, 16),
                        Color.FromArgb(225, 3, 5, 11),
                        90f)) {
                        g.FillRectangle(glassBrush, 2, 2, w - 4, h - 4);
                    }
                    // Radial sky blue glow
                    using (var path = new GraphicsPath()) {
                        path.AddEllipse(w * 0.5f - 80, h * 0.4f - 60, 160, 120);
                        using (var pgb = new PathGradientBrush(path)) {
                            pgb.CenterColor = Color.FromArgb(35, accent.R, accent.G, accent.B);
                            pgb.SurroundColors = new Color[] { Color.Transparent };
                            g.FillPath(pgb, path);
                        }
                    }
                }

                // 3. CYBER FRAME & CORNER BRACKETS
                using (var p = new Pen(Color.FromArgb(80, accent.R, accent.G, accent.B), 1f)) g.DrawRectangle(p, 2, 2, w - 5, h - 5);
                DrawCornerBrackets(g, 2, 2, w - 4, h - 4, accent, 10f);

                // Top accent stripe with laser beam pulse
                using (var b = new SolidBrush(accent)) g.FillRectangle(b, 2, 2, w - 4, 3);
                float beamX = ((t * 1.5f) % 1.0f) * (w + 80) - 40;
                using (var brushBeam = new LinearGradientBrush(
                    new RectangleF(beamX - 30, 2, 60, 3), Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, Color.FromArgb(255, 255, 255, 255), Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    brushBeam.InterpolationColors = cb;
                    g.FillRectangle(brushBeam, beamX - 30, 2, 60, 3);
                }

                // 4. ROW 1: INDEX & TITLE
                using (var font = new Font("Consolas", 9.8f, FontStyle.Bold))
                using (var b = new SolidBrush(accent)) {
                    g.DrawString("03 // ROOTCAUSE-IQ", font, b, 12, 12);
                }

                // Status Pill
                float pulse = 0.65f + 0.35f * (float)Math.Sin((t + 0.66f) * Math.PI * 2f);
                int dotA = (int)(255 * pulse);
                int pillW = 66, pillH = 18;
                int pillX = w - pillW - 12, pillY = 11;
                using (var bPill = new SolidBrush(Color.FromArgb(220, 6, 12, 18)))
                using (var pPill = new Pen(Color.FromArgb(120, accent.R, accent.G, accent.B), 1f))
                using (var bDot = new SolidBrush(Color.FromArgb(dotA, accent)))
                using (var fStatus = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var bStatusText = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                    g.FillRectangle(bPill, pillX, pillY, pillW, pillH);
                    g.DrawRectangle(pPill, pillX, pillY, pillW, pillH);
                    g.FillEllipse(bDot, pillX + 6, pillY + 6, 6, 6);
                    g.DrawString("ONLINE", fStatus, bStatusText, pillX + 16, pillY + 3);
                }

                // Separator Line
                using (var p = new Pen(Color.FromArgb(60, 255, 255, 255), 1f)) g.DrawLine(p, 12, 34, w - 12, 34);

                // Headline (Pure White Bold)
                using (var font = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(255, 255, 255, 255))) {
                    g.DrawString("Automated Diagnostic Engine", font, b, 12, 40);
                }

                // Description (2 lines)
                using (var font = new Font("Segoe UI", 7.8f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                    g.DrawString("Full-stack trace graph reconstruction", font, b, 12, 60);
                    g.DrawString("Deterministic root-cause localization.", font, b, 12, 75);
                }

                // Telemetry Inset Box (Glass HUD Inset)
                int tx = 12, ty = 98, tw = w - 24, th = 48;
                using (var b = new SolidBrush(Color.FromArgb(225, 4, 8, 14))) g.FillRectangle(b, tx, ty, tw, th);
                using (var p = new Pen(Color.FromArgb(90, accent.R, accent.G, accent.B), 1f)) g.DrawRectangle(p, tx, ty, tw, th);
                DrawCornerBrackets(g, tx, ty, tw, th, accent, 5f);

                // Live Telemetry Readout
                using (var font = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var b = new SolidBrush(accent)) {
                    g.DrawString("CAUSAL GRAPH // 142 NODES | 89ms", font, b, tx + 8, ty + 7);
                }
                using (var font = new Font("Consolas", 7.0f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString("STATE: ROOT LOCATED | TRACE: 99.4%", font, b, tx + 8, ty + 24);
                }

                // Animated graph node indicator on right side of inset
                float gx = tx + tw - 20;
                float gy = ty + th / 2f;
                using (var gp = new Pen(Color.FromArgb(120, accent.R, accent.G, accent.B), 1.2f)) {
                    g.DrawLine(gp, gx - 8, gy + 5, gx, gy - 6);
                    g.DrawLine(gp, gx, gy - 6, gx + 8, gy + 5);
                    g.DrawLine(gp, gx - 8, gy + 5, gx + 8, gy + 5);
                }
                using (var gb = new SolidBrush(accent)) {
                    g.FillEllipse(gb, gx - 10, gy + 3, 4, 4);
                    g.FillEllipse(gb, gx - 2, gy - 8, 4, 4);
                    g.FillEllipse(gb, gx + 6, gy + 3, 4, 4);
                }
                float graphPing = 4f + 8f * ((t * 2.0f) % 1.0f);
                int graphA = (int)(255 * (1f - ((t * 2.0f) % 1.0f)));
                using (var gpGlow = new Pen(Color.FromArgb(graphA, accent), 1.0f)) {
                    g.DrawEllipse(gpGlow, gx - graphPing, gy - graphPing, graphPing * 2, graphPing * 2);
                }

                // Footer Tags Row (y: 158)
                string[] tags = new string[] { "Python", "Causal AI", "Next.js" };
                float tagX = 12f;
                int tagY = 158;
                using (var tagFont = new Font("Consolas", 7f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        int bw = (int)sz.Width + 10;
                        int bh = 18;
                        using (var b = new SolidBrush(Color.FromArgb(220, 6, 12, 20))) g.FillRectangle(b, tagX, tagY, bw, bh);
                        using (var p = new Pen(Color.FromArgb(70, accent.R, accent.G, accent.B), 1f)) g.DrawRectangle(p, tagX, tagY, bw, bh);
                        using (var b = new SolidBrush(Color.FromArgb(224, 242, 254))) {
                            g.DrawString(tag, tagFont, b, tagX + 5, tagY + 3);
                        }
                        tagX += bw + 6f;
                    }
                }

                // Right Arrow
                using (var font = new Font("Consolas", 10f, FontStyle.Bold))
                using (var b = new SolidBrush(accent)) {
                    g.DrawString("->", font, b, w - 24, tagY + 1);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 60);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // Divider matching repo
    public static void RenderDivider(string outputPath, int totalFrames = 20) {
        int w = 840, h = 24;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float progress = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var brush = new SolidBrush(Color.FromArgb(0, 0, 0))) g.FillRectangle(brush, 0, 0, w, h);

                // Base line
                using (var linePen = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawLine(linePen, 0, h / 2, w, h / 2);
                }

                // Traveling pulse dots on line
                float pX1 = (progress * (w + 200)) - 100;
                using (var pBrush = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                    g.FillEllipse(pBrush, pX1, h / 2 - 2, 4, 4);
                }

                // Center badge
                int bw = 270, bh = 18;
                int bx = (w - bw) / 2;
                int by = (h - bh) / 2;
                using (var bgBrush = new SolidBrush(Color.FromArgb(10, 14, 22))) {
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
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
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

Write-Host "Rendering banner_work.gif (SELECTED BUILDS)..."
[RealAssetGenerator]::RenderBanner("$assetsDir\banner_work.gif", ">> SELECTED BUILDS", "// 3 AUTONOMOUS PRODUCTION SYSTEMS", "[ACTIVE BUILDS]", [System.Drawing.Color]::FromArgb(0, 240, 255))

Write-Host "Rendering modern project cards (FaceTrack-AI, SkillGuard-OSS, RootCause-IQ)..."
& "$PSScriptRoot\render_new_cards.ps1"

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
