pipeline {
    agent {
        label 'Windows-Agent'
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['PLAN', 'APPLY', 'DESTROY'],
            description: 'Terraform operation to execute. APPLY/DESTROY require manual approval.'
        )
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

        stage('Terraform Format Check') {
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    bat 'terraform fmt -check -recursive || exit /b 0'
                }
            }
        }

        stage('Azure Authentication') {
            steps {
                withCredentials([
                    string(credentialsId: 'azure-client-id', variable: 'ARM_CLIENT_ID'),
                    string(credentialsId: 'azure-client-secret', variable: 'ARM_CLIENT_SECRET'),
                    string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID'),
                    string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID')
                ]) {
                    powershell '''
                        $env:ARM_CLIENT_ID = $env:ARM_CLIENT_ID.Trim()
                        $env:ARM_CLIENT_SECRET = $env:ARM_CLIENT_SECRET.Trim()
                        $env:ARM_TENANT_ID = $env:ARM_TENANT_ID.Trim()
                        $env:ARM_SUBSCRIPTION_ID = $env:ARM_SUBSCRIPTION_ID.Trim()

                        az login --service-principal --username $env:ARM_CLIENT_ID --password $env:ARM_CLIENT_SECRET --tenant $env:ARM_TENANT_ID --output none
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        az account set --subscription $env:ARM_SUBSCRIPTION_ID
                        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

                        Write-Host "Azure authentication successful."
                        az account show --query id -o tsv
                    '''
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
                        powershell '''
                            $env:ARM_CLIENT_ID = $env:ARM_CLIENT_ID.Trim()
                            $env:ARM_CLIENT_SECRET = $env:ARM_CLIENT_SECRET.Trim()
                            $env:ARM_TENANT_ID = $env:ARM_TENANT_ID.Trim()
                            $env:ARM_SUBSCRIPTION_ID = $env:ARM_SUBSCRIPTION_ID.Trim()
                            terraform init -upgrade -input=false
                            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                        '''
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
                        string(credentialsId: 'azure-client-id', variable: 'ARM_CLIENT_ID'),
                        string(credentialsId: 'azure-client-secret', variable: 'ARM_CLIENT_SECRET'),
                        string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID'),
                        string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID')
                    ]) {
                        powershell '''
                            $env:ARM_CLIENT_ID = $env:ARM_CLIENT_ID.Trim()
                            $env:ARM_CLIENT_SECRET = $env:ARM_CLIENT_SECRET.Trim()
                            $env:ARM_TENANT_ID = $env:ARM_TENANT_ID.Trim()
                            $env:ARM_SUBSCRIPTION_ID = $env:ARM_SUBSCRIPTION_ID.Trim()
                            $env:TF_VAR_subscription_id = $env:ARM_SUBSCRIPTION_ID

                            if ($env:ACTION -eq 'DESTROY') {
                                terraform plan -destroy -input=false -out=tfplan
                            }
                            else {
                                terraform plan -input=false -out=tfplan
                            }

                            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                        '''
                    }
                }
            }
        }

        stage('Approval') {
            when {
                anyOf {
                    expression { params.ACTION == 'APPLY' }
                    expression { params.ACTION == 'DESTROY' }
                }
            }
            steps {
                script {
                    def message = params.ACTION == 'DESTROY' ?
                        'WARNING: This will DESTROY the Azure East US landing zone. Review the Terraform destroy plan carefully before approval.' :
                        'Review the Terraform plan before deploying the Azure East US landing zone.'

                    timeout(time: 30, unit: 'MINUTES') {
                        input message: message, ok: params.ACTION == 'DESTROY' ? 'Approve DESTROY' : 'Approve APPLY'
                    }
                }
            }
        }

        stage('Terraform Apply / Destroy') {
            when {
                anyOf {
                    expression { params.ACTION == 'APPLY' }
                    expression { params.ACTION == 'DESTROY' }
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
                        powershell '''
                            $env:ARM_CLIENT_ID = $env:ARM_CLIENT_ID.Trim()
                            $env:ARM_CLIENT_SECRET = $env:ARM_CLIENT_SECRET.Trim()
                            $env:ARM_TENANT_ID = $env:ARM_TENANT_ID.Trim()
                            $env:ARM_SUBSCRIPTION_ID = $env:ARM_SUBSCRIPTION_ID.Trim()
                            $env:TF_VAR_subscription_id = $env:ARM_SUBSCRIPTION_ID

                            terraform apply -input=false -auto-approve tfplan
                            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
                        '''
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
