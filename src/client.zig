const std = @import("std");
const net = std.net;
const os = std.os;

const alloc = std.heap.page_allocator;
fn find(buf: []u8, char: u8) usize {
    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        if (buf[i] == char)
            return i;
    }
    return i;
}

pub fn create_udp_socket(address: std.net.Address) !os.socket_t {
    const sock_flags = os.SOCK.DGRAM | os.SOCK.CLOEXEC;
    const proto = os.IPPROTO.UDP;

    const fd = try os.socket(address.any.family, sock_flags, proto);
    errdefer {
        os.closeSocket(fd);
    }

    try os.setsockopt(
        fd,
        os.SOL.SOCKET,
        os.SO.REUSEADDR,
        &std.mem.toBytes(@as(c_int, 1)),
    );

    var socklen = address.getOsSockLen();
    try os.bind(fd, &address.any, socklen);

    return fd;
}

pub fn try_connection(src_addr: std.net.Address, dest_addr: std.net.Address) !void {
    const local = try create_udp_socket(src_addr);
    const msg = "Hello there";
    _ = try os.sendto(local, msg, 0, &dest_addr.any, @sizeOf(std.net.Address));

    var recv_address: std.net.Address = undefined;
    var socklen = recv_address.getOsSockLen();

    var buf: [100]u8 = undefined;
    const read = try os.recvfrom(local, &buf, 0, &recv_address.any, &socklen);
    std.log.info("Got: {s} from {}", .{ buf[0..read], recv_address });
}

pub fn main() anyerror!void {
    std.log.info("Client.", .{});
    var args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 3) {
        std.log.err("Usage: {s} [serverip] [serverport]", .{args[0]});
        return error.NotEnoughArguments;
    }

    var address = try std.net.Address.parseIp("0.0.0.0", 0); //Addr ANY, with ephemeral port
    const sockfd = try create_udp_socket(address);

    // Set server destination address
    const server_ip = args[1];
    const server_port = try std.fmt.parseInt(u16, args[2], 0);
    const dst_address = try std.net.Address.parseIp(server_ip, server_port);

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
    var target_addr = try std.net.Address.parseIp(ip_addr_str, port);

    var frames: [256]@Frame(try_connection) = undefined;
    var i: usize = 0;
    while (i < frames.len) : (i += 1) {
        var any_address = try std.net.Address.parseIp("0.0.0.0", 0); //Addr ANY, with ephemeral port

        frames[i] = async try_connection(any_address, target_addr);

        var prng = std.rand.DefaultPrng.init(0);
        const random = prng.random();

        target_addr.setPort(random.int(u16));
    }
    // Send hello
    {
        // address.setPort(address.getPort() + 1);
        // target_addr.setPort(target_addr.getPort() + 1);

        // const send_sockfd = blk: {
        //     const sock_flags = os.SOCK.DGRAM | os.SOCK.CLOEXEC;
        //     const proto = os.IPPROTO.UDP;

        //     const fd =
        //         try os.socket(address.any.family, sock_flags, proto);
        //     errdefer {
        //         os.closeSocket(fd);
        //     }

        //     try os.setsockopt(
        //         fd,
        //         os.SOL.SOCKET,
        //         os.SO.REUSEADDR,
        //         &std.mem.toBytes(@as(c_int, 1)),
        //     );
        //     break :blk fd;
        // };
        // std.log.info("binding to {}", .{address});
        // var socklen = address.getOsSockLen();
        // try os.bind(send_sockfd, &address.any, socklen);

        const message = "Hello, you there?";
        std.log.info("sending to: {s}", .{target_addr});
        _ = try os.sendto(sockfd, message, 0, &target_addr.any, @sizeOf(std.net.Address));

        // Listen for reply
        std.log.info("receiving", .{});
        var socklen = target_addr.getOsSockLen();
        const read2 = try os.recvfrom(sockfd, &buf, 0, &target_addr.any, &socklen);
        std.log.info("Got: {s}", .{buf[0..read2]});

        // Send hello again
        while (true) {
            std.time.sleep(100000000);
            std.log.info("sending to: {s}", .{target_addr});
            _ = try os.sendto(sockfd, message, 0, &target_addr.any, @sizeOf(std.net.Address));
        }
    }

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
