# Changelog

Notable changes to this project are documented here, following the Keep a Changelog format.

## [Unreleased]

## [1.0.1] - 2026-10-07

### Added

- Concurrency tests of the change signal: simultaneous requests never throw on the request path and wake the wait;
  two simultaneous waits share the signals, each one waking a single wait.

### Changed

- README, the package page on NuGet, written in English.
- Changelog and repository documentation written in English.

## [1.0.0] - 2026-10-07

### Added

- `AddOmniPerformanceCollector`: the collector alone, without the page's services (Razor components, localization),
  for a host that shows the figures itself; `MapOmniPerformance` refuses such a host at startup.
- Blocking coverage floors, in the launcher (`-c`) and continuous integration: 95 % of lines, 85 % of branches.

### Changed

- First stable version: the public API now follows semantic versioning.

## [0.2.0] - 2026-10-06

### Added

- Change signal `RequestPerformanceRecorder.WaitForChangeAsync`: completes as soon as a measured request is recorded,
  several requests between two waits give a single signal; it lets an application page update live.

### Changed

- Package description and README: the 2 MiB limit applies to the memory held by the collector; the README states
  what stays outside that limit (route template cache, copy of the ring while the page renders).

### Fixed

- The default filter leaves out the `/health`, `/_framework`, `/_content` and `/_blazor` families by whole segment:
  `/healthcare/{id}` is measured again.
- The page no longer measures itself: reading it no longer ranks among the slowest calls.
- `<html lang>` is `fr` under the invariant culture (instead of the non-existent `iv` code).
- Rendering the page allocates a single copy of the ring (about 1.9 MiB instead of several MiB): the percentiles are
  read from the copy sorted in place, the ranking comes from a bounded heap.

### Removed

- Automatic dependency update configuration: no more automatic update requests; the local launcher reports outdated
  packages and SDK.

## [0.1.0] - 2026-10-06

### Added

- Repository skeleton: solution, `src/OmniEurope.Performance` project, EUPL-1.2 licence, `ylaunch.ps1` launcher,
  CRAP gate (`scripts/crap-gate.ps1`).
- `RequestPerformanceRecorder` collector: request durations per route template, read from the ASP.NET Core
  `http.server.request.duration` measurement, without middleware; 7-day window, at most 2 MiB of memory held, with a
  rolling ring, slowest requests kept outside the ring, `OmniPerformance` settings.
- `/performance` page (`AddOmniPerformance`, `MapOmniPerformance`): unstyled HTML document, slowest calls and
  per-route percentiles; `PerformanceReportView` for a host that styles it. French and English texts.
- Test suite `tests/OmniEurope.Performance.Tests` (xUnit v3, bUnit, ASP.NET Core test host, memory measurement).
- Continuous integration and NuGet publication (`.github/workflows`), `.snupkg` symbol package.

### Changed

- The package references the `Microsoft.AspNetCore.App` shared framework instead of the
  `Microsoft.AspNetCore.Components.Web` package: it requires an ASP.NET Core host.
