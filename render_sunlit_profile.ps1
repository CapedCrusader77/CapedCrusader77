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

public static class SunlitProfileRenderer {
    const int Frames = 12;
    const int DelayMs = 90;
    const int Width = 840;
    static readonly Color Paper = Color.FromArgb(255, 247, 232);
    static readonly Color Ink = Color.FromArgb(28, 26, 23);
    static readonly Color Muted = Color.FromArgb(92, 77, 59);
    static readonly Color Sun = Color.FromArgb(255, 211, 61);
    static readonly Color Coral = Color.FromArgb(242, 84, 54);
    static readonly Color RuleColor = Color.FromArgb(155, 105, 84, 59);

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

    static void Background(Graphics g, Image image, int width, int height, float pan, float focusY) {
        g.Clear(Paper);
        DrawCrop(g, image, new Rectangle(0, 0, width, height), 0.5f + pan, focusY);
    }

    static void Text(Graphics g, string value, string face, float size, FontStyle style, Color color,
                     float x, float y, float width, float height, StringAlignment alignment) {
        using (Font font = new Font(face, size, style, GraphicsUnit.Pixel))
        using (SolidBrush brush = new SolidBrush(color))
        using (StringFormat format = new StringFormat()) {
            format.Alignment = alignment;
            format.LineAlignment = StringAlignment.Near;
            format.Trimming = StringTrimming.Word;
            format.FormatFlags = StringFormatFlags.LineLimit;
            g.DrawString(value, font, brush, new RectangleF(x, y, width, height), format);
        }
    }

