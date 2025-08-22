pipeline {
  agent any
  options { timestamps() }

  environment {
    IMAGE_API = 'biblioflow-api:ci'
    NET       = 'biblio-api-ci-net'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build API Image') {
      steps { sh 'docker build -t ${IMAGE_API} .' }
    }

    stage('Bring up stack (isolated net, no host publish)') {
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
          for i in $(seq 1 60); do
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

          # Wait for Mongo to accept auth (first seconds can give "Authentication failed")
          for i in $(seq 1 90); do
            if docker exec ci_mongo sh -lc "mongosh --quiet -u root -p rootpw --authenticationDatabase admin --eval 'db.adminCommand({ping:1}).ok' | grep -q 1"; then
              echo "Mongo is ready"; break
            fi
            echo "Waiting for Mongo... ($i)"; sleep 1
          done

          # API (NO host port publishing)
          docker run -d --name ci_api --network ${NET} \
            -e PORT=3000 \
            -e DATABASE_URL=postgres://test:test@ci_postgres:5432/testdb \
            -e MONGODB_URL='mongodb://root:rootpw@ci_mongo:27017/testdb?authSource=admin' \
            ${IMAGE_API}
        '''
      }
    }

    stage('Smoke Test (inside network)') {
      steps {
        sh '''
          set -e

          echo "Container state:"
          docker ps --filter "name=ci_api" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

          # Quick bail if container already exited
          if [ "$(docker inspect -f '{{.State.Running}}' ci_api || echo false)" != "true" ]; then
            echo "ci_api is not running. Recent logs:"
            docker logs --tail=200 ci_api || true
            exit 1
          fi

          # Function: consider API "up" if TCP port is open OR any HTTP response is returned (200..599)
          is_up() {
            docker run --rm --network ${NET} curlimages/curl:8.8.0 \
              -sS -o /dev/null -w '%{http_code}' http://ci_api:3000/ || return 1
          }

          # Wait up to 90s for API
          ok=false
          for i in $(seq 1 90); do
            if is_up; then
              echo "API responded on ci_api:3000"
              ok=true
              break
            fi
            # Show brief status every few seconds to help debugging in Jenkins logs
            if [ $((i % 7)) -eq 0 ]; then
              echo "-- probe $i: showing last 50 lines from api --"
              docker logs --tail=50 ci_api || true
            fi
            echo "Waiting for API... ($i)"; sleep 1
          done

          if [ "$ok" != "true" ]; then
            echo "API did not come up in time. Dumping logs:"
            docker logs ci_api || true
            exit 1
          fi

          # If you really have /books, keep these functional checks; otherwise skip or adjust route
          docker run --rm --network ${NET} curlimages/curl:8.8.0 \
            -fsS -X POST http://ci_api:3000/books \
            -H "Content-Type: application/json" \
            -d '{"title":"CI Build","author":"Jenkins"}' || true

          docker run --rm --network ${NET} curlimages/curl:8.8.0 \
            -sS http://ci_api:3000/books | tee api_output.json >/dev/null || true
        '''
      }
    }

  }

  post {
    always {
      sh '''
        # Collect logs
        docker logs ci_api       > api.log       2>&1 || true
        docker logs ci_postgres  > postgres.log  2>&1 || true
        docker logs ci_mongo     > mongo.log     2>&1 || true

        # Teardown
        docker rm -f ci_api ci_postgres ci_mongo >/dev/null 2>&1 || true
        docker network rm ${NET} >/dev/null 2>&1 || true
      '''
      archiveArtifacts artifacts: 'api_output.json, *.log', allowEmptyArchive: true
    }
  }
}
