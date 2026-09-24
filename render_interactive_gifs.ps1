Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$source = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;

public static class ProfileArtworkMotion
{
    private static readonly Color Paper = Color.FromArgb(239, 236, 226);
    private static readonly Color Ink = Color.FromArgb(37, 42, 37);
    private static readonly Color Muted = Color.FromArgb(92, 94, 83);
    private static readonly Color Oxide = Color.FromArgb(177, 72, 51);

    private static void DrawCoverType(Graphics g)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        using (var accent = new SolidBrush(Oxide))
            g.FillRectangle(accent, 48, 61, 4, 20);
        using (var labelFont = new Font("Segoe UI", 12, FontStyle.Bold, GraphicsUnit.Pixel))
        using (var ink = new SolidBrush(Ink))
            g.DrawString("GOKUL A", labelFont, ink, 64, 60);

        using (var titleFont = new Font("Georgia", 34, FontStyle.Bold, GraphicsUnit.Pixel))
        using (var ink = new SolidBrush(Ink))
        {
            g.DrawString("Systems that", titleFont, ink, 48, 96);
            g.DrawString("make signals", titleFont, ink, 48, 137);
            g.DrawString("useful.", titleFont, ink, 48, 178);
        }

        using (var subtitleFont = new Font("Segoe UI", 15, FontStyle.Regular, GraphicsUnit.Pixel))
        using (var ink = new SolidBrush(Muted))
            g.DrawString("Computer vision  ·  applied AI  ·  engineering tools", subtitleFont, ink, 52, 239);
    }

    private static Bitmap RenderFrame(string sourcePath, int width, int height, int frame, int frameCount,
                                      float panX, float panY, bool cover)
    {
        using (var source = Image.FromFile(sourcePath))
        {
            var canvas = new Bitmap(width, height, PixelFormat.Format24bppRgb);
            using (var g = Graphics.FromImage(canvas))
            {
                g.Clear(Paper);
                g.SmoothingMode = SmoothingMode.HighQuality;
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;

                double phase = 2.0 * Math.PI * frame / frameCount;
                double fit = Math.Max((double)width / source.Width, (double)height / source.Height);
                // The small, eased scale and pan return exactly to their starting pose each loop.
                double scale = fit * (1.008 + 0.018 * (0.5 - 0.5 * Math.Cos(phase)));
                float drawWidth = (float)(source.Width * scale);
                float drawHeight = (float)(source.Height * scale);
                float x = (width - drawWidth) / 2f + (float)(panX * Math.Sin(phase));
                float y = (height - drawHeight) / 2f + (float)(panY * Math.Sin(phase + 0.7));
                g.DrawImage(source, new RectangleF(x, y, drawWidth, drawHeight));

                if (cover) DrawCoverType(g);
            }
            return canvas;
        }
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

    private static void SaveLoopingGif(Bitmap[] frames, string output, Image template, int delay)
    {
        ImageCodecInfo codec = null;
        foreach (var candidate in ImageCodecInfo.GetImageEncoders())
            if (candidate.MimeType == "image/gif") { codec = candidate; break; }

        var first = frames[0];
        first.SetPropertyItem(DelayProperty(template, frames.Length, delay));
        using (var parameters = new EncoderParameters(1))
        {
            parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.MultiFrame);
            first.Save(output, codec, parameters);
            parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.FrameDimensionTime);
            for (int i = 1; i < frames.Length; i++) first.SaveAdd(frames[i], parameters);
            parameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.Flush);
            first.SaveAdd(parameters);
        }
        foreach (var frame in frames) frame.Dispose();
        AddInfiniteLoopExtension(output);
    }

    private static void AddInfiniteLoopExtension(string path)
    {
        var bytes = System.IO.File.ReadAllBytes(path);
        if (System.Text.Encoding.ASCII.GetString(bytes).Contains("NETSCAPE2.0")) return;
        int packed = bytes[10];
        int colorTableBytes = (packed & 0x80) != 0 ? 3 * (1 << ((packed & 0x07) + 1)) : 0;
        int insertAt = 13 + colorTableBytes;
        byte[] extension = { 0x21,0xFF,0x0B,0x4E,0x45,0x54,0x53,0x43,0x41,0x50,0x45,0x32,0x2E,0x30,0x03,0x01,0x00,0x00,0x00 };
        var looped = new byte[bytes.Length + extension.Length];
        Array.Copy(bytes, 0, looped, 0, insertAt);
        Array.Copy(extension, 0, looped, insertAt, extension.Length);
        Array.Copy(bytes, insertAt, looped, insertAt + extension.Length, bytes.Length - insertAt);
        System.IO.File.WriteAllBytes(path, looped);
    }

    private static Bitmap[] Frames(string path, int width, int height, int count, float panX, float panY, bool cover)
    {
        var frames = new Bitmap[count];
        for (int i = 0; i < count; i++)
            frames[i] = RenderFrame(path, width, height, i, count, panX, panY, cover);
        return frames;
    }

    public static void RenderAll(string root, string templatePath)
    {
        string source = System.IO.Path.Combine(root, "assets", "motion", "source");
        string output = System.IO.Path.Combine(root, "assets", "motion");
        using (var template = Image.FromFile(templatePath))
        {
            SaveLoopingGif(Frames(System.IO.Path.Combine(source, "cover.jpg"), 840, 323, 32, 5, 3, true),
                           System.IO.Path.Combine(output, "cover-art.gif"), template, 11);
            SaveLoopingGif(Frames(System.IO.Path.Combine(source, "facetrack.jpg"), 512, 304, 32, 4, 3, false),
                           System.IO.Path.Combine(output, "facetrack-art.gif"), template, 11);
            SaveLoopingGif(Frames(System.IO.Path.Combine(source, "skillguard.jpg"), 512, 304, 32, 4, 3, false),
                           System.IO.Path.Combine(output, "skillguard-art.gif"), template, 11);
            SaveLoopingGif(Frames(System.IO.Path.Combine(source, "rootcause.jpg"), 512, 304, 32, 4, 3, false),
                           System.IO.Path.Combine(output, "rootcause-art.gif"), template, 11);
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

$root = Get-Location
$templatePath = Join-Path $root 'assets\divider.gif'
[ProfileArtworkMotion]::RenderAll($root.Path, $templatePath)
Write-Output "Rendered the cover and three seamless illustrated project GIFs in $(Join-Path $root 'assets\motion')"
