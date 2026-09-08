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

    // 2. Horizontal Project Card 1: FaceTrack-AI (Cyber Biometric Vision)
    public static void RenderCardFaceTrack(string outputPath, int totalFrames = 24) {
        int w = 274, h = 280;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(0, 240, 255); // Cyan

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Pure Black Canvas
                using (var brush = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }

                // Attractive Cyber Ambient Gradient Background
                using (var gradBrush = new LinearGradientBrush(
                    new Rectangle(0, 0, w, h),
                    Color.FromArgb(6, 18, 30), Color.FromArgb(1, 3, 6), 90f)) {
                    g.FillRectangle(gradBrush, 0, 0, w, h);
                }

                // Cyber Circuit / Perspective Grid Lines on Background
                using (var bgPen = new Pen(Color.FromArgb(18, 32, 48), 1f)) {
                    for (int gy = 40; gy < h; gy += 24) {
                        g.DrawLine(bgPen, 0, gy, w, gy);
                    }
                    for (int gx = 16; gx < w; gx += 32) {
                        g.DrawLine(bgPen, gx, 0, gx, h);
                    }
                }

                // Floating ambient cyber micro-particles
                for (int p = 0; p < 6; p++) {
                    float px = (p * 45f + (float)Math.Sin(t * Math.PI * 2f + p) * 12f) % w;
                    float py = 30f + ((p * 42f + t * 50f) % (h - 60f));
                    int alpha = (int)(40 + 35 * Math.Sin(t * Math.PI * 2f + p));
                    using (var pBrush = new SolidBrush(Color.FromArgb(alpha, 0, 240, 255))) {
                        g.FillEllipse(pBrush, px, py, 2.5f, 2.5f);
                    }
                }

                // Outer Cyber Border
                using (var pen = new Pen(Color.FromArgb(28, 44, 64), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // Left Accent Stripe
                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 3, h);
                }

                // Top Traveling Laser Beam
                float beamX = t * (w + 60) - 30;
                using (var beamBrush = new LinearGradientBrush(
                    new RectangleF(beamX - 35, 0, 70, 2),
                    Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, accent, Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    beamBrush.InterpolationColors = cb;
                    g.FillRectangle(beamBrush, beamX - 35, 0, 70, 2);
                }

                // Top Header: Index & Status Badge
                using (var font = new Font("Consolas", 10f, FontStyle.Bold))
                using (var brush = new SolidBrush(accent)) {
                    g.DrawString("01 // VISION_AI", font, brush, 14, 11);
                }
                using (var stFont = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(14, 30, 46)))
                using (var stBorder = new Pen(Color.FromArgb(0, 200, 220), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                    g.FillRectangle(stBg, w - 110, 10, 98, 17);
                    g.DrawRectangle(stBorder, w - 110, 10, 98, 17);
                    g.DrawString("[60 FPS // RT]", stFont, stText, w - 102, 12);
                }

                // Viewport Container (Cyber Biometric HUD)
                int vpX = 12, vpY = 34, vpW = w - 24, vpH = 106;
                using (var vpBg = new SolidBrush(Color.FromArgb(2, 6, 12))) {
                    g.FillRectangle(vpBg, vpX, vpY, vpW, vpH);
                }
                using (var vpPen = new Pen(Color.FromArgb(22, 36, 52), 1f)) {
                    g.DrawRectangle(vpPen, vpX, vpY, vpW, vpH);
                }
                DrawCornerBrackets(g, vpX, vpY, vpW, vpH, accent, 7f);

                // High-Tech Perspective Wireframe in Viewport
                using (var gridPen = new Pen(Color.FromArgb(16, 28, 44), 1f)) {
                    for (int gx = vpX + 16; gx < vpX + vpW; gx += 22) g.DrawLine(gridPen, gx, vpY, gx, vpY + vpH);
                    for (int gy = vpY + 14; gy < vpY + vpH; gy += 18) g.DrawLine(gridPen, vpX, gy, vpX + vpW, gy);
                }

                // Expanding Biometric Sonar Pulse
                float sonarR = 15f + ((t * 1.5f) % 1f) * 40f;
                int sonarAlpha = Math.Max(0, (int)((1f - ((t * 1.5f) % 1f)) * 120));
                using (var sonarPen = new Pen(Color.FromArgb(sonarAlpha, 0, 240, 255), 1.2f)) {
                    g.DrawEllipse(sonarPen, vpX + vpW / 2f - sonarR, vpY + vpH / 2f - sonarR, sonarR * 2, sonarR * 2);
                }

                // Animated 6-DoF Biometric FaceMesh
                float yaw = (float)Math.Sin(t * Math.PI * 2f) * 10f;
                float pitch = (float)Math.Cos(t * Math.PI * 2f) * 5f;
                float fcX = vpX + vpW / 2f + (yaw * 0.9f);
                float fcY = vpY + vpH / 2f + (pitch * 0.7f);

                // Multi-point Landmark Triangulation
                PointF[] pts = new PointF[] {
                    new PointF(fcX - 28, fcY - 26), // Top-left brow
                    new PointF(fcX + 28, fcY - 26), // Top-right brow
                    new PointF(fcX - 16, fcY - 12), // Left Eye
                    new PointF(fcX + 16, fcY - 12), // Right Eye
                    new PointF(fcX, fcY + 2),       // Nose bridge
                    new PointF(fcX - 14, fcY + 18), // Left mouth
                    new PointF(fcX + 14, fcY + 18), // Right mouth
                    new PointF(fcX, fcY + 30)       // Chin
                };

                // Triangulation wires
                using (var meshPen = new Pen(Color.FromArgb(85, 0, 240, 255), 1.2f)) {
                    g.DrawLine(meshPen, pts[0], pts[1]);
                    g.DrawLine(meshPen, pts[0], pts[2]);
                    g.DrawLine(meshPen, pts[1], pts[3]);
                    g.DrawLine(meshPen, pts[2], pts[3]);
                    g.DrawLine(meshPen, pts[2], pts[4]);
                    g.DrawLine(meshPen, pts[3], pts[4]);
                    g.DrawLine(meshPen, pts[4], pts[5]);
                    g.DrawLine(meshPen, pts[4], pts[6]);
                    g.DrawLine(meshPen, pts[5], pts[6]);
                    g.DrawLine(meshPen, pts[5], pts[7]);
                    g.DrawLine(meshPen, pts[6], pts[7]);
                }

                // Glowing landmark nodes
                foreach (var pt in pts) {
                    using (var ptBrush = new SolidBrush(Color.FromArgb(230, 0, 240, 255))) {
                        g.FillEllipse(ptBrush, pt.X - 2.2f, pt.Y - 2.2f, 4.4f, 4.4f);
                    }
                }

                // Center Reticle
                DrawCornerBrackets(g, fcX - 36, fcY - 34, 72, 68, Color.FromArgb(160, 0, 240, 255), 8f);

                // Vertical laser scanline
                float scanY = vpY + 4 + (t * (vpH - 8));
                using (var scanBrush = new LinearGradientBrush(
                    new RectangleF(vpX + 4, scanY - 3, vpW - 8, 6),
                    Color.Transparent, Color.FromArgb(140, 0, 240, 255), 90f)) {
                    g.FillRectangle(scanBrush, vpX + 4, scanY - 3, vpW - 8, 6);
                }
                using (var scanPen = new Pen(Color.FromArgb(220, 255, 255, 255), 1f)) {
                    g.DrawLine(scanPen, vpX + 6, scanY, vpX + vpW - 6, scanY);
                }

                // Viewport Top & Bottom Labels
                using (var hudFont = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var hudText = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                    g.DrawString("MESH_ID: #468", hudFont, hudText, vpX + 6, vpY + 4);
                    g.DrawString(string.Format("YAW {0:+00;-00} DEG", yaw), hudFont, hudText, vpX + vpW - 74, vpY + 4);
                    g.DrawString("LOCK: 99.8% // ACTIVE", hudFont, hudText, vpX + 6, vpY + vpH - 12);
                }

                // --- CONTENT AREA ---
                // Title
                using (var titleFont = new Font("Consolas", 12.5f, FontStyle.Bold))
                using (var titleBrush = new SolidBrush(Color.FromArgb(245, 248, 252))) {
                    g.DrawString("FACETRACK_AI", titleFont, titleBrush, 14, 148);
                }

                // Subtitle
                using (var subFont = new Font("Segoe UI", 8.8f, FontStyle.Bold))
                using (var subBrush = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                    g.DrawString("Real-time CV & 6-DoF FaceMesh", subFont, subBrush, 14, 170);
                }

                // Description
                using (var descFont = new Font("Segoe UI", 8.0f, FontStyle.Regular))
                using (var descBrush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("High-frequency perception pipeline with\nfacial mesh tracking & client tensor inference.", descFont, descBrush, 14, 190);
                }

                // Tech Tags
                string[] tags = new string[] { "TypeScript", "CV", "TF.js" };
                float tagX = 14;
                using (var tagFont = new Font("Consolas", 7.8f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        using (var bgBrush = new SolidBrush(Color.FromArgb(14, 24, 38))) {
                            g.FillRectangle(bgBrush, tagX, 230, sz.Width + 8, 18);
                        }
                        using (var borderPen = new Pen(Color.FromArgb(32, 52, 74), 1f)) {
                            g.DrawRectangle(borderPen, tagX, 230, sz.Width + 8, 18);
                        }
                        using (var textBrush = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                            g.DrawString(tag, tagFont, textBrush, tagX + 4, 232);
                        }
                        tagX += sz.Width + 12;
                    }
                }

                // Bottom Footer Telemetry
                using (var linePen = new Pen(Color.FromArgb(24, 38, 56), 1f)) {
                    g.DrawLine(linePen, 12, 256, w - 12, 256);
                }
                using (var footFont = new Font("Consolas", 7.5f, FontStyle.Bold)) {
                    using (var dotBrush = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                        g.FillEllipse(dotBrush, 14, 263, 6, 6);
                    }
                    using (var footText = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString("60 FPS // CONF: 99.8% // 1.2ms", footFont, footText, 25, 260);
                    }
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 3. Horizontal Project Card 2: skillguard-oss (Cyber Security Command Node)
    public static void RenderCardSkillguard(string outputPath, int totalFrames = 24) {
        int w = 274, h = 280;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(139, 92, 246); // Electric Violet

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Pure Black Canvas
                using (var brush = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }

                // Attractive Cyber Ambient Gradient Background
                using (var gradBrush = new LinearGradientBrush(
                    new Rectangle(0, 0, w, h),
                    Color.FromArgb(22, 10, 36), Color.FromArgb(2, 1, 4), 90f)) {
                    g.FillRectangle(gradBrush, 0, 0, w, h);
                }

                // Hexagonal Cyber Honeycomb Pattern in Background
                using (var hexPen = new Pen(Color.FromArgb(26, 16, 42), 1f)) {
                    for (int hy = 20; hy < h; hy += 26) {
                        for (int hx = 10; hx < w; hx += 32) {
                            float offX = ((hy / 26) % 2 == 0) ? 0 : 16;
                            g.DrawPolygon(hexPen, new PointF[] {
                                new PointF(hx + offX, hy - 7),
                                new PointF(hx + offX + 7, hy - 3),
                                new PointF(hx + offX + 7, hy + 5),
                                new PointF(hx + offX, hy + 9),
                                new PointF(hx + offX - 7, hy + 5),
                                new PointF(hx + offX - 7, hy - 3)
                            });
                        }
                    }
                }

                // Outer Cyber Border
                using (var pen = new Pen(Color.FromArgb(42, 28, 62), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // Left Accent Stripe
                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 3, h);
                }

                // Top Traveling Laser Beam
                float beamX = t * (w + 60) - 30;
                using (var beamBrush = new LinearGradientBrush(
                    new RectangleF(beamX - 35, 0, 70, 2),
                    Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, accent, Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    beamBrush.InterpolationColors = cb;
                    g.FillRectangle(beamBrush, beamX - 35, 0, 70, 2);
                }

                // Top Header: Index & Status Badge (Clean ASCII)
                using (var font = new Font("Consolas", 10f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(167, 139, 250))) {
                    g.DrawString("02 // SECURITY", font, brush, 14, 11);
                }
                using (var stFont = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(32, 18, 50)))
                using (var stBorder = new Pen(Color.FromArgb(167, 139, 250), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(192, 132, 252))) {
                    g.FillRectangle(stBg, w - 110, 10, 98, 17);
                    g.DrawRectangle(stBorder, w - 110, 10, 98, 17);
                    g.DrawString("[1* // OSS AUDIT]", stFont, stText, w - 105, 12);
                }

                // Viewport Container (Cyber Animation)
                int vpX = 12, vpY = 34, vpW = w - 24, vpH = 106;
                using (var vpBg = new SolidBrush(Color.FromArgb(10, 5, 18))) {
                    g.FillRectangle(vpBg, vpX, vpY, vpW, vpH);
                }
                using (var vpPen = new Pen(Color.FromArgb(38, 24, 58), 1f)) {
                    g.DrawRectangle(vpPen, vpX, vpY, vpW, vpH);
                }
                DrawCornerBrackets(g, vpX, vpY, vpW, vpH, accent, 7f);

                // Holographic Cyber Security Shield Crest
                float scX = vpX + vpW / 2f;
                float scY = vpY + vpH / 2f;
                float shieldPulse = 0.7f + 0.3f * (float)Math.Sin(t * Math.PI * 2f);

                // Hexagonal Outer Forcefield
                PointF[] hexPts = new PointF[6];
                float hexR = 34f + (shieldPulse * 3f);
                for (int k = 0; k < 6; k++) {
                    double ang = k * Math.PI / 3.0;
                    hexPts[k] = new PointF(scX + (float)(Math.Cos(ang) * hexR), scY + (float)(Math.Sin(ang) * hexR));
                }
                using (var hPen = new Pen(Color.FromArgb(80, 167, 139, 250), 1.2f)) {
                    g.DrawPolygon(hPen, hexPts);
                }

                // Inner Shield Contour
                PointF[] sPts = new PointF[] {
                    new PointF(scX - 22, scY - 24),
                    new PointF(scX + 22, scY - 24),
                    new PointF(scX + 18, scY + 6),
                    new PointF(scX, scY + 26),
                    new PointF(scX - 18, scY + 6)
                };
                using (var sPen = new Pen(Color.FromArgb(200, 192, 132, 252), 1.5f)) {
                    g.DrawPolygon(sPen, sPts);
                }

                // Center Pulsing Energy Core
                using (var coreBrush = new SolidBrush(Color.FromArgb((int)(shieldPulse * 220), 192, 132, 252))) {
                    g.FillEllipse(coreBrush, scX - 8, scY - 8, 16, 16);
                }
                using (var corePen = new Pen(Color.FromArgb(255, 255, 255, 255), 1.2f)) {
                    g.DrawEllipse(corePen, scX - 8, scY - 8, 16, 16);
                }

                // Sweeping violet laser scanline
                float scanY = vpY + 4 + (t * (vpH - 8));
                using (var scanBrush = new LinearGradientBrush(
                    new RectangleF(vpX + 4, scanY - 3, vpW - 8, 6),
                    Color.Transparent, Color.FromArgb(140, 139, 92, 246), 90f)) {
                    g.FillRectangle(scanBrush, vpX + 4, scanY - 3, vpW - 8, 6);
                }
                using (var scanPen = new Pen(Color.FromArgb(230, 240, 230, 255), 1f)) {
                    g.DrawLine(scanPen, vpX + 6, scanY, vpX + vpW - 6, scanY);
                }

                // Viewport Top & Bottom Labels
                using (var hudFont = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var hudText = new SolidBrush(Color.FromArgb(221, 214, 254))) {
                    g.DrawString("AST_PARSER // SECURE", hudFont, hudText, vpX + 6, vpY + 4);
                    g.DrawString("VULN: 0", hudFont, hudText, vpX + vpW - 54, vpY + 4);
                    g.DrawString("GUARD: 100% // VERIFIED", hudFont, hudText, vpX + 6, vpY + vpH - 12);
                }

                // --- CONTENT AREA ---
                // Title
                using (var titleFont = new Font("Consolas", 12.5f, FontStyle.Bold))
                using (var titleBrush = new SolidBrush(Color.FromArgb(245, 248, 252))) {
                    g.DrawString("SKILLGUARD_OSS", titleFont, titleBrush, 14, 148);
                }

                // Subtitle
                using (var subFont = new Font("Segoe UI", 8.8f, FontStyle.Bold))
                using (var subBrush = new SolidBrush(Color.FromArgb(167, 139, 250))) {
                    g.DrawString("AI Agent Security & AST Audit", subFont, subBrush, 14, 170);
                }

                // Description
                using (var descFont = new Font("Segoe UI", 8.0f, FontStyle.Regular))
                using (var descBrush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Automated capability audit engine analyzing\nAST syntaxes, sandboxes & permission guards.", descFont, descBrush, 14, 190);
                }

                // Tech Tags
                string[] tags = new string[] { "Python", "AST", "Security" };
                float tagX = 14;
                using (var tagFont = new Font("Consolas", 7.8f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        using (var bgBrush = new SolidBrush(Color.FromArgb(26, 16, 40))) {
                            g.FillRectangle(bgBrush, tagX, 230, sz.Width + 8, 18);
                        }
                        using (var borderPen = new Pen(Color.FromArgb(56, 38, 82), 1f)) {
                            g.DrawRectangle(borderPen, tagX, 230, sz.Width + 8, 18);
                        }
                        using (var textBrush = new SolidBrush(Color.FromArgb(221, 214, 254))) {
                            g.DrawString(tag, tagFont, textBrush, tagX + 4, 232);
                        }
                        tagX += sz.Width + 12;
                    }
                }

                // Bottom Footer Telemetry
                using (var linePen = new Pen(Color.FromArgb(40, 26, 56), 1f)) {
                    g.DrawLine(linePen, 12, 256, w - 12, 256);
                }
                using (var footFont = new Font("Consolas", 7.5f, FontStyle.Bold)) {
                    using (var dotBrush = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                        g.FillEllipse(dotBrush, 14, 263, 6, 6);
                    }
                    using (var footText = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString("SANDBOX: ACTIVE // VULN: 0 // PASS", footFont, footText, 25, 260);
                    }
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 4. Horizontal Project Card 3: rootcause-iq (Enterprise Causal Trace)
    public static void RenderCardRootcause(string outputPath, int totalFrames = 24) {
        int w = 274, h = 280;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(56, 189, 248); // Sky Blue

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Pure Black Canvas
                using (var brush = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }

                // Attractive Cyber Ambient Gradient Background
                using (var gradBrush = new LinearGradientBrush(
                    new Rectangle(0, 0, w, h),
                    Color.FromArgb(6, 20, 32), Color.FromArgb(1, 4, 8), 90f)) {
                    g.FillRectangle(gradBrush, 0, 0, w, h);
                }

                // High-Tech PCB Circuit Board Traces in Background
                using (var pcbPen = new Pen(Color.FromArgb(18, 38, 58), 1f)) {
                    g.DrawLine(pcbPen, 20, 50, 80, 50);
                    g.DrawLine(pcbPen, 80, 50, 110, 80);
                    g.DrawLine(pcbPen, 110, 80, 200, 80);
                    g.DrawLine(pcbPen, 200, 80, 240, 120);

                    g.DrawLine(pcbPen, 30, 210, 100, 210);
                    g.DrawLine(pcbPen, 100, 210, 130, 240);
                    g.DrawLine(pcbPen, 130, 240, 230, 240);
                }
                // Traveling circuit pulse beads
                float pulseX1 = 20 + ((t * 180f) % 180f);
                using (var dotB = new SolidBrush(Color.FromArgb(120, 56, 189, 248))) {
                    g.FillEllipse(dotB, pulseX1, 50 - 2, 4, 4);
                }

                // Outer Cyber Border
                using (var pen = new Pen(Color.FromArgb(28, 46, 68), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // Left Accent Stripe
                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 3, h);
                }

                // Top Traveling Laser Beam
                float beamX = t * (w + 60) - 30;
                using (var beamBrush = new LinearGradientBrush(
                    new RectangleF(beamX - 35, 0, 70, 2),
                    Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, accent, Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    beamBrush.InterpolationColors = cb;
                    g.FillRectangle(beamBrush, beamX - 35, 0, 70, 2);
                }

                // Top Header: Index & Status Badge
                using (var font = new Font("Consolas", 10f, FontStyle.Bold))
                using (var brush = new SolidBrush(accent)) {
                    g.DrawString("03 // DIAGNOSTICS", font, brush, 14, 11);
                }
                using (var stFont = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(14, 32, 48)))
                using (var stBorder = new Pen(Color.FromArgb(56, 189, 248), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.FillRectangle(stBg, w - 110, 10, 98, 17);
                    g.DrawRectangle(stBorder, w - 110, 10, 98, 17);
                    g.DrawString("[AUTO-HEAL // OK]", stFont, stText, w - 105, 12);
                }

                // Viewport Container (Cyber Animation)
                int vpX = 12, vpY = 34, vpW = w - 24, vpH = 106;
                using (var vpBg = new SolidBrush(Color.FromArgb(2, 8, 14))) {
                    g.FillRectangle(vpBg, vpX, vpY, vpW, vpH);
                }
                using (var vpPen = new Pen(Color.FromArgb(22, 38, 56), 1f)) {
                    g.DrawRectangle(vpPen, vpX, vpY, vpW, vpH);
                }
                DrawCornerBrackets(g, vpX, vpY, vpW, vpH, accent, 7f);

                // Microservice Causal Graph Nodes
                PointF[] gNodes = new PointF[] {
                    new PointF(vpX + 30, vpY + 34),   // Client
                    new PointF(vpX + 95, vpY + 26),   // Gateway
                    new PointF(vpX + 95, vpY + 74),   // Auth
                    new PointF(vpX + 160, vpY + 40),  // Core API (Anomaly)
                    new PointF(vpX + 220, vpY + 28),  // DB
                    new PointF(vpX + 220, vpY + 74)   // Fallback Cache
                };

                int[][] gLinks = new int[][] {
                    new int[] { 0, 1 }, new int[] { 1, 2 }, new int[] { 1, 3 },
                    new int[] { 3, 4 }, new int[] { 2, 5 }, new int[] { 5, 4 }
                };

                using (var linkPen = new Pen(Color.FromArgb(60, 56, 189, 248), 1.2f)) {
                    foreach (var edge in gLinks) {
                        g.DrawLine(linkPen, gNodes[edge[0]], gNodes[edge[1]]);
                    }
                }

                // Auto-healing fallback path in neon emerald
                using (var healPen = new Pen(Color.FromArgb(140, 52, 211, 153), 1.5f)) {
                    healPen.DashStyle = DashStyle.Dash;
                    g.DrawLine(healPen, gNodes[1], gNodes[2]);
                    g.DrawLine(healPen, gNodes[2], gNodes[5]);
                    g.DrawLine(healPen, gNodes[5], gNodes[4]);
                }

                // Causal propagation pulse
                float waveT = (t * 2f) % 1f;
                PointF pA = gNodes[1];
                PointF pB = gNodes[3];
                float wX = pA.X + (pB.X - pA.X) * waveT;
                float wY = pA.Y + (pB.Y - pA.Y) * waveT;
                using (var waveBrush = new SolidBrush(Color.FromArgb(255, 0, 240, 255))) {
                    g.FillEllipse(waveBrush, wX - 2.5f, wY - 2.5f, 5f, 5f);
                }

                // Draw Graph Nodes
                for (int i = 0; i < gNodes.Length; i++) {
                    PointF pt = gNodes[i];
                    Color nCol = Color.FromArgb(56, 189, 248);
                    if (i == 3) {
                        // Root cause anomaly node (pulsing red/orange)
                        float aPulse = 0.5f + 0.5f * (float)Math.Sin(t * Math.PI * 2f);
                        nCol = Color.FromArgb(240, (int)(70 + aPulse * 50), 60);
                        using (var ringP = new Pen(Color.FromArgb((int)(aPulse * 180), 239, 68, 68), 1.2f)) {
                            g.DrawEllipse(ringP, pt.X - 8, pt.Y - 8, 16, 16);
                        }
                    } else if (i == 5) {
                        nCol = Color.FromArgb(52, 211, 153);
                    }

                    using (var nBrush = new SolidBrush(nCol)) {
                        g.FillEllipse(nBrush, pt.X - 4, pt.Y - 4, 8, 8);
                    }
                }

                // Sweeping sky-blue laser scanline
                float scanY = vpY + 4 + (t * (vpH - 8));
                using (var scanBrush = new LinearGradientBrush(
                    new RectangleF(vpX + 4, scanY - 3, vpW - 8, 6),
                    Color.Transparent, Color.FromArgb(140, 56, 189, 248), 90f)) {
                    g.FillRectangle(scanBrush, vpX + 4, scanY - 3, vpW - 8, 6);
                }
                using (var scanPen = new Pen(Color.FromArgb(220, 230, 250, 255), 1f)) {
                    g.DrawLine(scanPen, vpX + 6, scanY, vpX + vpW - 6, scanY);
                }

                // Viewport Top & Bottom Labels
                using (var hudFont = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var hudText = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                    g.DrawString("CAUSAL_TRACE // 6 NODES", hudFont, hudText, vpX + 6, vpY + 4);
                    g.DrawString("LAT: 0.8ms", hudFont, hudText, vpX + vpW - 64, vpY + 4);
                    g.DrawString("ANOMALY: ISOLATED // HEAL: 100%", hudFont, hudText, vpX + 6, vpY + vpH - 12);
                }

                // --- CONTENT AREA ---
                // Title
                using (var titleFont = new Font("Consolas", 12.5f, FontStyle.Bold))
                using (var titleBrush = new SolidBrush(Color.FromArgb(245, 248, 252))) {
                    g.DrawString("ROOTCAUSE_IQ", titleFont, titleBrush, 14, 148);
                }

                // Subtitle
                using (var subFont = new Font("Segoe UI", 8.8f, FontStyle.Bold))
                using (var subBrush = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.DrawString("Diagnostic & Root-Cause Engine", subFont, subBrush, 14, 170);
                }

                // Description
                using (var descFont = new Font("Segoe UI", 8.0f, FontStyle.Regular))
                using (var descBrush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Intelligent failure tracing correlating\ndistributed error propagations & recovery paths.", descFont, descBrush, 14, 190);
                }

                // Tech Tags
                string[] tags = new string[] { "TypeScript", "Graph", "Next.js" };
                float tagX = 14;
                using (var tagFont = new Font("Consolas", 7.8f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        using (var bgBrush = new SolidBrush(Color.FromArgb(14, 26, 42))) {
                            g.FillRectangle(bgBrush, tagX, 230, sz.Width + 8, 18);
                        }
                        using (var borderPen = new Pen(Color.FromArgb(34, 56, 82), 1f)) {
                            g.DrawRectangle(borderPen, tagX, 230, sz.Width + 8, 18);
                        }
                        using (var textBrush = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                            g.DrawString(tag, tagFont, textBrush, tagX + 4, 232);
                        }
                        tagX += sz.Width + 12;
                    }
                }

                // Bottom Footer Telemetry
                using (var linePen = new Pen(Color.FromArgb(24, 40, 60), 1f)) {
                    g.DrawLine(linePen, 12, 256, w - 12, 256);
                }
                using (var footFont = new Font("Consolas", 7.5f, FontStyle.Bold)) {
                    using (var dotBrush = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                        g.FillEllipse(dotBrush, 14, 263, 6, 6);
                    }
                    using (var footText = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString("AUTO-HEAL: 100% // NO DOWNTIME", footFont, footText, 25, 260);
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
