using System.Text.Json;
using System.Text.RegularExpressions;

var searchPath = args.Length > 0 ? args[0] : null;

if (string.IsNullOrWhiteSpace(searchPath))
{
    Console.Error.WriteLine("Usage: Configurator <relative-path>");
    Console.Error.WriteLine("  Example: Configurator dir1/dir2/dir3");
    return 1;
}

var startDir = Path.GetDirectoryName(AppContext.BaseDirectory)!;
var port = FindPort(startDir, searchPath);

if (port is null)
{
    Console.Error.WriteLine($"Could not resolve port from path '{searchPath}'.");
    return 1;
}

Console.WriteLine(port);
return 0;

static string? FindPort(string startDir, string searchPath)
{
    var current = new DirectoryInfo(startDir);

    while (current is not null)
    {
        var candidate = Path.Combine(current.FullName, searchPath);

        if (Directory.Exists(candidate))
        {
            var packageJson = Path.Combine(candidate, "package.json");

            if (File.Exists(packageJson))
            {
                return ExtractPort(packageJson);
            }

            Console.Error.WriteLine($"Found '{searchPath}' at '{candidate}' but no package.json inside.");
            return null;
        }

        current = current.Parent;
    }

    Console.Error.WriteLine($"Path '{searchPath}' not found in any ancestor directory starting from '{startDir}'.");
    return null;
}

static string? ExtractPort(string packageJsonPath)
{
    var json = File.ReadAllText(packageJsonPath);
    using var doc = JsonDocument.Parse(json);

    if (!doc.RootElement.TryGetProperty("scripts", out var scripts))
    {
        Console.Error.WriteLine("No 'scripts' section found in package.json.");
        return null;
    }

    if (!scripts.TryGetProperty("start", out var startScript))
    {
        Console.Error.WriteLine("No 'start' script found in scripts section.");
        return null;
    }

    var startValue = startScript.GetString();

    if (startValue is null)
    {
        Console.Error.WriteLine("'start' script value is null.");
        return null;
    }

    var match = Regex.Match(startValue, @"--port\s+(\d+)");

    if (!match.Success)
    {
        Console.Error.WriteLine($"No '--port' argument found in start script: {startValue}");
        return null;
    }

    return match.Groups[1].Value;
}
