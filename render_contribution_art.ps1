Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$source = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Text;

public static class ContributionArtRenderer
{
    private static readonly Color Paper = Color.FromArgb(239, 236, 226);
    private static readonly Color Ink = Color.FromArgb(37, 42, 37);
    private static readonly Color Muted = Color.FromArgb(119, 119, 106);
    private static readonly Color Rule = Color.FromArgb(204, 198, 182);
    private static readonly Color Oxide = Color.FromArgb(177, 72, 51);
    private static readonly Color[] Cells = {
        Color.FromArgb(224, 220, 207),
        Color.FromArgb(216, 188, 168),
        Color.FromArgb(192, 142, 116),
        Color.FromArgb(145, 153, 119),
        Color.FromArgb(96, 113, 84)
    };

    private static void Text(Graphics g, string value, string family, float size,
                             FontStyle style, Color color, float x, float y)
    {
        using (var font = new Font(family, size, style, GraphicsUnit.Pixel))
        using (var brush = new SolidBrush(color))
            g.DrawString(value, font, brush, x, y);
    }

    private static Color Mix(Color a, Color b, float amount)
    {
        amount = Math.Max(0, Math.Min(1, amount));
        return Color.FromArgb(
            (int)(a.R + (b.R - a.R) * amount),
            (int)(a.G + (b.G - a.G) * amount),
            (int)(a.B + (b.B - a.B) * amount));
    }

    private static Bitmap DrawFrame(int[,] grid, int activeWeeks, int frame, int frameCount)
    {
        const int width = 840, height = 168, weeks = 53, days = 7;
        const int gridX = 178, gridY = 43, tile = 9, gap = 3, step = tile + gap;
        var bitmap = new Bitmap(width, height, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(bitmap))
        using (var paper = new SolidBrush(Paper))
        using (var ink = new SolidBrush(Ink))
        using (var muted = new SolidBrush(Muted))
        {
            g.Clear(Paper);
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.FillRectangle(new SolidBrush(Oxide), 22, 31, 3, 20);
            Text(g, "367", "Georgia", 32, FontStyle.Bold, Ink, 36, 28);
            Text(g, "contributions", "Segoe UI", 11, FontStyle.Bold, Ink, 37, 66);
            Text(g, activeWeeks.ToString() + " active weeks", "Segoe UI", 9, FontStyle.Regular, Muted, 37, 94);
            Text(g, "12 months · through 9 Sep 2026", "Segoe UI", 8, FontStyle.Regular, Muted, 37, 119);
            using (var divider = new Pen(Rule, 1)) g.DrawLine(divider, 151, 24, 151, 142);

            string[] months = { "Sep", "Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug" };
            for (int m = 0; m < months.Length; m++)
            {
                int x = gridX + (int)(m * (weeks / 12.0) * step);
                Text(g, months[m], "Segoe UI", 8, FontStyle.Regular, Muted, x, 20);
            }
            Text(g, "M", "Segoe UI", 7, FontStyle.Regular, Muted, 158, gridY + 1);
            Text(g, "W", "Segoe UI", 7, FontStyle.Regular, Muted, 158, gridY + 25);
            Text(g, "F", "Segoe UI", 7, FontStyle.Regular, Muted, 158, gridY + 49);

            double phase = 2.0 * Math.PI * frame / frameCount;
            float focusWeek = (weeks - 1) * (0.5f - 0.5f * (float)Math.Cos(phase));
            int focusColumn = Math.Max(0, Math.Min(weeks - 1, (int)Math.Round(focusWeek)));
            for (int x = 0; x < weeks; x++)
            for (int y = 0; y < days; y++)
            {
                Color fill = Cells[grid[x, y]];
                if (x == focusColumn && grid[x, y] > 0) fill = Mix(fill, Paper, 0.18f);
                using (var brush = new SolidBrush(fill))
                    g.FillRectangle(brush, gridX + x * step, gridY + y * step, tile, tile);
            }

            // A small oxide registration mark moves across the year; no chart or fake live signal.
            float markerX = gridX + focusWeek * step + 2;
            using (var marker = new SolidBrush(Oxide)) g.FillRectangle(marker, markerX, 36, 5, 2);
            Text(g, "LESS", "Segoe UI", 7, FontStyle.Regular, Muted, gridX, 139);
            for (int i = 0; i < Cells.Length; i++)
            using (var brush = new SolidBrush(Cells[i]))
                g.FillRectangle(brush, gridX + 31 + i * 13, 139, 9, 9);
            Text(g, "MORE", "Segoe UI", 7, FontStyle.Regular, Muted, gridX + 104, 139);
        }
        return bitmap;
    }

