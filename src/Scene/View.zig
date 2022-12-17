const std = @import("std");

const wl = @import("wayland").server.wl;
const wlr = @import("wlroots");

const log = std.log.scoped(.view);

const View = @This(); // {

pub const XdgToplevel = @import("View/XdgToplevel.zig");

pub const VTable = struct {
    destroy: *const fn (*View) void,
};

link: wl.list.Link,

vtable: VTable,

listeners: struct {
    fn init(self: *@This()) void {
        _ = self;
    }
},

pub fn init(self: *View, vtable: VTable) void {
    self.vtable = vtable;

    self.listeners.init();
}

pub fn deinit(self: *View) void {
    _ = self;
}

pub fn destroy(self: *View) void {
    self.vtable.destroy(self);
}

// Handlers

