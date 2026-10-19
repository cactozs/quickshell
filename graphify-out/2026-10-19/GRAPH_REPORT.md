# Graph Report - quickshell  (2026-10-18)

## Corpus Check
- 50 files · ~35,263 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 2 file(s) not represented in the graph (top: (none) 2)

## Summary
- 105 nodes · 112 edges · 37 communities (10 shown, 27 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c8f317a1`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Bar Status Chips
- LayoutBadge (keyboard-layout HUD)
- Clipboard Overlay
- App Launcher Overlay
- PowerButton (tonal power toggle)
- M3 Theme & Controls
- Niri Workspaces
- Graphify Agent Workflow
- SystemMonitor (CPU/GPU/RAM/network poller)
- QuickShell Config
- ShellState.barHidden
- handleLine() event dispatch

## God Nodes (most connected - your core abstractions)
1. `Bar (M3 floating pill panel)` - 13 edges
2. `IconButton (M3 chip control base)` - 10 edges
3. `ClipboardLauncher (cliphist overlay)` - 10 edges
4. `Launcher (app launcher overlay, wofi replacement)` - 8 edges
5. `Workspaces (niri workspace chips)` - 8 edges
6. `LayoutBadge (keyboard-layout HUD)` - 7 edges
7. `StateLayer (M3 hover/press overlay)` - 7 edges
8. `Tip (M3 tooltip popup)` - 6 edges
9. `handleLine() event dispatch` - 6 edges
10. `Theme (M3 Expressive design tokens singleton)` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Bar (M3 floating pill panel)` --shares_data_with--> `ShellState.barHidden`  [EXTRACTED]
  modules/Bar.qml → services/ShellState.qml
- `Material 3 Expressive design language` --rationale_for--> `IconButton (M3 chip control base)`  [INFERRED]
  style/Theme.qml → modules/IconButton.qml
- `SystemStats (CPU/GPU/RAM chip)` --references--> `SystemMonitor.tooltip`  [EXTRACTED]
  modules/SystemStats.qml → services/SystemMonitor.qml
- `LayoutBadge (keyboard-layout HUD)` --references--> `layoutSwitched signal`  [EXTRACTED]
  modules/LayoutBadge.qml → services/Niri.qml
- `Bar (M3 floating pill panel)` --references--> `Theme (M3 Expressive design tokens singleton)`  [EXTRACTED]
  modules/Bar.qml → style/Theme.qml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **M3 Expressive design system implementation** — style_theme_theme, style_theme_m3_expressive, modules_iconbutton_iconbutton, modules_statelayer_statelayer, modules_tip_tip, modules_bar_bar, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]
- **niri IPC integration (event stream + action bridge)** — services_niri_niri, services_niri_handleline, services_niri_layoutswitched, modules_workspaces_workspaces, modules_windowtitle_windowtitle, modules_keyboardlayout_keyboardlayout, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]

## Communities (37 total, 27 thin omitted)

### Community 0 - "Bar Status Chips"
Cohesion: 0.28
Nodes (12): Backlight (brightnessctl chip), Bar (M3 floating pill panel), Battery (UPower chip), DateClock (date chip with calendar tooltip), IconButton (M3 chip control base), KeyboardLayout (niri layout chip), PowerButton (tonal power toggle), SystemStats (CPU/GPU/RAM chip) (+4 more)

### Community 1 - "LayoutBadge (keyboard-layout HUD)"
Cohesion: 0.29
Nodes (6): LayoutBadge (keyboard-layout HUD), Niri.currentLayout, Niri.keyboardLayouts state, layoutShortName(), Waybar-era shell migration, ShellRoot (per-screen shell entry point)

### Community 2 - "Clipboard Overlay"
Cohesion: 0.24
Nodes (10): activateMenu(), ClipboardLauncher (cliphist overlay), copyEntry(), deleteEntry(), parseList(), wipeHistory(), ShellState.clipboardScreen, closeClipboard() (+2 more)

### Community 3 - "App Launcher Overlay"
Cohesion: 0.25
Nodes (8): activate(), fieldScore(), Launcher (app launcher overlay, wofi replacement), scoreEntry(), closeLauncher(), IPC target: launcher, ShellState.launcherScreen, toggleLauncher()

### Community 4 - "PowerButton (tonal power toggle)"
Cohesion: 0.67
Nodes (3): IPC target: power, ShellState.powerMenuScreen, togglePowerMenu()

### Community 5 - "M3 Theme & Controls"
Cohesion: 0.25
Nodes (6): ClipItem (inline entry delegate), MenuEntry (inline actions row), ResultItem (inline app row delegate), StateLayer (M3 hover/press overlay), applyGeneratedScheme(), Theme (M3 Expressive design tokens singleton)

### Community 6 - "Niri Workspaces"
Cohesion: 0.40
Nodes (3): Workspaces (niri workspace chips), Niri.workspaces state, workspacesFor()

### Community 24 - "QuickShell Config"
Cohesion: 0.50
Nodes (3): dependencies, keybinds, MOSTLY WRITTEN BY AI

### Community 25 - "ShellState.barHidden"
Cohesion: 0.67
Nodes (3): ShellState.barHidden, IPC target: bar, toggleBar()

### Community 32 - "handleLine() event dispatch"
Cohesion: 0.33
Nodes (7): Niri.focusedWindow, handleLine() event dispatch, layoutSwitched signal, Niri (niri IPC bridge singleton), refreshWorkspaces(), Niri.windows state, ShellState (cross-window state singleton)

## Knowledge Gaps
- **5 isolated node(s):** `TimeClock (clock chip)`, `IPC target: bar`, `ShellState (cross-window state singleton)`, `IPC target: power`, `ShellState.powerMenuScreen`
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 47 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **27 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Bar (M3 floating pill panel)` connect `Bar Status Chips` to `ShellState.barHidden`, `M3 Theme & Controls`, `Niri Workspaces`, `LayoutBadge (keyboard-layout HUD)`?**
  _High betweenness centrality (0.171) - this node is a cross-community bridge._
- **What connects `TimeClock (clock chip)`, `IPC target: bar`, `ShellState (cross-window state singleton)` to the rest of the system?**
  _5 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Why does `Launcher (app launcher overlay, wofi replacement)` connect `App Launcher Overlay` to `Bar Status Chips`, `LayoutBadge (keyboard-layout HUD)`, `Clipboard Overlay`, `M3 Theme & Controls`?**
  _High betweenness centrality (0.137) - this node is a cross-community bridge._
- **Why does `ClipboardLauncher (cliphist overlay)` connect `Clipboard Overlay` to `LayoutBadge (keyboard-layout HUD)`, `App Launcher Overlay`, `M3 Theme & Controls`?**
  _High betweenness centrality (0.129) - this node is a cross-community bridge._