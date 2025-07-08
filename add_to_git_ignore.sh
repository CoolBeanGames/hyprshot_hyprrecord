#!/bin/bash

# Change to the directory where this script is located
cd "$(dirname "$0")"

read -p "Enter the file type or pattern to add to .gitignore (e.g., *.log, temp/): " file_type

GITIGNORE_FILE=".gitignore"

# Check if .gitignore exists, create if not
if [ ! -f "$GITIGNORE_FILE" ]; then
    echo "Creating $GITIGNORE_FILE file..."
    touch "$GITIGNORE_FILE"
fi

# Check if the pattern already exists in .gitignore
if grep -Fxq "$file_type" "$GITIGNORE_FILE"; then
    echo "\"$file_type\" already exists in $GITIGNORE_FILE."
else
    echo "Adding \"$file_type\" to $GITIGNORE_FILE..."
    echo "$file_type" >> "$GITIGNORE_FILE"
    echo "$GITIGNORE_FILE updated."
fi

read -p "Press Enter to continue..."