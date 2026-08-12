# Initial Tor Setup With Docker Compose

This deployment uses a manual Tor onion service for Bitcoin P2P reachability. The Tor container owns the onion service keys and forwards onion traffic to the Core container on port `8333`.

The first startup can happen on a fresh machine with empty Docker volumes. Core may begin initial block download, but Tor does not need IBD to complete before it creates the onion hostname. Tor only needs its `tor_data_dir` volume to be writable so it can create `/var/lib/tor/knots-p2p/hostname`.

## First Run: Generate the Onion Hostname

Build the local Tor image from the sibling repository before starting the personal-node stack:

```bash
cd ../image-tor
make build
cd ../personal-node
```

Start the bootstrap stack without a node-local `bitcoin.conf` override:

```bash
make up-bootstrap-onion
```

Tor should generate the onion service hostname shortly after the Tor container starts. Core can still be syncing blocks while this happens. Print the hostname with:

```bash
make tor-hostname
```

If the hostname is not available yet, wait briefly and run the command again. The hostname is stored in the `tor_data_dir` Docker volume at `knots-p2p/hostname`.

At this point, the node is reachable through that onion address for inbound Bitcoin P2P connections. Tor accepts the onion connection and forwards it to `core:8333` on the Docker network.

## Second Run: Advertise the Onion Address

The first run makes the onion address exist. To make Core advertise that onion address as one of its local reachable addresses, create a node-local `bitcoin.conf` override from the committed example:

```bash
cp bitcoin.conf.example bitcoin.conf
```

Edit `bitcoin.conf`, uncomment `externalip`, and replace the placeholder with the generated onion hostname:

```conf
externalip=<your-generated-onion-hostname>
```

The example preserves the baked image defaults, including `listen=1`. The real `bitcoin.conf` is ignored by Git because it contains machine-local node configuration.

Start the steady-state stack with the node-local config override:

```bash
make up
```

After this point, `make up` is the normal command for subsequent starts and updates.

You can verify Core sees the onion address with `getnetworkinfo`; the address should appear under `localaddresses` after Core starts with the override.

## Optional Outbound Onion Connections

The manual onion service is enough for inbound reachability. If you also want Core to use Tor for outbound onion peers, add this to the same `bitcoin.conf` override:

```conf
onion=tor:9050
```

If you want all outbound Bitcoin P2P traffic to use the Tor SOCKS proxy, use `proxy=tor:9050` instead. When using `proxy`, keep `listen=1` set if you still want inbound listening.

## Notes

- Do not expose Electrs through this onion service by default. Electrs remains available on the existing local/LAN `50001` port.
- Do not add unrelated services to the Bitcoin P2P onion service. Use a separate onion service for each distinct service.
- The onion hostname is stable as long as the `tor_data_dir` Docker volume is preserved. Removing the Tor volume generates a new onion address.
