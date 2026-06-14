const std = @import("std");
const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Model = @This();

count: u32 = 0,
cpu_usage: f32 = 0.0,
ram_usage: f32 = 0.0,
button: vxfw.Button,

pub fn widget(self: *Model) vxfw.Widget {
    return .{
        .userdata = self,
        .eventHandler = Model.typeErasedEventHandler,
        .drawFn = Model.typeErasedDrawFn,
    };
}

fn typeErasedEventHandler(ptr: *anyopaque, ctx: *vxfw.EventContext, event: vxfw.Event) anyerror!void {
    const self: *Model = @ptrCast(@alignCast(ptr));
    switch (event) {
        .init => return ctx.requestFocus(self.button.widget()),
        .key_press => |key| {
            if (key.matches('q', .{ .ctrl = false })) {
                ctx.quit = true;
                return;
            }
        },
        .focus_in => return ctx.requestFocus(self.button.widget()),
        else => {},
    }
}

fn typeErasedDrawFn(ptr: *anyopaque, ctx: vxfw.DrawContext) std.mem.Allocator.Error!vxfw.Surface {
    const self: *Model = @ptrCast(@alignCast(ptr));
    const cpu_text = try std.fmt.allocPrint(ctx.arena, "CPU: {:.1}%", .{self.cpu_usage});
    const cpu_label: vxfw.Text = .{ .text = cpu_text };

    const cpu_child: vxfw.SubSurface = .{
        .origin = .{ .row = 0, .col = 0 },
        .surface = try cpu_label.draw(ctx),
    };

    const ram_text = try std.fmt.allocPrint(ctx.arena, "RAM: {:.1}%", .{self.ram_usage});
    const ram_label: vxfw.Text = .{ .text = ram_text };

    const ram_child: vxfw.SubSurface = .{
        .origin = .{ .row = 1, .col = 0 },
        .surface = try ram_label.draw(ctx),
    };

    const button_child: vxfw.SubSurface = .{
        .origin = .{ .row = 3, .col = 0 },
        .surface = try self.button.draw(ctx.withConstraints(
            ctx.min,
            .{ .width = 16, .height = 3 },
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
