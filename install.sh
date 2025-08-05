#!/bin/bash
# install.sh for Brazil3000

APP_NAME="Brazil3000"
SCRIPT_NAME="brazil3000"
BIN_DIR="$HOME/.local/bin"
APP_SUPPORT="$HOME/Library/Application Support/$APP_NAME"

echo "Installing Brazil3000..."

# Create directories
mkdir -p "$BIN_DIR"
mkdir -p "$APP_SUPPORT"

# Install the main script
cp brazil3000.sh "$BIN_DIR/$SCRIPT_NAME"
chmod +x "$BIN_DIR/$SCRIPT_NAME"

# Install data files (adjust these based on what files you have)
if [[ -d "data" ]]; then
    cp -r data/ "$APP_SUPPORT/"
fi

if [[ -f "config.txt" ]]; then
    cp config.txt "$APP_SUPPORT/"
fi

# Copy any other files your script needs
# cp -r assets/ "$APP_SUPPORT/" 
# cp *.json "$APP_SUPPORT/"

echo "✅ Brazil3000 installed successfully!"
echo
echo "📁 Executable: $BIN_DIR/$SCRIPT_NAME"
echo "📁 Data files: $APP_SUPPORT"
echo
echo "To use from anywhere, add this to your ~/.zshrc:"
echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
echo
echo "Then run: source ~/.zshrc"
echo "After that, you can run: brazil3000"
