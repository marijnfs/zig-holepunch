const std = @import("std");
const net = std.net;
const os = std.os;

pub fn main() anyerror!void {
    std.log.info("Server.", .{});

    const address = try std.net.Address.parseIp("0.0.0.0", 3001);
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

    var socklen = address.getOsSockLen();
    try os.bind(sockfd, &address.any, socklen);
    // try os.listen(sockfd, 0);
    // try os.getsockname(sockfd, &self.listen_address.any, &socklen);

    // var accepted_addr: std.net.Address = undefined;
    // var adr_len: os.socklen_t = @sizeOf(std.net.Address);
    // const fd = try os.accept(sockfd, &accepted_addr.any, &adr_len, os.SOCK.CLOEXEC);

    var first_address: std.net.Address = undefined;
    var second_address: std.net.Address = undefined;

    { //recv from first client
        var buf: [100]u8 = undefined;
        const read = try os.recv(sockfd, &buf, 0);

        try os.getsockname(sockfd, &first_address.any, &socklen);

        // std.log.info("{}", .{accepted_addr.any});
        std.log.info("First: {}", .{first_address});
        std.log.info("buf: {s}", .{buf[0..read]});
    }

    { //recv from second client
        var buf: [100]u8 = undefined;
        const read = try os.recv(sockfd, &buf, 0);
        try os.getsockname(sockfd, &second_address.any, &socklen);
        std.log.info("Second: {}", .{second_address});
        std.log.info("buf: {s}", .{buf[0..read]});

        const first_addr_str = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{first_address});
        const second_addr_str = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{second_address});

        _ = try os.sendto(sockfd, second_addr_str, 0, &first_address.any, @sizeOf(std.net.Address));
        _ = try os.sendto(sockfd, first_addr_str, 0, &second_address.any, @sizeOf(std.net.Address));
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
