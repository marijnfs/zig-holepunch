# Zig based UDP holepunching to create a TCP connection


# Building:
zig build

# Usage on server side
```Bash
./zig-out/bin/zig-holepunch-server 3000
```

# Usage on client sides (x 2)
```Bash
./zig-out/bin/zig-holepunch 0.0.0.0 3000
```

Ip Address _0.0.0.0_ is used here for localhost, replace it with the ip of the server
