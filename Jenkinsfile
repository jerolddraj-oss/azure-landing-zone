pipeline {
    agent {
        label 'Windows-Agent'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(false)
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['APPLY', 'DESTROY'],
            description: 'Terraform action. APPLY creates/updates the landing zone. DESTROY permanently removes managed resources.'
        )
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

        stage('Terraform Format Check') {
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    bat 'terraform fmt -check -recursive || exit /b 0'
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    withCredentials([
                        string(credentialsId: 'azure-client-id', variable: 'ARM_CLIENT_ID'),
                        string(credentialsId: 'azure-client-secret', variable: 'ARM_CLIENT_SECRET'),
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

        stage('Azure Login') {
            steps {
                withCredentials([
                    string(credentialsId: 'azure-client-id', variable: 'ARM_CLIENT_ID'),
                    string(credentialsId: 'azure-client-secret', variable: 'ARM_CLIENT_SECRET'),
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

        stage('Terraform Plan') {
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    withCredentials([
                        string(credentialsId: 'azure-client-id', variable: 'ARM_CLIENT_ID'),
                        string(credentialsId: 'azure-client-secret', variable: 'ARM_CLIENT_SECRET'),
                        string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID'),
                        string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID')
                    ]) {
                        bat '''
                            @echo off
                            set TF_VAR_subscription_id=%ARM_SUBSCRIPTION_ID%
                            if /I "%ACTION%"=="DESTROY" (
                                terraform plan -destroy -input=false -out=tfplan
                            ) else (
                                terraform plan -input=false -out=tfplan
                            )
                        '''
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
                script {
                    def approvalMessage = params.ACTION == 'DESTROY'
                        ? 'DANGER: Review the Terraform DESTROY plan. This will permanently delete resources managed by this configuration. Approve only if you are certain.'
                        : 'Review the Terraform APPLY plan and approve deployment to Azure East US.'

                    timeout(time: 30, unit: 'MINUTES') {
                        input message: approvalMessage,
                              ok: params.ACTION == 'DESTROY' ? 'Approve DESTROY' : 'Approve APPLY'
                    }
                }
            }
        }

        stage('Terraform Apply / Destroy') {
            when {
                allOf {
                    branch 'main'
                    not { changeRequest() }
                }
            }
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    withCredentials([
                        string(credentialsId: 'azure-client-id', variable: 'ARM_CLIENT_ID'),
                        string(credentialsId: 'azure-client-secret', variable: 'ARM_CLIENT_SECRET'),
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
