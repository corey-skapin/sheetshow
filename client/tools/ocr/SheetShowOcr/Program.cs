using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Data.Pdf;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage;
using Windows.Storage.Streams;

// SheetShowOcr — CLI tool for OCR using Windows built-in APIs.
//
// Usage:
//   SheetShowOcr.exe <image-path>              — OCR a PNG/JPG image
//   SheetShowOcr.exe <pdf-path> <page-number>  — Render a PDF page then OCR it
//
// Outputs recognized text to stdout. OCR fragments that share the same
// vertical position are merged into a single line (handles two-column layouts).

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: SheetShowOcr <image-path>");
    Console.Error.WriteLine("       SheetShowOcr <pdf-path> <page-number>");
    return 1;
}

try
{
    SoftwareBitmap bitmap;

    if (args.Length >= 2 && int.TryParse(args[1], out int pageNumber))
    {
        // PDF mode: render the specified page (1-indexed).
        bitmap = await RenderPdfPage(args[0], pageNumber);
    }
    else
    {
        // Image mode: load from file.
        bitmap = await LoadImage(args[0]);
    }

    // Apply Otsu binarization for better handwritten text recognition.
    bitmap = EnhanceForOcr(bitmap);

    var engine = OcrEngine.TryCreateFromUserProfileLanguages();
    if (engine == null)
    {
        Console.Error.WriteLine("Failed to create OCR engine");
        return 1;
    }

    var result = await engine.RecognizeAsync(bitmap);

    // Work at the WORD level to detect column layouts. The OCR engine
    // may merge words from both columns into a single line, so we must
    // examine individual word bounding boxes to find the column gap.
    var words = new List<(double x, double xEnd, double y, string text)>();
    foreach (var line in result.Lines)
    {
        foreach (var word in line.Words)
        {
            double yCenter = word.BoundingRect.Y + word.BoundingRect.Height / 2;
            words.Add((word.BoundingRect.X,
                        word.BoundingRect.X + word.BoundingRect.Width,
                        yCenter,
                        word.Text));
        }
    }

    if (words.Count == 0)
    {
        Console.Write("");
        return 0;
    }

    double pageWidth = bitmap.PixelWidth;
    // Tight tolerance to avoid merging adjacent text rows.
    // For a ~2600px tall page with ~35 index rows, each row is ~75px.
    // 0.6% ≈ 16px — enough for same-line word alignment but not adjacent rows.
    double rowTolerance = bitmap.PixelHeight * 0.006;

    // Detect column layout by finding a vertical strip in the middle of the
    // page where no word's bounding box overlaps. Using full word occupancy
    // (not just centers) prevents splitting inside a column where page numbers
    // sit far from their titles.
    // Words that are purely dots/punctuation (dot leaders) are excluded from
    // gap detection since they often span between columns in index layouts.
    double splitX = -1;
    {
        int bucketCount = 200;
        double bucketWidth = pageWidth / bucketCount;
        var occupied = new int[bucketCount];
        foreach (var w in words)
        {
            // Skip dot leaders and pure punctuation — they span the gap.
            if (w.text.All(c => c == '.' || c == ',' || c == ' ' || c == '\u2026'))
                continue;
            int startB = Math.Max(0, (int)(w.x / bucketWidth));
            int endB = Math.Min(bucketCount - 1, (int)(w.xEnd / bucketWidth));
            for (int b = startB; b <= endB; b++)
                occupied[b]++;
        }

        // Find the widest run of empty buckets in the middle 30%-70% of page.
        int minBucket = (int)(0.30 * bucketCount);
        int maxBucket = (int)(0.70 * bucketCount);
        int bestRunStart = -1, bestRunLen = 0;
        int runStart = -1, runLen = 0;
        for (int b = minBucket; b <= maxBucket; b++)
        {
            if (occupied[b] == 0)
            {
                if (runStart < 0) runStart = b;
                runLen = b - runStart + 1;
            }
            else
            {
                if (runLen > bestRunLen) { bestRunLen = runLen; bestRunStart = runStart; }
                runStart = -1; runLen = 0;
            }
        }
        if (runLen > bestRunLen) { bestRunLen = runLen; bestRunStart = runStart; }

        // Need a gap of at least 2% of page width (~4 buckets at 200) to
        // declare two columns.
        if (bestRunLen >= 4)
        {
            splitX = (bestRunStart + bestRunLen / 2.0) * bucketWidth;
        }
    }

    // Assign words to columns and assemble lines within each column.
    List<string> assembleColumn(List<(double x, double xEnd, double y, string text)> colWords)
    {
        if (colWords.Count == 0) return new List<string>();
        colWords.Sort((a, b) => { int yc = a.y.CompareTo(b.y); return yc != 0 ? yc : a.x.CompareTo(b.x); });

        var lines = new List<string>();
        int idx = 0;
        while (idx < colWords.Count)
        {
            double rowY = colWords[idx].y;
            var row = new List<(double x, string text)> { (colWords[idx].x, colWords[idx].text) };
            int next = idx + 1;
            while (next < colWords.Count && Math.Abs(colWords[next].y - rowY) <= rowTolerance)
            {
                row.Add((colWords[next].x, colWords[next].text));
                next++;
            }
            row.Sort((a, b) => a.x.CompareTo(b.x));
            lines.Add(string.Join(" ", row.Select(r => r.text)));
            idx = next;
        }
        return lines;
    }

    var mergedLines = new List<string>();
    if (splitX > 0)
    {
        var leftWords = words.Where(w => w.xEnd <= splitX || w.x < splitX && (w.x + w.xEnd) / 2 < splitX).ToList();
        var rightWords = words.Where(w => w.x >= splitX || w.xEnd > splitX && (w.x + w.xEnd) / 2 >= splitX).ToList();
        mergedLines.AddRange(assembleColumn(leftWords));
        mergedLines.AddRange(assembleColumn(rightWords));
    }
    else
    {
        mergedLines.AddRange(assembleColumn(words));
    }

    Console.Write(string.Join("\n", mergedLines));
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"OCR error: {ex.Message}");
    return 1;
}

