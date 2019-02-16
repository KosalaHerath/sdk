#!/bin/bash
# ----------------------------------------------------------------------------------
# Copyright (c) 2019, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
#
# WSO2 Inc. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
# ----------------------------------------------------------------------------------
#
#Generate WSO2 Cellery Installers for macOS.

#Configuration Variables and Parameters

#Argument validation
function printUsage() {
  echo -e "\033[1mUsage:\033[0m"
  echo "$0 [VERSION]"
  echo
  echo -e "\033[1mOptions:\033[0m"
  echo "  -h (--help)"
  echo
  echo -e "\033[1mExample::\033[0m"
  echo "$0 1.0.0"

}

if [ -z "$1" ]; then # --help option need to be validate
    echo "Please enter the version of the cellery distribution."
    printUsage
    exit 1
fi

#Parameters
TARGET_DIRECTORY="target"
CELLERY_VERSION=${1}
INSTALLATION_DIRECTORY="cellery-ubuntu-x64-"${1}
DATE=`date +%Y-%m-%d`
TIME=`date +%H:%M:%S`
LOG_PREFIX="[$DATE $TIME]"
BINARY_SIZE="0 MB"

#Functions
go_to_dir() {
    pushd $1 >/dev/null 2>&1
}

log_info() {
    echo "${LOG_PREFIX}[INFO]" $1
}

log_warn() {
    echo "${LOG_PREFIX}[WARN]" $1
}

log_error() {
    echo "${LOG_PREFIX}[ERROR]" $1
}

deleteInstallationDirectory() {
    log_info "Cleaning $TARGET_DIRECTORY directory."
    rm -rf $TARGET_DIRECTORY

    if [[ $? != 0 ]]; then
        log_error "Failed to clean $TARGET_DIRECTORY directory" $?
        exit 1
    fi
}

createInstallationDirectory() {
    if [ -d ${TARGET_DIRECTORY} ]; then
        deleteInstallationDirectory
    fi
    mkdir $TARGET_DIRECTORY

    if [[ $? != 0 ]]; then
        log_error "Failed to create $TARGET_DIRECTORY directory" $?
        exit 1
    fi
}

# ballerina scripts
getBallerinaHome() {
    if [ -z "${HOME_BALLERINA}" ]; then
        BALLERINA_VERSION=$(ballerina version | awk '{print $2}')
        BALLERINA_DEFAULT_HOME_PREFIX="/Library/Ballerina/"
        HOME_BALLERINA=${BALLERINA_DEFAULT_HOME_PREFIX}/ballerina-${BALLERINA_VERSION}
        if [ ! -d $HOME_BALLERINA ]; then
            log_error "BALLERINA_HOME cannot be found."
            exit 1
        fi
    fi
}

buildBallerinaNatives() {
    go_to_dir ../../components/lang/
    mvn clean install
    popd >/dev/null 2>&1
}

buildCelleryCLI() {
    go_to_dir ../../
    make build-cli

    if [ $? != 0 ]; then
        log_error "Failed to build cellery CLI." $?
        exit 1
    fi
    popd >/dev/null 2>&1
}

getProductSize() {
    CELLERY_SIZE=$(du -s ../../components/build/cellery | awk '{print $1}')
    CELLERY_JAR_SIZE=$(du -s ../../components/lang/target/cellery-*.jar | awk '{print $1}')
    CELLERY_REPO_SIZE=$(du -s ../../components/lang/target/generated-balo/ | awk '{print $1}')

    BINARY_SIZE_KB=$((CELLERY_SIZE + CELLERY_JAR_SIZE + CELLERY_REPO_SIZE))
    BINARY_SIZE_MB=$((BINARY_SIZE_KB/1024))

    BINARY_SIZE=${BINARY_SIZE_MB}
}

copyDarwinDirectory(){
  createInstallationDirectory
  rm -rf ${TARGET_DIRECTORY}/darwin
  cp -r darwin ${TARGET_DIRECTORY}/
  chmod -R 755 ${TARGET_DIRECTORY}/darwin/scripts
  chmod -R 755 ${TARGET_DIRECTORY}/darwin/Resources
  chmod 755 ${TARGET_DIRECTORY}/darwin/Distribution
}

