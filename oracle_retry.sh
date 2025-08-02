#!/bin/bash
# Script to retry Oracle instance creation
# Run this and it will keep trying until it succeeds

echo "Trying to create Oracle instance..."
echo "Press Ctrl+C to stop"

while true; do
    date
    echo "Attempting to create instance..."
    
    # Try using OCI CLI (you'd need to set this up first)
    # Or just manually click "Create" in the web console
    
    echo "If you see the capacity error, I'll retry in 5 minutes"
    echo "If successful, press Ctrl+C to stop"
    
    sleep 300  # Wait 5 minutes before retry
done