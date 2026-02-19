//! algorithms_visually -- Interactive visualizations of bitwise algorithms.
//!
//! Three layers:
//!   algorithms/ -- Pure logic, no Raylib. User implements these.
//!   ui/         -- Reusable Raylib drawing components.
//!   viz/        -- Visualizations combining algorithms + UI.
const std = @import("std");

pub const algorithms = @import("algorithms/algorithms.zig");
pub const ui = @import("ui/ui.zig");
pub const viz = @import("viz/viz.zig");

test {
    // Force test discovery through all transitive imports.
    std.testing.refAllDeclsRecursive(@This());
}
