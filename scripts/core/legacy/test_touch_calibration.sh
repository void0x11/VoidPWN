#!/bin/bash

################################################################################
# VoidPWN - Touch Calibration Test Script
# Description: Interactive script to find the correct touch calibration matrix
# Author: void0x11
# Usage: sudo ./test_touch_calibration.sh
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

export DISPLAY=:0

echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  VoidPWN Touch Calibration Tester     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Find touch device
log_info "Detecting touch device..."
TOUCH_ID=$(xinput list | grep -i 'touch\|ADS7846' | grep -o 'id=[0-9]*' | grep -o '[0-9]*' | head -1)

if [ -z "$TOUCH_ID" ]; then
    log_warning "Touch device not found!"
    echo "Available input devices:"
    xinput list
    exit 1
fi

log_success "Found touch device ID: $TOUCH_ID"
echo ""

# Test matrices
MATRICES=(
    "1 0 0 0 1 0 0 0 1|Identity (0°)"
    "0 1 0 -1 0 1 0 0 1|90° CW Rotation"
    "-1 0 1 0 -1 1 0 0 1|180° Rotation"
    "0 -1 1 1 0 0 0 0 1|270° CW (90° CCW)"
    "-1 0 1 0 1 0 0 0 1|H-Flip + 180°"
    "1 0 0 0 -1 1 0 0 1|V-Flip"
)

echo -e "${YELLOW}Testing Touch Calibration Matrices${NC}"
echo ""
echo "We'll test each matrix. Touch the screen to see if it works correctly."
echo ""

for i in "${!MATRICES[@]}"; do
    IFS='|' read -r matrix desc <<< "${MATRICES[$i]}"
    
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}Test $((i+1))/${#MATRICES[@]}: ${desc}${NC}"
    echo -e "${CYAN}Matrix: ${matrix}${NC}"
    echo ""
    
    # Apply matrix
    xinput set-prop $TOUCH_ID 'Coordinate Transformation Matrix' $matrix
    
    echo "Touch the screen now to test:"
    echo "  • Touch TOP of screen - cursor should go to TOP"
    echo "  • Touch BOTTOM - cursor to BOTTOM"
    echo "  • Touch LEFT - cursor to LEFT"
    echo "  • Touch RIGHT - cursor to RIGHT"
    echo ""
    
    read -p "Does this matrix work correctly? (y/n): " answer
    
    if [[ "$answer" == "y" ]] || [[ "$answer" == "Y" ]]; then
        echo ""
        log_success "Perfect! This is the correct matrix!"
        echo ""
        echo -e "${YELLOW}Correct Matrix: ${matrix}${NC}"
        echo ""
        echo "To make this permanent, update:"
        echo "  ~/.config/autostart/calibrate-touch.desktop"
        echo ""
        echo "Or run:"
        echo "  sudo ~/VoidPWN/scripts/core/complete_tft_setup.sh"
        echo ""
        exit 0
    fi
done

echo ""
log_warning "None of the standard matrices worked."
echo "You may need custom calibration. Current matrix:"
xinput list-props $TOUCH_ID | grep "Coordinate Transformation Matrix"
