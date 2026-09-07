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

public class NeuralLabRendererV2 {
    public const int TOTAL_FRAMES = 60; // 60 frames * 133ms = 8.0s seamless loop
    public const int DELAY_MS = 133;

    public static float SmoothStep(float min, float max, float value) {
        float x = Math.Max(0.0f, Math.Min(1.0f, (value - min) / (max - min)));
        return x * x * (3.0f - 2.0f * x);
    }

    public static void RenderGif(string outputPath, int width, int height) {
        Console.WriteLine("Rendering Neural Lab GIF (" + width + "x" + height + ", " + TOTAL_FRAMES + " frames)...");
        var frames = new Bitmap[TOTAL_FRAMES];

        for (int f = 0; f < TOTAL_FRAMES; f++) {
            float t = (float)f / TOTAL_FRAMES * 8.0f;
            var bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                RenderSingleFrame(g, width, height, t);
            }
            frames[f] = bmp;
            if (f % 15 == 0) Console.WriteLine("Progress: " + f + " / " + TOTAL_FRAMES);
        }

        Console.WriteLine("Encoding GIF...");
        SimpleGif.CreateAnimatedGif(outputPath, frames, DELAY_MS);
        for (int f = 0; f < TOTAL_FRAMES; f++) frames[f].Dispose();
        Console.WriteLine("Done! Saved to: " + outputPath);
    }

    public static void ExportKeyframes(string dir, int width, int height) {
        float[] times = new float[] { 0.8f, 1.8f, 3.2f, 4.4f, 5.4f, 6.6f, 7.4f };
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
            var bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                RenderSingleFrame(g, width, height, t);
            }
            string path = Path.Combine(dir, "keyframe-" + names[i] + ".png");
            bmp.Save(path, ImageFormat.Png);
            bmp.Dispose();
            Console.WriteLine("Exported keyframe: " + path);
        }
    }

    public static void RenderSingleFrame(Graphics g, int W, int H, float t) {
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;

        float sx = (float)W / 960.0f;
        float sy = (float)H / 400.0f;
        float robotX = 730.0f * sx;
        float robotY = 195.0f * sy;

        // 1. BASE BACKGROUND
        using (var brushBg = new SolidBrush(Color.FromArgb(7, 9, 14))) {
            g.FillRectangle(brushBg, 0, 0, W, H);
        }

        // Radial glow background around robot/neural center
        using (var path = new GraphicsPath()) {
            path.AddEllipse(-100, -100, W + 200, H + 200);
            using (var pgb = new PathGradientBrush(path)) {
                pgb.CenterPoint = new PointF(robotX - 60 * sx, robotY);
                pgb.CenterColor = Color.FromArgb(28, 20, 56);
                pgb.SurroundColors = new Color[] { Color.FromArgb(7, 9, 14) };
                g.FillRectangle(pgb, 0, 0, W, H);
            }
        }

        // 2. TECHNICAL GRID & TICK MARKS
        float gridAlpha = t < 1.0f ? SmoothStep(0.0f, 0.9f, t) : (t > 7.6f ? SmoothStep(8.0f, 7.6f, t) * 0.6f + 0.4f : 1.0f);
        int gridCol = (int)(34 * gridAlpha);
        using (var penGrid = new Pen(Color.FromArgb(gridCol, 139, 92, 246), 1)) {
            int step = (int)(32 * sx);
            for (int x = 0; x <= W; x += step) g.DrawLine(penGrid, x, 0, x, H);
            for (int y = 0; y <= H; y += step) g.DrawLine(penGrid, 0, y, W, y);
        }

        // Intersection cross markers
        int crossCol = (int)(65 * gridAlpha);
        using (var penCross = new Pen(Color.FromArgb(crossCol, 0, 240, 255), 1)) {
            for (int x = (int)(64 * sx); x < W; x += (int)(96 * sx)) {
                for (int y = (int)(32 * sy); y < H; y += (int)(64 * sy)) {
                    g.DrawLine(penCross, x - 3, y, x + 3, y);
                    g.DrawLine(penCross, x, y - 3, x, y + 3);
                }
            }
        }

        // Font objects
        using (var fontTitle = new Font("Segoe UI", 34 * sx, FontStyle.Bold))
        using (var fontSub = new Font("Consolas", 10.0f * sx, FontStyle.Bold))
        using (var fontTag = new Font("Consolas", 8.0f * sx, FontStyle.Bold))
        using (var fontMicro = new Font("Consolas", 7.0f * sx, FontStyle.Regular))
        using (var fontHud = new Font("Consolas", 8.5f * sx, FontStyle.Regular)) {

            // Metric ticks along borders
            using (var brushTick = new SolidBrush(Color.FromArgb((int)(55 * gridAlpha), 148, 163, 184))) {
                for (int x = (int)(32 * sx); x < W - (int)(32 * sx); x += (int)(64 * sx)) {
                    g.FillRectangle(brushTick, x, 3, 1, 4);
                    g.FillRectangle(brushTick, x, H - 7, 1, 4);
                    g.DrawString("+" + ((int)(x / sx)).ToString("D4"), fontMicro, brushTick, x - 10, 10);
                }
            }

            // Ambient particles
            var rand = new Random(77);
            for (int i = 0; i < 35; i++) {
                float px0 = (float)(rand.NextDouble() * 960.0);
                float py0 = (float)(rand.NextDouble() * 400.0);
                float spx = (float)((rand.NextDouble() - 0.5) * 16.0);
                float spy = (float)((rand.NextDouble() - 0.5) * 12.0);
                float px = ((px0 + spx * t + 960.0f) % 960.0f) * sx;
                float py = ((py0 + spy * t + 400.0f) % 400.0f) * sy;
                float pAlpha = (float)(0.25f + 0.35f * Math.Sin(t * 3.0f + i));
                int alphaVal = (int)(255 * pAlpha * gridAlpha);
                alphaVal = Math.Max(0, Math.Min(255, alphaVal));
                Color pColor = (i % 2 == 0) ? Color.FromArgb(alphaVal, 0, 240, 255) : Color.FromArgb(alphaVal, 139, 92, 246);
                using (var brushP = new SolidBrush(pColor)) {
                    g.FillEllipse(brushP, px, py, 2.0f * sx, 2.0f * sy);
                }
            }

            // 3. SCANNING BEAM SWEEP (Phase 2: 1.0s to 2.4s)
            float beamX = -100;
            if (t >= 1.0f && t <= 2.4f) {
                float scanNorm = (t - 1.0f) / 1.4f;
                beamX = scanNorm * (W + 200) - 100;

                using (var brushBeam = new LinearGradientBrush(
                    new PointF(beamX - 120, 0), new PointF(beamX + 25, 0),
                    Color.FromArgb(0, 139, 92, 246), Color.FromArgb(130, 0, 240, 255))) {
                    g.FillRectangle(brushBeam, beamX - 120, 0, 145, H);
                }
                using (var penLaser = new Pen(Color.FromArgb(220, 255, 255, 255), 2.0f)) {
                    g.DrawLine(penLaser, beamX + 25, 0, beamX + 25, H);
                }
            }

            // Elements illuminate as the beam passes across
            float illuminateAlpha = 0.0f;
            if (t < 1.0f) {
                illuminateAlpha = 0.0f;
            } else if (t <= 2.4f) {
                illuminateAlpha = SmoothStep(1.0f, 2.4f, t);
            } else {
                illuminateAlpha = 1.0f;
            }

            // 4. NEURAL NETWORK SPANNING MIDGROUND & ROBOT (Phases 2-7)
            float neuralAlpha = SmoothStep(2.2f, 3.4f, t);
            if (neuralAlpha > 0.01f) {
                int na = (int)(180 * neuralAlpha);

                // Multi-layer Neural Graph: 5 layers
                var layerXs = new float[] { 500f * sx, 570f * sx, 645f * sx, 730f * sx, 820f * sx };
                var layerYs = new float[][] {
                    new float[] { 140f * sy, 200f * sy, 260f * sy },
                    new float[] { 110f * sy, 165f * sy, 225f * sy, 285f * sy },
                    new float[] { 90f * sy, 145f * sy, 200f * sy, 255f * sy, 310f * sy },
                    new float[] { 120f * sy, 185f * sy, 255f * sy },
                    new float[] { 150f * sy, 220f * sy }
                };

                // Synapses
                for (int l = 0; l < layerXs.Length - 1; l++) {
                    float x1 = layerXs[l]; float x2 = layerXs[l + 1];
                    var ys1 = layerYs[l]; var ys2 = layerYs[l + 1];

                    for (int i = 0; i < ys1.Length; i++) {
                        for (int j = 0; j < ys2.Length; j++) {
                            using (var penSyn = new Pen(Color.FromArgb((int)(40 * neuralAlpha), 139, 92, 246), 1.0f)) {
                                g.DrawLine(penSyn, x1, ys1[i], x2, ys2[j]);
                            }

                            // Signal pulse in Phase 5
                            if (t >= 4.4f && t <= 6.2f) {
                                float pulseTime = (t - 4.4f) * 1.8f;
                                float pDelay = l * 0.22f;
                                float prog = pulseTime - pDelay;
                                if (prog >= 0.0f && prog <= 1.0f) {
                                    float px = x1 + (x2 - x1) * prog;
                                    float py = ys1[i] + (ys2[j] - ys1[i]) * prog;
                                    using (var brushPulse = new SolidBrush(Color.FromArgb(240, 0, 240, 255))) {
                                        g.FillEllipse(brushPulse, px - 2.5f * sx, py - 2.5f * sy, 5 * sx, 5 * sy);
                                    }
                                }
                            }
                        }
                    }
                }

                // Neural Nodes
                for (int l = 0; l < layerXs.Length; l++) {
                    float x = layerXs[l];
                    foreach (float y in layerYs[l]) {
                        using (var brushNodeBg = new SolidBrush(Color.FromArgb(na, 15, 23, 42)))
                        using (var penNode = new Pen(Color.FromArgb(na, 139, 92, 246), 1.2f))
                        using (var brushCore = new SolidBrush(Color.FromArgb(na, 0, 240, 255))) {
                            g.FillEllipse(brushNodeBg, x - 4 * sx, y - 4 * sy, 8 * sx, 8 * sy);
                            g.DrawEllipse(penNode, x - 4 * sx, y - 4 * sy, 8 * sx, 8 * sy);
                            g.FillEllipse(brushCore, x - 1.5f * sx, y - 1.5f * sy, 3 * sx, 3 * sy);
                        }
                    }
                }
            }

            // 5. AUTONOMOUS ROBOTIC PROTOTYPE (RIGHT SIDE)
            float robotAlpha = SmoothStep(2.2f, 3.4f, t);
            if (robotAlpha > 0.01f) {
                int rAlpha = (int)(255 * robotAlpha);

                // Gimbal Outer Bearing Ring
                using (var penGimbal = new Pen(Color.FromArgb((int)(110 * robotAlpha), 139, 92, 246), 1.5f)) {
                    g.DrawEllipse(penGimbal, robotX - 130 * sx, robotY - 95 * sy, 260 * sx, 190 * sy);
                }
                // Pitch Ring
                using (var penPitch = new Pen(Color.FromArgb((int)(120 * robotAlpha), 0, 240, 255), 1.2f)) {
                    g.DrawEllipse(penPitch, robotX - 105 * sx, robotY - 75 * sy, 210 * sx, 150 * sy);
                }

                // Chassis Hex Core
                var hexPts = new PointF[6];
                float hexRadius = 50.0f * sx;
                for (int i = 0; i < 6; i++) {
                    float a = (float)(i * 60.0 * Math.PI / 180.0);
                    hexPts[i] = new PointF(robotX + (float)Math.Cos(a) * hexRadius, robotY + (float)Math.Sin(a) * hexRadius * 0.9f);
                }
                using (var brushHex = new SolidBrush(Color.FromArgb((int)(200 * robotAlpha), 14, 18, 28)))
                using (var penHex = new Pen(Color.FromArgb(rAlpha, 139, 92, 246), 2.0f)) {
                    g.FillPolygon(brushHex, hexPts);
                    g.DrawPolygon(penHex, hexPts);
                }

                // Primary Optical Lens (Center)
                float mainRadius = 24.0f * sx;
                using (var pathLens = new GraphicsPath()) {
                    pathLens.AddEllipse(robotX - mainRadius, robotY - mainRadius, mainRadius * 2, mainRadius * 2);
                    using (var pgbLens = new PathGradientBrush(pathLens)) {
                        pgbLens.CenterPoint = new PointF(robotX - 6 * sx, robotY - 6 * sy);
                        pgbLens.CenterColor = Color.FromArgb(rAlpha, 0, 240, 255);
                        pgbLens.SurroundColors = new Color[] { Color.FromArgb(rAlpha, 15, 23, 42) };
                        g.FillEllipse(pgbLens, robotX - mainRadius, robotY - mainRadius, mainRadius * 2, mainRadius * 2);
                    }
                }
                using (var penAperture = new Pen(Color.FromArgb(rAlpha, 0, 240, 255), 2.0f)) {
                    g.DrawEllipse(penAperture, robotX - mainRadius, robotY - mainRadius, mainRadius * 2, mainRadius * 2);
                }
                // Optical inner reflection rings
                using (var penIris = new Pen(Color.FromArgb((int)(140 * robotAlpha), 56, 189, 248), 1.0f)) {
                    g.DrawEllipse(penIris, robotX - mainRadius * 0.6f, robotY - mainRadius * 0.6f, mainRadius * 1.2f, mainRadius * 1.2f);
                }

                // Stereo Camera Pods Left & Right
                using (var brushStereo = new SolidBrush(Color.FromArgb((int)(160 * robotAlpha), 6, 182, 212)))
                using (var penStereo = new Pen(Color.FromArgb(rAlpha, 6, 182, 212), 1.2f)) {
                    g.FillEllipse(brushStereo, robotX - 42 * sx - 9 * sx, robotY - 10 * sy - 9 * sy, 18 * sx, 18 * sy);
                    g.DrawEllipse(penStereo, robotX - 42 * sx - 9 * sx, robotY - 10 * sy - 9 * sy, 18 * sx, 18 * sy);

                    g.FillEllipse(brushStereo, robotX + 42 * sx - 9 * sx, robotY - 10 * sy - 9 * sy, 18 * sx, 18 * sy);
                    g.DrawEllipse(penStereo, robotX + 42 * sx - 9 * sx, robotY - 10 * sy - 9 * sy, 18 * sx, 18 * sy);
                }

                // Top Rotating LiDAR Turret Housing
                using (var brushLidar = new SolidBrush(Color.FromArgb((int)(220 * robotAlpha), 17, 24, 39)))
                using (var penLidar = new Pen(Color.FromArgb(rAlpha, 168, 85, 247), 1.5f)) {
                    g.FillRectangle(brushLidar, robotX - 26 * sx, robotY - 65 * sy, 52 * sx, 20 * sy);
                    g.DrawRectangle(penLidar, robotX - 26 * sx, robotY - 65 * sy, 52 * sx, 20 * sy);
                }
                // LiDAR Status LED
                using (var brushLed = new SolidBrush(Color.FromArgb(rAlpha, 0, 240, 255))) {
                    g.FillEllipse(brushLed, robotX - 3 * sx, robotY - 57 * sy, 6 * sx, 6 * sy);
                }

                // Infrared Depth Sensor Emitter Bar
                using (var brushIr = new SolidBrush(Color.FromArgb((int)(140 * robotAlpha), 139, 92, 246)))
                using (var penIr = new Pen(Color.FromArgb(rAlpha, 139, 92, 246), 1.0f)) {
                    g.FillRectangle(brushIr, robotX - 18 * sx, robotY + 24 * sy, 36 * sx, 8 * sy);
                    g.DrawRectangle(penIr, robotX - 18 * sx, robotY + 24 * sy, 36 * sx, 8 * sy);
                }
            }

            // 6. COMPUTER VISION BOUNDING BOXES & RETICLES (Phase 3+)
            float cvAlpha = SmoothStep(2.8f, 3.6f, t);
            if (cvAlpha > 0.01f) {
                int cva = (int)(255 * cvAlpha);
                DrawBox(g, robotX - 80 * sx, robotY - 78 * sy, 160 * sx, 138 * sy, "SENSOR_RIG_01 // 99.4%", Color.FromArgb(cva, 0, 240, 255), fontTag);
                DrawBox(g, robotX - 36 * sx, robotY - 36 * sy, 72 * sx, 72 * sy, "TRACK_ID:#077", Color.FromArgb(cva, 139, 92, 246), fontTag);

                using (var penRet = new Pen(Color.FromArgb((int)(150 * cvAlpha), 0, 240, 255), 1.0f)) {
                    g.DrawEllipse(penRet, robotX - 42 * sx, robotY - 42 * sy, 84 * sx, 84 * sy);
                    penRet.DashStyle = DashStyle.Dash;
                    g.DrawLine(penRet, robotX - 60 * sx, robotY, robotX + 60 * sx, robotY);
                    g.DrawLine(penRet, robotX, robotY - 60 * sy, robotX, robotY + 60 * sy);
                }

                using (var brushCv = new SolidBrush(Color.FromArgb(cva, 0, 240, 255))) {
                    string metric1 = string.Format("X:{0:F3}m  Y:{1:F3}m  Z:0.842m", 1.24f + Math.Sin(t) * 0.04f, -0.18f + Math.Cos(t) * 0.03f);
                    g.DrawString(metric1, fontMicro, brushCv, robotX - 80 * sx, robotY + 66 * sy);
                    g.DrawString("CONF: 99.8%  IOU: 0.94  FPS: 120.0", fontMicro, brushCv, robotX - 80 * sx, robotY + 77 * sy);
                }
            }

            // 7. LIDAR 360° RADAR SWEEP & POINT CLOUD (Phase 6+)
            float lidarAlpha = SmoothStep(5.2f, 6.2f, t);
            if (lidarAlpha > 0.01f) {
                float sweepAngle = (t * 2.2f) % (float)(Math.PI * 2.0);
                using (var penBeam = new Pen(Color.FromArgb((int)(220 * lidarAlpha), 0, 240, 255), 1.5f)) {
                    g.DrawLine(penBeam, robotX, robotY, robotX + (float)Math.Cos(sweepAngle) * 140.0f * sx, robotY + (float)Math.Sin(sweepAngle) * 140.0f * sy);
                }

                for (int i = 0; i < 60; i++) {
                    float angle = (float)(i * (360.0 / 60.0));
                    float rad = (float)(angle * Math.PI / 180.0);
                    float baseDist = 65.0f + (float)(Math.Sin(angle * 0.08f) * 28.0f + Math.Cos(angle * 0.15f) * 18.0f);
                    float lx = robotX + (float)Math.Cos(rad) * baseDist * 1.25f * sx;
                    float ly = robotY + (float)Math.Sin(rad) * baseDist * 0.85f * sy;

                    float angleDiff = (float)Math.Abs((rad - sweepAngle + Math.PI * 4.0) % (Math.PI * 2.0));
                    float hit = angleDiff < 0.6f ? 1.0f - (angleDiff / 0.6f) : 0.18f;
                    int ptAlpha = (int)(255 * hit * lidarAlpha);
                    ptAlpha = Math.Max(0, Math.Min(255, ptAlpha));

                    Color ptCol = hit > 0.5f ? Color.FromArgb(ptAlpha, 0, 240, 255) : Color.FromArgb(ptAlpha, 139, 92, 246);
                    using (var brushPt = new SolidBrush(ptCol)) {
                        float size = (hit > 0.5f ? 2.5f : 1.5f) * sx;
                        g.FillEllipse(brushPt, lx - size / 2, ly - size / 2, size, size);
                    }
                }
            }

            // 8. LEFT HERO TYPOGRAPHY & IDENTITY (Phase 4+)
            float textAlpha = SmoothStep(3.2f, 4.2f, t);
            if (textAlpha > 0.01f) {
                int ta = (int)(255 * textAlpha);

                // Top Tag with crisp drawn status pip
                using (var brushTag = new SolidBrush(Color.FromArgb(ta, 139, 92, 246))) {
                    g.DrawString("[ NEURAL CONTROL LAB // BUILD 077 ]", fontTag, brushTag, 54 * sx, 52 * sy);
                }
                using (var brushDot = new SolidBrush(Color.FromArgb(ta, 0, 240, 255))) {
                    g.FillEllipse(brushDot, 42 * sx, 54 * sy, 6 * sx, 6 * sy);
                }

                // PRIMARY BRAND NAME: CAPEDCRUSADER77
                // Violet bloom shadow
                using (var brushGlow = new SolidBrush(Color.FromArgb((int)(90 * textAlpha), 139, 92, 246))) {
                    g.DrawString("CAPEDCRUSADER77", fontTitle, brushGlow, 52 * sx, 86 * sy);
                    g.DrawString("CAPEDCRUSADER77", fontTitle, brushGlow, 50 * sx, 88 * sy);
                }
                // Crisp White Foreground
                using (var brushMain = new SolidBrush(Color.FromArgb(ta, 255, 255, 255))) {
                    g.DrawString("CAPEDCRUSADER77", fontTitle, brushMain, 50 * sx, 84 * sy);
                }

                // SECONDARY LINE: AI ENGINEER // ROBOTICS // COMPUTER VISION
                using (var brushSub = new SolidBrush(Color.FromArgb(ta, 0, 240, 255))) {
                    g.DrawString("AI ENGINEER // ROBOTICS // COMPUTER VISION", fontSub, brushSub, 52 * sx, 150 * sy);
                }

                // PARADIGM PIPELINE (DRAWN VECTOR CHEVRONS)
                DrawPipelineVectors(g, 52 * sx, 182 * sy, t, fontSub, sx, sy);

                // TECHNICAL BADGES ROW
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

                float bX = 52 * sx;
                float bY = 238 * sy;
                for (int i = 0; i < badgeTexts.Length; i++) {
                    string bText = badgeTexts[i];
                    Color bCol = badgeColors[i];
                    var size = g.MeasureString(bText, fontTag);

                    using (var brushPill = new SolidBrush(Color.FromArgb(180, 13, 17, 26)))
                    using (var penPill = new Pen(Color.FromArgb(ta, bCol), 1.0f))
                    using (var brushPip = new SolidBrush(Color.FromArgb(ta, bCol)))
                    using (var brushPillText = new SolidBrush(Color.FromArgb(ta, 248, 250, 252))) {
                        g.FillRectangle(brushPill, bX, bY, size.Width + 18, 20 * sy);
                        g.DrawRectangle(penPill, bX, bY, size.Width + 18, 20 * sy);
                        g.FillEllipse(brushPip, bX + 5, bY + 7 * sy, 4 * sx, 4 * sy);
                        g.DrawString(bText, fontTag, brushPillText, bX + 13, bY + 3 * sy);
                    }
                    bX += size.Width + 24 * sx;
                }
            }

            // 9. TELEMETRY FOOTER & SYSTEM ONLINE STATE
            float sysAlpha = SmoothStep(6.6f, 7.4f, t);

            // Bottom telemetry bar
            using (var brushBar = new SolidBrush(Color.FromArgb(230, 9, 13, 22)))
            using (var penBar = new Pen(Color.FromArgb(80, 30, 41, 59), 1)) {
                g.FillRectangle(brushBar, 0, H - 32, W, 32);
                g.DrawLine(penBar, 0, H - 32, W, H - 32);
            }

            bool isOnline = (t >= 6.8f && t <= 7.8f);
            Color statColor = isOnline ? Color.FromArgb(0, 240, 255) : Color.FromArgb(148, 163, 184);

            // Draw status indicator circle manually for 100% clean rendering
            using (var brushDot = new SolidBrush(statColor)) {
                g.FillEllipse(brushDot, 52 * sx, H - 22, 6 * sx, 6 * sy);
            }

            using (var brushStatus = new SolidBrush(statColor))
            using (var brushTelem = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                g.DrawString(isOnline ? "SYSTEM ONLINE" : "RUNNING CALIBRATION", fontHud, brushStatus, 64 * sx, H - 21);
                g.DrawString("|  INFERENCE: 3.2ms", fontHud, brushTelem, 220 * sx, H - 21);
                g.DrawString("|  CUDA: 12.4", fontHud, brushTelem, 420 * sx, H - 21);
                g.DrawString("|  FRAME: 120 FPS", fontHud, brushTelem, 570 * sx, H - 21);
                g.DrawString("|  PERCEPTION: ACTIVE", fontHud, brushTelem, 710 * sx, H - 21);
            }

            // Phase 7 "SYSTEM ONLINE" Card
            if (sysAlpha > 0.01f) {
                float cardFade = t > 7.7f ? SmoothStep(8.0f, 7.7f, t) : 1.0f;
                int ca = (int)(255 * sysAlpha * cardFade);

                using (var brushCard = new SolidBrush(Color.FromArgb(ca, 13, 17, 26)))
                using (var penCard = new Pen(Color.FromArgb(ca, 0, 240, 255), 1.5f)) {
                    g.FillRectangle(brushCard, 52 * sx, 276 * sy, 400 * sx, 32 * sy);
                    g.DrawRectangle(penCard, 52 * sx, 276 * sy, 400 * sx, 32 * sy);
                }

                using (var brushV = new SolidBrush(Color.FromArgb(ca, 0, 240, 255)))
                using (var brushR = new SolidBrush(Color.FromArgb(ca, 139, 92, 246)))
                using (var brushA = new SolidBrush(Color.FromArgb(ca, 34, 211, 238))) {
                    g.DrawString("VISION: ACTIVE", fontSub, brushV, 64 * sx, 284 * sy);
                    g.DrawString("ROBOTICS: ACTIVE", fontSub, brushR, 192 * sx, 284 * sy);
                    g.DrawString("AI CORE: ONLINE", fontSub, brushA, 332 * sx, 284 * sy);
                }
            }

            // HUD Corners
            using (var penHud = new Pen(Color.FromArgb(90, 139, 92, 246), 1.5f)) {
                int m = 8; int s = 14;
                g.DrawLine(penHud, m, m + s, m, m); g.DrawLine(penHud, m, m + s, m, m);
                g.DrawLine(penHud, W - m - s, m, W - m, m); g.DrawLine(penHud, W - m, m, W - m, m + s);
                g.DrawLine(penHud, m, H - m - s, m, H - m); g.DrawLine(penHud, m, H - m, m + s, H - m);
                g.DrawLine(penHud, W - m - s, H - m, W - m, H - m); g.DrawLine(penHud, W - m, H - m, W - m, H - m - s);
            }
        }
    }

    private static void DrawPipelineVectors(Graphics g, float x, float y, float t, Font font, float sx, float sy) {
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
            curX += g.MeasureString(st.Name, font).Width + 8;

            if (i < stages.Length - 1) {
                Color arrCol = (t >= st.Phase + 0.25f) ? Color.FromArgb(139, 92, 246) : Color.FromArgb(80, 148, 163, 184);
                // Draw vector arrow
                using (var penArr = new Pen(arrCol, 1.5f))
                using (var brushArr = new SolidBrush(arrCol)) {
                    float ay = y + 7 * sy;
                    g.DrawLine(penArr, curX, ay, curX + 12 * sx, ay);
                    var arrowHead = new PointF[] {
                        new PointF(curX + 12 * sx, ay),
                        new PointF(curX + 8 * sx, ay - 3 * sy),
                        new PointF(curX + 8 * sx, ay + 3 * sy)
                    };
                    g.FillPolygon(brushArr, arrowHead);
                }
                curX += 24 * sx;
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

# 1. Render production optimized GIF
$optGif = "e:\Projects\Readme\capedcrusader77-neural-lab.gif"
[NeuralLabRendererV2]::RenderGif($optGif, 840, 350)

# 2. Render high resolution master GIF
$hqGif = "e:\Projects\Readme\capedcrusader77-neural-lab-hq.gif"
[NeuralLabRendererV2]::RenderGif($hqGif, 960, 400)

# 3. Export Keyframe PNGs
[NeuralLabRendererV2]::ExportKeyframes("e:\Projects\Readme", 960, 400)

$optItem = Get-Item $optGif
$hqItem = Get-Item $hqGif
Write-Output "=== COMPLETE EXPORT REPORT ==="
Write-Output "Optimized GIF: $($optItem.FullName) - Size: $([math]::Round($optItem.Length / 1MB, 2)) MB"
Write-Output "HQ Master GIF: $($hqItem.FullName) - Size: $([math]::Round($hqItem.Length / 1MB, 2)) MB"
