using System.Text.Json;
using System.Text.RegularExpressions;

namespace Configurator;

public static partial class PortResolver
{
    /// <summary>
    /// Searches ancestor directories starting from <paramref name="startDir"/> for the given
    /// <paramref name="relativePath"/>, reads <c>package.json</c> from it, and extracts the
    /// <c>--port</c> value from the <c>scripts.start</c> entry.
    /// </summary>
    /// <returns>The port number as a string, or <c>null</c> if not found.</returns>
    public static string? ResolvePort(string startDir, string relativePath)
    {
        var current = new DirectoryInfo(startDir);

        while (current is not null)
        {
            var candidate = Path.Combine(current.FullName, relativePath);

            if (Directory.Exists(candidate))
            {
                var packageJsonPath = Path.Combine(candidate, "package.json");

                if (!File.Exists(packageJsonPath))
                    return null;

                return ExtractPort(File.ReadAllText(packageJsonPath));
            }

            current = current.Parent;
        }

        return null;
    }

    internal static string? ExtractPort(string packageJsonContent)
    {
        using var doc = JsonDocument.Parse(packageJsonContent);

        if (!doc.RootElement.TryGetProperty("scripts", out var scripts))
            return null;

        if (!scripts.TryGetProperty("start", out var startScript))
            return null;

        var startValue = startScript.GetString();

        if (startValue is null)
            return null;

        var match = PortPattern().Match(startValue);
        return match.Success ? match.Groups[1].Value : null;
    }

    [GeneratedRegex(@"--port\s+(\d+)")]
    private static partial Regex PortPattern();
}
