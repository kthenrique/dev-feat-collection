# Neovim as default terminal IDE (nvim)

Set up Neovim for development

## Example Usage
You can use the feature in the `.devcontainer/devcontainer.json` of your project as follows:
```json
{
  "features": {
    "ghcr.io/kthenrique/dev-feat-collection/neovim:latest": {
    }
  }
}
```

## Options
| Options Id | Description | Type | Default Value | Other Possible Values |
|-----|-----|-----|-----|-----|
| version | Choose which Neovim version to use | string | stable | stable, v0.10.0, v0.9.5, etc |
| build_type | Choose which build type to use | string | appimage | source, prebuilt, apt |
| nvim_config | Which config to use. This may be set to host (for bind-mounting the host config), base (for a minimum configuration project specific) or a git repository | string | host | base, \<url-to-a-git-repo\> |

