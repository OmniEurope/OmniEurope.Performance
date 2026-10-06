// SPDX-License-Identifier: EUPL-1.2
using System.Globalization;
using Bunit;
using Microsoft.Extensions.DependencyInjection;
using OmniEurope.Performance.Components;

namespace OmniEurope.Performance.Tests;

/// <summary>
/// The figures as the view writes them: semantic tables without a class or a style, the texts from the
/// package's resources in French (neutral) and English.
/// </summary>
public sealed class PerformanceReportViewTests : IDisposable
{
    private static readonly DateTime Since = new(2026, 10, 6, 8, 30, 0, DateTimeKind.Utc);
    private readonly CultureInfo _culture = CultureInfo.CurrentCulture;
    private readonly CultureInfo _uiCulture = CultureInfo.CurrentUICulture;
    private readonly BunitContext _context = new();

    public PerformanceReportViewTests() => _context.Services.AddLocalization();

    public void Dispose()
    {
        _context.Dispose();
        CultureInfo.CurrentCulture = _culture;
        CultureInfo.CurrentUICulture = _uiCulture;
    }

    [Fact]
    public void WithSamples_WritesTheWindow_TheSlowestCalls_AndOneLinePerRoute()
    {
        UseCulture("fr-FR");
        var summary = new RequestPerformanceSummary(
            Since.AddDays(-7),
            [new RequestTimingSample(Since.AddMinutes(5), "GET", "/orders/{id}", 200, 1234)],
            Since, 3, Truncated: false,
            [new RouteTimingSummary("GET", "/orders/{id}", 3, 12, 980, 1234, 1234)]);

        var view = Render(summary);

        Assert.Contains("Depuis le 2026-09-29 08:30:00 (UTC), les plus lents d'abord.", view.Markup);
        Assert.Contains("Requêtes mesurées : 3, depuis le 2026-10-06 08:30:00 (UTC).", view.Markup);
        Assert.DoesNotContain("Plafond atteint", view.Markup);
        var tables = view.FindAll("table");
        Assert.Equal(2, tables.Count);
        Assert.Equal(["Appels les plus lents", "Par route"], view.FindAll("h2").Select(h => h.TextContent));
        var slowest = tables[0].QuerySelectorAll("tbody td").Select(td => td.TextContent).ToArray();
        Assert.Equal(["1,23 s", "GET", "/orders/{id}", "200", "2026-10-06 08:35:00"], slowest);
        var route = tables[1].QuerySelectorAll("tbody td").Select(td => td.TextContent).ToArray();
        Assert.Equal(["GET", "/orders/{id}", "3", "12 ms", "980 ms", "1,23 s", "1,23 s"], route);
        Assert.Empty(view.FindAll("[class], [style], style, link, script"));
    }

    [Fact]
    public void WithoutSamples_SaysSo_AndDrawsNoTable()
    {
        UseCulture("fr-FR");

        var view = Render(new RequestPerformanceSummary(Since, [], null, 0, false, []));

        Assert.Contains("Aucune requête mesurée pour l'instant.", view.Markup);
        Assert.Empty(view.FindAll("table"));
    }

    [Fact]
    public void PastTheCap_SaysThePercentilesLostTheOldest_InEnglish()
    {
        UseCulture("en-GB");
        var call = new RequestTimingSample(Since, "GET", "/orders", 200, 10);
        var summary = new RequestPerformanceSummary(Since, [call], Since, 1, Truncated: true, []);

        var view = Render(summary);

        Assert.Contains("Cap reached: the oldest requests no longer count in these percentiles (the slowest calls list is not affected).", view.Markup);
        Assert.Equal(["Slowest calls", "By route"], view.FindAll("h2").Select(h => h.TextContent));
    }

    [Theory]
    [InlineData("en-GB", "en")]
    [InlineData("fr-BE", "fr")]
    [InlineData("", "fr")] // invariant culture: its two-letter name "iv" is no language
    public void ThePageLanguage_IsTheUiCultures_OrTheNeutralFrench(string culture, string expected)
    {
        CultureInfo.CurrentUICulture = CultureInfo.GetCultureInfo(culture);

        Assert.Equal(expected, PerformancePage.Language);
    }

    private IRenderedComponent<PerformanceReportView> Render(RequestPerformanceSummary summary) =>
        _context.Render<PerformanceReportView>(parameters => parameters.Add(view => view.Summary, summary));

    private static void UseCulture(string name)
    {
        CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo(name);
        CultureInfo.CurrentUICulture = CultureInfo.GetCultureInfo(name);
    }
}
