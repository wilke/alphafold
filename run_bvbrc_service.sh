#!/bin/bash
#
# BV-BRC AlphaFold Service Runner
# 
# This script provides the proper mounting and environment setup to run
# the BV-BRC AlphaFold service (App-AlphaFold.pl) with the unified Patric container.
#
# Requirements:
# - dev_container repository mounted at /dev_container
# - AlphaFoldApp repository mounted at /AlphaFoldApp
# - Container must have writable tmpfs for service operations
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_IMAGE="../images/alphafold_unified_patric.sif"
ALPHAFOLD_BASE_DIR="/nfs/ml_lab/projects/ml_lab/cepi/alphafold"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking BV-BRC service prerequisites..."
    
    # Check if container exists
    if [ ! -f "$CONTAINER_IMAGE" ]; then
        log_error "Container not found: $CONTAINER_IMAGE"
        exit 1
    fi
    
    # Check if dev_container exists
    if [ ! -d "$ALPHAFOLD_BASE_DIR/dev_container" ]; then
        log_error "dev_container not found: $ALPHAFOLD_BASE_DIR/dev_container"
        log_info "Please ensure dev_container repository is cloned to $ALPHAFOLD_BASE_DIR/dev_container"
        exit 1
    fi
    
    # Check if AlphaFoldApp exists
    if [ ! -d "$ALPHAFOLD_BASE_DIR/AlphaFoldApp" ]; then
        log_error "AlphaFoldApp not found: $ALPHAFOLD_BASE_DIR/AlphaFoldApp"
        log_info "Please ensure AlphaFoldApp repository is cloned to $ALPHAFOLD_BASE_DIR/AlphaFoldApp"
        exit 1
    fi
    
    # Check if service script exists
    local service_script="$ALPHAFOLD_BASE_DIR/AlphaFoldApp/service-scripts/App-AlphaFold.pl"
    if [ ! -f "$service_script" ]; then
        log_error "BV-BRC service script not found: $service_script"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Display usage information
usage() {
    cat << EOF
BV-BRC AlphaFold Service Runner

Usage: $0 [OPTIONS] [SERVICE_ARGS...]

This script runs the BV-BRC AlphaFold service (App-AlphaFold.pl) with proper
container mounting and environment setup.

OPTIONS:
    -h, --help          Show this help message
    -i, --interactive   Start interactive shell instead of running service
    -v, --verbose       Enable verbose output
    --dry-run          Show command that would be executed without running it

SERVICE_ARGS:
    Arguments passed directly to the App-AlphaFold.pl service script
    
    Common service arguments:
    - job_id              BV-BRC job identifier
    - app_definition.json Application definition file
    - parameters.json     Job parameters file

EXAMPLES:
    # Interactive shell for debugging
    $0 --interactive
    
    # Run BV-BRC service with job parameters
    $0 job_12345 app_definition.json parameters.json
    
    # Show what command would be executed
    $0 --dry-run job_12345 app_definition.json parameters.json

REQUIRED REPOSITORIES:
    The following repositories must be present:
    - $ALPHAFOLD_BASE_DIR/dev_container     (BV-BRC development environment)
    - $ALPHAFOLD_BASE_DIR/AlphaFoldApp      (BV-BRC AlphaFold application)

CONTAINER REQUIREMENTS:
    - Container: $CONTAINER_IMAGE
    - Mount Points:
      * dev_container → /dev_container
      * AlphaFoldApp → /AlphaFoldApp
    - Writable tmpfs for service operations
EOF
}

# Build and execute the apptainer command
run_service() {
    local interactive=false
    local verbose=false
    local dry_run=false
    local service_args=()
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                service_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Build the apptainer command
    local apptainer_cmd=(
        "apptainer"
    )
    
    if [ "$interactive" = true ]; then
        apptainer_cmd+=("shell")
    else
        apptainer_cmd+=("run" "--app" "bvbrc")
    fi
    
    # Add container options
    apptainer_cmd+=(
        "--writable-tmpfs"
        "--bind" "$ALPHAFOLD_BASE_DIR/dev_container:/dev_container"
        "--bind" "$ALPHAFOLD_BASE_DIR/AlphaFoldApp:/AlphaFoldApp"
        "$CONTAINER_IMAGE"
    )
    
    # Add service arguments if not interactive
    if [ "$interactive" = false ] && [ ${#service_args[@]} -gt 0 ]; then
        apptainer_cmd+=("${service_args[@]}")
    fi
    
    # Display command information
    if [ "$verbose" = true ] || [ "$dry_run" = true ]; then
        log_info "Container: $CONTAINER_IMAGE"
        log_info "Mount points:"
        log_info "  - $ALPHAFOLD_BASE_DIR/dev_container → /dev_container"
        log_info "  - $ALPHAFOLD_BASE_DIR/AlphaFoldApp → /AlphaFoldApp"
        log_info "Command: ${apptainer_cmd[*]}"
        echo
    fi
    
    # Execute or display command
    if [ "$dry_run" = true ]; then
        log_info "Dry run - command would be executed:"
        echo "${apptainer_cmd[*]}"
        return 0
    fi
    
    if [ "$interactive" = true ]; then
        log_info "Starting interactive BV-BRC service shell..."
        log_info "Inside the container, you can run:"
        log_info "  perl /AlphaFoldApp/service-scripts/App-AlphaFold.pl [args]"
        echo
    else
        log_info "Running BV-BRC AlphaFold service..."
        if [ ${#service_args[@]} -eq 0 ]; then
            log_warning "No service arguments provided - service may require job parameters"
        fi
    fi
    
    # Execute the command
    exec "${apptainer_cmd[@]}"
}

# Main execution
main() {
    log_info "BV-BRC AlphaFold Service Runner"
    
    check_prerequisites
    run_service "$@"
}

# Handle script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi