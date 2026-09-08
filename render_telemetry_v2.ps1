$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class AutonomousTelemetrySuite {
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
        using (var p = new Pen(color, 1.2f)) {
            g.DrawLines(p, new PointF[] { new PointF(x, y + len), new PointF(x, y), new PointF(x + len, y) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - len, y), new PointF(x + w, y), new PointF(x + w, y + len) });
            g.DrawLines(p, new PointF[] { new PointF(x, y + h - len), new PointF(x, y + h), new PointF(x + len, y + h) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - len, y + h), new PointF(x + w, y + h), new PointF(x + w, y + h - len) });
        }
    }

    // 1. Render Banner: 02 // AUTONOMOUS SYSTEMS TELEMETRY
    public static void RenderBanner(string outputPath, int totalFrames = 20) {
        int w = 840, h = 36;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                using (var bBg = new SolidBrush(Color.FromArgb(7, 9, 14))) {
                    g.FillRectangle(bBg, 0, 0, w, h);
                }
                using (var pBorder = new Pen(Color.FromArgb(30, 41, 59), 1f)) {
                    g.DrawRectangle(pBorder, 1, 1, w - 2, h - 2);
                }

                // Left accent indicator
                using (var bBar = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                    g.FillRectangle(bBar, 4, 8, 3, 20);
                }

                // Title
                using (var fTitle = new Font("Segoe UI", 10.5f, FontStyle.Bold))
                using (var bTitle = new SolidBrush(Color.White)) {
                    g.DrawString("02 // AUTONOMOUS SYSTEMS TELEMETRY", fTitle, bTitle, 16, 7);
                }

                // Subtitle
                using (var fSub = new Font("Consolas", 7.8f, FontStyle.Regular))
                using (var bSub = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("// REAL-TIME PERCEPTION, CAUSAL INFERENCE & AST DIAGNOSTICS", fSub, bSub, 320, 10);
                }

                // Status pill (pulsing cyan / emerald)
                float pulse = 0.65f + 0.35f * (float)Math.Sin(t * Math.PI * 2f);
                int dotA = (int)(255 * pulse);
                int pillW = 142, pillH = 20;
                int pillX = w - pillW - 8, pillY = 8;
                using (var bPill = new SolidBrush(Color.FromArgb(15, 23, 42)))
                using (var pPill = new Pen(Color.FromArgb(51, 65, 85), 1f))
                using (var bDot = new SolidBrush(Color.FromArgb(dotA, 0, 240, 255)))
                using (var fStatus = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var bStatusText = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.FillRectangle(bPill, pillX, pillY, pillW, pillH);
                    g.DrawRectangle(pPill, pillX, pillY, pillW, pillH);
                    g.FillEllipse(bDot, pillX + 8, pillY + 6, 7, 7);
                    g.DrawString("ALL NODES SYNCED", fStatus, bStatusText, pillX + 20, pillY + 3);
                }
            }
            frames[f] = bmp;
        }

        SaveGif(outputPath, frames, 50);
        string pngPath = outputPath.Replace(".gif", ".png");
        frames[0].Save(pngPath, ImageFormat.Png);

        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 2. Render Autonomous Systems Diagnostic HUD (telemetry.gif)
    public static void RenderTelemetryHUD(string outputPath, int totalFrames = 30) {
        int w = 840, h = 280;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Deep obsidian background
                using (var bBg = new SolidBrush(Color.FromArgb(7, 9, 14))) {
                    g.FillRectangle(bBg, 0, 0, w, h);
                }

                // 1. OUTER BORDER & CORNER ACCENTS
                using (var pBorder = new Pen(Color.FromArgb(30, 41, 59), 1f)) {
                    g.DrawRectangle(pBorder, 1, 1, w - 2, h - 2);
                }
                DrawCornerBrackets(g, 2, 2, w - 4, h - 4, Color.FromArgb(0, 240, 255), 10f);

                // Top accent stripe + continuous laser beam pulse
                using (var bTop = new SolidBrush(Color.FromArgb(20, 30, 48))) {
                    g.FillRectangle(bTop, 2, 2, w - 4, 2);
                }
                float beamX = t * (w + 80) - 40;
                using (var brushBeam = new LinearGradientBrush(
                    new RectangleF(beamX - 30, 2, 60, 2), Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, Color.FromArgb(220, 0, 240, 255), Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    brushBeam.InterpolationColors = cb;
                    g.FillRectangle(brushBeam, beamX - 30, 2, 60, 2);
                }

                // 2. CONSOLE HEADER BAR
                int headY = 8;
                using (var fHead = new Font("Consolas", 7.8f, FontStyle.Bold))
                using (var bHead = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                    g.DrawString("AUTONOMOUS ARCHITECTURE DIAGNOSTICS", fHead, bHead, 12, headY);
                }

                // Node Badge
                using (var bBadge = new SolidBrush(Color.FromArgb(15, 23, 42)))
                using (var pBadge = new Pen(Color.FromArgb(56, 189, 248), 1f))
                using (var fBadge = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var bBadgeT = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.FillRectangle(bBadge, 260, headY - 1, 142, 16);
                    g.DrawRectangle(pBadge, 260, headY - 1, 142, 16);
                    g.DrawString("NODE: IIT-MADRAS-LAB", fBadge, bBadgeT, 266, headY + 1);
                }

                // Right header telemetry
                float pulse = 0.65f + 0.35f * (float)Math.Sin(t * Math.PI * 2f);
                using (var fRight = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var bRight = new SolidBrush(Color.FromArgb(100, 116, 139)))
                using (var bDot = new SolidBrush(Color.FromArgb((int)(255 * pulse), 52, 211, 153)))
                using (var bStat = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("FREQ: 100Hz   |   FLUX: 1.2M t/s", fRight, bRight, w - 280, headY);
                    g.FillEllipse(bDot, w - 75, headY + 4, 6, 6);
                    g.DrawString("ONLINE", fRight, bStat, w - 65, headY);
                }

                // 3. TOP SUBSYSTEM CARDS (y: 28 to 166, height: 138px)
                int cardY = 28, cardH = 138;
                int cardW = 264;
                int[] cardXs = new int[] { 12, 288, 564 };

                Color[] accents = new Color[] {
                    Color.FromArgb(0, 240, 255),    // Cyan
                    Color.FromArgb(56, 189, 248),   // Sky Blue
                    Color.FromArgb(167, 139, 250)   // Purple
                };

                string[] titles = new string[] { "[01] PERCEPTION CORE", "[02] CAUSAL INFERENCE", "[03] ZERO-TRUST AST" };
                string[] subs = new string[] { "FaceTrack-AI // WASM-SIMD", "RootCause-IQ // Do-Calculus", "SkillGuard-OSS // Security" };
                string[] badges = new string[] { "60 FPS // PASS", "p < 0.001 // SOLVED", "0 LEAKS // VERIFIED" };

                // Oscillating yaw/pitch angles for Card 1
                float yaw = (float)Math.Sin(t * Math.PI * 2f) * 4.8f;
                float pitch = (float)Math.Cos(t * Math.PI * 2f) * 2.4f;

                string[][] cardDetails = new string[][] {
                    new string[] {
                        "> MODEL: 468-pt Mesh & Gaze Tensor",
                        String.Format("> 6-DoF: YAW {0:+0.0;-0.0} deg | PITCH {1:+0.0;-0.0} deg", yaw, pitch),
                        "> RUNTIME: WebAssembly SIMD (8.2ms)",
                        "> GAZE TENSOR: [-0.04, +0.12, +0.99]"
                    },
                    new string[] {
                        "> ARCH: Structural Causal Model",
                        "> VERTICES: 18 Active Causal Nodes",
                        "> DAG CONFIDENCE: p < 0.001 (Signif)",
                        "> LOCALIZATION: Lock Contention"
                    },
                    new string[] {
                        "> SCANNER: Static AST Engine",
                        "> POLICY: Zero-Trust Capability",
                        "> CHILDPROCESS: RESTRICTED -> PASS",
                        "> EVAL INTERCEPT: Blocked (0 Escapes)"
                    }
                };

                for (int c = 0; c < 3; c++) {
                    int cx = cardXs[c];

                    using (var bCard = new SolidBrush(Color.FromArgb(12, 17, 27)))
                    using (var pCard = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                        g.FillRectangle(bCard, cx, cardY, cardW, cardH);
                        g.DrawRectangle(pCard, cx, cardY, cardW, cardH);
                    }

                    // Top highlight accent line
                    using (var pTop = new Pen(Color.FromArgb(200, accents[c]), 1.5f)) {
                        g.DrawLine(pTop, cx + 4, cardY + 1, cx + cardW - 4, cardY + 1);
                    }

                    // Subsystem Title
                    using (var fT = new Font("Consolas", 8.2f, FontStyle.Bold))
                    using (var bT = new SolidBrush(accents[c])) {
                        g.DrawString(titles[c], fT, bT, cx + 8, cardY + 7);
                    }

                    // Subtitle / Tech pill
                    using (var fS = new Font("Consolas", 6.8f, FontStyle.Regular))
                    using (var bS = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString(subs[c], fS, bS, cx + 8, cardY + 23);
                    }

                    // Divider line inside card
                    using (var pIn = new Pen(Color.FromArgb(24, 32, 46), 1f)) {
                        g.DrawLine(pIn, cx + 8, cardY + 38, cx + cardW - 8, cardY + 38);
                    }

                    // Metric Lines
                    using (var fM = new Font("Consolas", 6.8f, FontStyle.Regular))
                    using (var bM = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                        for (int m = 0; m < 4; m++) {
                            g.DrawString(cardDetails[c][m], fM, bM, cx + 8, cardY + 44 + m * 16);
                        }
                    }

                    // Status Pill at bottom of card
                    using (var bPBg = new SolidBrush(Color.FromArgb(16, 24, 38)))
                    using (var pPB = new Pen(Color.FromArgb(70, accents[c]), 1f))
                    using (var fStat = new Font("Consolas", 6.5f, FontStyle.Bold))
                    using (var bStatT = new SolidBrush(accents[c])) {
                        g.FillRectangle(bPBg, cx + 8, cardY + 112, cardW - 16, 18);
                        g.DrawRectangle(pPB, cx + 8, cardY + 112, cardW - 16, 18);
                        g.DrawString(badges[c], fStat, bStatT, cx + 14, cardY + 115);
                    }
                }

                // 4. DIVIDER BEFORE OSCILLOSCOPE
                using (var pDiv = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawLine(pDiv, 12, 174, w - 12, 174);
                }

                // 5. BOTTOM SECTION: LIVE TENSOR STREAM & INFERENCE WAVEFORM (y: 180 to 272)
                int waveBoxX = 12, waveBoxY = 178, waveBoxW = w - 24;

                // Waveform Header
                using (var fWHead = new Font("Consolas", 7.8f, FontStyle.Bold))
                using (var bWHead = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                    g.DrawString("LIVE TENSOR FLUX & OSCILLOSCOPE", fWHead, bWHead, waveBoxX + 4, waveBoxY);
                }

                using (var fWInfo = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bWInfo = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("COMPUTE: 42.8 GFLOP/s   |   WASM FOOTPRINT: 38.4 MB   |   STABILITY: 99.98%", fWInfo, bWInfo, w - 485, waveBoxY);
                }

                // Inset Waveform Canvas (y: 196 to 254, height: 58px)
                int cX = waveBoxX, cY = waveBoxY + 17, cW = waveBoxW, cH = 58;
                using (var bIn = new SolidBrush(Color.FromArgb(5, 8, 13)))
                using (var pIn = new Pen(Color.FromArgb(24, 34, 48), 1f)) {
                    g.FillRectangle(bIn, cX, cY, cW, cH);
                    g.DrawRectangle(pIn, cX, cY, cW, cH);
                }

                // Horizontal center grid line + grid dashes
                using (var pGrid = new Pen(Color.FromArgb(18, 26, 38), 1f)) {
                    pGrid.DashStyle = DashStyle.Dash;
                    g.DrawLine(pGrid, cX, cY + cH / 2, cX + cW, cY + cH / 2);
                    for (int gx = cX + 60; gx < cX + cW; gx += 60) {
                        g.DrawLine(pGrid, gx, cY, gx, cY + cH);
                    }
                }

                // Draw Animated Waveforms
                float midY = cY + cH / 2f;
                int step = 3;
                int pointCount = cW / step + 1;
                PointF[] wave1 = new PointF[pointCount];
                PointF[] wave2 = new PointF[pointCount];
                PointF[] wave3 = new PointF[pointCount];

                for (int p = 0; p < pointCount; p++) {
                    float px = cX + p * step;
                    float phase1 = (float)(px * 0.038f + t * Math.PI * 2f);
                    float phase2 = (float)(px * 0.085f - t * Math.PI * 4f);
                    float phase3 = (float)(px * 0.022f - t * Math.PI * 2f);

                    float y1 = midY + (float)(Math.Sin(phase1) * 15.0f + Math.Sin(phase2) * 6.0f);
                    float y2 = midY + (float)(Math.Cos(phase3) * 11.0f + Math.Sin(phase1 * 0.7f) * 7.0f);
                    float y3 = midY + (float)(Math.Sin(phase3 * 1.4f) * 8.0f);

                    wave1[p] = new PointF(px, y1);
                    wave2[p] = new PointF(px, y2);
                    wave3[p] = new PointF(px, y3);
                }

                // Draw Wave 3 (Ambient Harmonic Mint)
                using (var pW3 = new Pen(Color.FromArgb(50, 52, 211, 153), 1f)) {
                    pW3.DashStyle = DashStyle.Dot;
                    g.DrawCurve(pW3, wave3, 0.5f);
                }

                // Draw Wave 2 (Causal Sky Blue)
                using (var pW2 = new Pen(Color.FromArgb(160, 56, 189, 248), 1.2f)) {
                    g.DrawCurve(pW2, wave2, 0.5f);
                }

                // Draw Wave 1 (Perception Cyan - Primary)
                using (var pW1 = new Pen(Color.FromArgb(230, 0, 240, 255), 1.5f)) {
                    g.DrawCurve(pW1, wave1, 0.5f);
                }

                // Vertical Frequency Sweep Line
                float sweepX = cX + t * cW;
                using (var pSweep = new Pen(Color.FromArgb(200, 0, 240, 255), 1.2f)) {
                    g.DrawLine(pSweep, sweepX, cY, sweepX, cY + cH);
                }

                // Bottom Status Footer (y: 261)
                using (var fFoot = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bFoot = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("[DIAGNOSTICS] ALL 3 SUBSYSTEMS CONVERGED  //  PIPELINE FLUX: ACTIVE  //  0 PACKET LOSS", fFoot, bFoot, waveBoxX + 4, cY + cH + 5);
                }
            }
            frames[f] = bmp;
        }

        SaveGif(outputPath, frames, 40);
        string pngPath = outputPath.Replace(".gif", ".png");
        frames[0].Save(pngPath, ImageFormat.Png);

        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 3. Render Robotics & Perception State HUD (contrib.gif)
    public static void RenderRoboticsHUD(string outputPath, int totalFrames = 30) {
        int w = 840, h = 160;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Deep obsidian background
                using (var bBg = new SolidBrush(Color.FromArgb(7, 9, 14))) {
                    g.FillRectangle(bBg, 0, 0, w, h);
                }

                // Outer border & corner accents
                using (var pBorder = new Pen(Color.FromArgb(30, 41, 59), 1f)) {
                    g.DrawRectangle(pBorder, 1, 1, w - 2, h - 2);
                }
                DrawCornerBrackets(g, 2, 2, w - 4, h - 4, Color.FromArgb(52, 211, 153), 8f);

                // Top accent stripe + laser pulse
                using (var bTop = new SolidBrush(Color.FromArgb(20, 30, 48))) {
                    g.FillRectangle(bTop, 2, 2, w - 4, 2);
                }
                float beamX = t * (w + 80) - 40;
                using (var brushBeam = new LinearGradientBrush(
                    new RectangleF(beamX - 25, 2, 50, 2), Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, Color.FromArgb(200, 52, 211, 153), Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    brushBeam.InterpolationColors = cb;
                    g.FillRectangle(brushBeam, beamX - 25, 2, 50, 2);
                }

                // Header Bar
                int headY = 7;
                using (var fHead = new Font("Consolas", 7.8f, FontStyle.Bold))
                using (var bHead = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                    g.DrawString("ROBOTICS & SPATIAL PERCEPTION TELEMETRY", fHead, bHead, 12, headY);
                }
                using (var fHSub = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bHSub = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("// 6-DoF ATTITUDE & 180 DEG LIDAR DEPTH SLICE", fHSub, bHSub, 296, headY + 1);
                }

                float pulse = 0.65f + 0.35f * (float)Math.Sin(t * Math.PI * 2f);
                using (var fRight = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var bDot = new SolidBrush(Color.FromArgb((int)(255 * pulse), 52, 211, 153)))
                using (var bRight = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("STATE: AUTONOMOUS", fRight, bRight, w - 240, headY);
                    g.FillEllipse(bDot, w - 105, headY + 4, 6, 6);
                    g.DrawString("[IITM-CAMPUS]", fRight, bRight, w - 95, headY);
                }

                // ================= ZONE 1: ATTITUDE INDICATOR (x: 10, y: 24, w: 264, h: 128) =================
                int z1X = 10, z1Y = 24, z1W = 264, z1H = 128;
                using (var bZ = new SolidBrush(Color.FromArgb(12, 17, 27)))
                using (var pZ = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.FillRectangle(bZ, z1X, z1Y, z1W, z1H);
                    g.DrawRectangle(pZ, z1X, z1Y, z1W, z1H);
                }
                using (var pTop = new Pen(Color.FromArgb(200, 0, 240, 255), 1.5f)) {
                    g.DrawLine(pTop, z1X + 4, z1Y + 1, z1X + z1W - 4, z1Y + 1);
                }
                using (var fZ1 = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var bZ1 = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                    g.DrawString("[01] ATTITUDE INDICATOR // 6-DoF", fZ1, bZ1, z1X + 8, z1Y + 6);
                }

                // Artificial Horizon Sub-Canvas (x: 18, y: 46, w: 114, h: 74)
                int ahX = z1X + 8, ahY = z1Y + 22, ahW = 114, ahH = 74;
                using (var bAh = new SolidBrush(Color.FromArgb(6, 10, 16)))
                using (var pAh = new Pen(Color.FromArgb(22, 30, 44), 1f)) {
                    g.FillRectangle(bAh, ahX, ahY, ahW, ahH);
                    g.DrawRectangle(pAh, ahX, ahY, ahW, ahH);
                }

                // Horizon Math
                float ahMidX = ahX + ahW / 2f;
                float ahMidY = ahY + ahH / 2f;
                float pitchDeg = (float)(Math.Sin(t * Math.PI * 2f) * 3.6f);
                float rollDeg = (float)(Math.Cos(t * Math.PI * 2f) * 4.8f);

                var prevTrans = g.Transform;
                var clipPrev = g.Clip;
                g.SetClip(new Rectangle(ahX + 1, ahY + 1, ahW - 2, ahH - 2));

                // Rotate and translate for horizon
                g.TranslateTransform(ahMidX, ahMidY);
                g.RotateTransform(rollDeg);
                g.TranslateTransform(0, pitchDeg * 1.8f);

                // Sky / Ground subtle divide
                using (var bSky = new SolidBrush(Color.FromArgb(25, 14, 40, 70))) {
                    g.FillRectangle(bSky, -ahW, -ahH, ahW * 2, ahH);
                }
                using (var bGnd = new SolidBrush(Color.FromArgb(25, 40, 30, 20))) {
                    g.FillRectangle(bGnd, -ahW, 0, ahW * 2, ahH);
                }

                // Horizon Center Line
                using (var pHoriz = new Pen(Color.FromArgb(0, 240, 255), 1.4f)) {
                    g.DrawLine(pHoriz, -45, 0, 45, 0);
                }
                // Pitch ladder bars
                using (var pLad = new Pen(Color.FromArgb(140, 0, 240, 255), 1f))
                using (var fLad = new Font("Consolas", 5.8f, FontStyle.Regular))
                using (var bLad = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawLine(pLad, -16, -16, 16, -16);
                    g.DrawString("+10", fLad, bLad, 18, -20);
                    g.DrawLine(pLad, -16, 16, 16, 16);
                    g.DrawString("-10", fLad, bLad, 18, 12);
                }

                g.Transform = prevTrans;
                g.Clip = clipPrev;

                // Center fixed aircraft reticle (stationary)
                using (var pRet = new Pen(Color.FromArgb(255, 255, 255), 1.5f)) {
                    g.DrawLine(pRet, ahMidX - 18, ahMidY, ahMidX - 5, ahMidY);
                    g.DrawLine(pRet, ahMidX + 5, ahMidY, ahMidX + 18, ahMidY);
                    g.DrawLine(pRet, ahMidX, ahMidY - 5, ahMidX, ahMidY - 2);
                    g.FillEllipse(new SolidBrush(Color.FromArgb(0, 240, 255)), ahMidX - 2, ahMidY - 2, 4, 4);
                }

                // Attitude Readouts (x: 132 to 264)
                int atX = z1X + 130, atY = z1Y + 24;
                using (var fA = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bA = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString(String.Format("PITCH: {0:+0.0;-0.0} deg", pitchDeg), fA, bA, atX, atY);
                    g.DrawString(String.Format("ROLL:  {0:+0.0;-0.0} deg", rollDeg), fA, bA, atX, atY + 16);
                    g.DrawString("YAW:   042.8 deg", fA, bA, atX, atY + 32);
                }

                // Gyro status pill
                using (var bGP = new SolidBrush(Color.FromArgb(16, 24, 38)))
                using (var pGP = new Pen(Color.FromArgb(70, 0, 240, 255), 1f))
                using (var fG = new Font("Consolas", 6.5f, FontStyle.Bold))
                using (var bG = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                    g.FillRectangle(bGP, atX, atY + 54, 118, 18);
                    g.DrawRectangle(pGP, atX, atY + 54, 118, 18);
                    g.DrawString("GYRO: STABLE", fG, bG, atX + 8, atY + 57);
                }

                // Bottom strip of Zone 1
                using (var fZ1Foot = new Font("Consolas", 6.2f, FontStyle.Regular))
                using (var bZ1Foot = new SolidBrush(Color.FromArgb(71, 85, 105))) {
                    g.DrawString("IMU: 100Hz KALMAN FILTERED", fZ1Foot, bZ1Foot, z1X + 8, z1Y + 108);
                }

                // ================= ZONE 2: 180 DEG SPATIAL LIDAR (x: 282, y: 24, w: 290, h: 128) =================
                int z2X = 282, z2Y = 24, z2W = 290, z2H = 128;
                using (var bZ = new SolidBrush(Color.FromArgb(12, 17, 27)))
                using (var pZ = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.FillRectangle(bZ, z2X, z2Y, z2W, z2H);
                    g.DrawRectangle(pZ, z2X, z2Y, z2W, z2H);
                }
                using (var pTop = new Pen(Color.FromArgb(200, 56, 189, 248), 1.5f)) {
                    g.DrawLine(pTop, z2X + 4, z2Y + 1, z2X + z2W - 4, z2Y + 1);
                }
                using (var fZ2 = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var bZ2 = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.DrawString("[02] 180 DEG SPATIAL LIDAR // 30m", fZ2, bZ2, z2X + 8, z2Y + 6);
                }

                // LIDAR Arc Display
                int lx = z2X + 115, ly = z2Y + 114; // Apex origin
                using (var pArc = new Pen(Color.FromArgb(26, 38, 56), 1f)) {
                    pArc.DashStyle = DashStyle.Dot;
                    g.DrawArc(pArc, lx - 28, ly - 28, 56, 56, 180, 180); // 10m
                    g.DrawArc(pArc, lx - 56, ly - 56, 112, 112, 180, 180); // 20m
                    g.DrawArc(pArc, lx - 84, ly - 84, 168, 168, 180, 180); // 30m
                    // Radial lines
                    g.DrawLine(pArc, lx, ly, lx - 84, ly);
                    g.DrawLine(pArc, lx, ly, lx + 84, ly);
                    g.DrawLine(pArc, lx, ly, lx, ly - 84);
                }

                // Range markers
                using (var fR = new Font("Consolas", 5.8f, FontStyle.Regular))
                using (var bR = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("10m", fR, bR, lx - 10, ly - 30);
                    g.DrawString("20m", fR, bR, lx - 10, ly - 58);
                    g.DrawString("30m", fR, bR, lx - 10, ly - 86);
                }

                // Sweep Ray Angle (oscillates from -72 deg to +72 deg)
                float sweepDeg = -72f + (float)(Math.Sin(t * Math.PI * 2f) * 72f);
                float sweepRad = (float)((sweepDeg - 90f) * Math.PI / 180f);
                float sEndX = lx + 84f * (float)Math.Cos(sweepRad);
                float sEndY = ly + 84f * (float)Math.Sin(sweepRad);

                // Draw Sweep Ray
                using (var pRay = new Pen(Color.FromArgb(220, 56, 189, 248), 1.4f)) {
                    g.DrawLine(pRay, lx, ly, sEndX, sEndY);
                }

                // Obstacle Targets in point cloud
                float[] tgtAngles = new float[] { -38f, +22f, +52f };
                float[] tgtDist = new float[] { 50f, 72f, 40f };

                for (int ob = 0; ob < 3; ob++) {
                    float obRad = (float)((tgtAngles[ob] - 90f) * Math.PI / 180f);
                    float obX = lx + tgtDist[ob] * (float)Math.Cos(obRad);
                    float obY = ly + tgtDist[ob] * (float)Math.Sin(obRad);

                    float diff = Math.Abs(sweepDeg - tgtAngles[ob]);
                    Color dotColor = Color.FromArgb(100, 56, 189, 248);
                    if (diff < 18f) {
                        dotColor = Color.FromArgb(255, 52, 211, 153);
                        using (var bBloom = new SolidBrush(Color.FromArgb(40, 52, 211, 153))) {
                            g.FillEllipse(bBloom, obX - 5, obY - 5, 10, 10);
                        }
                    }

                    using (var bDot = new SolidBrush(dotColor)) {
                        g.FillEllipse(bDot, obX - 2.5f, obY - 2.5f, 5, 5);
                    }
                }

                // LIDAR Telemetry side notes (x: z2X + 205)
                int ltx = z2X + 208, lty = z2Y + 26;
                using (var fL = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bL = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString("FOV: 180 deg", fL, bL, ltx, lty);
                    g.DrawString("48k pts/s", fL, bL, ltx, lty + 16);
                    g.DrawString("T1: 18m @-38", fL, bL, ltx, lty + 32);
                }
                using (var bSP = new SolidBrush(Color.FromArgb(16, 24, 38)))
                using (var pSP = new Pen(Color.FromArgb(70, 52, 211, 153), 1f))
                using (var fS = new Font("Consolas", 6.2f, FontStyle.Bold))
                using (var bS = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.FillRectangle(bSP, ltx, lty + 52, 74, 18);
                    g.DrawRectangle(pSP, ltx, lty + 52, 74, 18);
                    g.DrawString("100% CLEAR", fS, bS, ltx + 5, lty + 55);
                }

                // Bottom strip of Zone 2
                using (var fZ2Foot = new Font("Consolas", 6.2f, FontStyle.Regular))
                using (var bZ2Foot = new SolidBrush(Color.FromArgb(71, 85, 105))) {
                    g.DrawString("RANGE CONE: 30m ZERO OCCLUSION", fZ2Foot, bZ2Foot, z2X + 8, z2Y + 108);
                }

                // ================= ZONE 3: ACTUATION & NAV STATE (x: 580, y: 24, w: 250, h: 128) =================
                int z3X = 580, z3Y = 24, z3W = 250, z3H = 128;
                using (var bZ = new SolidBrush(Color.FromArgb(12, 17, 27)))
                using (var pZ = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.FillRectangle(bZ, z3X, z3Y, z3W, z3H);
                    g.DrawRectangle(pZ, z3X, z3Y, z3W, z3H);
                }
                using (var pTop = new Pen(Color.FromArgb(200, 167, 139, 250), 1.5f)) {
                    g.DrawLine(pTop, z3X + 4, z3Y + 1, z3X + z3W - 4, z3Y + 1);
                }
                using (var fZ3 = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var bZ3 = new SolidBrush(Color.FromArgb(167, 139, 250))) {
                    g.DrawString("[03] ACTUATION & NAV STATE", fZ3, bZ3, z3X + 8, z3Y + 6);
                }

                // 2 Control Bars
                string[] barLabels = new string[] { "LINEAR VEL", "ANGULAR RATE" };
                string[] barVals = new string[] { "1.85 m/s", "0.12 rad/s" };
                float[] barRatios = new float[] { 0.65f, 0.32f };
                Color[] barColors = new Color[] { Color.FromArgb(0, 240, 255), Color.FromArgb(56, 189, 248) };

                for (int b = 0; b < 2; b++) {
                    int by = z3Y + 22 + b * 24;
                    using (var fBL = new Font("Consolas", 6.8f, FontStyle.Regular))
                    using (var bBL = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString(barLabels[b], fBL, bBL, z3X + 8, by);
                    }
                    using (var fBV = new Font("Consolas", 6.8f, FontStyle.Bold))
                    using (var bBV = new SolidBrush(barColors[b])) {
                        g.DrawString(barVals[b], fBV, bBV, z3X + 172, by);
                    }
                    // Progress Bar
                    using (var bBgB = new SolidBrush(Color.FromArgb(16, 24, 38))) {
                        g.FillRectangle(bBgB, z3X + 8, by + 11, 230, 5);
                    }
                    using (var bFill = new SolidBrush(barColors[b])) {
                        g.FillRectangle(bFill, z3X + 8, by + 11, (int)(230 * barRatios[b]), 5);
                    }
                }

                // Waypoint info
                int wy = z3Y + 70;
                using (var fW = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bW = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString("> WAYPOINT: WP-04 [IITM-CAMPUS]", fW, bW, z3X + 8, wy);
                    g.DrawString("> PLANNER CONFIDENCE: 99.8%", fW, bW, z3X + 8, wy + 14);
                }

                // Status pill
                using (var bFP = new SolidBrush(Color.FromArgb(16, 24, 38)))
                using (var pFP = new Pen(Color.FromArgb(70, 52, 211, 153), 1f))
                using (var fF = new Font("Consolas", 6.5f, FontStyle.Bold))
                using (var bF = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.FillRectangle(bFP, z3X + 8, z3Y + 102, 232, 18);
                    g.DrawRectangle(pFP, z3X + 8, z3Y + 102, 232, 18);
                    g.DrawString("FAILSAFE: ZERO-FAULT ONLINE", fF, bF, z3X + 28, z3Y + 105);
                }
            }
            frames[f] = bmp;
        }

        SaveGif(outputPath, frames, 40);
        string pngPath = outputPath.Replace(".gif", ".png");
        frames[0].Save(pngPath, ImageFormat.Png);

        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing"

$assetsDir = "e:\Projects\Readme\assets"

Write-Host "Rendering Autonomous Systems Diagnostic Suite..."

Write-Host "1. Rendering banner_telemetry.gif..."
[AutonomousTelemetrySuite]::RenderBanner("$assetsDir\banner_telemetry.gif", 20)

Write-Host "2. Rendering telemetry.gif (Autonomous Systems Diagnostic HUD)..."
[AutonomousTelemetrySuite]::RenderTelemetryHUD("$assetsDir\telemetry.gif", 30)

Write-Host "3. Rendering contrib.gif (Robotics & Perception State HUD)..."
[AutonomousTelemetrySuite]::RenderRoboticsHUD("$assetsDir\contrib.gif", 30)

Write-Host "All autonomous diagnostic assets rendered successfully!"
Get-ChildItem $assetsDir\banner_telemetry.*, $assetsDir\telemetry.*, $assetsDir\contrib.* | Select-Object Name, Length

