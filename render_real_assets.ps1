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

    // Helpers for Tactical Poster Cards
    public static void DrawTape(Graphics g, float cx, float cy, float w, float h, float angle = -1.5f) {
        var state = g.Save();
        g.TranslateTransform(cx, cy);
        g.RotateTransform(angle);
        using (var tapeBrush = new SolidBrush(Color.FromArgb(75, 245, 245, 235))) {
            g.FillRectangle(tapeBrush, -w / 2f, -h / 2f, w, h);
        }
        using (var tapePen = new Pen(Color.FromArgb(90, 255, 255, 255), 1f)) {
            g.DrawRectangle(tapePen, -w / 2f, -h / 2f, w, h);
        }
        g.Restore(state);
    }

    public static void DrawCornerBracket(Graphics g, float x, float y, float size, Color color, float thick = 2f) {
        using (var p = new Pen(color, thick)) {
            g.DrawLine(p, x - size, y, x, y);
            g.DrawLine(p, x, y - size, x, y);
        }
    }

    public static void DrawStar(Graphics g, float cx, float cy, float r, Color color) {
        PointF[] pts = new PointF[10];
        for (int i = 0; i < 10; i++) {
            float rad = (i % 2 == 0) ? r : r * 0.45f;
            double ang = -Math.PI / 2.0 + (i * Math.PI / 5.0);
            pts[i] = new PointF(cx + (float)(Math.Cos(ang) * rad), cy + (float)(Math.Sin(ang) * rad));
        }
        using (var b = new SolidBrush(color)) g.FillPolygon(b, pts);
    }

    // 1. Tactical Banner: SELECTED WORK
    public static void RenderSelectedWorkBanner(string outputPath, int totalFrames = 20) {
        int w = 840, h = 54;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var b = new SolidBrush(Color.Black)) g.FillRectangle(b, 0, 0, w, h);

                // Left Angled Trapezoid Badge
                PointF[] trap = new PointF[] {
                    new PointF(12, 8),
                    new PointF(290, 8),
                    new PointF(272, 46),
                    new PointF(12, 46)
                };
                using (var b = new SolidBrush(Color.FromArgb(238, 234, 222))) g.FillPolygon(b, trap);
                using (var p = new Pen(Color.FromArgb(200, 195, 180), 1f)) g.DrawPolygon(p, trap);

                using (var font = new Font("Impact", 21f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(15, 23, 42))) {
                    g.DrawString("SELECTED WORK", font, b, 24, 12);
                }

                // Middle Red Rule + Subtitle
                using (var p = new Pen(Color.FromArgb(225, 29, 72), 2f)) {
                    g.DrawLine(p, 305, 20, 620, 20);
                }
                using (var subFont = new Font("Consolas", 8.5f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("three current builds // verified repositories", subFont, b, 312, 28);
                }

                // Right 5 Stars with subtle pulse
                for (int s = 0; s < 5; s++) {
                    float starPulse = 0.8f + 0.2f * (float)Math.Sin((t + s * 0.15f) * Math.PI * 2f);
                    int alpha = (int)(255 * starPulse);
                    DrawStar(g, w - 130 + s * 22, 27, 7.5f, Color.FromArgb(alpha, 225, 29, 72));
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 85);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 2. Card 1: FaceTrack-AI (Tactical Obsidian & Biometric Reticle)
    public static void RenderCardFaceTrack(string outputPath, int totalFrames = 20) {
        int w = 274, h = 360;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var b = new SolidBrush(Color.Black)) g.FillRectangle(b, 0, 0, w, h);

                int pad = 4;
                int cardW = w - pad * 2, cardH = h - pad * 2 - 4;
                var cardRect = new Rectangle(pad, pad + 4, cardW, cardH);

                // Dark Obsidian Slate Gradient
                using (var grad = new LinearGradientBrush(cardRect, Color.FromArgb(14, 20, 26), Color.FromArgb(6, 9, 12), 90f)) {
                    g.FillRectangle(grad, cardRect);
                }
                using (var p = new Pen(Color.FromArgb(32, 44, 56), 1f)) g.DrawRectangle(p, cardRect);

                // Subtle paper fold / crease line across middle
                using (var fold1 = new Pen(Color.FromArgb(18, 255, 255, 255), 1f)) {
                    g.DrawLine(fold1, pad + 2, 180, pad + cardW - 2, 180);
                }
                using (var fold2 = new Pen(Color.FromArgb(25, 0, 0, 0), 1f)) {
                    g.DrawLine(fold2, pad + 2, 181, pad + cardW - 2, 181);
                }

                // Top Tape Tab
                DrawTape(g, w / 2f, pad + 4, 48, 14, -1.8f);

                // Header: Title & Index
                using (var font = new Font("Impact", 19f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(248, 250, 252))) {
                    g.DrawString("FACETRACK", font, b, 14, 18);
                }
                using (var iFont = new Font("Consolas", 10f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("01", iFont, b, w - 34, 22);
                }

                // Repo Link
                using (var urlFont = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("github.com/CapedCrusader77/FaceTrack-AI", urlFont, b, 14, 46);
                }

                // Center Tactical Biometric Graphic (y = 65..220)
                float cx = w / 2f, cy = 142f;
                using (var bgGrid = new Pen(Color.FromArgb(18, 28, 38), 1f)) {
                    g.DrawLine(bgGrid, cx - 75, cy, cx + 75, cy);
                    g.DrawLine(bgGrid, cx, cy - 65, cx, cy + 65);
                    g.DrawRectangle(bgGrid, cx - 65, cy - 55, 130, 110);
                }

                // Concentric reticle rings
                float[] radii = new float[] { 20f, 40f, 60f };
                foreach (var r in radii) {
                    using (var rp = new Pen(Color.FromArgb(40, 52, 211, 153), 1f)) {
                        g.DrawEllipse(rp, cx - r, cy - r, r * 2, r * 2);
                    }
                }

                // Biometric Landmark Mesh Triangulation
                float yaw = (float)Math.Sin(t * Math.PI * 2f) * 6f;
                PointF[] facePts = new PointF[] {
                    new PointF(cx - 22 + yaw, cy - 20),
                    new PointF(cx + 22 + yaw, cy - 20),
                    new PointF(cx - 12 + yaw, cy - 6),
                    new PointF(cx + 12 + yaw, cy - 6),
                    new PointF(cx + yaw, cy + 4),
                    new PointF(cx - 10 + yaw, cy + 18),
                    new PointF(cx + 10 + yaw, cy + 18),
                    new PointF(cx + yaw, cy + 28)
                };
                using (var mp = new Pen(Color.FromArgb(120, 52, 211, 153), 1.2f)) {
                    g.DrawLine(mp, facePts[0], facePts[1]);
                    g.DrawLine(mp, facePts[0], facePts[2]);
                    g.DrawLine(mp, facePts[1], facePts[3]);
                    g.DrawLine(mp, facePts[2], facePts[3]);
                    g.DrawLine(mp, facePts[2], facePts[4]);
                    g.DrawLine(mp, facePts[3], facePts[4]);
                    g.DrawLine(mp, facePts[4], facePts[5]);
                    g.DrawLine(mp, facePts[4], facePts[6]);
                    g.DrawLine(mp, facePts[5], facePts[6]);
                    g.DrawLine(mp, facePts[5], facePts[7]);
                    g.DrawLine(mp, facePts[6], facePts[7]);
                }
                foreach (var pt in facePts) {
                    using (var pb = new SolidBrush(Color.FromArgb(220, 52, 211, 153))) {
                        g.FillEllipse(pb, pt.X - 2f, pt.Y - 2f, 4f, 4f);
                    }
                }

                // Crosshair corners
                using (var cp = new Pen(Color.FromArgb(80, 52, 211, 153), 1f)) {
                    g.DrawLine(cp, cx - 80, cy - 65, cx - 72, cy - 65);
                    g.DrawLine(cp, cx - 80, cy - 65, cx - 80, cy - 57);
                    g.DrawLine(cp, cx + 80, cy - 65, cx + 72, cy - 65);
                    g.DrawLine(cp, cx + 80, cy - 65, cx + 80, cy - 57);
                    g.DrawLine(cp, cx - 80, cy + 65, cx - 72, cy + 65);
                    g.DrawLine(cp, cx - 80, cy + 65, cx - 80, cy + 57);
                    g.DrawLine(cp, cx + 80, cy + 65, cx + 72, cy + 65);
                    g.DrawLine(cp, cx + 80, cy + 65, cx + 80, cy + 57);
                }

                // Telemetry sub-label
                using (var tf = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var tb = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("6-DoF MESH // WASM // 60 FPS", tf, tb, cx - 64, cy + 72);
                }

                // Bottom Content
                using (var hf = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var hb = new SolidBrush(Color.FromArgb(248, 250, 252))) {
                    g.DrawString("Real-time 6-DoF perception engine.", hf, hb, 14, 236);
                }
                using (var df = new Font("Segoe UI", 7.8f, FontStyle.Regular))
                using (var db = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("High-frequency facial landmark tracking\nwith client WebAssembly tensor pipeline.", df, db, 14, 258);
                }

                // Tech Stack
                using (var sf = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var sb = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("TYPESCRIPT / WASM / OPENCV", sf, sb, 14, 305);
                }

                // Corner L-Bracket
                DrawCornerBracket(g, w - 16, h - 22, 16, Color.FromArgb(52, 211, 153), 2.2f);
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 85);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 3. Card 2: skillguard-oss (Tactical Crimson & Radar Oscilloscope)
    public static void RenderCardSkillguard(string outputPath, int totalFrames = 20) {
        int w = 274, h = 360;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var b = new SolidBrush(Color.Black)) g.FillRectangle(b, 0, 0, w, h);

                int pad = 4;
                int cardW = w - pad * 2, cardH = h - pad * 2 - 4;
                var cardRect = new Rectangle(pad, pad + 4, cardW, cardH);

                // Bold Crimson Red Poster Gradient
                using (var grad = new LinearGradientBrush(cardRect, Color.FromArgb(168, 24, 38), Color.FromArgb(120, 16, 28), 90f)) {
                    g.FillRectangle(grad, cardRect);
                }
                using (var p = new Pen(Color.FromArgb(200, 40, 56), 1f)) g.DrawRectangle(p, cardRect);

                // Subtle paper fold / crease line across middle
                using (var fold1 = new Pen(Color.FromArgb(30, 255, 255, 255), 1f)) {
                    g.DrawLine(fold1, pad + 2, 180, pad + cardW - 2, 180);
                }
                using (var fold2 = new Pen(Color.FromArgb(40, 60, 8, 14), 1f)) {
                    g.DrawLine(fold2, pad + 2, 181, pad + cardW - 2, 181);
                }

                // Top Tape Tab
                DrawTape(g, w / 2f, pad + 4, 48, 14, 1.2f);

                // Header: Title & Index
                using (var font = new Font("Impact", 19f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.White)) {
                    g.DrawString("SKILLGUARD", font, b, 14, 18);
                }
                using (var iFont = new Font("Consolas", 10f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(254, 205, 211))) {
                    g.DrawString("02", iFont, b, w - 34, 22);
                }

                // Repo Link
                using (var urlFont = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(254, 205, 211))) {
                    g.DrawString("github.com/CapedCrusader77/skillguard-oss", urlFont, b, 14, 46);
                }

                // Center Radar Rings & Frequency Oscilloscope Waveform (y = 65..220)
                float cx = w / 2f, cy = 168f;
                float[] radii = new float[] { 24f, 48f, 72f, 96f };
                foreach (var r in radii) {
                    using (var rp = new Pen(Color.FromArgb(70, 255, 255, 255), 1f)) {
                        g.DrawEllipse(rp, cx - r, cy - r, r * 2, r * 2);
                    }
                }

                // Fine Radar Crosshairs
                using (var cp = new Pen(Color.FromArgb(60, 255, 255, 255), 1f)) {
                    g.DrawLine(cp, cx - 90, cy, cx + 90, cy);
                    g.DrawLine(cp, cx, cy - 90, cx, cy + 10);
                }

                // Dynamic Oscilloscope Waveform along cy
                var wavePts = new PointF[120];
                for (int i = 0; i < 120; i++) {
                    float wx = cx - 90 + (i / 119f) * 180f;
                    float normX = (wx - cx) / 45f;
                    float env = (float)Math.Exp(-normX * normX); // Gaussian bell envelope
                    float wave = (float)Math.Sin(normX * 8f + t * Math.PI * 4f) * 22f * env;
                    wave += (float)Math.Sin(normX * 16f - t * Math.PI * 2f) * 12f * env;
                    wavePts[i] = new PointF(wx, cy + wave);
                }
                using (var wp = new Pen(Color.White, 1.8f)) {
                    g.DrawCurve(wp, wavePts);
                }

                // Bottom Content
                using (var hf = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var hb = new SolidBrush(Color.White)) {
                    g.DrawString("Zero-trust security audit engine.", hf, hb, 14, 236);
                }
                using (var df = new Font("Segoe UI", 7.8f, FontStyle.Regular))
                using (var db = new SolidBrush(Color.FromArgb(254, 205, 211))) {
                    g.DrawString("AST capability inspection analyzing\nsandbox boundaries and permission guards.", df, db, 14, 258);
                }

                // Tech Stack
                using (var sf = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var sb = new SolidBrush(Color.White)) {
                    g.DrawString("PYTHON / AST-PARSER / SECURITY", sf, sb, 14, 305);
                }

                // Corner L-Bracket
                DrawCornerBracket(g, w - 16, h - 22, 16, Color.White, 2.2f);
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 85);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 4. Card 3: rootcause-iq (Vintage Parchment & Causal Blueprint)
    public static void RenderCardRootcause(string outputPath, int totalFrames = 20) {
        int w = 274, h = 360;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var b = new SolidBrush(Color.Black)) g.FillRectangle(b, 0, 0, w, h);

                int pad = 4;
                int cardW = w - pad * 2, cardH = h - pad * 2 - 4;
                var cardRect = new Rectangle(pad, pad + 4, cardW, cardH);

                // Vintage Dossier Parchment Gradient
                using (var grad = new LinearGradientBrush(cardRect, Color.FromArgb(232, 227, 216), Color.FromArgb(218, 212, 198), 90f)) {
                    g.FillRectangle(grad, cardRect);
                }
                using (var p = new Pen(Color.FromArgb(190, 184, 168), 1f)) g.DrawRectangle(p, cardRect);

                // Subtle paper fold / crease line across middle
                using (var fold1 = new Pen(Color.FromArgb(40, 255, 255, 255), 1f)) {
                    g.DrawLine(fold1, pad + 2, 180, pad + cardW - 2, 180);
                }
                using (var fold2 = new Pen(Color.FromArgb(30, 120, 110, 95), 1f)) {
                    g.DrawLine(fold2, pad + 2, 181, pad + cardW - 2, 181);
                }

                // Top Tape Tab
                DrawTape(g, w / 2f, pad + 4, 48, 14, -0.8f);

                // Header: Title & Index
                using (var font = new Font("Impact", 19f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(17, 24, 39))) {
                    g.DrawString("ROOTCAUSE", font, b, 14, 18);
                }
                using (var iFont = new Font("Consolas", 10f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.FromArgb(225, 29, 72))) {
                    g.DrawString("03", iFont, b, w - 34, 22);
                }

                // Repo Link
                using (var urlFont = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var b = new SolidBrush(Color.FromArgb(225, 29, 72))) {
                    g.DrawString("github.com/CapedCrusader77/rootcause-iq", urlFont, b, 14, 46);
                }

                // Center Causal DAG Blueprint Graphic (y = 65..220)
                float cx = w / 2f, cy = 142f;
                using (var bgGrid = new Pen(Color.FromArgb(25, 0, 0, 0), 1f)) {
                    for (int gx = -80; gx <= 80; gx += 20) g.DrawLine(bgGrid, cx + gx, cy - 65, cx + gx, cy + 65);
                    for (int gy = -60; gy <= 60; gy += 20) g.DrawLine(bgGrid, cx - 80, cy + gy, cx + 80, cy + gy);
                }

                PointF[] gNodes = new PointF[] {
                    new PointF(cx - 65, cy - 20), // Ingress
                    new PointF(cx - 25, cy - 40), // Gateway
                    new PointF(cx - 25, cy + 20), // Auth
                    new PointF(cx + 25, cy - 25), // Core API (Root Cause)
                    new PointF(cx + 65, cy - 40), // Database
                    new PointF(cx + 65, cy + 20)  // Failover Cache
                };

                // Connecting links in charcoal drafting ink
                using (var lp = new Pen(Color.FromArgb(140, 30, 41, 59), 1.4f)) {
                    g.DrawLine(lp, gNodes[0], gNodes[1]);
                    g.DrawLine(lp, gNodes[0], gNodes[2]);
                    g.DrawLine(lp, gNodes[1], gNodes[3]);
                    g.DrawLine(lp, gNodes[3], gNodes[4]);
                    g.DrawLine(lp, gNodes[2], gNodes[5]);
                    g.DrawLine(lp, gNodes[5], gNodes[4]);
                }

                // Auto-heal recovery route in red dashed ink
                using (var healP = new Pen(Color.FromArgb(225, 29, 72), 1.5f)) {
                    healP.DashStyle = DashStyle.Dash;
                    g.DrawLine(healP, gNodes[1], gNodes[2]);
                    g.DrawLine(healP, gNodes[2], gNodes[5]);
                    g.DrawLine(healP, gNodes[5], gNodes[4]);
                }

                // Nodes
                for (int i = 0; i < gNodes.Length; i++) {
                    PointF pt = gNodes[i];
                    if (i == 3) {
                        // Root cause anomaly node (Red with pulsing ring)
                        float aPulse = 0.5f + 0.5f * (float)Math.Sin(t * Math.PI * 2f);
                        using (var nb = new SolidBrush(Color.FromArgb(225, 29, 72))) g.FillEllipse(nb, pt.X - 5, pt.Y - 5, 10, 10);
                        using (var np = new Pen(Color.FromArgb((int)(160 + 95 * aPulse), 225, 29, 72), 1.2f)) g.DrawEllipse(np, pt.X - 9, pt.Y - 9, 18, 18);
                    } else {
                        using (var nb = new SolidBrush(Color.FromArgb(30, 41, 59))) g.FillEllipse(nb, pt.X - 4, pt.Y - 4, 8, 8);
                    }
                }

                // Telemetry sub-label
                using (var tf = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var tb = new SolidBrush(Color.FromArgb(71, 85, 105))) {
                    g.DrawString("CAUSAL DAG // LAT: 0.8ms // AUTO-HEAL", tf, tb, cx - 72, cy + 72);
                }

                // Bottom Content
                using (var hf = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var hb = new SolidBrush(Color.FromArgb(17, 24, 39))) {
                    g.DrawString("Autonomous causal diagnostic engine.", hf, hb, 14, 236);
                }
                using (var df = new Font("Segoe UI", 7.8f, FontStyle.Regular))
                using (var db = new SolidBrush(Color.FromArgb(71, 85, 105))) {
                    g.DrawString("Intelligent failure tracing correlating\ndistributed error propagations & recovery.", df, db, 14, 258);
                }

                // Tech Stack
                using (var sf = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var sb = new SolidBrush(Color.FromArgb(225, 29, 72))) {
                    g.DrawString("TYPESCRIPT / OPENTELEMETRY / GRAPH", sf, sb, 14, 305);
                }

                // Corner L-Bracket
                DrawCornerBracket(g, w - 16, h - 22, 16, Color.FromArgb(225, 29, 72), 2.2f);
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 85);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 5. Divider Generator: GA-01 Timeline & Neon Progress Runner
    public static void RenderDivider(string outputPath, int totalFrames = 20) {
        int w = 840, h = 32;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var b = new SolidBrush(Color.Black)) g.FillRectangle(b, 0, 0, w, h);

                // Dashed timeline
                using (var p = new Pen(Color.FromArgb(30, 41, 59), 1.2f)) {
                    p.DashStyle = DashStyle.Dash;
                    g.DrawLine(p, 20, 16, w - 20, 16);
                }

                // Center Red Capsule Badge: [ GA-01 ]
                float cx = w / 2f, cy = 16f;
                using (var b = new SolidBrush(Color.FromArgb(225, 29, 72))) {
                    g.FillRectangle(b, cx - 28, cy - 9, 56, 18);
                }
                using (var font = new Font("Impact", 9f, FontStyle.Bold))
                using (var b = new SolidBrush(Color.White)) {
                    g.DrawString("GA - 01", font, b, cx - 22, cy - 7);
                }

                // Right Neon Green Progress Runner
                float runX = cx + 60 + ((t * 260f) % 260f);
                using (var b = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.FillRectangle(b, runX, cy - 2, 45, 4);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 70);
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

Write-Host "Rendering banner_work.gif (SELECTED WORK)..."
[RealAssetGenerator]::RenderSelectedWorkBanner("$assetsDir\banner_work.gif")


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
