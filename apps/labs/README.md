# PostgreSQL and Redis lab

Run `ducker start` if the Lima VM is stopped, then run `ducker lab start`. Docker Compose pulls the official images and waits for PostgreSQL and Redis to become healthy. `ducker lab status` shows their current state. The optional `data` argument names this lab explicitly, as in `ducker lab start data`.

| Service | Local address | Connection details |
| --- | --- | --- |
| PostgreSQL | `127.0.0.1:15432` | Database, username, and password are all `lab` |
| Redis | `127.0.0.1:16379` | Local development instance with no password |

With the client programs installed on your Mac, check the connections with `psql -h 127.0.0.1 -p 15432 -U lab -d lab -c 'SELECT 1'` and `redis-cli -h 127.0.0.1 -p 16379 PING`.

Set `LAB_POSTGRES_PORT` and `LAB_REDIS_PORT` when starting the lab to use different loopback ports. Use this if another process or Lima VM already uses the defaults.

```sh
LAB_POSTGRES_PORT=25432 LAB_REDIS_PORT=26379 ducker lab start
```

`ducker lab stop` removes the lab containers and network. PostgreSQL data and Redis append-only files persist in named volumes on the selected Lima instance. `ducker lab stop --volumes` also deletes those volumes and their data. Lab commands use `INSTANCE_NAME` and `LIMA_HOME` to select the Lima Docker socket.
