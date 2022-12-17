const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const Server = @import("Server.zig");

pub const View = @import("Scene/View.zig");
pub const Output = @import("Scene/Output.zig");

const log = std.log.scoped(.scene);

const Scene = @This(); // {

renderer: *wlr.Renderer,
allocator: *wlr.Allocator,

xdg_shell: *wlr.XdgShell,
xwayland: *wlr.Xwayland,

output_layout: *wlr.OutputLayout,

outputs: wl.list.Head(Output, "link"),
views: wl.list.Head(View, "link"),

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

    // TODO: plug this into cursor
    self.output_layout = try wlr.OutputLayout.create();

    self.outputs.init();
    self.views.init();

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
    wlr_output: *wlr.Output,
) void {
    const self = Scene.fromListener("new_output", listener);

    log.debug("new output: {s}", .{wlr_output.name});

    if (!wlr_output.initRender(self.allocator, self.renderer)) {
        log.err("Failed to init render for output {s}", .{wlr_output.name});
        return;
    }

    if (wlr_output.preferredMode()) |mode| {
        wlr_output.setMode(mode);
        wlr_output.enable(true);
        wlr_output.commit() catch |err| {
            log.err("Failed initial commit for wlr_output {s}: {}", .{
                wlr_output.name,
                err,
            });
        };
    }

    // TODO: build output context and store reference...
    const output = Output.create(
        self.output_layout,
        wlr_output,
    ) catch |err| {
        log.err("Failed to allocate output ctx for {s}: {}", .{
            wlr_output.name,
            err,
        });
        return;
    };

    self.outputs.prepend(output);
}

// new_xdg_surface: wl.Listener(*wlr.XdgSurface),
fn handleNewXdgSurface(
    listener: *wl.Listener(*wlr.XdgSurface),
    xdg_surface: *wlr.XdgSurface,
) void {
    const self = Scene.fromListener("new_xdg_surface", listener);

    switch (xdg_surface.role) {
        .toplevel => {
            log.debug("new xdg toplevel surface: {s}", .{
                xdg_surface.role_data.toplevel.title orelse "(title unset)",
            });

            const view = &(View.XdgToplevel.create(
                xdg_surface.role_data.toplevel,
            ) catch |err| {
                log.err("failed to create xdg_toplevel view: {}", .{err});
                return;
            }).view;

            self.views.prepend(view);
        },
        .popup => {
            log.debug("new xdg popup surface", .{});
        },
        .none => unreachable,
    }
}

// new_xwayland_surface: wl.Listener(*wlr.XwaylandSurface),
fn handleNewXwaylandSurface(
    listener: *wl.Listener(*wlr.XwaylandSurface),
    xwayland_surface: *wlr.XwaylandSurface,
) void {
    const self = Scene.fromListener("new_xwayland_surface", listener);

    log.debug("new xwayland surface: {s}", .{
        xwayland_surface.title orelse "(title unset)",
    });

    _ = self;
}

// Util

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
