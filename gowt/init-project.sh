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

setup_project_structure() {
    print_info "Setting up project structure..."
    
    mkdir -p src/{controllers,models,services,utils,middleware}
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
        
        if [[ "$GITHUB_REPO" =~ ^https://github.com/.+/.+$ ]]; then
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

main() {
    clear
    print_header
    
    if [ -n "$(ls -A 2>/dev/null)" ] && [ ! -f ".git/config" ]; then
        print_error "Current directory is not empty and not a git repository."
        if ! prompt_yes_no "Continue anyway?" "n"; then
            exit 1
        fi
    fi
    
    check_prerequisites
    
    echo
    print_info "Project Configuration"
    echo
    
    prompt_input "Project name" PROJECT_NAME "$(basename "$PWD")"
    prompt_input "Project description" PROJECT_DESCRIPTION "A new Node.js project"
    prompt_input "Author name" AUTHOR_NAME "$(git config --global user.name 2>/dev/null || echo 'Your Name')"
    prompt_input "License" LICENSE "MIT"
    prompt_input "GitHub repository (e.g., username/repo or full URL, leave empty to skip)" GITHUB_REPO ""
    
    echo
    print_info "Starting project initialization..."
    echo
    
    setup_project_structure
    initialize_git
    initialize_nodejs
    setup_sqlite
    create_env_file
    create_readme
    setup_worktrees
    setup_github_remote
    
    echo
    print_header
    print_success "Project initialization complete!"
    echo
    print_info "Next steps:"
    echo "  1. Run: npm install"
    echo "  2. Run: npm run db:migrate"
    echo "  3. Run: npm run dev"
    echo
    print_info "Worktree commands:"
    echo "  - Switch worktree: npm run worktree:switch <branch>"
    echo "  - Create worktree: npm run worktree:create <branch>"
    echo
    
    if [ -n "$GITHUB_REPO" ]; then
        print_info "GitHub remote: $(git remote get-url origin 2>/dev/null || echo 'Not configured')"
    fi
}

main "$@"