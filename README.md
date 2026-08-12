# Personal Node

Run a containerized Bitcoin Core node, Electrum server, and Tor onion service for Bitcoin P2P reachability.

## Configuration

The **Bitcoin Core**, **Electrs**, and **Tor** images ship with opinionated default configuration.

If you need to override or extend these default settings, you can do so at deploy time without modifying the underlying images. See the [docs](docs) directory for instructions on how to customize the configuration files for each service.

## Image Compatibility Contract

This deployment assumes the paired **Bitcoin Core**, **Electrs**, and **Tor** images expose a stable runtime interface. These values are intentionally used by `docker-compose.yaml` and the Makefile volume permission helpers.

| Component | Requirement |
| --- | --- |
| `bitcoin-core` | Runs as UID/GID `10001:10001` |
| `bitcoin-core` | Uses datadir `/home/bitcoin/.bitcoin` |
| `bitcoin-core` | Writes the RPC auth cookie at `/home/bitcoin/.bitcoin/.cookie` |
| `electrs` | Runs as UID/GID `10002:10002` by default |
| `electrs` | Can run with group access to GID `10001` for read-only access to Core data |
| `electrs` | Reads Bitcoin Core data mounted at `/bitcoin-data` |
| `electrs` | Stores its RocksDB index at `/db` |
| `tor` | Runs as UID/GID `10003:10003` |
| `tor` | Stores Tor state and onion service keys at `/var/lib/tor` |
| `tor` | Creates a Bitcoin P2P onion hostname at `/var/lib/tor/knots-p2p/hostname` |
| `docker-compose.yaml` | Uses the `core` service name for Docker DNS resolution from Electrs and Tor |

Docker named volumes store numeric file ownership, so the host machine does not need matching users or groups. The container images and deployment scripts only need these numeric IDs and paths to remain stable.

## Tor Onion Service

The Tor service uses the local image `tor:v0.4.9.11-0_deb13u1-0` by default and does not pull from a registry. Build `../image-tor` locally before starting the stack, or override the image with `TOR_IMAGE`.

Tor exposes only the Bitcoin P2P port as a v3 onion service. Electrs remains available through the existing local/LAN `50001` port and is not exposed over Tor by default. After the stack is running and Tor has initialized, print the node onion hostname with:

```bash
make tor-hostname
```

The generated hostname is stored in the `tor_data_dir` Docker volume. The active Bitcoin Core data is stored in the Compose-managed `personal-node_bitcoin_data_dir` volume; the old global `bitcoin_data_dir` volume is intentionally left untouched for a future Knots stack. See [Initial Tor Setup With Docker Compose](docs/initial-tor-setup.md) for the first-run and second-run flow.
