#!/bin/sh

# Follow the guidance below
# https://medium.com/swlh/how-to-setup-mlflow-on-azure-5ba67c178e7d



export AZURE_STORAGE_ACCESS_KEY="<...>"
export AZURE_STORAGE_CONNECTION_STRING="<...>"

export MLFLOW_TRACKING_USERNAME="<...>"
export MLFLOW_TRACKING_PASSWORD="<...>"

# pip install azure-datalake-store  # this doesn't solve the problem
pip install  install azure-storage-blob  # this solved the problem

GUNICORN_CMD_ARGS="--timeout 120" mlflow server --backend-store-uri "<backend_uri>" --default-artifact-root wasbs://<container_name>@blob4aue.blob.core.windows.net/<blob_path> --host 0.0.0.0 --port 5000
# - "<backend_uri>" 是本地的 mlflow 的地址

# sftp 的逻辑也类似: https://www.mlflow.org/docs/latest/tracking.html#sftp-server
# pip install pysftp   # 客户端和服务端都要安装
# GUNICORN_CMD_ARGS="--timeout 120" mlflow server --backend-store-uri /home/xiaoyang/service/mlflow_tracking/mlruns --default-artifact-root  sftp://xiaoyang@10.190.175.90//home/xiaoyang/service/mlflow_tracking/mlruns/ --host 0.0.0.0 --port 5005


# 创建相应的AzureBlob container
# 


# 客户端需要设置
# os.environ['AZURE_STORAGE_CONNECTION_STRING'] = <....>
# os.environ['MLFLOW_TRACKING_USERNAME'] = <...>
# os.environ['MLFLOW_TRACKING_PASSWORD'] = <...>

# 客户端在和 server 沟通后应该自己知道 应该连什么 artifact
# 它需要能解决两层认证：
# 1) tracking server 的认证，由 `MLFLOW_TRACKING_*` 环境变量解决h
# 对应的server需要自己实现http认证(mlflow不提供), 比如nginx 就是用这个配置
# server {
#     listen 10099 default_server;
#     listen [::]:10099 default_server;
#     server_name _;
# 
#     auth_basic "Private Property";
#     auth_basic_user_file /etc/nginx/.htpasswd;
#     expires -1;
#     location / {
#         proxy_pass http://127.0.0.1:10098/;
#         expires -1;
#     }
# }
# 2) artifact的认证
# 
