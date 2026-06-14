const std = @import("std");

pub fn readCpuUsage(init: std.process.Init) !f32 {
    const file = try std.Io.Dir.cwd().openFile(init.io, "/proc/stat", .{ .mode = .read_only });
    defer file.close(init.io);

    var buffer: [1024]u8 = undefined;
    var reader = file.reader(init.io, &buffer);

    const contents = try reader.interface.readAlloc(std.heap.page_allocator, 1024);
    defer std.heap.page_allocator.free(contents);

    var it = std.mem.splitScalar(u8, contents, ' ');
    _ = it.next() orelse return -5.0;
    _ = it.next() orelse return -5.0;

    const user = try std.fmt.parseInt(u64, it.next() orelse return -10.0, 10);
    const nice = try std.fmt.parseInt(u64, it.next() orelse return -15.0, 10);
    const system = try std.fmt.parseInt(u64, it.next() orelse return -20.0, 10);
    const idle = try std.fmt.parseInt(u64, it.next() orelse return -25.0, 10);

    const total = user + nice + system + idle;
    if (total == 0) return 0.0;
    return 100.0 * @as(f32, @floatFromInt(user + nice + system)) / @as(f32, @floatFromInt(total));
}

pub fn readRamUsage(init: std.process.Init) !f32 {
    const file = try std.Io.Dir.cwd().openFile(init.io, "/proc/meminfo", .{ .mode = .read_only });
    defer file.close(init.io);

    var buffer: [1024]u8 = undefined;
    var reader = file.reader(init.io, &buffer);

    const contents = try reader.interface.readAlloc(std.heap.page_allocator, 1024);
    defer std.heap.page_allocator.free(contents);

    var it = std.mem.splitScalar(u8, contents, '\n');
    var total: u64 = 0;
    var available: u64 = 0;

    while (it.next()) |line| {
        if (std.mem.startsWith(u8, line, "MemTotal:")) {
            var line_it = std.mem.splitScalar(u8, line, ' ');
            _ = line_it.next();
            var buff = line_it.next();
            while (buff.?.len == 0) buff = line_it.next();
            total = try std.fmt.parseInt(u64, buff orelse return -5.0, 10);
        }
        if (std.mem.startsWith(u8, line, "MemAvailable:")) {
            var line_it = std.mem.splitScalar(u8, line, ' ');
            _ = line_it.next();
            var buff = line_it.next();
            while (buff.?.len == 0) buff = line_it.next();
            available = try std.fmt.parseInt(u64, buff orelse return -10.0, 10);
        }
    }

    if (total == 0) return @as(f32, @floatFromInt(available));
    return 100.0 * @as(f32, @floatFromInt(total - available)) / @as(f32, @floatFromInt(total));
}
