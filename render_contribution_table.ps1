$ErrorActionPreference = "Stop"
$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class ContributionTable {
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
        using (var f = new Font(family, size, style)) using (var b = new SolidBrush(color)) g.DrawString(value, f, b, x, y);
    }

    static void Rounded(Graphics g, int x, int y, int w, int h, int r, Color fill, Color stroke) {
        using (var path = new GraphicsPath()) {
            path.AddArc(x, y, r, r, 180, 90);
            path.AddArc(x + w - r, y, r, r, 270, 90);
            path.AddArc(x + w - r, y + h - r, r, r, 0, 90);
            path.AddArc(x, y + h - r, r, r, 90, 90);
            path.CloseFigure();
            using (var b = new SolidBrush(fill)) g.FillPath(b, path);
            using (var p = new Pen(stroke, 1f)) g.DrawPath(p, path);
        }
    }

    static Color Mix(Color a, Color b, float amount) {
        amount = Math.Max(0f, Math.Min(1f, amount));
        return C(255, (int)(a.R + (b.R - a.R) * amount), (int)(a.G + (b.G - a.G) * amount), (int)(a.B + (b.B - a.B) * amount));
    }

    public static void Render(string outputPath, string matrixFile, int totalFrames = 48) {
        int w = 840, h = 220, weeks = 53, days = 7;
        int[,] grid = new int[weeks, days];
        if (File.Exists(matrixFile)) {
            string[] cols = File.ReadAllText(matrixFile).Split(';');
            for (int x = 0; x < Math.Min(weeks, cols.Length); x++) {
                string[] vals = cols[x].Split(',');
                for (int y = 0; y < Math.Min(days, vals.Length); y++) { int n; if (int.TryParse(vals[y], out n)) grid[x, y] = Math.Max(0, Math.Min(4, n)); }
            }
        }
        Color cyan = C(255, 76, 231, 255);
        Color violet = C(255, 172, 127, 255);
        Color lime = C(255, 183, 241, 106);
        Color ink = C(245, 242, 250, 255);
        Color muted = C(185, 196, 210, 220);
        Color[] cells = new Color[] { C(190, 8, 14, 24), C(220, 18, 39, 61), C(235, 31, 83, 104), C(240, 76, 163, 160), C(245, 183, 241, 106) };
        var frames = new Bitmap[totalFrames];
        int startX = 145, startY = 55, tile = 9, gap = 3, step = tile + gap;
        int[] weeksTotals = new int[weeks];
        int activeWeeks = 0;
        for (int x = 0; x < weeks; x++) {
            for (int y = 0; y < days; y++) weeksTotals[x] += grid[x, y];
            if (weeksTotals[x] > 0) activeWeeks++;
        }

        for (int f = 0; f < totalFrames; f++) {
            float t = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                Quality(g);
                using (var bg = new LinearGradientBrush(new Rectangle(0, 0, w, h), C(255, 3, 6, 11), C(255, 7, 11, 19), 90f)) g.FillRectangle(bg, 0, 0, w, h);
                using (var border = new Pen(C(80, 42, 61, 82), 1f)) g.DrawRectangle(border, 1, 1, w - 3, h - 3);
                using (var p = new Pen(C(180, cyan.R, cyan.G, cyan.B), 2f)) g.DrawLine(p, 3, 3, 37, 3);
                using (var p = new Pen(C(180, violet.R, violet.G, violet.B), 2f)) g.DrawLine(p, 39, 3, 73, 3);
                using (var p = new Pen(C(180, lime.R, lime.G, lime.B), 2f)) g.DrawLine(p, 75, 3, 109, 3);
                using (var b = new SolidBrush(C(150, 4, 9, 18))) g.FillRectangle(b, 140, 37, 646, 111);
                using (var p = new Pen(C(55, 40, 57, 78), 1f)) g.DrawRectangle(p, 140, 37, 646, 111);
                using (var b = new SolidBrush(C(110, 4, 9, 17))) g.FillRectangle(b, 140, 153, 646, 49);
                using (var p = new Pen(C(48, 40, 57, 70), 1f)) g.DrawRectangle(p, 140, 153, 646, 49);
                Text(g, "03 // CONTRIBUTIONS", "Consolas", 7.2f, FontStyle.Bold, cyan, 14, 12);
                using (var b = new SolidBrush(C(210, lime.R, lime.G, lime.B))) g.FillEllipse(b, 760, 15, 6, 6);
                Text(g, "YEAR VIEW", "Consolas", 6.8f, FontStyle.Bold, muted, 773, 12);
                Text(g, "264", "Segoe UI", 26f, FontStyle.Bold, ink, 14, 43);
                Text(g, "CONTRIBUTIONS", "Consolas", 6.5f, FontStyle.Bold, muted, 16, 88);
                Text(g, activeWeeks.ToString().PadLeft(2, '0') + " ACTIVE WEEKS", "Consolas", 6.5f, FontStyle.Bold, lime, 16, 108);
                using (var p = new Pen(C(80, 53, 69, 88), 1f)) g.DrawLine(p, 16, 124, 112, 124);
                Text(g, "LAST 12 MONTHS", "Consolas", 6.2f, FontStyle.Regular, muted, 16, 137);
                using (var p = new Pen(C(85, 40, 53, 75), 1f)) g.DrawLine(p, 124, 42, 124, 147);

                string[] months = new string[] { "Sep", "Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug" };
                for (int m = 0; m < months.Length; m++) { int mx = startX + (int)(m * (weeks / 12.0f) * step); Text(g, months[m], "Consolas", 6.6f, FontStyle.Regular, muted, mx, 42); }
                Text(g, "M", "Consolas", 6.2f, FontStyle.Regular, muted, 131, startY + 7);
                Text(g, "W", "Consolas", 6.2f, FontStyle.Regular, muted, 131, startY + 31);
                Text(g, "F", "Consolas", 6.2f, FontStyle.Regular, muted, 131, startY + 55);

                int chartX = startX;
                float sweep = 0.5f + 0.5f * (float)Math.Sin((t - 0.25f) * Math.PI * 2f);
                float focusWeek = 0.75f + (weeks - 1.5f) * sweep;
                float markerX = chartX + focusWeek * step;
                using (var p = new Pen(C(75, cyan.R, cyan.G, cyan.B), 1f)) g.DrawLine(p, markerX, 44, markerX, 146);
                for (int x = 0; x < weeks; x++) for (int y = 0; y < days; y++) {
                    int tx = startX + x * step, ty = startY + y * step;
                    Color fill = cells[grid[x, y]];
                    float distance = Math.Abs(x - focusWeek);
                    if (distance < 1.2f && grid[x, y] > 0) fill = Mix(fill, C(255, 226, 240, 255), (1.2f - distance) / 1.2f * 0.18f);
                    using (var b = new SolidBrush(fill)) g.FillRectangle(b, tx, ty, tile, tile);
                    using (var p = new Pen(C(55, 46, 65, 89), 1f)) g.DrawRectangle(p, tx, ty, tile, tile);
                    if (distance < 1.75f) { int alpha = (int)(55f + 100f * (1.75f - distance) / 1.75f); using (var p = new Pen(C(alpha, cyan.R, cyan.G, cyan.B), 1f)) g.DrawRectangle(p, tx - 1, ty - 1, tile + 2, tile + 2); }
                }

                int chartY = 174, chartW = weeks * step - gap, chartH = 22;
                Text(g, "WEEKLY ACTIVITY", "Consolas", 6.2f, FontStyle.Bold, muted, chartX, 158);
                using (var p = new Pen(C(55, 53, 73, 95), 1f)) g.DrawLine(p, chartX, chartY + chartH, chartX + chartW, chartY + chartH);
                PointF[] curve = new PointF[weeks];
                int max = 1; for (int x = 0; x < weeks; x++) if (weeksTotals[x] > max) max = weeksTotals[x];
                for (int x = 0; x < weeks; x++) { float xx = chartX + x * step; float yy = chartY + chartH - ((float)weeksTotals[x] / max) * chartH; curve[x] = new PointF(xx, yy); }
                using (var p = new Pen(C(180, violet.R, violet.G, violet.B), 1.15f)) g.DrawCurve(p, curve, 0.35f);
                using (var p = new Pen(C(190, cyan.R, cyan.G, cyan.B), 1f)) g.DrawLine(p, markerX, chartY - 1, markerX, chartY + chartH + 1);
                int markerIndex = Math.Max(0, Math.Min(weeks - 1, (int)Math.Round(focusWeek)));
                float markerY = curve[markerIndex].Y;
                using (var b = new SolidBrush(C(40, cyan.R, cyan.G, cyan.B))) g.FillEllipse(b, markerX - 4, markerY - 4, 8, 8);
                using (var b = new SolidBrush(C(235, cyan.R, cyan.G, cyan.B))) g.FillEllipse(b, markerX - 2, markerY - 2, 4, 4);
                Text(g, "LESS", "Consolas", 6.2f, FontStyle.Regular, muted, 674, 158);
                for (int i = 0; i < 5; i++) { using (var b = new SolidBrush(cells[i])) g.FillRectangle(b, 702 + i * 12, 157, tile, tile); using (var p = new Pen(C(55, 46, 65, 89), 1f)) g.DrawRectangle(p, 702 + i * 12, 157, tile, tile); }
                Text(g, "MORE", "Consolas", 6.2f, FontStyle.Regular, muted, 774, 158);
            }
            frames[f] = bmp;
        }
        SaveGif(outputPath, frames, 55);
        frames[0].Save(outputPath.Replace(".gif", ".png"), ImageFormat.Png);
        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing"
$assetsDir = "E:\Projects\Readme\assets"
[ContributionTable]::Render("$assetsDir\contrib.gif", "E:\Projects\Readme\real_contrib_matrix.txt", 48)
Write-Host "Contribution table rendered from real_contrib_matrix.txt"
$img = [System.Drawing.Image]::FromFile("$assetsDir\contrib.gif")
try { Write-Host ("{0}x{1}, {2} frames" -f $img.Width, $img.Height, $img.GetFrameCount([System.Drawing.Imaging.FrameDimension]::Time)) } finally { $img.Dispose() }
