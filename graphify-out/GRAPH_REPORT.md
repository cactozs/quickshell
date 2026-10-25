# Graph Report - quickshell  (2026-10-25)

## Corpus Check
- 64 files · ~174,173 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 11 file(s) not represented in the graph (top: (none) 7, .toml 2, .ini 1)

## Summary
- 236 nodes · 385 edges · 42 communities (9 shown, 33 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 6 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `8c953d37`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Bar Status Chips
- LayoutBadge (keyboard-layout HUD)
- ClipboardLauncher (cliphist overlay)
- install.sh
- Quickshell
- Quickshell
- Contributing
- Graphify Agent Workflow
- check-qml.py
- calculate

## God Nodes (most connected - your core abstractions)
1. `ok()` - 23 edges
2. `note()` - 22 edges
3. `warn()` - 20 edges
4. `install.sh script` - 17 edges
5. `run_checks()` - 15 edges
6. `Quickshell` - 14 edges
7. `Quickshell` - 14 edges
8. `Bar (M3 floating pill panel)` - 13 edges
9. `have()` - 11 edges
10. `fail()` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Bar (M3 floating pill panel)` --shares_data_with--> `ShellState.barHidden`  [EXTRACTED]
  modules/Bar.qml → services/ShellState.qml
- `ShellRoot (per-screen shell entry point)` --references--> `Bar (M3 floating pill panel)`  [EXTRACTED]
  shell.qml → modules/Bar.qml
- `Material 3 Expressive design language` --rationale_for--> `IconButton (M3 chip control base)`  [INFERRED]
  style/Theme.qml → modules/IconButton.qml
- `KeyboardLayout (niri layout chip)` --references--> `Niri.currentLayout`  [EXTRACTED]
  modules/KeyboardLayout.qml → services/Niri.qml
- `Material 3 Expressive design language` --rationale_for--> `StateLayer (M3 hover/press overlay)`  [INFERRED]
  style/Theme.qml → modules/StateLayer.qml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **M3 Expressive design system implementation** — style_theme_theme, style_theme_m3_expressive, modules_iconbutton_iconbutton, modules_statelayer_statelayer, modules_tip_tip, modules_bar_bar, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]
- **niri IPC integration (event stream + action bridge)** — services_niri_niri, services_niri_handleline, services_niri_layoutswitched, modules_workspaces_workspaces, modules_windowtitle_windowtitle, modules_keyboardlayout_keyboardlayout, modules_layoutbadge_layoutbadge [EXTRACTED 1.00]

## Communities (42 total, 33 thin omitted)

### Community 0 - "Bar Status Chips"
Cohesion: 0.10
Nodes (24): Backlight (brightnessctl chip), Bar (M3 floating pill panel), Battery (UPower chip), ClipItem (inline entry delegate), DateClock (date chip with calendar tooltip), IconButton (M3 chip control base), KeyboardLayout (niri layout chip), PowerButton (tonal power toggle) (+16 more)

### Community 1 - "LayoutBadge (keyboard-layout HUD)"
Cohesion: 0.08
Nodes (25): activate(), fieldScore(), Launcher (app launcher overlay, wofi replacement), ResultItem (inline app row delegate), scoreEntry(), LayoutBadge (keyboard-layout HUD), Workspaces (niri workspace chips), Niri.currentLayout (+17 more)

### Community 2 - "ClipboardLauncher (cliphist overlay)"
Cohesion: 0.21
Nodes (11): activateMenu(), ClipboardLauncher (cliphist overlay), copyEntry(), deleteEntry(), MenuEntry (inline actions row), parseList(), wipeHistory(), ShellState.clipboardScreen (+3 more)

### Community 3 - "install.sh"
Cohesion: 0.23
Nodes (37): append_if_missing(), append_niri_autostart(), append_niri_environment(), apply_ghostty(), apply_niri(), apply_qt6ct(), backup_file(), check_desktop() (+29 more)

### Community 4 - "Quickshell"
Cohesion: 0.08
Nodes (25): 1. Клонирование, 2. Пакеты, 3. Шрифты, 4. matugen, 5. Шим для awww, 6. niri, 7. ghostty и Qt, 8. Обои, погода и терминал (+17 more)

### Community 5 - "Quickshell"
Cohesion: 0.07
Nodes (25): 1. Clone, 2. Packages, 3. Fonts, 4. matugen, 5. The awww shim, 6. niri, 7. ghostty and Qt, 8. Wallpapers, weather and terminal (+17 more)

### Community 6 - "Contributing"
Cohesion: 0.40
Nodes (4): Check before sending a change, Contributing, Rules of thumb, Run it

### Community 24 - "check-qml.py"
Cohesion: 0.25
Nodes (8): block_after_key(), check_fileviews(), check_hardcoded_colors(), check_i18n(), check_singletons(), find_blocks(), main(), qml_files()

### Community 40 - "calculate"
Cohesion: 0.25
Nodes (12): calculate(), expression(), postfix(), power(), primary(), skip(), startsFactor(), term() (+4 more)

## Knowledge Gaps
- **5 isolated node(s):** `TimeClock (clock chip)`, `IPC target: bar`, `IPC target: power`, `ShellState.powerMenuScreen`, `ShellState (cross-window state singleton)`
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 111 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **33 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Bar (M3 floating pill panel)` connect `Bar Status Chips` to `LayoutBadge (keyboard-layout HUD)`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **What connects `TimeClock (clock chip)`, `IPC target: bar`, `IPC target: power` to the rest of the system?**
  _5 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Bar Status Chips` be split into smaller, more focused modules?**
  _Cohesion score 0.10114942528735632 - nodes in this community are weakly interconnected._
- **Why does `Quickshell` connect `Quickshell` to `Quickshell`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Should `LayoutBadge (keyboard-layout HUD)` be split into smaller, more focused modules?**
  _Cohesion score 0.07956989247311828 - nodes in this community are weakly interconnected._
- **Should `Quickshell` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._
- **Should `Quickshell` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._