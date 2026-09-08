$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class SimpleGif {
    public static void CreateAnimatedGif(string outputPath, Bitmap[] frames, int delayMs) {
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


public class KeyframeExporter {
    public static void ExportKeyframes(string dir) {
        float[] times = new float[] { 0.8f, 2.0f, 3.2f, 4.4f, 5.4f, 6.6f, 7.4f };
        string[] names = new string[] {
            "phase1-calibration",
            "phase2-laser-scan",
            "phase3-robotic-vision",
            "phase4-typography",
            "phase5-neural-propagation",
            "phase6-lidar-sweep",
            "phase7-system-online"
        };

        for (int i = 0; i < times.Length; i++) {
            float t = times[i];
            var bmp = new Bitmap(960, 400, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                RenderSingleFrame(g, 960, 400, t);
            }
            string path = Path.Combine(dir, "keyframe-" + names[i] + ".png");
            bmp.Save(path, ImageFormat.Png);
            bmp.Dispose();
            Console.WriteLine("Saved: " + path);
        }
    }

    public static void RenderOptimizedGif(string outputPath) {
        int w = 840;
        int h = 350;
        int totalFrames = 54; // 54 frames * 148ms = ~8.0s loop
        int delayMs = 148;

        Console.WriteLine("Rendering optimized GIF (840x350, 54 frames)...");
        var frames = new Bitmap[totalFrames];
        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames * 8.0f;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                RenderSingleFrame(g, w, h, t);
            }
            frames[f] = bmp;
        }

        SimpleGif.CreateAnimatedGif(outputPath, frames, delayMs);
        for (int f = 0; f < totalFrames; f++) {
            frames[f].Dispose();
        }
        Console.WriteLine("Optimized GIF saved to: " + outputPath);
    }

    private static float SmoothStep(float min, float max, float value) {
        float x = Math.Max(0.0f, Math.Min(1.0f, (value - min) / (max - min)));
        return x * x * (3.0f - 2.0f * x);
    }

    private static void RenderSingleFrame(Graphics g, int WIDTH, int HEIGHT, float t) {
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;

        float scaleX = (float)WIDTH / 960.0f;
        float scaleY = (float)HEIGHT / 400.0f;
        float robotX = 720.0f * scaleX;
        float robotY = 195.0f * scaleY;

        // Base background
        using (var brushBg = new SolidBrush(Color.FromArgb(7, 9, 14))) {
            g.FillRectangle(brushBg, 0, 0, WIDTH, HEIGHT);
        }

        // Radial glow background
        using (var path = new GraphicsPath()) {
            path.AddEllipse(-100, -100, WIDTH + 200, HEIGHT + 200);
            using (var pgb = new PathGradientBrush(path)) {
                pgb.CenterPoint = new PointF(robotX - 100 * scaleX, robotY);
                pgb.CenterColor = Color.FromArgb(28, 20, 55);
                pgb.SurroundColors = new Color[] { Color.FromArgb(7, 9, 14) };
                g.FillRectangle(pgb, 0, 0, WIDTH, HEIGHT);
            }
        }

        // Grid & Ticks
        float gridAlpha = t < 1.0f ? SmoothStep(0.0f, 0.9f, t) : (t > 7.6f ? SmoothStep(8.0f, 7.6f, t) * 0.6f + 0.4f : 1.0f);
        int gridCol = (int)(32 * gridAlpha);
        using (var penGrid = new Pen(Color.FromArgb(gridCol, 139, 92, 246), 1)) {
            int step = (int)(32 * scaleX);
            for (int x = 0; x <= WIDTH; x += step) g.DrawLine(penGrid, x, 0, x, HEIGHT);
            for (int y = 0; y <= HEIGHT; y += step) g.DrawLine(penGrid, 0, y, WIDTH, y);
        }

        // Cross markers
        int crossCol = (int)(70 * gridAlpha);
        using (var penCross = new Pen(Color.FromArgb(crossCol, 0, 240, 255), 1)) {
            for (int x = (int)(64 * scaleX); x < WIDTH; x += (int)(96 * scaleX)) {
                for (int y = (int)(32 * scaleY); y < HEIGHT; y += (int)(64 * scaleY)) {
                    g.DrawLine(penCross, x - 3, y, x + 3, y);
                    g.DrawLine(penCross, x, y - 3, x, y + 3);
                }
            }
        }

        // Fonts
        using (var fontTitle = new Font("Segoe UI", 34 * scaleX, FontStyle.Bold))
        using (var fontSub = new Font("Consolas", 10.0f * scaleX, FontStyle.Bold))
        using (var fontTag = new Font("Consolas", 8.0f * scaleX, FontStyle.Bold))
        using (var fontMicro = new Font("Consolas", 7.0f * scaleX, FontStyle.Regular))
        using (var fontHud = new Font("Consolas", 8.5f * scaleX, FontStyle.Regular)) {

            // Scan Beam
            if (t >= 1.0f && t <= 2.4f) {
                float scanNorm = (t - 1.0f) / 1.4f;
                float scanX = scanNorm * (WIDTH + 200) - 100;
                using (var brushBeam = new LinearGradientBrush(
                    new PointF(scanX - 100, 0), new PointF(scanX + 20, 0),
                    Color.FromArgb(0, 139, 92, 246), Color.FromArgb(140, 0, 240, 255))) {
                    g.FillRectangle(brushBeam, scanX - 100, 0, 120, HEIGHT);
                }
                using (var penLaser = new Pen(Color.FromArgb(220, 255, 255, 255), 2)) {
                    g.DrawLine(penLaser, scanX + 20, 0, scanX + 20, HEIGHT);
                }
            }

            // Robot Prototype
            float robotAlpha = SmoothStep(2.0f, 3.2f, t);
            if (robotAlpha > 0.01f) {
                int rAlpha = (int)(255 * robotAlpha);

                using (var penGimbal = new Pen(Color.FromArgb((int)(110 * robotAlpha), 139, 92, 246), 1.5f)) {
                    g.DrawEllipse(penGimbal, robotX - 130 * scaleX, robotY - 95 * scaleY, 260 * scaleX, 190 * scaleY);
                }
                using (var penPitch = new Pen(Color.FromArgb((int)(120 * robotAlpha), 0, 240, 255), 1.2f)) {
                    g.DrawEllipse(penPitch, robotX - 105 * scaleX, robotY - 75 * scaleY, 210 * scaleX, 150 * scaleY);
                }

                var hexPts = new PointF[6];
                float hexRadius = 50.0f * scaleX;
                for (int i = 0; i < 6; i++) {
                    float a = (float)(i * 60.0 * Math.PI / 180.0);
                    hexPts[i] = new PointF(robotX + (float)Math.Cos(a) * hexRadius, robotY + (float)Math.Sin(a) * hexRadius * 0.9f);
                }
                using (var brushHex = new SolidBrush(Color.FromArgb((int)(200 * robotAlpha), 14, 18, 28)))
                using (var penHex = new Pen(Color.FromArgb(rAlpha, 139, 92, 246), 2.0f)) {
                    g.FillPolygon(brushHex, hexPts);
                    g.DrawPolygon(penHex, hexPts);
                }

                float mainRadius = 24.0f * scaleX;
                using (var pathLens = new GraphicsPath()) {
                    pathLens.AddEllipse(robotX - mainRadius, robotY - mainRadius, mainRadius * 2, mainRadius * 2);
                    using (var pgbLens = new PathGradientBrush(pathLens)) {
                        pgbLens.CenterPoint = new PointF(robotX - 6 * scaleX, robotY - 6 * scaleY);
                        pgbLens.CenterColor = Color.FromArgb(rAlpha, 0, 240, 255);
                        pgbLens.SurroundColors = new Color[] { Color.FromArgb(rAlpha, 15, 23, 42) };
                        g.FillEllipse(pgbLens, robotX - mainRadius, robotY - mainRadius, mainRadius * 2, mainRadius * 2);
                    }
                }
                using (var penAperture = new Pen(Color.FromArgb(rAlpha, 0, 240, 255), 2.0f)) {
                    g.DrawEllipse(penAperture, robotX - mainRadius, robotY - mainRadius, mainRadius * 2, mainRadius * 2);
                }

                using (var brushStereo = new SolidBrush(Color.FromArgb((int)(160 * robotAlpha), 6, 182, 212)))
                using (var penStereo = new Pen(Color.FromArgb(rAlpha, 6, 182, 212), 1.2f)) {
                    g.FillEllipse(brushStereo, robotX - 42 * scaleX - 9 * scaleX, robotY - 10 * scaleY - 9 * scaleY, 18 * scaleX, 18 * scaleY);
                    g.DrawEllipse(penStereo, robotX - 42 * scaleX - 9 * scaleX, robotY - 10 * scaleY - 9 * scaleY, 18 * scaleX, 18 * scaleY);

                    g.FillEllipse(brushStereo, robotX + 42 * scaleX - 9 * scaleX, robotY - 10 * scaleY - 9 * scaleY, 18 * scaleX, 18 * scaleY);
                    g.DrawEllipse(penStereo, robotX + 42 * scaleX - 9 * scaleX, robotY - 10 * scaleY - 9 * scaleY, 18 * scaleX, 18 * scaleY);
                }

                using (var brushLidar = new SolidBrush(Color.FromArgb((int)(220 * robotAlpha), 17, 24, 39)))
                using (var penLidar = new Pen(Color.FromArgb(rAlpha, 168, 85, 247), 1.5f)) {
                    g.FillRectangle(brushLidar, robotX - 26 * scaleX, robotY - 65 * scaleY, 52 * scaleX, 20 * scaleY);
                    g.DrawRectangle(penLidar, robotX - 26 * scaleX, robotY - 65 * scaleY, 52 * scaleX, 20 * scaleY);
                }
                using (var brushLed = new SolidBrush(Color.FromArgb(rAlpha, 0, 240, 255))) {
                    g.FillEllipse(brushLed, robotX - 3 * scaleX, robotY - 57 * scaleY, 6 * scaleX, 6 * scaleY);
                }

                using (var brushIr = new SolidBrush(Color.FromArgb((int)(140 * robotAlpha), 139, 92, 246)))
                using (var penIr = new Pen(Color.FromArgb(rAlpha, 139, 92, 246), 1.0f)) {
                    g.FillRectangle(brushIr, robotX - 18 * scaleX, robotY + 24 * scaleY, 36 * scaleX, 8 * scaleY);
                    g.DrawRectangle(penIr, robotX - 18 * scaleX, robotY + 24 * scaleY, 36 * scaleX, 8 * scaleY);
                }
            }

            // CV Bounding Boxes
            float cvAlpha = SmoothStep(2.8f, 3.6f, t);
            if (cvAlpha > 0.01f) {
                int cva = (int)(255 * cvAlpha);
                DrawBox(g, robotX - 80 * scaleX, robotY - 78 * scaleY, 160 * scaleX, 138 * scaleY, "SENSOR_RIG_01 // 99.4%", Color.FromArgb(cva, 0, 240, 255), fontTag);
                DrawBox(g, robotX - 36 * scaleX, robotY - 36 * scaleY, 72 * scaleX, 72 * scaleY, "TRACK_ID:#077", Color.FromArgb(cva, 139, 92, 246), fontTag);

                using (var penRet = new Pen(Color.FromArgb((int)(150 * cvAlpha), 0, 240, 255), 1.0f)) {
                    g.DrawEllipse(penRet, robotX - 42 * scaleX, robotY - 42 * scaleY, 84 * scaleX, 84 * scaleY);
                    penRet.DashStyle = DashStyle.Dash;
                    g.DrawLine(penRet, robotX - 60 * scaleX, robotY, robotX + 60 * scaleX, robotY);
                    g.DrawLine(penRet, robotX, robotY - 60 * scaleY, robotX, robotY + 60 * scaleY);
                }

                using (var brushCv = new SolidBrush(Color.FromArgb(cva, 0, 240, 255))) {
                    string metric1 = string.Format("X:{0:F3}m  Y:{1:F3}m  Z:0.842m", 1.24f + Math.Sin(t) * 0.04f, -0.18f + Math.Cos(t) * 0.03f);
                    g.DrawString(metric1, fontMicro, brushCv, robotX - 80 * scaleX, robotY + 66 * scaleY);
                    g.DrawString("CONF: 99.8%  IOU: 0.94  FPS: 120.0", fontMicro, brushCv, robotX - 80 * scaleX, robotY + 77 * scaleY);
                }
            }

            // LiDAR Radar Sweep & Points
            float lidarAlpha = SmoothStep(5.2f, 6.2f, t);
            if (lidarAlpha > 0.01f) {
                float sweepAngle = (t * 2.2f) % (float)(Math.PI * 2.0);
                using (var penBeam = new Pen(Color.FromArgb((int)(220 * lidarAlpha), 0, 240, 255), 1.5f)) {
                    g.DrawLine(penBeam, robotX, robotY, robotX + (float)Math.Cos(sweepAngle) * 140.0f * scaleX, robotY + (float)Math.Sin(sweepAngle) * 140.0f * scaleY);
                }

                for (int i = 0; i < 60; i++) {
                    float angle = (float)(i * (360.0 / 60.0));
                    float rad = (float)(angle * Math.PI / 180.0);
                    float baseDist = 65.0f + (float)(Math.Sin(angle * 0.08f) * 28.0f + Math.Cos(angle * 0.15f) * 18.0f);
                    float lx = robotX + (float)Math.Cos(rad) * baseDist * 1.25f * scaleX;
                    float ly = robotY + (float)Math.Sin(rad) * baseDist * 0.85f * scaleY;

                    float angleDiff = (float)Math.Abs((rad - sweepAngle + Math.PI * 4.0) % (Math.PI * 2.0));
                    float hit = angleDiff < 0.6f ? 1.0f - (angleDiff / 0.6f) : 0.18f;
                    int ptAlpha = (int)(255 * hit * lidarAlpha);
                    ptAlpha = Math.Max(0, Math.Min(255, ptAlpha));

                    Color ptCol = hit > 0.5f ? Color.FromArgb(ptAlpha, 0, 240, 255) : Color.FromArgb(ptAlpha, 139, 92, 246);
                    using (var brushPt = new SolidBrush(ptCol)) {
                        float size = (hit > 0.5f ? 2.5f : 1.5f) * scaleX;
                        g.FillEllipse(brushPt, lx - size / 2, ly - size / 2, size, size);
                    }
                }
            }

            // Neural Net Synapses & Nodes
            float neuralAlpha = SmoothStep(4.2f, 5.0f, t);
            if (neuralAlpha > 0.01f) {
                int na = (int)(180 * neuralAlpha);
                var layerXs = new float[] { 540f * scaleX, 615f * scaleX, 695f * scaleX, 775f * scaleX, 850f * scaleX };
                var layerYs = new float[][] {
                    new float[] { 130f * scaleY, 190f * scaleY, 250f * scaleY },
                    new float[] { 105f * scaleY, 160f * scaleY, 220f * scaleY, 275f * scaleY },
                    new float[] { 85f * scaleY, 140f * scaleY, 195f * scaleY, 250f * scaleY, 305f * scaleY },
                    new float[] { 120f * scaleY, 190f * scaleY, 260f * scaleY },
                    new float[] { 150f * scaleY, 230f * scaleY }
                };

                for (int l = 0; l < layerXs.Length - 1; l++) {
                    float x1 = layerXs[l]; float x2 = layerXs[l + 1];
                    var ys1 = layerYs[l]; var ys2 = layerYs[l + 1];

                    for (int i = 0; i < ys1.Length; i++) {
                        for (int j = 0; j < ys2.Length; j++) {
                            using (var penSyn = new Pen(Color.FromArgb((int)(40 * neuralAlpha), 139, 92, 246), 1.0f)) {
                                g.DrawLine(penSyn, x1, ys1[i], x2, ys2[j]);
                            }

                            if (t >= 4.4f && t <= 6.2f) {
                                float pulseTime = (t - 4.4f) * 1.8f;
                                float pDelay = l * 0.2f;
                                float prog = pulseTime - pDelay;
                                if (prog >= 0.0f && prog <= 1.0f) {
                                    float px = x1 + (x2 - x1) * prog;
                                    float py = ys1[i] + (ys2[j] - ys1[i]) * prog;
                                    using (var brushPulse = new SolidBrush(Color.FromArgb(240, 0, 240, 255))) {
                                        g.FillEllipse(brushPulse, px - 2, py - 2, 4 * scaleX, 4 * scaleY);
                                    }
                                }
                            }
                        }
                    }
                }

                for (int l = 0; l < layerXs.Length; l++) {
                    float x = layerXs[l];
                    foreach (float y in layerYs[l]) {
                        using (var brushNodeBg = new SolidBrush(Color.FromArgb(na, 15, 23, 42)))
                        using (var penNode = new Pen(Color.FromArgb(na, 139, 92, 246), 1.2f))
                        using (var brushCore = new SolidBrush(Color.FromArgb(na, 0, 240, 255))) {
                            g.FillEllipse(brushNodeBg, x - 4 * scaleX, y - 4 * scaleY, 8 * scaleX, 8 * scaleY);
                            g.DrawEllipse(penNode, x - 4 * scaleX, y - 4 * scaleY, 8 * scaleX, 8 * scaleY);
                            g.FillEllipse(brushCore, x - 1.5f * scaleX, y - 1.5f * scaleY, 3 * scaleX, 3 * scaleY);
                        }
                    }
                }
            }

            // Typography & Branding (100% Stagnant Throughout)
            float textAlpha = 1.0f;
            if (true) {
                int ta = (int)(255 * textAlpha);

                using (var brushTag = new SolidBrush(Color.FromArgb(ta, 139, 92, 246))) {
                    g.DrawString("[ NEURAL CONTROL LAB // BUILD 077 ]", fontTag, brushTag, 54 * scaleX, 52 * scaleY);
                }
                using (var brushDot = new SolidBrush(Color.FromArgb(ta, 0, 240, 255))) {
                    g.FillEllipse(brushDot, 42 * scaleX, 53 * scaleY, 6 * scaleX, 6 * scaleY);
                }

                using (var brushGlow = new SolidBrush(Color.FromArgb((int)(90 * textAlpha), 139, 92, 246))) {
                    g.DrawString("CAPEDCRUSADER77", fontTitle, brushGlow, 52 * scaleX, 86 * scaleY);
                    g.DrawString("CAPEDCRUSADER77", fontTitle, brushGlow, 50 * scaleX, 88 * scaleY);
                }
                using (var brushMain = new SolidBrush(Color.FromArgb(ta, 255, 255, 255))) {
                    g.DrawString("CAPEDCRUSADER77", fontTitle, brushMain, 50 * scaleX, 84 * scaleY);
                }

                using (var brushSub = new SolidBrush(Color.FromArgb(ta, 0, 240, 255))) {
                    g.DrawString("AI ENGINEER // ROBOTICS // COMPUTER VISION", fontSub, brushSub, 52 * scaleX, 150 * scaleY);
                }

                // Pipeline
                var stages = new[] {
                    new { Name = "PERCEPTION", Phase = 4.6f },
                    new { Name = "DECISION", Phase = 5.1f },
                    new { Name = "ACTION", Phase = 5.6f }
                };
                float curPx = 52 * scaleX;
                for (int i = 0; i < stages.Length; i++) {
                    var st = stages[i];
                    bool active = (t >= st.Phase && t <= 7.6f);
                    Color col = active ? Color.FromArgb(0, 240, 255) : Color.FromArgb(148, 163, 184);
                    using (var brushPText = new SolidBrush(col)) {
                        g.DrawString(st.Name, fontSub, brushPText, curPx, 182 * scaleY);
                    }
                    curPx += g.MeasureString(st.Name, fontSub).Width + 6;
                    if (i < stages.Length - 1) {
                        Color arrCol = (t >= st.Phase + 0.25f) ? Color.FromArgb(139, 92, 246) : Color.FromArgb(80, 148, 163, 184);
                        using (var brushArr = new SolidBrush(arrCol)) {
                            g.DrawString("→", fontSub, brushArr, curPx, 182 * scaleY);
                        }
                        curPx += 18 * scaleX;
                    }
                }

                // Badges
                string[] badgeTexts = new string[] {
                    "ROS2 // ACTIVE",
                    "EDGE INFERENCE",
                    "AUTONOMOUS SYSTEMS",
                    "SENSOR ARRAY"
                };
                Color[] badgeColors = new Color[] {
                    Color.FromArgb(0, 240, 255),
                    Color.FromArgb(139, 92, 246),
                    Color.FromArgb(56, 189, 248),
                    Color.FromArgb(192, 132, 252)
                };

                float bX = 52 * scaleX;
                float bY = 238 * scaleY;
                for (int i = 0; i < badgeTexts.Length; i++) {
                    string bText = badgeTexts[i];
                    Color bCol = badgeColors[i];
                    var size = g.MeasureString(bText, fontTag);

                    using (var brushPill = new SolidBrush(Color.FromArgb(180, 13, 17, 26)))
                    using (var penPill = new Pen(Color.FromArgb(ta, bCol), 1.0f))
                    using (var brushPip = new SolidBrush(Color.FromArgb(ta, bCol)))
                    using (var brushPillText = new SolidBrush(Color.FromArgb(ta, 248, 250, 252))) {
                        g.FillRectangle(brushPill, bX, bY, size.Width + 18, 20 * scaleY);
                        g.DrawRectangle(penPill, bX, bY, size.Width + 18, 20 * scaleY);
                        g.FillEllipse(brushPip, bX + 5, bY + 7 * scaleY, 4 * scaleX, 4 * scaleY);
                        g.DrawString(bText, fontTag, brushPillText, bX + 13, bY + 3 * scaleY);
                    }
                    bX += size.Width + 24 * scaleX;
                }
            }

            // Telemetry Footer
            float sysAlpha = SmoothStep(6.6f, 7.4f, t);
            using (var brushBar = new SolidBrush(Color.FromArgb(230, 9, 13, 22)))
            using (var penBar = new Pen(Color.FromArgb(80, 30, 41, 59), 1)) {
                g.FillRectangle(brushBar, 0, HEIGHT - 32, WIDTH, 32);
                g.DrawLine(penBar, 0, HEIGHT - 32, WIDTH, HEIGHT - 32);
            }

            bool isOnline = (t >= 6.8f && t <= 7.8f);
            using (var brushStatus = new SolidBrush(isOnline ? Color.FromArgb(0, 240, 255) : Color.FromArgb(148, 163, 184)))
            using (var brushTelem = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                g.DrawString(isOnline ? "● SYSTEM ONLINE" : "◐ RUNNING CALIBRATION", fontHud, brushStatus, 52 * scaleX, HEIGHT - 20);
                g.DrawString("|  INFERENCE: 3.2ms", fontHud, brushTelem, 220 * scaleX, HEIGHT - 20);
                g.DrawString("|  CUDA: 12.4", fontHud, brushTelem, 420 * scaleX, HEIGHT - 20);
                g.DrawString("|  FRAME: 120 FPS", fontHud, brushTelem, 570 * scaleX, HEIGHT - 20);
                g.DrawString("|  PERCEPTION: ACTIVE", fontHud, brushTelem, 710 * scaleX, HEIGHT - 20);
            }

            // Phase 7 Card
            if (sysAlpha > 0.01f) {
                float cardFade = t > 7.7f ? SmoothStep(8.0f, 7.7f, t) : 1.0f;
                int ca = (int)(255 * sysAlpha * cardFade);

                using (var brushCard = new SolidBrush(Color.FromArgb(ca, 13, 17, 26)))
                using (var penCard = new Pen(Color.FromArgb(ca, 0, 240, 255), 1.5f)) {
                    g.FillRectangle(brushCard, 52 * scaleX, 276 * scaleY, 400 * scaleX, 32 * scaleY);
                    g.DrawRectangle(penCard, 52 * scaleX, 276 * scaleY, 400 * scaleX, 32 * scaleY);
                }

                using (var brushV = new SolidBrush(Color.FromArgb(ca, 0, 240, 255)))
                using (var brushR = new SolidBrush(Color.FromArgb(ca, 139, 92, 246)))
                using (var brushA = new SolidBrush(Color.FromArgb(ca, 34, 211, 238))) {
                    g.DrawString("VISION: ACTIVE", fontSub, brushV, 64 * scaleX, 284 * scaleY);
                    g.DrawString("ROBOTICS: ACTIVE", fontSub, brushR, 192 * scaleX, 284 * scaleY);
                    g.DrawString("AI CORE: ONLINE", fontSub, brushA, 332 * scaleX, 284 * scaleY);
                }
            }

            // HUD Corners
            using (var penHud = new Pen(Color.FromArgb(90, 139, 92, 246), 1.5f)) {
                int m = 8; int s = 14;
                g.DrawLine(penHud, m, m + s, m, m); g.DrawLine(penHud, m, m + s, m, m);
                g.DrawLine(penHud, WIDTH - m - s, m, WIDTH - m, m); g.DrawLine(penHud, WIDTH - m, m, WIDTH - m, m + s);
                g.DrawLine(penHud, m, HEIGHT - m - s, m, HEIGHT - m); g.DrawLine(penHud, m, HEIGHT - m, m + s, HEIGHT - m);
                g.DrawLine(penHud, WIDTH - m - s, HEIGHT - m, WIDTH - m, HEIGHT - m); g.DrawLine(penHud, WIDTH - m, HEIGHT - m, WIDTH - m, HEIGHT - m - s);
            }
        }
    }

    private static void DrawBox(Graphics g, float x, float y, float w, float h, string label, Color color, Font font) {
        float cornerLen = 8;
        using (var penCorner = new Pen(color, 1.5f))
        using (var penFaint = new Pen(Color.FromArgb(60, color), 1.0f)) {
            g.DrawLine(penCorner, x, y + cornerLen, x, y);
            g.DrawLine(penCorner, x, y, x + cornerLen, y);
            g.DrawLine(penCorner, x + w - cornerLen, y, x + w, y);
            g.DrawLine(penCorner, x + w, y, x + w, y + cornerLen);
            g.DrawLine(penCorner, x, y + h - cornerLen, x, y + h);
            g.DrawLine(penCorner, x, y + h, x + cornerLen, y + h);
            g.DrawLine(penCorner, x + w - cornerLen, y + h, x + w, y + h);
            g.DrawLine(penCorner, x + w, y + h, x + w, y + h - cornerLen);
            g.DrawRectangle(penFaint, x, y, w, h);
        }

        var size = g.MeasureString(label, font);
        using (var brushLabelBg = new SolidBrush(color))
        using (var brushLabelText = new SolidBrush(Color.FromArgb(7, 9, 14))) {
            g.FillRectangle(brushLabelBg, x, y - 13, size.Width + 5, 13);
            g.DrawString(label, font, brushLabelText, x + 2, y - 12);
        }
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing"

# Move previous high quality GIF to HQ
Copy-Item "e:\Projects\Readme\capedcrusader77-neural-lab.gif" "e:\Projects\Readme\capedcrusader77-neural-lab-hq.gif"

# Export keyframe PNGs
[KeyframeExporter]::ExportKeyframes("e:\Projects\Readme")

# Export optimized production GIF
[KeyframeExporter]::RenderOptimizedGif("e:\Projects\Readme\capedcrusader77-neural-lab.gif")

$optItem = Get-Item "e:\Projects\Readme\capedcrusader77-neural-lab.gif"
$hqItem = Get-Item "e:\Projects\Readme\capedcrusader77-neural-lab-hq.gif"

Write-Output "=== RENDERING REPORT ==="
Write-Output "Optimized GIF: $($optItem.FullName) - Size: $([math]::Round($optItem.Length / 1MB, 2)) MB"
Write-Output "HQ Master GIF: $($hqItem.FullName) - Size: $([math]::Round($hqItem.Length / 1MB, 2)) MB"
