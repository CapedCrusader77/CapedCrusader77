$ErrorActionPreference = "Stop"
$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class TelemetryCards {
    static Color C(int a, int r, int g, int b) { return Color.FromArgb(a, r, g, b); }

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
        using (var f = new Font(family, size, style))
        using (var b = new SolidBrush(color)) g.DrawString(value, f, b, x, y);
    }

    static void Brackets(Graphics g, float x, float y, float w, float h, Color color) {
        using (var p = new Pen(color, 1.4f)) {
            float s = 10f;
            g.DrawLines(p, new PointF[] { new PointF(x, y + s), new PointF(x, y), new PointF(x + s, y) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - s, y), new PointF(x + w, y), new PointF(x + w, y + s) });
            g.DrawLines(p, new PointF[] { new PointF(x, y + h - s), new PointF(x, y + h), new PointF(x + s, y + h) });
            g.DrawLines(p, new PointF[] { new PointF(x + w - s, y + h), new PointF(x + w, y + h), new PointF(x + w, y + h - s) });
        }
    }

    static void Grid(Graphics g, int x, int y, int w, int h, int step) {
        using (var p = new Pen(C(36, 38, 63, 82), 1f)) {
            p.DashStyle = DashStyle.Dot;
            for (int gx = x + step; gx < x + w; gx += step) g.DrawLine(p, gx, y, gx, y + h);
            for (int gy = y + step; gy < y + h; gy += step) g.DrawLine(p, x, gy, x + w, gy);
        }
    }

    static void Dot(Graphics g, float x, float y, float r, Color color, float phase) {
        float spread = 2.5f + phase;
        using (var b = new SolidBrush(C(24, color.R, color.G, color.B))) g.FillEllipse(b, x - r * spread, y - r * spread, r * spread * 2, r * spread * 2);
        using (var b = new SolidBrush(C(220, color.R, color.G, color.B))) g.FillEllipse(b, x - r, y - r, r * 2, r * 2);
    }

    static void Flow(Graphics g, float t, PointF a, PointF b, PointF c, PointF d, Color color) {
        using (var path = new GraphicsPath()) {
            path.AddBezier(a, b, c, d);
            using (var p = new Pen(C(42, color.R, color.G, color.B), 4f)) g.DrawPath(p, path);
            using (var p = new Pen(C(180, color.R, color.G, color.B), 1.1f)) g.DrawPath(p, path);
            float p1 = (t * 0.7f) % 1f;
            float q = 1f - p1;
            float x = q*q*q*a.X + 3*q*q*p1*b.X + 3*q*p1*p1*c.X + p1*p1*p1*d.X;
            float y = q*q*q*a.Y + 3*q*q*p1*b.Y + 3*q*p1*p1*c.Y + p1*p1*p1*d.Y;
            Dot(g, x, y, 1.7f, color, 0.35f);
        }
    }

    static void DrawArt(Graphics g, int kind, float t, Color accent) {
        int x = 8, y = 36, w = 258, h = 130;
        using (var b = new SolidBrush(C(210, 4, 9, 18))) g.FillRectangle(b, x, y, w, h);
        using (var p = new Pen(C(60, 40, 53, 75), 1f)) g.DrawRectangle(p, x, y, w, h);
        Grid(g, x + 8, y + 8, w - 16, h - 16, 28);

        if (kind == 1) {
            Color cyan = C(235, 76, 231, 255), violet = C(205, 172, 127, 255);
            float scan = x + 18 + ((t * 1.3f) % 1f) * (w - 36);
            using (var p = new Pen(C(95, 76, 231, 255), 1f)) g.DrawLine(p, scan, y + 12, scan, y + h - 12);
            for (int r = 12; r <= 42; r += 10) using (var p = new Pen(C(55, 76, 231, 255), 1f)) g.DrawEllipse(p, 137 - r, 99 - r, r * 2, r * 2);
            using (var p = new Pen(C(180, 76, 231, 255), 1.2f)) { g.DrawEllipse(p, 119, 81, 36, 36); g.DrawLine(p, 125, 99, 149, 99); }
            Flow(g, t, new PointF(24, 73), new PointF(68, 57), new PointF(92, 79), new PointF(119, 92), cyan);
            Flow(g, t + 0.45f, new PointF(24, 126), new PointF(67, 141), new PointF(91, 116), new PointF(119, 106), violet);
            Flow(g, t + 0.2f, new PointF(155, 99), new PointF(181, 72), new PointF(211, 73), new PointF(245, 58), cyan);
            Dot(g, 24, 73, 2.3f, cyan, 0.4f); Dot(g, 24, 126, 2.3f, violet, 0.4f); Dot(g, 245, 58, 2.3f, cyan, 0.4f);
            Text(g, "SENSOR FIELD", "Consolas", 6.5f, FontStyle.Bold, C(205, 76, 231, 255), 18, 151);
        } else if (kind == 2) {
            Color violet = C(235, 172, 127, 255), cyan = C(205, 76, 231, 255);
            PointF[] nodes = new PointF[] { new PointF(36, 98), new PointF(82, 64), new PointF(82, 132), new PointF(132, 98), new PointF(182, 64), new PointF(182, 132), new PointF(228, 98) };
            int[,] edges = new int[,] { {0,1},{0,2},{1,3},{2,3},{3,4},{3,5},{4,6},{5,6} };
            using (var p = new Pen(C(95, 127, 88, 152), 1f)) for (int e = 0; e < edges.GetLength(0); e++) g.DrawLine(p, nodes[edges[e,0]], nodes[edges[e,1]]);
            for (int e = 0; e < edges.GetLength(0); e++) {
                PointF a = nodes[edges[e,0]], b = nodes[edges[e,1]];
                float p1 = (t * 0.55f + e * 0.11f) % 1f;
                Dot(g, a.X + (b.X - a.X) * p1, a.Y + (b.Y - a.Y) * p1, 1.5f, e % 2 == 0 ? violet : cyan, 0.25f);
            }
            for (int n = 0; n < nodes.Length; n++) { Dot(g, nodes[n].X, nodes[n].Y, n == 3 ? 3.4f : 2.1f, n == 3 ? cyan : violet, n == 3 ? 0.5f : 0.2f); }
            Text(g, "CAUSAL GRAPH", "Consolas", 6.5f, FontStyle.Bold, C(210, 172, 127, 255), 18, 151);
        } else {
            Color mint = C(235, 183, 241, 106), warm = C(220, 248, 184, 92);
            float ox = 92, oy = 133;
            using (var p = new Pen(C(68, 52, 58, 85), 1f)) { p.DashStyle = DashStyle.Dot; for (int r = 24; r <= 72; r += 24) g.DrawArc(p, ox - r, oy - r, r * 2, r * 2, 195, 150); g.DrawLine(p, ox - 76, oy, ox + 76, oy); }
            float sweep = -72f + (float)Math.Sin(t * Math.PI * 2f) * 72f;
            float sr = (float)((sweep - 90f) * Math.PI / 180f);
            using (var p = new Pen(C(220, 183, 241, 106), 1.4f)) g.DrawLine(p, ox, oy, ox + 73 * (float)Math.Cos(sr), oy + 73 * (float)Math.Sin(sr));
            float[] angles = new float[] {-46f, -18f, 19f, 48f, 68f}; float[] dist = new float[] {48f, 67f, 45f, 62f, 52f};
            for (int i = 0; i < angles.Length; i++) { float ar = (float)((angles[i] - 90f) * Math.PI / 180f); float px = ox + dist[i] * (float)Math.Cos(ar), py = oy + dist[i] * (float)Math.Sin(ar); Dot(g, px, py, Math.Abs(sweep - angles[i]) < 16f ? 2.5f : 1.5f, Math.Abs(sweep - angles[i]) < 16f ? mint : warm, 0.25f); }
            Flow(g, t + 0.3f, new PointF(165, 126), new PointF(190, 115), new PointF(215, 116), new PointF(246, 104), warm);
            Dot(g, 246, 104, 2.2f, warm, 0.35f);
            Text(g, "DEPTH / 30m", "Consolas", 6.5f, FontStyle.Bold, C(215, 183, 241, 106), 18, 151);
        }
    }

    public static Bitmap[] Generate(int kind, int totalFrames = 36) {
        int w = 274, h = 340;
        var frames = new Bitmap[totalFrames];
        Color[] accents = new Color[] { C(255, 76, 231, 255), C(255, 172, 127, 255), C(255, 183, 241, 106) };
        string[] tags = new string[] { "PERCEPTION", "REASONING", "ACTION" };
        string[] subtitles = new string[] { "SENSOR FUSION", "CAUSAL MODEL", "SPATIAL CONTROL" };
        string[] descriptions = new string[] { "Turns camera and depth input into\nstable landmarks.", "Traces cause and effect across\na changing system.", "Maps distance, heading, and\nthe next safe move." };
        string[][] chips = new string[][] { new string[] { "Vision", "WASM", "6-DoF" }, new string[] { "Graph", "Policy", "Trace" }, new string[] { "LiDAR", "Nav", "Control" } };
        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            Color accent = accents[kind - 1];
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                Quality(g);
                using (var bg = new LinearGradientBrush(new Rectangle(0, 0, w, h), C(255, 4, 7, 12), C(255, 7, 10, 18), 90f)) g.FillRectangle(bg, 0, 0, w, h);
                DrawArt(g, kind, t, accent);
                using (var border = new Pen(C(85, accent.R, accent.G, accent.B), 1f)) g.DrawRectangle(border, 2, 2, w - 5, h - 5);
                Brackets(g, 2, 2, w - 4, h - 4, accent);
                using (var p = new Pen(C(185, accent.R, accent.G, accent.B), 2f)) g.DrawLine(p, 2, 2, w - 4, 2);
                Text(g, String.Format("0{0} // {1}", kind, tags[kind - 1]), "Consolas", 7.2f, FontStyle.Bold, accent, 13, 13);
                float pulse = 0.65f + 0.35f * (float)Math.Sin((t + kind * 0.22f) * Math.PI * 2f);
                using (var b = new SolidBrush(C((int)(160 + 95 * pulse), 183, 241, 106))) g.FillEllipse(b, w - 70, 15, 6, 6);
                Text(g, "LIVE", "Consolas", 6.8f, FontStyle.Bold, C(230, 226, 232, 235), w - 57, 12);
                using (var p = new Pen(C(35, 53, 69, 80), 1f)) g.DrawLine(p, 12, 173, w - 12, 173);
                using (var b = new SolidBrush(accent)) g.FillRectangle(b, 12, 184, 3, 16);
                Text(g, tags[kind - 1], "Segoe UI", 12.2f, FontStyle.Bold, C(250, 248, 252, 255), 20, 181);
                Text(g, subtitles[kind - 1], "Consolas", 7.2f, FontStyle.Bold, accent, 13, 207);
                Text(g, descriptions[kind - 1], "Segoe UI", 8.2f, FontStyle.Regular, C(205, 213, 225, 245), 13, 231);
                float px = 13f;
                using (var fChip = new Font("Consolas", 6.7f, FontStyle.Regular)) foreach (var chip in chips[kind - 1]) { var sz = g.MeasureString(chip, fChip); float pw = sz.Width + 10; using (var b = new SolidBrush(C(190, 8, 14, 24))) g.FillRectangle(b, px, 296, pw, 20); using (var p = new Pen(C(80, 100, 116, 139), 1f)) g.DrawRectangle(p, px, 296, pw, 20); using (var bt = new SolidBrush(C(230, 242, 254, 240))) g.DrawString(chip, fChip, bt, px + 5, 300); px += pw + 5; }
                Text(g, "VIEW ->", "Consolas", 7.8f, FontStyle.Bold, accent, w - 61, 300);
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
                g.Clear(C(255, 3, 6, 11));
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
$perception = [TelemetryCards]::Generate(1, 36)
$reasoning = [TelemetryCards]::Generate(2, 36)
$action = [TelemetryCards]::Generate(3, 36)

[TelemetryCards]::SaveGif("$assetsDir\telemetry_perception.gif", $perception, 40)
[TelemetryCards]::SaveGif("$assetsDir\telemetry_reasoning.gif", $reasoning, 40)
[TelemetryCards]::SaveGif("$assetsDir\telemetry_action.gif", $action, 40)
$perception[0].Save("$assetsDir\telemetry_perception.png", [System.Drawing.Imaging.ImageFormat]::Png)
$reasoning[0].Save("$assetsDir\telemetry_reasoning.png", [System.Drawing.Imaging.ImageFormat]::Png)
$action[0].Save("$assetsDir\telemetry_action.png", [System.Drawing.Imaging.ImageFormat]::Png)

[TelemetryCards]::SaveRow("$assetsDir\telemetry_cards.gif", @($perception, $reasoning, $action), 40)
Copy-Item "$assetsDir\telemetry_cards.gif" "$assetsDir\telemetry.gif" -Force
Copy-Item "$assetsDir\telemetry_cards.png" "$assetsDir\telemetry.png" -Force

foreach ($frameSet in @($perception, $reasoning, $action)) { foreach ($frame in $frameSet) { $frame.Dispose() } }
Write-Host "Telemetry cards rendered: perception, reasoning, action."
Get-ChildItem "$assetsDir\telemetry*.gif", "$assetsDir\telemetry*.png" | Select-Object Name, Length
