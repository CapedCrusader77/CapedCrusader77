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

public class AssetGenerator {
    // Utility helpers
    public static void SetHighQuality(Graphics g) {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
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

                // Base container
                using (var brush = new SolidBrush(Color.FromArgb(10, 14, 22))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }
                using (var pen = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // Left accent chamfer tag
                int chamferW = 180;
                var pts = new PointF[] {
                    new PointF(0, 0),
                    new PointF(chamferW, 0),
                    new PointF(chamferW - 14, h),
                    new PointF(0, h)
                };
                using (var brush = new SolidBrush(Color.FromArgb(18, 26, 40))) {
                    g.FillPolygon(brush, pts);
                }
                using (var pen = new Pen(accent, 1.5f)) {
                    g.DrawLine(pen, 0, 0, chamferW, 0);
                    g.DrawLine(pen, chamferW, 0, chamferW - 14, h);
                    g.DrawLine(pen, 0, h - 1, chamferW - 14, h - 1);
                    g.DrawLine(pen, 0, 0, 0, h);
                }

                // Title
                using (var font = new Font("Segoe UI", 12f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(245, 248, 252))) {
                    g.DrawString(title, font, brush, 18, 11);
                }

                // Subtitle
                using (var font = new Font("Consolas", 10f, FontStyle.Regular))
                using (var brush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString(subtitle, font, brush, chamferW + 16, 14);
                }

                // Animated light beam across the top edge
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

                // Right status tag
                float pulse = 0.6f + 0.4f * (float)Math.Sin(progress * Math.PI * 2);
                int r = (int)(accent.R * pulse);
                int gr = (int)(accent.G * pulse);
                int b = (int)(accent.B * pulse);
                using (var dotBrush = new SolidBrush(Color.FromArgb(r, gr, b))) {
                    g.FillEllipse(dotBrush, w - 160, 18, 9, 9);
                }
                using (var font = new Font("Consolas", 9.5f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                    g.DrawString(tag, font, brush, w - 144, 14);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 2. Project Card 1: SLAM
    public static void RenderCardSlam(string outputPath, int totalFrames = 24) {
        int w = 840, h = 150;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(0, 240, 255); // Cyan

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Base card
                using (var brush = new SolidBrush(Color.FromArgb(8, 12, 20))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }
                using (var pen = new Pen(Color.FromArgb(26, 36, 52), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // Left vertical accent bar
                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 4, h);
                }

                // Index & Name
                using (var font = new Font("Consolas", 13f, FontStyle.Bold))
                using (var brush = new SolidBrush(accent)) {
                    g.DrawString("01 // SENSOR_FUSION_SLAM", font, brush, 24, 16);
                }
                // Status badge next to title
                using (var stFont = new Font("Consolas", 8.5f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(15, 30, 45)))
                using (var stBorder = new Pen(Color.FromArgb(0, 200, 220), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                    g.FillRectangle(stBg, 320, 16, 190, 20);
                    g.DrawRectangle(stBorder, 320, 16, 190, 20);
                    g.DrawString("[ACTIVE // ZERO_DRIFT]", stFont, stText, 328, 19);
                }

                using (var font = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                    g.DrawString("Real-time LiDAR-Visual Odometry & 3D Volumetric Mapping", font, brush, 25, 44);
                }
                using (var font = new Font("Segoe UI", 9f, FontStyle.Regular))
                using (var brush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Multi-modal SLAM fusing stereo optical flow with 3D LiDAR point clouds\nfor drift-free 6-DoF state estimation in degraded GPS environments.", font, brush, 25, 66);
                }

                // Tech tags
                string[] tags = new string[] { "ROS 2", "C++20", "PCL", "Ceres-Solver", "Eigen3" };
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

                // --- RIGHT SIDE: Animated 3D SLAM Viewport ---
                int vpX = 540, vpY = 12, vpW = 285, vpH = 126;
                using (var vpBg = new SolidBrush(Color.FromArgb(5, 8, 14))) {
                    g.FillRectangle(vpBg, vpX, vpY, vpW, vpH);
                }
                using (var vpBorder = new Pen(Color.FromArgb(24, 34, 50), 1f)) {
                    g.DrawRectangle(vpBorder, vpX, vpY, vpW, vpH);
                }

                // Corner ticks
                using (var p = new Pen(accent, 1.2f)) {
                    g.DrawLines(p, new Point[] { new Point(vpX, vpY + 8), new Point(vpX, vpY), new Point(vpX + 8, vpY) });
                    g.DrawLines(p, new Point[] { new Point(vpX + vpW - 9, vpY), new Point(vpX + vpW - 1, vpY), new Point(vpX + vpW - 1, vpY + 8) });
                    g.DrawLines(p, new Point[] { new Point(vpX, vpY + vpH - 9), new Point(vpX, vpY + vpH - 1), new Point(vpX + 8, vpY + vpH - 1) });
                    g.DrawLines(p, new Point[] { new Point(vpX + vpW - 9, vpY + vpH - 1), new Point(vpX + vpW - 1, vpY + vpH - 1), new Point(vpX + vpW - 1, vpY + vpH - 9) });
                }

                // Grid lines inside viewport
                using (var gridPen = new Pen(Color.FromArgb(14, 22, 34), 1f)) {
                    for (int gx = vpX + 20; gx < vpX + vpW; gx += 28) g.DrawLine(gridPen, gx, vpY, gx, vpY + vpH);
                    for (int gy = vpY + 20; gy < vpY + vpH; gy += 25) g.DrawLine(gridPen, vpX, gy, vpX + vpW, gy);
                }

                // 3D Point cloud rotating around center
                float cX = vpX + vpW / 2f;
                float cY = vpY + vpH / 2f + 4f;
                float angle = t * (float)Math.PI * 2f;

                // Draw point cloud cluster
                int numPoints = 36;
                for (int i = 0; i < numPoints; i++) {
                    float theta = (float)i / numPoints * (float)Math.PI * 2f;
                    float radius = 35f + (float)Math.Sin(i * 3.7f) * 22f;
                    float z = (float)Math.Cos(i * 2.1f) * 20f;

                    // Rotate in 3D around Y
                    float curAngle = theta + angle;
                    float rotX = (float)Math.Cos(curAngle) * radius;
                    float rotZ = (float)Math.Sin(curAngle) * radius;
                    float rotY = z + (float)Math.Sin(curAngle * 2f) * 6f;

                    // Perspective projection
                    float d = 110f;
                    float scale = d / (d + rotZ);
                    float projX = cX + rotX * scale;
                    float projY = cY + rotY * scale;

                    int alpha = (int)Math.Max(40, Math.Min(255, 120 + rotZ * 4f));
                    float ptSize = Math.Max(1.5f, 2.8f * scale);
                    using (var ptBrush = new SolidBrush(Color.FromArgb(alpha, 0, 240, 255))) {
                        g.FillEllipse(ptBrush, projX - ptSize / 2f, projY - ptSize / 2f, ptSize, ptSize);
                    }
                }

                // Trajectory Ribbon winding
                var trajPts = new PointF[12];
                for (int j = 0; j < 12; j++) {
                    float step = (float)j / 11f;
                    float tx = vpX + 25 + step * (vpW - 50);
                    float ty = cY + (float)Math.Sin((step * 3f + t) * Math.PI * 2f) * 22f;
                    trajPts[j] = new PointF(tx, ty);
                }
                using (var trajPen = new Pen(Color.FromArgb(160, 56, 189, 248), 1.6f)) {
                    g.DrawCurve(trajPen, trajPts);
                }

                // Current robot pose keyframe marker
                int currIdx = (int)(t * 11) % 12;
                PointF curPose = trajPts[currIdx];
                using (var poseBrush = new SolidBrush(Color.White)) {
                    g.FillEllipse(poseBrush, curPose.X - 3.5f, curPose.Y - 3.5f, 7f, 7f);
                }
                using (var ringPen = new Pen(accent, 1.2f)) {
                    g.DrawEllipse(ringPen, curPose.X - 7f, curPose.Y - 7f, 14f, 14f);
                }

                // Telemetry overlay text
                using (var hudFont = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var hudBrush = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                    g.DrawString("SLAM // 3D_ODOM", hudFont, hudBrush, vpX + 8, vpY + 6);
                    g.DrawString(string.Format("XYZ: +{0:00.0}m -{1:00.0}m +{2:00.0}m", 14.2 + Math.Sin(t*6.28)*2.0, 3.8 + Math.Cos(t*6.28)*1.5, 1.1), hudFont, hudBrush, vpX + 8, vpY + vpH - 15);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 3. Project Card 2: Vision
    public static void RenderCardVision(string outputPath, int totalFrames = 24) {
        int w = 840, h = 150;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(139, 92, 246); // Electric Violet

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Base card
                using (var brush = new SolidBrush(Color.FromArgb(8, 12, 20))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }
                using (var pen = new Pen(Color.FromArgb(26, 36, 52), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // Left vertical accent bar
                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 4, h);
                }

                // Index & Name
                using (var font = new Font("Consolas", 13f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(167, 139, 250))) {
                    g.DrawString("02 // EDGE_TENSOR_VISION", font, brush, 24, 16);
                }
                // Status badge next to title
                using (var stFont = new Font("Consolas", 8.5f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(28, 20, 48)))
                using (var stBorder = new Pen(Color.FromArgb(167, 139, 250), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(192, 132, 252))) {
                    g.FillRectangle(stBg, 320, 16, 190, 20);
                    g.DrawRectangle(stBorder, 320, 16, 190, 20);
                    g.DrawString("[ACTIVE // 120 FPS FP16]", stFont, stText, 326, 19);
                }

                using (var font = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                    g.DrawString("Sub-4ms Zero-Copy Perception Pipeline on NVIDIA Jetson Orin", font, brush, 25, 44);
                }
                using (var font = new Font("Segoe UI", 9f, FontStyle.Regular))
                using (var brush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Accelerated perception engine for 3D object detection, 6-DoF pose estimation,\nand real-time depth fusion optimized with TensorRT INT8/FP16 kernels.", font, brush, 25, 66);
                }

                // Tech tags
                string[] tags = new string[] { "PyTorch", "TensorRT", "CUDA", "OpenCV", "DeepStream" };
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

                // --- RIGHT SIDE: Animated Vision Viewport ---
                int vpX = 540, vpY = 12, vpW = 285, vpH = 126;
                using (var vpBg = new SolidBrush(Color.FromArgb(5, 8, 14))) {
                    g.FillRectangle(vpBg, vpX, vpY, vpW, vpH);
                }
                using (var vpBorder = new Pen(Color.FromArgb(34, 26, 54), 1f)) {
                    g.DrawRectangle(vpBorder, vpX, vpY, vpW, vpH);
                }

                // Corner ticks
                using (var p = new Pen(accent, 1.2f)) {
                    g.DrawLines(p, new Point[] { new Point(vpX, vpY + 8), new Point(vpX, vpY), new Point(vpX + 8, vpY) });
                    g.DrawLines(p, new Point[] { new Point(vpX + vpW - 9, vpY), new Point(vpX + vpW - 1, vpY), new Point(vpX + vpW - 1, vpY + 8) });
                    g.DrawLines(p, new Point[] { new Point(vpX, vpY + vpH - 9), new Point(vpX, vpY + vpH - 1), new Point(vpX + 8, vpY + vpH - 1) });
                    g.DrawLines(p, new Point[] { new Point(vpX + vpW - 9, vpY + vpH - 1), new Point(vpX + vpW - 1, vpY + vpH - 1), new Point(vpX + vpW - 1, vpY + vpH - 9) });
                }

                // Center camera crosshairs
                using (var crossPen = new Pen(Color.FromArgb(45, 35, 70), 1f)) {
                    g.DrawLine(crossPen, vpX + vpW / 2, vpY + 10, vpX + vpW / 2, vpY + vpH - 10);
                    g.DrawLine(crossPen, vpX + 10, vpY + vpH / 2, vpX + vpW - 10, vpY + vpH / 2);
                }

                // Moving scanning laser line
                float scanY = vpY + (float)(Math.Sin(t * Math.PI * 2f) * 0.5f + 0.5f) * vpH;
                using (var scanPen = new Pen(Color.FromArgb(160, 167, 139, 250), 1.5f)) {
                    g.DrawLine(scanPen, vpX + 2, scanY, vpX + vpW - 2, scanY);
                }

                // Animated Bounding Box 1: Drone / Obstacle Target
                float b1X = vpX + 35 + (float)Math.Sin(t * 6.28f) * 12f;
                float b1Y = vpY + 28 + (float)Math.Cos(t * 6.28f) * 8f;
                float b1W = 75, b1H = 55;
                using (var boxPen = new Pen(Color.FromArgb(200, 167, 139, 250), 1.5f)) {
                    g.DrawRectangle(boxPen, b1X, b1Y, b1W, b1H);
                }
                using (var hudFont = new Font("Consolas", 7f, FontStyle.Bold))
                using (var tagBg = new SolidBrush(Color.FromArgb(139, 92, 246)))
                using (var textBr = new SolidBrush(Color.White)) {
                    g.FillRectangle(tagBg, b1X, b1Y - 12, 68, 12);
                    g.DrawString("ROBOT // 99.4%", hudFont, textBr, b1X + 2, b1Y - 11);
                }

                // Bounding Box 2: Static Marker
                float b2X = vpX + 160 + (float)Math.Cos(t * 6.28f) * 6f;
                float b2Y = vpY + 45 - (float)Math.Sin(t * 6.28f) * 6f;
                float b2W = 60, b2H = 45;
                using (var boxPen = new Pen(Color.FromArgb(160, 0, 240, 255), 1.2f)) {
                    g.DrawRectangle(boxPen, b2X, b2Y, b2W, b2H);
                }
                using (var hudFont = new Font("Consolas", 7f, FontStyle.Bold))
                using (var tagBg = new SolidBrush(Color.FromArgb(0, 180, 200)))
                using (var textBr = new SolidBrush(Color.Black)) {
                    g.FillRectangle(tagBg, b2X, b2Y - 12, 58, 12);
                    g.DrawString("GATE // 98.1%", hudFont, textBr, b2X + 2, b2Y - 11);
                }

                // Sparkline inference latency at bottom
                var sparkPts = new PointF[16];
                for (int k = 0; k < 16; k++) {
                    float sx = vpX + 120 + k * 9.5f;
                    float sy = vpY + vpH - 16 + (float)Math.Sin((k * 0.8f + t * 4f)) * 5f;
                    sparkPts[k] = new PointF(sx, sy);
                }
                using (var sparkPen = new Pen(Color.FromArgb(120, 192, 132, 252), 1.2f)) {
                    g.DrawLines(sparkPen, sparkPts);
                }

                // Viewport title & inference readout
                using (var hudFont = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var hudBrush = new SolidBrush(Color.FromArgb(221, 214, 254))) {
                    g.DrawString("YOLOv11-TENSORRT // CAM_01", hudFont, hudBrush, vpX + 8, vpY + 6);
                    g.DrawString("INFERENCE: 3.2ms", hudFont, hudBrush, vpX + 8, vpY + vpH - 15);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 4. Project Card 3: MPC
    public static void RenderCardMpc(string outputPath, int totalFrames = 24) {
        int w = 840, h = 150;
        var frames = new Bitmap[totalFrames];
        Color accent = Color.FromArgb(56, 189, 248); // Sky Blue

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Base card
                using (var brush = new SolidBrush(Color.FromArgb(8, 12, 20))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }
                using (var pen = new Pen(Color.FromArgb(26, 36, 52), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // Left vertical accent bar
                using (var brush = new SolidBrush(accent)) {
                    g.FillRectangle(brush, 0, 0, 4, h);
                }

                // Index & Name
                using (var font = new Font("Consolas", 13f, FontStyle.Bold))
                using (var brush = new SolidBrush(accent)) {
                    g.DrawString("03 // AUTONOMOUS_POLICY_MPC", font, brush, 24, 16);
                }
                // Status badge next to title
                using (var stFont = new Font("Consolas", 8.5f, FontStyle.Bold))
                using (var stBg = new SolidBrush(Color.FromArgb(15, 28, 44)))
                using (var stBorder = new Pen(Color.FromArgb(56, 189, 248), 1f))
                using (var stText = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.FillRectangle(stBg, 320, 16, 190, 20);
                    g.DrawRectangle(stBorder, 320, 16, 190, 20);
                    g.DrawString("[ACTIVE // SIM2REAL]", stFont, stText, 334, 19);
                }

                using (var font = new Font("Segoe UI", 9.5f, FontStyle.Bold))
                using (var brush = new SolidBrush(Color.FromArgb(241, 245, 249))) {
                    g.DrawString("Reinforcement Learning Policy & Nonlinear Model Predictive Control", font, brush, 25, 44);
                }
                using (var font = new Font("Segoe UI", 9f, FontStyle.Regular))
                using (var brush = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("Deep policy network paired with nonlinear Model Predictive Control (MPC)\nfor reactive trajectory optimization and agile collision avoidance.", font, brush, 25, 66);
                }

                // Tech tags
                string[] tags = new string[] { "Python", "Isaac Sim", "ROS 2", "MPC", "C++20" };
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

                // --- RIGHT SIDE: Animated Trajectory & Vector Viewport ---
                int vpX = 540, vpY = 12, vpW = 285, vpH = 126;
                using (var vpBg = new SolidBrush(Color.FromArgb(5, 8, 14))) {
                    g.FillRectangle(vpBg, vpX, vpY, vpW, vpH);
                }
                using (var vpBorder = new Pen(Color.FromArgb(24, 34, 50), 1f)) {
                    g.DrawRectangle(vpBorder, vpX, vpY, vpW, vpH);
                }

                // Corner ticks
                using (var p = new Pen(accent, 1.2f)) {
                    g.DrawLines(p, new Point[] { new Point(vpX, vpY + 8), new Point(vpX, vpY), new Point(vpX + 8, vpY) });
                    g.DrawLines(p, new Point[] { new Point(vpX + vpW - 9, vpY), new Point(vpX + vpW - 1, vpY), new Point(vpX + vpW - 1, vpY + 8) });
                    g.DrawLines(p, new Point[] { new Point(vpX, vpY + vpH - 9), new Point(vpX, vpY + vpH - 1), new Point(vpX + 8, vpY + vpH - 1) });
                    g.DrawLines(p, new Point[] { new Point(vpX + vpW - 9, vpY + vpH - 1), new Point(vpX + vpW - 1, vpY + vpH - 1), new Point(vpX + vpW - 1, vpY + vpH - 9) });
                }

                // Obstacle potential field node
                float obsX = vpX + 140f, obsY = vpY + 60f;
                using (var ringPen = new Pen(Color.FromArgb(40, 239, 68, 68), 1f)) {
                    g.DrawEllipse(ringPen, obsX - 25, obsY - 25, 50, 50);
                    g.DrawEllipse(ringPen, obsX - 40, obsY - 40, 80, 80);
                }
                using (var obsBrush = new SolidBrush(Color.FromArgb(239, 68, 68))) {
                    g.FillEllipse(obsBrush, obsX - 5, obsY - 5, 10, 10);
                }

                // Optimal Trajectory Spline curving smoothly around the obstacle
                var trajPts = new PointF[16];
                for (int i = 0; i < 16; i++) {
                    float s = (float)i / 15f;
                    float px = vpX + 20 + s * (vpW - 40);
                    // Gaussian repulsion around obstacle
                    float dx = px - obsX;
                    float repulsion = 32f * (float)Math.Exp(-(dx * dx) / (2f * 28f * 28f));
                    float py = vpY + 68f - repulsion + (float)Math.Sin(s * 5f) * 6f;
                    trajPts[i] = new PointF(px, py);
                }
                using (var trajPen = new Pen(Color.FromArgb(180, 56, 189, 248), 1.8f)) {
                    g.DrawCurve(trajPen, trajPts);
                }

                // Horizon Dots (MPC predicted states)
                for (int hStep = 0; hStep < 16; hStep++) {
                    PointF pt = trajPts[hStep];
                    float alphaVal = 0.5f + 0.45f * (float)Math.Sin((hStep * 0.4f + t * 4f));
                    int a = Math.Max(20, Math.Min(255, (int)(alphaVal * 255)));
                    using (var dotBrush = new SolidBrush(Color.FromArgb(a, 0, 240, 255))) {
                        g.FillEllipse(dotBrush, pt.X - 2f, pt.Y - 2f, 4f, 4f);
                    }
                }

                // Moving Agent tracking trajectory
                float agentProgress = (t * 1.5f) % 1.0f;
                int agIdx = Math.Min(14, (int)(agentProgress * 15));
                PointF pA = trajPts[agIdx];
                PointF pB = trajPts[agIdx + 1];
                float subT = (agentProgress * 15) - agIdx;
                float curX = pA.X + (pB.X - pA.X) * subT;
                float curY = pA.Y + (pB.Y - pA.Y) * subT;

                using (var agBrush = new SolidBrush(Color.White)) {
                    g.FillEllipse(agBrush, curX - 4, curY - 4, 8, 8);
                }
                using (var agRing = new Pen(Color.FromArgb(0, 240, 255), 1.4f)) {
                    g.DrawEllipse(agRing, curX - 8, curY - 8, 16, 16);
                }

                // Heading vector line
                float angle = (float)Math.Atan2(pB.Y - pA.Y, pB.X - pA.X);
                float hx = curX + (float)Math.Cos(angle) * 16f;
                float hy = curY + (float)Math.Sin(angle) * 16f;
                using (var headPen = new Pen(Color.FromArgb(0, 240, 255), 1.6f)) {
                    g.DrawLine(headPen, curX, curY, hx, hy);
                }

                // Viewport text overlay
                using (var hudFont = new Font("Consolas", 7.5f, FontStyle.Bold))
                using (var hudBrush = new SolidBrush(Color.FromArgb(186, 230, 253))) {
                    g.DrawString("MPC // REAL-TIME PLANNER", hudFont, hudBrush, vpX + 8, vpY + 6);
                    g.DrawString("HORIZON: 20 STEPS @ 100Hz", hudFont, hudBrush, vpX + 8, vpY + vpH - 15);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 5. Divider Generator
    public static void RenderDivider(string outputPath, int totalFrames = 20) {
        int w = 840, h = 24;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float progress = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Base line
                using (var linePen = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawLine(linePen, 0, h / 2, w, h / 2);
                }

                // Center badge
                int bw = 240, bh = 18;
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
                    var str = "[ NCC-077 // AUTONOMOUS_CORE ]";
                    var sz = g.MeasureString(str, font);
                    g.DrawString(str, font, textBrush, bx + (bw - sz.Width) / 2, by + 2);
                }

                // Traveling pulse beam
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

    // 6. Telemetry Dual Console
    public static void RenderTelemetry(string outputPath, int totalFrames = 24) {
        int w = 840, h = 240;
        var frames = new Bitmap[totalFrames];

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Background
                using (var brush = new SolidBrush(Color.FromArgb(7, 9, 14))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }

                // ================= LEFT TERMINAL: STATS =================
                int t1X = 0, t1Y = 0, t1W = 412, t1H = h;
                using (var tBg = new SolidBrush(Color.FromArgb(10, 14, 22))) {
                    g.FillRectangle(tBg, t1X, t1Y, t1W, t1H);
                }
                using (var tBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawRectangle(tBorder, t1X, t1Y, t1W - 1, t1H - 1);
                }
                // Header bar
                using (var hBg = new SolidBrush(Color.FromArgb(15, 21, 32))) {
                    g.FillRectangle(hBg, t1X, t1Y, t1W, 28);
                }
                using (var hBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawLine(hBorder, t1X, t1Y + 28, t1X + t1W, t1Y + 28);
                }
                // Traffic light dots
                g.FillEllipse(new SolidBrush(Color.FromArgb(255, 95, 86)), t1X + 12, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(254, 188, 46)), t1X + 28, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(39, 201, 63)), t1X + 44, 9, 10, 10);
                // Terminal title
                using (var fTitle = new Font("Consolas", 9f, FontStyle.Regular))
                using (var bTitle = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("~/stats $ ./metrics --live", fTitle, bTitle, t1X + 64, 7);
                }

                // Numbers summary: stars, repos, followers
                using (var numFont = new Font("Consolas", 18f, FontStyle.Bold))
                using (var lblFont = new Font("Consolas", 8.5f, FontStyle.Regular)) {
                    // Stars
                    g.DrawString("85", numFont, new SolidBrush(Color.FromArgb(0, 240, 255)), t1X + 30, 42);
                    g.DrawString("stars *", lblFont, new SolidBrush(Color.FromArgb(148, 163, 184)), t1X + 32, 70);

                    // Repos
                    g.DrawString("24", numFont, new SolidBrush(Color.FromArgb(167, 139, 250)), t1X + 160, 42);
                    g.DrawString("repositories", lblFont, new SolidBrush(Color.FromArgb(148, 163, 184)), t1X + 156, 70);

                    // Followers
                    g.DrawString("36", numFont, new SolidBrush(Color.FromArgb(56, 189, 248)), t1X + 290, 42);
                    g.DrawString("followers", lblFont, new SolidBrush(Color.FromArgb(148, 163, 184)), t1X + 290, 70);
                }

                // Subtitle
                using (var fSub = new Font("Consolas", 8.5f, FontStyle.Bold))
                using (var bSub = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("// language distribution", fSub, bSub, t1X + 24, 96);
                }

                // Language Progress bars
                string[] langs = new string[] { "python", "c++20", "cuda / c" };
                int[] pcts = new int[] { 68, 22, 10 };
                Color[] barColors = new Color[] { Color.FromArgb(0, 240, 255), Color.FromArgb(167, 139, 250), Color.FromArgb(56, 189, 248) };

                for (int l = 0; l < 3; l++) {
                    int ly = 118 + l * 26;
                    using (var fLang = new Font("Consolas", 9f, FontStyle.Regular))
                    using (var bLang = new SolidBrush(Color.FromArgb(203, 213, 225))) {
                        g.DrawString(langs[l], fLang, bLang, t1X + 24, ly);
                    }

                    // Bar background
                    int bx = t1X + 105, bw = 230, bh = 14;
                    using (var bgBar = new SolidBrush(Color.FromArgb(20, 28, 42))) {
                        g.FillRectangle(bgBar, bx, ly + 2, bw, bh);
                    }

                    // Filled bar
                    float fillW = bw * (pcts[l] / 100f);
                    using (var fillBar = new SolidBrush(barColors[l])) {
                        g.FillRectangle(fillBar, bx, ly + 2, fillW, bh);
                    }

                    // Highlight shimmer on the top bar
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

                    // Percentage label
                    using (var fPct = new Font("Consolas", 8.5f, FontStyle.Bold))
                    using (var bPct = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                        g.DrawString(pcts[l] + "%", fPct, bPct, bx + bw + 10, ly);
                    }
                }

                // Terminal 1 footer
                using (var fFoot = new Font("Consolas", 8f, FontStyle.Regular))
                using (var bFoot = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("[SYNC] live metrics  //  rebuilt today  //  autonomous feed", fFoot, bFoot, t1X + 24, 212);
                }

                // ================= RIGHT TERMINAL: OPS LOG =================
                int t2X = 428, t2Y = 0, t2W = 412, t2H = h;
                using (var tBg = new SolidBrush(Color.FromArgb(10, 14, 22))) {
                    g.FillRectangle(tBg, t2X, t2Y, t2W, t2H);
                }
                using (var tBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawRectangle(tBorder, t2X, t2Y, t2W - 1, t2H - 1);
                }
                // Header bar
                using (var hBg = new SolidBrush(Color.FromArgb(15, 21, 32))) {
                    g.FillRectangle(hBg, t2X, t2Y, t2W, 28);
                }
                using (var hBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawLine(hBorder, t2X, t2Y + 28, t2X + t2W, t2Y + 28);
                }
                // Traffic light dots
                g.FillEllipse(new SolidBrush(Color.FromArgb(255, 95, 86)), t2X + 12, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(254, 188, 46)), t2X + 28, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(39, 201, 63)), t2X + 44, 9, 10, 10);
                // Terminal title
                using (var fTitle = new Font("Consolas", 9f, FontStyle.Regular))
                using (var bTitle = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("~/ops $ tail -f telemetry.log", fTitle, bTitle, t2X + 64, 7);
                }

                // Log entries
                string[] logs = new string[] {
                    "[00:42:01] BOOT: Neural Control Lab v2.0",
                    "[00:42:02] SYNC: Stereo cam: 120mm @ 1080p60",
                    "[00:42:03] SYNC: LiDAR 128-beam stream [OK]",
                    "[00:42:03] CUDA: Allocated device VRAM 4.8GB",
                    "[00:42:04] TRT:  Loaded yolov11_perception.plan",
                    "[00:42:05] PERC: Inference latency 3.2ms",
                    "[00:42:06] ROS2: Active: /camera /lidar /mpc",
                    "[00:42:07] STAT: Perception-Action LOCKED"
                };

                using (var logFont = new Font("Consolas", 8.5f, FontStyle.Regular)) {
                    for (int m = 0; m < logs.Length; m++) {
                        int ly = 38 + m * 20;
                        Color textC = Color.FromArgb(148, 163, 184);
                        if (logs[m].Contains("BOOT")) textC = Color.FromArgb(56, 189, 248);
                        if (logs[m].Contains("[OK]") || logs[m].Contains("LOCKED")) textC = Color.FromArgb(0, 240, 255);
                        if (logs[m].Contains("TRT") || logs[m].Contains("PERC")) textC = Color.FromArgb(167, 139, 250);

                        using (var bText = new SolidBrush(textC)) {
                            g.DrawString(logs[m], logFont, bText, t2X + 16, ly);
                        }
                    }

                    // Blinking terminal cursor
                    if ((int)(t * 6) % 2 == 0) {
                        using (var cursorBrush = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                            g.FillRectangle(cursorBrush, t2X + 16 + 280, 38 + 7 * 20, 7, 13);
                        }
                    }
                }

                // Terminal 2 footer
                using (var fFoot = new Font("Consolas", 8f, FontStyle.Regular))
                using (var bFoot = new SolidBrush(Color.FromArgb(0, 240, 255))) {
                    g.DrawString("[OK] live stream  //  all subsystems nominal", fFoot, bFoot, t2X + 16, 212);
                }
            }
            frames[f] = bmp;
        }

        GifMaker.SaveGif(outputPath, frames, 80);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }

    // 7. Contribution Scanner (Yearly commit grid with laser scan)
    public static void RenderContrib(string outputPath, int totalFrames = 26) {
        int w = 840, h = 180;
        var frames = new Bitmap[totalFrames];

        // Generate synthetic consistent commit heatmap
        int weeks = 52, days = 7;
        int[,] grid = new int[weeks, days];
        Random rnd = new Random(77);
        for (int x = 0; x < weeks; x++) {
            for (int y = 0; y < days; y++) {
                double r = rnd.NextDouble();
                if (r > 0.45) {
                    if (r > 0.88) grid[x, y] = 4;
                    else if (r > 0.72) grid[x, y] = 3;
                    else if (r > 0.58) grid[x, y] = 2;
                    else grid[x, y] = 1;
                } else {
                    grid[x, y] = 0;
                }
            }
        }

        Color[] tileColors = new Color[] {
            Color.FromArgb(15, 23, 34),   // 0
            Color.FromArgb(14, 68, 48),   // 1
            Color.FromArgb(16, 110, 70),  // 2
            Color.FromArgb(20, 160, 95),  // 3
            Color.FromArgb(0, 240, 150)   // 4
        };

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                SetHighQuality(g);

                // Terminal panel base
                using (var brush = new SolidBrush(Color.FromArgb(10, 14, 22))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }
                using (var pen = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // Terminal title bar
                using (var hBg = new SolidBrush(Color.FromArgb(15, 21, 32))) {
                    g.FillRectangle(hBg, 0, 0, w, 28);
                }
                using (var hBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
                    g.DrawLine(hBorder, 0, 28, w, 28);
                }
                // Traffic light dots
                g.FillEllipse(new SolidBrush(Color.FromArgb(255, 95, 86)), 12, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(254, 188, 46)), 28, 9, 10, 10);
                g.FillEllipse(new SolidBrush(Color.FromArgb(39, 201, 63)), 44, 9, 10, 10);
                // Terminal title
                using (var fTitle = new Font("Consolas", 9f, FontStyle.Regular))
                using (var bTitle = new SolidBrush(Color.FromArgb(148, 163, 184))) {
                    g.DrawString("~/contrib $ ./scan --year", fTitle, bTitle, 64, 7);
                }
                using (var fStat = new Font("Consolas", 9f, FontStyle.Bold))
                using (var bStat = new SolidBrush(Color.FromArgb(56, 189, 248))) {
                    g.DrawString("1,428 CONTRIBUTIONS // CONTINUOUS PIPELINE", fStat, bStat, w - 340, 7);
                }

                // Month labels
                string[] months = new string[] { "aug", "oct", "nov", "dec", "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug" };
                using (var mFont = new Font("Consolas", 8f, FontStyle.Regular))
                using (var mBrush = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    for (int mi = 0; mi < months.Length; mi++) {
                        g.DrawString(months[mi], mFont, mBrush, 55 + mi * 62, 36);
                    }
                }

                // Day labels
                using (var dFont = new Font("Consolas", 8f, FontStyle.Regular))
                using (var dBrush = new SolidBrush(Color.FromArgb(100, 116, 139))) {
                    g.DrawString("mon", dFont, dBrush, 22, 64);
                    g.DrawString("wed", dFont, dBrush, 22, 90);
                    g.DrawString("fri", dFont, dBrush, 22, 116);
                }

                // Draw Contribution Tiles
                int startX = 55, startY = 52, tileSize = 11, tileGap = 3;
                float laserX = startX + t * (weeks * (tileSize + tileGap));

                for (int x = 0; x < weeks; x++) {
                    int tx = startX + x * (tileSize + tileGap);
                    for (int y = 0; y < days; y++) {
                        int ty = startY + y * (tileSize + tileGap);
                        int level = grid[x, y];
                        Color col = tileColors[level];

                        // If laser recently swept, illuminate the tile
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

                // Laser Beam
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

                // Legend at bottom right
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

    // 8. Tech Stack Card
    public static void RenderStack(string outputPath, int totalFrames = 20) {
        int w = 840, h = 180;
        var frames = new Bitmap[totalFrames];

        string[] colTitles = new string[] { "01 // LANGUAGES", "02 // AI & DEEP LEARNING", "03 // ROBOTICS & CONTROL", "04 // VISION & SLAM" };
        string[][] colItems = new string[][] {
            new string[] { "C++20 / C++17", "Python 3.11+", "CUDA C++", "POSIX / Linux Bash" },
            new string[] { "PyTorch / LibTorch", "TensorRT 10.x", "ONNX Runtime", "Deep RL (PPO / SAC)" },
            new string[] { "ROS / ROS 2 (Humble)", "Nav2 Path Planning", "MoveIt 2 Manip", "Isaac Sim & Gazebo" },
            new string[] { "OpenCV & VPI", "Point Cloud Lib (PCL)", "ORB-SLAM3 / RTAB", "Jetson Orin AGX" }
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

                // Base card
                using (var brush = new SolidBrush(Color.FromArgb(8, 12, 20))) {
                    g.FillRectangle(brush, 0, 0, w, h);
                }
                using (var pen = new Pen(Color.FromArgb(26, 36, 52), 1f)) {
                    g.DrawRectangle(pen, 0, 0, w - 1, h - 1);
                }

                // 4 Columns
                int colW = 196, colH = 156;
                for (int c = 0; c < 4; c++) {
                    int cx = 14 + c * (colW + 8);
                    int cy = 12;

                    // Column background
                    using (var cBg = new SolidBrush(Color.FromArgb(12, 17, 27))) {
                        g.FillRectangle(cBg, cx, cy, colW, colH);
                    }
                    using (var cBorder = new Pen(Color.FromArgb(28, 40, 58), 1f)) {
                        g.DrawRectangle(cBorder, cx, cy, colW, colH);
                    }

                    // Column top accent bar
                    using (var cAccent = new SolidBrush(colAccents[c])) {
                        g.FillRectangle(cAccent, cx, cy, colW, 3);
                    }

                    // Column header
                    using (var hFont = new Font("Consolas", 8.5f, FontStyle.Bold))
                    using (var hBrush = new SolidBrush(colAccents[c])) {
                        g.DrawString(colTitles[c], hFont, hBrush, cx + 8, cy + 12);
                    }

                    // Separator line
                    using (var sepPen = new Pen(Color.FromArgb(24, 34, 50), 1f)) {
                        g.DrawLine(sepPen, cx + 8, cy + 30, cx + colW - 8, cy + 30);
                    }

                    // Item rows
                    using (var itemFont = new Font("Segoe UI", 8.5f, FontStyle.Regular))
                    using (var itemBrush = new SolidBrush(Color.FromArgb(226, 232, 240))) {
                        for (int r = 0; r < colItems[c].Length; r++) {
                            int ry = cy + 42 + r * 26;

                            // Small indicator dot
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

Write-Host "=================================================="
Write-Host "Generating Full Cyber GIF Suite for CapedCrusader77"
Write-Host "=================================================="

Write-Host "Rendering banner_work.gif..."
[AssetGenerator]::RenderBanner("$assetsDir\banner_work.gif", ">> SELECTED BUILDS", "// 3 AUTONOMOUS PRODUCTION SYSTEMS", "[ACTIVE BUILDS]", [System.Drawing.Color]::FromArgb(0, 240, 255))

Write-Host "Rendering card_slam.gif..."
[AssetGenerator]::RenderCardSlam("$assetsDir\card_slam.gif")

Write-Host "Rendering card_vision.gif..."
[AssetGenerator]::RenderCardVision("$assetsDir\card_vision.gif")

Write-Host "Rendering card_mpc.gif..."
[AssetGenerator]::RenderCardMpc("$assetsDir\card_mpc.gif")

Write-Host "Rendering divider.gif..."
[AssetGenerator]::RenderDivider("$assetsDir\divider.gif")

Write-Host "Rendering banner_telemetry.gif..."
[AssetGenerator]::RenderBanner("$assetsDir\banner_telemetry.gif", ">> LIVE TELEMETRY", "// REAL-TIME SYSTEM MONITORING & AUDIT", "[100Hz STREAM]", [System.Drawing.Color]::FromArgb(56, 189, 248))

Write-Host "Rendering telemetry.gif..."
[AssetGenerator]::RenderTelemetry("$assetsDir\telemetry.gif")

Write-Host "Rendering contrib.gif..."
[AssetGenerator]::RenderContrib("$assetsDir\contrib.gif")

Write-Host "Rendering banner_stack.gif..."
[AssetGenerator]::RenderBanner("$assetsDir\banner_stack.gif", ">> TECHNICAL ARSENAL", "// CORE RUNTIME & ARCHITECTURE LOADOUT", "[VERIFIED]", [System.Drawing.Color]::FromArgb(167, 139, 250))

Write-Host "Rendering stack.gif..."
[AssetGenerator]::RenderStack("$assetsDir\stack.gif")

Write-Host "Rendering banner_contact.gif..."
[AssetGenerator]::RenderBanner("$assetsDir\banner_contact.gif", ">> CONTROL UPLINK", "// SECURE COMMS & TRANSMISSION CHANNELS", "[TRANSMITTING]", [System.Drawing.Color]::FromArgb(0, 240, 255))

Write-Host "=================================================="
Write-Host "All Cyber GIF Suite assets rendered successfully!"
Get-ChildItem $assetsDir\*.gif | Select-Object Name, Length
