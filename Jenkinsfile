pipeline {
  agent any
  options { timestamps() }

  environment {
    IMAGE_API = 'biblioflow-api:ci'
    API_PORT  = '3003'
    NET       = 'biblio-api-ci-net'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build API Image') {
      steps { sh 'docker build -t ${IMAGE_API} .' }
    }

    stage('Bring up stack (no compose)') {
      steps {
        sh '''
          set -e

          # Clean old stuff
          docker rm -f ci_api ci_postgres ci_mongo >/dev/null 2>&1 || true
          docker network rm ${NET} >/dev/null 2>&1 || true
          docker network create ${NET}

          # Postgres
          docker run -d --name ci_postgres --network ${NET} \
            -e POSTGRES_USER=test -e POSTGRES_PASSWORD=test -e POSTGRES_DB=testdb \
            postgres:16-alpine

          # Wait for Postgres
          for i in $(seq 1 30); do
            if docker exec ci_postgres pg_isready -U test -d testdb >/dev/null 2>&1; then
              echo "Postgres is ready"; break
            fi
            echo "Waiting for Postgres... ($i)"; sleep 1
          done

          # Mongo (with auth)
          docker run -d --name ci_mongo --network ${NET} \
            -e MONGO_INITDB_ROOT_USERNAME=root \
            -e MONGO_INITDB_ROOT_PASSWORD=rootpw \
            -e MONGO_INITDB_DATABASE=testdb \
            mongo:7 --auth

          # Wait for Mongo
          for i in $(seq 1 30); do
            if docker exec ci_mongo sh -lc "mongosh --quiet -u root -p rootpw --authenticationDatabase admin --eval 'db.adminCommand({ping:1}).ok' | grep -q 1"; then
              echo "Mongo is ready"; break
            fi
            echo "Waiting for Mongo... ($i)"; sleep 1
          done

          # API
          docker run -d --name ci_api --network ${NET} -p ${API_PORT}:3000 \
            -e PORT=3000 \
            -e DATABASE_URL=postgres://test:test@ci_postgres:5432/testdb \
            -e MONGODB_URL='mongodb://root:rootpw@ci_mongo:27017/testdb?authSource=admin' \
            ${IMAGE_API}
        '''
      }
    }

    stage('Smoke Test') {
      steps {
        sh '''
          # Wait for API port to open on the host mapping
          for i in $(seq 1 30); do
            if curl -sS http://host.docker.internal:${API_PORT}/books >/dev/null 2>&1; then
              echo "API is up"; break
            fi
            echo "Waiting for API... ($i)"; sleep 1
          done

          # Create a book and list
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
        # Collect logs
        docker logs ci_api    > api.log    2>&1 || true
        docker logs ci_postgres > postgres.log 2>&1 || true
        docker logs ci_mongo  > mongo.log  2>&1 || true

        # Teardown
        docker rm -f ci_api ci_postgres ci_mongo >/dev/null 2>&1 || true
        docker network rm ${NET} >/dev/null 2>&1 || true
      '''
      archiveArtifacts artifacts: 'api_output.json, *.log', allowEmptyArchive: true
    }
  }
}
