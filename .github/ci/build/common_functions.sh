#!/usr/bin/env bash

# Common functions for iOS/macOS build scripts
# This file contains reusable functions for version validation

# Function: Normalize branch references to plain branch names
# Returns: Branch name without common ref prefixes
normalize_branch_name() {
    local branch_name="$1"

    branch_name=$(echo "$branch_name" | sed \
        -e 's|^refs/remotes/origin/||' \
        -e 's|^refs/heads/||' \
        -e 's|^remotes/origin/||' \
        -e 's|^origin/||')

    echo "$branch_name"
}

# Function: Get current git branch name
# Tries multiple methods to determine the branch name in CI environments
# Returns: Branch name without common ref prefixes
get_branch_name() {
    local branch_name=""
    
    # Method 1: Try the explicit Jenkins branch parameter first.
    # Jenkins checks out a detached HEAD, so inferring from branches containing
    # HEAD can pick an unrelated release branch before main.
    if [ ! -z "$api_examples_shengwang_branch" ]; then
        branch_name="$api_examples_shengwang_branch"
        echo "Branch from api_examples_shengwang_branch: $branch_name" >&2
    elif [ ! -z "$GIT_BRANCH" ]; then
        branch_name="$GIT_BRANCH"
        echo "Branch from GIT_BRANCH: $branch_name" >&2
    elif [ ! -z "$BRANCH_NAME" ]; then
        branch_name="$BRANCH_NAME"
        echo "Branch from BRANCH_NAME: $branch_name" >&2
    elif [ ! -z "$CI_COMMIT_REF_NAME" ]; then
        branch_name="$CI_COMMIT_REF_NAME"
        echo "Branch from CI_COMMIT_REF_NAME: $branch_name" >&2
    # Method 2: Try git command
    else
        branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [ "$branch_name" = "HEAD" ]; then
            echo "Detached HEAD without explicit branch; skipping branch inference" >&2
            branch_name=""
        else
            echo "Branch from git rev-parse: $branch_name" >&2
        fi
    fi
    
    branch_name=$(normalize_branch_name "$branch_name")
    
    echo "$branch_name"
}

# Function: Extract version from branch name
# Args:
#   $1 - Branch name
# Returns: Version string (e.g., "4.6.2") or empty if no version is present
extract_branch_version() {
    local branch_name="$1"
    
    if [[ $branch_name =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Function: Validate version between branch name and project file
# Args:
#   $1 - Path to project.pbxproj file
#   $2 - Branch name (optional, will auto-detect if not provided)
#   $3 - Platform (optional: "ios" or "macos", defaults to "ios")
# Returns: 0 on success, 1 on failure
validate_version() {
    local pbxproj_file="$1"
    local branch_name="${2:-$(get_branch_name)}"
    local platform="${3:-ios}"
    
    echo "Starting branch version validation..."
    
    if [ -z "$branch_name" ] || [ "$branch_name" = "HEAD" ]; then
        echo "Warning: Unable to get Git branch name, skipping version validation"
        return 0
    fi

    # Skip version check for main branch (we trust main when building from it)
    if [ "$branch_name" = "main" ]; then
        echo "Branch is main, skipping version validation (main branch is trusted)"
        return 0
    fi

    echo "Current branch: $branch_name"

    # Extract version from branch name (for example: dev/x.x.x or release/x.x.x)
    local branch_version=$(extract_branch_version "$branch_name")
    
    if [ -z "$branch_version" ]; then
        echo "Error: Branch name does not contain version number!"
        echo "Current branch: $branch_name"
        echo "Branch name must contain x.x.x (e.g., dev/4.6.2, release/4.6.2)"
        return 1
    fi
    
    echo "Branch version: $branch_version"
    
    # Check if project.pbxproj file exists
    if [ ! -f "$pbxproj_file" ]; then
        echo "Error: project.pbxproj file not found: $pbxproj_file"
        return 1
    fi
    
    # Extract MARKETING_VERSION for main target (skip Extension targets)
    # iOS uses @executable_path/Frameworks, macOS uses @executable_path/../Frameworks
    local plist_version=""
    if [ "$platform" = "macos" ]; then
        plist_version=$(grep -A 2 "@executable_path/../Frameworks" "$pbxproj_file" | grep "MARKETING_VERSION" | head -1 | sed 's/.*MARKETING_VERSION = \([^;]*\);/\1/' | tr -d ' ')
    else
        plist_version=$(grep -A 2 "@executable_path/Frameworks" "$pbxproj_file" | grep "MARKETING_VERSION" | head -1 | sed 's/.*MARKETING_VERSION = \([^;]*\);/\1/' | tr -d ' ')
    fi
    
    if [ -z "$plist_version" ]; then
        echo "Error: Unable to read MARKETING_VERSION from project.pbxproj"
        return 1
    fi
    
    echo "Info.plist version: $plist_version"
    
    # Compare versions
    if [ "$branch_version" != "$plist_version" ]; then
        echo "Error: Version mismatch!"
        echo "  Branch version: $branch_version"
        echo "  Info.plist version: $plist_version"
        echo "Please ensure the version in branch name matches MARKETING_VERSION in Info.plist"
        return 1
    fi
    
    echo "✓ Version validation passed: $branch_version"
    echo "Version validation completed"
    echo "-----------------------------------"
    return 0
}

# Function: Validate SDK version against branch version
# Args:
#   $1 - SDK version (e.g., "4.6.2")
#   $2 - Branch name (optional, will auto-detect if not provided)
# Returns: 0 on success, 1 on failure
validate_sdk_version() {
    local sdk_version="$1"
    local branch_name="${2:-$(get_branch_name)}"
    
    echo "Starting SDK version validation..."
    
    if [ -z "$sdk_version" ]; then
        echo "Warning: SDK version is empty, skipping SDK version validation"
        return 0
    fi
    
    if [ -z "$branch_name" ] || [ "$branch_name" = "HEAD" ]; then
        echo "Warning: Unable to get Git branch name, skipping SDK version validation"
        return 0
    fi

    # Skip version check for main branch (we trust main when building from it)
    if [ "$branch_name" = "main" ]; then
        echo "Branch is main, skipping SDK version validation (main branch is trusted)"
        return 0
    fi

    echo "Current branch: $branch_name"
    echo "SDK version from Podfile: $sdk_version"

    # Extract version from branch name
    local branch_version=$(extract_branch_version "$branch_name")
    
    if [ -z "$branch_version" ]; then
        echo "Warning: Branch name does not contain version number, skipping SDK version validation"
        echo "Current branch: $branch_name"
        return 0
    fi
    
    echo "Branch version: $branch_version"
    
    # Compare SDK version with branch version
    if [ "$sdk_version" != "$branch_version" ]; then
        echo "Error: SDK version mismatch!"
        echo "  SDK version (Podfile): $sdk_version"
        echo "  Branch version: $branch_version"
        echo "Please ensure the SDK version in Podfile matches the branch version"
        return 1
    fi
    
    echo "✓ SDK version validation passed: $sdk_version"
    echo "SDK version validation completed"
    echo "-----------------------------------"
    return 0
}
