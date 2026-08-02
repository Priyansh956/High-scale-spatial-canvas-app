# Architecture

## Backend: Spatial Filtering Strategy

Objects are stored in MongoDB with a legacy `2d` index on `[x, y]` (not
`2dsphere` — the plane is Cartesian, index `min`/`max` match the seeded
-10000..10000 range). `GET /api/objects` accepts a bounding box and filters
with `$geoWithin: { $box }`, returning only intersecting objects, capped at
2000 with a `truncated` flag so the client knows when a region has more
data than was returned. `.lean()` skips document hydration on this
read-only path.

`PATCH /api/objects/:id` validates the ObjectId format before querying
(avoiding an unhandled CastError → 500) and clamps coordinates to the
index's own range. The seed script uses one `insertMany` bulk write for
10,000 objects rather than 10,000 round trips, clearing existing data first
so it's safely re-runnable.

## Frontend: Rendering & Network Strategy

The canvas is a single `CustomPainter` inside a `RepaintBoundary` — never one
widget per object, since laying out thousands of widgets would blow the 50ms
frame budget. Fetched objects are indexed into a client-side quadtree, used
for viewport-culled painting and tap hit-testing instead of a linear scan
per frame or gesture.

Pan/zoom are driven by a `ViewportController` (`ChangeNotifier`) consumed via
`AnimatedBuilder`, so gesture updates repaint only the canvas, not the
surrounding `Scaffold`. Viewport refetches are debounced 250ms after the
last gesture update with a 30% buffer beyond the visible region, so
continuous panning doesn't fire a request per frame. A monotonic
fetch-generation counter discards stale responses that resolve out of order.

Selection uses a shape-aware `hitTest`: each candidate's own radius
determines whether a tap landed inside it, preferring direct hits over
closer-but-outside near-misses. Drag-to-move only activates when a gesture
starts on the *already-selected* object — panning, dragging, and selection
all share the same `onScaleStart/Update/End` trio (Flutter reports
single-finger pan through the scale-gesture API), so a movement-distance
threshold at gesture end disambiguates tap from drag/pan. Position updates
apply optimistically every drag frame; `PATCH` fires once on release,
rolling back on failure.

## Trade-offs, Bottlenecks, and What I'd Improve

The trickiest bug was a coordinate-space mismatch: hit-testing used
`MediaQuery.of(context).size` (full screen) while `CustomPaint` receives the
actual body size (screen minus AppBar) — a systematic offset that looked
like "wrong object selected" rather than a crash, fixed by sourcing both
painting and hit-testing from the same `LayoutBuilder` constraints. A second
issue: `ScaleGestureRecognizer` claims gestures on finger-down, so a
separate `onTapUp` recognizer rarely won the gesture arena — selection is
now derived from `onScaleEnd`, treating "moved less than 8px" as a tap.

Rendering culls to the visible viewport via the quadtree, but drag updates
still trigger a broader `setState` rather than the scoped repaint pan/zoom
gets through `ViewportController` — extracting drag position into its own
notifier would close that gap. At larger scale, I'd move low-zoom rendering
to server-side clustering rather than raw points, and switch from
full-replace-per-fetch to a merged cache keyed by viewport region.

The backend is deployed on Render (Docker, same `Dockerfile` as local dev)
against MongoDB Atlas, so the tested and production environments are
identical. The main deployment trade-off is Render's free tier spinning
down after ~15 minutes of inactivity, adding latency to the first request.
