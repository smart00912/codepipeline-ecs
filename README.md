![Build Status](https://codebuild.us-east-1.amazonaws.com/badges?uuid=eyJlbmNyeXB0ZWREYXRhIjoiRmhJTlZDV0tlUlp0amJDQ0UycUVDT28zYit6MmFtWDl5cHZvU05Vdnl1RXd1OFV6RitNc1FScW1pOXg2R3JmOFFiY2xqMWVUYTFzV3FtQlBOY2FsRU1VPSIsIml2UGFyYW1ldGVyU3BlYyI6ImE0RGsvSzNERVAzVGNGRVIiLCJtYXRlcmlhbFNldFNlcmlhbCI6MX0%3D&branch=master)

# 一、架构图

# 二、创建 ECR 仓库
创建 ECR 镜像仓库，我所有的操作都是在 us-east-1 这个区域，操作的 IAM 用户拥有 root 权限。
```
$ aws ecr create-repository --repository-name nginx-ecs --image-scanning-configuration scanOnPush=true --region us-east-1 
{
    "repository": {
        "repositoryUri": "921283538843.dkr.ecr.us-east-1.amazonaws.com/nginx-ecs", 
        "imageScanningConfiguration": {
            "scanOnPush": true
        }, 
        "registryId": "921283538843", 
        "imageTagMutability": "MUTABLE", 
        "repositoryArn": "arn:aws:ecr:us-east-1:921283538843:repository/nginx-ecs", 
        "repositoryName": "nginx-ecs", 
        "createdAt": 1580358204.0
    }
}
```
# 三、创建 codepipeline
## 3.1、创建所需 Role


创建 codepipeline 服务角色
```

```