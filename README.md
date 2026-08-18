# cloud-select

Combine Google Cloud CLI (`gcloud`) and Azure CLI (`az`) profile switching into a single, clean shell script. Sourcing this file defines both `gcloud-select` and `azurecli-select` helper functions, complete with full tab-completion under **Zsh** and **Bash**.

- GCP profiles default directory: `~/.config/gcloud.d`
- Azure profiles default directory: `~/.config/azure.d`

You can use the environment variable `CLOUD_CLI_PROFILE_DIR` to override the default parent directory (`~/.config`).

---

## How It Works

### Google Cloud CLI (`gcloud-select`)
The Google Cloud CLI keeps all of its state (configuration, credentials, active project, and cache) in one directory—`~/.config/gcloud` by default. Defining the standard `CLOUDSDK_CONFIG` environment variable points `gcloud` to a chosen profile directory, keeping separate identities isolated.

A *profile* is just a subdirectory of `~/.config/gcloud.d/` (or your customized profile root) holding one such configuration:

```
~/.config/gcloud.d
|-- personal
|   |-- active_config
|   |-- configurations
|   |   `-- config_default
|   |-- credentials.db
|   `-- ...
`-- work
    |-- active_config
    |-- configurations
    |   `-- config_default
    |-- credentials.db
    `-- ...
```

### Azure CLI (`azurecli-select`)
The Azure CLI keeps all of its state (`config`, `azureProfile.json`, the MSAL token cache, and logs) in `~/.azure` by default. Defining `AZURE_CONFIG_DIR` points the CLI to a chosen profile directory.

A *profile* is just a subdirectory of `~/.config/azure.d/` (or your customized profile root) holding one such configuration:

```
~/.config/azure.d
|-- personal
|   |-- azureProfile.json
|   |-- config
|   |-- msal_token_cache.json
|   `-- ...
`-- work
    |-- azureProfile.json
    |-- config
    |-- msal_token_cache.json
    `-- ...
```

---

## Install

The script must be **sourced**, not executed, because it exports variables directly into your active shell session.

1. Run the installer to copy the setup script:
   ```sh
   ./install.sh
   ```
2. Add the following line to your shell configuration file:

   - **Zsh** (in `~/.zshrc`):
     *Note: Place the line after `compinit`, otherwise completion registration is skipped and a warning is printed to stderr.*
     ```sh
     source ~/.cloud-select.sh
     ```

   - **Bash** (in `~/.bashrc`):
     ```sh
     source ~/.cloud-select.sh
     ```

### Requirements
- Zsh with its completion system initialised, or **Bash 5.2 or newer**.
- `jq` version 1.7 or newer (needed for `azurecli-select show` and `env`).

---

## Configuration

### Customizing Profile Directories
By default, profiles are stored in:
- `~/.config/gcloud.d` for GCP
- `~/.config/azure.d` for Azure

You can override the default `~/.config` base directory by setting the `CLOUD_CLI_PROFILE_DIR` environment variable before sourcing the script:

```sh
export CLOUD_CLI_PROFILE_DIR="$HOME/.my-cloud-profiles"
```
With the above override, your profiles will default to:
- `$HOME/.my-cloud-profiles/gcloud.d`
- `$HOME/.my-cloud-profiles/azure.d`

Alternatively, you can override each profile root individually with:
- `GCLOUD_PROFILE_ROOT` (defaults to `$CLOUD_CLI_PROFILE_DIR/gcloud.d`)
- `AZURECLI_PROFILE_ROOT` (defaults to `$CLOUD_CLI_PROFILE_DIR/azure.d`)

---

## Usage

### Google Cloud CLI (`gcloud-select`)

| Command | Effect |
| --- | --- |
| `gcloud-select select <profile>` | Export `CLOUDSDK_CONFIG=$GCLOUD_PROFILE_ROOT/<profile>` |
| `gcloud-select select` | Unset `CLOUDSDK_CONFIG`, so the gcloud CLI uses `~/.config/gcloud` |
| `gcloud-select show` | Print the active configuration of the selected profile |
| `gcloud-select help` | Print usage information |

```console
$ gcloud-select select work
Selected gcloud CLI profile: work

$ gcloud auth login        # credentials saved in work profile only

$ gcloud-select select     # back to default
```

### Azure CLI (`azurecli-select`)

| Command | Effect |
| --- | --- |
| `azurecli-select select <profile>` | Export `AZURE_CONFIG_DIR=$AZURECLI_PROFILE_ROOT/<profile>` |
| `azurecli-select select` | Unset `AZURE_CONFIG_DIR`, so the Azure CLI uses `~/.azure` |
| `azurecli-select show` | Print the signed-in context of the selected profile |
| `azurecli-select env` | Export `AZURE_SUBSCRIPTION_ID` and `AZURE_TENANT_ID` |
| `azurecli-select help` | Print usage information |

```console
$ azurecli-select select work
Selected Azure CLI profile: work

$ az login                 # credentials saved in work profile only

$ azurecli-select env      # export AZURE_SUBSCRIPTION_ID and AZURE_TENANT_ID

$ azurecli-select select   # back to default
```

### Tab Completion
Press <kbd>Tab</kbd> after typing `gcloud-select` or `azurecli-select` to list the commands. Press <kbd>Tab</kbd> after `select` to automatically complete the profiles that already exist in your profile directory.

---

## License

MIT, see [LICENSE](LICENSE).
