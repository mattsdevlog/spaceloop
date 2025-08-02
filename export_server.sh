#!/bin/bash

# Export server build
godot --headless --export-pack "Linux/X11" server.pck

# Create run script
cat > run_server.sh << 'EOF'
#!/bin/bash
godot --headless --main-pack server.pck
EOF

chmod +x run_server.sh

echo "Server export complete! Upload server.pck and run_server.sh to your cloud server."