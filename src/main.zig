const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const proc = @import("proc.zig");

const Model = @import("Model.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const alloc = init.gpa;

    var buffer: [1024]u8 = undefined;
    var app: vxfw.App = try .init(io, alloc, init.environ_map, &buffer);
    defer app.deinit();

    run(init, &app) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return err;
    };
}

fn run(init: std.process.Init, app: *vxfw.App) !void {
    const alloc = init.gpa;
    const model = try alloc.create(Model);
    defer alloc.destroy(model);

    const cpu_usage = try proc.readCpuUsage(init);
    const ram_usage = try proc.readRamUsage(init);

    model.* = .{
        .cpu_usage = cpu_usage,
        .ram_usage = ram_usage,
        .button = .{
            .label = "Refresh",
            .onClick = onClick,
            .userdata = model,
        },
        .init = init,
    };

    try app.run(model.widget(), .{});
}

fn onClick(maybe_ptr: ?*anyopaque, ctx: *vxfw.EventContext) anyerror!void {
    const ptr = maybe_ptr orelse return;
    const self: *Model = @ptrCast(@alignCast(ptr));
    self.cpu_usage = try proc.readCpuUsage(self.init);
    self.ram_usage = try proc.readRamUsage(self.init);
    return ctx.consumeAndRedraw();
}
