#!/bin/bash

# Git Worktree Branch Cleanup Script
# Usage: ./cleanup-branch.sh <branch-name> [--force]
#
# This script safely removes a git worktree and its associated branch
# Use --force flag to delete unmerged branches

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Check if branch name provided
if [ -z "$1" ]; then
    print_error "Usage: $0 <branch-name> [--force]"
    print_status "Example: $0 server"
    print_status "Example: $0 feature/auth --force"
    exit 1
fi

BRANCH=$1
FORCE_FLAG=$2
WORKTREE_PATH="../$BRANCH"

print_status "Starting cleanup for branch: $BRANCH"

# Check if we're in the main worktree
if [ ! -d ".git" ]; then
    print_error "This script must be run from the main git worktree directory"
    exit 1
fi

# Check if worktree exists
if [ -d "$WORKTREE_PATH" ]; then
    print_status "Removing worktree: $WORKTREE_PATH"
    if git worktree remove "$WORKTREE_PATH" 2>/dev/null; then
        print_success "Worktree removed successfully"
    else
        print_warning "Worktree removal failed or already removed"
    fi
else
    print_warning "Worktree directory not found: $WORKTREE_PATH"
fi

# Check if branch exists locally
if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    # Check if branch is merged (unless force flag is used)
    if [ "$FORCE_FLAG" = "--force" ]; then
        print_status "Force deleting branch: $BRANCH"
        if git branch -D "$BRANCH" 2>/dev/null; then
            print_success "Local branch force deleted"
        else
            print_error "Failed to force delete local branch"
        fi
    else
        print_status "Safely deleting merged branch: $BRANCH"
        if git branch -d "$BRANCH" 2>/dev/null; then
            print_success "Local branch deleted"
        else
            print_error "Branch is not merged. Use --force flag to delete anyway"
            print_warning "Or merge the branch first: git merge $BRANCH"
            exit 1
        fi
    fi
else
    print_warning "Local branch does not exist: $BRANCH"
fi

# Check and delete remote branch
print_status "Checking for remote branch: origin/$BRANCH"
if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    print_status "Deleting remote branch: origin/$BRANCH"
    if git push origin --delete "$BRANCH" 2>/dev/null; then
        print_success "Remote branch deleted"
    else
        print_warning "Failed to delete remote branch (may not have permission or already deleted)"
    fi
else
    print_warning "Remote branch does not exist: origin/$BRANCH"
fi

# Clean up any prunable worktrees
print_status "Pruning stale worktree references"
git worktree prune

print_success "Branch cleanup completed for: $BRANCH"
print_status "Current worktrees:"
git worktree list