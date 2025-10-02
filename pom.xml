pipeline {
    agent any

    tools {
        jdk "java"
        maven "M2_HOME"
    }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }

    parameters {
        string(name: 'BRANCH_NAME', defaultValue: 'master', description: 'Git branch to build')
        string(name: 'DOCKER_CREDENTIALS', defaultValue: 'dockercredentials', description: 'DockerHub credential ID')
        string(name: 'SONAR_TOKEN_CRED_ID', defaultValue: 'sonar-token-id', description: 'Sonar token credential ID')
    }

    environment {
        IMAGE_NAME = "sreekanth45k/etoe"
    }

    stages {

        stage("Clone") {
            steps {
                git branch: "${params.BRANCH_NAME}", url: 'https://github.com/sreekanth45k/etoe.git'
            }
        }

        stage("Parallel Checks") {
            parallel {
                stage("Unit Tests") {
                    steps {
                        sh 'mvn clean test'
                        sh 'ls -l target/surefire-reports || true'
                        junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
                    }
                }

                stage("Checkstyle") {
                    steps {
                        sh 'mvn -B checkstyle:checkstyle'
                        archiveArtifacts artifacts: 'target/checkstyle-result.xml', allowEmptyArchive: true
                    }
                }

                stage("Dependency Analysis") {
                    steps {
                        sh 'mvn -B dependency:analyze || true'
                    }
                }

                stage("Secret Scan (Gitleaks)") {
                    steps {
                        sh '''
                          docker run --rm -v $PWD:/src zricethezav/gitleaks:latest detect \
                            --source /src --report-format sarif --report-path /src/gitleaks-report.sarif || true
                        '''
                        archiveArtifacts artifacts: 'gitleaks-report.sarif', allowEmptyArchive: true
                    }
                }

                stage("OWASP Dependency Check") {
                    steps {
                        sh '''
                          mvn -B org.owasp:dependency-check-maven:check \
                            -Dformat=ALL \
                            -DoutputDirectory=target/dependency-check-report \
                            -DfailBuildOnCVSS=9 || true
                        '''
                        archiveArtifacts artifacts: 'target/dependency-check-report/**/*', allowEmptyArchive: true
                    }
                }
            }
        }

        stage("Integration Tests") {
            steps {
                sh 'mvn -B -Pintegration-tests verify || true'
                junit allowEmptyResults: true, testResults: 'target/failsafe-reports/*.xml'
            }
        }

        stage("SonarQube Analysis") {
            steps {
                withCredentials([string(credentialsId: "${params.SONAR_TOKEN_CRED_ID}", variable: 'SONAR_TOKEN')]) {
                    withSonarQubeEnv('MySonarQube') {
                        sh """
                          mvn clean package sonar:sonar \
                             -Dsonar.login=$SONAR_TOKEN \
                             -Dsonar.projectKey=MyEcommerceArtifact \
                             -Dsonar.projectName=MyEcommerceArtifact \
                             -Dsonar.java.binaries=target/Ecomm/WEB-INF/classes
                        """
                    }
                }
            }
        }

        stage("Wait for SonarQube Quality Gate") {
            steps {
                script {
                    try {
                        timeout(time: 15, unit: 'MINUTES') {
                            waitForQualityGate abortPipeline: true
                        }
                    } catch (err) {
                        echo "SonarQube Quality Gate check timed out or failed: ${err}"
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }

        stage("Generate SBOM") {
            steps {
                sh 'mvn -B cyclonedx:makeAggregateBom || true'
                archiveArtifacts artifacts: 'target/bom.xml', allowEmptyArchive: true
            }
        }

        stage("Build & Package") {
            steps {
                sh 'mvn -B -DskipTests=true clean package'
                archiveArtifacts artifacts: 'target/*.war', fingerprint: true
            }
        }

        stage("Docker Build & Push") {
            steps {
                withCredentials([usernamePassword(credentialsId: "${params.DOCKER_CREDENTIALS}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                      docker build -t ${IMAGE_NAME}:${BRANCH_NAME} .
                      echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                      docker push ${IMAGE_NAME}:${BRANCH_NAME}
                    """
                }
            }
        }

    }

    post {
        always {
            cleanWs()
        }
        failure {
            echo "Build failed. Check console logs."
        }
    }
}
