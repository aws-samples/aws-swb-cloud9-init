#!/bin/bash
set -e

echo "-------------------------------------------------------------------------"
echo "Hosting Account Setup"
echo "-------------------------------------------------------------------------"

# doing this at ~
cwd=$(pwd)

if [ -z "$STAGE_NAME" ]
then
    printf "------ERROR: $STAGE_NAME environment variable has to be set-------------\n"
else
    # This will get the serverless stack variables and 
    # export to CFN_PARAM_* variables
    # a `hosting-account-env-vars` file is created and 
    # then sourced
    echo ">> 1/4 - Copying Loading Env Vars"
    cd ~/environment/service-workbench-on-aws/main/solution/backend
    aws cloudformation describe-stacks --stack-name $(pnpx sls info --verbose --stage $STAGE_NAME | grep 'stack: ' | sed 's/stack\: //g') | jq '.Stacks[].Outputs[] | {ParameterKey: .OutputKey, ParameterValue: .OutputValue} | select(.OutputKey != "ServiceEndpoint")  | flatten | "export CFN_PARAM_\(.[0])=\(.[1])"' | sed "s/\"//g; s/\=/\=\"/g; s/$/\";/" > ~/environment/cloud9/hosting-account-env-vars;
    source ~/environment/cloud9/hosting-account-env-vars
    
    
    echo ">> 2/4 - Preparing CFn Args"
    CFN_FILE_PARAM=~/environment/cloud9/hosting-account-cfn-args-$STAGE_NAME.json
    cp ~/environment/cloud9/example-hosting-account-params.json $CFN_FILE_PARAM
    
    # Namespace
    sed -i "s/CFN_PARAM_StageName/$STAGE_NAME/g" $CFN_FILE_PARAM
    
    # CentralAccountId == Same account for the Quick Start
    SAME_ACCOUNT_ID=$(echo $CFN_PARAM_WorkflowLoopRunnerRoleArn | sed "s/arn:aws:iam:://g; s/:role\/$STAGE_NAME-va-sw-WorkflowLoopRunner//g")
    sed -i "s/CFN_PARAM_CentralAccountId/$SAME_ACCOUNT_ID/g" $CFN_FILE_PARAM
    
    # ApiHandlerRoleArn (using | as separator as Arn contains slash)
    sed -i "s|CFN_PARAM_ApiHandlerRoleArn|$CFN_PARAM_ApiHandlerRoleArn|g" $CFN_FILE_PARAM
    sed -i "s|ApiHandlerRoleArn|ApiHandlerArn|g" $CFN_FILE_PARAM
    
    # WorkflowLoopRunnerRoleArn
    sed -i "s|CFN_PARAM_WorkflowLoopRunnerRoleArn|$CFN_PARAM_WorkflowLoopRunnerRoleArn|g" $CFN_FILE_PARAM
    sed -i "s|WorkflowLoopRunnerRoleArn|WorkflowRoleArn|g" $CFN_FILE_PARAM
    
    
    STACK_NAME=aws-hosting-account-$SAME_ACCOUNT_ID-stack
    echo ">> 3/4 - Creating stack: ${STACK_NAME}"
    STACK_ID=$(aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://~/environment/service-workbench-on-aws/addons/addon-base-raas/packages/base-raas-cfn-templates/src/templates/onboard-account.cfn.yml \
        --parameters file://$CFN_FILE_PARAM \
        --capabilities CAPABILITY_NAMED_IAM | jq '. | flatten | (.[0])' | sed "s/\"//g;")
        
    echo ">> 4/4 - Waiting for creation to complete ${STACK_ID} ..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME    
    # if [[ $? -eq 0 ]]; then
    #     # Wait for create-stack to finish
    #     echo  "Waiting for create-stack command to complete"
    #     CREATE_STACK_STATUS=$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} --query 'Stacks[0].StackStatus' --output text)
    #     while [[ $CREATE_STACK_STATUS == "REVIEW_IN_PROGRESS" ]] || [[ $CREATE_STACK_STATUS == "CREATE_IN_PROGRESS" ]]
    #     do
    #         # Wait 30 seconds and then check stack status again
    #         sleep 30
    #         CREATE_STACK_STATUS=$(aws --region cloudformation describe-stacks --stack-name ${STACK_NAME} --query 'Stacks[0].StackStatus' --output text)
    #     done
    # fi
    
    echo ">> Stack Output:"
    aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs" --output table 
fi

# getting back to the working dir
cd $cwd