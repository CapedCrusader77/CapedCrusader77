Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$source = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;

public static class ProfileMotionRenderer
{
    private static readonly Color Paper = Color.FromArgb(239, 236, 226);
    private static readonly Color Ink = Color.FromArgb(37, 42, 37);
    private static readonly Color Muted = Color.FromArgb(119, 119, 106);
    private static readonly Color Rule = Color.FromArgb(204, 198, 182);
    private static readonly Color Oxide = Color.FromArgb(177, 72, 51);
    private static readonly Color Moss = Color.FromArgb(96, 113, 84);
    private static readonly Color LightMoss = Color.FromArgb(215, 220, 204);

    private static Pen P(Color color, float width = 1f)
    {
        var pen = new Pen(color, width);
        pen.StartCap = LineCap.Round;
        pen.EndCap = LineCap.Round;
        pen.LineJoin = LineJoin.Round;
        return pen;
    }

    private static SolidBrush B(Color color) { return new SolidBrush(color); }

    private static Font F(string family, float size, FontStyle style = FontStyle.Regular)
    {
        return new Font(family, size, style, GraphicsUnit.Pixel);
    }

    private static void Setup(Graphics g)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
    }

    private static void Text(Graphics g, string text, string family, float size, Color color,
                             float x, float y, FontStyle style = FontStyle.Regular)
    {
        using (var font = F(family, size, style))
        using (var brush = B(color))
            g.DrawString(text, font, brush, x, y);
    }

    private static void CenterText(Graphics g, string text, string family, float size, Color color,
                                   float centerX, float y, FontStyle style = FontStyle.Regular)
    {
        using (var font = F(family, size, style))
        using (var brush = B(color))
        using (var format = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Near })
            g.DrawString(text, font, brush, new RectangleF(centerX - 90, y, 180, size + 8), format);
    }

    private static void Line(Graphics g, Color color, float width, PointF a, PointF b)
    {
        using (var pen = P(color, width)) g.DrawLine(pen, a, b);
    }

    private static void Circle(Graphics g, float cx, float cy, float radius, Color color, float width = 1f)
    {
        using (var pen = P(color, width))
            g.DrawEllipse(pen, cx - radius, cy - radius, radius * 2, radius * 2);
    }

    private static void Dot(Graphics g, float cx, float cy, float radius, Color color)
    {
        using (var brush = B(color))
            g.FillEllipse(brush, cx - radius, cy - radius, radius * 2, radius * 2);
    }

    private static void RoundedRect(Graphics g, Color color, float width, RectangleF rect, float radius)
    {
        using (var path = new GraphicsPath())
        using (var pen = P(color, width))
        {
            float d = radius * 2;
            path.AddArc(rect.X, rect.Y, d, d, 180, 90);
            path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
            path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
            path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            g.DrawPath(pen, path);
        }
    }

    private static Bitmap Canvas(int width, int height, out Graphics graphics)
    {
        var bitmap = new Bitmap(width, height, PixelFormat.Format24bppRgb);
        graphics = Graphics.FromImage(bitmap);
        Setup(graphics);
        graphics.Clear(Paper);
        return bitmap;
    }

    private static PropertyItem DelayProperty(Image template, int frameCount, int delayCentiseconds)
    {
        var item = template.GetPropertyItem(0x5100);
        item.Id = 0x5100;
        item.Type = 4;
        item.Len = frameCount * 4;
        item.Value = new byte[item.Len];
        for (int i = 0; i < frameCount; i++)
            Array.Copy(BitConverter.GetBytes(delayCentiseconds), 0, item.Value, i * 4, 4);
        return item;
    }

    private static void SaveGif(Bitmap[] frames, string output, Image template, int delayCentiseconds)
    {
        ImageCodecInfo codec = null;
        foreach (var candidate in ImageCodecInfo.GetImageEncoders())
            if (candidate.MimeType == "image/gif") { codec = candidate; break; }

        var first = frames[0];
        first.SetPropertyItem(DelayProperty(template, frames.Length, delayCentiseconds));
        using (var parameters = new EncoderParameters(1))
        {
            parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.MultiFrame);
            first.Save(output, codec, parameters);
            parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.FrameDimensionTime);
            for (int i = 1; i < frames.Length; i++)
                first.SaveAdd(frames[i], parameters);
            parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.Flush);
            first.SaveAdd(parameters);
        }
        foreach (var frame in frames) frame.Dispose();
        AddInfiniteLoopExtension(output);
    }

    private static void AddInfiniteLoopExtension(string path)
    {
        var bytes = System.IO.File.ReadAllBytes(path);
        string marker = System.Text.Encoding.ASCII.GetString(bytes);
        if (marker.Contains("NETSCAPE2.0")) return;

        int packed = bytes[10];
        int colorTableBytes = (packed & 0x80) != 0 ? 3 * (1 << ((packed & 0x07) + 1)) : 0;
        int insertAt = 13 + colorTableBytes;
        byte[] extension = {
            0x21, 0xFF, 0x0B, 0x4E, 0x45, 0x54, 0x53, 0x43, 0x41, 0x50, 0x45, 0x32, 0x2E, 0x30,
            0x03, 0x01, 0x00, 0x00, 0x00
        };

        var looped = new byte[bytes.Length + extension.Length];
        Array.Copy(bytes, 0, looped, 0, insertAt);
        Array.Copy(extension, 0, looped, insertAt, extension.Length);
        Array.Copy(bytes, insertAt, looped, insertAt + extension.Length, bytes.Length - insertAt);
        System.IO.File.WriteAllBytes(path, looped);
    }

    private static PointF Along(PointF a, PointF b, float t)
    {
        return new PointF(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t);
    }

    private static Bitmap DrawCover(int frame, int frameCount)
    {
        Graphics g;
        var bitmap = Canvas(900, 346, out g);
        using (g)
        {
            g.ScaleTransform(0.8035714f, 0.8035714f);
            using (var block = B(Oxide)) g.FillRectangle(block, 575, 0, 545, 430);
            using (var brush = B(Oxide)) g.FillRectangle(brush, 72, 66, 7, 64);
            Text(g, "GOKUL A", "Georgia", 25, Muted, 96, 66, FontStyle.Bold);
            Text(g, "Systems that make", "Georgia", 46, Ink, 70, 143, FontStyle.Bold);
            Text(g, "signals useful.", "Georgia", 46, Ink, 70, 197, FontStyle.Bold);
            Text(g, "COMPUTER VISION   ·   AI SYSTEMS   ·   ENGINEERING TOOLS",
                 "Segoe UI", 15, Muted, 76, 286, FontStyle.Bold);
            using (var pen = P(Rule, 1.3f)) g.DrawLine(pen, 76, 338, 500, 338);
            Text(g, "From raw input to a decision you can inspect.", "Segoe UI", 17, Ink, 76, 355);

            using (var pen = P(Paper, 1.2f)) g.DrawLine(pen, 575, 54, 575, 377);

            // A three-stage signal path, drawn as a working diagram rather than a status panel.
            PointF[] nodes = { new PointF(682, 202), new PointF(848, 116), new PointF(1014, 202) };
            Line(g, Paper, 2, nodes[0], nodes[1]);
            Line(g, Paper, 2, nodes[1], nodes[2]);
            Line(g, Paper, 1, new PointF(682, 202), new PointF(682, 300));
            Line(g, Paper, 1, new PointF(848, 116), new PointF(848, 300));
            Line(g, Paper, 1, new PointF(1014, 202), new PointF(1014, 300));

            // Sensor frame.
            RoundedRect(g, Paper, 2, new RectangleF(647, 167, 70, 70), 8);
            Circle(g, nodes[0].X, nodes[0].Y, 15, Paper, 2);
            Dot(g, nodes[0].X, nodes[0].Y, 3, Paper);

            // A small causal graph.
            Circle(g, nodes[1].X, nodes[1].Y, 30, Paper, 1.5f);
            Circle(g, nodes[1].X, nodes[1].Y, 8, Paper, 2);
            Line(g, Paper, 1.3f, new PointF(828, 98), new PointF(813, 78));
            Line(g, Paper, 1.3f, new PointF(868, 99), new PointF(886, 79));
            Line(g, Paper, 1.3f, new PointF(827, 135), new PointF(810, 153));
            Line(g, Paper, 1.3f, new PointF(869, 135), new PointF(887, 153));
            Dot(g, 813, 78, 4, Paper); Dot(g, 886, 79, 4, LightMoss);
            Dot(g, 810, 153, 4, LightMoss); Dot(g, 887, 153, 4, Paper);

            // A control vector.
            using (var pen = P(Ink, 2.2f))
            {
                g.DrawLines(pen, new[] { new PointF(986, 219), new PointF(1001, 183), new PointF(1020, 190), new PointF(1037, 150) });
                g.DrawLine(pen, 1037, 150, 1028, 156);
                g.DrawLine(pen, 1037, 150, 1036, 161);
            }
            Circle(g, 1014, 202, 8, Paper, 2);

            CenterText(g, "SENSE", "Consolas", 14, Paper, nodes[0].X, 319, FontStyle.Bold);
            CenterText(g, "REASON", "Consolas", 14, Paper, nodes[1].X, 319, FontStyle.Bold);
            CenterText(g, "RESPOND", "Consolas", 14, Paper, nodes[2].X, 319, FontStyle.Bold);

            float progress = (float)frame / frameCount;
            float eased = 0.5f - 0.5f * (float)Math.Cos(progress * Math.PI * 2);
            PointF marker;
            if (eased < 0.5f) marker = Along(nodes[0], nodes[1], eased * 2f);
            else marker = Along(nodes[1], nodes[2], (eased - 0.5f) * 2f);
            Dot(g, marker.X, marker.Y, 6.5f, Paper);
            Circle(g, marker.X, marker.Y, 12, Paper, 1.2f);

            // Fine registration marks give the composition a printed, measured edge.
            Line(g, Paper, 1, new PointF(600, 56), new PointF(622, 56));
            Line(g, Paper, 1, new PointF(600, 56), new PointF(600, 78));
            Line(g, Paper, 1, new PointF(1088, 352), new PointF(1066, 352));
            Line(g, Paper, 1, new PointF(1088, 352), new PointF(1088, 330));
        }
        return bitmap;
    }

    private static Bitmap DrawSiege(int frame, int frameCount)
    {
        Graphics g;
        var bitmap = Canvas(576, 342, out g);
        using (g)
        {
            g.ScaleTransform(0.9f, 0.9f);
            Text(g, "EVENT ROUTE", "Consolas", 13, Muted, 40, 26, FontStyle.Bold);
            Text(g, "SIEGE  /  SIMULATED NETWORK", "Segoe UI", 13, Ink, 394, 26, FontStyle.Bold);
            Line(g, Rule, 1.2f, new PointF(40, 54), new PointF(600, 54));

            PointF[] n = {
                new PointF(72, 172), new PointF(188, 104), new PointF(304, 172),
                new PointF(420, 104), new PointF(536, 172), new PointF(420, 267), new PointF(188, 267)
            };
            int[,] edges = { {0,1},{1,2},{2,3},{3,4},{2,5},{5,6},{6,0},{1,6},{5,4} };
            for (int i = 0; i < edges.GetLength(0); i++)
                Line(g, Rule, 1.4f, n[edges[i,0]], n[edges[i,1]]);

            string[] labels = { "CLIENT", "EDGE", "API", "WEBSOCKET", "SERVICE", "IDS / FIREWALL", "HISTORY" };
            for (int i = 0; i < n.Length; i++)
            {
                Circle(g, n[i].X, n[i].Y, 16, i == 5 ? Moss : Ink, 1.8f);
                if (i == 5) Circle(g, n[i].X, n[i].Y, 22, LightMoss, 1.5f);
                Dot(g, n[i].X, n[i].Y, 3.5f, i == 5 ? Moss : Ink);
                CenterText(g, labels[i], "Consolas", 10.5f, Muted, n[i].X, n[i].Y + 27, FontStyle.Regular);
            }

            // Event packets take a fixed route through the simulated network.
            PointF[] route = { n[0], n[1], n[2], n[3], n[4] };
            float phase = (float)frame / frameCount;
            float routePosition = phase * (route.Length - 1);
            int segment = Math.Min(route.Length - 2, (int)routePosition);
            float local = routePosition - segment;
            PointF packet = Along(route[segment], route[segment + 1], local);
            using (var pen = P(Oxide, 3f))
                for (int i = 0; i < segment; i++) g.DrawLine(pen, route[i], route[i + 1]);
            using (var pen = P(Oxide, 3f)) g.DrawLine(pen, route[segment], packet);
            Dot(g, packet.X, packet.Y, 6, Oxide);

            // The response boundary is highlighted as the packet approaches the service.
            PointF gate = Along(n[3], n[4], 0.54f);
            float response = Math.Max(0, Math.Min(1, (phase - 0.64f) / 0.20f));
            if (response > 0)
            {
                float spread = 13 + response * 5;
                Line(g, Moss, 3, new PointF(gate.X - spread, gate.Y - spread), new PointF(gate.X + spread, gate.Y + spread));
                Line(g, Moss, 3, new PointF(gate.X - spread, gate.Y + spread), new PointF(gate.X + spread, gate.Y - spread));
                Circle(g, gate.X, gate.Y, 28 + 5 * (float)Math.Sin(response * Math.PI), LightMoss, 1.4f);
            }

            Line(g, Rule, 1, new PointF(40, 332), new PointF(600, 332));
            Text(g, "API  →  EVENT STREAM  →  DEFENCE  →  HISTORY", "Consolas", 12, Muted, 40, 344);
        }
        return bitmap;
    }

    private static PointF StockPoint(float t)
    {
        float x = 76 + 486 * t;
        float y = 239 - (float)(53 * t + 40 * Math.Sin(t * 8.2) + 23 * Math.Sin(t * 18.7) + 12 * Math.Cos(t * 28.5));
        return new PointF(x, y);
    }

    private static PointF EstimatePoint(float t)
    {
        float x = 76 + 486 * t;
        float y = 239 - (float)(53 * t + 40 * Math.Sin(t * 8.2) + 23 * Math.Sin(t * 18.7) + 12 * Math.Cos(t * 28.5));
        return new PointF(x, y);
    }

    private static Bitmap DrawMarket(int frame, int frameCount)
    {
        Graphics g;
        var bitmap = Canvas(576, 342, out g);
        using (g)
        {
            g.ScaleTransform(0.9f, 0.9f);
            Text(g, "MODEL WINDOW", "Consolas", 13, Muted, 40, 26, FontStyle.Bold);
            Text(g, "HISTORY  →  ESTIMATE", "Segoe UI", 13, Ink, 430, 26, FontStyle.Bold);
            Line(g, Rule, 1.2f, new PointF(40, 54), new PointF(600, 54));

            for (int i = 0; i < 5; i++)
            {
                float y = 102 + i * 50;
                Line(g, Rule, 1, new PointF(72, y), new PointF(570, y));
            }
            Line(g, Ink, 1.1f, new PointF(72, 90), new PointF(72, 302));
            Line(g, Ink, 1.1f, new PointF(72, 302), new PointF(570, 302));
            using (var divider = P(Muted, 1.1f))
            {
                divider.DashPattern = new float[] { 4, 6 };
                g.DrawLine(divider, 385, 90, 385, 302);
            }
            Text(g, "OBSERVED", "Consolas", 11, Muted, 82, 78, FontStyle.Bold);
            Text(g, "ESTIMATE", "Consolas", 11, Oxide, 407, 78, FontStyle.Bold);

            PointF[] history = new PointF[42];
            for (int i = 0; i < history.Length; i++)
                history[i] = StockPoint((float)i / (history.Length - 1) * 0.64f);
            using (var pen = P(Ink, 2.4f)) g.DrawLines(pen, history);

            float progress = 0.12f + 0.88f * (0.5f - 0.5f * (float)Math.Cos((float)frame / frameCount * Math.PI * 2));
            int forecastCount = 26;
            var forecast = new PointF[forecastCount];
            for (int i = 0; i < forecastCount; i++)
                forecast[i] = EstimatePoint(0.64f + (float)i / (forecastCount - 1) * 0.36f);

            // A quiet interval around the estimate, drawn as a restrained band.
            float envelope = 6 + progress * 13;
            using (var bandPen = P(LightMoss, envelope))
            {
                bandPen.StartCap = LineCap.Flat;
                bandPen.EndCap = LineCap.Flat;
                g.DrawLines(bandPen, forecast);
            }
            using (var pen = P(Oxide, 2.5f))
            {
                pen.DashPattern = new float[] { 5, 4 };
                int through = Math.Max(2, Math.Min(forecastCount, (int)(progress * forecastCount)));
                var segment = new PointF[through];
                Array.Copy(forecast, segment, through);
                g.DrawLines(pen, segment);
                PointF estimate = segment[segment.Length - 1];
                Dot(g, estimate.X, estimate.Y, 5.5f, Oxide);
                Circle(g, estimate.X, estimate.Y, 11, Oxide, 1.3f);
            }

            Line(g, Rule, 1, new PointF(40, 332), new PointF(600, 332));
            Text(g, "ILLUSTRATIVE SIGNAL  ·  HISTORICAL INPUT → TREND ESTIMATE", "Consolas", 10.5f, Muted, 40, 344);
        }
        return bitmap;
    }

    private static Bitmap[] RenderFrames(int count, Func<int, int, Bitmap> draw)
    {
        var frames = new Bitmap[count];
        for (int i = 0; i < count; i++) frames[i] = draw(i, count);
        return frames;
    }

    public static void RenderAll(string templatePath, string outputDir)
    {
        using (var template = Image.FromFile(templatePath))
        {
            SaveGif(RenderFrames(40, DrawCover), System.IO.Path.Combine(outputDir, "cover.gif"), template, 8);
            SaveGif(RenderFrames(36, DrawSiege), System.IO.Path.Combine(outputDir, "siege.gif"), template, 8);
            SaveGif(RenderFrames(36, DrawMarket), System.IO.Path.Combine(outputDir, "market.gif"), template, 8);
        }
    }
}
'@

$runtimeDir = Split-Path ([System.Drawing.Image].Assembly.Location)
$references = Get-ChildItem -LiteralPath $runtimeDir -Filter 'System*.dll' |
  ForEach-Object {
    try {
      [System.Reflection.AssemblyName]::GetAssemblyName($_.FullName) | Out-Null
      $_.FullName
    } catch { }
  }
Add-Type -TypeDefinition $source -ReferencedAssemblies $references -ErrorAction Stop

$outputDir = Join-Path (Get-Location) 'assets\motion'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$templatePath = Join-Path (Get-Location) 'assets\divider.gif'
[ProfileMotionRenderer]::RenderAll($templatePath, $outputDir)
Write-Output "Rendered animated profile visuals to $outputDir"