    private static PropertyItem DelayProperty(Image template, int count, int centiseconds)
    {
        var item = template.GetPropertyItem(0x5100);
        item.Id = 0x5100;
        item.Type = 4;
        item.Len = count * 4;
        item.Value = new byte[item.Len];
        for (int i = 0; i < count; i++)
            Array.Copy(BitConverter.GetBytes(centiseconds), 0, item.Value, i * 4, 4);
        return item;
    }

    private static void SaveLoopingGif(Bitmap[] frames, string path, Image template)
    {
        ImageCodecInfo codec = null;
        foreach (var candidate in ImageCodecInfo.GetImageEncoders())
            if (candidate.MimeType == "image/gif") { codec = candidate; break; }

        frames[0].SetPropertyItem(DelayProperty(template, frames.Length, 11));
        using (var parameters = new EncoderParameters(1))
        {
            parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.MultiFrame);
            frames[0].Save(path, codec, parameters);
            parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.FrameDimensionTime);
            for (int i = 1; i < frames.Length; i++) frames[0].SaveAdd(frames[i], parameters);
            parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.Flush);
            frames[0].SaveAdd(parameters);
        }
        foreach (var frame in frames) frame.Dispose();

        byte[] bytes = System.IO.File.ReadAllBytes(path);
        int packed = bytes[10];
        int tableBytes = (packed & 0x80) != 0 ? 3 * (1 << ((packed & 0x07) + 1)) : 0;
        int insertAt = 13 + tableBytes;
        byte[] loop = { 0x21,0xFF,0x0B,0x4E,0x45,0x54,0x53,0x43,0x41,0x50,0x45,0x32,0x2E,0x30,0x03,0x01,0x00,0x00,0x00 };
        var output = new byte[bytes.Length + loop.Length];
        Array.Copy(bytes, 0, output, 0, insertAt);
        Array.Copy(loop, 0, output, insertAt, loop.Length);
        Array.Copy(bytes, insertAt, output, insertAt + loop.Length, bytes.Length - insertAt);
        System.IO.File.WriteAllBytes(path, output);
    }

    public static void Render(string root, string matrixPath, string templatePath)
    {
        const int weeks = 53, days = 7, frameCount = 32;
        var grid = new int[weeks, days];
        string[] columns = System.IO.File.ReadAllText(matrixPath).Split(';');
        for (int x = 0; x < Math.Min(weeks, columns.Length); x++)
        {
            string[] values = columns[x].Split(',');
            for (int y = 0; y < Math.Min(days, values.Length); y++)
            {
                int value;
                if (Int32.TryParse(values[y], out value)) grid[x, y] = Math.Max(0, Math.Min(4, value));
            }
        }

        int activeWeeks = 0;
        for (int x = 0; x < weeks; x++)
        {
            int total = 0;
            for (int y = 0; y < days; y++) total += grid[x, y];
            if (total > 0) activeWeeks++;
        }

        var frames = new Bitmap[frameCount];
        for (int i = 0; i < frameCount; i++) frames[i] = DrawFrame(grid, activeWeeks, i, frameCount);
        using (var template = Image.FromFile(templatePath))
            SaveLoopingGif(frames, System.IO.Path.Combine(root, "assets", "motion", "contributions-art.gif"), template);
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

$root = Get-Location
$matrixPath = Join-Path $root 'real_contrib_matrix.txt'
$templatePath = Join-Path $root 'assets\divider.gif'
[ContributionArtRenderer]::Render($root.Path, $matrixPath, $templatePath)
Write-Output "Rendered the warm contribution snapshot GIF in $(Join-Path $root 'assets\motion')"
