#!/bin/bash

# Change to the directory where this script is located
cd "$(dirname "$0")"

read -p "Enter the Git repository URL (e.g., https://github.com/user/repo.git or git@github.com:user/repo.git): " repo_url

echo "Cloning repository from \"$repo_url\" into the current directory..."
git clone "$repo_url"

if [ $? -eq 0 ]; then
    echo "Repository cloned successfully!"
else
    echo "Error: Failed to clone the repository."
    echo "Please check the URL and your Git setup."
fi

read -p "Press Enter to continue..."