#!/bin/bash

# Change to the directory where this script is located
cd "$(dirname "$0")"

read -p "Enter commit message: " commit_msg

echo "Staging all changes..."
git add .

echo "Committing changes..."
git commit -m "$commit_msg"

echo "Pushing changes..."
git push

echo "Git operations complete."
read -p "Press Enter to continue..."