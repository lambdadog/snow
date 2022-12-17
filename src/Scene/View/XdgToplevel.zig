const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const ally = @import("../../main.zig").ally;
const log = std.log.scoped(.view);

const View = @import("../View.zig");

const XdgToplevel = @This(); // {

view: View,

xdg_toplevel: *wlr.XdgToplevel,

listeners: struct {
    destroy: wl.Listener(*wlr.XdgSurface),
    map: wl.Listener(*wlr.XdgSurface),
    unmap: wl.Listener(*wlr.XdgSurface),
    new_popup: wl.Listener(*wlr.XdgPopup),
    new_subsurface: wl.Listener(*wlr.Subsurface),

    ack_configure: wl.Listener(*wlr.XdgSurface.Configure),
    commit: wl.Listener(*wlr.Surface),

    fn init(self: *@This()) void {
        inline for (.{
            .{ "destroy", handleDestroy },
            .{ "map", handleMap },
            .{ "unmap", handleUnmap },
            .{ "new_popup", handleNewPopup },
            .{ "new_subsurface", handleNewSubsurface },

            .{ "ack_configure", handleAckConfigure },
            .{ "commit", handleCommit },
        }) |ldata| {
            @field(self, ldata.@"0").setNotify(ldata.@"1");
        }
    }
},

pub fn create(xdg_toplevel: *wlr.XdgToplevel) !*XdgToplevel {
    const self = try ally.create(XdgToplevel);
    errdefer ally.destroy(self);

    self.view.init(.{
        .destroy = &VTableImpl.destroy,
    });

    self.xdg_toplevel = xdg_toplevel;

    self.listeners.init();

    // Add base listeners
    self.xdg_toplevel.base.events.destroy.add(&self.listeners.destroy);
    self.xdg_toplevel.base.events.map.add(&self.listeners.map);
    self.xdg_toplevel.base.events.unmap.add(&self.listeners.unmap);
    self.xdg_toplevel.base.events.new_popup.add(&self.listeners.new_popup);
    self.xdg_toplevel.base.surface.events.new_subsurface.add(
        &self.listeners.new_subsurface,
    );

    return self;
}

pub fn destroy(self: *XdgToplevel) void {
    self.listeners.destroy.link.remove();
    self.listeners.map.link.remove();
    self.listeners.unmap.link.remove();
    self.listeners.new_popup.link.remove();
    self.listeners.new_subsurface.link.remove();

    // destroy subsurfaces and popups

    self.view.deinit();

    ally.destroy(self);
}

// Handlers

// destroy: wl.Listener(void),
fn handleDestroy(
    listener: *wl.Listener(*wlr.XdgSurface),
    _: *wlr.XdgSurface,
) void {
    const self = XdgToplevel.fromListener("destroy", listener);

    log.debug("destroy", .{});

    self.destroy();
}

// map: wl.Listener(void),
fn handleMap(
    listener: *wl.Listener(*wlr.XdgSurface),
    _: *wlr.XdgSurface,
) void {
    const self = XdgToplevel.fromListener("map", listener);

    log.debug("map", .{});

    self.xdg_toplevel.base.events.ack_configure.add(
        &self.listeners.ack_configure,
    );
    self.xdg_toplevel.base.surface.events.commit.add(
        &self.listeners.commit,
    );

    var box: wlr.Box = undefined;
    self.xdg_toplevel.base.getGeometry(&box);

    //box.y = @divTrunc(std.math.max(0,
}

// unmap: wl.Listener(void),
fn handleUnmap(
    listener: *wl.Listener(*wlr.XdgSurface),
    _: *wlr.XdgSurface,
) void {
    const self = XdgToplevel.fromListener("unmap", listener);

    log.debug("unmap", .{});

    _ = self;
}

// new_popup: wl.Listener(*wlr.XdgPopup),
fn handleNewPopup(
    listener: *wl.Listener(*wlr.XdgPopup),
    xdg_popup: *wlr.XdgPopup,
) void {
    const self = XdgToplevel.fromListener("new_popup", listener);

    log.debug("new_popup", .{});

    _ = self;
    _ = xdg_popup;
}

// new_subsurface: wl.Listener(*wlr.Subsurface),
fn handleNewSubsurface(
    listener: *wl.Listener(*wlr.Subsurface),
    xdg_subsurface: *wlr.Subsurface,
) void {
    const self = XdgToplevel.fromListener("new_subsurface", listener);

    log.debug("new_subsurface", .{});

    _ = self;
    _ = xdg_subsurface;
}

// ack_configure: wl.Listener(*wlr.XdgSurface.Configure),
fn handleAckConfigure(
    listener: *wl.Listener(*wlr.XdgSurface.Configure),
    configure: *wlr.XdgSurface.Configure,
) void {
    const self = XdgToplevel.fromListener("ack_configure", listener);
    _ = self;
    _ = configure;
}

// commit: wl.Listener(*wlr.Surface),
fn handleCommit(
    listener: *wl.Listener(*wlr.Surface),
    wlr_surface: *wlr.Surface,
) void {
    const self = XdgToplevel.fromListener("commit", listener);
    _ = self;
    _ = wlr_surface;
}

// View vtable implementation

const VTableImpl = struct {
    fn destroy(view: *View) void {
        const self = @fieldParentPtr(XdgToplevel, "view", view);
        self.destroy();
    }
};

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
