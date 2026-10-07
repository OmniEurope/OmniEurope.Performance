<!-- SPDX-License-Identifier: EUPL-1.2 -->
# PLAN-001 : Initial scope

> Status: **done** (2026-10-06), version 0.1.0 published on NuGet.

## Objective

A performance page, without a theme, that an ASP.NET Core application adds in two lines (services, route) and that a
component library can style afterwards.

## Chosen architecture (2026-10-06)

- **A single package**: server-side collector and Razor page in `OmniEurope.Performance`. The collector requires
  `FrameworkReference Microsoft.AspNetCore.App`: the package targets an ASP.NET Core host (Blazor Web App or Server),
  not a standalone Blazor WebAssembly app.
- **Server side**: request durations collected per route without middleware, by listening to the
  `http.server.request.duration` histogram ASP.NET Core already publishes (`MeterListener` in an `IHostedService`).
- **Memory**: at most 2 MiB held by default (`MemoryLimitBytes`). The list of the slowest requests (`SlowestCount` per
  hour of the window) is served first, the rest is a ring allocated once for the percentiles. 7-day window by default
  (`Window`), settings read from the `OmniPerformance` section.
- **Page side**: the page reads the collector through dependency injection, without an intermediate JSON API. It is
  served by an ordinary endpoint (`MapOmniPerformance`, `RazorComponentResult`), independent of the application's
  Blazor router; `PerformanceReportView` carries the figures alone for a host that styles them.

## Batch 1 : inventory of the measurements

- [x] Inventory of the measurements a minimal performance page needs: what it measures, how, what is out of scope.
- Check: the list of the measurements kept and of those left aside is recorded here.

Kept:

- listening to `http.server.request.duration` and grouping by route template and method, case-insensitive;
- the report: slowest calls, 50/95/99 percentiles by nearest rank, maximum, sorted by 95th percentile;
- the configurable route filter and the default exclusion of probes and the framework;
- the window sentence ("since when the figures count") and the warning when requests are dropped.

Added: configurable 7-day window; memory limit with a rolling ring; ranking of the slowest requests independent of
the ring; filtering by the host's `IMeterFactory` (two hosts of one process never mix); default exclusion of static
files and `/_blazor`; route template normalized with a leading slash.

Left aside (beyond the strict minimum):

- exporting the figures to a monitoring tool and reading them for other applications;
- refresh pushed by a real-time hub;
- an intermediate JSON API;
- browser-side measurements (WebAssembly);
- grids, tabs, Markdown/CSV exports, header and icons: styling belongs to the host;
- smoothing percentiles computed on too few calls.

## Batch 2 : minimal page

- [x] Page component, semantic markup without CSS, one-line registration on each side (`AddOmniPerformance`,
  `MapOmniPerformance`).
- Check: bUnit tests of the rendering and the registration; no `.css` file nor third-party dependency in the
  package. Done: 30 tests (bUnit, end-to-end ASP.NET Core test host, memory measurement), 0 `.css`, no dependency in
  the `.nuspec` besides `Microsoft.AspNetCore.App`.

## Batch 3 : bounded memory

- [x] `MemoryLimitBytes` limit (2 MiB), ring allocated once, hourly ranking of the slowest requests outside the ring,
  route template cache without allocation per request.
- Check: `RecorderMemoryTests` counts the bytes allocated for a full week (ring rolled over, every hour full) and
  requires them to stay under the limit. Done: 2,056,520 bytes for 2,097,152, identical from one run to the next.

## Batch 4 : publication

- [x] NuGet package 0.1.0 with symbols (`.snupkg`), embedded README, `ylaunch.ps1 -c` green (CRAP gate).
- [x] `.github/workflows/ci.yml` (build, tests, coverage, CRAP, verified package, artifact) and `publish-nuget.yml`
  (on a published GitHub release, pushes the package validated by CI, NuGet trusted publishing without an API key).
- Check: the `ci.yml` steps replayed locally in Release pass (`CRAP gate passed`, package verified). Done: GitHub
  release `0.1.0`, "Publish NuGet" workflow green, package and symbols pushed to nuget.org.
