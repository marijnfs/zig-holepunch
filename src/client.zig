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

    if (args.len < 3) {
        std.log.err("Usage: {s} [serverip] [serverport]", .{args[0]});
        return error.NotEnoughArguments;
    }

    var address = try std.net.Address.parseIp("0.0.0.0", 0); //Addr ANY, with ephemeral port
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

    // Set server destination address
    const server_ip = args[1];
    const server_port = try std.fmt.parseInt(u16, args[2], 0);
    const dst_address = try std.net.Address.parseIp(server_ip, server_port);
    {
        var socklen = address.getOsSockLen();
        try os.bind(sockfd, &address.any, socklen);
    }

    {
        var socklen = address.getOsSockLen();
        try os.getsockname(sockfd, &address.any, &socklen);
        std.log.info("Current address: {}", .{address});
    }

    // Send nonsense package
    std.log.info("Sending Address packet to {}", .{dst_address});
    var buf: [100]u8 = undefined;
    _ = try os.sendto(sockfd, &buf, 0, &dst_address.any, @sizeOf(std.net.Address));

    // Receive address of other client
    const read = try os.recv(sockfd, &buf, 0);

    // Parse the ip
    var ip_buf = buf[0..read];
    const sep = find(ip_buf, ':');
    const ip_addr_str = ip_buf[0..sep];
    const port = try std.fmt.parseInt(u16, buf[sep + 1 .. read], 0);
    const target_addr = try std.net.Address.parseIp(ip_addr_str, port);

    // Send hello
    std.log.info("sending to: {s}", .{target_addr});
    const message = "Hello, you there?";
    _ = try os.sendto(sockfd, message, 0, &target_addr.any, @sizeOf(std.net.Address));

    // Listen for reply
    std.log.info("receiving", .{});
    const read2 = try os.recv(sockfd, &buf, 0);
    std.log.info("Got: {s}", .{buf[0..read2]});

    // Start Tcp connection
    // if (read != 0) { //we will connect
    //     std.time.sleep(100000000);
    //     std.log.info("sending", .{});
    //     var ip_buf = buf[0..read];
    //     const sep = find(ip_buf, ':');
    //     const ip_addr_str = ip_buf[0..sep];
    //     const port = try std.fmt.parseInt(u16, buf[sep + 1 .. read], 0);

    //     const target_addr = try std.net.Address.parseIp(ip_addr_str, port);
    //     std.log.info("target addr: {s}", .{target_addr});

    //     var stream_connection = try net.tcpConnectToAddress(target_addr);
    //     const msg = "test";
    //     std.log.info("Sending message: {s}", .{msg});
    //     _ = try stream_connection.write(msg);
    // } else { //we will receive
    //     std.log.info("receiving on {}", .{address});
    //     var stream_server = std.net.StreamServer.init(net.StreamServer.Options{ .reuse_address = true });
    //     try stream_server.listen(address);
    //     var stream_connection = try stream_server.accept();
    //     var len = try stream_connection.stream.read(&buf);
    //     std.log.info("Got TCP message: {s}", .{buf[0..len]});
    // }
}
