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

    // Helpers for Cyber Module Cards
    public static GraphicsPath RoundedRect(RectangleF bounds, float radius) {
        GraphicsPath path = new GraphicsPath();
        float d = radius * 2f;
        path.AddArc(bounds.X, bounds.Y, d, d, 180, 90);
        path.AddArc(bounds.Right - d, bounds.Y, d, d, 270, 90);
        path.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90);
        path.AddArc(bounds.X, bounds.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }
    // 1. Header Banner: FEATURED ARCHITECTURES
    public static void RenderFeaturedArchitecturesBanner(string outputPath, int totalFrames = 20) {
        int w = 840, h = 48;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var b = new SolidBrush(Color.Black)) g.FillRectangle(b, 0, 0, w, h);

                // Container frame
                using (var p = new Pen(Color.FromArgb(28, 38, 54), 1f)) g.DrawRectangle(p, 0, 0, w - 1, h - 1);

                // Left Cyber Terminal Badge
                using (var b = new SolidBrush(Color.FromArgb(12, 18, 28))) {
                    g.FillRectangle(b, 1, 1, 235, h - 2);
                }
                using (var p = new Pen(Color.FromArgb(56, 189, 248), 1.5f)) {
                    g.DrawLine(p, 1, 1, 235, 1);
                    g.DrawLine(p, 235, 1, 235, h - 2);
                    g.DrawLine(p, 1, h - 2, 235, h - 2);
                }

                using (var font = new Font("Impact", 15f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.White)) {
                    g.DrawString("FEATURED ARCHITECTURES", font, b, 14, 11);
                }

                // Center description
                using (var subFont = new Font("Consolas", 8.2f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("// VERIFIED PRODUCTION SYSTEMS : 3 CORE ENGINES", subFont, b, 255, 17);
                }

                // Right Status Badge
                float pulse = 0.7f + 0.3f * (float)Math.Sin(t * Math.PI * 2f);
                Color beaconColor = Color.FromArgb((int)(255 * pulse), 52, 211, 153);
                using (var b = new SolidBrush(Color.FromArgb(8, 22, 18))) {
                    g.FillRectangle(b, w - 165, 10, 150, 26);
                }
                using (var p = new Pen(Color.FromArgb(52, 211, 153), 1f)) {
                    g.DrawRectangle(p, w - 165, 10, 150, 26);
                }
                using (var b = new SolidBrush(beaconColor)) {
                    g.FillEllipse(b, w - 152, 19, 8, 8);
                }
                using (var sFont = new Font("Consolas", 8f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("ENGINES ONLINE", sFont, b, w - 138, 16);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 85);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 2. Card 1: FaceTrack-AI (Perception Module // Cyan & Sky Blue)
    public static void RenderCardFaceTrack(string outputPath, int totalFrames = 20) {
        int w = 274, h = 360;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var b = new SolidBrush(Color.Black)) g.FillRectangle(b, 0, 0, w, h);

                var bounds = new RectangleF(3, 3, w - 6, h - 6);
                using (var path = RoundedRect(bounds, 6f)) {
                    using (var grad = new LinearGradientBrush(bounds, Color.FromArgb(14, 22, 34), Color.FromArgb(7, 10, 16), 90f)) {
                        g.FillPath(grad, path);
                    }
                    using (var p = new Pen(Color.FromArgb(30, 48, 72), 1.2f)) {
                        g.DrawPath(p, path);
                    }
                }

                // Top Glowing Edge Accent Line
                using (var p = new Pen(Color.FromArgb(56, 189, 248), 2f)) {
                    g.DrawLine(p, 12, 3, w - 12, 3);
                }

                // Row 1: Module Meta Tag
                using (var font = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.DrawString("SYS-01 // PERCEPTION CORE", font, b, 12, 14);
                }
                // Status Tag
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.FillEllipse(b, w - 68, 18, 5, 5);
                }
                using (var font = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("ACTIVE", font, b, w - 58, 14);
                }

                // Row 2: Title (Impact Bold Uppercase)
                using (var font = new Font("Impact", 18f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.White)) {
                    g.DrawString("FACETRACK-AI", font, b, 11, 28);
                }

                // Row 3: Repo Link
                using (var font = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.DrawString("github.com/CapedCrusader77/FaceTrack-AI", font, b, 12, 54);
                }

                // Center Visual Viewport (x: 12, y: 72, w: 250, h: 146)
                var vpRect = new Rectangle(12, 72, w - 24, 146);
                using (var b = new SolidBrush(Color.FromArgb(4, 7, 12))) g.FillRectangle(b, vpRect);
                using (var p = new Pen(Color.FromArgb(20, 32, 48), 1f)) g.DrawRectangle(p, vpRect);
                DrawCornerBrackets(g, 12, 72, w - 24, 146, Color.FromArgb(56, 189, 248), 7f);

                // Technical Grid & Crosshairs inside viewport
                float cx = 12 + (w - 24) / 2f, cy = 72 + 73f;
                using (var gp = new Pen(Color.FromArgb(16, 26, 40), 1f)) {
                    g.DrawLine(gp, 12, cy, w - 12, cy);
                    g.DrawLine(gp, cx, 72, cx, 218);
                    g.DrawEllipse(gp, cx - 60, cy - 60, 120, 120);
                    g.DrawEllipse(gp, cx - 35, cy - 35, 70, 70);
                }

                // Angle tick marks on outer ring
                using (var tp = new Pen(Color.FromArgb(40, 56, 189, 248), 1f)) {
                    for (int ang = 0; ang < 360; ang += 30) {
                        double rad = ang * Math.PI / 180.0;
                        float x1 = cx + (float)Math.Cos(rad) * 56;
                        float y1 = cy + (float)Math.Sin(rad) * 56;
                        float x2 = cx + (float)Math.Cos(rad) * 62;
                        float y2 = cy + (float)Math.Sin(rad) * 62;
                        g.DrawLine(tp, x1, y1, x2, y2);
                    }
                }

                // Rich 3D FaceMesh Landmark Topology
                float yaw = (float)Math.Sin(t * Math.PI * 2f) * 9f;
                float pitch = (float)Math.Cos(t * Math.PI * 2f) * 4f;

                PointF[] mesh = new PointF[] {
                    new PointF(cx - 36 + yaw * 1.2f, cy - 34 + pitch), // 0: Left Forehead
                    new PointF(cx + 36 + yaw * 1.2f, cy - 34 + pitch), // 1: Right Forehead
                    new PointF(cx + yaw, cy - 38 + pitch),             // 2: Mid Forehead
                    new PointF(cx - 20 + yaw, cy - 14 + pitch),        // 3: Left Eye
                    new PointF(cx + 20 + yaw, cy - 14 + pitch),        // 4: Right Eye
                    new PointF(cx - 38 + yaw * 0.9f, cy + 2 + pitch),  // 5: Left Cheek
                    new PointF(cx + 38 + yaw * 0.9f, cy + 2 + pitch),  // 6: Right Cheek
                    new PointF(cx + yaw, cy - 2 + pitch),              // 7: Nose Bridge
                    new PointF(cx + yaw, cy + 12 + pitch),             // 8: Nose Tip
                    new PointF(cx - 16 + yaw, cy + 26 + pitch),        // 9: Left Mouth
                    new PointF(cx + 16 + yaw, cy + 26 + pitch),        // 10: Right Mouth
                    new PointF(cx + yaw, cy + 40 + pitch)              // 11: Chin
                };

                // Mesh edges in glowing cyan wireframe
                using (var mp = new Pen(Color.FromArgb(160, 56, 189, 248), 1.2f)) {
                    // Forehead
                    g.DrawLine(mp, mesh[0], mesh[2]); g.DrawLine(mp, mesh[2], mesh[1]);
                    g.DrawLine(mp, mesh[0], mesh[3]); g.DrawLine(mp, mesh[1], mesh[4]);
                    // Midface
                    g.DrawLine(mp, mesh[3], mesh[7]); g.DrawLine(mp, mesh[4], mesh[7]);
                    g.DrawLine(mp, mesh[0], mesh[5]); g.DrawLine(mp, mesh[1], mesh[6]);
                    g.DrawLine(mp, mesh[5], mesh[3]); g.DrawLine(mp, mesh[6], mesh[4]);
                    g.DrawLine(mp, mesh[7], mesh[8]);
                    g.DrawLine(mp, mesh[5], mesh[8]); g.DrawLine(mp, mesh[6], mesh[8]);
                    // Lower face & Jaw
                    g.DrawLine(mp, mesh[8], mesh[9]); g.DrawLine(mp, mesh[8], mesh[10]);
                    g.DrawLine(mp, mesh[9], mesh[10]);
                    g.DrawLine(mp, mesh[5], mesh[9]); g.DrawLine(mp, mesh[6], mesh[10]);
                    g.DrawLine(mp, mesh[9], mesh[11]); g.DrawLine(mp, mesh[10], mesh[11]);
                }

                // Keypoint vertices with subtle glow
                foreach (var pt in mesh) {
                    using (var pb = new SolidBrush(Color.FromArgb(240, 255, 255))) {
                        g.FillEllipse(pb, pt.X - 2f, pt.Y - 2f, 4f, 4f);
                    }
                }

                // Target lock box corners
                float boxW = 86f, boxH = 92f;
                float bx = cx - boxW / 2f + yaw, by = cy - boxH / 2f + pitch;
                using (var lp = new Pen(Color.FromArgb(120, 56, 189, 248), 1.2f)) {
                    g.DrawLine(lp, bx, by, bx + 10, by); g.DrawLine(lp, bx, by, bx, by + 10);
                    g.DrawLine(lp, bx + boxW - 10, by, bx + boxW, by); g.DrawLine(lp, bx + boxW, by, bx + boxW, by + 10);
                    g.DrawLine(lp, bx, by + boxH - 10, bx, by + boxH); g.DrawLine(lp, bx, by + boxH, bx + 10, by + boxH);
                    g.DrawLine(lp, bx + boxW - 10, by + boxH, bx + boxW, by + boxH); g.DrawLine(lp, bx + boxW, by + boxH - 10, bx + boxW, by + boxH);
                }

                // Telemetry readout line inside viewport
                using (var b = new SolidBrush(Color.FromArgb(200, 56, 189, 248)))
                using (var font = new Font("Consolas", 6.8f, FontStyle.Regular)) {
                    g.DrawString(String.Format("POSE: Y:{0:+0.0;-0.0}deg P:{1:+0.0;-0.0}deg // 60 FPS", yaw, pitch), font, b, 18, 202);
                }

                // Content: Primary Hook
                using (var font = new Font("Segoe UI", 9.2f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.White)) {
                    g.DrawString("Real-time 6-DoF perception engine.", font, b, 12, 227);
                }

                // Content: Description
                using (var font = new Font("Segoe UI", 7.8f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Client-side WebAssembly inference for high-\nfrequency facial landmark & head-pose tracking.", font, b, 12, 246);
                }

                // Metrics / Specs Row
                using (var b = new SolidBrush(Color.FromArgb(12, 18, 28))) {
                    g.FillRectangle(b, 12, 285, w - 24, 22);
                }
                using (var p = new Pen(Color.FromArgb(24, 38, 58), 1f)) {
                    g.DrawRectangle(p, 12, 285, w - 24, 22);
                }
                using (var font = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.DrawString("LATENCY: <12ms  //  ACCEL: SIMD WASM", font, b, 18, 290);
                }

                // Stack Badges
                string[] tags = new string[] { "TypeScript", "WASM", "OpenCV" };
                float tx = 12f;
                foreach (var tag in tags) {
                    using (var b = new SolidBrush(Color.FromArgb(16, 26, 40))) g.FillRectangle(b, tx, 318, 68, 18);
                    using (var p = new Pen(Color.FromArgb(38, 62, 92), 1f)) g.DrawRectangle(p, tx, 318, 68, 18);
                    using (var font = new Font("Consolas", 6.8f, FontStyle.Bold))
                    using (var b = new SolidBrush(Color.FromArgb(224, 242, 254))) {
                        g.DrawString(tag, font, b, tx + 6, 321);
                    }
                    tx += 74f;
                }

                // Bottom Accent Stripe
                using (var p = new Pen(Color.FromArgb(56, 189, 248), 1.5f)) {
                    g.DrawLine(p, 12, h - 8, w - 12, h - 8);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 85);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 3. Card 2: skillguard-oss (Security Module // Electric Violet & Coral)
    public static void RenderCardSkillguard(string outputPath, int totalFrames = 20) {
        int w = 274, h = 360;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var b = new SolidBrush(Color.Black)) g.FillRectangle(b, 0, 0, w, h);

                var bounds = new RectangleF(3, 3, w - 6, h - 6);
                using (var path = RoundedRect(bounds, 6f)) {
                    using (var grad = new LinearGradientBrush(bounds, Color.FromArgb(24, 18, 36), Color.FromArgb(11, 8, 18), 90f)) {
                        g.FillPath(grad, path);
                    }
                    using (var p = new Pen(Color.FromArgb(56, 36, 84), 1.2f)) {
                        g.DrawPath(p, path);
                    }
                }

                // Top Glowing Edge Accent Line
                using (var p = new Pen(Color.FromArgb(167, 139, 250), 2f)) {
                    g.DrawLine(p, 12, 3, w - 12, 3);
                }

                // Row 1: Module Meta Tag
                using (var font = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(167, 139, 250))) {
                    g.DrawString("SYS-02 // ZERO-TRUST GUARD", font, b, 12, 14);
                }
                // Status Tag
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.FillEllipse(b, w - 68, 18, 5, 5);
                }
                using (var font = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("ACTIVE", font, b, w - 58, 14);
                }

                // Row 2: Title (Impact Bold Uppercase)
                using (var font = new Font("Impact", 18f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.White)) {
                    g.DrawString("SKILLGUARD-OSS", font, b, 11, 28);
                }

                // Row 3: Repo Link
                using (var font = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(167, 139, 250))) {
                    g.DrawString("github.com/CapedCrusader77/skillguard-oss", font, b, 12, 54);
                }

                // Center Visual Viewport (x: 12, y: 72, w: 250, h: 146)
                var vpRect = new Rectangle(12, 72, w - 24, 146);
                using (var b = new SolidBrush(Color.FromArgb(8, 4, 14))) g.FillRectangle(b, vpRect);
                using (var p = new Pen(Color.FromArgb(36, 22, 54), 1f)) g.DrawRectangle(p, vpRect);
                DrawCornerBrackets(g, 12, 72, w - 24, 146, Color.FromArgb(167, 139, 250), 7f);

                // Hexagonal Shield Force-Field & AST Node Containment
                float cx = 12 + (w - 24) / 2f, cy = 72 + 73f;

                // Concentric Hexagons
                for (int hr = 24; hr <= 60; hr += 12) {
                    PointF[] hex = new PointF[6];
                    for (int i = 0; i < 6; i++) {
                        double ang = i * Math.PI / 3.0 + t * Math.PI * (hr % 24 == 0 ? -0.4 : 0.4);
                        hex[i] = new PointF(cx + (float)(Math.Cos(ang) * hr), cy + (float)(Math.Sin(ang) * hr));
                    }
                    using (var hp = new Pen(Color.FromArgb(hr == 60 ? 110 : 50, 167, 139, 250), 1.2f)) {
                        g.DrawPolygon(hp, hex);
                    }
                }

                // AST Syntax Tree Nodes floating on perimeter
                PointF[] astNodes = new PointF[] {
                    new PointF(cx - 52, cy - 24),
                    new PointF(cx + 52, cy - 24),
                    new PointF(cx - 48, cy + 30),
                    new PointF(cx + 48, cy + 30),
                    new PointF(cx, cy - 48)
                };
                using (var ap = new Pen(Color.FromArgb(80, 251, 113, 133), 1.2f)) {
                    ap.DashStyle = DashStyle.Dash;
                    foreach (var pt in astNodes) g.DrawLine(ap, cx, cy, pt.X, pt.Y);
                }
                foreach (var pt in astNodes) {
                    using (var nb = new SolidBrush(Color.FromArgb(251, 113, 133))) g.FillEllipse(nb, pt.X - 3f, pt.Y - 3f, 6f, 6f);
                }

                // Central Core Shield Glyph
                using (var sp = new Pen(Color.FromArgb(230, 240, 255), 1.6f)) {
                    PointF[] shield = new PointF[] {
                        new PointF(cx - 16, cy - 16),
                        new PointF(cx + 16, cy - 16),
                        new PointF(cx + 16, cy + 6),
                        new PointF(cx, cy + 22),
                        new PointF(cx - 16, cy + 6)
                    };
                    using (var sb = new SolidBrush(Color.FromArgb(140, 139, 92, 246))) g.FillPolygon(sb, shield);
                    g.DrawPolygon(sp, shield);
                }

                // Rotating Radar Scan Wave
                float sweepAngle = (t * 360f) % 360f;
                using (var sp = new Pen(Color.FromArgb(170, 251, 113, 133), 1.5f)) {
                    double rad = sweepAngle * Math.PI / 180.0;
                    g.DrawLine(sp, cx, cy, cx + (float)(Math.Cos(rad) * 64), cy + (float)(Math.Sin(rad) * 64));
                }

                // Telemetry readout line inside viewport
                using (var b = new SolidBrush(Color.FromArgb(200, 167, 139, 250)))
                using (var font = new Font("Consolas", 6.8f, FontStyle.Regular)) {
                    g.DrawString("AST SCAN: HARDENED  //  PERIMETER: ZERO-TRUST", font, b, 18, 202);
                }

                // Content: Primary Hook
                using (var font = new Font("Segoe UI", 9.2f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.White)) {
                    g.DrawString("Zero-trust security audit engine.", font, b, 12, 227);
                }

                // Content: Description
                using (var font = new Font("Segoe UI", 7.8f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Static AST analysis auditing external runtime\nsandbox bounds and privileged API guardrails.", font, b, 12, 246);
                }

                // Metrics / Specs Row
                using (var b = new SolidBrush(Color.FromArgb(20, 14, 30))) {
                    g.FillRectangle(b, 12, 285, w - 24, 22);
                }
                using (var p = new Pen(Color.FromArgb(48, 32, 70), 1f)) {
                    g.DrawRectangle(p, 12, 285, w - 24, 22);
                }
                using (var font = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(167, 139, 250))) {
                    g.DrawString("ANALYSIS: AST GRAPH  //  TARGET: PYTHON/NODE", font, b, 18, 290);
                }

                // Stack Badges
                string[] tags = new string[] { "Python", "AST Parser", "Security" };
                float tx = 12f;
                foreach (var tag in tags) {
                    using (var b = new SolidBrush(Color.FromArgb(32, 20, 48))) g.FillRectangle(b, tx, 318, 68, 18);
                    using (var p = new Pen(Color.FromArgb(76, 48, 112), 1f)) g.DrawRectangle(p, tx, 318, 68, 18);
                    using (var font = new Font("Consolas", 6.8f, FontStyle.Bold))
                    using (var b = new SolidBrush(Color.FromArgb(243, 232, 255))) {
                        g.DrawString(tag, font, b, tx + 6, 321);
                    }
                    tx += 74f;
                }

                // Bottom Accent Stripe
                using (var p = new Pen(Color.FromArgb(167, 139, 250), 1.5f)) {
                    g.DrawLine(p, 12, h - 8, w - 12, h - 8);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 85);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 4. Card 3: rootcause-iq (Causal Diagnostics // Emerald & Mint)
    public static void RenderCardRootcause(string outputPath, int totalFrames = 20) {
        int w = 274, h = 360;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var b = new SolidBrush(Color.Black)) g.FillRectangle(b, 0, 0, w, h);

                var bounds = new RectangleF(3, 3, w - 6, h - 6);
                using (var path = RoundedRect(bounds, 6f)) {
                    using (var grad = new LinearGradientBrush(bounds, Color.FromArgb(14, 28, 24), Color.FromArgb(6, 14, 11), 90f)) {
                        g.FillPath(grad, path);
                    }
                    using (var p = new Pen(Color.FromArgb(28, 64, 52), 1.2f)) {
                        g.DrawPath(p, path);
                    }
                }

                // Top Glowing Edge Accent Line
                using (var p = new Pen(Color.FromArgb(52, 211, 153), 2f)) {
                    g.DrawLine(p, 12, 3, w - 12, 3);
                }

                // Row 1: Module Meta Tag
                using (var font = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("SYS-03 // CAUSAL OBSERVABILITY", font, b, 12, 14);
                }
                // Status Tag
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.FillEllipse(b, w - 68, 18, 5, 5);
                }
                using (var font = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("ACTIVE", font, b, w - 58, 14);
                }

                // Row 2: Title (Impact Bold Uppercase)
                using (var font = new Font("Impact", 18f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.White)) {
                    g.DrawString("ROOTCAUSE-IQ", font, b, 11, 28);
                }

                // Row 3: Repo Link
                using (var font = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("github.com/CapedCrusader77/rootcause-iq", font, b, 12, 54);
                }

                // Center Visual Viewport (x: 12, y: 72, w: 250, h: 146)
                var vpRect = new Rectangle(12, 72, w - 24, 146);
                using (var b = new SolidBrush(Color.FromArgb(3, 10, 8))) g.FillRectangle(b, vpRect);
                using (var p = new Pen(Color.FromArgb(18, 44, 34), 1f)) g.DrawRectangle(p, vpRect);
                DrawCornerBrackets(g, 12, 72, w - 24, 146, Color.FromArgb(52, 211, 153), 7f);

                // Distributed Microservice Causal DAG Topology
                float cx = 12 + (w - 24) / 2f, cy = 72 + 65f;

                PointF[] nodes = new PointF[] {
                    new PointF(cx - 78, cy - 20), // 0: INGRESS
                    new PointF(cx - 28, cy - 38), // 1: GATEWAY
                    new PointF(cx - 28, cy + 22), // 2: AUTH
                    new PointF(cx + 25, cy - 20), // 3: CORE (Root Cause)
                    new PointF(cx + 72, cy - 38), // 4: DATABASE
                    new PointF(cx + 72, cy + 22), // 5: CACHE
                    new PointF(cx + 25, cy + 30)  // 6: QUEUE
                };
                string[] nodeLabels = new string[] { "ING", "GW", "AUTH", "CORE", "DB", "CACHE", "MQ" };

                // Connecting links with arrows
                using (var lp = new Pen(Color.FromArgb(70, 52, 211, 153), 1.4f)) {
                    g.DrawLine(lp, nodes[0], nodes[1]);
                    g.DrawLine(lp, nodes[0], nodes[2]);
                    g.DrawLine(lp, nodes[1], nodes[3]);
                    g.DrawLine(lp, nodes[3], nodes[4]);
                    g.DrawLine(lp, nodes[2], nodes[5]);
                    g.DrawLine(lp, nodes[5], nodes[4]);
                    g.DrawLine(lp, nodes[3], nodes[6]);
                    g.DrawLine(lp, nodes[6], nodes[5]);
                }

                // Causal pulse traveling across nodes[1] -> nodes[3] -> nodes[4]
                float pulseProg = (t * 2f) % 1f;
                float px1 = nodes[1].X + (nodes[3].X - nodes[1].X) * pulseProg;
                float py1 = nodes[1].Y + (nodes[3].Y - nodes[1].Y) * pulseProg;
                using (var pb = new SolidBrush(Color.FromArgb(250, 255, 255))) {
                    g.FillEllipse(pb, px1 - 3, py1 - 3, 6, 6);
                }

                // Draw Nodes & Labels
                using (var lblFont = new Font("Consolas", 6f, FontStyle.Bold)) {
                    for (int i = 0; i < nodes.Length; i++) {
                        PointF pt = nodes[i];
                        if (i == 3) {
                            // Highlighted Root Cause Node (Red alert pulse)
                            float wave = 1f + 0.3f * (float)Math.Sin(t * Math.PI * 4f);
                            using (var np = new Pen(Color.FromArgb(239, 68, 68), 1.2f)) {
                                g.DrawEllipse(np, pt.X - 10 * wave, pt.Y - 10 * wave, 20 * wave, 20 * wave);
                            }
                            using (var nb = new SolidBrush(Color.FromArgb(239, 68, 68))) {
                                g.FillEllipse(nb, pt.X - 5, pt.Y - 5, 10, 10);
                            }
                            using (var lb = new SolidBrush(Color.FromArgb(254, 202, 202))) {
                                g.DrawString(nodeLabels[i], lblFont, lb, pt.X - 12, pt.Y - 14);
                            }
                        } else {
                            using (var nb = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                                g.FillEllipse(nb, pt.X - 4, pt.Y - 4, 8, 8);
                            }
                            using (var lb = new SolidBrush(Color.FromArgb(110, 231, 183))) {
                                g.DrawString(nodeLabels[i], lblFont, lb, pt.X - 10, pt.Y - 14);
                            }
                        }
                    }
                }

                // Dynamic anomaly latency waveform at bottom of viewport
                PointF[] wavePts = new PointF[60];
                for (int i = 0; i < 60; i++) {
                    float wx = 18 + i * (w - 36) / 59f;
                    float env = (float)Math.Sin(i / 59f * Math.PI);
                    float wy = cy + 46 + (float)Math.Sin(i * 0.5f + t * Math.PI * 4f) * 6f * env;
                    wavePts[i] = new PointF(wx, wy);
                }
                using (var wp = new Pen(Color.FromArgb(140, 52, 211, 153), 1.2f)) {
                    g.DrawCurve(wp, wavePts);
                }

                // Telemetry readout line inside viewport
                using (var b = new SolidBrush(Color.FromArgb(200, 52, 211, 153)))
                using (var font = new Font("Consolas", 6.8f, FontStyle.Regular)) {
                    g.DrawString("CAUSAL TRACE: O(1) PINPOINT // MTTR -74%", font, b, 18, 202);
                }

                // Content: Primary Hook
                using (var font = new Font("Segoe UI", 9.2f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.White)) {
                    g.DrawString("Autonomous causal diagnostic engine.", font, b, 12, 227);
                }

                // Content: Description
                using (var font = new Font("Segoe UI", 7.8f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Graph-based distributed failure isolation correlating\ntelemetry traces and propagating anomaly trees.", font, b, 12, 246);
                }

                // Metrics / Specs Row
                using (var b = new SolidBrush(Color.FromArgb(10, 22, 18))) {
                    g.FillRectangle(b, 12, 285, w - 24, 22);
                }
                using (var p = new Pen(Color.FromArgb(24, 52, 42), 1f)) {
                    g.DrawRectangle(p, 12, 285, w - 24, 22);
                }
                using (var font = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("TOPOLOGY: K8S DAG  //  CORRELATION: 0.98", font, b, 18, 290);
                }

                // Stack Badges
                string[] tags = new string[] { "TypeScript", "OpenTelemetry", "Graph DAG" };
                float tx = 12f;
                foreach (var tag in tags) {
                    using (var b = new SolidBrush(Color.FromArgb(16, 36, 28))) g.FillRectangle(b, tx, 318, 68, 18);
                    using (var p = new Pen(Color.FromArgb(36, 84, 64), 1f)) g.DrawRectangle(p, tx, 318, 68, 18);
                    using (var font = new Font("Consolas", 6.8f, FontStyle.Bold))
                    using (var b = new SolidBrush(Color.FromArgb(209, 250, 229))) {
                        g.DrawString(tag, font, b, tx + 4, 321);
                    }
                    tx += 74f;
                }

                // Bottom Accent Stripe
                using (var p = new Pen(Color.FromArgb(52, 211, 153), 1.5f)) {
                    g.DrawLine(p, 12, h - 8, w - 12, h - 8);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 85);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 5. Divider (Cyber Bus // GA-CORE)
    public static void RenderDivider(string outputPath, int totalFrames = 20) {
        int w = 840, h = 28;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var b = new SolidBrush(Color.Black)) g.FillRectangle(b, 0, 0, w, h);

                float cy = 14f;
                // Background Bus Line
                using (var p = new Pen(Color.FromArgb(24, 36, 52), 1f)) {
                    g.DrawLine(p, 10, cy, w - 10, cy);
                }

                // Traveling pulses
                float p1 = (t * (w - 20)) % (w - 20);
                float p2 = (w - 20) - ((t * (w - 20)) % (w - 20));
                using (var p = new Pen(Color.FromArgb(56, 189, 248), 1.5f)) {
                    g.DrawLine(p, 10 + Math.Max(0, p1 - 30), cy, 10 + p1, cy);
                }
                using (var p = new Pen(Color.FromArgb(52, 211, 153), 1.5f)) {
                    g.DrawLine(p, 10 + p2, cy, 10 + Math.Min(w - 20, p2 + 30), cy);
                }

                // Center Node
                int boxW = 260, boxH = 18;
                int bx = (w - boxW) / 2;
                using (var b = new SolidBrush(Color.Black)) {
                    g.FillRectangle(b, bx - 8, (int)cy - boxH / 2 - 2, boxW + 16, boxH + 4);
                }
                using (var b = new SolidBrush(Color.FromArgb(12, 18, 28))) {
                    g.FillRectangle(b, bx, (int)cy - boxH / 2, boxW, boxH);
                }
                using (var p = new Pen(Color.FromArgb(40, 60, 88), 1f)) {
                    g.DrawRectangle(p, bx, (int)cy - boxH / 2, boxW, boxH);
                }
                using (var font = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    string label = "[ GOKUL A // AUTONOMOUS AI CORE ]";
                    var sz = g.MeasureString(label, font);
                    g.DrawString(label, font, b, bx + (boxW - sz.Width) / 2f, cy - sz.Height / 2f);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 85);
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

Write-Host "Rendering banner_work.gif (FEATURED ARCHITECTURES)..."
[RealAssetGenerator]::RenderFeaturedArchitecturesBanner("$assetsDir\banner_work.gif")


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
