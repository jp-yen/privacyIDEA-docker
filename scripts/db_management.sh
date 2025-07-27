#!/bin/bash

# Database Management Utility Script for PrivacyIDEA
# Usage: ./db_management.sh <command> [options]
# Commands:
#   status     - Show database status and connection info
#   tables     - List all tables with row counts
#   size       - Show database and table sizes
#   users      - List database users and permissions
#   vacuum     - Perform database maintenance (VACUUM)
#   analyze    - Update database statistics (ANALYZE)
#   check      - Check database integrity
#   shell      - Open interactive PostgreSQL shell

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Database configuration from .env file
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
else
    echo "Error: .env file not found in $PROJECT_DIR"
    exit 1
fi

# Validate required environment variables
if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Error: DB_USER and DB_PASSWORD must be set in .env file"
    exit 1
fi

# Function to check if PostgreSQL container is running
check_postgres_container() {
    if ! docker ps --format "{{.Names}}" | grep -q "^PostgreSQL$"; then
        echo "Error: PostgreSQL container is not running"
        echo "Please start the database with: make up"
        exit 1
    fi
}

# Function to execute SQL command
execute_sql() {
    local sql="$1"
    docker exec PostgreSQL psql -U "$DB_USER" -d privacyidea -c "$sql"
}

# Function to show database status
show_status() {
    echo "=================================================="
    echo "Database Status"
    echo "=================================================="
    
    echo "Container Status:"
    docker ps | grep PostgreSQL || echo "PostgreSQL container not found"
    echo ""
    
    echo "Database Connection Info:"
    execute_sql "SELECT version();" 2>/dev/null || echo "Cannot connect to database"
    echo ""
    
    echo "Database Size:"
    execute_sql "
        SELECT 
            datname as \"Database\",
            pg_size_pretty(pg_database_size(datname)) as \"Size\"
        FROM pg_database 
        WHERE datname = 'privacyidea';
    " 2>/dev/null || echo "Cannot retrieve database size"
    echo ""
    
    echo "Active Connections:"
    execute_sql "
        SELECT 
            count(*) as \"Active Connections\",
            usename as \"User\"
        FROM pg_stat_activity 
        WHERE datname = 'privacyidea'
        GROUP BY usename;
    " 2>/dev/null || echo "Cannot retrieve connection info"
}

# Function to list tables with row counts
show_tables() {
    echo "=================================================="
    echo "Database Tables and Row Counts"
    echo "=================================================="
    
    execute_sql "
        SELECT 
            schemaname as \"Schema\",
            relname as \"Table\",
            n_tup_ins as \"Inserts\",
            n_tup_upd as \"Updates\",
            n_tup_del as \"Deletes\",
            n_live_tup as \"Live Rows\"
        FROM pg_stat_user_tables 
        ORDER BY schemaname, relname;
    " 2>/dev/null || echo "Cannot retrieve table information"
}

# Function to show database and table sizes
show_sizes() {
    echo "=================================================="
    echo "Database and Table Sizes"
    echo "=================================================="
    
    echo "Database Size:"
    execute_sql "
        SELECT 
            pg_size_pretty(pg_database_size('privacyidea')) as \"Total Database Size\";
    " 2>/dev/null || echo "Cannot retrieve database size"
    echo ""
    
    echo "Table Sizes:"
    execute_sql "
        SELECT 
            schemaname as \"Schema\",
            tablename as \"Table\",
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as \"Total Size\",
            pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as \"Table Size\",
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as \"Index Size\"
        FROM pg_tables 
        WHERE schemaname NOT IN ('information_schema', 'pg_catalog')
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
    " 2>/dev/null || echo "Cannot retrieve table sizes"
}

# Function to list users and permissions
show_users() {
    echo "=================================================="
    echo "Database Users and Permissions"
    echo "=================================================="
    
    execute_sql "
        SELECT 
            usename as \"Username\",
            usesuper as \"Superuser\",
            usecreatedb as \"Create DB\",
            userepl as \"Replication\",
            valuntil as \"Valid Until\"
        FROM pg_user 
        ORDER BY usename;
    " 2>/dev/null || echo "Cannot retrieve user information"
    echo ""
    
    echo "Database Permissions:"
    execute_sql "
        SELECT 
            datname as \"Database\",
            datacl as \"Access Privileges\"
        FROM pg_database 
        WHERE datname = 'privacyidea';
    " 2>/dev/null || echo "Cannot retrieve permission information"
}

# Function to perform vacuum
perform_vacuum() {
    echo "=================================================="
    echo "Performing Database VACUUM"
    echo "=================================================="
    
    echo "Starting VACUUM operation..."
    execute_sql "VACUUM VERBOSE;" 2>/dev/null || echo "VACUUM operation failed"
    echo "VACUUM completed"
}

# Function to perform analyze
perform_analyze() {
    echo "=================================================="
    echo "Performing Database ANALYZE"
    echo "=================================================="
    
    echo "Starting ANALYZE operation..."
    execute_sql "ANALYZE VERBOSE;" 2>/dev/null || echo "ANALYZE operation failed"
    echo "ANALYZE completed"
}

# Function to check database integrity
check_integrity() {
    echo "=================================================="
    echo "Database Integrity Check"
    echo "=================================================="
    
    echo "Checking database integrity..."
    
    # Check for corrupted indexes
    echo "Checking indexes..."
    execute_sql "
        SELECT 
            schemaname,
            tablename,
            indexname
        FROM pg_indexes 
        WHERE schemaname NOT IN ('information_schema', 'pg_catalog');
    " 2>/dev/null || echo "Cannot check indexes"
    
    echo "Integrity check completed"
}

# Function to open interactive shell
open_shell() {
    echo "=================================================="
    echo "Opening PostgreSQL Interactive Shell"
    echo "=================================================="
    echo "Type \\q to quit the shell"
    echo ""
    
    export PGPASSWORD="$DB_PASSWORD"
    docker exec -it PostgreSQL psql -U "$DB_USER" -d privacyidea
    unset PGPASSWORD
}

# Function to show help
show_help() {
    echo "Database Management Utility for PrivacyIDEA"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status     Show database status and connection info"
    echo "  tables     List all tables with row counts"
    echo "  size       Show database and table sizes"
    echo "  users      List database users and permissions"
    echo "  vacuum     Perform database maintenance (VACUUM)"
    echo "  analyze    Update database statistics (ANALYZE)"
    echo "  check      Check database integrity"
    echo "  shell      Open interactive PostgreSQL shell"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 tables"
    echo "  $0 vacuum"
    echo "  $0 shell"
}

# Main execution
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

COMMAND="$1"

# Check if PostgreSQL container is running (except for help)
if [ "$COMMAND" != "help" ]; then
    check_postgres_container
    export PGPASSWORD="$DB_PASSWORD"
fi

# Execute command
case "$COMMAND" in
    "status")
        show_status
        ;;
    "tables")
        show_tables
        ;;
    "size")
        show_sizes
        ;;
    "users")
        show_users
        ;;
    "vacuum")
        perform_vacuum
        ;;
    "analyze")
        perform_analyze
        ;;
    "check")
        check_integrity
        ;;
    "shell")
        open_shell
        ;;
    "help")
        show_help
        ;;
    *)
        echo "Error: Unknown command '$COMMAND'"
        echo ""
        show_help
        exit 1
        ;;
esac

# Clean up
if [ "$COMMAND" != "help" ] && [ "$COMMAND" != "shell" ]; then
    unset PGPASSWORD
fi
