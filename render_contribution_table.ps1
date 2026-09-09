$ErrorActionPreference = "Stop"

$source = @"
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Drawing.Imaging;

public class ContributionTable {
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
        g.SmoothingMode = SmoothingMode.HighQuality;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
    }

    public static Color Mix(Color a, Color b, float amount) {
        amount = Math.Max(0f, Math.Min(1f, amount));
        return Color.FromArgb(
            255,
            (int)(a.R + (b.R - a.R) * amount),
            (int)(a.G + (b.G - a.G) * amount),
            (int)(a.B + (b.B - a.B) * amount)
        );
    }

    public static void RenderFrame(Graphics g, int w, int h, int[,] grid, int[] weeksTotals, int activeWeeks, float progress) {
        SetHighQuality(g);

        Color cyan = Color.FromArgb(0, 240, 255);
        Color emerald = Color.FromArgb(52, 211, 153);
        Color purple = Color.FromArgb(168, 85, 247);
        Color textWhite = Color.FromArgb(248, 250, 252);
        Color textMuted = Color.FromArgb(148, 163, 184);
        Color textDim = Color.FromArgb(90, 105, 125);

        // Modern Cyber Palette for Cells
        Color[] cellColors = new Color[] {
            Color.FromArgb(14, 20, 32),   // 0: empty
            Color.FromArgb(16, 68, 80),   // 1: low
            Color.FromArgb(18, 130, 140), // 2: med
            Color.FromArgb(0, 210, 225),  // 3: high
            Color.FromArgb(52, 211, 153)  // 4: peak emerald
        };

        // 1. Deep atmospheric background
        using (var bgBrush = new LinearGradientBrush(
            new RectangleF(0, 0, w, h),
            Color.FromArgb(9, 13, 22), Color.FromArgb(5, 7, 13), 90f)) {
            g.FillRectangle(bgBrush, 0, 0, w, h);
        }

        // Faint ambient glow behind left stats panel
        using (var glowPather = new GraphicsPath()) {
            glowPather.AddEllipse(-40, -40, 300, 200);
            using (var pgb = new PathGradientBrush(glowPather)) {
                pgb.CenterColor = Color.FromArgb(22, cyan.R, cyan.G, cyan.B);
                pgb.SurroundColors = new Color[] { Color.Transparent };
                g.FillPath(pgb, glowPather);
            }
        }

        // Outer sleek container border
        using (var penBorder = new Pen(Color.FromArgb(28, 38, 54), 1f)) {
            g.DrawRectangle(penBorder, 0, 0, w - 1, h - 1);
        }

        // Corner framing micro-accents
        using (var penCorner = new Pen(Color.FromArgb(90, cyan.R, cyan.G, cyan.B), 1.2f)) {
            g.DrawLine(penCorner, 0, 0, 8, 0);
            g.DrawLine(penCorner, 0, 0, 0, 8);
            g.DrawLine(penCorner, w - 1, 0, w - 9, 0);
            g.DrawLine(penCorner, w - 1, 0, w - 1, 8);
            g.DrawLine(penCorner, 0, h - 1, 8, h - 1);
            g.DrawLine(penCorner, 0, h - 1, 0, h - 9);
            g.DrawLine(penCorner, w - 1, h - 1, w - 9, h - 1);
            g.DrawLine(penCorner, w - 1, h - 1, w - 1, h - 9);
        }

        // Top traveling laser beam with radiant spark flare
        float beamX = progress * (w + 160) - 80;
        using (var beamBrush = new LinearGradientBrush(
            new RectangleF(beamX - 80, 0, 160, 2),
            Color.Transparent, Color.Transparent, 0f)) {
            var cb = new ColorBlend(3);
            cb.Colors = new Color[] { Color.Transparent, cyan, Color.Transparent };
            cb.Positions = new float[] { 0f, 0.5f, 1f };
            beamBrush.InterpolationColors = cb;
            g.FillRectangle(beamBrush, beamX - 80, 0, 160, 2);
        }
        using (var brushSpark = new SolidBrush(Color.FromArgb(240, 255, 255, 255))) {
            g.FillRectangle(brushSpark, beamX - 4, 0, 8, 2);
        }

        using (var fontBig = new Font("Segoe UI", 26f, FontStyle.Bold))
        using (var fontLabel = new Font("Consolas", 7.8f, FontStyle.Bold))
        using (var fontSmall = new Font("Consolas", 6.8f, FontStyle.Regular))
        using (var fontMono = new Font("Consolas", 7.2f, FontStyle.Regular)) {

            // ================= LEFT TELEMETRY METRICS PANEL (Width: ~140px) =================
            int leftPanelW = 142;

            // Live stream header tag
            using (var bTagBg = new SolidBrush(Color.FromArgb(16, 24, 38)))
            using (var pTag = new Pen(Color.FromArgb(60, cyan.R, cyan.G, cyan.B), 1f)) {
                g.FillRectangle(bTagBg, 16, 14, 110, 18);
                g.DrawRectangle(pTag, 16, 14, 110, 18);
            }
            float dotPulse = (float)(0.65f + 0.35f * Math.Sin(progress * Math.PI * 2));
            int dotA = (int)(255 * dotPulse);
            using (var bDotGlow = new SolidBrush(Color.FromArgb((int)(dotA * 0.4f), cyan.R, cyan.G, cyan.B)))
            using (var bDot = new SolidBrush(Color.FromArgb(dotA, cyan.R, cyan.G, cyan.B))) {
                g.FillEllipse(bDotGlow, 21, 18, 10, 10);
                g.FillEllipse(bDot, 23, 20, 6, 6);
            }
            using (var bTagText = new SolidBrush(Color.FromArgb(220, 235, 248))) {
                g.DrawString("LIVE TELEMETRY", fontSmall, bTagText, 34, 17);
            }

            // Big 264 Metric
            float numY = 40;
            using (var bNumGlow = new SolidBrush(Color.FromArgb(70, cyan.R, cyan.G, cyan.B)))
            using (var bNum = new SolidBrush(textWhite)) {
                g.DrawString("264", fontBig, bNumGlow, 15.5f, numY + 0.5f);
                g.DrawString("264", fontBig, bNum, 14, numY);
            }

            // Sub-labels
            using (var bLabel = new SolidBrush(cyan)) {
                g.DrawString("CONTRIBUTIONS", fontLabel, bLabel, 16, 88);
            }
            using (var bActive = new SolidBrush(emerald)) {
                g.DrawString(activeWeeks + " ACTIVE WEEKS", fontLabel, bActive, 16, 104);
            }

            // Divider line
            using (var pDiv = new Pen(Color.FromArgb(30, 42, 60), 1f)) {
                g.DrawLine(pDiv, 16, 122, 126, 122);
            }

            // Bottom telemetry specs
            using (var bSpec = new SolidBrush(textMuted)) {
                g.DrawString("PERIOD // 365 DAYS", fontSmall, bSpec, 16, 130);
                g.DrawString("AUDIT  // VERIFIED", fontSmall, bSpec, 16, 144);
                g.DrawString("PEAK   // 4 COMMITS/D", fontSmall, bSpec, 16, 158);
                g.DrawString("RATE   // 100% SYNC", fontSmall, bSpec, 16, 172);
            }

            // Vertical separator between panel and matrix
            using (var pVert = new Pen(Color.FromArgb(24, 34, 50), 1f)) {
                g.DrawLine(pVert, leftPanelW, 14, leftPanelW, h - 14);
            }
            using (var pVertAccent = new Pen(Color.FromArgb(80, cyan.R, cyan.G, cyan.B), 1.5f)) {
                g.DrawLine(pVertAccent, leftPanelW, 14, leftPanelW, 26);
                g.DrawLine(pVertAccent, leftPanelW, h - 26, leftPanelW, h - 14);
            }

            // ================= RIGHT HEATMAP MATRIX PANEL =================
            int startX = 172;
            int startY = 38;
            int tile = 9;
            int gap = 3;
            int step = tile + gap;
            int weeks = 53;
            int days = 7;

            // Header Row: Months
            string[] months = new string[] { "Sep", "Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug" };
            using (var bMonth = new SolidBrush(textMuted)) {
                for (int m = 0; m < months.Length; m++) {
                    int mx = startX + (int)(m * (weeks / 12.0f) * step);
                    g.DrawString(months[m], fontMono, bMonth, mx, 20);
                }
            }

            // Left Day Labels (M, W, F)
            using (var bDay = new SolidBrush(textDim)) {
                g.DrawString("M", fontSmall, bDay, startX - 16, startY + 8);
                g.DrawString("W", fontSmall, bDay, startX - 16, startY + 32);
                g.DrawString("F", fontSmall, bDay, startX - 16, startY + 56);
            }

            // Radar laser sweep calculation
            float sweep = 0.5f + 0.5f * (float)Math.Sin((progress - 0.25f) * Math.PI * 2f);
            float focusWeek = 0.75f + (weeks - 1.5f) * sweep;
            float markerX = startX + focusWeek * step + (tile / 2f);

            // Subtle vertical radar beam line over the heatmap
            using (var pSweep = new Pen(Color.FromArgb(90, cyan.R, cyan.G, cyan.B), 1f)) {
                g.DrawLine(pSweep, markerX, startY - 2, markerX, startY + (days * step));
            }

            // Draw Cells
            for (int x = 0; x < weeks; x++) {
                for (int y = 0; y < days; y++) {
                    int tx = startX + x * step;
                    int ty = startY + y * step;
                    int val = grid[x, y];
                    Color fill = cellColors[val];

                    // Active sweep highlight
                    float dist = Math.Abs(x - focusWeek);
                    if (dist < 1.2f && val > 0) {
                        fill = Mix(fill, Color.FromArgb(240, 255, 255), (1.2f - dist) / 1.2f * 0.28f);
                    }

                    using (var bCell = new SolidBrush(fill)) {
                        g.FillRectangle(bCell, tx, ty, tile, tile);
                    }
                    using (var pCell = new Pen(Color.FromArgb(30, 42, 60), 1f)) {
                        g.DrawRectangle(pCell, tx, ty, tile, tile);
                    }

                    // Neon halo on laser contact
                    if (dist < 1.6f && val > 0) {
                        int alpha = (int)(70f + 120f * (1.6f - dist) / 1.6f);
                        using (var pGlow = new Pen(Color.FromArgb(alpha, cyan.R, cyan.G, cyan.B), 1f)) {
                            g.DrawRectangle(pGlow, tx - 1, ty - 1, tile + 2, tile + 2);
                        }
                    }
                }
            }

            // ================= BOTTOM WEEKLY ACTIVITY WAVEFORM =================
            int chartX = startX;
            int chartY = startY + (days * step) + 22;
            int chartW = weeks * step - gap;
            int chartH = 24;

            // Waveform container background
            using (var bChartBg = new SolidBrush(Color.FromArgb(12, 16, 26)))
            using (var pChartBorder = new Pen(Color.FromArgb(24, 34, 50), 1f)) {
                g.FillRectangle(bChartBg, chartX - 4, chartY - 14, chartW + 8, chartH + 20);
                g.DrawRectangle(pChartBorder, chartX - 4, chartY - 14, chartW + 8, chartH + 20);
            }

            // Title above waveform
            using (var bWaveTitle = new SolidBrush(textMuted)) {
                g.DrawString("WEEKLY COMMIT VELOCITY", fontLabel, bWaveTitle, chartX, chartY - 11);
            }

            // Legend on right
            int legX = chartX + chartW - 136;
            using (var bLegText = new SolidBrush(textDim)) {
                g.DrawString("LESS", fontSmall, bLegText, legX, chartY - 10);
            }
            for (int i = 0; i < 5; i++) {
                int lx = legX + 30 + i * 14;
                using (var bL = new SolidBrush(cellColors[i])) {
                    g.FillRectangle(bL, lx, chartY - 11, tile, tile);
                }
                using (var pL = new Pen(Color.FromArgb(40, 54, 76), 1f)) {
                    g.DrawRectangle(pL, lx, chartY - 11, tile, tile);
                }
            }
            using (var bLegText = new SolidBrush(textDim)) {
                g.DrawString("MORE", fontSmall, bLegText, legX + 104, chartY - 10);
            }

            // Baseline
            using (var pBase = new Pen(Color.FromArgb(32, 44, 64), 1f)) {
                g.DrawLine(pBase, chartX, chartY + chartH, chartX + chartW, chartY + chartH);
            }

            // Build Waveform Curve
            PointF[] curve = new PointF[weeks];
            int maxVal = 1;
            for (int x = 0; x < weeks; x++) {
                if (weeksTotals[x] > maxVal) maxVal = weeksTotals[x];
            }
            for (int x = 0; x < weeks; x++) {
                float xx = chartX + x * step + (tile / 2f);
                float yy = chartY + chartH - ((float)weeksTotals[x] / maxVal) * chartH;
                curve[x] = new PointF(xx, yy);
            }

            // Draw Area Gradient under curve
            using (var pathArea = new GraphicsPath()) {
                pathArea.AddLine(chartX, chartY + chartH, curve[0].X, curve[0].Y);
                pathArea.AddCurve(curve, 0.35f);
                pathArea.AddLine(curve[weeks - 1].X, chartY + chartH, chartX, chartY + chartH);
                using (var brushArea = new LinearGradientBrush(
                    new RectangleF(chartX, chartY, chartW, chartH),
                    Color.FromArgb(40, purple.R, purple.G, purple.B),
                    Color.Transparent, 90f)) {
                    g.FillPath(brushArea, pathArea);
                }
            }

            // Draw Waveform Stroke
            using (var pCurve = new Pen(Color.FromArgb(200, purple.R, purple.G, purple.B), 1.5f)) {
                g.DrawCurve(pCurve, curve, 0.35f);
            }

            // Vertical radar tracker on waveform
            using (var pMarker = new Pen(Color.FromArgb(180, cyan.R, cyan.G, cyan.B), 1f)) {
                g.DrawLine(pMarker, markerX, chartY - 3, markerX, chartY + chartH + 3);
            }

            // Glowing pip on curve
            int mIdx = Math.Max(0, Math.Min(weeks - 1, (int)Math.Round(focusWeek)));
            float markerY = curve[mIdx].Y;
            using (var bPipGlow = new SolidBrush(Color.FromArgb(80, cyan.R, cyan.G, cyan.B)))
            using (var bPip = new SolidBrush(cyan))
            using (var bPipCore = new SolidBrush(Color.White)) {
                g.FillEllipse(bPipGlow, markerX - 6, markerY - 6, 12, 12);
                g.FillEllipse(bPip, markerX - 3.5f, markerY - 3.5f, 7, 7);
                g.FillEllipse(bPipCore, markerX - 1.5f, markerY - 1.5f, 3, 3);
            }
        }
    }

    public static void Render(string outputPath, string matrixFile, int totalFrames = 32, int delayMs = 50) {
        int w = 840, h = 220;
        int weeks = 53, days = 7;
        int[,] grid = new int[weeks, days];
        int[] weeksTotals = new int[weeks];
        int activeWeeks = 0;

        if (File.Exists(matrixFile)) {
            string[] cols = File.ReadAllText(matrixFile).Trim().Split(';');
            for (int x = 0; x < Math.Min(weeks, cols.Length); x++) {
                string[] vals = cols[x].Split(',');
                for (int y = 0; y < Math.Min(days, vals.Length); y++) {
                    int n;
                    if (int.TryParse(vals[y], out n)) {
                        grid[x, y] = Math.Max(0, Math.Min(4, n));
                    }
                }
            }
        }

        for (int x = 0; x < weeks; x++) {
            for (int y = 0; y < days; y++) weeksTotals[x] += grid[x, y];
            if (weeksTotals[x] > 0) activeWeeks++;
        }

        var frames = new Bitmap[totalFrames];
        for (int f = 0; f < totalFrames; f++) {
            float progress = (float)f / totalFrames;
            var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(bmp)) {
                RenderFrame(g, w, h, grid, weeksTotals, activeWeeks, progress);
            }
            frames[f] = bmp;
        }

        SaveGif(outputPath, frames, delayMs);
        frames[0].Save(outputPath.Replace(".gif", ".png"), ImageFormat.Png);
        frames[0].Save(outputPath.Replace(".gif", "_frame.png"), ImageFormat.Png);

        for (int i = 0; i < totalFrames; i++) frames[i].Dispose();
        Console.WriteLine("Rendered Telemetry Table to: " + outputPath);
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies "System.Drawing"

$assetsDir = "E:\Projects\Readme\assets"
$matrixFile = "E:\Projects\Readme\real_contrib_matrix.txt"
$contribGif = "$assetsDir\contrib.gif"
$contribV2Gif = "$assetsDir\contrib_v2.gif"

Write-Host "Rendering state-of-the-art Live Telemetry Table (contrib.gif)..."
[ContributionTable]::Render($contribV2Gif, $matrixFile, 32, 50)
Copy-Item $contribV2Gif $contribGif -Force

Write-Host "Telemetry table rendered successfully!"
Get-ChildItem "$assetsDir\contrib*.gif" | Select-Object Name, Length
