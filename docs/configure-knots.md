# Knots Configuration (`bitcoin.conf`)

To pass a custom configuration file (`bitcoin.conf`) to the Bitcoin Knots container, you can mount it into the container at runtime. 

1. Create a custom `bitcoin.conf` file on your host machine in the root of this project directory and add your desired configuration options.

2. Add a docker config block to the bottom of the `docker-compose.yaml` file in the root of this project directory:

```yaml
# docker-compose.yaml

configs:
  custom_bitcoin_conf:
    file: ./bitcoin.conf
```

3. Update the `knots` service in the `docker-compose.yaml` file to use the custom configuration under the `configs` section:

```yaml
# docker-compose.yaml

services:
  knots:
    ...
    configs:
      - source: custom_bitcoin_conf
        target: /home/bitcoin/.bitcoin/bitcoin.conf # <-- This location corresponds to the bitcoind data-dir (/home/bitcoin/.bitcoin/)
```
