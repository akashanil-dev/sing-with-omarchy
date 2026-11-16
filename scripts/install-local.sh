#!/usr/bin/env bash
# Install the committed local build alongside existing plugins.
set -euo pipefail

source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
plugin_id=akash.sing-with-omarchy
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"
config_file="$HOME/.config/omarchy/shell.json"

if [[ $(omarchy-shell shell ping) != ok ]]; then
    echo 'Run this from a terminal inside your running Omarchy desktop session.' >&2
    exit 1
fi
omarchy plugin validate "$source_dir"
if [[ -e "$plugin_dir" || -L "$plugin_dir" ]]; then
    echo "Already present: $plugin_dir. No files were replaced." >&2
    exit 1
fi
if [[ -n $(git -C "$source_dir" status --porcelain) ]]; then
    echo 'The source checkout has uncommitted changes. Commit them before installing.' >&2
    exit 1
fi

backup_dir="$HOME/.local/state/sing-with-omarchy/backups"
mkdir -p "$backup_dir"
if [[ -f "$config_file" ]]; then
    backup_file=$(mktemp "$backup_dir/shell-$(date +%Y%m%d-%H%M%S)-XXXXXX.json")
    cp -p "$config_file" "$backup_file"
    echo "Bar configuration backup: $backup_file"
fi

mkdir -p "$(dirname "$plugin_dir")"
git clone --no-hardlinks --single-branch --branch main -- "$source_dir" "$plugin_dir"
omarchy plugin validate "$plugin_dir"
omarchy-shell shell rescanPlugins >/dev/null
discovered=false
for ((attempt=0; attempt<40; attempt++)); do
    if omarchy plugin list --json | jq -e --arg id "$plugin_id" 'any(.[]; .id == $id)' >/dev/null; then
        discovered=true
        break
    fi
    sleep 0.1
done
if [[ $discovered != true ]]; then
    echo "Files installed, but the shell has not discovered $plugin_id. Existing plugins are unchanged." >&2
    exit 1
fi
omarchy plugin enable "$plugin_id" --section right
if ! jq -e --arg id "$plugin_id" '[.bar.layout[]?[]? | select(.id == $id)] | length > 0' "$config_file" >/dev/null; then
    echo 'The plugin was copied, but its enabled bar entry could not be verified.' >&2
    exit 1
fi
echo "Installed $(git -C "$plugin_dir" rev-parse --short HEAD). Click the music-note button in the right bar."
echo "Disable this trial with: omarchy plugin disable $plugin_id"
echo 'This checkout updates from the local source folder. Your other plugins were not replaced.'
