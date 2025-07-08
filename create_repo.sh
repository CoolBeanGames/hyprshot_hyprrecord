#!/bin/bash

# This script automates the creation of a new Git repository,
# initializes it, stages all files, commits them, and pushes
# to a new public GitHub repository using GitHub CLI.

echo "--- Git Repository Creation Script ---"

# --- 1. Get Directory Path ---
read -p "Enter the full path to the directory for your new repository (e.g., /home/user/my_project): " REPO_DIR

# Check if the directory exists
if [ ! -d "$REPO_DIR" ]; then
    read -p "Directory '$REPO_DIR' does not exist. Do you want to create it? (y/n): " CREATE_DIR_CONFIRM
    if [[ "$CREATE_DIR_CONFIRM" =~ ^[Yy]$ ]]; then
        mkdir -p "$REPO_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create directory '$REPO_DIR'. Exiting."
            exit 1
        fi
        echo "Directory '$REPO_DIR' created."
    else
        echo "Directory not created. Exiting."
        exit 1
    fi
fi

# Navigate into the directory
cd "$REPO_DIR" || { echo "Error: Could not change to directory '$REPO_DIR'. Exiting."; exit 1; }
echo "Navigated to: $(pwd)"

# --- 2. Get Repository Name ---
read -p "Enter the desired name for your new GitHub repository: " REPO_NAME

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Please install it using 'yay -S github-cli' (on Arch Linux) and then run 'gh auth login' to authenticate."
    exit 1
fi

# Check if gh CLI is authenticated (basic check)
# This is not foolproof, but a good first check.
if ! gh auth status &> /dev/null; then
    echo "Warning: GitHub CLI (gh) might not be authenticated."
    echo "Please run 'gh auth login' and follow the prompts to authenticate, then re-run this script."
    # Exit or continue? For automated repo creation, authentication is crucial.
    exit 1
fi

# --- 3. Initialize Git Repository ---
echo "Initializing local Git repository..."
git init
if [ $? -ne 0 ]; then
    echo "Error: Failed to initialize Git repository. Exiting."
    exit 1
fi
echo "Local Git repository initialized."

# --- 4. Stage All Files ---
echo "Staging all files in '$REPO_DIR'..."
git add .
if [ $? -ne 0 ]; then
    echo "Error: Failed to stage files. Exiting."
    exit 1
fi
echo "All files staged."

# --- 5. Commit Changes ---
echo "Committing staged files..."
git commit -m "Initial commit of $REPO_NAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to commit files. Exiting."
    exit 1
fi
echo "Files committed."

# --- 6. Create Remote Repository and Push ---
echo "Creating new public GitHub repository '$REPO_NAME' and pushing initial commit..."
# The --source=. flag tells gh to use the current directory as the source
# The --push flag pushes the current branch to the new remote
# The --public flag makes the repository public
gh repo create "$REPO_NAME" --public --source=. --push
if [ $? -ne 0 ]; then
    echo "Error: Failed to create remote repository or push to GitHub."
    echo "Please check your GitHub CLI authentication and try again."
    exit 1
fi

echo "--- Repository '$REPO_NAME' created and pushed successfully! ---"
echo "You can now view your repository at: https://github.com/$(gh api user | grep login | cut -d '"' -f 4)/$REPO_NAME"
echo "To continue working, simply 'cd $REPO_DIR' and start coding!"

