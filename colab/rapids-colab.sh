#!/bin/bash

MULT="100"
STABLE=14
NIGHTLIES=15
LOWEST=13

CTK_VERSION=10.1

RAPIDS_VERSION="0.$STABLE"
RAPIDS_RESULT=$STABLE
 
echo "PLEASE READ"
echo "********************************************************************************************************"
echo "Changes:"
echo "1. IMPORTANT CHANGES: RAPIDS on Colab will be pegged to 0.14 Stable until further notice."
echo "2. Default stable version is now 0.$STABLE.  Nightly will redirect to 0.$STABLE."
echo "3. You can now declare your RAPIDSAI version as a CLI option and skip the user prompts (ex: '0.$STABLE' or '0.$NIGHTLIES', between 0.$LOWEST to 0.$STABLE, without the quotes): "
echo '        "!bash rapidsai-csp-utils/colab/rapids-colab.sh <version/label>"'
echo "        Examples: '!bash rapidsai-csp-utils/colab/rapids-colab.sh 0.$STABLE', or '!bash rapidsai-csp-utils/colab/rapids-colab.sh stable', or '!bash rapidsai-csp-utils/colab/rapids-colab.sh s'"
echo "                  '!bash rapidsai-csp-utils/colab/rapids-colab.sh 0.$NIGHTLIES, or '!bash rapidsai-csp-utils/colab/rapids-colab.sh nightly', or '!bash rapidsai-csp-utils/colab/rapids-colab.sh n'"
echo "Enjoy using RAPIDS!  If you have any issues with or suggestions for RAPIDSAI on Colab, please create a bug request on https://github.com/rapidsai/rapidsai-csp-utils/issues/new.  Thanks!"


install_RAPIDS () {
    echo "Checking for GPU type:"
    python rapidsai-csp-utils/colab/env-check.py

    if [ ! -f ac.sh ]; then
        echo "Removing conflicting packages, will replace with RAPIDS compatible versions"
        # remove existing xgboost and dask installs
        pip uninstall -y xgboost dask distributed

        # intall miniconda
        echo "Installing conda"
        wget -qO ac.sh https://repo.anaconda.com/archive/Anaconda3-2020.11-Linux-x86_64.sh
        chmod +x ac.sh
        bash ./ac.sh -b -f -p /root

        #pin python3.6
        echo "python 3.7.*" > /root/conda-meta/pinned
        
        cd /root
        export PYTHONPATH=/root
        source /root/bin/activate root
        
        #Installing another conda package first something first seems to fix https://github.com/rapidsai/rapidsai-csp-utils/issues/4
        conda install --channel defaults conda python=3.7 --yes
        conda update -y -c conda-forge -c defaults --all
        conda install -y --prefix /root -c conda-forge -c defaults openssl six
        
        ln -s /usr/local/lib/python3.6/dist-packages/google \
        /root/lib/python3.7/site-packages/google

        if (( $RAPIDS_RESULT == $NIGHTLIES )) ;then #Newest nightly packages.  UPDATE EACH RELEASE!
        echo "Installing RAPIDS $RAPIDS_VERSION packages from the nightly release channel"
        echo "Please standby, this will take a few minutes..."
        # install RAPIDS packages
            conda install -y --prefix /usr/local \
                    -c rapidsai-nightly/label/xgboost -c rapidsai-nightly -c nvidia -c conda-forge -c defaults \
                    python=3.6 gdal=3.0.4 cudatoolkit=$CTK_VERSION \
                    cudf=$RAPIDS_VERSION cuml cugraph gcsfs pynvml cuspatial xgboost \
                    dask-cudf cusignal  
        elif (( $RAPIDS_RESULT == 13 )) ;then #0.13 uses xgboost 1.0.2, low than that use 1.0.0
            echo "Installing RAPIDS $RAPIDS_VERSION packages from the stable release channel"
            echo "Please standby, this will take a few minutes..."
            # install RAPIDS packages
            conda install -y --prefix /usr/local \
                -c rapidsai -c nvidia -c conda-forge -c defaults \
                python=3.6 cudatoolkit=$CTK_VERSION \
                cudf=$RAPIDS_VERSION cuml cugraph cuspatial gcsfs pynvml xgboost=1.0.2dev.rapidsai$RAPIDS_VERSION \
                dask-cudf cusignal numba=0.48
        else #Stable packages #0.14 uses xgboost 1.11.0
            echo "Installing RAPIDS $RAPIDS_VERSION packages from the stable release channel"
            echo "Please standby, this will take a few minutes..."
            # install RAPIDS packages
            conda env update --prefix /root --file ENV.yml  --prune
            conda config --set pip_interop_enabled True
            jupyter labextension install @jupyter-widgets/jupyterlab-manager --no-build  
            jupyter labextension install bqplot --no-build   
            jupyter lab build
            jupyter labextension install jupyterlab-nvdashboard
            jupyter lab build
            jupyter labextension install dask-labextension
            jupyter serverextension enable dask_labextension
            jupyter lab build
            cd /root/
            git clone -b v0.11.1 https://github.com/NVIDIA/NeMo.git
            cd /root/NeMo
            cp /root/nemo.patch /root/NeMo/
            git apply nemo.patch && \
            bash reinstall.sh
            cd /root
            git clone https://github.com/rapidsai/gQuant.git
            cd /root/gQuant
        fi
    
        echo "Copying shared object files to /usr/lib"
        # copy .so files to /usr/lib, where Colab's Python looks for libs
        cp /root/lib/libcudf.so /usr/lib/libcudf.so
        cp /root/lib/librmm.so /usr/lib/librmm.so
        cp /root/lib/libnccl.so /usr/lib/libnccl.so
        echo "Copying RAPIDS compatible xgboost"	
        cp /root/lib/libxgboost.so /usr/lib/libxgboost.so
    fi

    echo ""
    echo "************************************************"
    echo "Your Google Colab instance has RAPIDS installed!"
    echo "************************************************"
}

