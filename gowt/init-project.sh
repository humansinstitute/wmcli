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
    "worktree:create": "./scripts/worktree-create.sh"
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