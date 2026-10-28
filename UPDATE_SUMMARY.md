# Recording Studio kit pins

Read from `recording_studio_mcp_ui.gemspec`, `Gemfile`, and `test/dummy/Gemfile`.

| Source | Gem | Pin |
| --- | --- | --- |
| gemspec | rails | `~> 8.1.0` |
| gemspec | recording_studio | `~> 4.2` |
| gemspec | view_component | `>= 3.0` |
| gemspec | required Ruby | `>= 3.3.0` |
| root Gemfile | recording_studio | GitHub tag `v4.6.0` |
| dummy Gemfile | rails | `~> 8.1.1` |
| dummy Gemfile | recording_studio | GitHub tag `v4.7.0` |
| dummy Gemfile | recording_studio_accessible | GitHub tag `v0.18.0` |
| dummy Gemfile | recording_studio_admin | GitHub tag `v2.3.0` |
| dummy Gemfile | recording_studio_api | GitHub tag `v0.7.0` |
| dummy Gemfile | recording_studio_mcp | GitHub tag `v0.13.1` |
| dummy Gemfile | recording_studio_oauth | GitHub tag `v0.10.1` |
| dummy Gemfile | recording_studio_user | GitHub tag `v0.21.0` |
| dummy Gemfile | recording_studio_attachable | GitHub tag `v0.15.0` |
| dummy Gemfile | recording_studio_metrics | GitHub tag `v0.2.3` |
| dummy Gemfile | recording_studio_trashable | GitHub tag `v0.11.0` |
| dummy Gemfile | recording_studio_cache | GitHub tag `v0.5.0` |
| dummy Gemfile | recording_studio_site_settings | GitHub tag `v0.2.0` |
| dummy Gemfile | recording_studio_root_switchable | GitHub tag `v0.9.0` |
| dummy Gemfile | flat_pack | GitHub tag `v0.1.213` |

- Authenticated dummy layout: `RecordingStudio::UsesDefaultLayout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
- Optional example mixin: `include RecordingStudio::Capabilities::Example.to(**opts)` wraps `RecordingStudio::Capabilities.include_for`. Installing the gem does not enable it globally.
