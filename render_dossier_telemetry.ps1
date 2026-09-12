$ErrorActionPreference = "Stop"
$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class DossierTelemetry {
    static Color C(int a, int r, int g, int b) { return Color.FromArgb(a, r, g, b); }

    static readonly Color Charcoal = C(255, 16, 16, 18);
    static readonly Color Paper = C(255, 226, 218, 201);
    static readonly Color PaperLight = C(255, 239, 232, 215);
    static readonly Color Ink = C(255, 28, 27, 30);
    static readonly Color Red = C(255, 198, 54, 58);
    static readonly Color RedSoft = C(170, 198, 54, 58);
    static readonly Color Ash = C(235, 199, 193, 184);

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
                            } else fs.Write(bytes, imgStart, bytes.Length - imgStart - 1);
                        }
                    }
                }
            }
            fs.WriteByte(0x3B);
        }
    }

    static void Quality(Graphics g) {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
    }

    static void Text(Graphics g, string value, string family, float size, FontStyle style, Color color, float x, float y) {
        using (var f = new Font(family, size, style)) using (var b = new SolidBrush(color)) g.DrawString(value, f, b, x, y);
    }

    static void Dot(Graphics g, float x, float y, float r, Color color, float pulse) {
        float halo = 2.0f + pulse;
        using (var b = new SolidBrush(C(28, color.R, color.G, color.B))) g.FillEllipse(b, x - r * halo, y - r * halo, r * halo * 2, r * halo * 2);
        using (var b = new SolidBrush(color)) g.FillEllipse(b, x - r, y - r, r * 2, r * 2);
    }

    static void Stamp(Graphics g, string value, float x, float y, float angle) {
        var state = g.Save();
        g.TranslateTransform(x, y);
        g.RotateTransform(angle);
        using (var f = new Font("Consolas", 6.2f, FontStyle.Bold))
        using (var b = new SolidBrush(RedSoft))
        using (var p = new Pen(RedSoft, 1f)) {
            g.DrawRectangle(p, 0, 0, 42, 15);
            g.DrawString(value, f, b, 4, 3);
        }
        g.Restore(state);
    }

    static PointF Along(PointF a, PointF b, float t) { return new PointF(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t); }

    static void DrawArt(Graphics g, int kind, float t) {
        int x = 12, y = 38, w = 250, h = 128;
        using (var b = new SolidBrush(Paper)) g.FillRectangle(b, x, y, w, h);
        using (var p = new Pen(C(190, Ink.R, Ink.G, Ink.B), 1f)) g.DrawRectangle(p, x, y, w, h);
        using (var p = new Pen(C(55, Ink.R, Ink.G, Ink.B), 1f)) {
            for (int gx = x + 20; gx < x + w; gx += 32) g.DrawLine(p, gx, y + 8, gx, y + h - 8);
            for (int gy = y + 24; gy < y + h; gy += 28) g.DrawLine(p, x + 8, gy, x + w - 8, gy);
        }
        float sweep = x + 18 + ((t * 0.78f + kind * 0.13f) % 1f) * (w - 36);
        using (var p = new Pen(RedSoft, 1.2f)) g.DrawLine(p, sweep, y + 8, sweep, y + h - 8);

        if (kind == 1) {
            PointF[] path = new PointF[] { new PointF(24, 119), new PointF(72, 82), new PointF(124, 105), new PointF(178, 76), new PointF(244, 96) };
            using (var p = new Pen(Ink, 1.2f)) g.DrawLines(p, path);
            for (int r = 18; r <= 48; r += 10) using (var p = new Pen(C(145, Ink.R, Ink.G, Ink.B), 1f)) g.DrawEllipse(p, 136 - r, 101 - r, r * 2, r * 2);
            using (var p = new Pen(Ink, 1.1f)) { g.DrawEllipse(p, 122, 87, 28, 28); g.DrawLine(p, 122, 101, 150, 101); g.DrawLine(p, 136, 87, 136, 115); }
            float q = (t * 0.82f) % 1f;
            int segment = Math.Min(path.Length - 2, (int)(q * (path.Length - 1)));
            Dot(g, Along(path[segment], path[segment + 1], (q * (path.Length - 1)) - segment).X, Along(path[segment], path[segment + 1], (q * (path.Length - 1)) - segment).Y, 2.2f, Red, 0.55f);
            Text(g, "FIELD NOTES", "Consolas", 6.4f, FontStyle.Bold, Ink, 20, 148);
            Stamp(g, "CASE 01", 193, 54, -7f);
        } else if (kind == 2) {
            PointF[] nodes = new PointF[] { new PointF(28, 102), new PointF(74, 72), new PointF(74, 132), new PointF(130, 101), new PointF(186, 72), new PointF(186, 132), new PointF(238, 101) };
            int[,] edges = new int[,] { {0,1},{0,2},{1,3},{2,3},{3,4},{3,5},{4,6},{5,6} };
            using (var p = new Pen(C(175, Ink.R, Ink.G, Ink.B), 1.1f)) for (int i = 0; i < edges.GetLength(0); i++) g.DrawLine(p, nodes[edges[i,0]], nodes[edges[i,1]]);
            for (int i = 0; i < nodes.Length; i++) Dot(g, nodes[i].X, nodes[i].Y, i == 3 ? 3.0f : 1.8f, i == 3 ? Red : Ink, i == 3 ? 0.45f : 0.12f);
            float route = (t * 0.68f) % 1f;
            int edge = Math.Min(edges.GetLength(0) - 1, (int)(route * edges.GetLength(0)));
            float local = route * edges.GetLength(0) - edge;
            PointF moving = Along(nodes[edges[edge,0]], nodes[edges[edge,1]], local);
            Dot(g, moving.X, moving.Y, 2.2f, Red, 0.5f);
            Text(g, "EVIDENCE MAP", "Consolas", 6.4f, FontStyle.Bold, Ink, 20, 148);
            Stamp(g, "CASE 02", 193, 54, 6f);
        } else {
            using (var p = new Pen(C(170, Ink.R, Ink.G, Ink.B), 1f)) {
                g.DrawLine(p, 26, 132, 239, 132);
                g.DrawLine(p, 42, 132, 42, 72);
                for (int i = 0; i < 5; i++) g.DrawLine(p, 42 + i * 38, 132, 42 + i * 38, 128 - i * 7);
                g.DrawArc(p, 132, 58, 76, 76, 210, 120);
            }
            PointF[] route = new PointF[] { new PointF(36, 127), new PointF(80, 118), new PointF(118, 122), new PointF(162, 94), new PointF(226, 78) };
            using (var p = new Pen(Ink, 1.25f)) g.DrawLines(p, route);
            using (var p = new Pen(Red, 1.2f)) { g.DrawLine(p, 226, 78, 215, 73); g.DrawLine(p, 226, 78, 218, 87); }
            float q = (t * 0.78f) % 1f;
            int segment = Math.Min(route.Length - 2, (int)(q * (route.Length - 1)));
            PointF moving = Along(route[segment], route[segment + 1], (q * (route.Length - 1)) - segment);
            Dot(g, moving.X, moving.Y, 2.2f, Red, 0.55f);
            Text(g, "ROUTE PLAN", "Consolas", 6.4f, FontStyle.Bold, Ink, 20, 148);
            Stamp(g, "CASE 03", 193, 54, -5f);
        }
    }

    public static Bitmap[] GenerateCard(int kind, int totalFrames = 48) {
        int w = 274, h = 340;
        var frames = new Bitmap[totalFrames];
        string[] headers = new string[] { "OBSERVE", "CONNECT", "MOVE" };
        string[] titles = new string[] { "PERCEPTION", "REASONING", "ACTION" };
        string[] subtitles = new string[] { "CAMERA + DEPTH", "CAUSE + EFFECT", "RANGE + HEADING" };
        string[] descriptions = new string[] { "Stable landmarks from visual input.", "A usable policy from connected evidence.", "A safe move from measured space." };
        string[][] chips = new string[][] { new string[] { "Vision", "OpenCV", "WASM" }, new string[] { "Graph", "Policy", "Trace" }, new string[] { "LiDAR", "Nav", "Control" } };
        Color[] accents = new Color[] { C(255, 188, 55, 58), C(255, 188, 55, 58), C(255, 188, 55, 58) };
        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                Quality(g);
                using (var b = new SolidBrush(Charcoal)) g.FillRectangle(b, 0, 0, w, h);
                DrawArt(g, kind, t);
                using (var p = new Pen(C(215, Red.R, Red.G, Red.B), 1f)) g.DrawRectangle(p, 2, 2, w - 5, h - 5);
                using (var p = new Pen(C(210, Red.R, Red.G, Red.B), 2f)) g.DrawLine(p, 3, 3, w - 4, 3);
                using (var p = new Pen(C(90, Red.R, Red.G, Red.B), 1f)) { g.DrawLine(p, 3, 3, 3, 18); g.DrawLine(p, w - 4, h - 18, w - 4, h - 3); }
                Text(g, String.Format("{0:00} // {1}", kind, headers[kind - 1]), "Consolas", 7.2f, FontStyle.Bold, PaperLight, 13, 13);
                using (var b = new SolidBrush(Red)) g.FillEllipse(b, w - 68, 17, 5, 5);
                Text(g, "ACTIVE", "Consolas", 6.7f, FontStyle.Bold, PaperLight, w - 57, 12);
                using (var p = new Pen(C(80, Paper.R, Paper.G, Paper.B), 1f)) g.DrawLine(p, 12, 175, w - 12, 175);
                using (var b = new SolidBrush(Red)) g.FillRectangle(b, 12, 188, 3, 16);
                Text(g, titles[kind - 1], "Segoe UI", 11.7f, FontStyle.Bold, PaperLight, 21, 181);
                Text(g, subtitles[kind - 1], "Consolas", 6.8f, FontStyle.Bold, Red, 13, 208);
                Text(g, descriptions[kind - 1], "Segoe UI", 8.2f, FontStyle.Regular, Ash, 13, 232);
                float px = 13f;
                using (var fChip = new Font("Consolas", 6.7f, FontStyle.Regular)) foreach (var chip in chips[kind - 1]) {
                    var sz = g.MeasureString(chip, fChip); int pw = (int)sz.Width + 10;
                    using (var b = new SolidBrush(C(215, Paper.R, Paper.G, Paper.B))) g.FillRectangle(b, px, 296, pw, 20);
                    using (var p = new Pen(C(180, Paper.R, Paper.G, Paper.B), 1f)) g.DrawRectangle(p, px, 296, pw, 20);
                    using (var bt = new SolidBrush(Ink)) g.DrawString(chip, fChip, bt, px + 5, 300);
                    px += pw + 5;
                }
                Text(g, "FILED", "Consolas", 7.1f, FontStyle.Bold, Red, w - 49, 301);
            }
            frames[f] = bmp;
        }
        return frames;
    }

    public static Bitmap[] GenerateBanner(int totalFrames = 48) {
        int w = 840, h = 42;
        var frames = new Bitmap[totalFrames];
        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                Quality(g);
                using (var b = new SolidBrush(Charcoal)) g.FillRectangle(b, 0, 0, w, h);
                using (var b = new SolidBrush(Paper)) g.FillRectangle(b, 12, 6, 194, 30);
                using (var p = new Pen(Red, 1f)) g.DrawRectangle(p, 12, 6, 194, 30);
                Text(g, "02 // CASE FILE", "Georgia", 11.2f, FontStyle.Bold, Ink, 20, 11);
                Text(g, "PERCEPTION  /  REASONING  /  ACTION", "Consolas", 7.1f, FontStyle.Regular, PaperLight, 232, 14);
                Text(g, "RESEARCH LOG", "Consolas", 6.8f, FontStyle.Bold, Red, 232, 26);
                int stampX = 740 + (int)(Math.Sin(t * Math.PI * 2f) * 4f);
                using (var p = new Pen(Red, 1f)) g.DrawRectangle(p, stampX, 9, 82, 24);
                Text(g, "OPEN / 03", "Consolas", 7.2f, FontStyle.Bold, PaperLight, stampX + 12, 16);
                using (var p = new Pen(C(150, Red.R, Red.G, Red.B), 1f)) g.DrawLine(p, 214, 36, 824, 36);
            }
            frames[f] = bmp;
        }
        return frames;
    }

    public static void SaveRow(string outputPath, Bitmap[][] cards, int delayMs) {
        int w = 840, h = 360, totalFrames = cards[0].Length;
        var row = new Bitmap[totalFrames];
        for (int f = 0; f < totalFrames; f++) {
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                g.Clear(Charcoal);
                g.DrawImage(cards[0][f], 4, 10, 274, 340);
                g.DrawImage(cards[1][f], 284, 10, 274, 340);
                g.DrawImage(cards[2][f], 564, 10, 274, 340);
            }
            row[f] = bmp;
        }
        SaveGif(outputPath, row, delayMs);
        row[0].Save(outputPath.Replace(".gif", ".png"), ImageFormat.Png);
        for (int f = 0; f < totalFrames; f++) row[f].Dispose();
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing"
$assetsDir = "E:\Projects\Readme\assets"
$perception = [DossierTelemetry]::GenerateCard(1, 48)
$reasoning = [DossierTelemetry]::GenerateCard(2, 48)
$action = [DossierTelemetry]::GenerateCard(3, 48)

