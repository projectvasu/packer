pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Packer Init') {
            steps {
                dir('base') {
                    sh 'packer init .'
                }
            }
        }

        stage('Packer Validate') {
            steps {
                dir('base') {
                    sh 'packer validate .'
                }
            }
        }

        stage('Build AMI') {
            steps {
                dir('base') {
                    sh 'packer build -color=false base-ami.pkr.hcl'
                }
            }
        }
    }

    post {
        success { echo 'AMI built. Check EC2 → Images → AMIs.' }
        failure { echo 'Build failed. Check the console output above.' }
    }
}
