#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}       Project Initialization Script${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local default="$3"
    
    if [ -n "$default" ]; then
        read -p "$(echo -e "${BLUE}?${NC} $prompt [$default]: ")" input
        eval "$var_name=\"${input:-$default}\""
    else
        read -p "$(echo -e "${BLUE}?${NC} $prompt: ")" input
        eval "$var_name=\"$input\""
    fi
}

prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local response
    
    if [ "$default" = "y" ]; then
        read -p "$(echo -e "${BLUE}?${NC} $prompt [Y/n]: ")" response
        response=${response:-y}
    else
        read -p "$(echo -e "${BLUE}?${NC} $prompt [y/N]: ")" response
        response=${response:-n}
    fi
    
    [[ "$response" =~ ^[Yy]$ ]]
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_deps=()
    
    command -v git >/dev/null 2>&1 || missing_deps+=("git")
    command -v node >/dev/null 2>&1 || missing_deps+=("node")
    command -v npm >/dev/null 2>&1 || missing_deps+=("npm")
    command -v sqlite3 >/dev/null 2>&1 || missing_deps+=("sqlite3")
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
    
    print_success "All prerequisites met"
}

analyze_existing_repo() {
    print_info "Analyzing existing repository..."
    
    # Initialize analysis results
    IS_GIT_REPO=false
    IS_NODE_PROJECT=false
    HAS_PACKAGE_JSON=false
    HAS_WORKTREES=false
    HAS_MENU_SCRIPT=false
    PROJECT_TYPE="unknown"
    DETECTED_PROJECT_NAME=""
    DETECTED_DESCRIPTION=""
    DETECTED_AUTHOR=""
    EXISTING_SCRIPTS=()
    
    # Check if it's a git repository
    if [ -d ".git" ] || git rev-parse --git-dir > /dev/null 2>&1; then
        IS_GIT_REPO=true
        print_info "Git repository detected"
    fi
    
    # Check for package.json and analyze Node.js project
    if [ -f "package.json" ]; then
        HAS_PACKAGE_JSON=true
        IS_NODE_PROJECT=true
        PROJECT_TYPE="nodejs"
        
        # Extract existing project info
        if command -v jq >/dev/null 2>&1; then
            DETECTED_PROJECT_NAME=$(jq -r '.name // empty' package.json 2>/dev/null)
            DETECTED_DESCRIPTION=$(jq -r '.description // empty' package.json 2>/dev/null)
            DETECTED_AUTHOR=$(jq -r '.author // empty' package.json 2>/dev/null)
            
            # Get existing scripts
            EXISTING_SCRIPTS=()
            while IFS= read -r script; do
                EXISTING_SCRIPTS+=("$script")
            done < <(jq -r '.scripts | keys[]?' package.json 2>/dev/null)
        else
            # Fallback parsing without jq
            DETECTED_PROJECT_NAME=$(grep '"name"' package.json | sed 's/.*"name": *"\([^"]*\)".*/\1/' 2>/dev/null)
            DETECTED_DESCRIPTION=$(grep '"description"' package.json | sed 's/.*"description": *"\([^"]*\)".*/\1/' 2>/dev/null)
            DETECTED_AUTHOR=$(grep '"author"' package.json | sed 's/.*"author": *"\([^"]*\)".*/\1/' 2>/dev/null)
        fi
        
        print_info "Node.js project detected: ${DETECTED_PROJECT_NAME:-"unnamed project"}"
    fi
    
    # Check for other project types
    if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
        PROJECT_TYPE="python"
        print_info "Python project detected"
    elif [ -f "Cargo.toml" ]; then
        PROJECT_TYPE="rust"
        print_info "Rust project detected"
    elif [ -f "go.mod" ]; then
        PROJECT_TYPE="go"
        print_info "Go project detected"
    elif [ -f "composer.json" ]; then
        PROJECT_TYPE="php"
        print_info "PHP project detected"
    fi
    
    # Check for existing worktree setup
    if [ -d ".worktrees" ]; then
        HAS_WORKTREES=true
        print_info "Existing worktree setup detected"
    fi
    
    # Check for existing menu script
    if [ -f "menu.sh" ]; then
        HAS_MENU_SCRIPT=true
        print_info "Existing menu script detected"
    fi
    
    # Check for React/Vue/Angular specific markers
    if [ -f "package.json" ]; then
        if grep -q "react" package.json 2>/dev/null; then
            PROJECT_TYPE="react"
            print_info "React project detected"
        elif grep -q "vue" package.json 2>/dev/null; then
            PROJECT_TYPE="vue"
            print_info "Vue.js project detected"
        elif grep -q "@angular" package.json 2>/dev/null; then
            PROJECT_TYPE="angular"
            print_info "Angular project detected"
        elif grep -q "next" package.json 2>/dev/null; then
            PROJECT_TYPE="nextjs"
            print_info "Next.js project detected"
        fi
    fi
    
    print_success "Repository analysis complete"
}

check_project_compatibility() {
    print_info "Checking project compatibility..."
    
    local warnings=()
    local blockers=()
    
    # Check for conflicting files that would be overwritten
    if [ -f "README.md" ] && [ "$MODE" = "init" ]; then
        warnings+=("README.md exists and will be overwritten")
    fi
    
    if [ -f ".gitignore" ] && [ "$MODE" = "init" ]; then
        warnings+=(".gitignore exists and will be merged")
    fi
    
    # Check for empty directory
    if [ "$MODE" = "init" ] && [ -n "$(ls -A . 2>/dev/null | grep -v '\.git')" ]; then
        warnings+=("Directory is not empty")
    fi
    
    # Show warnings
    if [ ${#warnings[@]} -gt 0 ]; then
        print_warning "Compatibility warnings:"
        for warning in "${warnings[@]}"; do
            echo "  - $warning"
        done
        echo
        if ! prompt_yes_no "Continue with initialization?" "y"; then
            exit 0
        fi
    fi
    
    # Check for blockers
    if [ ${#blockers[@]} -gt 0 ]; then
        print_error "Cannot proceed due to:"
        for blocker in "${blockers[@]}"; do
            echo "  - $blocker"
        done
        exit 1
    fi
    
    print_success "Project is compatible"
}

determine_init_mode() {
    print_info "Determining initialization mode..."
    
    # Check command line arguments
    if [[ "$1" == "--existing-repo" ]] || [[ "$1" == "--enhance" ]]; then
        MODE="enhance"
        print_info "Enhancement mode: Will add tooling to existing project"
    elif [[ "$1" == "--init" ]] || [[ "$1" == "--new" ]]; then
        MODE="init"
        print_info "Full initialization mode: Will create new project structure"
    elif [[ "$1" == "--minimal" ]] || [[ "$1" == "--worktree-only" ]]; then
        MODE="minimal"
        print_info "Minimal mode: Will only add worktree management and menu"
    else
        # Auto-detect mode based on project state
        if [ "$IS_GIT_REPO" = true ] && [ "$HAS_PACKAGE_JSON" = true ]; then
            MODE="enhance"
            print_info "Auto-detected enhancement mode: Existing project found"
        elif [ "$IS_GIT_REPO" = true ] && [ -n "$(ls -A . 2>/dev/null | grep -v '\.git')" ]; then
            print_warning "Git repository detected with existing files"
            echo "Choose setup mode:"
            echo "1. Enhancement mode (add Node.js tooling if applicable)"
            echo "2. Minimal mode (worktree management and menu only)"
            echo "3. Full initialization (may overwrite files)"
            echo -n "Select mode [1-3]: "
            read mode_choice
            case $mode_choice in
                1) MODE="enhance" ;;
                2) MODE="minimal" ;;
                3) MODE="init" ;;
                *) MODE="minimal"; print_info "Invalid choice, defaulting to minimal mode" ;;
            esac
        elif [ -n "$(ls -A . 2>/dev/null | grep -v '\.git')" ]; then
            print_warning "Directory contains files but no clear project structure"
            if prompt_yes_no "Use enhancement mode (preserve existing files)?" "y"; then
                MODE="enhance"
            else
                MODE="init"
            fi
        else
            MODE="init"
            print_info "Auto-detected initialization mode: Empty or minimal directory"
        fi
    fi
    
    export MODE
}