rapids_version_check () {
    
  if  [ $RESPONSE == "NIGHTLY" ]|| [ $RESPONSE == "nightly" ]  || [ $RESPONSE == "N" ] || [ $RESPONSE == "n" ] ; then
    #RAPIDS_VERSION="0.$NIGHTLIES"
    #RAPIDS_RESULT=$NIGHTLIES
    #echo "Starting to prep Colab for install RAPIDS Version $RAPIDS_VERSION nightly"
    RAPIDS_VERSION="0.$STABLE"
    RAPIDS_RESULT=$STABLE
    echo "Starting to prep Colab for install RAPIDS Version $RAPIDS_VERSION STABLE.  If you need to run 0.15 or higher, please use https://app.blazingsql.com/"
  elif [ $RESPONSE == "STABLE" ]|| [ $RESPONSE == "stable" ]  || [ $RESPONSE == "S" ] || [ $RESPONSE == "s" ] ; then
    RAPIDS_VERSION="0.$STABLE"
    RAPIDS_RESULT=$STABLE
    echo "Starting to prep Colab for install RAPIDS Version $RAPIDS_VERSION stable"
  else
    RAPIDS_RESULT=$(awk '{print $1*$2}' <<<"${RESPONSE} ${MULT}")
    if (( $RAPIDS_RESULT > $NIGHTLIES )) ; then
      # RAPIDS_VERSION="0.$NIGHTLIES"
      # RAPIDS_RESULT=$NIGHTLIES
      # echo "RAPIDS Version modified to $RAPIDS_VERSION nightly"
      RAPIDS_VERSION="0.$STABLE"
      RAPIDS_RESULT=$STABLE
      echo "Starting to prep Colab for install RAPIDS Version $RAPIDS_VERSION STABLE.  If you need to run 0.15 or higher, please use https://app.blazingsql.com/"

    elif (($RAPIDS_RESULT < $LOWEST)) ; then
      RAPIDS_VERSION="0.$LOWEST"
      RAPIDS_RESULT=$LOWEST
      echo "RAPIDS Version modified to $RAPIDS_VERSION stable"
    #elif (($RAPIDS_RESULT >= $LOWEST)) &&  (( $RAPIDS_RESULT <= $NIGHTLIES )) ; then
    elif (($RAPIDS_RESULT >= $LOWEST)) &&  (( $RAPIDS_RESULT <= $STABLE )) ; then
      RAPIDS_RESULT= $STABLE
      RAPIDS_VERSION="0.$RAPIDS_RESULT"
      
      echo "RAPIDS Version to install is $RAPIDS_VERSION"
    else
      echo "You've entered and incorrect RAPIDS version.  please make the neccessary changes and try again"
    fi
  fi
}

if [ -n "$1" ] ; then
  RESPONSE=$1
  rapids_version_check
  RAPIDS_VERSION="0.$STABLE"
  RAPIDS_RESULT=$STABLE
  install_RAPIDS
else
  echo "As you didn't specify a RAPIDS version, please enter in the box your desired RAPIDS version (ex: '0.$STABLE' or '0.$NIGHTLIES', between 0.$LOWEST to 0.$NIGHTLIES, without the quotes)"
  echo "and hit Enter. If you need stability, use 0.$STABLE. If you want bleeding edge, use our nightly version (0.$NIGHTLIES), but understand that caveats that come with nightly versions."
  read RESPONSE
  rapids_version_check
  install_RAPIDS
fi
