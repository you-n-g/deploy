#!/bin/sh

# No luck...
# cd ~/apps/
# git clone https://github.com/langfuse/langfuse.git
# cd langfuse
# docker compose up -d

# cat .env.prod | grep LANGFUSE_INIT_USER_EMAIL
# cat .env.prod | grep LANGFUSE_INIT

docker pull langfuse/langfuse:2

docker run --name langfuse \
-e DATABASE_URL=postgresql://hello \
-e NEXTAUTH_URL=http://localhost:3000 \
-e NEXTAUTH_SECRET=mysecret \
-e SALT=mysalt \
-e ENCRYPTION_KEY=$(openssl rand -hex 32) \
-p 3000:3000 \
-a STDOUT \
langfuse/langfuse
