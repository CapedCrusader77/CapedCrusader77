$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;
using System.Collections.Generic;

public class SimpleGif {
    public static void CreateAnimatedGif(string outputPath, Bitmap[] frames, int delayMs) {
        using (var fs = new FileStream(outputPath, FileMode.Create, FileAccess.Write)) {
            // Delay in 100ths of a second
            int delay100th = delayMs / 10;
            byte delayLo = (byte)(delay100th & 0xFF);
            byte delayHi = (byte)((delay100th >> 8) & 0xFF);

            for (int i = 0; i < frames.Length; i++) {
                using (var ms = new MemoryStream()) {
                    frames[i].Save(ms, ImageFormat.Gif);
                    byte[] bytes = ms.ToArray();

                    if (i == 0) {
                        // Header (bytes 0-5) + Screen Descriptor (bytes 6-12)
                        fs.Write(bytes, 0, 13);

                        // Check for global color table
                        int gctSize = 0;
                        if ((bytes[10] & 0x80) != 0) {
                            int count = 1 << ((bytes[10] & 7) + 1);
                            gctSize = 3 * count;
                            fs.Write(bytes, 13, gctSize);
                        }

                        // Netscape 2.0 Loop Extension (Infinite loop)
                        byte[] netscape = new byte[] {
                            0x21, 0xFF, 0x0B,
                            (byte)'N', (byte)'E', (byte)'T', (byte)'S', (byte)'C', (byte)'A', (byte)'P', (byte)'E', (byte)'2', (byte)'.', (byte)'0',
                            0x03, 0x01, 0x00, 0x00, 0x00
                        };
                        fs.Write(netscape, 0, netscape.Length);

                        // Graphic Control Extension for Frame 0
                        byte[] gce = new byte[] { 0x21, 0xF9, 0x04, 0x00, delayLo, delayHi, 0x00, 0x00 };
                        fs.Write(gce, 0, gce.Length);

                        // Image Descriptor & Data from byte (13 + gctSize) up to end - 1
                        int imgStart = 13 + gctSize;
                        if (bytes[imgStart] == 0x21 && bytes[imgStart + 1] == 0xF9) {
                            imgStart += 8;
                        }
                        fs.Write(bytes, imgStart, bytes.Length - imgStart - 1);
                    } else {
                        // Graphic Control Extension for subsequent frame
                        byte[] gce = new byte[] { 0x21, 0xF9, 0x04, 0x00, delayLo, delayHi, 0x00, 0x00 };
                        fs.Write(gce, 0, gce.Length);

                        // Find Image Descriptor (0x2C)
                        int imgStart = 13;
                        if ((bytes[10] & 0x80) != 0) {
                            int count = 1 << ((bytes[10] & 7) + 1);
                            imgStart += 3 * count;
                        }
                        if (bytes[imgStart] == 0x21 && bytes[imgStart + 1] == 0xF9) {
                            imgStart += 8;
                        }

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

public class NeuralLabRenderer {
    public const int WIDTH = 960;
    public const int HEIGHT = 400;
    public const int TOTAL_FRAMES = 80; // 80 frames * 100ms = 8.0s loop
    public const int DELAY_MS = 100;

    public static float SmoothStep(float min, float max, float value) {
        float x = Math.Max(0.0f, Math.Min(1.0f, (value - min) / (max - min)));
        return x * x * (3.0f - 2.0f * x);
    }

    public static void RenderAll(string outputPath) {
        Console.WriteLine("Starting Neural Lab Render: " + TOTAL_FRAMES + " frames...");

        var rand = new Random(77);
        int pCount = 40;
        var pX = new float[pCount];
        var pY = new float[pCount];
        var pSpeedX = new float[pCount];
        var pSpeedY = new float[pCount];
        var pSize = new float[pCount];
        var pIsCyan = new bool[pCount];

        for (int i = 0; i < pCount; i++) {
            pX[i] = (float)(rand.NextDouble() * WIDTH);
            pY[i] = (float)(rand.NextDouble() * HEIGHT);
            pSpeedX[i] = (float)((rand.NextDouble() - 0.5) * 20.0);
            pSpeedY[i] = (float)((rand.NextDouble() - 0.5) * 15.0);
            pSize[i] = 1.5f + (float)rand.NextDouble() * 1.5f;
            pIsCyan[i] = rand.NextDouble() > 0.45;
        }

        int lCount = 72;
        var lRad = new float[lCount];
        var lDist = new float[lCount];
        var lX = new float[lCount];
        var lY = new float[lCount];
        float robotX = 720.0f;
        float robotY = 195.0f;

        for (int i = 0; i < lCount; i++) {
            float angle = (float)(i * (360.0 / lCount));
            float rad = (float)(angle * Math.PI / 180.0);
            lRad[i] = rad;
            float baseDist = 65.0f + (float)(Math.Sin(angle * 0.08f) * 28.0f + Math.Cos(angle * 0.15f) * 18.0f);
            lDist[i] = baseDist;
            lX[i] = robotX + (float)Math.Cos(rad) * baseDist * 1.25f;
            lY[i] = robotY + (float)Math.Sin(rad) * baseDist * 0.85f;
        }

        var layerXs = new float[] { 540f, 615f, 695f, 775f, 850f };
        var layerYs = new float[][] {
            new float[] { 130f, 190f, 250f },
            new float[] { 105f, 160f, 220f, 275f },
            new float[] { 85f, 140f, 195f, 250f, 305f },
            new float[] { 120f, 190f, 260f },
            new float[] { 150f, 230f }
        };

        using (var fontTitle = new Font("Segoe UI", 36, FontStyle.Bold))
        using (var fontSub = new Font("Consolas", 10.5f, FontStyle.Bold))
        using (var fontTag = new Font("Consolas", 8.5f, FontStyle.Bold))
        using (var fontMicro = new Font("Consolas", 7.5f, FontStyle.Regular))
        using (var fontHud = new Font("Consolas", 9.0f, FontStyle.Regular))
        {
            var frames = new Bitmap[TOTAL_FRAMES];

            for (int f = 0; f < TOTAL_FRAMES; f++) {
                float t = (float)f / TOTAL_FRAMES * 8.0f;
                var bmp = new Bitmap(WIDTH, HEIGHT, PixelFormat.Format32bppArgb);

                using (var g = Graphics.FromImage(bmp)) {
                    g.SmoothingMode = SmoothingMode.HighQuality;
                    g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;

                    // 1. BASE BACKGROUND
                    using (var brushBg = new SolidBrush(Color.FromArgb(7, 9, 14))) {
                        g.FillRectangle(brushBg, 0, 0, WIDTH, HEIGHT);
                    }

                    // Radial glow background
                    using (var path = new GraphicsPath()) {
                        path.AddEllipse(-100, -100, WIDTH + 200, HEIGHT + 200);
                        using (var pgb = new PathGradientBrush(path)) {
                            pgb.CenterPoint = new PointF(robotX - 100, robotY);
                            pgb.CenterColor = Color.FromArgb(28, 20, 55);
                            pgb.SurroundColors = new Color[] { Color.FromArgb(7, 9, 14) };
                            g.FillRectangle(pgb, 0, 0, WIDTH, HEIGHT);
                        }
                    }

                    // 2. COORDINATE GRID & TICK MARKS
                    float gridAlpha = t < 1.0f ? SmoothStep(0.0f, 0.9f, t) : (t > 7.6f ? SmoothStep(8.0f, 7.6f, t) * 0.6f + 0.4f : 1.0f);
                    int gridCol = (int)(32 * gridAlpha);
                    using (var penGrid = new Pen(Color.FromArgb(gridCol, 139, 92, 246), 1)) {
                        int step = 32;
                        for (int x = 0; x <= WIDTH; x += step) {
                            g.DrawLine(penGrid, x, 0, x, HEIGHT);
                        }
                        for (int y = 0; y <= HEIGHT; y += step) {
                            g.DrawLine(penGrid, 0, y, WIDTH, y);
                        }
                    }

                    int crossCol = (int)(70 * gridAlpha);
                    using (var penCross = new Pen(Color.FromArgb(crossCol, 0, 240, 255), 1)) {
                        for (int x = 64; x < WIDTH; x += 96) {
                            for (int y = 32; y < HEIGHT; y += 64) {
                                g.DrawLine(penCross, x - 3, y, x + 3, y);
                                g.DrawLine(penCross, x, y - 3, x, y + 3);
                            }
                        }
                    }

                    using (var brushTick = new SolidBrush(Color.FromArgb(50, 148, 163, 184))) {
                        for (int x = 32; x < WIDTH - 32; x += 64) {
                            g.FillRectangle(brushTick, x, 4, 1, 4);
                            g.FillRectangle(brushTick, x, HEIGHT - 8, 1, 4);
                            g.DrawString("+" + x.ToString("D4"), fontMicro, brushTick, x - 12, 12);
                        }
                    }

                    for (int i = 0; i < pCount; i++) {
                        float px = (pX[i] + pSpeedX[i] * t + WIDTH) % WIDTH;
                        float py = (pY[i] + pSpeedY[i] * t + HEIGHT) % HEIGHT;
                        float pAlpha = (float)(0.25f + 0.35f * Math.Sin(t * 3.0f + i));
                        int alphaVal = (int)(255 * pAlpha * gridAlpha);
                        alphaVal = Math.Max(0, Math.Min(255, alphaVal));
                        Color pColor = pIsCyan[i] ? Color.FromArgb(alphaVal, 0, 240, 255) : Color.FromArgb(alphaVal, 139, 92, 246);
                        using (var brushP = new SolidBrush(pColor)) {
                            g.FillEllipse(brushP, px, py, pSize[i], pSize[i]);
                        }
                    }

                    // 3. SCANNING BEAM SWEEP (Phase 2)
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

                    // 4. AUTONOMOUS ROBOTIC SENSOR SYSTEM (RIGHT SIDE)
                    float robotAlpha = SmoothStep(2.0f, 3.2f, t);
                    if (robotAlpha > 0.01f) {
                        int rAlpha = (int)(255 * robotAlpha);

                        using (var penGimbal = new Pen(Color.FromArgb((int)(110 * robotAlpha), 139, 92, 246), 1.5f)) {
                            g.DrawEllipse(penGimbal, robotX - 130, robotY - 95, 260, 190);
                        }
                        using (var penPitch = new Pen(Color.FromArgb((int)(120 * robotAlpha), 0, 240, 255), 1.2f)) {
                            g.DrawEllipse(penPitch, robotX - 105, robotY - 75, 210, 150);
                        }

                        var hexPts = new PointF[6];
                        float hexRadius = 50.0f;
                        for (int i = 0; i < 6; i++) {
                            float a = (float)(i * 60.0 * Math.PI / 180.0);
                            hexPts[i] = new PointF(robotX + (float)Math.Cos(a) * hexRadius, robotY + (float)Math.Sin(a) * hexRadius * 0.9f);
                        }
                        using (var brushHex = new SolidBrush(Color.FromArgb((int)(200 * robotAlpha), 14, 18, 28)))
                        using (var penHex = new Pen(Color.FromArgb(rAlpha, 139, 92, 246), 2.0f)) {
                            g.FillPolygon(brushHex, hexPts);
                            g.DrawPolygon(penHex, hexPts);
                        }

                        float mainRadius = 24.0f;
                        using (var pathLens = new GraphicsPath()) {
                            pathLens.AddEllipse(robotX - mainRadius, robotY - mainRadius, mainRadius * 2, mainRadius * 2);
                            using (var pgbLens = new PathGradientBrush(pathLens)) {
                                pgbLens.CenterPoint = new PointF(robotX - 6, robotY - 6);
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
                            g.FillEllipse(brushStereo, robotX - 42 - 10, robotY - 10 - 10, 20, 20);
                            g.DrawEllipse(penStereo, robotX - 42 - 10, robotY - 10 - 10, 20, 20);

                            g.FillEllipse(brushStereo, robotX + 42 - 10, robotY - 10 - 10, 20, 20);
                            g.DrawEllipse(penStereo, robotX + 42 - 10, robotY - 10 - 10, 20, 20);
                        }

                        using (var brushLidar = new SolidBrush(Color.FromArgb((int)(220 * robotAlpha), 17, 24, 39)))
                        using (var penLidar = new Pen(Color.FromArgb(rAlpha, 168, 85, 247), 1.5f)) {
                            g.FillRectangle(brushLidar, robotX - 26, robotY - 65, 52, 20);
                            g.DrawRectangle(penLidar, robotX - 26, robotY - 65, 52, 20);
                        }
                        using (var brushLed = new SolidBrush(Color.FromArgb(rAlpha, 0, 240, 255))) {
                            g.FillEllipse(brushLed, robotX - 3, robotY - 57, 6, 6);
                        }

                        using (var brushIr = new SolidBrush(Color.FromArgb((int)(140 * robotAlpha), 139, 92, 246)))
                        using (var penIr = new Pen(Color.FromArgb(rAlpha, 139, 92, 246), 1.0f)) {
                            g.FillRectangle(brushIr, robotX - 18, robotY + 24, 36, 8);
                            g.DrawRectangle(penIr, robotX - 18, robotY + 24, 36, 8);
                        }
                    }

                    // 5. COMPUTER VISION BOUNDING BOXES & LABELS
                    float cvAlpha = SmoothStep(2.8f, 3.6f, t);
                    if (cvAlpha > 0.01f) {
                        int cva = (int)(255 * cvAlpha);

                        DrawBoundingBox(g, robotX - 80, robotY - 78, 160, 138, "SENSOR_RIG_01 // 99.4%", Color.FromArgb(cva, 0, 240, 255), fontTag);
                        DrawBoundingBox(g, robotX - 36, robotY - 36, 72, 72, "TRACK_ID:#077", Color.FromArgb(cva, 139, 92, 246), fontTag);

                        using (var penRet = new Pen(Color.FromArgb((int)(150 * cvAlpha), 0, 240, 255), 1.0f)) {
                            g.DrawEllipse(penRet, robotX - 42, robotY - 42, 84, 84);
                            penRet.DashStyle = DashStyle.Dash;
                            g.DrawLine(penRet, robotX - 60, robotY, robotX + 60, robotY);
                            g.DrawLine(penRet, robotX, robotY - 60, robotX, robotY + 60);
                        }

                        using (var brushCv = new SolidBrush(Color.FromArgb(cva, 0, 240, 255))) {
                            string metric1 = string.Format("X:{0:F3}m  Y:{1:F3}m  Z:0.842m", 1.24f + Math.Sin(t) * 0.04f, -0.18f + Math.Cos(t) * 0.03f);
                            g.DrawString(metric1, fontMicro, brushCv, robotX - 80, robotY + 66);
                            g.DrawString("CONF: 99.8%  IOU: 0.94  FPS: 120.0", fontMicro, brushCv, robotX - 80, robotY + 77);
                        }
                    }

                    // 6. LIDAR 360° RADAR SWEEP & POINT CLOUD
                    float lidarAlpha = SmoothStep(5.2f, 6.2f, t);
                    if (lidarAlpha > 0.01f) {
                        float sweepAngle = (t * 2.2f) % (float)(Math.PI * 2.0);

                        using (var penBeam = new Pen(Color.FromArgb((int)(220 * lidarAlpha), 0, 240, 255), 1.5f)) {
                            g.DrawLine(penBeam, robotX, robotY, robotX + (float)Math.Cos(sweepAngle) * 150.0f, robotY + (float)Math.Sin(sweepAngle) * 150.0f);
                        }

                        for (int i = 0; i < lCount; i++) {
                            float angleDiff = (float)Math.Abs((lRad[i] - sweepAngle + Math.PI * 4.0) % (Math.PI * 2.0));
                            float hit = angleDiff < 0.6f ? 1.0f - (angleDiff / 0.6f) : 0.18f;
                            int ptAlpha = (int)(255 * hit * lidarAlpha);
                            ptAlpha = Math.Max(0, Math.Min(255, ptAlpha));

                            Color ptCol = hit > 0.5f ? Color.FromArgb(ptAlpha, 0, 240, 255) : Color.FromArgb(ptAlpha, 139, 92, 246);
                            using (var brushPt = new SolidBrush(ptCol)) {
                                float size = hit > 0.5f ? 2.5f : 1.5f;
                                g.FillEllipse(brushPt, lX[i] - size / 2, lY[i] - size / 2, size, size);
                            }
                        }
                    }

                    // 7. NEURAL NETWORK NODES & SYNAPTIC PULSES
                    float neuralAlpha = SmoothStep(4.2f, 5.0f, t);
                    if (neuralAlpha > 0.01f) {
                        int na = (int)(180 * neuralAlpha);

                        for (int l = 0; l < layerXs.Length - 1; l++) {
                            float x1 = layerXs[l];
                            float x2 = layerXs[l + 1];
                            var ys1 = layerYs[l];
                            var ys2 = layerYs[l + 1];

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
                                                g.FillEllipse(brushPulse, px - 2, py - 2, 4, 4);
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
                                    g.FillEllipse(brushNodeBg, x - 4, y - 4, 8, 8);
                                    g.DrawEllipse(penNode, x - 4, y - 4, 8, 8);
                                    g.FillEllipse(brushCore, x - 1.5f, y - 1.5f, 3, 3);
                                }
                            }
                        }
                    }

                    // 8. LEFT HERO TYPOGRAPHY & IDENTITY (100% Stagnant Throughout)
                    float textAlpha = 1.0f;
                    if (true) {
                        int ta = (int)(255 * textAlpha);

                        using (var brushTag = new SolidBrush(Color.FromArgb(ta, 139, 92, 246))) {
                            g.DrawString("[ NEURAL CONTROL LAB // BUILD 077 ]", fontTag, brushTag, 54, 52);
                        }
                        using (var brushDot = new SolidBrush(Color.FromArgb(ta, 0, 240, 255))) {
                            g.FillEllipse(brushDot, 42, 53, 6, 6);
                        }

                        // Glowing shadow
                        using (var brushGlow = new SolidBrush(Color.FromArgb((int)(90 * textAlpha), 139, 92, 246))) {
                            g.DrawString("CAPEDCRUSADER77", fontTitle, brushGlow, 52, 86);
                            g.DrawString("CAPEDCRUSADER77", fontTitle, brushGlow, 50, 88);
                        }
                        using (var brushMain = new SolidBrush(Color.FromArgb(ta, 255, 255, 255))) {
                            g.DrawString("CAPEDCRUSADER77", fontTitle, brushMain, 50, 84);
                        }

                        using (var brushSub = new SolidBrush(Color.FromArgb(ta, 0, 240, 255))) {
                            g.DrawString("AI ENGINEER // ROBOTICS // COMPUTER VISION", fontSub, brushSub, 52, 154);
                        }

                        DrawPipeline(g, 52, 186, t, fontSub);

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

                        float bX = 52;
                        float bY = 246;
                        for (int i = 0; i < badgeTexts.Length; i++) {
                            string bText = badgeTexts[i];
                            Color bCol = badgeColors[i];
                            var size = g.MeasureString(bText, fontTag);

                            using (var brushPill = new SolidBrush(Color.FromArgb(180, 13, 17, 26)))
                            using (var penPill = new Pen(Color.FromArgb(ta, bCol), 1.0f))
                            using (var brushPip = new SolidBrush(Color.FromArgb(ta, bCol)))
                            using (var brushPillText = new SolidBrush(Color.FromArgb(ta, 248, 250, 252))) {
                                g.FillRectangle(brushPill, bX, bY, size.Width + 20, 22);
                                g.DrawRectangle(penPill, bX, bY, size.Width + 20, 22);
                                g.FillEllipse(brushPip, bX + 6, bY + 8, 5, 5);
                                g.DrawString(bText, fontTag, brushPillText, bX + 15, bY + 4);
                            }

                            bX += size.Width + 30;
                        }
                    }

                    // 9. TELEMETRY BAR & SYSTEM ONLINE CARD
                    float sysAlpha = SmoothStep(6.6f, 7.4f, t);

                    using (var brushBar = new SolidBrush(Color.FromArgb(230, 9, 13, 22)))
                    using (var penBar = new Pen(Color.FromArgb(80, 30, 41, 59), 1)) {
                        g.FillRectangle(brushBar, 0, HEIGHT - 34, WIDTH, 34);
                        g.DrawLine(penBar, 0, HEIGHT - 34, WIDTH, HEIGHT - 34);
                    }

                    bool isOnline = (t >= 6.8f && t <= 7.8f);
                    using (var brushStatus = new SolidBrush(isOnline ? Color.FromArgb(0, 240, 255) : Color.FromArgb(148, 163, 184)))
                    using (var brushTelem = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString(isOnline ? "● SYSTEM ONLINE" : "◐ RUNNING CALIBRATION", fontHud, brushStatus, 52, HEIGHT - 22);
                        g.DrawString("|  INFERENCE: 3.2ms (TensorRT)", fontHud, brushTelem, 220, HEIGHT - 22);
                        g.DrawString("|  CUDA: 12.4 ACTIVE", fontHud, brushTelem, 430, HEIGHT - 22);
                        g.DrawString("|  FRAME: 120 FPS", fontHud, brushTelem, 590, HEIGHT - 22);
                        g.DrawString("|  PERCEPTION: ZERO_LATENCY", fontHud, brushTelem, 730, HEIGHT - 22);
                    }

                    if (sysAlpha > 0.01f) {
                        float cardFade = t > 7.7f ? SmoothStep(8.0f, 7.7f, t) : 1.0f;
                        int ca = (int)(255 * sysAlpha * cardFade);

                        using (var brushCard = new SolidBrush(Color.FromArgb(ca, 13, 17, 26)))
                        using (var penCard = new Pen(Color.FromArgb(ca, 0, 240, 255), 1.5f)) {
                            g.FillRectangle(brushCard, 52, 288, 420, 34);
                            g.DrawRectangle(penCard, 52, 288, 420, 34);
                        }

                        using (var brushV = new SolidBrush(Color.FromArgb(ca, 0, 240, 255)))
                        using (var brushR = new SolidBrush(Color.FromArgb(ca, 139, 92, 246)))
                        using (var brushA = new SolidBrush(Color.FromArgb(ca, 34, 211, 238))) {
                            g.DrawString("VISION: ACTIVE", fontSub, brushV, 66, 297);
                            g.DrawString("ROBOTICS: ACTIVE", fontSub, brushR, 202, 297);
                            g.DrawString("AI CORE: ONLINE", fontSub, brushA, 350, 297);
                        }
                    }

                    DrawHudCorners(g, WIDTH, HEIGHT);
                }

                frames[f] = bmp;
                if (f % 20 == 0) {
                    Console.WriteLine("Rendered frame " + f + " / " + TOTAL_FRAMES);
                }
            }

            Console.WriteLine("Encoding optimized animated GIF...");
            SimpleGif.CreateAnimatedGif(outputPath, frames, DELAY_MS);
            Console.WriteLine("GIF Encoding Complete! Path: " + outputPath);

            for (int f = 0; f < TOTAL_FRAMES; f++) {
                frames[f].Dispose();
            }
        }
    }

    private static void DrawBoundingBox(Graphics g, float x, float y, float w, float h, string label, Color color, Font font) {
        float cornerLen = 10;
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
            g.FillRectangle(brushLabelBg, x, y - 14, size.Width + 6, 14);
            g.DrawString(label, font, brushLabelText, x + 3, y - 13);
        }
    }

    private static void DrawPipeline(Graphics g, float x, float y, float t, Font font) {
        var stages = new[] {
            new { Name = "PERCEPTION", Phase = 4.6f },
            new { Name = "DECISION", Phase = 5.1f },
            new { Name = "ACTION", Phase = 5.6f }
        };

        float curX = x;
        for (int i = 0; i < stages.Length; i++) {
            var st = stages[i];
            bool active = (t >= st.Phase && t <= 7.6f);
            Color col = active ? Color.FromArgb(0, 240, 255) : Color.FromArgb(148, 163, 184);

            using (var brushText = new SolidBrush(col)) {
                g.DrawString(st.Name, font, brushText, curX, y);
            }
            curX += g.MeasureString(st.Name, font).Width + 6;

            if (i < stages.Length - 1) {
                Color arrCol = (t >= st.Phase + 0.25f) ? Color.FromArgb(139, 92, 246) : Color.FromArgb(80, 148, 163, 184);
                using (var brushArr = new SolidBrush(arrCol)) {
                    g.DrawString("→", font, brushArr, curX, y);
                }
                curX += 20;
            }
        }
    }

    private static void DrawHudCorners(Graphics g, int w, int h) {
        using (var penHud = new Pen(Color.FromArgb(90, 139, 92, 246), 1.5f)) {
            int m = 8;
            int s = 14;
            g.DrawLine(penHud, m, m + s, m, m);
            g.DrawLine(penHud, m, m, m + s, m);
            g.DrawLine(penHud, w - m - s, m, w - m, m);
            g.DrawLine(penHud, w - m, m, w - m, m + s);
            g.DrawLine(penHud, m, h - m - s, m, h - m);
            g.DrawLine(penHud, m, h - m, m + s, h - m);
            g.DrawLine(penHud, w - m - s, h - m, w - m, h - m);
            g.DrawLine(penHud, w - m, h - m, w - m, h - m - s);
        }
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing"

$outGif = "e:\Projects\Readme\capedcrusader77-neural-lab.gif"
[NeuralLabRenderer]::RenderAll($outGif)

$item = Get-Item $outGif
Write-Output "Generation Complete! Path: $($item.FullName), Size: $($item.Length) bytes ($([math]::Round($item.Length / 1MB, 2)) MB)"