setup_project_structure() {
    print_info "Setting up project structure..."
    
    mkdir -p src/{controllers,models,services,utils,middleware,db}
    mkdir -p tests/{unit,integration}
    mkdir -p config
    mkdir -p public/{css,js,images}
    mkdir -p views
    mkdir -p db/migrations
    mkdir -p scripts
    mkdir -p docs
    
    print_success "Project structure created"
}

initialize_git() {
    print_info "Initializing Git repository..."
    
    git init --initial-branch=main
    
    cat > .gitignore << 'EOF'
# Dependencies
node_modules/
package-lock.json
yarn.lock

# Environment variables
.env
.env.local
.env.*.local

# Database
*.sqlite
*.sqlite3
*.db
db/*.sqlite*

# Logs
logs/
*.log
npm-debug.log*
yarn-debug.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Build outputs
dist/
build/
*.tsbuildinfo

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Testing
coverage/
.nyc_output/

# Temporary files
tmp/
temp/

# Worktrees (except the .worktrees directory structure)
.worktrees/*
!.worktrees/.gitkeep
EOF
    
    print_success "Git repository initialized"
}

setup_worktrees() {
    print_info "Setting up Git worktrees..."
    
    git add .
    git commit -m "Initial commit: Project structure setup" || true
    
    mkdir -p .worktrees
    touch .worktrees/.gitkeep
    
    git worktree add .worktrees/main main 2>/dev/null || {
        print_warning "Main worktree already exists or branch not ready"
    }
    
    if git show-ref --quiet refs/heads/hotfix; then
        git worktree add .worktrees/hotfix hotfix 2>/dev/null || {
            print_warning "Hotfix worktree already exists"
        }
    else
        git branch hotfix
        git worktree add .worktrees/hotfix hotfix
    fi
    
    cat > scripts/worktree-switch.sh << 'EOF'
#!/bin/bash

WORKTREE_DIR=".worktrees"

if [ -z "$1" ]; then
    echo "Usage: ./scripts/worktree-switch.sh <branch-name>"
    echo "Available worktrees:"
    git worktree list
    exit 1
fi

TARGET="$WORKTREE_DIR/$1"

if [ -d "$TARGET" ]; then
    echo "Switching to worktree: $1"
    cd "$TARGET" && exec $SHELL
else
    echo "Worktree '$1' not found."
    echo "Available worktrees:"
    git worktree list
    exit 1
fi
EOF
    
    chmod +x scripts/worktree-switch.sh
    
    cat > scripts/worktree-create.sh << 'EOF'
#!/bin/bash

WORKTREE_DIR=".worktrees"

if [ -z "$1" ]; then
    echo "Usage: ./scripts/worktree-create.sh <branch-name> [base-branch]"
    exit 1
fi

BRANCH_NAME="$1"
BASE_BRANCH="${2:-main}"

if git show-ref --quiet "refs/heads/$BRANCH_NAME"; then
    echo "Branch '$BRANCH_NAME' already exists."
    read -p "Add worktree for existing branch? [y/N]: " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        git worktree add "$WORKTREE_DIR/$BRANCH_NAME" "$BRANCH_NAME"
    fi
else
    echo "Creating new branch '$BRANCH_NAME' from '$BASE_BRANCH'"
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR/$BRANCH_NAME" "$BASE_BRANCH"
fi

echo "Worktree created at: $WORKTREE_DIR/$BRANCH_NAME"
EOF
    
    chmod +x scripts/worktree-create.sh
    
    print_success "Worktrees configured"
}

initialize_nodejs() {
    print_info "Initializing Node.js project..."
    
    cat > package.json << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "$PROJECT_DESCRIPTION",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint src/ --ext .js",
    "format": "prettier --write 'src/**/*.js'",
    "db:migrate": "node scripts/migrate.js",
    "db:seed": "node scripts/seed.js",
    "worktree:switch": "./scripts/worktree-switch.sh",
    "worktree:create": "./scripts/worktree-create.sh",
    "menu": "./menu.sh"
  },
  "keywords": [],
  "author": "$AUTHOR_NAME",
  "license": "$LICENSE",
  "dependencies": {
    "express": "^4.18.2",
    "sqlite3": "^5.1.6",
    "dotenv": "^16.3.1",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.6.2",
    "eslint": "^8.45.0",
    "prettier": "^3.0.0"
  }
}
EOF
    
    cat > .eslintrc.json << 'EOF'
{
  "env": {
    "node": true,
    "es2021": true,
    "jest": true
  },
  "extends": "eslint:recommended",
  "parserOptions": {
    "ecmaVersion": "latest",
    "sourceType": "module"
  },
  "rules": {
    "indent": ["error", 2],
    "quotes": ["error", "single"],
    "semi": ["error", "always"]
  }
}
EOF
    
    cat > .prettierrc << 'EOF'
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 80
}
EOF
    
    cat > src/index.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const db = require('./db/connection');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get('/', (req, res) => {
  res.json({ 
    message: 'API is running',
    environment: process.env.NODE_ENV || 'development'
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Something went wrong!' });
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});

module.exports = app;
EOF
    
    cat > menu.sh << 'EOF'
#!/bin/bash

set -e

# Colors for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

clear_screen() {
    clear
}

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}                     PROJECT MENU SYSTEM                      ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Show current context
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local current_dir=$(basename "$PWD")
    echo -e "${CYAN}Project:${NC} ${current_dir}  ${CYAN}Branch:${NC} ${current_branch}"
    
    # Check if we're in a worktree
    local worktree_info=$(git worktree list --porcelain 2>/dev/null | grep "$(pwd)" | head -1 || echo "")
    if [[ -n "$worktree_info" ]]; then
        echo -e "${PURPLE}Worktree:${NC} $(pwd)"
    fi
    echo
}

show_main_menu() {
    print_header
    echo -e "${WHITE}Main Menu:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Switch Worktree"
    echo -e "${GREEN}2.${NC} Create New Worktree" 
    echo -e "${GREEN}3.${NC} Delete Worktree"
    echo -e "${GREEN}4.${NC} Run Scripts"
    echo -e "${GREEN}5.${NC} Git Operations"
    echo -e "${GREEN}6.${NC} Database Operations"
    echo -e "${GREEN}7.${NC} Launch Claude Code"
    echo -e "${GREEN}8.${NC} Launch Editor"
    echo -e "${GREEN}9.${NC} Project Info"
    echo
    echo -e "${RED}0.${NC} Exit"
    echo
    echo -n "Select option [0-9]: "
}

