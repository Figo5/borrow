# Working on Borrow

Borrow is a native macOS Swift application and local task recorder. Build with `swift build`, test with `swift test`, and package with `bash scripts/build-app.sh`.

Keep findings bounded by evidence. A live process, quiet CPU, successful connectivity probe, or zero command exit must never become an invented claim that an agent's task is correct. Unknown is a valid result. Never label a sampling gap as sleep without a separate sleep signal. Fixture-based tests must not be presented as physical closed-lid validation.

The prototype changes only its own recording files and launches explicitly requested foreground commands. It must not change global power settings, agent permissions/configuration, system services, or terminate unrelated processes. Connectivity probes are opt-in. Do not persist prompts, command arguments, output, environment contents, or screenshots in reports.

Use `@Observable` state and native SwiftUI/AppKit components. Keep app state on the main actor and core evidence rules independent of views. No external dependencies are currently needed.

Use a disposable `--output` directory for CLI verification. Add tests when evidence semantics or process lifecycle behavior changes. Document physical tests with hardware, OS, power source, duration, and exact observations. A missing physical test is a release limitation, not permission to simulate a green result.

Ousel remains separate. The user authorized archiving it once Borrow is ready, not deleting its history. Read docs/product-brief.md for readiness gates.