static async Task<SoftwareBitmap> LoadImage(string imagePath)
{
    if (!File.Exists(imagePath))
        throw new FileNotFoundException($"File not found: {imagePath}");

    var bytes = await File.ReadAllBytesAsync(imagePath);
    var stream = new InMemoryRandomAccessStream();
    await stream.WriteAsync(bytes.AsBuffer());
    stream.Seek(0);
    var decoder = await BitmapDecoder.CreateAsync(stream);
    return await decoder.GetSoftwareBitmapAsync(
        BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied);
}

static async Task<SoftwareBitmap> RenderPdfPage(string pdfPath, int pageNumber)
{
    if (!File.Exists(pdfPath))
        throw new FileNotFoundException($"PDF not found: {pdfPath}");

    var file = await StorageFile.GetFileFromPathAsync(Path.GetFullPath(pdfPath));
    var pdfDoc = await PdfDocument.LoadFromFileAsync(file);

    if (pageNumber < 1 || pageNumber > (int)pdfDoc.PageCount)
        throw new ArgumentException(
            $"Page {pageNumber} out of range (1-{pdfDoc.PageCount})");

    using var page = pdfDoc.GetPage((uint)(pageNumber - 1));

    // Render at high resolution for OCR quality.
    var renderStream = new InMemoryRandomAccessStream();
    var options = new PdfPageRenderOptions
    {
        DestinationWidth = 2000
    };
    await page.RenderToStreamAsync(renderStream, options);
    renderStream.Seek(0);

    var decoder = await BitmapDecoder.CreateAsync(renderStream);
    return await decoder.GetSoftwareBitmapAsync(
        BitmapPixelFormat.Bgra8, BitmapAlphaMode.Premultiplied);
}

static SoftwareBitmap EnhanceForOcr(SoftwareBitmap bitmap)
{
    int pixelCount = bitmap.PixelWidth * bitmap.PixelHeight;
    int byteCount = pixelCount * 4;
    var buffer = new Windows.Storage.Streams.Buffer((uint)byteCount);
    bitmap.CopyToBuffer(buffer);
    byte[] pixels = buffer.ToArray();

    var histogram = new int[256];
    for (int i = 0; i < pixels.Length; i += 4)
    {
        int b = pixels[i], g = pixels[i + 1], r = pixels[i + 2];
        int gray = (r * 299 + g * 587 + b * 114) / 1000;
        histogram[gray]++;
    }

    int threshold = OtsuThreshold(histogram, pixelCount);

    for (int i = 0; i < pixels.Length; i += 4)
    {
        int b = pixels[i], g = pixels[i + 1], r = pixels[i + 2];
        int gray = (r * 299 + g * 587 + b * 114) / 1000;
        byte val = (byte)(gray < threshold ? 0 : 255);
        pixels[i] = val;
        pixels[i + 1] = val;
        pixels[i + 2] = val;
    }

    bitmap.CopyFromBuffer(pixels.AsBuffer());
    return bitmap;
}

static int OtsuThreshold(int[] histogram, int totalPixels)
{
    long sumTotal = 0;
    for (int i = 0; i < 256; i++) sumTotal += i * (long)histogram[i];

    long sumBackground = 0;
    int weightBackground = 0;
    double maxVariance = 0;
    int bestThreshold = 128;

    for (int t = 0; t < 256; t++)
    {
        weightBackground += histogram[t];
        if (weightBackground == 0) continue;
        int weightForeground = totalPixels - weightBackground;
        if (weightForeground == 0) break;

        sumBackground += t * (long)histogram[t];
        double meanBg = (double)sumBackground / weightBackground;
        double meanFg = (double)(sumTotal - sumBackground) / weightForeground;
        double variance = (double)weightBackground * weightForeground *
                          (meanBg - meanFg) * (meanBg - meanFg);

        if (variance > maxVariance)
        {
            maxVariance = variance;
            bestThreshold = t;
        }
    }
    return bestThreshold;
}
