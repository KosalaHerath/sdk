#!/bin/bash
PATH=/usr/local/bin:/usr/local/sbin:~/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/wum/bin/
# ----------------------------------------------------------------------------------
# Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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
#Generate WSO2 Product Installers for macOS.

#Configuration Variables and Parameters

function printUsage() {
    echo "Usage:"
    echo "$0 [options]"
    echo "options:"
    echo "    -v (--version)"
    echo "        version of the product distribution. ex : 2.5.0"
    echo "    -p (--path)"
    echo "        path of the working directory. ex : ./ "
    echo "    -n (--name)"
    echo "        name of the product distribution. ex : ws02am"
    echo "    -j (--jdk)"
    echo "        name of jdk directory. ex : jdk1.8.0_192"
    echo "    -l (--longName)"
    echo "        name of product which shown in UI. ex : API Manager"
}

BUILD_ALL_DISTRIBUTIONS=false
POSITIONAL=()
while [[ $# -gt 0 ]]; do
	key="$1"
	case ${key} in
	    -v|--version)
	    VERSION="$2"
	    shift # past argument
	    shift # past value
	    ;;
	    -p|--path)
	    WORKING_DIR="$2"
	    shift # past argument
	    shift # past value
	    ;;
	    -n|--name)
	    PRODUCT="$2"
	    shift # past argument
	    shift # past value
	    ;;
	    -j|--jdk)
	    JDK="$2"
	    shift # past argument
	    shift # past value
	    ;;     
        -l|--longName)
        LONG_NAME="$2"
        shift # past argument
        shift # past value
        ;;
	    *)    # unknown option
	    POSITIONAL+=("$1") # save it in an array for later
	    shift # past argument
	    ;;
	esac
done

if [ -z "$VERSION" ]; then
    echo "Please enter the version of the product pack"
    printUsage
    exit 1
fi

if [ -z "$WORKING_DIR" ]; then
    echo "Please enter the path of the working directory"
    printUsage
    exit 1
fi

if [ -z "$PRODUCT" ]; then
    echo "Please enter the name of the product."
    printUsage
    exit 1
fi

if [ -z "$JDK" ]; then
    echo "Please enter the name of the jdk directory."
    printUsage
    exit 1
fi

if [ -z "$LONG_NAME" ]; then
    echo "Please enter the long name of the product packs"
    printUsage
    exit 1
fi

PRODUCT_DISTRIBUTION_LOCATION=${WORKING_DIR}
PRODUCT_DIRECTORY=${PRODUCT}-${VERSION}

#Functions
function deleteTargetDirectory() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Deleting target directory"
    rm -rf target
}

function extractPack() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Extracting the PRODUCT distribution, " $1
    rm -rf target/original
    mkdir -p target/original
    unzip $1 -d target/original > /dev/null 2>&1
    mv target/original/__MACOSX/$2 target/original/${PRODUCT_DIRECTORY}
    rm -rf target/original/__MACOSX
}

