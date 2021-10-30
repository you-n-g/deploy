#!/bin/sh

# Follow the guidance below
# https://medium.com/swlh/how-to-setup-mlflow-on-azure-5ba67c178e7d



export AZURE_STORAGE_ACCESS_KEY="<...>"
export AZURE_STORAGE_CONNECTION_STRING="<...>"

export MLFLOW_TRACKING_USERNAME="<...>"
export MLFLOW_TRACKING_PASSWORD="<...>"

# pip install azure-datalake-store  # this doesn't solve the problem
pip install  install azure-storage-blob  # this solved the problem

mlflow server --backend-store-uri "<backend_uri>" --default-artifact-root wasbs://<container_name>@blob4aue.blob.core.windows.net/<blob_path> --host 0.0.0.0 --port 5000


# 创建相应的AzureBlob container
# 


# 客户端需要设置
# os.environ['AZURE_STORAGE_CONNECTION_STRING'] = <....>
# os.environ['MLFLOW_TRACKING_USERNAME'] = <...>
# os.environ['MLFLOW_TRACKING_PASSWORD'] = <...>