show_scripts_menu() {
    clear_screen
    print_header
    echo -e "${WHITE}Available Scripts:${NC}"
    echo
    
    # Parse package.json scripts - try jq first, fallback to grep/sed
    local scripts=""
    if command -v jq >/dev/null 2>&1; then
        scripts=$(jq -r '.scripts | to_entries[] | "\(.key)|\(.value)"' package.json 2>/dev/null)
    else
        # Fallback parsing without jq
        scripts=$(grep -A 20 '"scripts"' package.json | sed -n '/".*":/p' | sed 's/.*"\([^"]*\)": *"\([^"]*\)".*/\1|\2/' | head -20)
    fi
    
    if [[ -z "$scripts" ]]; then
        echo -e "${RED}No scripts found in package.json${NC}"
        echo
        echo -n "Press Enter to return to main menu..."
        read
        return
    fi
    
    local count=1
    local script_names=()
    
    while IFS='|' read -r name command; do
        [[ -z "$name" ]] && continue
        echo -e "${GREEN}${count}.${NC} ${CYAN}${name}${NC} - ${command}"
        script_names+=("$name")
        ((count++))
    done <<< "$scripts"
    
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select script to run [0-${#script_names[@]}]: "
    
    read choice
    if [[ "$choice" == "0" ]]; then
        return
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#script_names[@]}" ]]; then
        local script_name="${script_names[$((choice-1))]}"
        echo
        echo -e "${YELLOW}Running: npm run $script_name${NC}"
        echo
        npm run "$script_name"
        echo
        echo -n "Press Enter to continue..."
        read
    else
        echo -e "${RED}Invalid choice!${NC}"
        sleep 1
    fi
}

show_worktree_menu() {
    clear_screen
    print_header
    echo -e "${WHITE}Switch Worktree:${NC}"
    echo
    
    local worktrees=$(git worktree list 2>/dev/null)
    if [[ -z "$worktrees" ]]; then
        echo -e "${RED}No worktrees found${NC}"
        echo -n "Press Enter to continue..."
        read
        return
    fi
    
    echo "$worktrees"
    echo
    local count=1
    local worktree_paths=()
    
    while IFS= read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        local branch=$(echo "$line" | awk '{print $2}' | tr -d '[]')
        worktree_paths+=("$path")
        echo -e "${GREEN}${count}.${NC} ${CYAN}${branch}${NC} - ${path}"
        ((count++))
    done <<< "$worktrees"
    
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select worktree [0-$((count-1))]: "
    
    read choice
    if [[ "$choice" == "0" ]]; then
        return
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -lt "$count" ]]; then
        local target_path="${worktree_paths[$((choice-1))]}"
        echo
        echo -e "${YELLOW}Switching to: $target_path${NC}"
        cd "$target_path" && exec bash
    else
        echo -e "${RED}Invalid choice!${NC}"
        sleep 1
    fi
}

create_worktree() {
    clear_screen
    print_header
    echo -e "${WHITE}Create New Worktree:${NC}"
    echo
    
    echo -n "Enter branch name: "
    read branch_name
    
    if [[ -z "$branch_name" ]]; then
        echo -e "${RED}Branch name cannot be empty!${NC}"
        sleep 2
        return
    fi
    
    echo -n "Base branch (default: main): "
    read base_branch
    base_branch=${base_branch:-main}
    
    echo
    echo -e "${YELLOW}Creating worktree '$branch_name' from '$base_branch'...${NC}"
    
    if ./scripts/worktree-create.sh "$branch_name" "$base_branch"; then
        echo -e "${GREEN}Worktree created successfully!${NC}"
    else
        echo -e "${RED}Failed to create worktree${NC}"
    fi
    
    echo
    echo -n "Press Enter to continue..."
    read
}

delete_worktree() {
    clear_screen
    print_header
    echo -e "${WHITE}Delete Worktree:${NC}"
    echo
    
    local worktrees=$(git worktree list 2>/dev/null | grep -v "$(git rev-parse --show-toplevel)")
    if [[ -z "$worktrees" ]]; then
        echo -e "${RED}No additional worktrees found to delete${NC}"
        echo -n "Press Enter to continue..."
        read
        return
    fi
    
    echo "$worktrees"
    echo
    local count=1
    local worktree_info=()
    
    while IFS= read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        local branch=$(echo "$line" | awk '{print $2}' | tr -d '[]')
        worktree_info+=("$path|$branch")
        echo -e "${GREEN}${count}.${NC} ${CYAN}${branch}${NC} - ${path}"
        ((count++))
    done <<< "$worktrees"
    
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select worktree to delete [0-$((count-1))]: "
    
    read choice
    if [[ "$choice" == "0" ]]; then
        return
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -lt "$count" ]]; then
        local info="${worktree_info[$((choice-1))]}"
        local path=$(echo "$info" | cut -d'|' -f1)
        local branch=$(echo "$info" | cut -d'|' -f2)
        
        echo
        echo -e "${RED}WARNING: This will delete worktree '$branch' at '$path'${NC}"
        echo -n "Are you sure? [y/N]: "
        read confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Deleting worktree...${NC}"
            git worktree remove "$path" --force
            echo -e "${GREEN}Worktree deleted successfully!${NC}"
        else
            echo -e "${YELLOW}Cancelled${NC}"
        fi
    else
        echo -e "${RED}Invalid choice!${NC}"
        sleep 1
    fi
    
    echo
    echo -n "Press Enter to continue..."
    read
}

show_git_menu() {
    clear_screen
    print_header
    echo -e "${WHITE}Git Operations:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Git Status"
    echo -e "${GREEN}2.${NC} Git Pull"
    echo -e "${GREEN}3.${NC} Git Push"
    echo -e "${GREEN}4.${NC} Git Log (last 5 commits)"
    echo -e "${GREEN}5.${NC} List Branches"
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select option [0-5]: "
    
    read choice
    case $choice in
        1) clear_screen && git status && echo && echo -n "Press Enter to continue..." && read ;;
        2) clear_screen && git pull && echo && echo -n "Press Enter to continue..." && read ;;
        3) clear_screen && git push && echo && echo -n "Press Enter to continue..." && read ;;
        4) clear_screen && git log --oneline -5 && echo && echo -n "Press Enter to continue..." && read ;;
        5) clear_screen && git branch -a && echo && echo -n "Press Enter to continue..." && read ;;
        0) return ;;
        *) echo -e "${RED}Invalid choice!${NC}" && sleep 1 ;;
    esac
}

show_db_menu() {
    clear_screen
    print_header
    echo -e "${WHITE}Database Operations:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Run Migrations"
    echo -e "${GREEN}2.${NC} Seed Database"
    echo -e "${GREEN}3.${NC} Reset Database (migrate + seed)"
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select option [0-3]: "
    
    read choice
    case $choice in
        1) clear_screen && npm run db:migrate && echo && echo -n "Press Enter to continue..." && read ;;
        2) clear_screen && npm run db:seed && echo && echo -n "Press Enter to continue..." && read ;;
        3) clear_screen && npm run db:migrate && npm run db:seed && echo && echo -n "Press Enter to continue..." && read ;;
        0) return ;;
        *) echo -e "${RED}Invalid choice!${NC}" && sleep 1 ;;
    esac
}

launch_claude() {
    clear_screen
    echo -e "${YELLOW}Launching Claude Code...${NC}"
    if command -v claude >/dev/null 2>&1; then
        claude
    else
        echo -e "${RED}Claude Code not found in PATH${NC}"
        echo -n "Press Enter to continue..."
        read
    fi
}

launch_editor() {
    clear_screen
    print_header
    echo -e "${WHITE}Launch Editor:${NC}"
    echo
    echo -e "${GREEN}1.${NC} VSCode (code .)"
    echo -e "${GREEN}2.${NC} VSCode Insiders (code-insiders .)"
    echo -e "${GREEN}3.${NC} Vim"
    echo -e "${GREEN}4.${NC} Nano"
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select editor [0-4]: "
    
    read choice
    case $choice in
        1) command -v code >/dev/null 2>&1 && code . || echo -e "${RED}VSCode not found${NC}" ;;
        2) command -v code-insiders >/dev/null 2>&1 && code-insiders . || echo -e "${RED}VSCode Insiders not found${NC}" ;;
        3) vim . ;;
        4) nano . ;;
        0) return ;;
        *) echo -e "${RED}Invalid choice!${NC}" && sleep 1 ;;
    esac
}

