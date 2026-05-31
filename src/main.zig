const std = @import("std");
const Io = std.Io;
const c = @import("c");
const boole = @import("boole");

const Options = struct {
    host: ?[]const u8 = null,
    command: ?[]const u8 = null,
    inventory: ?[]const u8 = null,
    task: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var options = Options{};

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h")) {
            i += 1;
            if (i >= args.len) return error.MissingHostValue;
            options.host = args[i];
        } else if (std.mem.eql(u8, arg, "-c")) {
            i += 1;
            if (i >= args.len) return error.MissingCommandValue;
            options.command = args[i];
        } else if (std.mem.eql(u8, arg, "-i")) {
            i += 1;
            if (i >= args.len) return error.MissingInventoryValue;
            options.inventory = args[i];
        } else if (std.mem.eql(u8, arg, "-t")) {
            i += 1;
            if (i >= args.len) return error.MissingTaskValue;
            options.task = args[i];
        } else {
            std.debug.print("Unknown argument: {s}\n", .{arg});
            return;
        }
    }

    if (options.host != null and options.command != null) {
        try runSingleHostCommand(init.io, options.host.?, options.command.?);
    } else if (options.inventory != null and options.task != null) {
        try runGroupTask();
    } else {
        std.debug.print("Error: Invalid argument combinations.\n\n", .{});
    }
}

fn runSingleHostCommand(io: anytype, host: []const u8, command: []const u8) !void {
    std.debug.print("Connecting to host: {s}...\n", .{host});

    const ssh_session = c.ssh_new() orelse return error.SshInitFailed;
    defer c.ssh_free(ssh_session);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const c_host = try allocator.dupeSentinel(u8, host, 0);
    const c_command = try allocator.dupeSentinel(u8, command, 0);

    _ = c.ssh_options_set(ssh_session, c.SSH_OPTIONS_HOST, @ptrCast(c_host.ptr));

    if (c.ssh_options_parse_config(ssh_session, null) != 0) {
        std.debug.print("Warning: Could not parse SSH config file\n", .{});
    }

    const remote_connection = c.ssh_connect(ssh_session);
    if (remote_connection != c.SSH_OK) {
        const err_msg = c.ssh_get_error(ssh_session);
        std.debug.print("Connection error: {s}\n", .{err_msg});
        return error.SshConnectFailed;
    }
    defer c.ssh_disconnect(ssh_session);

    const auth_res = c.ssh_userauth_publickey_auto(ssh_session, null, null);
    if (auth_res != c.SSH_AUTH_SUCCESS) {
        const err_msg = c.ssh_get_error(ssh_session);
        std.debug.print("Authentication failed: {s}\n", .{err_msg});
        return error.SshAuthFailed;
    }

    std.debug.print("Authentication successful!\n", .{});

    const channel = c.ssh_channel_new(ssh_session) orelse return error.ChannelCreationFailed;
    defer c.ssh_channel_free(channel);

    if (c.ssh_channel_open_session(channel) != c.SSH_OK) {
        const err_msg = c.ssh_get_error(ssh_session);
        std.debug.print("Failed to open channel session: {s}\n", .{err_msg});
        return error.ChannelSessionOpenFailed;
    }
    defer _ = c.ssh_channel_close(channel);

    std.debug.print("Executing: \"{s}\"\n---\n", .{command});
    if (c.ssh_channel_request_exec(channel, @ptrCast(c_command.ptr)) != c.SSH_OK) {
        const err_msg = c.ssh_get_error(ssh_session);
        std.debug.print("Failed to request execution: {s}\n", .{err_msg});
        return error.CommandExecutionFailed;
    }

    var buffer: [4096]u8 = undefined;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer = @TypeOf(io).File.Writer.init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    while (true) {
        const bytes_read = c.ssh_channel_read(channel, &buffer, buffer.len, 0);

        if (bytes_read < 0) {
            std.debug.print("Error encountered while reading from channel\n", .{});
            return error.ChannelReadFailed;
        }

        if (bytes_read == 0) break;

        const slice_len: usize = @intCast(bytes_read);
        try stdout_writer.writeAll(buffer[0..slice_len]);
    }

    try stdout_writer.flush();
    _ = c.ssh_channel_send_eof(channel);
}

fn runGroupTask() !void {
    return error.NotImplementedError;
}
