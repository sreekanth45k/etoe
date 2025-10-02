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
        string(name: 'SONAR_TOKEN', defaultValue: 'sonar-token-id', description: 'SonarQube/SonarCloud token')
    }

    environment {
        IMAGE_NAME = "sreekanth45k/etoe"
    }

    stages {
        stage("Clone Repository") {
            steps {
                git branch: "${params.BRANCH_NAME}", url: 'https://github.com/sreekanth45k/etoe.git'
            }
        }

        stage("Parallel Checks") {
            parallel {
                stage("Unit Tests") {
                    steps {
                        sh 'mvn test'
                        junit 'target/surefire-reports/*.xml'
                        archiveArtifacts artifacts: 'target/surefire-reports/*.xml', fingerprint: true
                    }
                }

                stage("Checkstyle") {
                    steps {
                        sh 'mvn checkstyle:checkstyle'
                    }
                }

                stage("Dependency Analysis") {
                    steps {
                        sh 'mvn dependency:analyze'
                    }
                }

                stage("Secret Scan") {
                    steps {
                        sh '''
                            gitleaks detect --source . \
                                --report-format sarif \
                                --report-path gitleaks-report.sarif || true
                        '''
                        archiveArtifacts artifacts: 'gitleaks-report.sarif'
                    }
                }

                stage("OWASP Dependency Check") {
                    steps {
                        sh '''
                            mvn org.owasp:dependency-check-maven:check \
                                -Dformat=ALL \
                                -DoutputDirectory=target/dependency-check-report \
                                -DfailBuildOnCVSS=9 || true
                        '''
                        archiveArtifacts artifacts: 'target/dependency-check-report/*'
                    }
                }
            }
        }

        stage("Integration Tests") {
            steps {
                sh 'mvn verify -P integration-tests'
                junit 'target/failsafe-reports/*.xml'
                archiveArtifacts artifacts: 'target/failsafe-reports/*.xml', fingerprint: true
            }
        }

        stage("SonarQube Analysis") {
            environment {
                SONAR_TOKEN = credentials("${params.SONAR_TOKEN}")
            }
            steps {
                sh "mvn sonar:sonar -Dsonar.login=$SONAR_TOKEN"
            }
        }

        stage("Sonar Quality Gate") {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage("Generate SBOM") {
            steps {
                sh 'mvn cyclonedx:makeAggregateBom'
                archiveArtifacts artifacts: 'target/bom.xml'
            }
        }

        stage("Build & Package") {
            steps {
                sh 'mvn clean package'
                archiveArtifacts artifacts: 'target/*.war', fingerprint: true
            }
        }

        stage("Tomcat Deploy") {
            when {
                expression { return params.DEPLOY_TO_TOMCAT }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: "${params.TOMCAT_CREDENTIALS}", usernameVariable: 'TOMCAT_USER', passwordVariable: 'TOMCAT_PASS')]) {
                    sh """
                        mvn tomcat7:deploy \
                            -Dusername=$TOMCAT_USER \
                            -Dpassword=$TOMCAT_PASS
                    """
                }
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
            echo 'Cleaning workspace...'
            cleanWs()
        }
        failure {
            mail to: 'sreekanthaws24@gmail.com',
                 subject: "Build Failed: ${currentBuild.fullDisplayName}",
                 body: "Check console output at ${env.BUILD_URL}"
        }
    }
}