show_project_info() {
    clear_screen
    print_header
    echo -e "${WHITE}Project Information:${NC}"
    echo
    
    if [[ -f "package.json" ]]; then
        local name=$(grep '"name"' package.json | sed 's/.*"name": *"\([^"]*\)".*/\1/')
        local version=$(grep '"version"' package.json | sed 's/.*"version": *"\([^"]*\)".*/\1/')
        local description=$(grep '"description"' package.json | sed 's/.*"description": *"\([^"]*\)".*/\1/')
        
        echo -e "${CYAN}Name:${NC} $name"
        echo -e "${CYAN}Version:${NC} $version"
        echo -e "${CYAN}Description:${NC} $description"
        echo
    fi
    
    echo -e "${CYAN}Current Directory:${NC} $(pwd)"
    echo -e "${CYAN}Git Branch:${NC} $(git branch --show-current 2>/dev/null || echo 'Not a git repository')"
    echo -e "${CYAN}Node Version:${NC} $(node --version 2>/dev/null || echo 'Not installed')"
    echo -e "${CYAN}NPM Version:${NC} $(npm --version 2>/dev/null || echo 'Not installed')"
    echo
    
    if [[ -f "package.json" ]]; then
        echo -e "${WHITE}Dependencies:${NC}"
        grep -A 10 '"dependencies"' package.json | grep '"' | sed 's/.*"\([^"]*\)": *"\([^"]*\)".*/  \1: \2/' || echo "  None"
        echo
    fi
    
    echo -n "Press Enter to continue..."
    read
}

main_loop() {
    while true; do
        clear_screen
        show_main_menu
        read choice
        
        case $choice in
            1) show_worktree_menu ;;
            2) create_worktree ;;
            3) delete_worktree ;;
            4) show_scripts_menu ;;
            5) show_git_menu ;;
            6) show_db_menu ;;
            7) launch_claude ;;
            8) launch_editor ;;
            9) show_project_info ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice! Please select 0-9.${NC}"; sleep 1 ;;
        esac
    done
}

# Check if we're in a project directory
if [[ ! -f "package.json" ]]; then
    echo -e "${RED}Error: package.json not found. This script should be run from a project root.${NC}"
    exit 1
fi

main_loop
EOF
    
    chmod +x menu.sh
    
    print_success "Node.js project initialized"
}

setup_sqlite() {
    print_info "Setting up SQLite database..."
    
    cat > src/db/connection.js << 'EOF'
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, '../../db/database.sqlite');

const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error opening database:', err);
  } else {
    console.log('Connected to SQLite database');
    db.run('PRAGMA foreign_keys = ON');
  }
});

const runQuery = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function(err) {
      if (err) {
        reject(err);
      } else {
        resolve({ id: this.lastID, changes: this.changes });
      }
    });
  });
};

const getOne = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => {
      if (err) {
        reject(err);
      } else {
        resolve(row);
      }
    });
  });
};

const getAll = (sql, params = []) => {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) {
        reject(err);
      } else {
        resolve(rows);
      }
    });
  });
};

module.exports = {
  db,
  runQuery,
  getOne,
  getAll
};
EOF
    
    cat > scripts/migrate.js << 'EOF'
const { db, runQuery } = require('../src/db/connection');
const fs = require('fs');
const path = require('path');

