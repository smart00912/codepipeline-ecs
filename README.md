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
## 3.1、创建 codepipeline 所需 SerivceRole
如果您的 AWS 账户中还没有 CodePipeline 服务角色，请创建一个。借助此服务角色，CodePipeline 可代表您与其他 AWS 服务进行交互，包括 AWS CodeBuild。
```
aws iam create-role --role-name AWSCodePipelineServiceRole --assume-role-policy-document '{"Version":"2012-10-17","Statement":{"Effect":"Allow","Principal":{"Service":"codepipeline.amazonaws.com"},"Action":"sts:AssumeRole"}}'
```
为 codepipeline role 创建 policy，并将 policy 附加到 AWSCodePipelineServiceRole。
```
$ aws iam create-policy --policy-name AWSCodePipelineServiceRolePolicy --policy-document https://raw.githubusercontent.com/wangzan18/codepipeline-ecs/master/awscli/AWSCodePipelineServiceRolePolicy.json
{
    "Policy": {
        "PolicyName": "AWSCodePipelineServiceRolePolicy", 
        "PermissionsBoundaryUsageCount": 0, 
        "CreateDate": "2020-01-30T05:33:22Z", 
        "AttachmentCount": 0, 
        "IsAttachable": true, 
        "PolicyId": "ANPA5NAGHF6NULEJS574V", 
        "DefaultVersionId": "v1", 
        "Path": "/", 
        "Arn": "arn:aws:iam::921283538843:policy/AWSCodePipelineServiceRolePolicy", 
        "UpdateDate": "2020-01-30T05:33:22Z"
    }
}
$ aws iam attach-role-policy --role-name AWSCodePipelineServiceRole --policy-arn arn:aws:iam::921283538843:policy/AWSCodePipelineServiceRolePolicy
```
## 3.2、创建 pipeline
```
$ aws codepipeline create-pipeline --cli-input-json https://raw.githubusercontent.com/wangzan18/codepipeline-ecs/master/awscli/create-pipeline.json --region us-east-1
```






































