#!/usr/bin/env bash
set -euo pipefail

if [ $# -gt 1 ]; then
    echo "Usage: $0 [version]"
    echo "Examples:"
    echo "  $0           # Update to latest version from npm"
    echo "  $0 2.0.26    # Update to specific version"
    exit 1
fi

# Fetch version from npm registry if not provided
if [ $# -eq 0 ]; then
    echo "Fetching latest version from npm registry..."
    VERSION=$(curl -s https://registry.npmjs.org/@anthropic-ai/claude-code | grep -oP '"latest"\s*:\s*"\K[^"]+')

    if [ -z "$VERSION" ]; then
        echo "Error: Failed to fetch latest version from npm registry"
        exit 1
    fi

    echo "Latest version: $VERSION"
else
    VERSION="$1"
    echo "Using specified version: $VERSION"
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

echo "Updating claude-code to version $VERSION..."

# Step 1: Update version in package.nix
echo "→ Updating version in package.nix..."
sed -i "s/version = \".*\";/version = \"$VERSION\";/" "$PACKAGE_NIX"

# Step 2: Fetch source tarball and calculate hash
echo "→ Fetching source tarball..."
URL="https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${VERSION}.tgz"
SRC_HASH=$(nix-prefetch-url --unpack "$URL")
SRC_HASH_SRI=$(nix hash convert --hash-algo sha256 --to sri "$SRC_HASH")
echo "  Source hash: $SRC_HASH_SRI"

# Update source hash in package.nix
sed -i "s|hash = \"sha256-.*\";|hash = \"$SRC_HASH_SRI\";|" "$PACKAGE_NIX"

# Step 3: Generate package-lock.json from source
echo "→ Generating package-lock.json..."
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Download and extract the tarball to get package.json
TARBALL="$TEMP_DIR/claude-code.tgz"
curl -sL "$URL" -o "$TARBALL"
tar -xzf "$TARBALL" -C "$TEMP_DIR"

# Generate package-lock.json
cd "$TEMP_DIR/package"
AUTHORIZED=1 npm install --package-lock-only

# Copy package-lock.json to repo
cp package-lock.json "$SCRIPT_DIR/package-lock.json"
echo "  Saved package-lock.json to $SCRIPT_DIR/package-lock.json"

# Step 4: Calculate npmDepsHash
echo "→ Calculating npmDepsHash..."
NPM_DEPS_HASH=$(nix-shell -p prefetch-npm-deps --run "prefetch-npm-deps package-lock.json")
echo "  npmDepsHash: $NPM_DEPS_HASH"

# Update npmDepsHash in package.nix
sed -i "s|npmDepsHash = \"sha256-.*\";|npmDepsHash = \"$NPM_DEPS_HASH\";|" "$PACKAGE_NIX"

echo "✓ Successfully updated to version $VERSION"
echo ""
echo "Updated hashes:"
echo "  hash = \"$SRC_HASH_SRI\""
echo "  npmDepsHash = \"$NPM_DEPS_HASH\""