async function runMigrations() {
  try {
    await runQuery(`
      CREATE TABLE IF NOT EXISTS migrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT UNIQUE NOT NULL,
        executed_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    const migrationsDir = path.join(__dirname, '../db/migrations');
    const files = fs.readdirSync(migrationsDir).sort();
    
    for (const file of files) {
      if (file.endsWith('.sql')) {
        const executed = await require('../src/db/connection').getOne(
          'SELECT * FROM migrations WHERE filename = ?',
          [file]
        );
        
        if (!executed) {
          console.log(`Running migration: ${file}`);
          const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
          
          const statements = sql.split(';').filter(s => s.trim());
          for (const statement of statements) {
            await runQuery(statement);
          }
          
          await runQuery('INSERT INTO migrations (filename) VALUES (?)', [file]);
          console.log(`✓ Migration ${file} completed`);
        }
      }
    }
    
    console.log('All migrations completed');
    process.exit(0);
  } catch (error) {
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

runMigrations();
EOF
    
    cat > db/migrations/001_initial_schema.sql << 'EOF'
-- Initial database schema

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    user_id INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX idx_projects_user_id ON projects(user_id);
CREATE INDEX idx_users_email ON users(email);
EOF
    
    cat > scripts/seed.js << 'EOF'
const { runQuery } = require('../src/db/connection');

async function seedDatabase() {
  try {
    console.log('Seeding database...');
    
    await runQuery(
      'INSERT OR IGNORE INTO users (username, email) VALUES (?, ?)',
      ['admin', 'admin@example.com']
    );
    
    await runQuery(
      'INSERT OR IGNORE INTO projects (name, description, user_id) VALUES (?, ?, ?)',
      ['Sample Project', 'This is a sample project', 1]
    );
    
    console.log('Database seeded successfully');
    process.exit(0);
  } catch (error) {
    console.error('Seeding failed:', error);
    process.exit(1);
  }
}

seedDatabase();
EOF
    
    print_success "SQLite database configured"
}

setup_github_remote() {
    if [ -n "$GITHUB_REPO" ]; then
        print_info "Configuring GitHub remote..."
        
        if [[ "$GITHUB_REPO" =~ ^https://github.com/.+/.+\.git$ ]]; then
            git remote add origin "$GITHUB_REPO" 2>/dev/null || {
                git remote set-url origin "$GITHUB_REPO"
            }
        elif [[ "$GITHUB_REPO" =~ ^https://github.com/.+/.+$ ]]; then
            git remote add origin "$GITHUB_REPO.git" 2>/dev/null || {
                git remote set-url origin "$GITHUB_REPO.git"
            }
        elif [[ "$GITHUB_REPO" =~ ^git@github.com:.+/.+\.git$ ]]; then
            git remote add origin "$GITHUB_REPO" 2>/dev/null || {
                git remote set-url origin "$GITHUB_REPO"
            }
        elif [[ "$GITHUB_REPO" =~ ^[^/]+/[^/]+$ ]]; then
            git remote add origin "https://github.com/$GITHUB_REPO.git" 2>/dev/null || {
                git remote set-url origin "https://github.com/$GITHUB_REPO.git"
            }
        else
            print_warning "Invalid GitHub repository format. Skipping remote setup."
            return
        fi
        
        print_success "GitHub remote configured: $(git remote get-url origin)"
        
        if prompt_yes_no "Push to GitHub repository?" "n"; then
            git push -u origin main --force
            git push origin hotfix --force
            print_success "Pushed to GitHub"
        fi
    fi
}

create_env_file() {
    print_info "Creating environment file..."
    
    cat > .env.example << 'EOF'
NODE_ENV=development
PORT=3000
DATABASE_PATH=./db/database.sqlite

# Add your environment variables here
# API_KEY=your_api_key_here
# SECRET_KEY=your_secret_key_here
EOF
    
    cp .env.example .env
    
    print_success "Environment file created"
}

create_readme() {
    if [ "$MODE" = "enhance" ] && [ -f "README.md" ]; then
        print_info "README.md exists, skipping creation"
        return
    fi
    
    cat > README.md << EOF
# $PROJECT_NAME

$PROJECT_DESCRIPTION

## Features

- Node.js/Express backend
- SQLite database
- Git worktrees for main and hotfix branches
- Structured project layout
- Testing setup with Jest
- Linting with ESLint
- Code formatting with Prettier

## Getting Started

### Prerequisites

- Node.js (v14 or higher)
- npm or yarn
- Git
- SQLite3

### Installation

1. Install dependencies:
\`\`\`bash
npm install
\`\`\`

2. Set up environment variables:
\`\`\`bash
cp .env.example .env
\`\`\`

3. Run database migrations:
\`\`\`bash
npm run db:migrate
\`\`\`

4. Seed the database (optional):
\`\`\`bash
npm run db:seed
\`\`\`

### Development

Start the development server:
\`\`\`bash
npm run dev
\`\`\`

### Working with Worktrees

Switch to a worktree:
\`\`\`bash
npm run worktree:switch main
# or
npm run worktree:switch hotfix
\`\`\`

Create a new worktree:
\`\`\`bash
npm run worktree:create feature-name
\`\`\`

### Testing

Run tests:
\`\`\`bash
npm test
\`\`\`

Run tests with coverage:
\`\`\`bash
npm run test:coverage
\`\`\`

### Project Structure

\`\`\`
.
├── src/
│   ├── controllers/    # Route controllers
│   ├── models/         # Data models
│   ├── services/       # Business logic
│   ├── middleware/     # Express middleware
│   ├── utils/          # Utility functions
│   └── db/            # Database connection
├── tests/
│   ├── unit/          # Unit tests
│   └── integration/   # Integration tests
├── config/            # Configuration files
├── db/
│   └── migrations/    # Database migrations
├── scripts/           # Utility scripts
├── public/            # Static files
└── views/             # View templates
\`\`\`

## License

$LICENSE

## Author

$AUTHOR_NAME
EOF
    
    print_success "README created"
}

enhance_existing_package_json() {
    print_info "Enhancing existing package.json..."
    
    # Create a temporary file with new scripts
    cat > /tmp/new_scripts.json << EOF
{
  "worktree:switch": "./scripts/worktree-switch.sh",
  "worktree:create": "./scripts/worktree-create.sh",
  "menu": "./menu.sh",
  "db:migrate": "node scripts/migrate.js",
  "db:seed": "node scripts/seed.js"
}
EOF
    
    # Merge scripts if jq is available
    if command -v jq >/dev/null 2>&1; then
        # Create backup
        cp package.json package.json.backup
        
        # Merge scripts
        jq '.scripts += input' package.json /tmp/new_scripts.json > /tmp/merged_package.json
        
        # Conditionally add development dependencies if they don't exist
        jq '.devDependencies += {
          "nodemon": "^3.0.1",
          "jest": "^29.6.2",
          "eslint": "^8.45.0",
          "prettier": "^3.0.0"
        }' /tmp/merged_package.json > /tmp/final_package.json
        
        # Conditionally add production dependencies if they don't exist
        jq '.dependencies += {
          "dotenv": "^16.3.1",
          "sqlite3": "^5.1.6"
        }' /tmp/final_package.json > package.json
        
        rm /tmp/new_scripts.json /tmp/merged_package.json /tmp/final_package.json
        
        print_success "Package.json enhanced with new scripts and dependencies"
    else
        print_warning "jq not available, manual package.json enhancement required"
        print_info "Consider adding these scripts to package.json:"
        cat /tmp/new_scripts.json
        rm /tmp/new_scripts.json
    fi
}

setup_project_structure_selective() {
    print_info "Setting up additional project structure..."
    
    # Only create directories that don't exist
    local dirs_to_create=()
    
    [ ! -d "scripts" ] && dirs_to_create+=("scripts")
    [ ! -d "config" ] && dirs_to_create+=("config")
    
    # For Node.js projects, conditionally add standard directories
    if [ "$IS_NODE_PROJECT" = true ]; then
        [ ! -d "src" ] && dirs_to_create+=("src")
        [ ! -d "src/controllers" ] && [ -d "src" ] && dirs_to_create+=("src/controllers")
        [ ! -d "src/models" ] && [ -d "src" ] && dirs_to_create+=("src/models")
        [ ! -d "src/services" ] && [ -d "src" ] && dirs_to_create+=("src/services")
        [ ! -d "src/utils" ] && [ -d "src" ] && dirs_to_create+=("src/utils")
        [ ! -d "src/middleware" ] && [ -d "src" ] && dirs_to_create+=("src/middleware")
        [ ! -d "src/db" ] && [ -d "src" ] && dirs_to_create+=("src/db")
        [ ! -d "tests" ] && dirs_to_create+=("tests")
        [ ! -d "tests/unit" ] && [ -d "tests" ] && dirs_to_create+=("tests/unit")
        [ ! -d "tests/integration" ] && [ -d "tests" ] && dirs_to_create+=("tests/integration")
        [ ! -d "public" ] && dirs_to_create+=("public")
        [ ! -d "public/css" ] && [ -d "public" ] && dirs_to_create+=("public/css")
        [ ! -d "public/js" ] && [ -d "public" ] && dirs_to_create+=("public/js")
        [ ! -d "public/images" ] && [ -d "public" ] && dirs_to_create+=("public/images")
        [ ! -d "db" ] && dirs_to_create+=("db")
        [ ! -d "db/migrations" ] && [ -d "db" ] && dirs_to_create+=("db/migrations")
    fi
    
    # Create directories if any are needed
    if [ ${#dirs_to_create[@]} -gt 0 ]; then
        print_info "Creating missing directories: ${dirs_to_create[*]}"
        mkdir -p "${dirs_to_create[@]}"
        print_success "Additional directories created"
    else
        print_info "All necessary directories already exist"
    fi
}

setup_worktrees_enhance() {
    if [ "$HAS_WORKTREES" = true ]; then
        print_info "Worktree setup already exists, enhancing scripts only"
    else
        print_info "Setting up Git worktrees..."
        
        # Ensure we're in a git repository
        if [ "$IS_GIT_REPO" = false ]; then
            print_warning "Not a git repository, skipping worktree setup"
            return
        fi
        
        # Commit current changes if any
        if ! git diff --quiet 2>/dev/null; then
            git add .
            git commit -m "Initial commit before worktree setup" || true
        fi
        
        mkdir -p .worktrees
        touch .worktrees/.gitkeep
        
        # Create worktrees for common branches if they exist
        local current_branch=$(git branch --show-current)
        
        if [ "$current_branch" != "main" ] && git show-ref --quiet refs/heads/main; then
            git worktree add .worktrees/main main 2>/dev/null || {
                print_warning "Main worktree already exists or branch not ready"
            }
        fi
        
        if [ "$current_branch" != "hotfix" ] && git show-ref --quiet refs/heads/hotfix; then
            git worktree add .worktrees/hotfix hotfix 2>/dev/null || {
                print_warning "Hotfix worktree already exists"
            }
        elif [ "$current_branch" != "hotfix" ] && ! git show-ref --quiet refs/heads/hotfix; then
            git branch hotfix
            git worktree add .worktrees/hotfix hotfix
        fi
        
        print_success "Worktrees configured"
    fi
    
    # Always ensure scripts exist
    create_worktree_scripts
}

create_worktree_scripts() {
    # Create worktree management scripts
    cat > scripts/worktree-switch.sh << 'EOF'
#!/bin/bash

WORKTREE_DIR=".worktrees"

if [ -z "$1" ]; then
    echo "Usage: ./scripts/worktree-switch.sh <branch-name>"
    echo "Available worktrees:"
    git worktree list
    exit 1
fi

TARGET="$WORKTREE_DIR/$1"

if [ -d "$TARGET" ]; then
    echo "Switching to worktree: $1"
    cd "$TARGET" && exec $SHELL
else
    echo "Worktree '$1' not found."
    echo "Available worktrees:"
    git worktree list
    exit 1
fi
EOF
    
    chmod +x scripts/worktree-switch.sh
    
    cat > scripts/worktree-create.sh << 'EOF'
#!/bin/bash

WORKTREE_DIR=".worktrees"

if [ -z "$1" ]; then
    echo "Usage: ./scripts/worktree-create.sh <branch-name> [base-branch]"
    exit 1
fi

BRANCH_NAME="$1"
BASE_BRANCH="${2:-main}"

if git show-ref --quiet "refs/heads/$BRANCH_NAME"; then
    echo "Branch '$BRANCH_NAME' already exists."
    read -p "Add worktree for existing branch? [y/N]: " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        git worktree add "$WORKTREE_DIR/$BRANCH_NAME" "$BRANCH_NAME"
    fi
else
    echo "Creating new branch '$BRANCH_NAME' from '$BASE_BRANCH'"
    git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR/$BRANCH_NAME" "$BASE_BRANCH"
fi

echo "Worktree created at: $WORKTREE_DIR/$BRANCH_NAME"
EOF
    
    chmod +x scripts/worktree-create.sh
}

create_minimal_menu_script() {
    print_info "Creating minimal development menu..."
    
    cat > menu.sh << 'EOF'
#!/bin/bash

set -e

# Colors for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

clear_screen() {
    clear
}

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}                    WINGMAN CLI MENU SYSTEM                    ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Show current context
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local current_dir=$(basename "$PWD")
    echo -e "${CYAN}Project:${NC} ${current_dir}  ${CYAN}Branch:${NC} ${current_branch}"
    
    # Check if we're in a worktree
    local worktree_info=$(git worktree list --porcelain 2>/dev/null | grep "$(pwd)" | head -1 || echo "")
    if [[ -n "$worktree_info" ]]; then
        echo -e "${PURPLE}Worktree:${NC} $(pwd)"
    fi
    echo
}

show_main_menu() {
    print_header
    echo -e "${WHITE}Main Menu:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Switch Worktree"
    echo -e "${GREEN}2.${NC} Create New Worktree" 
    echo -e "${GREEN}3.${NC} Delete Worktree"
    echo -e "${GREEN}4.${NC} Git Operations"
    echo -e "${GREEN}5.${NC} Launch Claude Code"
    echo -e "${GREEN}6.${NC} Launch Editor"
    echo -e "${GREEN}7.${NC} Project Info"
    echo
    echo -e "${RED}0.${NC} Exit"
    echo
    echo -n "Select option [0-7]: "
}

show_worktree_menu() {
    clear_screen
    print_header
    echo -e "${WHITE}Switch Worktree:${NC}"
    echo
    
    local worktrees=$(git worktree list 2>/dev/null)
    if [[ -z "$worktrees" ]]; then
        echo -e "${RED}No worktrees found${NC}"
        echo -n "Press Enter to continue..."
        read
        return
    fi
    
    echo "$worktrees"
    echo
    local count=1
    local worktree_paths=()
    
    while IFS= read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        local branch=$(echo "$line" | awk '{print $2}' | tr -d '[]')
        worktree_paths+=("$path")
        echo -e "${GREEN}${count}.${NC} ${CYAN}${branch}${NC} - ${path}"
        ((count++))
    done <<< "$worktrees"
    
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select worktree [0-$((count-1))]: "
    
    read choice
    if [[ "$choice" == "0" ]]; then
        return
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -lt "$count" ]]; then
        local target_path="${worktree_paths[$((choice-1))]}"
        echo
        echo -e "${YELLOW}Switching to: $target_path${NC}"
        cd "$target_path" && exec bash
    else
        echo -e "${RED}Invalid choice!${NC}"
        sleep 1
    fi
}

create_worktree() {
    clear_screen
    print_header
    echo -e "${WHITE}Create New Worktree:${NC}"
    echo
    
    echo -n "Enter branch name: "
    read branch_name
    
    if [[ -z "$branch_name" ]]; then
        echo -e "${RED}Branch name cannot be empty!${NC}"
        sleep 2
        return
    fi
    
    echo -n "Base branch (default: main): "
    read base_branch
    base_branch=${base_branch:-main}
    
    echo
    echo -e "${YELLOW}Creating worktree '$branch_name' from '$base_branch'...${NC}"
    
    if ./scripts/worktree-create.sh "$branch_name" "$base_branch" 2>/dev/null || {
        # Fallback if script doesn't exist
        if git show-ref --quiet "refs/heads/$branch_name"; then
            git worktree add ".worktrees/$branch_name" "$branch_name"
        else
            git worktree add -b "$branch_name" ".worktrees/$branch_name" "$base_branch"
        fi
    }; then
        echo -e "${GREEN}Worktree created successfully!${NC}"
    else
        echo -e "${RED}Failed to create worktree${NC}"
    fi
    
    echo
    echo -n "Press Enter to continue..."
    read
}

delete_worktree() {
    clear_screen
    print_header
    echo -e "${WHITE}Delete Worktree:${NC}"
    echo
    
    local worktrees=$(git worktree list 2>/dev/null | grep -v "$(git rev-parse --show-toplevel)")
    if [[ -z "$worktrees" ]]; then
        echo -e "${RED}No additional worktrees found to delete${NC}"
        echo -n "Press Enter to continue..."
        read
        return
    fi
    
    echo "$worktrees"
    echo
    local count=1
    local worktree_info=()
    
    while IFS= read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        local branch=$(echo "$line" | awk '{print $2}' | tr -d '[]')
        worktree_info+=("$path|$branch")
        echo -e "${GREEN}${count}.${NC} ${CYAN}${branch}${NC} - ${path}"
        ((count++))
    done <<< "$worktrees"
    
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select worktree to delete [0-$((count-1))]: "
    
    read choice
    if [[ "$choice" == "0" ]]; then
        return
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -lt "$count" ]]; then
        local info="${worktree_info[$((choice-1))]}"
        local path=$(echo "$info" | cut -d'|' -f1)
        local branch=$(echo "$info" | cut -d'|' -f2)
        
        echo
        echo -e "${RED}WARNING: This will delete worktree '$branch' at '$path'${NC}"
        echo -n "Are you sure? [y/N]: "
        read confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Deleting worktree...${NC}"
            git worktree remove "$path" --force
            echo -e "${GREEN}Worktree deleted successfully!${NC}"
        else
            echo -e "${YELLOW}Cancelled${NC}"
        fi
    else
        echo -e "${RED}Invalid choice!${NC}"
        sleep 1
    fi
    
    echo
    echo -n "Press Enter to continue..."
    read
}

show_git_menu() {
    clear_screen
    print_header
    echo -e "${WHITE}Git Operations:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Git Status"
    echo -e "${GREEN}2.${NC} Git Pull"
    echo -e "${GREEN}3.${NC} Git Push"
    echo -e "${GREEN}4.${NC} Git Log (last 5 commits)"
    echo -e "${GREEN}5.${NC} List Branches"
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select option [0-5]: "
    
    read choice
    case $choice in
        1) clear_screen && git status && echo && echo -n "Press Enter to continue..." && read ;;
        2) clear_screen && git pull && echo && echo -n "Press Enter to continue..." && read ;;
        3) clear_screen && git push && echo && echo -n "Press Enter to continue..." && read ;;
        4) clear_screen && git log --oneline -5 && echo && echo -n "Press Enter to continue..." && read ;;
        5) clear_screen && git branch -a && echo && echo -n "Press Enter to continue..." && read ;;
        0) return ;;
        *) echo -e "${RED}Invalid choice!${NC}" && sleep 1 ;;
    esac
}

launch_claude() {
    clear_screen
    echo -e "${YELLOW}Launching Claude Code...${NC}"
    if command -v claude >/dev/null 2>&1; then
        claude
    else
        echo -e "${RED}Claude Code not found in PATH${NC}"
        echo -n "Press Enter to continue..."
        read
    fi
}

launch_editor() {
    clear_screen
    print_header
    echo -e "${WHITE}Launch Editor:${NC}"
    echo
    echo -e "${GREEN}1.${NC} VSCode (code .)"
    echo -e "${GREEN}2.${NC} VSCode Insiders (code-insiders .)"
    echo -e "${GREEN}3.${NC} Vim"
    echo -e "${GREEN}4.${NC} Nano"
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select editor [0-4]: "
    
    read choice
    case $choice in
        1) command -v code >/dev/null 2>&1 && code . || echo -e "${RED}VSCode not found${NC}" ;;
        2) command -v code-insiders >/dev/null 2>&1 && code-insiders . || echo -e "${RED}VSCode Insiders not found${NC}" ;;
        3) vim . ;;
        4) nano . ;;
        0) return ;;
        *) echo -e "${RED}Invalid choice!${NC}" && sleep 1 ;;
    esac
}

show_project_info() {
    clear_screen
    print_header
    echo -e "${WHITE}Project Information:${NC}"
    echo
    
    echo -e "${CYAN}Current Directory:${NC} $(pwd)"
    echo -e "${CYAN}Git Branch:${NC} $(git branch --show-current 2>/dev/null || echo 'Not a git repository')"
    
    # Show language/framework specific info if available
    if command -v node >/dev/null 2>&1; then
        echo -e "${CYAN}Node Version:${NC} $(node --version)"
    fi
    if command -v npm >/dev/null 2>&1; then
        echo -e "${CYAN}NPM Version:${NC} $(npm --version)"
    fi
    if command -v python3 >/dev/null 2>&1; then
        echo -e "${CYAN}Python Version:${NC} $(python3 --version)"
    fi
    if command -v go >/dev/null 2>&1; then
        echo -e "${CYAN}Go Version:${NC} $(go version)"
    fi
    if command -v cargo >/dev/null 2>&1; then
        echo -e "${CYAN}Rust Version:${NC} $(rustc --version)"
    fi
    
    echo
    echo -n "Press Enter to continue..."
    read
}

main_loop() {
    while true; do
        clear_screen
        show_main_menu
        read choice
        
        case $choice in
            1) show_worktree_menu ;;
            2) create_worktree ;;
            3) delete_worktree ;;
            4) show_git_menu ;;
            5) launch_claude ;;
            6) launch_editor ;;
            7) show_project_info ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid choice! Please select 0-7.${NC}"; sleep 1 ;;
        esac
    done
}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Warning: This doesn't appear to be a git repository.${NC}"
    echo "The menu system works best when run from a git repository root."
    echo
fi

main_loop
EOF
    
    chmod +x menu.sh
    print_success "Minimal menu script created"
}

create_enhanced_menu_script() {
    print_info "Creating enhanced development menu..."
    
    # Use the existing menu.sh from the original function but make it more generic
    cat > menu.sh << 'EOF'
#!/bin/bash

set -e

# Colors for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

clear_screen() {
    clear
}

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${WHITE}                    WINGMAN CLI MENU SYSTEM                    ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Show current context
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local current_dir=$(basename "$PWD")
    echo -e "${CYAN}Project:${NC} ${current_dir}  ${CYAN}Branch:${NC} ${current_branch}"
    
    # Check if we're in a worktree
    local worktree_info=$(git worktree list --porcelain 2>/dev/null | grep "$(pwd)" | head -1 || echo "")
    if [[ -n "$worktree_info" ]]; then
        echo -e "${PURPLE}Worktree:${NC} $(pwd)"
    fi
    echo
}

show_main_menu() {
    print_header
    echo -e "${WHITE}Main Menu:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Switch Worktree"
    echo -e "${GREEN}2.${NC} Create New Worktree" 
    echo -e "${GREEN}3.${NC} Delete Worktree"
    echo -e "${GREEN}4.${NC} Run Scripts"
    echo -e "${GREEN}5.${NC} Git Operations"
    
    # Conditionally show database operations if database setup exists
    if [ -f "scripts/migrate.js" ] || [ -f "db/database.sqlite" ]; then
        echo -e "${GREEN}6.${NC} Database Operations"
        echo -e "${GREEN}7.${NC} Launch Claude Code"
        echo -e "${GREEN}8.${NC} Launch Editor"
        echo -e "${GREEN}9.${NC} Project Info"
    else
        echo -e "${GREEN}6.${NC} Launch Claude Code"
        echo -e "${GREEN}7.${NC} Launch Editor"
        echo -e "${GREEN}8.${NC} Project Info"
    fi
    
    echo
    echo -e "${RED}0.${NC} Exit"
    echo
    echo -n "Select option: "
}

show_scripts_menu() {
    clear_screen
    print_header
    echo -e "${WHITE}Available Scripts:${NC}"
    echo
    
    local scripts=""
    if [ -f "package.json" ]; then
        # Parse package.json scripts - try jq first, fallback to grep/sed
        if command -v jq >/dev/null 2>&1; then
            scripts=$(jq -r '.scripts | to_entries[] | "\(.key)|\(.value)"' package.json 2>/dev/null)
        else
            # Fallback parsing without jq
            scripts=$(grep -A 20 '"scripts"' package.json | sed -n '/".*":/p' | sed 's/.*"\([^"]*\)": *"\([^"]*\)".*/\1|\2/' | head -20)
        fi
    fi
    
    if [[ -z "$scripts" ]]; then
        echo -e "${RED}No scripts found in package.json${NC}"
        echo
        echo -n "Press Enter to return to main menu..."
        read
        return
    fi
    
    local count=1
    local script_names=()
    
    while IFS='|' read -r name command; do
        [[ -z "$name" ]] && continue
        echo -e "${GREEN}${count}.${NC} ${CYAN}${name}${NC} - ${command}"
        script_names+=("$name")
        ((count++))
    done <<< "$scripts"
    
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select script to run [0-${#script_names[@]}]: "
    
    read choice
    if [[ "$choice" == "0" ]]; then
        return
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#script_names[@]}" ]]; then
        local script_name="${script_names[$((choice-1))]}"
        echo
        echo -e "${YELLOW}Running: npm run $script_name${NC}"
        echo
        npm run "$script_name"
        echo
        echo -n "Press Enter to continue..."
        read
    else
        echo -e "${RED}Invalid choice!${NC}"
        sleep 1
    fi
}

# Include other menu functions (simplified for enhancement mode)
show_worktree_menu() {
    clear_screen
    print_header
    echo -e "${WHITE}Switch Worktree:${NC}"
    echo
    
    local worktrees=$(git worktree list 2>/dev/null)
    if [[ -z "$worktrees" ]]; then
        echo -e "${RED}No worktrees found${NC}"
        echo -n "Press Enter to continue..."
        read
        return
    fi
    
    echo "$worktrees"
    echo
    local count=1
    local worktree_paths=()
    
    while IFS= read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        local branch=$(echo "$line" | awk '{print $2}' | tr -d '[]')
        worktree_paths+=("$path")
        echo -e "${GREEN}${count}.${NC} ${CYAN}${branch}${NC} - ${path}"
        ((count++))
    done <<< "$worktrees"
    
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select worktree [0-$((count-1))]: "
    
    read choice
    if [[ "$choice" == "0" ]]; then
        return
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -lt "$count" ]]; then
        local target_path="${worktree_paths[$((choice-1))]}"
        echo
        echo -e "${YELLOW}Switching to: $target_path${NC}"
        cd "$target_path" && exec bash
    else
        echo -e "${RED}Invalid choice!${NC}"
        sleep 1
    fi
}

# Simplified menu functions for enhancement mode
show_git_menu() {
    clear_screen
    print_header
    echo -e "${WHITE}Git Operations:${NC}"
    echo
    echo -e "${GREEN}1.${NC} Git Status"
    echo -e "${GREEN}2.${NC} Git Log (last 5 commits)"
    echo -e "${GREEN}3.${NC} List Branches"
    echo
    echo -e "${RED}0.${NC} Back to Main Menu"
    echo
    echo -n "Select option [0-3]: "
    
    read choice
    case $choice in
        1) clear_screen && git status && echo && echo -n "Press Enter to continue..." && read ;;
        2) clear_screen && git log --oneline -5 && echo && echo -n "Press Enter to continue..." && read ;;
        3) clear_screen && git branch -a && echo && echo -n "Press Enter to continue..." && read ;;
        0) return ;;
        *) echo -e "${RED}Invalid choice!${NC}" && sleep 1 ;;
    esac
}

launch_claude() {
    clear_screen
    echo -e "${YELLOW}Launching Claude Code...${NC}"
    if command -v claude >/dev/null 2>&1; then
        claude
    else
        echo -e "${RED}Claude Code not found in PATH${NC}"
        echo -n "Press Enter to continue..."
        read
    fi
}

main_loop() {
    while true; do
        clear_screen
        show_main_menu
        read choice
        
        # Check if database operations are available
        local has_db_ops=false
        if [ -f "scripts/migrate.js" ] || [ -f "db/database.sqlite" ]; then
            has_db_ops=true
        fi
        
        if [ "$has_db_ops" = true ]; then
            case $choice in
                1) show_worktree_menu ;;
                2) ./scripts/worktree-create.sh ;;
                3) echo "Worktree deletion not implemented in simplified menu" ;;
                4) show_scripts_menu ;;
                5) show_git_menu ;;
                6) echo "Database operations not implemented in simplified menu" ;;
                7) launch_claude ;;
                8) code . 2>/dev/null || echo "Editor not available" ;;
                9) echo "Project info display not implemented in simplified menu" ;;
                0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
                *) echo -e "${RED}Invalid choice!${NC}"; sleep 1 ;;
            esac
        else
            case $choice in
                1) show_worktree_menu ;;
                2) ./scripts/worktree-create.sh ;;
                3) echo "Worktree deletion not implemented in simplified menu" ;;
                4) show_scripts_menu ;;
                5) show_git_menu ;;
                6) launch_claude ;;
                7) code . 2>/dev/null || echo "Editor not available" ;;
                8) echo "Project info display not implemented in simplified menu" ;;
                0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
                *) echo -e "${RED}Invalid choice!${NC}"; sleep 1 ;;
            esac
        fi
    done
}

# Check if we're in a project directory
if [[ ! -f "package.json" ]] && [[ ! -d ".git" ]]; then
    echo -e "${RED}Warning: This doesn't appear to be a project root directory.${NC}"
    echo "The menu system works best when run from a project root."
    echo
fi

main_loop
EOF
    
    chmod +x menu.sh
    print_success "Enhanced menu script created"
}

configure_project_settings() {
    print_info "Configuring project settings..."
    
    # Use detected values as defaults
    local default_name="${DETECTED_PROJECT_NAME:-$(basename "$PWD")}"
    local default_desc="${DETECTED_DESCRIPTION:-"Enhanced with Wingman CLI tooling"}"
    local default_author="${DETECTED_AUTHOR:-$(git config --global user.name 2>/dev/null || echo 'Your Name')}"
    
    if [ "$MODE" = "enhance" ]; then
        # In enhance mode, use detected values or ask for minimal input
        PROJECT_NAME="$default_name"
        PROJECT_DESCRIPTION="$default_desc"
        AUTHOR_NAME="$default_author"
        LICENSE="MIT"
        
        echo "Enhancing existing project: $PROJECT_NAME"
        echo "Description: $PROJECT_DESCRIPTION"
        echo
        
        prompt_input "GitHub repository (e.g., username/repo or full URL, leave empty to skip)" GITHUB_REPO ""
    else
        # In init mode, ask for all configuration
        prompt_input "Project name" PROJECT_NAME "$default_name"
        prompt_input "Project description" PROJECT_DESCRIPTION "A new Node.js project"
        prompt_input "Author name" AUTHOR_NAME "$default_author"
        prompt_input "License" LICENSE "MIT"
        prompt_input "GitHub repository (e.g., username/repo or full URL, leave empty to skip)" GITHUB_REPO ""
    fi
}

main() {
    clear
    print_header
    
    # Parse command line arguments and determine mode
    determine_init_mode "$1"
    
    # Analyze existing repository if present
    analyze_existing_repo
    
    # Check compatibility
    check_project_compatibility
    
    # Check prerequisites
    check_prerequisites
    
    echo
    print_info "Project Configuration"
    echo
    
    # Configure project settings based on mode
    configure_project_settings
    
    echo
    if [ "$MODE" = "enhance" ]; then
        print_info "Enhancing existing project..."
    else
        print_info "Initializing new project..."
    fi
    echo
    
    # Execute appropriate setup based on mode
    if [ "$MODE" = "enhance" ]; then
        # Enhancement mode - selective additions
        setup_project_structure_selective
        
        if [ "$IS_NODE_PROJECT" = true ]; then
            enhance_existing_package_json
            
            # Only setup database if it's not already present
            if [ ! -f "src/db/connection.js" ] && [ ! -f "db/database.sqlite" ]; then
                if prompt_yes_no "Add SQLite database setup?" "y"; then
                    setup_sqlite
                fi
            fi
        fi
        
        setup_worktrees_enhance
        
        # Only create menu if it doesn't exist
        if [ ! -f "menu.sh" ]; then
            create_enhanced_menu_script
        fi
        
        # Only setup environment if it doesn't exist
        if [ ! -f ".env" ] && [ ! -f ".env.example" ]; then
            create_env_file
        fi
        
        setup_github_remote
        
    elif [ "$MODE" = "minimal" ]; then
        # Minimal mode - only worktree management and menu
        # Create minimal scripts directory if needed
        [ ! -d "scripts" ] && mkdir -p scripts
        
        setup_worktrees_enhance
        
        # Create a language-agnostic menu script
        if [ ! -f "menu.sh" ]; then
            create_minimal_menu_script
        fi
        
        # Optional GitHub remote setup
        setup_github_remote
        
    else
        # Full initialization mode - create everything
        setup_project_structure
        
        # Initialize git if not already a repo
        if [ "$IS_GIT_REPO" = false ]; then
            initialize_git
        fi
        
        # Only setup Node.js if no other project type is detected or if requested
        if [ "$PROJECT_TYPE" = "unknown" ] || [ "$PROJECT_TYPE" = "nodejs" ]; then
            initialize_nodejs
            setup_sqlite
            create_env_file
        fi
        
        create_readme
        setup_worktrees
        setup_github_remote
    fi
    
    echo
    print_header
    
    if [ "$MODE" = "enhance" ]; then
        print_success "Project enhancement complete!"
        echo
        print_info "Added features:"
        echo "  - Worktree management scripts"
        echo "  - Enhanced development menu"
        [ "$IS_NODE_PROJECT" = true ] && echo "  - Additional npm scripts"
        [ ! -f ".env" ] && echo "  - Environment configuration"
    elif [ "$MODE" = "minimal" ]; then
        print_success "Minimal setup complete!"
        echo
        print_info "Added features:"
        echo "  - Worktree management scripts"
        echo "  - Language-agnostic development menu"
        echo "  - Git operations interface"
    else
        print_success "Project initialization complete!"
        echo
        print_info "Next steps:"
        if [ "$PROJECT_TYPE" = "nodejs" ] || [ "$PROJECT_TYPE" = "unknown" ]; then
            echo "  1. Run: npm install"
            echo "  2. Run: npm run db:migrate"
            echo "  3. Run: npm run dev"
        else
            echo "  1. Customize your project as needed"
            echo "  2. Use ./menu.sh for worktree management"
            echo "  3. Use worktree scripts in scripts/ directory"
        fi
    fi
    
    echo
    print_info "Wingman CLI commands:"
    if [ "$IS_NODE_PROJECT" = true ] && [ "$MODE" != "minimal" ]; then
        echo "  - Switch worktree: npm run worktree:switch <branch>"
        echo "  - Create worktree: npm run worktree:create <branch>"
        echo "  - Development menu: npm run menu"
    else
        echo "  - Switch worktree: ./scripts/worktree-switch.sh <branch>"
        echo "  - Create worktree: ./scripts/worktree-create.sh <branch>"
        echo "  - Development menu: ./menu.sh"
    fi
    echo
    
    if [ -n "$GITHUB_REPO" ]; then
        print_info "GitHub remote: $(git remote get-url origin 2>/dev/null || echo 'Not configured')"
    fi
}

main "$@"