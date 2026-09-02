pipeline {
    agent {
        label 'Windows-Agent'
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['PLAN', 'APPLY', 'DESTROY'],
            description: 'Terraform operation. APPLY/DESTROY require manual approval.'
        )
        string(
            name: 'NAME_PREFIX',
            defaultValue: 'jd-alz',
            description: 'Terraform resource naming prefix.'
        )
        string(
            name: 'TFSTATE_STORAGE_ACCOUNT',
            defaultValue: '',
            description: 'Optional globally unique Azure Storage Account name. Leave blank to derive one from the subscription ID.'
        )
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    environment {
        TF_IN_AUTOMATION   = 'true'
        TF_INPUT           = 'false'
        TF_WORKING_DIR     = 'environments/eastus'
        TF_VAR_name_prefix = "${params.NAME_PREFIX}"
        TF_VAR_location    = 'East US'
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
                    bat 'terraform fmt -check -recursive'
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
                    bat '''
                        @echo off
                        az login --service-principal --username "%ARM_CLIENT_ID%" --password "%ARM_CLIENT_SECRET%" --tenant "%ARM_TENANT_ID%" --output none
                        if errorlevel 1 exit /b 1

                        az account set --subscription "%ARM_SUBSCRIPTION_ID%"
                        if errorlevel 1 exit /b 1

                        echo Azure authentication successful.
                    '''
                }
            }
        }

        stage('Prepare Terraform Backend') {
            steps {
                withCredentials([
                    string(credentialsId: 'azure-client-id', variable: 'ARM_CLIENT_ID'),
                    string(credentialsId: 'azure-client-secret', variable: 'ARM_CLIENT_SECRET'),
                    string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID'),
                    string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID')
                ]) {
                    script {
                        env.TF_SUBSCRIPTION_ID = env.ARM_SUBSCRIPTION_ID

                        def stateAccount = params.TFSTATE_STORAGE_ACCOUNT?.trim()
                        if (!stateAccount) {
                            stateAccount = "jdalztfstate${env.ARM_SUBSCRIPTION_ID.substring(0, 8).toLowerCase()}"
                        }

                        env.TFSTATE_RESOURCE_GROUP = 'jd-alz-tfstate-rg'
                        env.TFSTATE_STORAGE_ACCOUNT = stateAccount
                        env.TFSTATE_CONTAINER = 'tfstate'
                        env.TFSTATE_KEY = "${params.NAME_PREFIX}-eastus.tfstate"

                        bat '''
                            @echo off
                            az group create --name "%TFSTATE_RESOURCE_GROUP%" --location "East US" --output none
                            if errorlevel 1 exit /b 1

                            az storage account show --resource-group "%TFSTATE_RESOURCE_GROUP%" --name "%TFSTATE_STORAGE_ACCOUNT%" --output none >nul 2>&1
                            if errorlevel 1 (
                                echo Terraform state storage account not found. Creating it...
                                az storage account create --resource-group "%TFSTATE_RESOURCE_GROUP%" --name "%TFSTATE_STORAGE_ACCOUNT%" --location "East US" --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 --allow-blob-public-access false --output none
                                if errorlevel 1 exit /b 1
                            )

                            echo Waiting for Terraform state storage account to become available...
                            set "STORAGE_READY="
                            for /L %%N in (1,1,12) do (
                                az storage account show --resource-group "%TFSTATE_RESOURCE_GROUP%" --name "%TFSTATE_STORAGE_ACCOUNT%" --output none >nul 2>&1
                                if not errorlevel 1 (
                                    set "STORAGE_READY=1"
                                    goto :storage_ready
                                )
                                echo Storage account not ready yet. Attempt %%N of 12...
                                timeout /t 5 /nobreak >nul
                            )

                            :storage_ready
                            if not defined STORAGE_READY (
                                echo ERROR: Terraform state storage account was not available after waiting.
                                exit /b 1
                            )

                            set "STATE_ACCESS_KEY="
                            for /f "delims=" %%K in ('az storage account keys list --resource-group "%TFSTATE_RESOURCE_GROUP%" --account-name "%TFSTATE_STORAGE_ACCOUNT%" --query "[0].value" --output tsv') do set "STATE_ACCESS_KEY=%%K"
                            if not defined STATE_ACCESS_KEY exit /b 1

                            az storage container create --account-name "%TFSTATE_STORAGE_ACCOUNT%" --name "%TFSTATE_CONTAINER%" --account-key "%STATE_ACCESS_KEY%" --output none
                            if errorlevel 1 exit /b 1
                        '''

                        def stateKey = bat(
                            returnStdout: true,
                            script: '@az storage account keys list --resource-group "%TFSTATE_RESOURCE_GROUP%" --account-name "%TFSTATE_STORAGE_ACCOUNT%" --query "[0].value" --output tsv'
                        ).trim()
                        if (!stateKey) {
                            error('Unable to retrieve the Terraform state storage account key.')
                        }
                        env.ARM_ACCESS_KEY = stateKey
                    }
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    withEnv(["ARM_ACCESS_KEY=${env.ARM_ACCESS_KEY}"]) {
                        bat '''
                            @echo off
                            terraform init -reconfigure -input=false ^
                              -backend-config="storage_account_name=%TFSTATE_STORAGE_ACCOUNT%" ^
                              -backend-config="container_name=%TFSTATE_CONTAINER%" ^
                              -backend-config="key=%TFSTATE_KEY%"
                            if errorlevel 1 exit /b 1
                        '''
                    }
                }
            }
        }

        stage('Adopt Existing Azure Resources') {
            steps {
                dir("${env.TF_WORKING_DIR}") {
                    withCredentials([
                        string(credentialsId: 'azure-client-id', variable: 'ARM_CLIENT_ID'),
                        string(credentialsId: 'azure-client-secret', variable: 'ARM_CLIENT_SECRET'),
                        string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID'),
                        string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID')
                    ]) {
                        withEnv(["ARM_ACCESS_KEY=${env.ARM_ACCESS_KEY}", "TF_VAR_subscription_id=${env.TF_SUBSCRIPTION_ID}", "TF_VAR_name_prefix=${params.NAME_PREFIX}", "TF_VAR_location=East US"]) {
                            powershell '.\\..\\..\\scripts\\adopt-existing.ps1'
                        }
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
                        withEnv(["ARM_ACCESS_KEY=${env.ARM_ACCESS_KEY}", "TF_VAR_subscription_id=${env.TF_SUBSCRIPTION_ID}", "TF_VAR_name_prefix=${params.NAME_PREFIX}", "TF_VAR_location=East US"]) {
                            bat '''
                                @echo off
                                if /I "%ACTION%"=="DESTROY" (
                                    terraform plan -destroy -input=false -out=tfplan
                                ) else (
                                    terraform plan -input=false -out=tfplan
                                )
                                if errorlevel 1 exit /b 1
                            '''
                        }
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
                        'WARNING: This will DESTROY the Azure East US landing zone. Review the destroy plan carefully.' :
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
                        withEnv(["ARM_ACCESS_KEY=${env.ARM_ACCESS_KEY}", "TF_VAR_subscription_id=${env.TF_SUBSCRIPTION_ID}", "TF_VAR_name_prefix=${params.NAME_PREFIX}", "TF_VAR_location=East US"]) {
                            bat '''
                                @echo off
                                terraform apply -input=false -auto-approve tfplan
                                if errorlevel 1 exit /b 1
                            '''
                        }
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
