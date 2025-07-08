#!/bin/bash

# Change to the directory where this script is located
cd "$(dirname "$0")"


echo "Pulling latest changes..."
git pull

echo "Git operations complete."
read -p "Press Enter to continue..."