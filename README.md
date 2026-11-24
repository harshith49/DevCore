# DevCore

Free, offline-first, open-source native macOS developer control center. Requires macOS 14 or newer. No subscriptions, accounts, network services, or third-party packages.

## First milestone

- Native SwiftUI split-view sidebar, system appearance, emerald accents and material cards.
- Real CPU activity with an interactive 60-sample chart, memory estimate, home-volume storage, and internal battery data.
- Read-only TCP port manager: process name, PID, port and bind address from `/usr/sbin/lsof`.
- Search filters module navigation and port data. ⌘K focuses search; ⌘R refreshes. The native toolbar toggles the sidebar.

## Build and install

Install full Xcode for an application bundle. Open `DevCore.xcodeproj`, select the DevCore scheme and My Mac, then Run. To install, build Release and copy `DevCore.app` from the Products group (Show in Finder) to Applications. Configure your own signing team for signed distribution; a paid developer account is not needed for local development. DevCore is not notarized or distributed as a signed download. Do not disable Gatekeeper.

With Apple's Swift command-line tools:

```sh
swift build
swift run DevCore
swift test
swift build -c release
```

The package executable is useful for local development; the Xcode target produces the normal macOS `.app`. Tests run through Swift Package Manager. Both builds use the same sources. No generated project tooling is required.

The project uses the native build architecture and supports arm64 and x86_64 source builds. Intel requires macOS 14+. Cross-architecture builds and hardware behavior must be verified on those Macs before release.

If XCTest is unavailable in a command-line-only installation, run the included assert-based checks (do not compile with `-O`):

```sh
swiftc Sources/DevCoreCore/*.swift Checks/SelfCheck.swift -o /tmp/devcore-self-check
/tmp/devcore-self-check
```

## Architecture

`DevCoreApp` owns the main-actor `DevCoreModel` (MVVM). Views render published snapshots. `SystemMonitor` samples Mach CPU/VM statistics, Foundation filesystem statistics and IOKit battery information. CPU is calculated between successive samples; the first sample is intentionally unavailable. A cancellable view task polls every two seconds and keeps 60 CPU samples. The port service runs a fixed executable and fixed arguments off the main actor and parses machine-readable lsof fields. Refreshes cannot overlap.

`DevCoreCore` is a Foundation/Darwin service module with XCTest coverage; `DevCore` is the SwiftUI/AppKit-hosted application and Swift Charts interface. SQLite, CryptoKit, Keychain storage and persistent data are deferred until a feature requires them, avoiding unused schema and credential code.

## Security and permissions

This milestone is read-only. It executes only `/usr/sbin/lsof -nP -iTCP -sTCP:LISTEN -Fpcn`, without a shell or user-provided arguments. No process termination, deletion, privilege escalation, credential collection, telemetry, or outbound network requests exist. It requires no Accessibility, Full Disk Access or administrator permission. It runs outside App Sandbox to inspect processes; normal macOS account permissions still apply. Protected or other-user processes may be missing; an empty list is not proof that no services exist. The table includes TCP only, not UDP.

Monitoring and port snapshots live in memory only. Storage describes the home filesystem and may reflect shared APFS capacity. Memory includes reclaimable inactive pages and differs from Activity Monitor's memory-pressure calculation. Battery status is absent on desktops and may vary by power source.

## Incremental roadmap

The following are intentionally unimplemented: localhost/browser manager, process termination, Git dashboard, Docker, terminal commands, REST client, SSH, network connections, cache analyzer, menu bar; JWT, hashes, certificate inspection, encoders, secret scanning, firewall inspection, and vulnerability audits.

Add them only after the first application builds successfully. Destructive actions must require explicit confirmation; never automatically terminate system processes. Future commands must use fixed executable paths and validated argument arrays. Future credentials belong in macOS Keychain. Any tool that contacts a server must be explicitly user initiated and explain the destination; no sensitive data may be uploaded automatically. Missing Docker or other optional dependencies must produce actionable errors.

## Validation

`swift test` covers lsof parsing (duplicates, IPv6, malformed PIDs/ports and empty output), real system statistics, and live lsof inspection. Xcode build, visual UI review, Intel execution and battery behavior require their respective tools/hardware. See the delivery notes for what was executed in the development environment.

Licensed under MIT.

### Current validation environment

Swift command-line debug and release builds and the standalone service checks were run locally. Full Xcode is absent on the development Mac, so `xcodebuild`, XCTest execution, signed bundle installation and Intel hardware validation remain outstanding. No later modules have been started.
