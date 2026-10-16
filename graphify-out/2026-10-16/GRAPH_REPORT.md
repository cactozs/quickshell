# Graph Report - quickshell  (2026-10-16)

## Corpus Check
- 35 files · ~16,245 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 2 file(s) not represented in the graph (top: (none) 2)

## Summary
- 88 nodes · 109 edges · 21 communities (8 shown, 13 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `101010ad`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Bar Status Chips
- Niri IPC Integration
- Clipboard Overlay
- App Launcher Overlay
- PowerButton (tonal power toggle)
- M3 Theme & Controls
- Niri Workspaces
- Graphify Agent Workflow
- handleLine() event dispatch

## God Nodes (most connected - your core abstractions)
1. `Bar (M3 floating pill panel)` - 13 edges
2. `ClipboardLauncher (cliphist overlay)` - 10 edges
3. `IconButton (M3 chip control base)` - 10 edges
4. `Launcher (app launcher overlay, wofi replacement)` - 8 edges
5. `Workspaces (niri workspace chips)` - 8 edges
6. `LayoutBadge (keyboard-layout HUD)` - 7 edges
7. `StateLayer (M3 hover/press overlay)` - 7 edges
8. `Tip (M3 tooltip popup)` - 6 edges
9. `handleLine() event dispatch` - 6 edges
10. `Theme (M3 Expressive design tokens singleton)` - 6 edges

## Surprising Connections (you probably didn't know these)
- `LayoutBadge (keyboard-layout HUD)` --references--> `layoutSwitched signal`  [EXTRACTED]
  modules/LayoutBadge.qml → services/Niri.qml
- `Bar (M3 floating pill panel)` --shares_data_with--> `ShellState.barHidden`  [EXTRACTED]
  modules/Bar.qml → services/ShellState.qml
- `Bar (M3 floating pill panel)` --references--> `Theme (M3 Expressive design tokens singleton)`  [EXTRACTED]
  modules/Bar.qml → style/Theme.qml
- `ShellRoot (per-screen shell entry point)` --references--> `Bar (M3 floating pill panel)`  [EXTRACTED]
  shell.qml → modules/Bar.qml
- `SystemStats (CPU/GPU/RAM chip)` --references--> `SystemMonitor.tooltip`  [EXTRACTED]
  modules/SystemStats.qml → services/SystemMonitor.qml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **M3 Expressive design system implementation** — style_theme_theme, style_theme_m3_expressive, modules_iconbutton_iconbutton, modules_statelayer_statelayer, modules_tip_tip, modules_bar_bar, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]
- **niri IPC integration (event stream + action bridge)** — services_niri_niri, services_niri_handleline, services_niri_layoutswitched, modules_workspaces_workspaces, modules_windowtitle_windowtitle, modules_keyboardlayout_keyboardlayout, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]

## Communities (21 total, 13 thin omitted)

### Community 0 - "Bar Status Chips"
Cohesion: 0.16
Nodes (14): Backlight (brightnessctl chip), Bar (M3 floating pill panel), Battery (UPower chip), DateClock (date chip with calendar tooltip), SystemStats (CPU/GPU/RAM chip), TimeClock (clock chip), Tip (M3 tooltip popup), Volume (Pipewire sink chip) (+6 more)

### Community 1 - "Niri IPC Integration"
Cohesion: 0.25
Nodes (7): KeyboardLayout (niri layout chip), LayoutBadge (keyboard-layout HUD), Niri.currentLayout, Niri.keyboardLayouts state, layoutShortName(), Waybar-era shell migration, ShellRoot (per-screen shell entry point)

### Community 2 - "Clipboard Overlay"
Cohesion: 0.19
Nodes (12): activateMenu(), ClipboardLauncher (cliphist overlay), ClipItem (inline entry delegate), copyEntry(), deleteEntry(), MenuEntry (inline actions row), parseList(), wipeHistory() (+4 more)

### Community 3 - "App Launcher Overlay"
Cohesion: 0.22
Nodes (9): activate(), fieldScore(), Launcher (app launcher overlay, wofi replacement), ResultItem (inline app row delegate), scoreEntry(), closeLauncher(), IPC target: launcher, ShellState.launcherScreen (+1 more)

### Community 4 - "PowerButton (tonal power toggle)"
Cohesion: 0.50
Nodes (4): PowerButton (tonal power toggle), IPC target: power, ShellState.powerMenuScreen, togglePowerMenu()

### Community 5 - "M3 Theme & Controls"
Cohesion: 0.43
Nodes (4): IconButton (M3 chip control base), StateLayer (M3 hover/press overlay), applyGeneratedScheme(), Theme (M3 Expressive design tokens singleton)

### Community 6 - "Niri Workspaces"
Cohesion: 0.40
Nodes (3): Workspaces (niri workspace chips), Niri.workspaces state, workspacesFor()

### Community 16 - "handleLine() event dispatch"
Cohesion: 0.33
Nodes (7): Niri.focusedWindow, handleLine() event dispatch, layoutSwitched signal, Niri (niri IPC bridge singleton), refreshWorkspaces(), Niri.windows state, ShellState (cross-window state singleton)

## Knowledge Gaps
- **5 isolated node(s):** `TimeClock (clock chip)`, `IPC target: bar`, `ShellState (cross-window state singleton)`, `IPC target: power`, `ShellState.powerMenuScreen`
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 31 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Bar (M3 floating pill panel)` connect `Bar Status Chips` to `Niri IPC Integration`, `PowerButton (tonal power toggle)`, `M3 Theme & Controls`, `Niri Workspaces`?**
  _High betweenness centrality (0.245) - this node is a cross-community bridge._
- **What connects `TimeClock (clock chip)`, `IPC target: bar`, `ShellState (cross-window state singleton)` to the rest of the system?**
  _5 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Why does `Launcher (app launcher overlay, wofi replacement)` connect `App Launcher Overlay` to `Niri IPC Integration`, `Clipboard Overlay`, `M3 Theme & Controls`?**
  _High betweenness centrality (0.196) - this node is a cross-community bridge._
- **Why does `ClipboardLauncher (cliphist overlay)` connect `Clipboard Overlay` to `Niri IPC Integration`, `App Launcher Overlay`?**
  _High betweenness centrality (0.185) - this node is a cross-community bridge._