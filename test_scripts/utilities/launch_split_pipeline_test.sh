#!/bin/bash
# Launcher script for AlphaFold split pipeline tests
# This script launches the test in the background and provides monitoring

set -e

# Configuration
TEST_BASE="/scratch/alphafold_split_pipeline_test"
LOG_DIR="$TEST_BASE/launcher_logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create log directory
mkdir -p "$LOG_DIR"

# Parse arguments
ARGS="$@"

# Launch test in background with nohup
echo -e "${YELLOW}Launching AlphaFold split pipeline test...${NC}"
echo "Arguments: $ARGS"
echo "Log file: $LOG_DIR/test_${TIMESTAMP}.log"
echo ""

nohup bash test_split_pipeline.sh $ARGS > "$LOG_DIR/test_${TIMESTAMP}.log" 2>&1 &
TEST_PID=$!

echo "Test launched with PID: $TEST_PID"
echo "Test PID: $TEST_PID" > "$TEST_BASE/current_test.pid"

# Create monitoring script
cat > "$TEST_BASE/monitor_test.sh" << 'EOF'
#!/bin/bash
# Monitor running test

TEST_BASE="/scratch/alphafold_split_pipeline_test"
if [ -f "$TEST_BASE/current_test.pid" ]; then
    PID=$(cat "$TEST_BASE/current_test.pid")
    if ps -p $PID > /dev/null; then
        echo "Test is running (PID: $PID)"
        echo ""
        
        # Show recent log activity
        LOG_FILE=$(ls -t "$TEST_BASE/launcher_logs"/test_*.log 2>/dev/null | head -1)
        if [ -f "$LOG_FILE" ]; then
            echo "Recent activity:"
            tail -20 "$LOG_FILE" | grep -E "(Starting|completed|Failed|ERROR|Success)" || tail -5 "$LOG_FILE"
        fi
        
        # Check for completed proteins
        echo ""
        echo "Progress:"
        for protein in 1VII 1UBQ 1LYZ 1MBN; do
            if [ -f "$TEST_BASE/output/$protein/features.pkl" ]; then
                echo "  ✓ $protein - preprocessing done"
            else
                echo "  ⋯ $protein - preprocessing pending/running"
            fi
            if [ -f "$TEST_BASE/output/$protein/ranked_0.pdb" ]; then
                echo "  ✓ $protein - inference done"
            fi
        done
        
        # Show resource usage
        echo ""
        echo "Resource usage:"
        ps -p $PID -o pid,ppid,%cpu,%mem,etime,cmd | tail -1
        
    else
        echo "Test completed or stopped (PID $PID no longer running)"
        rm "$TEST_BASE/current_test.pid"
    fi
else
    echo "No test currently running"
fi

# Show existing results
if [ -f "$TEST_BASE/preprocessing_results.csv" ]; then
    echo ""
    echo "Preprocessing results so far:"
    column -t -s',' "$TEST_BASE/preprocessing_results.csv" | head -10
fi
EOF
chmod +x "$TEST_BASE/monitor_test.sh"

# Create stop script
cat > "$TEST_BASE/stop_test.sh" << 'EOF'
#!/bin/bash
# Stop running test gracefully

TEST_BASE="/scratch/alphafold_split_pipeline_test"
if [ -f "$TEST_BASE/current_test.pid" ]; then
    PID=$(cat "$TEST_BASE/current_test.pid")
    if ps -p $PID > /dev/null; then
        echo "Stopping test (PID: $PID)..."
        # Send SIGTERM for graceful shutdown
        kill -TERM $PID
        sleep 2
        if ps -p $PID > /dev/null; then
            echo "Process still running, sending SIGKILL..."
            kill -KILL $PID
        fi
        rm "$TEST_BASE/current_test.pid"
        echo "Test stopped"
    else
        echo "Test already completed"
        rm "$TEST_BASE/current_test.pid"
    fi
else
    echo "No test currently running"
fi
EOF
chmod +x "$TEST_BASE/stop_test.sh"

# Show instructions
echo -e "${GREEN}Test launched successfully!${NC}"
echo ""
echo "Monitor commands:"
echo "  Watch progress:  $TEST_BASE/monitor_test.sh"
echo "  View full log:   tail -f $LOG_DIR/test_${TIMESTAMP}.log"
echo "  Stop test:       $TEST_BASE/stop_test.sh"
echo ""
echo "The test will run in the background. Check back in ~2 hours."
echo ""

# Do initial monitoring
sleep 5
"$TEST_BASE/monitor_test.sh"