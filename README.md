![Build Status](https://codebuild.us-east-1.amazonaws.com/badges?uuid=eyJlbmNyeXB0ZWREYXRhIjoiRmhJTlZDV0tlUlp0amJDQ0UycUVDT28zYit6MmFtWDl5cHZvU05Vdnl1RXd1OFV6RitNc1FScW1pOXg2R3JmOFFiY2xqMWVUYTFzV3FtQlBOY2FsRU1VPSIsIml2UGFyYW1ldGVyU3BlYyI6ImE0RGsvSzNERVAzVGNGRVIiLCJtYXRlcmlhbFNldFNlcmlhbCI6MX0%3D&branch=master)

# 一、架构图
## 1.1、架构图


## 1.2、一些文件解释

+ buildspec.yaml: 主要是 codebuile 在构建过程中需要的一个文件，用了告知如何构建。
+ appspec.yaml: 是 codedeploy 在部署过程中的修订文件，可以比作为一个环境变量配置文件吧。
+ taskdef.json：是我们的 ECS task 的一个定义文件，有这个文件 codepipeline 才可以在每次构建中根据要求为我们创建 task definition。
+ imageDetail.json：用来输出我们新构建的镜像地址，用于新的部署使用。

## 1.3、流程
1. codebuild 通过文件`buildspec.yaml`进行构建，生成文件`imageDetail.json`；
1. codepipeline 会提取文件`imageDetail.json`中的 imageurl，放入环境变量`IMAGE1_NAME`；
2. codepipeline 把`taskdef.json`中的`<IMAGE1_NAME>`替换为新的 URL，并请求 ECS RegisterTaskDefinition API 进行新的任务定义注册；
3. 注册完成后 API 会返回其任务定义 ARN，codepipeline 并用此 ARN 信息替换`appspec.yaml`中的`<TASK_DEFINITION>`;
4. 而后 CodePipeline 根据`appspec.yaml`的信息，发动 CreateDeployment API 开始透过 CodeDeploy 执行蓝绿布署。


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
# 三、创建 codebuild project
## 3.1、创建 ServiceRole
codebuild 需要获取 s3 等权限。
```
$ aws iam create-role --role-name AWSCodeBuildServiceRole --assume-role-policy-document '{"Version":"2012-10-17","Statement":{"Effect":"Allow","Principal":{"Service":"codebuild.amazonaws.com"},"Action":"sts:AssumeRole"}}'
```
创建 policy。
```
$ aws iam create-policy --policy-name AWSCodeBuildPolicy --policy-document https://raw.githubusercontent.com/wangzan18/codepipeline-ecs/master/awscli/AWSCodeBuildPolicy.json
{
    "Policy": {
        "PolicyName": "AWSCodeBuildPolicy", 
        "PermissionsBoundaryUsageCount": 0, 
        "CreateDate": "2020-01-30T09:34:36Z", 
        "AttachmentCount": 0, 
        "IsAttachable": true, 
        "PolicyId": "ANPA5NAGHF6NYARCBUGDT", 
        "DefaultVersionId": "v1", 
        "Path": "/", 
        "Arn": "arn:aws:iam::921283538843:policy/AWSCodeBuildPolicy", 
        "UpdateDate": "2020-01-30T09:34:36Z"
    }
}
角色附加策略。
$ aws iam attach-role-policy --role-name AWSCodeBuildServiceRole --policy-arn arn:aws:iam::921283538843:policy/AWSCodeBuildPolicy
$ aws iam attach-role-policy --role-name AWSCodeBuildServiceRole --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
```
## 3.2、创建 codebuild project
```
$ wget https://raw.githubusercontent.com/wangzan18/codepipeline-ecs/master/awscli/create-project.json
$ wget aws codebuild create-project --cli-input-json file://create-project.json
```

+ 参考文档：https://docs.aws.amazon.com/zh_cn/codebuild/latest/userguide/create-project.html#create-project-cli
+ buildspec.yaml : https://docs.aws.amazon.com/zh_cn/codebuild/latest/userguide/build-spec-ref.html#build-spec-ref-syntax

# 四、创建 ECS 蓝绿 CodeDeploy
## 4.1、为 CodeDeploy 创建服务角色
```
$ aws iam create-role --role-name AWSCodeDeployServiceRole --assume-role-policy-document '{"Version":"2012-10-17","Statement":{"Effect":"Allow","Principal":{"Service":"codedeploy.amazonaws.com"},"Action":"sts:AssumeRole"}}'
```
附加策略。
```
$ aws iam attach-role-policy --role-name AWSCodeDeployServiceRole --policy-arn arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS
```
## 4.2、创建 ECS 使用的 ALB
使用 create-load-balancer 命令创建 应用程序负载均衡器。指定两个不属于同一可用区的子网以及一个安全组。
```
aws elbv2 create-load-balancer \
     --name nginx-ecs-bluegreen-alb \
     --subnets subnet-694b2b35 subnet-f5761192 \
     --security-groups sg-cdc5cf8f \
     --region us-east-1
```
使用 create-target-group 命令创建目标组。此目标组将流量路由到服务中的原始任务集。
```
aws elbv2 create-target-group \
     --name bluegreentarget1 \
     --protocol HTTP \
     --port 80 \
     --target-type ip \
     --vpc-id vpc-ebff4c91 \
     --region us-east-1
```
```
aws elbv2 create-target-group \
     --name bluegreentarget2 \
     --protocol HTTP \
     --port 80 \
     --target-type ip \
     --vpc-id vpc-ebff4c91 \
     --region us-east-1
```
使用 create-listener 命令创建负载均衡器侦听器，该侦听器带有将请求转发到目标组的默认规则。
```
aws elbv2 create-listener \
     --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:921283538843:loadbalancer/app/nginx-ecs-bluegreen-alb/28cd5055a92630c1 \
     --protocol HTTP \
     --port 80 \
     --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:921283538843:targetgroup/bluegreentarget1/80b89a8c4e5f574d \
     --region us-east-1
```

## 4.3、创建 Amazon ECS 集群
使用 create-cluster 命令创建要使用的名为 nginx-ecs-bluegreen 的集群。
```
aws ecs create-cluster \
     --cluster-name nginx-ecs-bluegreen \
     --region us-east-1
```
为 ECS task 创建执行角色。
```
$ aws iam create-role --role-name AWSECSTaskServiceRole --assume-role-policy-document '{"Version":"2012-10-17","Statement":{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}}'
```
附加策略 AmazonECSTaskExecutionRolePolicy。
```
$ aws iam attach-role-policy --role-name AWSECSTaskServiceRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```
然后，使用您创建的 fargate-task.json 文件注册任务定义。
```
$ wget https://raw.githubusercontent.com/wangzan18/codepipeline-ecs/master/awscli/fargate-task.json
$ aws ecs register-task-definition \
     --cli-input-json file://fargate-task.json \
     --region us-east-1
```
创建 ECS Service。
```
$ wget https://raw.githubusercontent.com/wangzan18/codepipeline-ecs/master/awscli/service-bluegreen.json
$ aws ecs create-service \
     --cli-input-json file://service-bluegreen.json \
     --region us-east-1
```

## 4.4、创建 AWS CodeDeploy 资源
使用 create-application 命令创建 CodeDeploy 应用程序。指定 ECS 计算平台。
```
$ aws deploy create-application \
     --application-name nginx-ecs \
     --compute-platform ECS \
     --region us-east-1
```
使用 create-deployment-group 命令创建 CodeDeploy 部署组。
```
$ wget https://raw.githubusercontent.com/wangzan18/codepipeline-ecs/master/awscli/deployment-group.json
$ aws deploy create-deployment-group \
     --cli-input-json file://deployment-group.json \
     --region us-east-1
```



+ 参考文档：https://docs.aws.amazon.com/zh_cn/AmazonECS/latest/developerguide/create-blue-green.html#create-blue-green-loadbalancer
+ imageDetail.json ：https://docs.aws.amazon.com/zh_cn/codepipeline/latest/userguide/file-reference.html#file-reference-ecs-bluegreen
+ taskdef.json : https://docs.aws.amazon.com/zh_cn/codepipeline/latest/userguide/tutorials-ecs-ecr-codedeploy.html#tutorials-ecs-ecr-codedeploy-taskdefinition


# 四、创建 codepipeline
## 4.1、创建 codepipeline 所需 SerivceRole
如果您的 AWS 账户中还没有 CodePipeline 服务角色，请创建一个。借助此服务角色，CodePipeline 可代表您与其他 AWS 服务进行交互，包括 AWS CodeBuild。
```
$ aws iam create-role --role-name AWSCodePipelineServiceRole --assume-role-policy-document '{"Version":"2012-10-17","Statement":{"Effect":"Allow","Principal":{"Service":"codepipeline.amazonaws.com"},"Action":"sts:AssumeRole"}}'
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
角色附加策略。
$ aws iam attach-role-policy --role-name AWSCodePipelineServiceRole --policy-arn arn:aws:iam::921283538843:policy/AWSCodePipelineServiceRolePolicy
```
## 4.2、创建 pipeline
```
$ wget https://raw.githubusercontent.com/wangzan18/codepipeline-ecs/master/awscli/create-pipeline.json
$ aws codepipeline create-pipeline --cli-input-json file://create-pipeline.json --region us-east-1
```
注意：文档中的 OAuthToken 自己去 github 中去申请。
+ 参考文档：https://docs.aws.amazon.com/zh_cn/codepipeline/latest/userguide/GitHub-create-personal-token-CLI.html
+ https://docs.aws.amazon.com/zh_cn/codepipeline/latest/userguide/pipelines-create.html#pipelines-create-cli

## 4.3、为 pipeline 创建 webhook
```
$ wget https://raw.githubusercontent.com/wangzan18/codepipeline-ecs/master/awscli/my-webhook.json
$ aws codepipeline put-webhook --cli-input-json file://my-webhook.json --region us-east-1
$ aws codepipeline register-webhook-with-third-party --webhook-name nginx-ecs-webhook --region us-east-1
```
相关参数可以根据自己情况填写，参考文档：https://docs.aws.amazon.com/zh_cn/codepipeline/latest/userguide/pipelines-webhooks-create.html。

获得了 webhook 的相关信息之后，我们登陆 github，选择相应的存储库，



































