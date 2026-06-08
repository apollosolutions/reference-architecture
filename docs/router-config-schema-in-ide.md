# Day 0: wire up `router.yaml` autocomplete and validation in your IDE

> Five minutes of setup that catches half the config mistakes before the Router ever starts. Tracks [AS-333](https://apollographql.atlassian.net/browse/AS-333).

Apollo Router can emit a JSON Schema of its config from the running binary. Pointing your IDE at the generated schema gives you autocomplete on key paths, hover-help with the field descriptions, and inline errors on typos or invalid values. Far cheaper than discovering the same problems at `router start`.

## Generate the schema from your installed Router

The schema is **not published as a URL or release asset**. Generate it from the same Router binary you'll be running, so the schema matches your installed version exactly:

```bash
./router config schema > .apollo/router-config-schema.json
```

Commit `.apollo/router-config-schema.json` next to your `router.yaml` so the whole team gets the same hints, and regenerate it whenever you bump the Router version (a CI step works well — fail PRs if the generated file diverges from the committed copy).

If you want to know which version you're targeting:

```bash
./router --version                                              # local binary
gh release list --repo apollographql/router --limit 1           # latest published tag
gh release view --repo apollographql/router --json tagName -q .tagName   # just the tag string
```

## VS Code

Install the [`redhat.vscode-yaml`](https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml) extension if you don't already have it, then in your project's `.vscode/settings.json`:

```jsonc
{
  "yaml.schemas": {
    "./.apollo/router-config-schema.json": [
      "router.yaml",
      "router/*.yaml",
      "deploy/**/router*.yaml"
    ]
  }
}
```

Save, open `router.yaml`, and start typing — you'll get completion on top-level keys (`authentication`, `traffic_shaping`, `telemetry`, …) and on nested ones once you've committed to a section.

For a workspace-wide setup that everyone gets without per-clone fiddling, commit both the schema file and the `.vscode/settings.json` block.

## JetBrains (IntelliJ, GoLand, PyCharm, RustRover)

JetBrains IDEs ship YAML schema support natively.

1. **Preferences → Languages & Frameworks → Schemas and DTDs → JSON Schema Mappings**.
2. **+** to add a new mapping.
3. **Name**: `Apollo Router`.
4. **Schema file or URL**: point at `./.apollo/router-config-schema.json` in your repo.
5. **Schema version**: JSON Schema 7 (the default works).
6. **File path patterns**: add `router.yaml`, `router/*.yaml`, and any other globs that match your layout.

The mappings file lives at `.idea/jsonSchemas.xml` — commit it to get the same effect cross-clone (or document the steps in your project README so each contributor can replicate).

## Neovim / Vim with `coc-yaml` or `yaml-language-server`

If you're running `coc-yaml`, add to `:CocConfig`:

```jsonc
{
  "yaml.schemas": {
    "./.apollo/router-config-schema.json": [
      "router.yaml",
      "router/*.yaml"
    ]
  }
}
```

Direct `yaml-language-server` via `lspconfig` honours the same `yaml.schemas` block in `settings`.

## Inline `# yaml-language-server: $schema=` directive

If you can't change project settings (e.g. you're editing someone else's repo on a quick fix), the schema directive at the top of the file is also supported by `yaml-language-server`:

```yaml
# yaml-language-server: $schema=./.apollo/router-config-schema.json
authentication:
  router:
    jwt:
      jwks:
        - url: https://example.com/jwks.json
```

The directive applies only to the file it's in.

## Verifying it's wired

Type an obvious typo in the YAML — e.g. `authetnication:` — and you should see an inline diagnostic. Hover over a key (e.g. `traffic_shaping.timeout`) and you should see the description from the schema.

If nothing shows up:

- IDE caches schemas. Re-open the file or restart the LSP server.
- Check the URL responds — paste it in a browser.
- For JetBrains: confirm the file matches the configured glob (the right-hand sidebar shows which schema is currently mapped).

## See also

- [Apollo Router YAML configuration reference](https://www.apollographql.com/docs/graphos/routing/configuration/yaml)
- [Router CLI reference](https://www.apollographql.com/docs/graphos/routing/configuration/cli) — `router config schema` and related commands
- [yaml-language-server schema directive docs](https://github.com/redhat-developer/yaml-language-server#using-inlined-schema)
- [Router releases](https://github.com/apollographql/router/releases) — get the right tag for your installed version
