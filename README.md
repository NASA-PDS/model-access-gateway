# LITELLM docker image opening a free health end-point for healthcheck prupose


## Build the docker image

    
    cd docker
    export GIT_SHA=`git rev-parse HEAD`
    docker build --build-arg IMAGE_TAG=$GIT_SHA -t nasapds/litellm-freehealth:$GIT_SHA .

## Run the docker image locally
It start the LLM and provided heath check free end-point on port 4001

    docker run -p 4001:4001 -p 4000:4000 -it -e LITELLM_MASTER_KEY=my_own_key nasapds/litellm-freehealth:$GIT_SHA


## Deploy the docker image to AWS ECR, manually

Login to AWS.

    aws ecr create-repository --repository-name pds-litellm --tags Key=tenant,Value=en Key=venue,Value=dev Key=component,Value=llm-for-developers Key=managedby,Value={your email} Key=cicd,Value=cli


## Deploy with terraform

In AWS console, create secrets:



Get AWS credentials in your terminal:

    terraform init
    terraform plan
    terraform apply