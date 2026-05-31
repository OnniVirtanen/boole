const std = @import("std");
const Io = std.Io;

const c = @import("c");

const boole = @import("boole");

pub fn main(init: std.process.Init) !void {
    _ = init;

    const ssh_session = c.ssh_new();
    if (ssh_session == null) {
        _ = c.printf("ssh session is null\n");
    }
    defer c.ssh_free(ssh_session);

    // for now just hardcode ubuntu to ssh_options
    _ = c.ssh_options_set(ssh_session, c.SSH_OPTIONS_HOST, "ubuntu");

    // parse ssh config
    if (c.ssh_options_parse_config(ssh_session, null) != 0) {
        std.debug.print("Warning: Could not parse SSH config file\n", .{});
    }

    // make a remote connection with ssh
    const remote_connection = c.ssh_connect(ssh_session);
    if (remote_connection != c.SSH_OK) {
        const err_msg = c.ssh_get_error(ssh_session);
        std.debug.print("Connection error: {s}\n", .{err_msg});
    }
    defer c.ssh_disconnect(ssh_session);

    std.debug.print("Successfully connected!\n", .{});

    // authenticate using public key
    const auth_res = c.ssh_userauth_publickey_auto(ssh_session, null, null);
    if (auth_res != c.SSH_AUTH_SUCCESS) {
        const err_msg = c.ssh_get_error(ssh_session);
        std.debug.print("Authentication failed: {s}\n", .{err_msg});
        return;
    }

    std.debug.print("Authentication successful! You are logged in.\n", .{});
}
