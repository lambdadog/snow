const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Server = @import("Server.zig");

const Scene = @This(); // {

backend: *wlr.Backend,
renderer: *wlr.Renderer,
allocator: *wlr.Allocator,

xdg_shell: *wlr.XdgShell,
xwayland: *wlr.Xwayland,

listeners: struct {
    new_output: wl.Listener(*wlr.Output),
    new_xdg_surface: wl.Listener(*wlr.XdgSurface),
    new_xwayland_surface: wl.Listener(*wlr.XwaylandSurface),

    fn init(self: *@This()) void {
        inline for (.{
            .{ "new_output", handleNewOutput },
            .{ "new_xdg_surface", handleNewXdgSurface },
            .{ "new_xwayland_surface", handleNewXwaylandSurface },
        }) |ldata| {
            @field(self, ldata.@"0").setNotify(ldata.@"1");
        }
    }
},

pub fn init(
    self: *Scene,
    wl_server: *wl.Server,
    backend: *wlr.Backend,
) !void {
    self.renderer = try wlr.Renderer.autocreate(backend);
    errdefer self.renderer.destroy();

    try self.renderer.initServer(wl_server);

    self.allocator = try wlr.Allocator.autocreate(
        backend,
        self.renderer,
    );
    errdefer self.allocator.destroy();

    const compositor = try wlr.Compositor.create(
        wl_server,
        self.renderer,
    );

    self.xdg_shell = try wlr.XdgShell.create(wl_server);

    self.xwayland = try wlr.Xwayland.create(
        wl_server,
        compositor,
        false,
    );
    errdefer self.xwayland.destroy();

    self.listeners.init();

    backend.events.new_output.add(&self.listeners.new_output);

    self.xdg_shell.events.new_surface.add(&self.listeners.new_xdg_surface);
    self.xwayland.events.new_surface.add(&self.listeners.new_xwayland_surface);
}

pub fn deinit(self: *Scene) void {
    self.xwayland.destroy();
    self.allocator.destroy();
    self.renderer.destroy();
}

// Handlers

// new_output: wl.Listener(*wlr.Output),
fn handleNewOutput(
    listener: *wl.Listener(*wlr.Output),
    output: *wlr.Output,
) void {
    const self = Scene.fromListener("new_output", listener);

    std.log.debug("new output: {s}", .{output.name});

    _ = self;
}

// new_xdg_surface: wl.Listener(*wlr.XdgSurface),
fn handleNewXdgSurface(
    listener: *wl.Listener(*wlr.XdgSurface),
    xdg_surface: *wlr.XdgSurface,
) void {
    const self = Scene.fromListener("new_xdg_surface", listener);

    switch (xdg_surface.role) {
        .toplevel => {
            std.log.debug("new xdg toplevel surface: {s}", .{
                xdg_surface.role_data.toplevel.title orelse "(title unset)",
            });
        },
        .popup => {
            std.log.debug("new xdg popup surface", .{});
        },
        .none => unreachable,
    }

    _ = self;
}

// new_xwayland_surface: wl.Listener(*wlr.XwaylandSurface),
fn handleNewXwaylandSurface(
    listener: *wl.Listener(*wlr.XwaylandSurface),
    xwayland_surface: *wlr.XwaylandSurface,
) void {
    const self = Scene.fromListener("new_xwayland_surface", listener);

    std.log.debug("new xwayland surface: {s}", .{
        xwayland_surface.title orelse "(title unset)",
    });

    _ = self;
}

// Util

inline fn server(self: *Scene) *Server {
    @fieldParentPtr(Server, "root", self);
}

inline fn fromListener(
    comptime listener_name: []const u8,
    listener_ptr: anytype,
) *@This() {
    switch (@typeInfo(@TypeOf(listener_ptr))) {
        .Pointer => return @fieldParentPtr(
            @This(),
            "listeners",
            @fieldParentPtr(
                Listeners: {
                    const s: @This() = undefined;
                    break :Listeners @TypeOf(s.listeners);
                },
                listener_name,
                listener_ptr,
            ),
        ),
        else => @compileError("listener_ptr should be a pointer"),
    }
}