function createPackInstallationDirectory() {
    rm -rf target/darwin
    cp -r darwin target/darwin

    sed -i -e 's/__PRODUCT_VERSION__/'${VERSION}'/g' target/darwin/scripts/postinstall
    sed -i -e 's/__PRODUCT__/'${PRODUCT}'/g' target/darwin/scripts/postinstall
    sed -i -e 's/__TITLE__/'${TITLE}'/g' target/darwin/scripts/postinstall
    chmod -R 755 target/darwin/scripts/postinstall

    sed -i -e 's/__PRODUCT_VERSION__/'${VERSION}'/g' target/darwin/Distribution
    sed -i -e 's/__PRODUCT__/'${PRODUCT}'/g' target/darwin/Distribution
    sed -i -e 's/__TITLE__/'${TITLE}'/g' target/darwin/Distribution
    sed -i -e "s/__LONG_NAME__/$LONG_NAME/g" target/darwin/Distribution
    chmod -R 755 target/darwin/Distribution

    sed -i -e 's/__PRODUCT_VERSION__/'${VERSION}'/g' target/darwin/Resources/*.html 
    chmod -R 755 target/darwin/Resources/

    rm -rf target/darwinpkg
    mkdir -p target/darwinpkg
    chmod -R 755 target/darwinpkg

    mkdir -p target/darwinpkg/Library/WSO2/$TITLE/$VERSION
    mv target/original/${PRODUCT_DIRECTORY}/* target/darwinpkg/Library/WSO2/$TITLE/$VERSION
    chmod -R 755 target/darwinpkg/Library/WSO2/$TITLE/$VERSION

    rm -rf target/package
    mkdir -p target/package
    chmod -R 755 target/package

    mkdir -p target/pkg
    chmod -R 755 target/pkg
}

function buildPackage() {
    pkgbuild --identifier org.${PRODUCT}.${VERSION} \
    --version ${VERSION} \
    --scripts target/darwin/scripts \
    --root target/darwinpkg \
    target/package/$PRODUCT.pkg > /dev/null 2>&1
}

function buildProduct() {
    productbuild --distribution target/darwin/Distribution \
    --resources target/darwin/Resources \
    --package-path target/package \
    target/pkg/$1 > /dev/null 2>&1
}

function signProduct() {
    mkdir -p target/pkg-signed
    chmod -R 755 target/pkg-signed

    productsign --sign "Developer ID Installer: WSO2, Inc. (QH8DVR4443)" \
    target/pkg/$1 \
    target/pkg-signed/$1

    pkgutil --check-signature target/pkg-signed/$1
}

function createInstaller() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Creating Product platform installer"
    extractPack "$PRODUCT_DISTRIBUTION_LOCATION/$PRODUCT-$VERSION.zip" ${PRODUCT_DIRECTORY}
    createPackInstallationDirectory
    buildPackage
    buildProduct $PRODUCT-macos-installer-x64-$VERSION.pkg
    signProduct $PRODUCT-macos-installer-x64-$VERSION.pkg
}

function createUninstaller(){
    cd tmp/
    sed -i .bk "s/__PRODUCT_VERSION__/${VERSION}/g" "./uninstall.sh" && rm *.bk  #for uninstall file
    sed -i .bk "s/__PRODUCT__/${PRODUCT}/g" "./uninstall.sh" && rm *.bk  #for uninstall file
    sed -i .bk "s/__TITLE__/${TITLE}/g" "./uninstall.sh" && rm *.bk  #for uninstall file
    cd ../
    cp tmp/uninstall.sh $PRODUCT-$VERSION/
}

#Main script
cd $WORKING_DIR

if [ ! -f products/${PRODUCT}-${VERSION}.zip ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')]: [ERROR] Product pack not found...!"
    exit 1
fi
if [ ! -d ${JDK} ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')]: [ERROR] JDK directory not found...!"
    exit 1
fi
if [ ! -d launcher_files ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')]: [ERROR] Launcher files directory not found...!"
    exit 1
fi

cp products/$PRODUCT-$VERSION.zip ./$PRODUCT-$VERSION.zip
echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Unzipping product-pack to working directory..."
unzip -q $PRODUCT-$VERSION.zip
echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Unzipping process finished."
rm -rf __MACOSX
mkdir $PRODUCT-$VERSION/jdk
cp -r $JDK $PRODUCT-$VERSION/jdk

#pre-process launcher files 
[ -e tmp ] && rm -rf tmp
mkdir tmp
cp launcher_files/* tmp/
cd tmp
sed -i .bk "s/__JDK_NAME__/${JDK}/g" ./*.sh && rm *.bk
chmod a+rwx ./*.sh 
cd ../

case "$PRODUCT" in 
    wso2am) echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Product API Manager is selected. Process started..."
            TITLE="APIManager"
            cp wum_inplace/update_darwin $PRODUCT-$VERSION/bin
            cp tmp/launcher_wso2server.sh $PRODUCT-$VERSION/bin
            createUninstaller
            echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping product-pack to target directory..."
            [ -f wso2am/$PRODUCT-$VERSION.zip  ] && rm  wso2am/$PRODUCT-$VERSION.zip
			zip -q -r wso2am/$PRODUCT-$VERSION.zip $PRODUCT-$VERSION
			echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping process finished."
			PRODUCT_DISTRIBUTION_LOCATION=$(pwd)/wso2am
            ;;
    wso2am-analytics) echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Product API Manager Analytics is selected. Process started..."
            TITLE="APIManagerAnalytics"
            cp wum_inplace/update_darwin $PRODUCT-$VERSION/bin
            cp tmp/launcher_dashboard.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_worker.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_editor.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_manager.sh $PRODUCT-$VERSION/bin
            createUninstaller
            echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping product-pack to target directory..."
            [ -f wso2am-analytics/$PRODUCT-$VERSION.zip  ] && rm  wso2am-analytics/$PRODUCT-$VERSION.zip
            zip -q -r wso2am-analytics/$PRODUCT-$VERSION.zip $PRODUCT-$VERSION
            echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping process finished."
            PRODUCT_DISTRIBUTION_LOCATION=$(pwd)/wso2am-analytics
            ;;
    wso2is) echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Product Identity Server is selected. Process started..."
            TITLE="IdentityServer"
            cp wum_inplace/update_darwin $PRODUCT-$VERSION/bin
            cp tmp/launcher_wso2server.sh $PRODUCT-$VERSION/bin
            createUninstaller
            echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping product-pack to target directory..."
            [ -f wso2is/$PRODUCT-$VERSION.zip  ] && rm  wso2is/$PRODUCT-$VERSION.zip
			zip -q -r wso2is/$PRODUCT-$VERSION.zip $PRODUCT-$VERSION
			echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping process finished."
			PRODUCT_DISTRIBUTION_LOCATION=$(pwd)/wso2is
            ;;
    wso2is-analytics) echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Product Identity Server Analytics is selected. Process started..."
            TITLE="IdentityServerAnalytics"
            cp wum_inplace/update_darwin $PRODUCT-$VERSION/bin
            cp tmp/launcher_dashboard.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_worker.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_editor.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_manager.sh $PRODUCT-$VERSION/bin
            createUninstaller
            echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping product-pack to target directory..."
            [ -f wso2is-analytics/$PRODUCT-$VERSION.zip  ] && rm  wso2is-analytics/$PRODUCT-$VERSION.zip
            zip -q -r wso2is-analytics/$PRODUCT-$VERSION.zip $PRODUCT-$VERSION
            echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping process finished."
            PRODUCT_DISTRIBUTION_LOCATION=$(pwd)/wso2is-analytics
            ;;
    wso2is-km) echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Product Identity Server as Key Manager is selected. Process started..."
            TITLE="IdentityServerKM"
            cp wum_inplace/update_darwin $PRODUCT-$VERSION/bin
            cp tmp/launcher_wso2server.sh $PRODUCT-$VERSION/bin
            createUninstaller
            echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping product-pack to target directory..."
            [ -f wso2is-km/$PRODUCT-$VERSION.zip  ] && rm  wso2is-km/$PRODUCT-$VERSION.zip
            zip -q -r wso2is-km/$PRODUCT-$VERSION.zip $PRODUCT-$VERSION
            echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping process finished."
            PRODUCT_DISTRIBUTION_LOCATION=$(pwd)/wso2is-km
            ;;
    wso2ei) echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Product Enterprise Integrator is selected. Process started..."
            TITLE="EnterpriseIntegrator"
            cp wum_inplace/update_darwin $PRODUCT-$VERSION/bin
            cp tmp/launcher_analytics-dashboard.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_analytics-worker.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_broker.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_business-process.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_integrator.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_micro-integrator.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_msf4j.sh $PRODUCT-$VERSION/bin
            createUninstaller
            echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping product-pack to target directory..."
            [ -f wso2ei/$PRODUCT-$VERSION.zip  ] && rm  wso2ei/$PRODUCT-$VERSION.zip
			zip -q -r wso2ei/$PRODUCT-$VERSION.zip $PRODUCT-$VERSION
			echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping process finished."
			PRODUCT_DISTRIBUTION_LOCATION=$(pwd)/wso2ei
            ;;
    wso2sp) echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Product Stream Processor is selected. Process started..."  
            TITLE="StreamProcessor"   
            cp wum_inplace/update_darwin $PRODUCT-$VERSION/bin 
            cp tmp/launcher_editor.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_dashboard.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_worker.sh $PRODUCT-$VERSION/bin
            cp tmp/launcher_manager.sh $PRODUCT-$VERSION/bin
            createUninstaller
            echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping product-pack to target directory..."
            [ -f wso2sp/$PRODUCT-$VERSION.zip  ] && rm  wso2sp/$PRODUCT-$VERSION.zip
			zip -q -r wso2sp/$PRODUCT-$VERSION.zip $PRODUCT-$VERSION
			echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Zipping process finished."
			PRODUCT_DISTRIBUTION_LOCATION=$(pwd)/wso2sp
            ;;
esac

rm -rf $PRODUCT-$VERSION
rm $PRODUCT-$VERSION.zip
rm -rf tmp

echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Product preparation finished."
echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Installer Generating process started."

cd $PRODUCT_DISTRIBUTION_LOCATION

echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Build started..."
deleteTargetDirectory
createInstaller
echo "[$(date +'%Y-%m-%d %H:%M:%S')]: Build completed."

[ -f $PRODUCT-$VERSION.zip  ] && rm  $PRODUCT-$VERSION.zip
exit 0 
