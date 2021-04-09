## bind deadlock

This repo contains docker image to reproduce a deadlock with concurrent rndc addzone/delzone commands

### How to reproduce

```bash
$ docker build -f Dockerfile.916 -t bind-deadlock:916 .
$ docker run --rm -it --name bind-deadlock-916 --cap-add=SYS_PTRACE bind-deadlock:916
```

If bind becomes unreachable for 30s a backtrace will be generated and the last logs will be displayed

You can then exec gdb in another shell to debug the deadlocked named instance.

```bash
$ docker exec -it bind-deadlock-916 bash
root@cccfd8fea3a8:/# gdb -p $(cat /var/run/named/named.pid) /usr/sbin/named
```