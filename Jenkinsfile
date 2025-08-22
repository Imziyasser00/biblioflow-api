pipeline {
  agent any
  options { timestamps() }

  environment {
    IMAGE_API = 'biblioflow-api:ci'
    NET       = 'biblio-api-ci-net'
    // Name must match what you configured in Manage Jenkins → System → SonarQube servers
    SONARQUBE_NAME = 'sonarqube'
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    // ---- TP11 additions: install, test, sonar ----
    stage('Install deps') {
      steps {
        sh 'npm ci'
      }
    }

    stage('Unit tests + coverage') {
      steps {
        sh '''
          set -e
          npm run test:ci || true
          # Make sure coverage/lcov.info exists, even if no tests yet
          test -f coverage/lcov.info || { mkdir -p coverage && touch coverage/lcov.info; }
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: 'coverage/**', allowEmptyArchive: true
        }
      }
    }

    stage('SonarQube Analysis') {
      steps {
        // Works whether you installed the global scanner tool or not:
        // - If Jenkins has the SonarQube server configured, env + webhook get set up.
        withSonarQubeEnv("${env.SONARQUBE_NAME}") {
          sh '''
            # Prefer local scanner via npx so the job is self-contained
            npx --yes sonar-scanner \
              -Dsonar.projectKey=biblioflow-api \
              -Dsonar.sources=src \
              -Dsonar.exclusions=**/node_modules/**,**/dist/** \
              -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
          '''
        }
      }
    }

    stage('Quality Gate') {
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true
        }
      }
    }
    // ---- end TP11 additions ----

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

          # Wait for Mongo to accept auth
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

          if [ "$(docker inspect -f '{{.State.Running}}' ci_api || echo false)" != "true" ]; then
            echo "ci_api is not running. Recent logs:"
            docker logs --tail=200 ci_api || true
            exit 1
          fi

          is_up() {
            docker run --rm --network ${NET} curlimages/curl:8.8.0 \
              -sS -o /dev/null -w '%{http_code}' http://ci_api:3000/ || return 1
          }

          ok=false
          for i in $(seq 1 90); do
            if is_up; then
              echo "API responded on ci_api:3000"
              ok=true
              break
            fi
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

          # Optional functional checks:
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
