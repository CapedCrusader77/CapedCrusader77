$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class TelemetrySuite {
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

    // 1. Render Banner
    public static void RenderBanner(string outputPath, int totalFrames = 20) {
        int w = 840, h = 36;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Background
                using (var bBg = new SolidBrush(Color.FromArgb(7, 9, 14))) {
                    g.FillRectangle(bBg, 0, 0, w, h);
                }

                // Outer border
                using (var pBorder = new Pen(Color.FromArgb(30, 41, 59), 1f)) {
                    g.DrawRectangle(pBorder, 1, 1, w - 2, h - 2);
                }

                // Left accent bar
                using (var bBar = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.FillRectangle(bBar, 4, 8, 3, 20);
                }

                // Title
                using (var fTitle = new Font("Segoe UI", 10.5f, FontStyle.Bold))
                using (var bTitle = new SolidBrush(Color.White)) {
                    g.DrawString("02 // OBSERVABILITY & TELEMETRY", fTitle, bTitle, 16, 7);
                }

                // Subtitle
                using (var fSub = new Font("Consolas", 8f, FontStyle.Regular))
                using (var bSub = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("// REAL-TIME METRICS & AUDIT ENGINE", fSub, bSub, 292, 10);
                }

                // Status pill (pulsing emerald)
                float pulse = 0.65f + 0.35f * (float)Math.Sin(t * Math.PI * 2f);
                int dotA = (int)(255 * pulse);
                int pillW = 142, pillH = 20;
                int pillX = w - pillW - 8, pillY = 8;
                using (var bPill = new SolidBrush(Color.FromArgb(15, 23, 42)))
                using (var pPill = new Pen(Color.FromArgb(51, 65, 85), 1f))
                using (var bDot = new SolidBrush(Color.FromArgb(dotA, 52, 211, 153)))
                using (var fStatus = new Font("Consolas", 7.2f, FontStyle.Bold))
                using (var bStatusText = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.FillRectangle(bPill, pillX, pillY, pillW, pillH);
                    g.DrawRectangle(pPill, pillX, pillY, pillW, pillH);
                    g.FillEllipse(bDot, pillX + 8, pillY + 6, 7, 7);
                    g.DrawString("SYSTEMS NOMINAL", fStatus, bStatusText, pillX + 20, pillY + 3);
                }
            }
            frames[f] = bmp;
        }

        SaveGif(outputPath, frames, 50);
        string pngPath = outputPath.Replace(".gif", ".png");
        frames[0].Save(pngPath, ImageFormat.Png);

        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 2. Render Main Observability Dashboard
    public static void RenderTelemetry(string outputPath, int totalFrames = 30) {
        int w = 840, h = 260;
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

                // 1. OUTER BORDER & TOP ACCENT BEAM
                using (var pBorder = new Pen(Color.FromArgb(30, 41, 59), 1f)) {
                    g.DrawRectangle(pBorder, 1, 1, w - 2, h - 2);
                }
                DrawCornerBrackets(g, 2, 2, w - 4, h - 4, Color.FromArgb(56, 189, 248), 10f);

                // Top accent stripe + laser beam sweep
                using (var bTop = new SolidBrush(Color.FromArgb(20, 30, 48))) {
                    g.FillRectangle(bTop, 2, 2, w - 4, 2);
                }
                float beamX = t * (w + 80) - 40;
                using (var brushBeam = new LinearGradientBrush(
                    new RectangleF(beamX - 30, 2, 60, 2), Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, Color.FromArgb(220, 56, 189, 248), Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    brushBeam.InterpolationColors = cb;
                    g.FillRectangle(brushBeam, beamX - 30, 2, 60, 2);
                }

                // 2. CONSOLE HEADER BAR
                int headY = 8;
                using (var fHead = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var bHead = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("METRICS_ENGINE // v2.4.0-PROD", fHead, bHead, 12, headY);
                }

                // Version badge
                using (var bBadge = new SolidBrush(Color.FromArgb(15, 23, 42)))
                using (var pBadge = new Pen(Color.FromArgb(56, 189, 248), 1f))
                using (var fBadge = new Font("Consolas", 6.8f, FontStyle.Bold))
                using (var bBadgeT = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.FillRectangle(bBadge, 184, headY - 1, 46, 16);
                    g.DrawRectangle(pBadge, 184, headY - 1, 46, 16);
                    g.DrawString("LIVE", fBadge, bBadgeT, 194, headY + 1);
                }

                // Right telemetry telemetry readout
                float lat = 11.2f + 0.4f * (float)Math.Sin(t * Math.PI * 2f);
                float pulse = 0.65f + 0.35f * (float)Math.Sin(t * Math.PI * 2f);
                using (var fRight = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var bRight = new SolidBrush(Color.FromArgb(100, 116, 139)))
                using (var bDot = new SolidBrush(Color.FromArgb((int)(255 * pulse), 52, 211, 153)))
                using (var bLat = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("CLUSTER: ASIA-SOUTH1   |   SYS HEALTH: 100%", fRight, bRight, w - 340, headY);
                    g.FillEllipse(bDot, w - 100, headY + 4, 6, 6);
                    g.DrawString(String.Format("LAT: {0:0.0}ms", lat), fRight, bLat, w - 90, headY);
                }

                // 3. TOP ROW: 4 KPI CARDS (y: 28 to 92)
                int cardY = 28, cardH = 64;
                int[] cardX = new int[] { 12, 218, 424, 630 };
                int cardW = 196;

                string[] labels = new string[] { "TOTAL STARS", "REPOSITORIES", "COMMUNITY", "YEARLY COMMITS" };
                string[] values = new string[] { "5", "15", "25", "264" };
                string[] subs = new string[] { "TOP OSS REPOSITORIES", "100% PUBLIC // CODE", "NETWORK FOLLOWERS", "PEAK DEV VELOCITY" };
                Color[] cardAccents = new Color[] {
                    Color.FromArgb(0, 240, 255),    // Cyan
                    Color.FromArgb(167, 139, 250),  // Purple
                    Color.FromArgb(56, 189, 248),   // Sky Blue
                    Color.FromArgb(52, 211, 153)    // Emerald
                };

                for (int k = 0; k < 4; k++) {
                    int cx = cardX[k];
                    int cw = (k == 3) ? 198 : cardW;

                    using (var bCard = new SolidBrush(Color.FromArgb(12, 17, 27)))
                    using (var pCard = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                        g.FillRectangle(bCard, cx, cardY, cw, cardH);
                        g.DrawRectangle(pCard, cx, cardY, cw, cardH);
                    }

                    // Top highlight line
                    using (var pTop = new Pen(Color.FromArgb(180, cardAccents[k]), 1.5f)) {
                        g.DrawLine(pTop, cx + 4, cardY + 1, cx + cw - 4, cardY + 1);
                    }

                    // Card Label
                    using (var fL = new Font("Consolas", 6.8f, FontStyle.Bold))
                    using (var bL = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString(labels[k], fL, bL, cx + 10, cardY + 7);
                    }

                    // Metric Value
                    using (var fV = new Font("Consolas", 15.5f, FontStyle.Bold))
                    using (var bV = new SolidBrush(cardAccents[k])) {
                        g.DrawString(values[k], fV, bV, cx + 8, cardY + 22);
                    }

                    // Subtitle
                    using (var fS = new Font("Segoe UI", 6.8f, FontStyle.Regular))
                    using (var bS = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                        g.DrawString(subs[k], fS, bS, cx + 10, cardY + 46);
                    }
                }

                // 4. DIVIDERS
                using (var pDiv = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawLine(pDiv, 12, 100, w - 12, 100);
                    g.DrawLine(pDiv, 416, 104, 416, h - 8);
                }

                // 5. LEFT COLUMN: PRODUCTION LANGUAGE DISTRIBUTION (x: 12, w: 394)
                int leftX = 12;
                using (var fLHead = new Font("Consolas", 7.8f, FontStyle.Bold))
                using (var bLHead = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                    g.DrawString("PRODUCTION LANGUAGE DISTRIBUTION", fLHead, bLHead, leftX + 4, 108);
                }
                using (var fLSub = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bLSub = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("// VERIFIED REPOSITORY PROFILE", fLSub, bLSub, leftX + 236, 109);
                }

                // Multi-Segment Stacked Progress Bar (y: 128, w: 390, h: 14)
                int barX = leftX + 4, barY = 128, barW = 390, barH = 14;
                using (var bBarBg = new SolidBrush(Color.FromArgb(15, 23, 42))) {
                    g.FillRectangle(bBarBg, barX, barY, barW, barH);
                }

                // Segments: TS 45%, PY 30%, JS 15%, SH 10%
                int wTS = (int)(barW * 0.45f);
                int wPY = (int)(barW * 0.30f);
                int wJS = (int)(barW * 0.15f);
                int wSH = barW - wTS - wPY - wJS;

                int curX = barX;
                using (var b1 = new SolidBrush(Color.FromArgb(0, 240, 255))) { g.FillRectangle(b1, curX, barY, wTS, barH); curX += wTS; }
                using (var b2 = new SolidBrush(Color.FromArgb(167, 139, 250))) { g.FillRectangle(b2, curX, barY, wPY, barH); curX += wPY; }
                using (var b3 = new SolidBrush(Color.FromArgb(56, 189, 248))) { g.FillRectangle(b3, curX, barY, wJS, barH); curX += wJS; }
                using (var b4 = new SolidBrush(Color.FromArgb(52, 211, 153))) { g.FillRectangle(b4, curX, barY, wSH, barH); }

                // Animated light shimmer sweep across the bar
                var prevClip = g.Clip;
                g.SetClip(new Rectangle(barX, barY, barW, barH));
                float shimX = barX + t * (barW + 80) - 40;
                using (var shimBrush = new LinearGradientBrush(
                    new RectangleF(shimX - 25, barY, 50, barH), Color.Transparent, Color.Transparent, 0f)) {
                    var cb = new ColorBlend(3);
                    cb.Colors = new Color[] { Color.Transparent, Color.FromArgb(160, 255, 255, 255), Color.Transparent };
                    cb.Positions = new float[] { 0f, 0.5f, 1f };
                    shimBrush.InterpolationColors = cb;
                    g.FillRectangle(shimBrush, shimX - 25, barY, 50, barH);
                }
                g.Clip = prevClip;

                // Language Detail Pills (2x2 Grid)
                string[] langNames = new string[] { "TypeScript", "Python", "JavaScript", "Shell / Other" };
                string[] langPcts = new string[] { "45.0%", "30.0%", "15.0%", "10.0%" };
                Color[] langCols = new Color[] {
                    Color.FromArgb(0, 240, 255),
                    Color.FromArgb(167, 139, 250),
                    Color.FromArgb(56, 189, 248),
                    Color.FromArgb(52, 211, 153)
                };

                int[] pillXs = new int[] { leftX + 4, leftX + 204, leftX + 4, leftX + 204 };
                int[] pillYs = new int[] { 152, 152, 180, 180 };

                for (int p = 0; p < 4; p++) {
                    int px = pillXs[p], py = pillYs[p];
                    using (var bPBg = new SolidBrush(Color.FromArgb(12, 17, 27)))
                    using (var pPB = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                        g.FillRectangle(bPBg, px, py, 190, 22);
                        g.DrawRectangle(pPB, px, py, 190, 22);
                    }

                    // Dot
                    using (var bDot = new SolidBrush(langCols[p])) {
                        g.FillEllipse(bDot, px + 8, py + 7, 7, 7);
                    }

                    // Name
                    using (var fN = new Font("Consolas", 7.2f, FontStyle.Regular))
                    using (var bN = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                        g.DrawString(langNames[p], fN, bN, px + 22, py + 4);
                    }

                    // Percent
                    using (var fP = new Font("Consolas", 7.5f, FontStyle.Bold))
                    using (var bP = new SolidBrush(langCols[p])) {
                        g.DrawString(langPcts[p], fP, bP, px + 140, py + 4);
                    }
                }

                // Left bottom sync footer
                using (var fSync = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bSync = new SolidBrush(Color.FromArgb(71, 85, 105))) {
                    g.DrawString("[SYNC] PRO ACCOUNT  //  15 PUBLIC REPOS  //  264 COMMITS VERIFIED", fSync, bSync, leftX + 4, 214);
                }

                // 6. RIGHT COLUMN: PIPELINE EVENT STREAM // LIVE (x: 428, w: 400)
                int rightX = 428;
                using (var fRHead = new Font("Consolas", 7.8f, FontStyle.Bold))
                using (var bRHead = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                    g.DrawString("PIPELINE EVENT STREAM // LIVE", fRHead, bRHead, rightX + 4, 108);
                }
                using (var fRSub = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bRSub = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("// CONTINUOUS INTEGRATION FEED", fRSub, bRSub, rightX + 210, 109);
                }

                string[] evTypes = new string[] { "PASS", "PASS", "PASS", "INFO", "INFO" };
                string[] evRepos = new string[] { "FaceTrack-AI", "SkillGuard-OSS", "RootCause-IQ", "ZeroDayHeist", "CarbonX" };
                string[] evDescs = new string[] {
                    "// 6-DoF WASM Deployed (60 FPS)",
                    "// Zero-Trust AST Rules Verified",
                    "// Causal Inference Engine Online",
                    "// 17 CTF Flags Captured",
                    "// Emissions Intelligence Pipeline Active"
                };

                for (int e = 0; e < 5; e++) {
                    int ey = 128 + e * 20;

                    // Event Badge
                    Color typeCol = (evTypes[e] == "PASS") ? Color.FromArgb(52, 211, 153) : Color.FromArgb(56, 189, 248);
                    using (var bEBg = new SolidBrush(Color.FromArgb(15, 23, 42)))
                    using (var pEB = new Pen(Color.FromArgb(60, typeCol), 1f))
                    using (var fType = new Font("Consolas", 6.5f, FontStyle.Bold))
                    using (var bType = new SolidBrush(typeCol)) {
                        g.FillRectangle(bEBg, rightX + 4, ey, 38, 16);
                        g.DrawRectangle(pEB, rightX + 4, ey, 38, 16);
                        g.DrawString(evTypes[e], fType, bType, rightX + 9, ey + 2);
                    }

                    // Repo name
                    using (var fRName = new Font("Consolas", 7.5f, FontStyle.Bold))
                    using (var bRName = new SolidBrush(Color.White)) {
                        g.DrawString(evRepos[e], fRName, bRName, rightX + 48, ey + 2);
                    }

                    // Repo details
                    using (var fRDesc = new Font("Consolas", 6.8f, FontStyle.Regular))
                    using (var bRDesc = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString(evDescs[e], fRDesc, bRDesc, rightX + 154, ey + 3);
                    }
                }

                // Right bottom stream status
                using (var fRStat = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bRStat = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("[STATUS] 5/5 PIPELINES ACTIVE  //  0 FAILING RUNS  //  ALL GATES PASSED", fRStat, bRStat, rightX + 4, 236);
                }
            }
            frames[f] = bmp;
        }

        SaveGif(outputPath, frames, 40);
        string pngPath = outputPath.Replace(".gif", ".png");
        frames[0].Save(pngPath, ImageFormat.Png);

        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 3. Render Modern Contribution Heatmap
    public static void RenderContrib(string outputPath, string matrixFile, int totalFrames = 26) {
        int w = 840, h = 160;
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
            Color.FromArgb(17, 24, 39),   // 0: no commits
            Color.FromArgb(6, 78, 59),    // 1: low
            Color.FromArgb(4, 120, 87),   // 2: med
            Color.FromArgb(16, 185, 129), // 3: high
            Color.FromArgb(52, 211, 153)  // 4: max
        };

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
                int headY = 8;
                using (var fHead = new Font("Consolas", 7.8f, FontStyle.Bold))
                using (var bHead = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                    g.DrawString("GIT ACTIVITY HEATMAP // 2025 - 2026", fHead, bHead, 12, headY);
                }

                using (var fRight = new Font("Consolas", 7.2f, FontStyle.Regular))
                using (var bRight = new SolidBrush(Color.FromArgb(52, 211, 153))) {
                    g.DrawString("264 CONTRIBUTIONS IN PAST 365 DAYS   |   STREAK: ACTIVE", fRight, bRight, w - 405, headY);
                }

                // Month Labels (y: 28)
                string[] months = new string[] { "Sep", "Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug" };
                int[] monthWeeks = new int[] { 0, 4, 8, 13, 17, 21, 25, 30, 34, 38, 43, 47 };
                int gridStartX = 52, gridStartY = 42;
                int pitch = 13, tileSize = 10;

                using (var fM = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bM = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    for (int m = 0; m < months.Length; m++) {
                        int mx = gridStartX + monthWeeks[m] * pitch;
                        g.DrawString(months[m], fM, bM, mx, 28);
                    }
                }

                // Day Labels (y: Mon, Wed, Fri)
                using (var fD = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bD = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("Mon", fD, bD, 18, gridStartY + 1 * pitch);
                    g.DrawString("Wed", fD, bD, 18, gridStartY + 3 * pitch);
                    g.DrawString("Fri", fD, bD, 18, gridStartY + 5 * pitch);
                }

                // Radar Scan position across the grid
                float scanX = gridStartX + t * (weeks * pitch);

                // Draw 53x7 Grid
                for (int c = 0; c < weeks; c++) {
                    int tx = gridStartX + c * pitch;
                    float dist = Math.Abs(tx - scanX);

                    for (int r = 0; r < days; r++) {
                        int ty = gridStartY + r * pitch;
                        int lvl = grid[c, r];
                        if (lvl > 4) lvl = 4;

                        Color baseC = tileColors[lvl];
                        // Ambient radar glow highlight if near scanX
                        if (dist < 32f) {
                            float factor = (1f - dist / 32f) * 0.45f;
                            int nr = Math.Min(255, (int)(baseC.R + 60 * factor));
                            int ng = Math.Min(255, (int)(baseC.G + 140 * factor));
                            int nb = Math.Min(255, (int)(baseC.B + 90 * factor));
                            baseC = Color.FromArgb(nr, ng, nb);
                        }

                        using (var bTile = new SolidBrush(baseC)) {
                            g.FillRectangle(bTile, tx, ty, tileSize, tileSize);
                        }
                    }
                }

                // Vertical Radar beam
                using (var scanPen = new Pen(Color.FromArgb(160, 52, 211, 153), 1.2f)) {
                    g.DrawLine(scanPen, scanX, gridStartY - 2, scanX, gridStartY + 7 * pitch + 2);
                }

                // Footer (y: 140)
                using (var fF = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bF = new SolidBrush(Color.FromArgb(71, 85, 105))) {
                    g.DrawString("[METRIC] AVG 0.72 COMMITS/DAY  //  PEAK: 4 COMMITS/DAY  //  VERIFIED GITHUB GRAPH", fF, bF, gridStartX, 140);
                }

                // Legend: Less ■ ■ ■ ■ More
                int legX = w - 170, legY = 140;
                using (var fL = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bL = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("Less", fL, bL, legX, legY);
                }
                for (int l = 0; l < 5; l++) {
                    using (var bLBox = new SolidBrush(tileColors[l])) {
                        g.FillRectangle(bLBox, legX + 32 + l * 14, legY + 1, 9, 9);
                    }
                }
                using (var fM = new Font("Consolas", 6.8f, FontStyle.Regular))
                using (var bM = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("More", fM, bM, legX + 108, legY);
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

Write-Host "Rendering modern Linear/Datadog Telemetry suite..."

Write-Host "1. Rendering banner_telemetry.gif..."
[TelemetrySuite]::RenderBanner("$assetsDir\banner_telemetry.gif", 20)

Write-Host "2. Rendering telemetry.gif (Observability Console)..."
[TelemetrySuite]::RenderTelemetry("$assetsDir\telemetry.gif", 30)

Write-Host "3. Rendering contrib.gif (Modern Git Activity Heatmap)..."
$matrixFile = "e:\Projects\Readme\real_contrib_matrix.txt"
[TelemetrySuite]::RenderContrib("$assetsDir\contrib.gif", $matrixFile, 26)

Write-Host "All modern telemetry assets rendered successfully!"
Get-ChildItem $assetsDir\banner_telemetry.*, $assetsDir\telemetry.*, $assetsDir\contrib.* | Select-Object Name, Length
