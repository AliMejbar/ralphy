#!/bin/bash
# Install script for Ralphy and create-prd

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing Ralphy and create-prd...${NC}"

# Make scripts executable
chmod +x "$SCRIPT_DIR/ralphy.sh"
chmod +x "$SCRIPT_DIR/create-prd.sh"

# Detect shell config file
SHELL_CONFIG=""
if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_CONFIG="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_CONFIG="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
  SHELL_CONFIG="$HOME/.bash_profile"
fi

# Check if already in PATH
PATH_EXPORT="export PATH=\"$SCRIPT_DIR:\$PATH\""

if [[ -n "$SHELL_CONFIG" ]]; then
  if grep -q "$SCRIPT_DIR" "$SHELL_CONFIG" 2>/dev/null; then
    echo -e "${YELLOW}PATH already configured in $SHELL_CONFIG${NC}"
  else
    echo "" >> "$SHELL_CONFIG"
    echo "# Ralphy AI scripts" >> "$SHELL_CONFIG"
    echo "$PATH_EXPORT" >> "$SHELL_CONFIG"
    echo -e "${GREEN}✓ Added to PATH in $SHELL_CONFIG${NC}"
  fi
else
  echo -e "${YELLOW}Could not detect shell config file.${NC}"
  echo "Add this to your shell config manually:"
  echo "  $PATH_EXPORT"
fi

# Add upstream remote if not exists
if ! git -C "$SCRIPT_DIR" remote | grep -q upstream; then
  git -C "$SCRIPT_DIR" remote add upstream https://github.com/michaelshimeles/ralphy.git
  echo -e "${GREEN}✓ Added upstream remote for syncing${NC}"
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "To use immediately, run:"
echo -e "  ${BLUE}source $SHELL_CONFIG${NC}"
echo ""
echo "Then from any project directory:"
echo -e "  ${BLUE}create-prd.sh \"Add user authentication\"${NC}"
echo -e "  ${BLUE}ralphy.sh${NC}"
echo ""
echo "To sync with upstream updates:"
echo -e "  ${BLUE}cd $SCRIPT_DIR && git fetch upstream && git merge upstream/main${NC}"
