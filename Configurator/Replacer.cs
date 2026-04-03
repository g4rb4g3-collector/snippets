using System.Text.RegularExpressions;

namespace Configurator;

public static partial class Replacer
{
    /// <summary>
    /// Reads <paramref name="templatePath"/>, replaces all <c>{{token}}</c> placeholders
    /// with values from <paramref name="tokens"/>, and writes the result to a new file
    /// with <c>_rendered</c> suffix (e.g. <c>template.json</c> → <c>template_rendered.json</c>).
    /// </summary>
    /// <param name="templatePath">Path to the template JSON file.</param>
    /// <param name="tokens">Dictionary mapping token names to replacement values.</param>
    /// <returns>The path to the rendered output file.</returns>
    public static string Render(string templatePath, IDictionary<string, string> tokens)
    {
        var content = File.ReadAllText(templatePath);

        var rendered = TokenPattern().Replace(content, match =>
        {
            var token = match.Groups[1].Value;
            return tokens.TryGetValue(token, out var value) ? value : match.Value;
        });

        var directory = Path.GetDirectoryName(templatePath) ?? ".";
        var name = Path.GetFileNameWithoutExtension(templatePath);
        var extension = Path.GetExtension(templatePath);
        var outputPath = Path.Combine(directory, $"{name}_rendered{extension}");

        File.WriteAllText(outputPath, rendered);

        return outputPath;
    }

    [GeneratedRegex(@"\{\{(\w+)\}\}")]
    private static partial Regex TokenPattern();
}
