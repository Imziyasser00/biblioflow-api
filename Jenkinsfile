pipeline {
  agent any
  options { timestamps() }

  environment {
    TEST_PORT = "3003"
    IMAGE = "biblioflow-api:ci"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build API Image') {
      steps {
        sh "docker build -t $IMAGE ."
      }
    }

    stage('Spin up stack') {
      steps {
        sh '''
          mkdir -p ci/db-init/postgres
          mkdir -p ci/db-init/mongo

          cat > ci/docker-compose.yml <<'YAML'
          version: "3.9"
          services:
            api:
              image: ${IMAGE}
              ports:
                - "${TEST_PORT}:3000"
              environment:
                PORT: 3000
                DATABASE_URL: postgres://test:test@postgres:5432/testdb
                MONGODB_URL: mongodb://root:rootpw@mongo:27017/testdb?authSource=admin
              depends_on:
                - postgres
                - mongo

            postgres:
              image: postgres:16-alpine
              environment:
                POSTGRES_USER: test
                POSTGRES_PASSWORD: test
                POSTGRES_DB: testdb
              healthcheck:
                test: ["CMD-SHELL", "pg_isready -U test"]
                interval: 5s
                retries: 10

            mongo:
              image: mongo:7
              command: ["--auth"]
              environment:
                MONGO_INITDB_ROOT_USERNAME: root
                MONGO_INITDB_ROOT_PASSWORD: rootpw
                MONGO_INITDB_DATABASE: testdb
              healthcheck:
                test: ["CMD", "mongosh", "--username", "root", "--password", "rootpw", "--eval", "db.adminCommand('ping')"]
                interval: 5s
                retries: 10
          YAML

          docker compose -f ci/docker-compose.yml up -d
          sleep 10
        '''
      }
    }

    stage('Smoke Test') {
      steps {
        sh 'curl -sSf http://localhost:$TEST_PORT/books || exit 1'
      }
    }
  }

  post {
    always {
      sh 'docker compose -f ci/docker-compose.yml down -v || true'
    }
  }
}
