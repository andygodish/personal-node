# Electrs Configuration(electrs.toml)

To pass a custom configuration file (electrs.toml) to the Electrs container, you can mount it into the container at runtime.

1. Create a custom electrs.toml file on your host machine in the root of this project directory and add your desired configuration options.

2. Add a docker config block to the bottom of the docker-compose.yaml file in the root of this project directory:

```yaml
# docker-compose.yaml

configs:
  custom_electrs_conf:
    file: ./electrs.toml
```

3. Update the electrs service in the docker-compose.yaml file to use the custom configuration under the configs section:

```yaml
# docker-compose.yaml

services:
  electrs:
    ...
    configs:
      - source: custom_electrs_conf
        target: /data/electrs.toml # <-- Corresponds to the working directory (/data/) where electrs automatically checks for overrides
```
