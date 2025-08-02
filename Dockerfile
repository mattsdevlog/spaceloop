FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    libx11-6 \
    libxcursor1 \
    libxinerama1 \
    libgl1 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libasound2 \
    libpulse0 \
    libudev1 \
    && rm -rf /var/lib/apt/lists/*

# Download Godot headless
RUN wget -q https://downloads.tuxfamily.org/godotengine/4.3/Godot_v4.3-stable_linux.x86_64.zip \
    && unzip -q Godot_v4.3-stable_linux.x86_64.zip \
    && mv Godot_v4.3-stable_linux.x86_64 /usr/local/bin/godot \
    && rm Godot_v4.3-stable_linux.x86_64.zip

WORKDIR /app
COPY . .

# Railway dynamically assigns ports via PORT env var
EXPOSE 8910 8911

CMD ["godot", "--headless", "--path", ".", "run_server.gd"]