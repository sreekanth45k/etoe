pipeline {
    agent any

    tools {
        jdk "java"
        maven "M2_HOME"
    }

    options {
        
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '1'))
    }

    parameters {
        string(name: 'BRANCH_NAME', defaultValue: 'master', description: 'Git branch to build')
        string(name: 'DOCKER_CREDENTIALS', defaultValue: 'dockercredentials', description: 'Credential ID for DockerHub')
    }

    environment {
        IMAGE_NAME = "sreekanth45k/epro"
    }

    stages {
        stage("Clone") {
            steps {
                echo " Cloning branch: ${params.BRANCH_NAME}"
                git branch: "${params.BRANCH_NAME}", url: 'https://github.com/sresrinivas/cicdpipeline.git'
            }
        }
    stage("Linitng and Formatting")
    {
          steps
          {
                sh "mvn checkstyle:checkstyle"
          }
    }
    
    
    stage("Secret Scan") {
    steps {
        echo "Running Gitleaks to scan for secrets"
        sh '''
            gitleaks detect --source . \
                --report-format sarif \
                --report-path gitleaks-report.sarif || true
        '''
    }
}
  
        stage("Dependency Analysis") {
            steps {
                echo " Running Maven dependency analysis"
                sh "mvn dependency:analyze"
            }
        }
        
         stage("OWASP Dependency Check") {
    steps {
        echo " Running Dependency-Check via Maven"
        sh '''
            mvn org.owasp:dependency-check-maven:check \
                -Dformat=ALL \
                -DoutputDirectory=target/dependency-check-report \
                -DfailBuildOnCVSS=9 || true
        '''
    }
         }
   
      stage("compile/build")
      {
            steps
            {
                  sh "mvn compile"
            }
      }

        stage("Unit Tests") {
            steps {
                echo " Running unit tests"
                sh "mvn test"
            }
            
        }
          stage("code coverage report")
          {
                steps
                {
                      sh "mvn jacoco:report"
                }
          }
    }
}

          