    static void Tracked(Graphics g, string value, string face, float size, FontStyle style,
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

    static void SectionTitle(Graphics g, string title, int number, float t) {
        using (SolidBrush brush = new SolidBrush(Coral)) g.FillRectangle(brush, 32, 20, 5, 29);
        Text(g, title, "Georgia", 27f, FontStyle.Bold, Ink, 49, 16, 400, 38, StringAlignment.Near);
        Tracked(g, number.ToString("00"), "Consolas", 10.5f, FontStyle.Bold, Muted, 771, 23, 1.1f);
        float pulse = 150f + 26f * (float)Math.Sin(t * Math.PI * 2.0);
        Rule(g, 49, 57, 49 + pulse, Sun, 3f);
        Rule(g, 49 + pulse + 12, 58, 808, RuleColor, 1f);
    }

    static void Panel(Graphics g, Rectangle rect, int alpha) {
        using (SolidBrush brush = new SolidBrush(Color.FromArgb(alpha, Paper))) g.FillRectangle(brush, rect);
        using (Pen pen = new Pen(Color.FromArgb(115, 126, 91, 60), 1f)) g.DrawRectangle(pen, rect);
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
                            0x21,0xFF,0x0B,
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
                    drawFrame(g, (float)i / Frames);
                }
                frames[i] = bmp;
            }
            SaveGif(outputPath, frames, DelayMs);
        } finally {
            for (int i = 0; i < frames.Length; i++) if (frames[i] != null) frames[i].Dispose();
        }
    }

    public static void BuildHero(string outputPath, string backgroundPath) {
        using (Image art = Image.FromFile(backgroundPath)) {
            Render(outputPath, Width, 350, delegate(Graphics g, float t) {
                float pan = 0.025f * (float)Math.Sin(t * Math.PI * 2.0);
                Background(g, art, Width, 350, pan, 0.5f);
                Tracked(g, "ENGINEERING  /  COMPUTER VISION  /  TOOLING", "Consolas", 11.5f, FontStyle.Bold, Muted, 38, 25, 0.85f);
                Rule(g, 38, 49, 800, RuleColor, 1f);
                float nameX = 39f;
                float nameY = 74f;
                using (Font nameFont = new Font("Georgia", 78f, FontStyle.Bold, GraphicsUnit.Pixel))
                using (SolidBrush nameBrush = new SolidBrush(Ink)) {
                    g.DrawString("GOKUL", nameFont, nameBrush, nameX, nameY);
                    float initialX = nameX + g.MeasureString("GOKUL", nameFont).Width + 2f;
                    float initialWidth = g.MeasureString("A.", nameFont).Width + 10f;
                    using (SolidBrush highlight = new SolidBrush(Sun))
                        g.FillRectangle(highlight, initialX, 84f, initialWidth, 70f);
                    g.DrawString("A.", nameFont, nameBrush, initialX + 5f, nameY);
                }
                float pulse = 278f + 14f * (float)Math.Sin(t * Math.PI * 2.0);
                using (SolidBrush brush = new SolidBrush(Coral)) g.FillRectangle(brush, 39, 174, pulse, 7);
                Text(g, "I build systems whose decisions can be followed\u2014and whose failure modes stay visible.",
                     "Segoe UI", 21f, FontStyle.Regular, Ink, 39, 204, 470, 72, StringAlignment.Near);
                Text(g, "github.com/CapedCrusader77", "Consolas", 14.5f, FontStyle.Bold, Ink, 40, 305, 450, 23, StringAlignment.Near);
                using (SolidBrush dot = new SolidBrush(Coral)) g.FillEllipse(dot, 14 + 8 * (float)Math.Sin(t * Math.PI * 2.0), 27, 7, 7);
            });
        }
    }

    public static void BuildProjects(string outputPath, string backgroundPath, string siegePath, string guardPath, string rootPath) {
        using (Image section = Image.FromFile(backgroundPath))
        using (Image siege = Image.FromFile(siegePath))
        using (Image guard = Image.FromFile(guardPath))
        using (Image root = Image.FromFile(rootPath)) {
            Render(outputPath, Width, 430, delegate(Graphics g, float t) {
                float pan = 0.008f * (float)Math.Sin(t * Math.PI * 2.0);
                Background(g, section, Width, 430, pan, 0.5f);
                SectionTitle(g, "Selected builds", 1, t);
                string[] names = { "SIEGE", "SkillGuard-OSS", "RootCause-IQ" };
                string[] descriptions = {
                    "Runs scripted attack scenarios and streams firewall/IDS responses to a live dashboard.",
                    "Uses static AST inspection to find excessive capabilities and supply-chain risk.",
                    "Reconstructs distributed traces to locate the event that triggered downstream failures."
                };
                string[] stacks = {
                    "FastAPI  /  React  /  WebSockets  /  D3",
                    "TypeScript  /  AST  /  Security",
                    "Python  /  OpenTelemetry  /  Causal AI"
                };
                Image[] art = { siege, guard, root };
                int[] xs = { 32, 300, 568 };
                for (int i = 0; i < 3; i++) {
                    int x = xs[i];
                    Panel(g, new Rectangle(x, 77, 240, 330), 244);
                    float drift = 0.018f * (float)Math.Sin((t + i * 0.07f) * Math.PI * 2.0);
                    DrawCrop(g, art[i], new Rectangle(x + 1, 78, 238, 112), 0.52f + drift, 0.63f);
                    using (SolidBrush tag = new SolidBrush(i == 1 ? Coral : Sun)) g.FillRectangle(tag, x + 14, 202, 29, 4);
                    Text(g, names[i], "Georgia", 19f, FontStyle.Bold, Ink, x + 14, 211, 214, 28, StringAlignment.Near);
                    Text(g, descriptions[i], "Segoe UI", 14f, FontStyle.Regular, Ink, x + 14, 249, 212, 63, StringAlignment.Near);
                    Rule(g, x + 14, 320, x + 226, RuleColor, 1f);
                    Text(g, stacks[i], "Consolas", 11f, FontStyle.Regular, Muted, x + 14, 331, 212, 48, StringAlignment.Near);
                    if (i < 2) {
                        using (SolidBrush bead = new SolidBrush(Coral)) g.FillEllipse(bead, x + 252, 84, 4, 4);
                    }
                }
            });
        }
    }

    public static void BuildDomains(string outputPath, string backgroundPath) {
        using (Image art = Image.FromFile(backgroundPath)) {
            Render(outputPath, Width, 224, delegate(Graphics g, float t) {
                Background(g, art, Width, 224, 0.012f * (float)Math.Sin(t * Math.PI * 2.0), 0.72f);
                SectionTitle(g, "Core domains", 2, t);
                string[] names = { "Computer vision", "AI agents", "Systems security" };
                string[] descriptions = {
                    "Landmark geometry, gaze estimation, and real-time visual pipelines.",
                    "Tool routing, multi-agent workflows, and inspectable decisions.",
                    "AST analysis, capability audits, and sandboxed runtimes."
                };
                int[] xs = { 32, 300, 568 };
                for (int i = 0; i < 3; i++) {
                    int x = xs[i];
                    Panel(g, new Rectangle(x, 78, 240, 125), 226);
                    Text(g, names[i], "Georgia", 19f, FontStyle.Bold, Ink, x + 14, 91, 214, 30, StringAlignment.Near);
                    using (SolidBrush accent = new SolidBrush(i == 1 ? Coral : Sun)) g.FillRectangle(accent, x + 14, 127, 32, 4);
                    Text(g, descriptions[i], "Segoe UI", 13.7f, FontStyle.Regular, Ink, x + 14, 143, 212, 53, StringAlignment.Near);
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

    public static void BuildContributions(string outputPath, string backgroundPath, string matrixPath) {
        int activeWeeks;
        int[,] grid = ReadContributionMatrix(matrixPath, out activeWeeks);
        if (activeWeeks != 23) throw new InvalidDataException("Expected 23 active weeks in the current 2026 snapshot, found " + activeWeeks);
        using (Image art = Image.FromFile(backgroundPath)) {
            Render(outputPath, Width, 224, delegate(Graphics g, float t) {
                Background(g, art, Width, 224, 0.012f * (float)Math.Sin(t * Math.PI * 2.0), 0.55f);
                SectionTitle(g, "Contributions", 3, t);
                Text(g, "361", "Georgia", 53f, FontStyle.Bold, Ink, 35, 77, 154, 60, StringAlignment.Near);
                Text(g, "2026 CONTRIBUTIONS", "Consolas", 10f, FontStyle.Bold, Muted, 39, 137, 152, 17, StringAlignment.Near);
                Text(g, "23", "Georgia", 53f, FontStyle.Bold, Ink, 215, 77, 100, 60, StringAlignment.Near);
                Text(g, "ACTIVE WEEKS", "Consolas", 10f, FontStyle.Bold, Muted, 219, 137, 130, 17, StringAlignment.Near);
                Panel(g, new Rectangle(320, 75, 488, 115), 226);

                int gridX = 332, gridY = 108, cell = 7, gap = 2, step = cell + gap;
                string[] months = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" };
                DateTime calendarStart = new DateTime(2025, 12, 28);
                using (Font monthFont = new Font("Consolas", 8.2f, GraphicsUnit.Pixel))
                using (SolidBrush monthBrush = new SolidBrush(Muted)) {
                    for (int m = 0; m < months.Length; m++) {
                        DateTime monthStart = new DateTime(2026, m + 1, 1);
                        int week = (int)(monthStart - calendarStart).TotalDays / 7;
                        float mx = gridX + week * step;
                        g.DrawString(months[m], monthFont, monthBrush, mx, 91);
                    }
                }
                Color[] levels = {
                    Color.FromArgb(241, 229, 210),
                    Color.FromArgb(255, 204, 153),
                    Color.FromArgb(255, 157, 99),
                    Color.FromArgb(242, 105, 66),
                    Color.FromArgb(196, 58, 35)
                };
                for (int w = 0; w < 53; w++) {
                    for (int d = 0; d < 7; d++) {
                        int x = gridX + w * step;
                        int y = gridY + d * step;
                        using (SolidBrush brush = new SolidBrush(levels[grid[w, d]])) g.FillRectangle(brush, x, y, cell, cell);
                    }
                }
                int focusWeek = (int)(t * 53f) % 53;
                using (SolidBrush marker = new SolidBrush(Coral)) g.FillRectangle(marker, gridX + focusWeek * step, gridY - 8, cell, 4);
                Text(g, "GITHUB PROFILE  /  THROUGH 25 SEP 2026", "Consolas", 9.2f, FontStyle.Bold, Muted, 368, 174, 420, 14, StringAlignment.Near);
            });
        }
    }

    public static void BuildToolkit(string outputPath, string backgroundPath) {
        using (Image art = Image.FromFile(backgroundPath)) {
            Render(outputPath, Width, 246, delegate(Graphics g, float t) {
                Background(g, art, Width, 246, 0.012f * (float)Math.Sin(t * Math.PI * 2.0), 0.73f);
                SectionTitle(g, "Technical toolkit", 4, t);
                string[] headings = { "Languages", "ML & vision", "Security", "Web & platforms" };
                string[] lists = {
                    "Python\nTypeScript\nJavaScript\nPowerShell / Bash",
                    "PyTorch\nTensorFlow\nscikit-learn\nOpenCV / NumPy\npandas",
                    "AST analysis\nCapability auditing\nSandboxed runtimes",
                    "React / Next.js\nNode.js / REST\nWebSockets\nGit / CI"
                };
                int[] xs = { 32, 232, 432, 632 };
                for (int i = 0; i < 4; i++) {
                    int x = xs[i];
                    Panel(g, new Rectangle(x, 78, 176, 152), 231);
                    float headingSize = i == 3 ? 15.2f : 17.3f;
                    Text(g, headings[i], "Georgia", headingSize, FontStyle.Bold, Ink, x + 12, 90, 152, 27, StringAlignment.Near);
                    using (SolidBrush accent = new SolidBrush(i == 2 ? Coral : Sun)) g.FillRectangle(accent, x + 12, 120, 29, 4);
                    Text(g, lists[i], "Segoe UI", 13.7f, FontStyle.Regular, Ink, x + 12, 134, 152, 89, StringAlignment.Near);
                }
            });
        }
    }

    public static void BuildContactHeading(string outputPath, string backgroundPath) {
        using (Image art = Image.FromFile(backgroundPath)) {
            Render(outputPath, Width, 74, delegate(Graphics g, float t) {
                Background(g, art, Width, 74, 0f, 0.12f);
                Text(g, "Find me around the web", "Georgia", 27f, FontStyle.Bold, Ink, 34, 17, 520, 40, StringAlignment.Near);
                float pulse = 84f + 23f * (float)Math.Sin(t * Math.PI * 2.0);
                using (SolidBrush brush = new SolidBrush(Coral)) g.FillRectangle(brush, 36, 58, pulse, 4);
            });
        }
    }

    public static void BuildContactLink(string outputPath, string backgroundPath, string label, string detail, int index) {
        using (Image art = Image.FromFile(backgroundPath)) {
            Render(outputPath, 260, 66, delegate(Graphics g, float t) {
                DrawCrop(g, art, new Rectangle(0, 0, 260, 66), 0.5f, 0.08f);
                using (SolidBrush wash = new SolidBrush(Color.FromArgb(224, Paper))) g.FillRectangle(wash, 5, 5, 250, 56);
                using (Pen border = new Pen(Color.FromArgb(190, Ink), 1.2f)) g.DrawRectangle(border, 5, 5, 250, 56);
                using (SolidBrush mark = new SolidBrush(index == 1 ? Coral : Sun)) g.FillRectangle(mark, 17, 17, 9, 30);
                Text(g, label, "Georgia", 17.5f, FontStyle.Bold, Ink, 36, 12, 200, 23, StringAlignment.Near);
                Text(g, detail, "Consolas", 9.5f, FontStyle.Regular, Muted, 37, 36, 205, 16, StringAlignment.Near);
                float sweep = 31f + 14f * (float)Math.Sin((t + index * 0.11f) * Math.PI * 2.0);
                using (SolidBrush underline = new SolidBrush(Coral)) g.FillRectangle(underline, 37, 55, sweep, 2);
            });
        }
    }
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies 'System.Drawing'

$assetDir = Join-Path $PSScriptRoot 'assets\sunlit'
$matrix = Join-Path $PSScriptRoot 'real_contrib_matrix_2026.txt'
[SunlitProfileRenderer]::BuildHero((Join-Path $assetDir 'hero.gif'), (Join-Path $assetDir 'hero-bg.jpg'))
[SunlitProfileRenderer]::BuildProjects((Join-Path $assetDir 'projects.gif'), (Join-Path $assetDir 'projects-bg.jpg'), (Join-Path $assetDir 'siege-bg.jpg'), (Join-Path $assetDir 'skillguard-bg.jpg'), (Join-Path $assetDir 'rootcause-bg.jpg'))
[SunlitProfileRenderer]::BuildDomains((Join-Path $assetDir 'domains.gif'), (Join-Path $assetDir 'domains-bg.jpg'))
[SunlitProfileRenderer]::BuildContributions((Join-Path $assetDir 'contributions.gif'), (Join-Path $assetDir 'contributions-bg.jpg'), $matrix)
[SunlitProfileRenderer]::BuildToolkit((Join-Path $assetDir 'toolkit.gif'), (Join-Path $assetDir 'toolkit-bg.jpg'))
[SunlitProfileRenderer]::BuildContactHeading((Join-Path $assetDir 'contact-heading.gif'), (Join-Path $assetDir 'contact-bg.jpg'))
[SunlitProfileRenderer]::BuildContactLink((Join-Path $assetDir 'contact-github.gif'), (Join-Path $assetDir 'contact-bg.jpg'), 'GitHub', 'CapedCrusader77', 0)
[SunlitProfileRenderer]::BuildContactLink((Join-Path $assetDir 'contact-linkedin.gif'), (Join-Path $assetDir 'contact-bg.jpg'), 'LinkedIn', 'Gokul A.', 1)
[SunlitProfileRenderer]::BuildContactLink((Join-Path $assetDir 'contact-email.gif'), (Join-Path $assetDir 'contact-bg.jpg'), 'Email', '25f2008464@ds.study.iitm.ac.in', 2)

Get-ChildItem -LiteralPath $assetDir -Filter '*.gif' | Select-Object Name, @{n='KB';e={[math]::Round($_.Length / 1KB, 1)}}
