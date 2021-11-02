const std = @import("std");
const net = std.net;
const os = std.os;

fn find(buf: []u8, char: u8) usize {
    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        if (buf[i] == char)
            return i;
    }
    return i;
}

pub fn main() anyerror!void {
    std.log.info("Client.", .{});
    var args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    const my_port = try std.fmt.parseInt(u16, args[1], 0);

    const address = try std.net.Address.parseIp("0.0.0.0", my_port);
    const sock_flags = os.SOCK.DGRAM | os.SOCK.CLOEXEC;
    const proto = os.IPPROTO.UDP;

    const sockfd = try os.socket(address.any.family, sock_flags, proto);
    errdefer {
        os.closeSocket(sockfd);
    }

    try os.setsockopt(
        sockfd,
        os.SOL.SOCKET,
        os.SO.REUSEADDR,
        &std.mem.toBytes(@as(c_int, 1)),
    );

    const dst_address = try std.net.Address.parseIp("0.0.0.0", 3001);

    var buf: [100]u8 = undefined;
    _ = try os.sendto(sockfd, &buf, 0, &dst_address.any, @sizeOf(std.net.Address));

    const read = try os.recv(sockfd, &buf, 0);

    if (read != 0) { //we will connect
        std.time.sleep(1000000000);
        var ip_buf = buf[0..read];
        const sep = find(ip_buf, ':');
        const ip_addr_str = ip_buf[0..sep];
        const port = try std.fmt.parseInt(u16, buf[sep + 1 .. read], 0);

        const target_addr = try std.net.Address.parseIp(ip_addr_str, port);
        std.log.info("target addr: {s}", .{target_addr});

        var stream_connection = try net.tcpConnectToAddress(target_addr);
        _ = try stream_connection.write("test");
    } else { //we will receive
        var stream_server = std.net.StreamServer.init(net.StreamServer.Options{ .reuse_address = true });
        try stream_server.listen(address);
        var stream_connection = try stream_server.accept();
        var len = try stream_connection.stream.read(&buf);
        std.log.info("got tcp msg: {s}", .{buf[0..len]});
    }

    // _ = try os.sendto(sockfd, &buf, 0, &target_addr.any, @sizeOf(std.net.Address));

    // var other_address: std.net.Address = undefined;
    // try os.getsockname(sockfd, &other_address.any, &socklen);

    // std.log.info("{}", .{accepted_addr.any});
    // std.log.info("{}", .{other_address.any});
    // std.log.info("buf: {s}", .{buf[0..read]});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
