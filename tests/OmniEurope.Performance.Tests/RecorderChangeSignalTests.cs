// SPDX-License-Identifier: EUPL-1.2
namespace OmniEurope.Performance.Tests;

/// <summary>
/// The change signal a live page waits on: raised by a recorded request, coalesced, silent for a route the
/// filter leaves out. Fed through the recorder's internal entry point; the listener raising it from a real
/// request is proven by <see cref="PerformanceEndpointTests"/>.
/// </summary>
public sealed class RecorderChangeSignalTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 6, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task ARecordedRequest_CompletesTheWait()
    {
        using var test = new TestRecorder(new ManualClock(Now));
        var wait = test.Recorder.WaitForChangeAsync(TestContext.Current.CancellationToken);
        Assert.False(wait.IsCompleted);

        test.Recorder.Record("/orders", "GET", 200, 5);

        await wait.WaitAsync(TimeSpan.FromSeconds(5), TestContext.Current.CancellationToken);
    }

    [Fact]
    public async Task ManyRequests_BetweenTwoWaits_RaiseOneSignal()
    {
        using var test = new TestRecorder(new ManualClock(Now));
        for (var i = 0; i < 100; i++)
            test.Recorder.Record("/orders", "GET", 200, i);

        await test.Recorder.WaitForChangeAsync(TestContext.Current.CancellationToken).WaitAsync(TimeSpan.FromSeconds(5), TestContext.Current.CancellationToken);

        Assert.False(test.Recorder.WaitForChangeAsync(TestContext.Current.CancellationToken).IsCompleted);
    }

    [Fact]
    public void ARouteTheFilterLeavesOut_RaisesNoSignal()
    {
        using var test = new TestRecorder(new ManualClock(Now), new PerformanceOptions { RouteFilter = route => route.StartsWith("/api/", StringComparison.Ordinal) });

        test.Recorder.Record("/health", "GET", 200, 1);
        test.Recorder.Record("/orders", "GET", 200, 1);
        test.Recorder.Record(null, "GET", 404, 1);

        Assert.False(test.Recorder.WaitForChangeAsync(TestContext.Current.CancellationToken).IsCompleted);
    }

    [Fact]
    public async Task ACancelledWait_EndsWithoutARequest()
    {
        using var test = new TestRecorder(new ManualClock(Now));
        using var cancel = new CancellationTokenSource();
        var wait = test.Recorder.WaitForChangeAsync(cancel.Token);

        await cancel.CancelAsync();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => wait);
    }
}
