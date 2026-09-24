$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -eq 'Core') {
    $windowsPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $windowsPowerShell)) {
        throw 'This renderer needs Windows PowerShell 5.1 for System.Drawing.'
    }
    & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath
    exit $LASTEXITCODE
}

$source = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;

public static class IndustrialProfileRenderer {
    const int Frames = 12;
    const int DelayMs = 90;
    const int Width = 840;
    static readonly Color Bone = Color.FromArgb(241, 239, 232);
    static readonly Color Ink = Color.FromArgb(27, 30, 29);
    static readonly Color Muted = Color.FromArgb(82, 86, 83);
    static readonly Color Accent = Color.FromArgb(229, 82, 37);
    static readonly Color Hairline = Color.FromArgb(105, 108, 103);

    static void Quality(Graphics g) {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
    }

    static void DrawCrop(Graphics g, Image image, Rectangle dest, float focusX, float focusY) {
        float scale = Math.Max(dest.Width / (float)image.Width, dest.Height / (float)image.Height);
        float sourceWidth = dest.Width / scale;
        float sourceHeight = dest.Height / scale;
        float sourceX = (image.Width - sourceWidth) * Math.Max(0f, Math.Min(1f, focusX));
        float sourceY = (image.Height - sourceHeight) * Math.Max(0f, Math.Min(1f, focusY));
        g.DrawImage(image, dest, new RectangleF(sourceX, sourceY, sourceWidth, sourceHeight), GraphicsUnit.Pixel);
    }

    static void Text(Graphics g, string value, string face, float size, FontStyle style, Color color,
                     float x, float y, float width, float height, StringAlignment alignment) {
        using (Font font = new Font(face, size, style, GraphicsUnit.Pixel))
        using (SolidBrush brush = new SolidBrush(color))
        using (StringFormat format = new StringFormat()) {
            format.Alignment = alignment;
            format.LineAlignment = StringAlignment.Near;
            format.Trimming = StringTrimming.Word;
            g.DrawString(value, font, brush, new RectangleF(x, y, width, height), format);
        }
    }

    static void TrackedText(Graphics g, string value, string face, float size, FontStyle style,
                            Color color, float x, float y, float tracking) {
        using (Font font = new Font(face, size, style, GraphicsUnit.Pixel))
        using (SolidBrush brush = new SolidBrush(color)) {
            for (int i = 0; i < value.Length; i++) {
                string letter = value.Substring(i, 1);
                g.DrawString(letter, font, brush, x, y);
                x += g.MeasureString(letter, font).Width + tracking;
            }
        }
    }

    static void Rule(Graphics g, float x1, float y, float x2, Color color, float thickness) {
        using (Pen pen = new Pen(color, thickness)) g.DrawLine(pen, x1, y, x2, y);
    }

