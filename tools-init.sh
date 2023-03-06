#!/bin/bash

# -----------------------------------------------
cwd=$(pwd)
echo "-------------------------------------------------------------------------"
echo "Preparing your environment ..."

DEPENDENCIES=(golang jq)
# echo "Installing dependencies ${DEPENDENCIES} ..."
for dependency in ${DEPENDENCIES[@]}; do
    if $(! yum list installed $dependency &> /dev/null); then
	    echo "Installing dependency: $dependency"
	    sudo yum install $dependency -y -q -e 0 &> /dev/null
    else
	    echo "Dependency is installed: $dependency"
    fi
done

# Check for AWS Region --------------------------
export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
if [ -z "$AWS_REGION" ]
then
    # metadata might err, this is a safeguard
    echo "Error: AWS region not found, exiting"
    exit 0
else
    echo "Deploying into AWS region: ${AWS_REGION}"
fi

# Export Default Env Variables ------------------
if ! grep -q 'export AWS_REGION' ~/.bash_profile; then
    echo "export AWS_REGION=${AWS_REGION}" >> ~/.bash_profile
fi


aws configure set default.region ${AWS_REGION}
aws configure get default.region

export NVM_VER=$(curl --silent "https://github.com/nvm-sh/nvm/releases/latest" | sed 's#.*tag/\(.*\)\".*#\1#') #v.0.38.0
export SWB_VER=$(curl --silent https://api.github.com/repos/awslabs/service-workbench-on-aws/releases/latest | jq -r .tag_name) #v.5.2.7
export PACKER_VER=1.7.2

# Ensure SWB code exists.  Assume it's the latest version. ------------
SWB_DIR=~/environment/service-workbench-on-aws
if [ -d $SWB_DIR ]; then
    cd $SWB_DIR
    CURRENT_VER=$(git describe --tags --abbrev=0)
    echo "SWB code ${CURRENT_VER} is currently installed"
    if [ ! $CURRENT_VER == $SWB_VER ]; then
	    echo "NOTE: Current latest version is $SWB_VER; `git pull` to update"
    fi
else
    echo "Cloning SWB Repo ${SWB_VER} from GitHub into ~/environment"
    cd ~/environment
    git clone https://github.com/awslabs/service-workbench-on-aws.git &>/dev/null
fi
cd $cwd

echo "Enabling utilities scripts ..."
chmod +x cloud9-resize.sh
chmod +x hosting-account/create-host-account.sh

DISKSIZE=$(df -m . | tail -1 | awk '{print $2}')
if (( DISKSIZE > 40000 )); then
    echo "Installation volume has adequate size: ${DISKSIZE} MB"
else
    echo "Resizing AWS Cloud9 Volume to 50 GB ..."    
    ./cloud9-resize.sh #50GB by default
fi

# NVM & Node Versions ---------------------------
source ~/.nvm/nvm.sh &> /dev/null
if ! nvm --version &> /dev/null; then
    echo "Installing nvm ${NVM_VER} ..."
    rm -rf ~/.nvm
    export NVM_DIR=
    curl --silent -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VER/install.sh" | bash
    source ~/.nvm/nvm.sh &> /dev/null
else
    nvm_ver=$(nvm --version)
    echo "nvm version ${nvm_ver} is installed"
fi

# LTS_VER=$(nvm version-remote --lts)
LTS_VER=v16
nvm use ${LTS_VER} &> /dev/null
if (($? != 0)); then
    echo "Installing node version ${LTS_VER}"
    nvm install --lts &> /dev/null
fi
nvm alias default $LTS_VER &> /dev/null
echo "Using node version:" $(node --version)

# npm packages ----------------------------------
NPM_PACKAGES=(serverless pnpm hygen yarn docusaurus)
NPM_INSTALLED=$(npm ls -g --depth=0)
for package in ${NPM_PACKAGES[@]}; do
    echo $NPM_INSTALLED | grep $package &>/dev/null
    if (($? != 0)); then
	    echo "Installing npm package ${package}"
	    npm install -g $package &> /dev/null
	    if (($? != 0)); then
	        echo "ERROR installing npm package ${package} using Node version ${LTS_VER}; exiting"
	        exit
	    fi
    else
	    echo "npm package is installed: ${package}"
    fi
done

# packer ----------------------------------------
/usr/local/bin/packer --version &> /dev/null
if (($? != 0)); then
    echo "Installing packer ${PACKER_VER} into /usr/local/bin/ ..."
    wget -q "https://releases.hashicorp.com/packer/$PACKER_VER/packer_${PACKER_VER}_linux_amd64.zip" -O packer_${PACKER_VER}_linux_amd64.zip
    unzip "packer_${PACKER_VER}_linux_amd64.zip" >/dev/null 2>&1
    sudo mv packer /usr/local/bin/ >/dev/null 2>&1
    rm -f "packer_${PACKER_VER}_linux_amd64.zip" >/dev/null 2>&1
else
    echo "Packer application is installed"
fi

# finishing up ----------------------------------
echo "Finishing up ..."
if ! grep -q 'alias swb-ami-list' ~/.bashrc; then
    echo -e "alias swb-ami-list='aws ec2 describe-images --owners self --query \"reverse(sort_by(Images[*].{Id:ImageId,Name:Name, Created:CreationDate}, &Created))\" --filters \"Name=name,Values=${STAGE_NAME}*\" --output table'" >> ~/.bashrc
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 
source ~/.bashrc 
echo ""
echo "Your AWS Cloud9 Environment is ready to use. "
echo "-------------------------------------------------------------------------"
