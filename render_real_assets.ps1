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

    // 2. Real Project Card 1: FaceTrack-AI (Cyber Biometric Vision HUD)
    public static void RenderCardFaceTrack(string outputPath, int totalFrames = 24) {
        int w = 840, h = 150;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(0, 240, 255); // Cyan

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

                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 4, h);
                }

                // Index & Name
                using (var font = new Font("Consolas", 13f, FontStyle.Bold))
                using (var brush = new SolidBrush(accent)) {
                    g.DrawString("01 // FACETRACK_AI", font, brush, 24, 16);
                }
                // Status badge
                using (var stFont = new Font("Consolas", 8.5f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(15, 30, 45)))
                using (var stBorder = new Pen(Color.FromArgb(0, 200, 220), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                    g.FillRectangle(stBg, 320, 16, 190, 20);
                    g.DrawRectangle(stBorder, 320, 16, 190, 20);
                    g.DrawString("[ACTIVE // 60 FPS // WEBRTC]", stFont, stText, 326, 19);
                }

                using (var font = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                    g.DrawString("Real-time Computer Vision & 6-DoF Facial Landmark Tracking", font, brush, 25, 44);
                }
                using (var font = new Font("Segoe UI", 9f, FontStyle.Regular))
                using (var brush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("High-frequency perception pipeline with multi-point facial mesh tracking,\nhead pose estimation, and low-latency client-side tensor inference.", font, brush, 25, 66);
                }

                // Tech tags
                string[] tags = new string[] { "TypeScript", "Computer Vision", "FaceMesh", "WebRTC", "TF.js" };
                float tagX = 25;
                using (var tagFont = new Font("Consolas", 8.5f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        using (var bgBrush = new SolidBrush(Color.FromArgb(15, 23, 36))) {
                            g.FillRectangle(bgBrush, tagX, 110, sz.Width + 10, 20);
                        }
                        using (var borderPen = new Pen(Color.FromArgb(38, 52, 75), 1f)) {
                            g.DrawRectangle(borderPen, tagX, 110, sz.Width + 10, 20);
                        }
                        using (var textBrush = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                            g.DrawString(tag, tagFont, textBrush, tagX + 5, 113);
                        }
                        tagX += sz.Width + 14;
                    }
                }

                // --- RIGHT SIDE: Cinematic Cyber Biometric Image Viewport ---
                int vpX = 540, vpY = 12, vpW = 285, vpH = 126;
                using (var vpBg = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(vpBg, vpX, vpY, vpW, vpH);
                }
                using (var vpBorder = new Pen(Color.FromArgb(24, 34, 50), 1f)) {
                    g.DrawRectangle(vpBorder, vpX, vpY, vpW, vpH);
                }

                DrawCornerBrackets(g, vpX, vpY, vpW, vpH, accent, 9f);

                // Left sub-panel inside viewport: Live 6-DoF telemetry & metrics
                float yaw = (float)Math.Sin(t * Math.PI * 2f) * 12f;
                float pitch = (float)Math.Cos(t * Math.PI * 2f) * 6f;
                float telX = vpX + 12f;
                float telY = vpY + 12f;

                using (var hudFont = new Font("Consolas", 7.2f, FontStyle.Bold)) {
                    using (var hBrush = new SolidBrush(accent)) {
                        g.DrawString("// BIOMETRIC_HUD", hudFont, hBrush, telX, telY);
                    }
                    using (var hText = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                        g.DrawString(string.Format("YAW   {0:+00.0;-00.0} DEG", yaw), hudFont, hText, telX, telY + 16);
                        g.FillRectangle(new SolidBrush(Color.FromArgb(20, 30, 48)), telX, telY + 27, 80, 4);
                        float yawW = Math.Abs(yaw) * 2.8f;
                        g.FillRectangle(new SolidBrush(accent), telX + 40 + (yaw < 0 ? -yawW : 0), telY + 27, yawW, 4);

                        g.DrawString(string.Format("PITCH {0:+00.0;-00.0} DEG", pitch), hudFont, hText, telX, telY + 35);
                        g.FillRectangle(new SolidBrush(Color.FromArgb(20, 30, 48)), telX, telY + 46, 80, 4);
                        float pitchW = Math.Abs(pitch) * 3.5f;
                        g.FillRectangle(new SolidBrush(Color.FromArgb(167, 139, 250)), telX + 40 + (pitch < 0 ? -pitchW : 0), telY + 46, pitchW, 4);
                    }

                    using (var gBrush = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                        g.DrawString("FPS : 60.0 [REALTIME]", hudFont, gBrush, telX, telY + 56);
                    }
                    using (var cBrush = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                        g.DrawString("CONF: 99.8% [LOCKED]", hudFont, cBrush, telX, telY + 68);
                    }
                    using (var nBrush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString("MESH: 468 KEYPOINTS", hudFont, nBrush, telX, telY + 80);
                        g.DrawString("WEBRTC // LOW_LATENCY", hudFont, nBrush, telX, telY + 94);
                    }
                }

                // Right sub-panel: Render 3D Cinematic Biometric Face Image
                int imgX = vpX + 158, imgY = vpY + 3, imgW = 120, imgH = 120;
                if (imgFaceTrack != null) {
                    g.DrawImage(imgFaceTrack, new Rectangle(imgX, imgY, imgW, imgH));

                    // Seamless left fade into black
                    using (var fadeBrush = new LinearGradientBrush(
                        new RectangleF(imgX - 1, imgY, 22, imgH),
                        Color.FromArgb(255, 0, 0, 0), Color.Transparent, 0f)) {
                        g.FillRectangle(fadeBrush, imgX - 1, imgY, 22, imgH);
                    }

                    // Vertical animated biometric scanline sweeping across face
                    float scanY = imgY + (t * imgH);
                    using (var scanBrush = new LinearGradientBrush(
                        new RectangleF(imgX, scanY - 3, imgW, 6),
                        Color.Transparent, Color.FromArgb(160, 0, 240, 255), 90f)) {
                        g.FillRectangle(scanBrush, imgX, scanY - 3, imgW, 6);
                    }
                    using (var scanPen = new Pen(Color.FromArgb(230, 255, 255, 255), 1.2f)) {
                        g.DrawLine(scanPen, imgX, scanY, imgX + imgW, scanY);
                    }

                    // Corner brackets on image
                    DrawCornerBrackets(g, imgX, imgY, imgW, imgH, Color.FromArgb(180, 0, 240, 255), 7f);

                    // Badge on bottom of image
                    using (var tagBg = new SolidBrush(Color.FromArgb(200, 0, 15, 25)))
                    using (var tagBorder = new Pen(accent, 1f))
                    using (var tagFont = new Font("Consolas", 6.8f, FontStyle.Bold))
                    using (var tagText = new SolidBrush(accent)) {
                        g.FillRectangle(tagBg, imgX + imgW - 68, imgY + imgH - 16, 64, 14);
                        g.DrawRectangle(tagBorder, imgX + imgW - 68, imgY + imgH - 16, 64, 14);
                        g.DrawString("IRIS_LOCK", tagFont, tagText, imgX + imgW - 64, imgY + imgH - 14);
                    }
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 3. Real Project Card 2: skillguard-oss (Cyber Security Command Node)
    public static void RenderCardSkillguard(string outputPath, int totalFrames = 24) {
        int w = 840, h = 150;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(139, 92, 246); // Electric Violet

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

                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 4, h);
                }

                // Index & Name
                using (var font = new Font("Consolas", 13f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(167, 139, 250))) {
                    g.DrawString("02 // SKILLGUARD_OSS", font, brush, 24, 16);
                }
                // Status badge
                using (var stFont = new Font("Consolas", 8.5f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(28, 20, 48)))
                using (var stBorder = new Pen(Color.FromArgb(167, 139, 250), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(192, 132, 252))) {
                    g.FillRectangle(stBg, 320, 16, 190, 20);
                    g.DrawRectangle(stBorder, 320, 16, 190, 20);
                    g.DrawString("[1* STAR // OSS ACTIVE]", stFont, stText, 334, 19);
                }

                using (var font = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                    g.DrawString("Open-Source Skill Verification & Security Inspection Engine", font, brush, 25, 44);
                }
                using (var font = new Font("Segoe UI", 9f, FontStyle.Regular))
                using (var brush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Automated capability audit engine for AI agents, analyzing AST syntaxes,\nruntime sandboxes, and permission escalation vulnerabilities.", font, brush, 25, 66);
                }

                // Tech tags
                string[] tags = new string[] { "Python", "AST Analysis", "Security", "AI Agents", "Static Audit" };
                float tagX = 25;
                using (var tagFont = new Font("Consolas", 8.5f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        using (var bgBrush = new SolidBrush(Color.FromArgb(22, 18, 38))) {
                            g.FillRectangle(bgBrush, tagX, 110, sz.Width + 10, 20);
                        }
                        using (var borderPen = new Pen(Color.FromArgb(60, 48, 98), 1f)) {
                            g.DrawRectangle(borderPen, tagX, 110, sz.Width + 10, 20);
                        }
                        using (var textBrush = new SolidBrush(Color.FromArgb(221, 214, 254))) {
                            g.DrawString(tag, tagFont, textBrush, tagX + 5, 113);
                        }
                        tagX += sz.Width + 14;
                    }
                }

                // --- RIGHT SIDE: Cinematic Cyber Security Shield Viewport ---
                int vpX = 540, vpY = 12, vpW = 285, vpH = 126;
                using (var vpBg = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(vpBg, vpX, vpY, vpW, vpH);
                }
                using (var vpBorder = new Pen(Color.FromArgb(34, 26, 54), 1f)) {
                    g.DrawRectangle(vpBorder, vpX, vpY, vpW, vpH);
                }

                DrawCornerBrackets(g, vpX, vpY, vpW, vpH, accent, 9f);

                // Left sub-panel inside viewport: Security audit checklist
                float shX = vpX + 12f;
                float shY = vpY + 12f;
                using (var shFont = new Font("Consolas", 7.2f, FontStyle.Bold)) {
                    using (var bTitle = new SolidBrush(Color.FromArgb(192, 132, 252))) {
                        g.DrawString("// SECURITY_NODE", shFont, bTitle, shX, shY);
                    }
                    string[] checks = new string[] {
                        "[OK] AST SYNTAX: PASS",
                        "[OK] SANDBOX: ISOLATED",
                        "[OK] PERM GUARD: ACTIVE",
                        "[OK] VULNERABILITIES: 0",
                        "STATUS: 100% AUDITED",
                        "OSS ENGINE // VERIFIED"
                    };
                    for (int k = 0; k < checks.Length; k++) {
                        Color checkCol = (k == 3) ? Color.FromArgb(52, 211, 153) : (k >= 4 ? Color.FromArgb(148, 163, 184) : Color.FromArgb(221, 214, 254));
                        using (var bCheck = new SolidBrush(checkCol)) {
                            g.DrawString(checks[k], shFont, bCheck, shX, shY + 16 + k * 15);
                        }
                    }
                }

                // Right sub-panel: Render 3D Cinematic Security Shield
                int imgX = vpX + 158, imgY = vpY + 3, imgW = 120, imgH = 120;
                if (imgSkillguard != null) {
                    g.DrawImage(imgSkillguard, new Rectangle(imgX, imgY, imgW, imgH));

                    // Seamless left fade into black
                    using (var fadeBrush = new LinearGradientBrush(
                        new RectangleF(imgX - 1, imgY, 22, imgH),
                        Color.FromArgb(255, 0, 0, 0), Color.Transparent, 0f)) {
                        g.FillRectangle(fadeBrush, imgX - 1, imgY, 22, imgH);
                    }

                    // Vertical animated laser scanline sweeping across shield
                    float scanY = imgY + (t * imgH);
                    using (var scanBrush = new LinearGradientBrush(
                        new RectangleF(imgX, scanY - 3, imgW, 6),
                        Color.Transparent, Color.FromArgb(160, 167, 139, 250), 90f)) {
                        g.FillRectangle(scanBrush, imgX, scanY - 3, imgW, 6);
                    }
                    using (var scanPen = new Pen(Color.FromArgb(240, 245, 243, 255), 1.2f)) {
                        g.DrawLine(scanPen, imgX, scanY, imgX + imgW, scanY);
                    }

                    // Corner brackets on image
                    DrawCornerBrackets(g, imgX, imgY, imgW, imgH, Color.FromArgb(180, 167, 139, 250), 7f);

                    // Badge on bottom of image
                    using (var tagBg = new SolidBrush(Color.FromArgb(200, 20, 10, 35)))
                    using (var tagBorder = new Pen(accent, 1f))
                    using (var tagFont = new Font("Consolas", 6.8f, FontStyle.Bold))
                    using (var tagText = new SolidBrush(Color.FromArgb(221, 214, 254))) {
                        g.FillRectangle(tagBg, imgX + imgW - 68, imgY + imgH - 16, 64, 14);
                        g.DrawRectangle(tagBorder, imgX + imgW - 68, imgY + imgH - 16, 64, 14);
                        g.DrawString("SHIELD: OK", tagFont, tagText, imgX + imgW - 64, imgY + imgH - 14);
                    }
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 4. Real Project Card 3: rootcause-iq (Enterprise Microservice Causal Trace)
    public static void RenderCardRootcause(string outputPath, int totalFrames = 24) {
        int w = 840, h = 150;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(56, 189, 248); // Sky Blue

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

                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 4, h);
                }

                // Index & Name
                using (var font = new Font("Consolas", 13f, FontStyle.Bold))
                using (var brush = new SolidBrush(accent)) {
                    g.DrawString("03 // ROOTCAUSE_IQ", font, brush, 24, 16);
                }
                // Status badge
                using (var stFont = new Font("Consolas", 8.5f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(15, 28, 44)))
                using (var stBorder = new Pen(Color.FromArgb(56, 189, 248), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.FillRectangle(stBg, 320, 16, 190, 20);
                    g.DrawRectangle(stBorder, 320, 16, 190, 20);
                    g.DrawString("[ACTIVE BUILD // DIAGNOSTICS]", stFont, stText, 324, 19);
                }

                using (var font = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                    g.DrawString("Automated Diagnostic & Root-Cause Failure Analysis Engine", font, brush, 25, 44);
                }
                using (var font = new Font("Segoe UI", 9f, FontStyle.Regular))
                using (var brush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Intelligent failure tracing framework correlating distributed error propagations,\nsystem anomalies, and automated incident recovery paths.", font, brush, 25, 66);
                }

                // Tech tags
                string[] tags = new string[] { "TypeScript", "Graph Theory", "Diagnostics", "Anomaly Detection", "Next.js" };
                float tagX = 25;
                using (var tagFont = new Font("Consolas", 8.5f, FontStyle.Regular)) {
                    foreach (var tag in tags) {
                        var sz = g.MeasureString(tag, tagFont);
                        using (var bgBrush = new SolidBrush(Color.FromArgb(15, 25, 38))) {
                            g.FillRectangle(bgBrush, tagX, 110, sz.Width + 10, 20);
                        }
                        using (var borderPen = new Pen(Color.FromArgb(36, 58, 86), 1f)) {
                            g.DrawRectangle(borderPen, tagX, 110, sz.Width + 10, 20);
                        }
                        using (var textBrush = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                            g.DrawString(tag, tagFont, textBrush, tagX + 5, 113);
                        }
                        tagX += sz.Width + 14;
                    }
                }

                // --- RIGHT SIDE: Cinematic Quantum Causal Core Viewport ---
                int vpX = 540, vpY = 12, vpW = 285, vpH = 126;
                using (var vpBg = new SolidBrush(Color.FromArgb(0, 0, 0))) {
                    g.FillRectangle(vpBg, vpX, vpY, vpW, vpH);
                }
                using (var vpBorder = new Pen(Color.FromArgb(24, 34, 50), 1f)) {
                    g.DrawRectangle(vpBorder, vpX, vpY, vpW, vpH);
                }

                DrawCornerBrackets(g, vpX, vpY, vpW, vpH, accent, 9f);

                // Left sub-panel inside viewport: Causal diagnostic metrics
                float rcX = vpX + 12f;
                float rcY = vpY + 12f;
                using (var rcFont = new Font("Consolas", 7.2f, FontStyle.Bold)) {
                    using (var rTitle = new SolidBrush(accent)) {
                        g.DrawString("// DIAGNOSTIC_CORE", rcFont, rTitle, rcX, rcY);
                    }
                    using (var rText = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                        g.DrawString("TOPOLOGY: 6 NODES", rcFont, rText, rcX, rcY + 16);
                        
                        // Anomaly pulse
                        float aPulse = 0.5f + 0.5f * (float)Math.Sin(t * Math.PI * 2f);
                        Color aCol = Color.FromArgb(255, (int)(120 + aPulse * 100), 50);
                        using (var anomBrush = new SolidBrush(aCol)) {
                            g.DrawString("ANOMALY : ISOLATED", rcFont, anomBrush, rcX, rcY + 30);
                        }

                        using (var gBrush = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                            g.DrawString("AUTO-HEAL: 100%", rcFont, gBrush, rcX, rcY + 44);
                        }
                        g.DrawString("LATENCY : 0.8ms // SYNC", rcFont, rText, rcX, rcY + 58);
                    }
                    using (var subBrush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString("GRAPH PROPAGATION: OK", rcFont, subBrush, rcX, rcY + 74);
                        g.DrawString("RESILIENT MESH // ACTIVE", rcFont, subBrush, rcX, rcY + 88);
                    }
                }

                // Right sub-panel: Render 3D Cinematic Quantum Microchip Core
                int imgX = vpX + 158, imgY = vpY + 3, imgW = 120, imgH = 120;
                if (imgRootcause != null) {
                    g.DrawImage(imgRootcause, new Rectangle(imgX, imgY, imgW, imgH));

                    // Seamless left fade into black
                    using (var fadeBrush = new LinearGradientBrush(
                        new RectangleF(imgX - 1, imgY, 22, imgH),
                        Color.FromArgb(255, 0, 0, 0), Color.Transparent, 0f)) {
                        g.FillRectangle(fadeBrush, imgX - 1, imgY, 22, imgH);
                    }

                    // Vertical animated laser scanline sweeping across quantum chip
                    float scanY = imgY + (t * imgH);
                    using (var scanBrush = new LinearGradientBrush(
                        new RectangleF(imgX, scanY - 3, imgW, 6),
                        Color.Transparent, Color.FromArgb(160, 56, 189, 248), 90f)) {
                        g.FillRectangle(scanBrush, imgX, scanY - 3, imgW, 6);
                    }
                    using (var scanPen = new Pen(Color.FromArgb(240, 220, 245, 255), 1.2f)) {
                        g.DrawLine(scanPen, imgX, scanY, imgX + imgW, scanY);
                    }

                    // Corner brackets on image
                    DrawCornerBrackets(g, imgX, imgY, imgW, imgH, Color.FromArgb(180, 56, 189, 248), 7f);

                    // Badge on bottom of image
                    using (var tagBg = new SolidBrush(Color.FromArgb(200, 5, 20, 35)))
                    using (var tagBorder = new Pen(accent, 1f))
                    using (var tagFont = new Font("Consolas", 6.8f, FontStyle.Bold))
                    using (var tagText = new SolidBrush(accent)) {
                        g.FillRectangle(tagBg, imgX + imgW - 68, imgY + imgH - 16, 64, 14);
                        g.DrawRectangle(tagBorder, imgX + imgW - 68, imgY + imgH - 16, 64, 14);
                        g.DrawString("QUANTUM", tagFont, tagText, imgX + imgW - 60, imgY + imgH - 14);
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
