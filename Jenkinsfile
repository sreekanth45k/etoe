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
        stage("Clone") {
            steps {
                echo "Cloning ${params.BRANCH_NAME}"
                git branch: "${params.BRANCH_NAME}", url: 'https://github.com/sreekanth45k/etoe.git'
            }
        }

        stage("Parallel Checks") {
            parallel {

                stage("Unit Tests") {
                    steps {
                        sh 'mvn -B -DskipTests=false test'
                        // debug listing
                        sh 'ls -l target/surefire-reports || true'
                        junit 'target/surefire-reports/*.xml'
                        archiveArtifacts artifacts: 'target/surefire-reports/*.xml', fingerprint: true
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

                stage("Secret Scan (Gitleaks in Docker)") {
                    steps {
                        sh '''
                          docker run --rm -v $PWD:/src zricethezav/gitleaks:latest detect \
                            --source /src \
                            --report-format sarif \
                            --report-path /src/gitleaks-report.sarif || true
                        '''
                        // allowEmptyArchive true so pipeline won't fail if the report is absent
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

        stage("Integration Tests (failsafe)") {
            steps {
                sh 'mvn -B -Pintegration-tests verify || true'
                sh 'ls -l target/failsafe-reports || true'
                junit allowEmptyResults: true, testResults: 'target/failsafe-reports/*.xml'
                archiveArtifacts artifacts: 'target/failsafe-reports/*.xml', allowEmptyArchive: true, fingerprint: true
            }
        }

        stage("SonarQube Analysis") {
            steps {
                // use the SonarQube server configured in Jenkins by name "MySonarQube"
                withCredentials([string(credentialsId: params.SONAR_TOKEN_CRED_ID, variable: 'SONAR_TOKEN')]) {
                    withSonarQubeEnv('MySonarQube') {
                        // This command will submit analysis to SonarQube and return a task id
                        sh "mvn -B sonar:sonar -Dsonar.login=${SONAR_TOKEN} -Dsonar.projectKey=MyEcommerceGroup_MyEcommerceArtifact -Dsonar.projectName=MyEcommerceApp -Dsonar.branch.name=${params.BRANCH_NAME}"
            }
        }

        stage("Wait for SonarQube Quality Gate") {
            steps {
                // This waits for SonarQube to call Jenkins via the webhook and return the quality gate status.
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
