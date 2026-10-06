// SPDX-License-Identifier: EUPL-1.2
namespace OmniEurope.Performance;

/// <summary>What the recorder holds: the slowest calls of the window and the percentiles of every route.</summary>
/// <param name="WindowStart">Start of the window the slowest calls cover, in UTC: the window's length ago, or
/// the process start when it is more recent.</param>
/// <param name="Slowest">The slowest requests of the window, slowest first, unaffected by the sample cap.</param>
/// <param name="Since">Oldest sample the percentiles count, in UTC; later than <paramref name="WindowStart"/>
/// when the cap dropped older ones. Null without samples.</param>
/// <param name="SampleCount">Samples the percentiles are computed from.</param>
/// <param name="Truncated">True while the cap has dropped samples that would still be inside the window.</param>
/// <param name="Routes">One line per route and method, slowest 95th percentile first.</param>
public sealed record RequestPerformanceSummary(
    DateTime WindowStart,
    IReadOnlyList<RequestTimingSample> Slowest,
    DateTime? Since,
    int SampleCount,
    bool Truncated,
    IReadOnlyList<RouteTimingSummary> Routes);

/// <summary>The timings of one route template and method, in milliseconds.</summary>
/// <param name="Method">The HTTP method.</param>
/// <param name="Route">The route template, as in <see cref="RequestTimingSample.Route"/>.</param>
/// <param name="Count">Requests measured.</param>
/// <param name="P50Ms">Median duration.</param>
/// <param name="P95Ms">95th percentile duration.</param>
/// <param name="P99Ms">99th percentile duration.</param>
/// <param name="MaxMs">Longest duration.</param>
public sealed record RouteTimingSummary(
    string Method,
    string Route,
    int Count,
    double P50Ms,
    double P95Ms,
    double P99Ms,
    double MaxMs);

/// <summary>Pure: turns kept samples into per-route percentiles beside the slowest calls, so the arithmetic
/// is tested without a listener or a clock.</summary>
internal static class RequestPerformanceReport
{
    public static RequestPerformanceSummary Build(
        IReadOnlyList<RequestTimingSample> samples, bool truncated, IReadOnlyList<RequestTimingSample> slowest, DateTime windowStart)
    {
        ArgumentNullException.ThrowIfNull(samples);
        ArgumentNullException.ThrowIfNull(slowest);

        var routes = samples
            .GroupBy(sample => (sample.Method, sample.Route))
            .Select(group =>
            {
                var sorted = group.Select(sample => sample.DurationMs).Order().ToArray();
                return new RouteTimingSummary(
                    group.Key.Method,
                    group.Key.Route,
                    sorted.Length,
                    Percentile(sorted, 0.50),
                    Percentile(sorted, 0.95),
                    Percentile(sorted, 0.99),
                    sorted[^1]);
            })
            .OrderByDescending(route => route.P95Ms)
            .ThenBy(route => route.Route, StringComparer.Ordinal)
            .ThenBy(route => route.Method, StringComparer.Ordinal)
            .ToList();

        return new RequestPerformanceSummary(
            windowStart,
            slowest,
            samples.Count == 0 ? null : samples.Min(sample => sample.At),
            samples.Count,
            truncated,
            routes);
    }

    /// <summary>Nearest-rank percentile on an ascending array: the smallest value at or above the
    /// requested share of the samples. No interpolation, so every figure is a request that happened.</summary>
    public static double Percentile(double[] ascending, double share)
    {
        ArgumentNullException.ThrowIfNull(ascending);
        if (ascending.Length == 0) return 0;
        var rank = (int)Math.Ceiling(share * ascending.Length);
        return ascending[Math.Clamp(rank - 1, 0, ascending.Length - 1)];
    }
}
