# Personal Node

Run a containerized Bitcoin node and Electrum server. 

## Configuration

Both **Bitcoin Knots** and **Electrs** images ship with an opinionated default configuration.

If you need to override or extend these default settings, you can do so at deploy time without modifying the underlying images. See the [./docs](docs directory) for instructions on how to customize the configuration files for each service.

## Image Compatibility Contract

This deployment assumes the paired **Bitcoin Knots** and **Electrs** images expose a stable runtime interface. These values are intentionally used by `docker-compose.yaml` and the Makefile volume permission helpers.

| Component | Requirement |
| --- | --- |
| `bitcoin-knots` | Runs as UID/GID `10001:10001` |
| `bitcoin-knots` | Uses datadir `/home/bitcoin/.bitcoin` |
| `bitcoin-knots` | Writes the RPC auth cookie at `/home/bitcoin/.bitcoin/.cookie` |
| `electrs` | Runs as UID/GID `10002:10002` by default |
| `electrs` | Can run with group access to GID `10001` for read-only access to Knots data |
| `electrs` | Reads Bitcoin data mounted at `/bitcoin-data` |
| `electrs` | Stores its RocksDB index at `/db` |
| `docker-compose.yaml` | Uses the `knots` service name for Docker DNS resolution from electrs |

Docker named volumes store numeric file ownership, so the host machine does not need matching users or groups. The container images and deployment scripts only need these numeric IDs and paths to remain stable.
