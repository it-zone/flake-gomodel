# flake-gomodel

Nix flake for [GoModel](https://github.com/ENTERPILOT/GoModel), an OpenAI- and Anthropic-compatible AI gateway written in Go.

This repository packages GoModel and provides a NixOS module for running it as a systemd service.

## Flake outputs

| Output | Description |
| --- | --- |
| `packages.<system>.gomodel` | GoModel package (default package). |
| `packages.<system>.default` | Alias of `gomodel`. |
| `overlays.default` | Overlay adding `gomodel` to `pkgs`. |
| `nixosModules.gomodel` | NixOS module for `services.gomodel` (also sets the default package from this flake). |
| `nixosModules.default` | Alias of `nixosModules.gomodel`. |

Supported systems: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`.

## Package

The package builds GoModel `v0.2.5` from upstream with:

- Go module build (`buildGo127Module`)
- vendored Go and npm dependencies
- prebuilt dashboard assets from `web/dashboard`
- release metadata embedded via `ldflags`
- `mainProgram = "gomodel"`

Upstream project: <https://github.com/ENTERPILOT/GoModel>

## Usage

### Run the package

```bash
nix run github:it-zone/flake-gomodel
# or, from a local checkout
nix run .#
```

### Use in a NixOS configuration

```nix
{
  inputs.gomodel.url = "github:it-zone/flake-gomodel";

  outputs = { nixpkgs, gomodel, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        gomodel.nixosModules.default
        ({ ... }: {
          services.gomodel = {
            enable = true;
            port = 8080;
            openFirewall = true;

            # Secrets / API keys should come from environment files, not the Nix store.
            environmentFiles = [ "/run/secrets/gomodel.env" ];

            settings = {
              providers = [
                {
                  name = "openai";
                  type = "openai";
                  api_key = "$OPENAI_API_KEY";
                }
              ];
            };
          };
        })
      ];
    };
  };
}
```

### Use the overlay

```nix
{
  nixpkgs.overlays = [ inputs.gomodel.overlays.default ];
  environment.systemPackages = [ pkgs.gomodel ];
}
```

## NixOS module options (`services.gomodel`)

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enable` | boolean | `false` | Enable the GoModel service. |
| `package` | package | `pkgs.gomodel` | GoModel package to run. The flake module sets this to the flake's packaged build by default. |
| `stateDir` | path | `/var/lib/gomodel` | State/working directory used for runtime data (database, pid, media, cache, etc.). |
| `port` | port | `8080` | HTTP listen port. Exported to the service as `PORT` and used for firewall opening. |
| `settings` | YAML attrset (freeform) | `{ }` | GoModel configuration rendered to `config.yaml`. See upstream docs for supported keys: <https://github.com/ENTERPILOT/GoModel>. |
| `settings.port` | null or port | `null` | Convenience option mapped to `server.port` in the generated YAML. If `null`, no `server.port` key is written. The top-level `port` key is removed before serialization. |
| `environmentFiles` | list of paths | `[ ]` | Files passed to systemd as `EnvironmentFile=` (in order; later files override earlier ones for the same variable). Intended for secrets such as API keys. |
| `openFirewall` | boolean | `false` | Open `services.gomodel.port` in `networking.firewall.allowedTCPPorts`. |

## Service behavior

When enabled, the module defines `systemd.services.gomodel` with:

- `ExecStart` running the `gomodel` binary.
- Generated config written to the Nix store and symlinked to `${stateDir}/config.yaml` (GoModel auto-discovers `config.yaml` in its working directory).
- `WorkingDirectory`/state managed under `services.gomodel.stateDir` (`StateDirectory=gomodel`, mode `0700`).
- `Environment = "PORT=${toString services.gomodel.port}"` set unconditionally. Per systemd semantics, `Environment=` overrides `EnvironmentFile=`, so `services.gomodel.port` is the effective listen-port knob.
- `DynamicUser=true` and a restrictive hardening profile.
- `Restart=on-failure` with a 5 second delay.
- `network.target` ordering and `wantedBy = [ "multi-user.target" ]`.

## Notes

- Put secrets in `environmentFiles` rather than directly in Nix settings to avoid storing them in the Nix store.
- GoModel provider/config keys are passed through `services.gomodel.settings` as YAML; consult the upstream GoModel documentation for the full schema and supported providers/features.
- A `tmpfiles` rule creates `stateDir` with mode `0700`.

## License

This flake repository is licensed under the MIT License (see [`LICENSE`](./LICENSE)). GoModel itself is upstream software under its own license.
