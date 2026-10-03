# Grid Layout Algorithm

## Overview

The **Grid** layout mode arranges windows into a structured rows × columns grid,
inspired by macOS Exposé's grid algorithm as described in **US Patent 8,612,883**
("User interface for managing the display of multiple display regions", Apple Inc.,
filed 2009, granted 2013).

When enabled (via Settings → Windows → Layout → "Grid", or
`omarchy-shell expose layoutMode grid`), the overview uses `computeGridLayout()`
instead of the default `computeWindowLayout()` adaptive packing.

## Algorithm

### 1. Entry Preparation

Each window (toplevel) is converted into a layout entry with:
- `ratio` — the window's aspect ratio (width / height), read from cached or live state
- `weight` — an adaptive weight `clamp(0.72, 1.28, sqrt(ratio / 1.6))` that slightly
  shrinks very wide or very tall windows for visual balance
- `extremity` — `max(ratio, 1/ratio)`, how far the window deviates from square

Entries are sorted by extremity (most non-square first), with original index as a
stable tiebreaker.

### 2. Grid Dimension Estimation

The initial grid dimensions are computed using a **sqrt-based formula adjusted for
screen aspect ratio** (derived from the patent and cross-referenced with the
StackOverflow "Exposé Layout Algorithm" answer):

```
viewportRatio = screen_width / screen_height
columns = round(sqrt(count × viewportRatio))
rows    = ceil(count / columns)
```

This produces wider grids on wide screens (more columns) and taller grids on tall
screens (more rows), matching how macOS Exposé adapts to the display.

### 3. Grid Constraint

For **4 or more windows**, the algorithm enforces a minimum of **2 rows** to prevent
degenerate single-row layouts (e.g., 4 windows in 1 row on a very wide monitor).

This gives the classic macOS Exposé grids:

| Windows | Grid     | Visual  |
|--------:|:-------|:--------|
| 1       | 1×1    | Single  |
| 2       | 1×2    | Row     |
| 3       | 2×2    | Triangle|
| 4       | 2×2    | Square  |
| 5       | 2×3    | 2+3     |
| 6       | 2×3    | Full    |
| 7       | 2×4    | 3+4     |
| 8       | 2×4    | Full    |
| 9       | 3×3    | Square  |
| 10–12   | 3×4    | Grid    |

### 4. Area Maximization (Row Optimization)

Following the patent's Step 2, the algorithm tries each row count from `minRows`
to `maxRows`, computing the corresponding column count for each. For each
configuration, a **binary search** finds the maximum uniform scale factor that fits
all windows within the available area. The configuration with the **highest scale**
(largest windows) is selected.

This mirrors the patent's directive: "decrease # of rows if the total compressed
window area is greater." Since total area = N × W × H / (rows × cols), maximizing
area is equivalent to minimizing the total number of grid cells (rows × cols).

The practical effect: for 8 windows on a wide screen, 2×4 (8 cells, 0 empty) beats
3×3 (9 cells, 1 empty), matching the empirically confirmed macOS behavior.

### 5. Even Distribution

Unlike the adaptive layout (which distributes windows to rows by width, placing
wider windows in earlier rows), the grid mode uses **even distribution**: windows
are placed left-to-right, top-to-bottom, with `ceil(count / rows)` windows per row.
Within each row, windows are re-sorted by their original index for consistent
left-to-right ordering.

### 6. Positioning

The shared `composeRows()` function positions cards within their rows:
- Each row is horizontally centered within the available width
- Rows are vertically centered within the available height
- A slight vertical stagger (`((index + row) % 3) / 2`) adds visual rhythm
- Edge insets (half the gap) are applied to all positions

## Comparison: Adaptive vs Grid

| Aspect              | Adaptive                          | Grid                              |
|---------------------|-----------------------------------|-----------------------------------|
| Row count selection | Maximizes scale across all counts | sqrt-based estimate, area-optimal |
| Distribution        | Width-sorted (wide first)         | Even (left-to-right, top-to-bottom)|
| 4 windows on wide   | May collapse to 1 row             | Always 2×2                        |
| 8 windows           | Variable (scale-dependent)        | 2×4 (macOS-style)                 |
| Best for            | Maximum window size on any screen | Predictable, structured layouts   |

## Sources

- US Patent 8,612,883 — "User interface for managing the display of multiple display regions" (Apple Inc.)
- US Patent 8,621,387 — Related Exposé grid algorithm patent
- Apple Stack Exchange #142935 — Empirical observation of 8-window 2×4 grid
- StackOverflow #4436043 — Exposé layout algorithm analysis
- KWin expolayout.h — Reverse-engineered implementation reference

## Persistence

The layout mode is saved in the plugin entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "expose.window-overview",
  "layoutMode": "grid",
  "workspaceScope": "current",
  ...
}
```

It can also be set programmatically:

```sh
omarchy-shell expose layoutMode grid     # or: adaptive
```
