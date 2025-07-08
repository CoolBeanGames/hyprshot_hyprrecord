#!/bin/bash

# This script lists all local Git branches, allows the user to select one by number,
# and then switches to the chosen branch.

echo "--- Git Branch Lister and Switcher Script ---"

# --- 1. Check if inside a Git repository ---
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Error: You are not inside a Git repository."
    echo "Please navigate to your Git project directory before running this script."
    exit 1
fi

# --- 2. Get and Display All Local Branches ---
echo "Fetching local branches..."
# Get a list of local branches, remove whitespace, and store in an array
# The `sed 's/^\* //'` removes the asterisk from the current branch
# The `grep -v '^$'` removes empty lines
mapfile -t BRANCHES < <(git branch | sed 's/^\* //g' | grep -v '^$')

if [ ${#BRANCHES[@]} -eq 0 ]; then
    echo "No local branches found in this repository."
    echo "Please create a branch first using 'git branch <branch-name>'."
    exit 0
fi

echo ""
echo "Available local branches:"
for i in "${!BRANCHES[@]}"; do
    # Check if this is the current branch to mark it with an asterisk
    if [[ "$(git branch --show-current)" == "${BRANCHES[$i]}" ]]; then
        echo "$((i+1)). * ${BRANCHES[$i]}"
    else
        echo "$((i+1)).   ${BRANCHES[$i]}"
    fi
done
echo ""

# --- 3. Get User Input ---
read -p "Enter the number of the branch to switch to, or type the branch name directly: " USER_INPUT

TARGET_BRANCH=""

# Check if input is a number
if [[ "$USER_INPUT" =~ ^[0-9]+$ ]]; then
    INDEX=$((USER_INPUT - 1)) # Convert to 0-based index

    if (( INDEX >= 0 && INDEX < ${#BRANCHES[@]} )); then
        TARGET_BRANCH="${BRANCHES[$INDEX]}"
    else
        echo "Error: Invalid number. Please enter a number corresponding to an available branch."
        exit 1
    fi
else
    # Assume input is a branch name
    TARGET_BRANCH="$USER_INPUT"
    # Basic check if the typed branch name exists locally
    if ! git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
        echo "Warning: Branch '$TARGET_BRANCH' does not exist locally. Attempting to switch anyway."
        echo "If it's a remote branch, you might need to fetch it first: 'git fetch origin $TARGET_BRANCH'"
        echo "Or create it locally: 'git branch $TARGET_BRANCH'"
    fi
fi

# --- 4. Switch to the Target Branch ---
echo "Attempting to switch to branch '$TARGET_BRANCH'..."
git checkout "$TARGET_BRANCH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to switch to branch '$TARGET_BRANCH'."
    echo "Possible reasons: Uncommitted changes, branch does not exist, or an invalid branch name."
    echo "Please resolve any conflicts or ensure the branch exists."
    exit 1
fi

echo "Successfully switched to branch '$TARGET_BRANCH'."
echo "--- Script Finished ---"
git status # Show current status