    static void SaveGif(string outputPath, Bitmap[] frames, int delayMs) {
        using (FileStream fs = new FileStream(outputPath, FileMode.Create, FileAccess.Write)) {
            int delay100th = delayMs / 10;
            byte delayLo = (byte)(delay100th & 0xFF);
            byte delayHi = (byte)((delay100th >> 8) & 0xFF);
            for (int i = 0; i < frames.Length; i++) {
                using (MemoryStream ms = new MemoryStream()) {
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
                        byte[] loop = new byte[] {
                            0x21, 0xFF, 0x0B,
                            (byte)'N',(byte)'E',(byte)'T',(byte)'S',(byte)'C',(byte)'A',(byte)'P',(byte)'E',(byte)'2',(byte)'.',(byte)'0',
                            0x03,0x01,0x00,0x00,0x00
                        };
                        fs.Write(loop, 0, loop.Length);
                        byte[] gce = new byte[] { 0x21,0xF9,0x04,0x00,delayLo,delayHi,0x00,0x00 };
                        fs.Write(gce, 0, gce.Length);
                        int imageStart = 13 + gctSize;
                        if (bytes[imageStart] == 0x21 && bytes[imageStart + 1] == 0xF9) imageStart += 8;
                        fs.Write(bytes, imageStart, bytes.Length - imageStart - 1);
                    } else {
                        byte[] gce = new byte[] { 0x21,0xF9,0x04,0x00,delayLo,delayHi,0x00,0x00 };
                        fs.Write(gce, 0, gce.Length);
                        int imageStart = 13;
                        if ((bytes[10] & 0x80) != 0) {
                            int count = 1 << ((bytes[10] & 7) + 1);
                            imageStart += 3 * count;
                        }
                        if (bytes[imageStart] == 0x21 && bytes[imageStart + 1] == 0xF9) imageStart += 8;
                        if (bytes[imageStart] == 0x2C) {
                            if ((bytes[10] & 0x80) != 0) {
                                byte[] descriptor = new byte[10];
                                Array.Copy(bytes, imageStart, descriptor, 0, 10);
                                descriptor[9] = (byte)(0x80 | (bytes[10] & 0x07));
                                fs.Write(descriptor, 0, 10);
                                int count = 1 << ((bytes[10] & 7) + 1);
                                fs.Write(bytes, 13, 3 * count);
                                fs.Write(bytes, imageStart + 10, bytes.Length - (imageStart + 10) - 1);
                            } else {
                                fs.Write(bytes, imageStart, bytes.Length - imageStart - 1);
                            }
                        }
                    }
                }
            }
            fs.WriteByte(0x3B);
        }
    }

    static void Render(string outputPath, int width, int height, Action<Graphics, float> drawFrame) {
        Bitmap[] frames = new Bitmap[Frames];
        try {
            for (int i = 0; i < Frames; i++) {
                Bitmap bmp = new Bitmap(width, height, PixelFormat.Format24bppRgb);
                using (Graphics g = Graphics.FromImage(bmp)) {
                    Quality(g);
                    drawFrame(g, (float)i / (Frames - 1));
                }
                frames[i] = bmp;
            }
            SaveGif(outputPath, frames, DelayMs);
        } finally {
            for (int i = 0; i < frames.Length; i++) if (frames[i] != null) frames[i].Dispose();
        }
    }

    static void Base(Graphics g, Image image, int height) {
        g.Clear(Bone);
        DrawCrop(g, image, new Rectangle(0, 0, Width, height), 0.5f, 0.5f);
    }

    static void SectionTitle(Graphics g, string title, float y, float ruleStart) {
        using (SolidBrush brush = new SolidBrush(Accent)) g.FillRectangle(brush, 32, y + 4, 5, 31);
        Text(g, title, "Bahnschrift", 31f, FontStyle.Bold, Ink, 51, y, ruleStart - 56, 39, StringAlignment.Near);
        Rule(g, ruleStart, y + 24, 808, Hairline, 1f);
    }

    public static void BuildHero(string outputPath, string backgroundPath) {
        using (Image background = Image.FromFile(backgroundPath)) {
            Render(outputPath, Width, 350, delegate(Graphics g, float t) {
                Base(g, background, 350);
                TrackedText(g, "ENGINEERING  /  COMPUTER VISION  /  TOOLING", "Consolas", 12.5f, FontStyle.Regular, Ink, 38, 26, 1.2f);
                Rule(g, 38, 54, 800, Hairline, 1f);
                Text(g, "GOKUL A.", "Bahnschrift", 76f, FontStyle.Bold, Ink, 38, 83, 500, 84, StringAlignment.Near);
                using (SolidBrush brush = new SolidBrush(Accent)) g.FillRectangle(brush, 40, 173, 38 + t * 48, 8);
                Text(g, "I build systems whose decisions can be followed\u2014and whose failure modes stay visible.",
                     "Segoe UI", 24f, FontStyle.Bold, Ink, 40, 204, 500, 100, StringAlignment.Near);
                TrackedText(g, "GOKUL A.  |  PROFILE", "Consolas", 10.5f, FontStyle.Regular, Muted, 40, 322, 1.6f);
            });
        }
    }

    public static void BuildProjects(string outputPath, string stockPath, string facePath, string guardPath, string rootPath) {
        using (Image stock = Image.FromFile(stockPath))
        using (Image face = Image.FromFile(facePath))
        using (Image guard = Image.FromFile(guardPath))
        using (Image root = Image.FromFile(rootPath)) {
            Render(outputPath, Width, 430, delegate(Graphics g, float t) {
                Base(g, stock, 430);
                SectionTitle(g, "Selected builds", 19, 294);
                string[] names = { "FaceTrack-AI", "SkillGuard-OSS", "RootCause-IQ" };
                string[] descriptions = {
                    "Streams 3D facial landmarks and gaze estimates through a WebAssembly pipeline.",
                    "Uses static AST inspection to find excessive capabilities and supply-chain risk.",
                    "Reconstructs distributed traces to locate the event that triggered downstream failures."
                };
                string[] stacks = {
                    "TypeScript \u00B7 WebAssembly \u00B7 OpenCV",
                    "TypeScript \u00B7 AST \u00B7 Security",
                    "Python \u00B7 OpenTelemetry \u00B7 Causal AI"
                };
                Image[] art = { face, guard, root };
                int[] xs = { 32, 306, 580 };
                int cardWidth = 228;
                int imageY = 73;
                int imageH = 114;
                int active = Math.Min(2, (int)(t * 3f));
                for (int i = 0; i < 3; i++) {
                    int x = xs[i];
                    DrawCrop(g, art[i], new Rectangle(x, imageY, cardWidth, imageH), 0.5f, 0.5f);
                    using (SolidBrush baseMark = new SolidBrush(Color.FromArgb(95, Ink)))
                        g.FillRectangle(baseMark, x, imageY + imageH - 3, cardWidth, 3);
                    if (i == active) {
                        using (SolidBrush mark = new SolidBrush(Accent))
                            g.FillRectangle(mark, x, imageY + imageH - 3, 50 + (int)(t * 22f), 3);
                    }
                    Text(g, names[i], "Bahnschrift", 21f, FontStyle.Bold, Ink, x, 203, cardWidth, 29, StringAlignment.Near);
                    using (SolidBrush brush = new SolidBrush(Accent)) g.FillRectangle(brush, x, 235, 27, 3);
                    Text(g, descriptions[i], "Segoe UI", 14.3f, FontStyle.Regular, Ink, x, 248, cardWidth, 68, StringAlignment.Near);
                    Text(g, stacks[i], "Consolas", 11.4f, FontStyle.Regular, Muted, x, 328, cardWidth, 42, StringAlignment.Near);
                    if (i < 2) {
                        using (Pen pen = new Pen(Color.FromArgb(140, Hairline), 1f))
                            g.DrawLine(pen, x + cardWidth + 18, 75, x + cardWidth + 18, 381);
                    }
                }
                Rule(g, 32, 399, 808, Hairline, 1f);
            });
        }
    }

    public static void BuildDomains(string outputPath, string stockPath) {
        using (Image stock = Image.FromFile(stockPath)) {
            Render(outputPath, Width, 224, delegate(Graphics g, float t) {
                Base(g, stock, 224);
                SectionTitle(g, "Core domains", 18, 270);
                string[] names = { "Computer vision", "AI agents", "Systems security" };
                string[] descriptions = {
                    "Landmark geometry, gaze estimation, and real-time visual pipelines.",
                    "Tool routing, multi-agent workflows, and inspectable decisions.",
                    "AST analysis, capability audits, and sandboxed runtimes."
                };
                int[] xs = { 34, 306, 578 };
                for (int i = 0; i < 3; i++) {
                    int x = xs[i];
                    Text(g, names[i], "Bahnschrift", 21f, FontStyle.Bold, Ink, x, 91, 235, 31, StringAlignment.Near);
                    using (SolidBrush brush = new SolidBrush(Accent)) g.FillRectangle(brush, x, 128, 30 + (i == (int)(t * 3) ? 14 : 0), 3);
                    Text(g, descriptions[i], "Segoe UI", 14.5f, FontStyle.Regular, Muted, x, 143, 232, 59, StringAlignment.Near);
                    if (i < 2) using (Pen pen = new Pen(Color.FromArgb(130, Hairline), 1f)) g.DrawLine(pen, x + 250, 88, x + 250, 205);
                }
            });
        }
    }

    static int[,] ReadContributionMatrix(string path, out int activeWeeks) {
        string raw = File.ReadAllText(path).Trim();
        string[] weekStrings = raw.Split(new char[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
        if (weekStrings.Length != 53) throw new InvalidDataException("Expected 53 contribution weeks, found " + weekStrings.Length);
        int[,] grid = new int[53, 7];
        activeWeeks = 0;
        for (int w = 0; w < 53; w++) {
            string[] days = weekStrings[w].Split(',');
            if (days.Length != 7) throw new InvalidDataException("Contribution week " + w + " does not contain 7 days");
            bool active = false;
            for (int d = 0; d < 7; d++) {
                int value;
                if (!Int32.TryParse(days[d], out value)) throw new InvalidDataException("Invalid contribution value");
                grid[w, d] = Math.Max(0, Math.Min(4, value));
                if (value > 0) active = true;
            }
            if (active) activeWeeks++;
        }
        return grid;
    }

    public static void BuildContributions(string outputPath, string stockPath, string matrixPath) {
        int activeWeeks;
        int[,] grid = ReadContributionMatrix(matrixPath, out activeWeeks);
        if (activeWeeks != 22) throw new InvalidDataException("Expected 22 active weeks in the approved snapshot, found " + activeWeeks);
        using (Image stock = Image.FromFile(stockPath)) {
            Render(outputPath, Width, 224, delegate(Graphics g, float t) {
                Base(g, stock, 224);
                SectionTitle(g, "Contributions", 16, 286);
                Text(g, "367", "Bahnschrift", 53f, FontStyle.Bold, Ink, 34, 75, 150, 62, StringAlignment.Near);
                TrackedText(g, "CONTRIBUTIONS", "Consolas", 11f, FontStyle.Regular, Muted, 38, 141, 1.2f);
                using (Pen pen = new Pen(Color.FromArgb(145, Hairline), 1f)) g.DrawLine(pen, 192, 81, 192, 163);
                Text(g, "22", "Bahnschrift", 53f, FontStyle.Bold, Ink, 218, 75, 110, 62, StringAlignment.Near);
                TrackedText(g, "ACTIVE WEEKS", "Consolas", 11f, FontStyle.Regular, Muted, 222, 141, 1.2f);

                int gridX = 375, gridY = 91, cell = 6, gap = 2, step = cell + gap;
                string[] months = { "OCT","NOV","DEC","JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP" };
                using (Font monthFont = new Font("Consolas", 8.5f, GraphicsUnit.Pixel))
                using (SolidBrush monthBrush = new SolidBrush(Muted)) {
                    for (int m = 0; m < months.Length; m++) {
                        float mx = gridX + (m * 53f / months.Length) * step;
                        g.DrawString(months[m], monthFont, monthBrush, mx, 72);
                    }
                }
                Color[] levels = {
                    Color.FromArgb(225, 224, 217),
                    Color.FromArgb(239, 193, 169),
                    Color.FromArgb(232, 144, 108),
                    Color.FromArgb(221, 99, 61),
                    Color.FromArgb(178, 60, 32)
                };
                for (int w = 0; w < 53; w++) {
                    for (int d = 0; d < 7; d++) {
                        int x = gridX + w * step;
                        int y = gridY + d * step;
                        using (SolidBrush brush = new SolidBrush(levels[grid[w, d]])) g.FillRectangle(brush, x, y, cell, cell);
                    }
                }
                int focusWeek = Math.Min(52, (int)(t * 53f));
                int markerX = gridX + focusWeek * step;
                using (SolidBrush marker = new SolidBrush(Accent)) g.FillRectangle(marker, markerX, gridY - 9, cell, 4);
                TrackedText(g, "STATIC SNAPSHOT  |  THROUGH 09 SEP 2026", "Consolas", 9.6f, FontStyle.Regular, Muted, 375, 164, 0.5f);
            });
        }
    }

    public static void BuildToolkit(string outputPath, string stockPath) {
        using (Image stock = Image.FromFile(stockPath)) {
            Render(outputPath, Width, 246, delegate(Graphics g, float t) {
                Base(g, stock, 246);
                SectionTitle(g, "Technical toolkit", 17, 315);
                string[] headings = { "Languages", "ML & vision", "Security", "Web & platforms" };
                string[] lists = {
                    "Python\nTypeScript\nJavaScript\nPowerShell / Bash",
                    "PyTorch\nTensorFlow\nscikit-learn\nOpenCV / NumPy\npandas",
                    "AST analysis\nCapability auditing\nSandboxed runtimes",
                    "React / Next.js\nNode.js / REST\nWebSockets\nGit / CI"
                };
                int[] xs = { 34, 239, 444, 649 };
                for (int i = 0; i < 4; i++) {
                    int x = xs[i];
                    Text(g, headings[i], "Bahnschrift", 18.5f, FontStyle.Bold, Ink, x, 91, 174, 28, StringAlignment.Near);
                    using (SolidBrush brush = new SolidBrush(Accent)) g.FillRectangle(brush, x, 122, 24 + ((i == (int)(t * 4) ? 10 : 0)), 3);
                    Text(g, lists[i], "Segoe UI", 14.5f, FontStyle.Regular, Muted, x, 137, 178, 102, StringAlignment.Near);
                    if (i < 3) using (Pen pen = new Pen(Color.FromArgb(125, Hairline), 1f)) g.DrawLine(pen, x + 190, 89, x + 190, 230);
                }
            });
        }
    }

    public static void BuildContactHeading(string outputPath, string stockPath) {
        using (Image stock = Image.FromFile(stockPath)) {
            Render(outputPath, Width, 70, delegate(Graphics g, float t) {
                Base(g, stock, 70);
                SectionTitle(g, "Contact", 14, 204);
            });
        }
    }

    public static void BuildContactLink(string outputPath, string stockPath, string label, int phase) {
        using (Image stock = Image.FromFile(stockPath)) {
            Render(outputPath, 240, 56, delegate(Graphics g, float t) {
                g.Clear(Bone);
                DrawCrop(g, stock, new Rectangle(0, 0, 240, 56), 0.5f, 0.5f);
                Rule(g, 8, 8, 232, Hairline, 0.8f);
                Text(g, label, "Bahnschrift", 18f, FontStyle.Bold, Ink, 16, 16, 198, 26, StringAlignment.Near);
                int left = 16 + (int)(t * 42f);
                Rule(g, 16, 46, left, Accent, 3f + ((phase + t) % 1f) * 0.35f);
                Rule(g, 8, 53, 232, Hairline, 0.8f);
            });
        }
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies 'System.Drawing'

$assetDir = Join-Path $PSScriptRoot 'assets\industrial'
$stock = Join-Path $assetDir 'industrial-stock-bg.jpg'
$matrix = Join-Path $PSScriptRoot 'real_contrib_matrix.txt'

[IndustrialProfileRenderer]::BuildHero((Join-Path $assetDir 'hero.gif'), (Join-Path $assetDir 'cover-track-bg.jpg'))
[IndustrialProfileRenderer]::BuildProjects((Join-Path $assetDir 'projects.gif'), $stock, (Join-Path $assetDir 'facetrack-profile-bg.jpg'), (Join-Path $assetDir 'skillguard-gate-bg.jpg'), (Join-Path $assetDir 'rootcause-origin-bg.jpg'))
[IndustrialProfileRenderer]::BuildDomains((Join-Path $assetDir 'domains.gif'), $stock)
[IndustrialProfileRenderer]::BuildContributions((Join-Path $assetDir 'contributions.gif'), $stock, $matrix)
[IndustrialProfileRenderer]::BuildToolkit((Join-Path $assetDir 'toolkit.gif'), $stock)
[IndustrialProfileRenderer]::BuildContactHeading((Join-Path $assetDir 'contact-heading.gif'), $stock)
[IndustrialProfileRenderer]::BuildContactLink((Join-Path $assetDir 'contact-github.gif'), $stock, 'GitHub', 0)
[IndustrialProfileRenderer]::BuildContactLink((Join-Path $assetDir 'contact-linkedin.gif'), $stock, 'LinkedIn', 1)
[IndustrialProfileRenderer]::BuildContactLink((Join-Path $assetDir 'contact-email.gif'), $stock, 'Email', 2)

Get-ChildItem -LiteralPath $assetDir -Filter '*.gif' | Select-Object Name, @{n='KB';e={[math]::Round($_.Length / 1KB, 1)}}
