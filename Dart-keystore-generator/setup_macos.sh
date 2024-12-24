#!/bin/bash
# setup.sh - For Linux/MacOS

echo "Setting up Keystore Manager..."

# Get the current directory
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to detect shell configuration file
detect_shell_config() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        echo "$HOME/.bashrc"
    else
        echo "$HOME/.profile"
    fi
}

SHELL_CONFIG=$(detect_shell_config)

# Add to PATH if not already present
if ! grep -q "$CURRENT_DIR" "$SHELL_CONFIG"; then
    echo "export PATH=\"\$PATH:$CURRENT_DIR\"" >> "$SHELL_CONFIG"
    echo "Added to PATH in $SHELL_CONFIG"
fi

# Activate the package globally
dart pub global activate --source path .

echo
echo "Setup completed successfully!"
echo "You can now use the 'keystore' command from anywhere."
echo "Please run 'source $SHELL_CONFIG' or restart your terminal for changes to take effect."