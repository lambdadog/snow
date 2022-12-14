const std = @import("std");

pub fn main() anyerror!void {
    std.debug.print("Hello, {s}!\n", .{"Snow"});
}
