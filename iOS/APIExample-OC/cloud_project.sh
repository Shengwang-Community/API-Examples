#!/usr/bin/env sh

PROJECT_PATH=$PWD

if [ "$WORKSPACE" = "" ]; then
	WORKSPACE=$PWD
fi
if [ "$BUILD_NUMBER" = "" ]; then
	BUILD_NUMBER=888
fi

# Version validation logic
echo "Starting branch version validation..."

# Get current branch name (try multiple methods for CI environments)
BRANCH_NAME=""

# Method 1: Try environment variable (Jenkins/GitLab CI)
if [ ! -z "$GIT_BRANCH" ]; then
    BRANCH_NAME="$GIT_BRANCH"
    echo "Branch from GIT_BRANCH: $BRANCH_NAME"
elif [ ! -z "$BRANCH_NAME" ]; then
    echo "Branch from BRANCH_NAME: $BRANCH_NAME"
elif [ ! -z "$CI_COMMIT_REF_NAME" ]; then
    BRANCH_NAME="$CI_COMMIT_REF_NAME"
    echo "Branch from CI_COMMIT_REF_NAME: $BRANCH_NAME"
# Method 2: Try git command
elif [ -z "$BRANCH_NAME" ]; then
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ "$BRANCH_NAME" = "HEAD" ]; then
        # In detached HEAD state, try to get branch from remote
        BRANCH_NAME=$(git branch -r --contains HEAD | grep -v HEAD | head -1 | sed 's/^[[:space:]]*origin\///')
        echo "Branch from git branch -r: $BRANCH_NAME"
    else
        echo "Branch from git rev-parse: $BRANCH_NAME"
    fi
fi

# Remove origin/ prefix if present (but keep the rest of the path)
BRANCH_NAME=$(echo "$BRANCH_NAME" | sed 's/^origin\///')

if [ -z "$BRANCH_NAME" ] || [ "$BRANCH_NAME" = "HEAD" ]; then
	echo "Warning: Unable to get Git branch name, skipping version validation"
else
	echo "Current branch: $BRANCH_NAME"
	
	# Extract version from branch name (format: dev/x.x.x)
	if [[ $BRANCH_NAME =~ ^dev/([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
		BRANCH_VERSION="${BASH_REMATCH[1]}"
		echo "Branch version: $BRANCH_VERSION"
		
		# Read MARKETING_VERSION from project.pbxproj
		PBXPROJ_FILE="${PROJECT_PATH}/APIExample-OC.xcodeproj/project.pbxproj"
		if [ ! -f "$PBXPROJ_FILE" ]; then
			echo "Error: project.pbxproj file not found: $PBXPROJ_FILE"
			exit 1
		fi
		
		# Extract MARKETING_VERSION for main target
		PLIST_VERSION=$(grep -A 2 "@executable_path/Frameworks" "$PBXPROJ_FILE" | grep "MARKETING_VERSION" | head -1 | sed 's/.*MARKETING_VERSION = \([^;]*\);/\1/' | tr -d ' ')
		
		if [ -z "$PLIST_VERSION" ]; then
			echo "Error: Unable to read MARKETING_VERSION from project.pbxproj"
			exit 1
		fi
		
		echo "Info.plist version: $PLIST_VERSION"
		
		# Compare versions
		if [ "$BRANCH_VERSION" != "$PLIST_VERSION" ]; then
			echo "Error: Version mismatch!"
			echo "  Branch version: $BRANCH_VERSION"
			echo "  Info.plist version: $PLIST_VERSION"
			echo "Please ensure the version in branch name matches MARKETING_VERSION in Info.plist"
			exit 1
		fi
		
		echo "✓ Version validation passed: $BRANCH_VERSION"
	else
		echo "Error: Branch name does not match dev/x.x.x format!"
		echo "Current branch: $BRANCH_NAME"
		echo "Required format: dev/x.x.x (e.g., dev/4.6.2)"
		exit 1
	fi
fi

echo "Version validation completed"
echo "-----------------------------------"


cd ${PROJECT_PATH} && pod install || exit 1

