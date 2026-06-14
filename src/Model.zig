const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const proc = @import("proc.zig");

const Model = @This();

cpu_usage: std.atomic.Value(f32),
ram_usage: std.atomic.Value(f32),
button: vxfw.Button,
init: std.process.Init,
thread: std.Thread,
running: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),
ctx: ?*vxfw.EventContext,

pub fn widget(self: *Model) vxfw.Widget {
    return .{
        .userdata = self,
        .eventHandler = Model.typeErasedEventHandler,
        .drawFn = Model.typeErasedDrawFn,
    };
}

pub fn refreshLoop(model: *Model) void {
    while (model.running.raw) {
        const cpu = proc.readCpuUsage(model.init) catch continue;
        const ram = proc.readRamUsage(model.init) catch continue;

        model.cpu_usage.store(cpu, .seq_cst);
        model.ram_usage.store(ram, .seq_cst);
        if (model.ctx) |*ctx| {
            ctx.*.redraw = true;
        }
        model.init.io.sleep(.fromSeconds(1), .real) catch continue;
    }
}

fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext, event: vxfw.Event) anyerror!void {
    const self: *Model = @ptrCast(@alignCast(ptr));
    switch (event) {
        .init => {
            self.ctx = ctx;
            return ctx.requestFocus(self.button.widget());
        },
        .key_press => |key| {
            if (key.matches('q', .{ .ctrl = false })) {
                self.running.store(false, .seq_cst);
                ctx.quit = true;
                return;
            }
            if (key.matches('r', .{ .ctrl = false })) {
                const cpu = try proc.readCpuUsage(self.init);
                const ram = try proc.readRamUsage(self.init);

                self.cpu_usage.store(cpu, .seq_cst);
                self.ram_usage.store(ram, .seq_cst);
                return ctx.consumeAndRedraw();
            }
        },
        .focus_in => return ctx.requestFocus(self.button.widget()),
        .winsize => ctx.redraw = true,
        else => {},
    }
}

fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) std.mem.Allocator.Error!vxfw.Surface {
    const self: *Model = @ptrCast(@alignCast(ptr));
    const cpu_text = try std.fmt.allocPrint(ctx.arena, "CPU: {:.1}%", .{self.cpu_usage.raw});
    const cpu_label: vxfw.Text = .{ .text = cpu_text };

    const cpu_child: vxfw.SubSurface = .{
        .origin = .{ .row = 0, .col = 0 },
        .surface = try cpu_label.draw(ctx),
    };

    const ram_text = try std.fmt.allocPrint(ctx.arena, "RAM: {:.1}%", .{self.ram_usage.raw});
    const ram_label: vxfw.Text = .{ .text = ram_text };

    const ram_child: vxfw.SubSurface = .{
        .origin = .{ .row = 1, .col = 0 },
        .surface = try ram_label.draw(ctx),
    };

    const button_child: vxfw.SubSurface = .{
        .origin = .{ .row = 3, .col = 0 },
        .surface = try self.button.draw(ctx.withConstraints(
            ctx.min,
            .{ .width = 11, .height = 1 },
        )),
    };

    const children = try ctx.arena.alloc(vxfw.SubSurface, 3);
    children[0] = cpu_child;
    children[1] = ram_child;
    children[2] = button_child;

    return .{
        .size = ctx.max.size(),
        .widget = self.widget(),
        .buffer = &.{},
        .children = children,
    };
}
