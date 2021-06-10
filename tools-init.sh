#!/bin/bash
# doing this at ~
cwd=$(pwd)
cd ~/environment
echo "-------------------------------------------------------------------------"
echo "Preparing your environment ..."
export NVM_VER=$(curl --silent "https://github.com/nvm-sh/nvm/releases/latest" | sed 's#.*tag/\(.*\)\".*#\1#') #v.0.38.0
export SWB_VER=$(curl --silent "https://github.com/awslabs/service-workbench-on-aws/releases/latest" | sed 's#.*tag/\(.*\)\".*#\1#') #v.3.1.0
export PACKER_VER=1.7.2
echo "Cloning SWB Repo ..."
# clone the workbench
git clone --depth 1 --branch $SWB_VER https://github.com/awslabs/service-workbench-on-aws.git >/dev/null 2>&1
echo "Installing dependencies ..."
# installing pre-req for serverless
sudo yum install jq -y -q -e 0 >/dev/null 2>&1
# cloud9 utils utils
echo "Cloning SWB Tools ..."
mkdir ~/environment/cloud9-tools >/dev/null 2>&1
cd ~/environment/cloud9-tools
git clone --depth 1 https://github.com/dgomesbr/aws-swb-cloud9-init.git . >/dev/null 2>&1
#disconnect from the actual repo
rm -rf .git
rm -rf .gitignore
rm -rf LICENSE
rm -rf tools-init.sh
echo "Enabling utilities scripts ..."
chmod +x cloud9-resize.sh
chmod +x hosting-account/create-host-account.sh
echo "Resizing AWS Cloud9 Volume ..."
# execute the resize script and bump the disk to 50GB by default
./cloud9-resize.sh
# getting back to the working dir
cd $cwd
echo "Installing nvm ..."
# remove old nvm
rm -rf ~/.nvm
# unset the NVM path
export NVM_DIR=
# install NVM
curl --silent -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VER/install.sh" | bash
source ~/.nvm/nvm.sh 
# use LTS release
nvm install --lts 
nvm alias default stable
# installing libs
echo "Installing framework and libs ..."
npm install -g serverless pnpm hygen yarn docusaurus serverless pnpm hygen >/dev/null 2>&1
# for the packer img builder
echo "Installing packer ..."
wget -q "https://releases.hashicorp.com/packer/$PACKER_VER/packer_${PACKER_VER}_linux_amd64.zip" -O packer_${PACKER_VER}_linux_amd64.zip
unzip "packer_${PACKER_VER}_linux_amd64.zip" >/dev/null 2>&1
sudo mv packer /usr/local/bin/ >/dev/null 2>&1
rm -f "packer_${PACKER_VER}_linux_amd64.zip" >/dev/null 2>&1
echo "Finishing up ..."
# creating an alias for searching the AMIs for a given STAGE_NAME
echo -e "alias swb-ami-list='aws ec2 describe-images --owners self --query \"reverse(sort_by(Images[*].{Id:ImageId,Name:Name, Created:CreationDate}, &Created))\" --filters \"Name=name,Values=${STAGE_NAME}*\" --output table'" >> ~/.bashrc 
# This has to be the last item that goes into bashrc, otherwise NVM 
# will keep forgetting the current version
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 
source ~/.bashrc 
echo ""
echo "Your AWS Cloud9 Environment is ready to use. "
echo "-------------------------------------------------------------------------"