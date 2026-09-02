pipeline {
    agent {
        label 'Windows-Agent'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(false)
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_INPUT         = 'false'
        TF_WORKING_DIR   = 'environments/eastus'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Format') {
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    bat 'terraform fmt -check -recursive'
                }
            }
        }

        stage('Azure Login') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'azure-service-principal',
                        usernameVariable: 'ARM_CLIENT_ID',
                        passwordVariable: 'ARM_CLIENT_SECRET'
                    ),
                    string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID'),
                    string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID')
                ]) {
                    bat '''
                        @echo off
                        az login --service-principal --username "%ARM_CLIENT_ID%" --password "%ARM_CLIENT_SECRET%" --tenant "%ARM_TENANT_ID%"
                        if errorlevel 1 exit /b 1
                        az account set --subscription "%ARM_SUBSCRIPTION_ID%"
                        if errorlevel 1 exit /b 1
                        az account show --query id -o tsv
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'azure-service-principal',
                            usernameVariable: 'ARM_CLIENT_ID',
                            passwordVariable: 'ARM_CLIENT_SECRET'
                        ),
                        string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID'),
                        string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID')
                    ]) {
                        bat 'terraform init -upgrade -input=false'
                    }
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    bat 'terraform validate'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'azure-service-principal',
                            usernameVariable: 'ARM_CLIENT_ID',
                            passwordVariable: 'ARM_CLIENT_SECRET'
                        ),
                        string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID'),
                        string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID')
                    ]) {
                        bat 'set TF_VAR_subscription_id=%ARM_SUBSCRIPTION_ID% && terraform plan -input=false -out=tfplan'
                    }
                }
            }
        }

        stage('Approval') {
            when {
                allOf {
                    branch 'main'
                    not { changeRequest() }
                }
            }
            steps {
                timeout(time: 30, unit: 'MINUTES') {
                    input message: 'Review the Terraform plan and approve deployment to Azure East US.',
                          ok: 'Approve Apply'
                }
            }
        }

        stage('Terraform Apply') {
            when {
                allOf {
                    branch 'main'
                    not { changeRequest() }
                }
            }
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'azure-service-principal',
                            usernameVariable: 'ARM_CLIENT_ID',
                            passwordVariable: 'ARM_CLIENT_SECRET'
                        ),
                        string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID'),
                        string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID')
                    ]) {
                        bat 'set TF_VAR_subscription_id=%ARM_SUBSCRIPTION_ID% && terraform apply -input=false -auto-approve tfplan'
                    }
                }
            }
        }
    }

    post {
        always {
            dir("${env.TF_WORKING_DIR}") {
                bat 'if exist tfplan del /f /q tfplan'
            }
            deleteDir()
        }
    }
}
