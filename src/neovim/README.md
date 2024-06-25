# Neovim as default terminal IDE (nvim)

Set up Neovim for development

## Example Usage
You can use the feature in the `.devcontainer/devcontainer.json` of your project as follows:
```json
{
  "features": {
    "./feat/nvim": {
    }
  }
}
```

## Options
| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Choose which Neovim version to use | string | stable |
| build_type | Choose which build type to use | string | appimage |
| link_host_config | Whether to link the host config folder [$HOME/.config/nvim] to the container | boolean | false |