copyBuildDirectory() {
    # sed -i -e 's/__PRODUCT_VERSION__/'${VERSION}'/g' target/darwin/scripts/postinstall
    # sed -i -e 's/__PRODUCT__/'${PRODUCT}'/g' target/darwin/scripts/postinstall
    # sed -i -e 's/__TITLE__/'${TITLE}'/g' target/darwin/scripts/postinstall
    # chmod -R 755 target/darwin/scripts/postinstall

    sed -i -e 's/__CELLERY_VERSION__/'${CELLERY_VERSION}'/g' ${TARGET_DIRECTORY}/darwin/Distribution
    chmod -R 755 ${TARGET_DIRECTORY}/darwin/Distribution

    sed -i -e 's/__CELLERY_VERSION__/'${CELLERY_VERSION}'/g' ${TARGET_DIRECTORY}/darwin/Resources/*.html
    chmod -R 755 target/darwin/Resources/

    rm -rf ${TARGET_DIRECTORY}/darwinpkg
    mkdir -p ${TARGET_DIRECTORY}/darwinpkg

    #Copy cellery product to /Library/Cellery
    mkdir -p ${TARGET_DIRECTORY}/darwinpkg/Library/Cellery
    cp ../../components/build/cellery ${TARGET_DIRECTORY}/darwinpkg/Library/Cellery
    chmod -R 755 ${TARGET_DIRECTORY}/darwinpkg/Library/Cellery

    #Copy ballerina to /Library/Ballerina
    getBallerinaHome
    mkdir -p ${TARGET_DIRECTORY}/darwinpkg/${HOME_BALLERINA}/bre/lib/
    mkdir -p ${TARGET_DIRECTORY}/darwinpkg/${HOME_BALLERINA}/lib/repo
    cp ../../components/lang/target/cellery-*.jar ${TARGET_DIRECTORY}/darwinpkg/${HOME_BALLERINA}/bre/lib/
    cp -R ../../components/lang/target/generated-balo/repo/celleryio ${TARGET_DIRECTORY}/darwinpkg/${HOME_BALLERINA}/lib/repo

    rm -rf ${TARGET_DIRECTORY}/package
    mkdir -p ${TARGET_DIRECTORY}/package
    chmod -R 755 ${TARGET_DIRECTORY}/package

    rm -rf ${TARGET_DIRECTORY}/pkg
    mkdir -p ${TARGET_DIRECTORY}/pkg
    chmod -R 755 ${TARGET_DIRECTORY}/pkg
}

function buildPackage() {
    log_info "Cellery product installer package building started.(1/3)"
    pkgbuild --identifier org.cellery.${CELLERY_VERSION} \
    --version ${CELLERY_VERSION} \
    --scripts ${TARGET_DIRECTORY}/darwin/scripts \
    --root ${TARGET_DIRECTORY}/darwinpkg \
    ${TARGET_DIRECTORY}/package/wso2am.pkg #> /dev/null 2>&1
}

function buildProduct() {
    log_info "Cellery product installer product building started.(2/3)"
    productbuild --distribution ${TARGET_DIRECTORY}/darwin/Distribution \
    --resources ${TARGET_DIRECTORY}/darwin/Resources \
    --package-path ${TARGET_DIRECTORY}/package \
    ${TARGET_DIRECTORY}/pkg/$1 &> ${TARGET_DIRECTORY}/kosala.txt#> /dev/null 2>&1
}

function signProduct() {
    log_info "Cellery product installer signing process started.(3/3)"
    mkdir -p ${TARGET_DIRECTORY}/pkg-signed
    chmod -R 755 ${TARGET_DIRECTORY}/pkg-signed

    productsign --sign "Developer ID Installer: WSO2, Inc. (QH8DVR4443)" \
    ${TARGET_DIRECTORY}/pkg/$1 \
    ${TARGET_DIRECTORY}/pkg-signed/$1

    pkgutil --check-signature ${TARGET_DIRECTORY}/pkg-signed/$1
}

function createInstaller() {
    log_info "Cellery product installer generation process started.(3 Steps)"
    buildPackage
    buildProduct cellery-macos-installer-x64-$CELLERY_VERSION.pkg
    signProduct cellery-macos-installer-x64-$CELLERY_VERSION.pkg
    log_info "Cellery product installer generation process finished."
}

# Main Code ---- Running -------

#Pre-requisites
command -v mvn -v >/dev/null 2>&1 || {
    log_warn "Apache Maven was not found. Please install Maven first."
    exit 1
}
command -v ballerina >/dev/null 2>&1 || {
    log_warn "Ballerina was not found. Please install ballerina first."
    exit 1
}

#Main script
log_info "Installer Generating process started."

buildBallerinaNatives
buildCelleryCLI

getProductSize
copyDarwinDirectory
copyBuildDirectory
createInstaller


echo "Process Finished...!!"
exit 1


# >>>>>>>>>>>>> MY CODE  <<<<<<<<<<<<<<<<<<<

function createUninstaller(){
    cd tmp/
    sed -i .bk "s/__PRODUCT_VERSION__/${VERSION}/g" "./uninstall.sh" && rm *.bk  #for uninstall file
    sed -i .bk "s/__PRODUCT__/${PRODUCT}/g" "./uninstall.sh" && rm *.bk  #for uninstall file
    sed -i .bk "s/__TITLE__/${TITLE}/g" "./uninstall.sh" && rm *.bk  #for uninstall file
    cd ../
    cp tmp/uninstall.sh $PRODUCT-$VERSION/
}




exit 0
