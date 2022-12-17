const std = @import("std");

const Server = @import("Server.zig");

pub const ally = std.heap.c_allocator;

pub fn main() anyerror!void {
    var server: Server = undefined;
    try server.init();
    defer server.deinit();

    try server.backend.start();

    std.log.info("WAYLAND_DISPLAY is {s}", .{server.getWaylandDisplay()});
    std.log.info("DISPLAY is {s}", .{server.getX11Display()});

    std.log.info("starting server...", .{});
    server.wl_server.run();
    std.log.info("shutting down...", .{});
}
