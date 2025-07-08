#!/bin/bash

# This script helps perform a Git merge operation.
# It lists local branches, prompts for a branch to merge,
# executes the merge, and provides guidance for conflicts.

echo "--- Git Merge Script ---"

# --- 1. Check if inside a Git repository ---
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Error: You are not inside a Git repository."
    echo "Please navigate to your Git project directory before running this script."
    exit 1
fi

# --- 2. Get Current Branch ---
CURRENT_BRANCH=$(git branch --show-current)
if [ -z "$CURRENT_BRANCH" ]; then
    echo "Error: Could not determine the current branch. Are you on a detached HEAD state?"
    exit 1
fi
echo "You are currently on branch: '$CURRENT_BRANCH'"
echo ""

# --- 3. Get and Display Other Local Branches for Merging ---
echo "Available local branches to merge (excluding current branch):"
# Get a list of local branches, filter out the current one, remove whitespace
mapfile -t MERGE_BRANCHES < <(git branch | sed 's/^\* //g' | grep -v "^$CURRENT_BRANCH$" | grep -v '^$')

if [ ${#MERGE_BRANCHES[@]} -eq 0 ]; then
    echo "No other local branches found to merge with."
    echo "Please create another branch first if you intend to merge."
    exit 0
fi

for i in "${!MERGE_BRANCHES[@]}"; do
    echo "$((i+1)). ${MERGE_BRANCHES[$i]}"
done
echo ""

# --- 4. Get User Input for Branch to Merge ---
read -p "Enter the number of the branch you want to merge INTO '$CURRENT_BRANCH', or type the branch name directly: " USER_INPUT

BRANCH_TO_MERGE=""

# Check if input is a number
if [[ "$USER_INPUT" =~ ^[0-9]+$ ]]; then
    INDEX=$((USER_INPUT - 1)) # Convert to 0-based index

    if (( INDEX >= 0 && INDEX < ${#MERGE_BRANCHES[@]} )); then
        BRANCH_TO_MERGE="${MERGE_BRANCHES[$INDEX]}"
    else
        echo "Error: Invalid number. Please enter a number corresponding to an available branch."
        exit 1
    fi
else
    # Assume input is a branch name
    BRANCH_TO_MERGE="$USER_INPUT"
    # Basic check if the typed branch name exists locally
    if ! git show-ref --verify --quiet "refs/heads/$BRANCH_TO_MERGE"; then
        echo "Error: Branch '$BRANCH_TO_MERGE' does not exist locally. Please choose an existing local branch."
        exit 1
    fi
fi

# Confirm merge
read -p "Are you sure you want to merge '$BRANCH_TO_MERGE' into '$CURRENT_BRANCH'? (y/n): " CONFIRM_MERGE
if [[ ! "$CONFIRM_MERGE" =~ ^[Yy]$ ]]; then
    echo "Merge cancelled by user. Exiting."
    exit 0
fi

# --- 5. Perform the Merge ---
echo "Attempting to merge branch '$BRANCH_TO_MERGE' into '$CURRENT_BRANCH'..."
git merge "$BRANCH_TO_MERGE"

MERGE_STATUS=$? # Capture the exit status of the merge command

# --- 6. Check Merge Result ---
if [ $MERGE_STATUS -eq 0 ]; then
    # Merge was successful (either fast-forward or a new merge commit)
    if git status | grep -q "nothing to commit, working tree clean"; then
        echo "Merge completed successfully (fast-forward or no changes)."
    else
        echo "Merge completed successfully. A new merge commit has been created."
    fi

    # Offer to push after successful merge
    read -p "Merge successful. Do you want to push your changes to the remote '$CURRENT_BRANCH' branch now? (y/n): " PUSH_CONFIRM
    if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Pushing changes to remote..."
        git push origin "$CURRENT_BRANCH"
        if [ $? -ne 0 ]; then
            echo "Warning: Failed to push changes. Please resolve manually if needed."
        else
            echo "Changes pushed successfully."
        fi
    else
        echo "Skipping push. Remember to push your changes later: 'git push origin $CURRENT_BRANCH'"
    fi

elif [ $MERGE_STATUS -ne 0 ] && git status | grep -q "Unmerged paths"; then
    # Merge resulted in conflicts
    echo ""
    echo "--- MERGE CONFLICTS DETECTED! ---"
    echo "The merge could not be completed automatically due to conflicts."
    echo "Please resolve the conflicts in the affected files manually."
    echo "You can use 'git status' to see the conflicted files."
    echo "After resolving, 'git add' the resolved files and then 'git commit' to complete the merge."
    echo "To abort the merge, run: 'git merge --abort'"
else
    # Other merge error (e.g., no common history, invalid branch)
    echo "Error: The merge operation failed for an unexpected reason."
    echo "Please check the output above for specific Git error messages."
fi

echo "--- Script Finished ---"
git status # Show final status
