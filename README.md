# boole
Boole is an infrastructure configuration tool written in Zig.

> The tool is a work in progress.

## Quickstart

Boole has two major concepts.

*Host* - A target server.

*Task* - Logical grouping of one or more operations.

## Example

Run a shell command for a single host.

```sh
boole -h debian.internal -c "chmod 755 file.txt"
```

Run a task for a host.

```sh
boole -h debian.internal -t task.zig
```

## Install

### Building from source

Requirements for client:
- [Zig (0.16)](https://ziglang.org/learn/getting-started/)
- [libssh](https://www.libssh.org/)
- Linux

---

Clone the repository

```sh
git clone git@github.com:OnniVirtanen/boole.git
```

Build from source

```sh
zig build
```

Set PATH environment variable (.profile, .zshrc, ...)

```sh
export PATH=$PATH:~/path/to/boole
```

## Testing

Run all tests

```sh
zig build test
```