#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR"

# Activate virtual environment
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d "/usr/bin/python3" ]; then
    echo -e "${YELLOW}⚠️ Virtual environment not found. Using system Python. Consider creating a venv: python3 -m venv venv${NC}"
else
    echo -e "${RED}❌ Python3 not found. Please install Python 3.${NC}"
    exit 1
fi

# Install dependencies if not already installed
pip install -r requirements.txt --quiet

# Run the Python application
python3 -m src.main
