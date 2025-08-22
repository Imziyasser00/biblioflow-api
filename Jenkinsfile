pipeline {
  agent any
  options { timestamps() }

  environment {
    IMAGE_API = 'biblioflow-api:ci'
    API_PORT  = '3003'                      
COMPOSE = 'docker run --rm -v $PWD:/wrk -w /wrk -v /var/run/docker.sock:/var/run/docker.sock docker/compose:1.29.2'
    PROJECT   = 'biblio-api-ci'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build API Image') {
      steps { sh 'docker build -t ${IMAGE_API} .' }
    }

    stage('Write CI files') {
      steps {
        sh '''
          mkdir -p ci

          # Compose file (no mounts, just images)
          cat > ci/compose.yml <<'YAML'
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
      POSTGRES_DB: testdb
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test -d testdb"]
      interval: 3s
      timeout: 3s
      retries: 20

  mongo:
    image: mongo:7
    command: ["--auth"]
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: rootpw
      MONGO_INITDB_DATABASE: testdb
    healthcheck:
      test: ["CMD-SHELL", "mongosh --quiet -u root -p rootpw --authenticationDatabase admin --eval 'db.adminCommand({ping:1}).ok' | grep 1"]
      interval: 3s
      timeout: 3s
      retries: 20

  api:
    image: ${IMAGE_API}
    environment:
      PORT: 3000
      DATABASE_URL: postgres://test:test@postgres:5432/testdb
      MONGODB_URL: mongodb://root:rootpw@mongo:27017/testdb?authSource=admin
    depends_on:
      postgres:
        condition: service_healthy
      mongo:
        condition: service_healthy
YAML

          # CI override: expose ports on host
          cat > ci/compose.ci.yml <<'YAML'
services:
  api:
    ports:
      - "${API_PORT}:3000"
YAML
        '''
      }
    }

    stage('Compose up') {
      steps {
        sh '''
          ${COMPOSE} -p ${PROJECT} down -v || true
          ${COMPOSE} -p ${PROJECT} -f ci/compose.yml -f ci/compose.ci.yml up -d --force-recreate --remove-orphans
        '''
      }
    }

    stage('Smoke Test') {
      steps {
        sh '''
          # wait for API to listen on the host-mapped port
          for i in $(seq 1 30); do
            if curl -sS http://host.docker.internal:${API_PORT}/books >/dev/null 2>&1; then
              echo "API is up"; break
            fi
            echo "Waiting for API... ($i)"; sleep 1
          done

          # Create a book then list
          curl -sS -X POST http://host.docker.internal:${API_PORT}/books \
               -H "Content-Type: application/json" \
               -d '{"title":"CI Build","author":"Jenkins"}' >/dev/null

          curl -sSf http://host.docker.internal:${API_PORT}/books | tee api_output.json >/dev/null
        '''
      }
    }
  }

  post {
    always {
      sh '''
        ${COMPOSE} -p ${PROJECT} logs --no-color > compose-ci.log 2>&1 || true
        ${COMPOSE} -p ${PROJECT} down || true
      '''
      archiveArtifacts artifacts: 'compose-ci.log, api_output.json', allowEmptyArchive: true
    }
  }
}
