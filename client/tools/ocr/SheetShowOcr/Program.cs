using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Graphics.Imaging;
using Windows.Media.Ocr;
using Windows.Storage.Streams;

// SheetShowOcr — minimal CLI tool that runs Windows built-in OCR on a PNG image.
// Usage: SheetShowOcr.exe <image-path>
// Outputs recognized text to stdout.

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: SheetShowOcr <image-path>");
    return 1;
}

var imagePath = args[0];
if (!File.Exists(imagePath))
{
    Console.Error.WriteLine($"File not found: {imagePath}");
    return 1;
}

try
{
    var bytes = await File.ReadAllBytesAsync(imagePath);
    var stream = new InMemoryRandomAccessStream();
    await stream.WriteAsync(bytes.AsBuffer());
    stream.Seek(0);

    var decoder = await BitmapDecoder.CreateAsync(stream);
    var bitmap = await decoder.GetSoftwareBitmapAsync();

    var engine = OcrEngine.TryCreateFromUserProfileLanguages();
    if (engine == null)
    {
        Console.Error.WriteLine("Failed to create OCR engine");
        return 1;
    }

    var result = await engine.RecognizeAsync(bitmap);
    Console.Write(result.Text);
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"OCR error: {ex.Message}");
    return 1;
}