$perception[0].Save("$assetsDir\telemetry_perception.png", [System.Drawing.Imaging.ImageFormat]::Png)
$reasoning[0].Save("$assetsDir\telemetry_reasoning.png", [System.Drawing.Imaging.ImageFormat]::Png)
$action[0].Save("$assetsDir\telemetry_action.png", [System.Drawing.Imaging.ImageFormat]::Png)
[DossierTelemetry]::SaveGif("$assetsDir\telemetry_perception.gif", $perception, 55)
[DossierTelemetry]::SaveGif("$assetsDir\telemetry_reasoning.gif", $reasoning, 55)
[DossierTelemetry]::SaveGif("$assetsDir\telemetry_action.gif", $action, 55)
[DossierTelemetry]::SaveRow("$assetsDir\telemetry_cards.gif", @($perception, $reasoning, $action), 55)
Copy-Item "$assetsDir\telemetry_cards.gif" "$assetsDir\telemetry.gif" -Force
Copy-Item "$assetsDir\telemetry_cards.png" "$assetsDir\telemetry.png" -Force

$banner = [DossierTelemetry]::GenerateBanner(48)
$banner[0].Save("$assetsDir\banner_telemetry_v3.png", [System.Drawing.Imaging.ImageFormat]::Png)
[DossierTelemetry]::SaveGif("$assetsDir\banner_telemetry_v3.gif", $banner, 55)
Copy-Item "$assetsDir\banner_telemetry_v3.gif" "$assetsDir\banner_telemetry.gif" -Force
Copy-Item "$assetsDir\banner_telemetry_v3.gif" "$assetsDir\banner_telemetry_v2.gif" -Force

foreach ($frames in @($perception, $reasoning, $action, $banner)) { foreach ($frame in $frames) { $frame.Dispose() } }
Write-Host "Dossier telemetry rendered: cards, row, and banner."
