using System.Text.Json;
using System.Text.RegularExpressions;

namespace Configurator;

public static class JsonTokenResolver
{
    /// <summary>
    /// Recursively searches <paramref name="startDir"/> and its subdirectories for the given
    /// <paramref name="relativePath"/>, reads the specified <paramref name="fileName"/> from it,
    /// navigates to the JSON property at <paramref name="jsonPath"/>, and extracts the first
    /// match of <paramref name="pattern"/> (returning the first capture group, or the full match
    /// if no groups are defined).
    /// </summary>
    /// <param name="startDir">Root directory to start the recursive search from.</param>
    /// <param name="relativePath">Relative directory path to look for (e.g. "dir1/dir2/dir3").</param>
    /// <param name="fileName">JSON file name to read (e.g. "package.json").</param>
    /// <param name="jsonPath">Slash-separated path to the JSON property (e.g. "scripts/start").</param>
    /// <param name="pattern">Regex pattern to match against the property value. If the pattern contains
    /// a capture group, the first group's value is returned; otherwise the full match is returned.</param>
    /// <returns>The matched value, or <c>null</c> if not found.</returns>
    public static string? Resolve(string startDir, string relativePath, string fileName, string jsonPath, string pattern)
    {
        var root = new DirectoryInfo(startDir);

        foreach (var dir in EnumerateDirectoriesRecursive(root))
        {
            var candidate = Path.Combine(dir.FullName, relativePath);

            if (Directory.Exists(candidate))
            {
                var filePath = Path.Combine(candidate, fileName);

                if (!File.Exists(filePath))
                    continue;

                return ExtractValue(File.ReadAllText(filePath), jsonPath, pattern);
            }
        }

        return null;
    }

    private static IEnumerable<DirectoryInfo> EnumerateDirectoriesRecursive(DirectoryInfo root)
    {
        yield return root;

        DirectoryInfo[] children;

        try
        {
            children = root.GetDirectories();
        }
        catch (UnauthorizedAccessException)
        {
            yield break;
        }

        foreach (var child in children)
        {
            foreach (var descendant in EnumerateDirectoriesRecursive(child))
                yield return descendant;
        }
    }

    internal static string? ExtractValue(string jsonContent, string jsonPath, string pattern)
    {
        using var doc = JsonDocument.Parse(jsonContent);

        var segments = jsonPath.Split('/');
        var current = doc.RootElement;

        foreach (var segment in segments)
        {
            if (!current.TryGetProperty(segment, out current))
                return null;
        }

        var value = current.GetString();

        if (value is null)
            return null;

        var match = Regex.Match(value, pattern);

        if (!match.Success)
            return null;

        return match.Groups.Count > 1 ? match.Groups[1].Value : match.Value;
    }
}
