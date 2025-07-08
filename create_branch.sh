#!/bin/bash

# This script creates a new Git branch and optionally switches to it.

echo "--- Git Branch Creation Script ---"

# --- 1. Check if inside a Git repository ---
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Error: You are not inside a Git repository."
    echo "Please navigate to your Git project directory before running this script."
    exit 1
fi

# --- 2. Get New Branch Name ---
read -p "Enter the name for your new branch: " NEW_BRANCH_NAME

# Validate branch name (basic check for empty name)
if [ -z "$NEW_BRANCH_NAME" ]; then
    echo "Error: Branch name cannot be empty. Exiting."
    exit 1
fi

# --- 3. Create the New Branch ---
echo "Creating branch '$NEW_BRANCH_NAME'..."
git branch "$NEW_BRANCH_NAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create branch '$NEW_BRANCH_NAME'. It might already exist or the name is invalid."
    exit 1
fi
echo "Branch '$NEW_BRANCH_NAME' created successfully."

# --- 4. Ask to Switch to New Branch ---
read -p "Do you want to switch to the new branch '$NEW_BRANCH_NAME' now? (y/n): " SWITCH_CONFIRM

if [[ "$SWITCH_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Switching to branch '$NEW_BRANCH_NAME'..."
    git checkout "$NEW_BRANCH_NAME"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to switch to branch '$NEW_BRANCH_NAME'."
        exit 1
    fi
    echo "Successfully switched to branch '$NEW_BRANCH_NAME'."
else
    echo "Staying on the current branch. You can switch later using: git checkout $NEW_BRANCH_NAME"
fi

echo "--- Script Finished ---"
git status # Show current status
