# E2 Lambda

These are the E2 Lambda jobs in support of removing cron, CICD, and cloud management operations

 * [cicd-codebuild-perl-layer-publisher](https://github.com/everything2/everything2/tree/master/lambda/cicd-codebuild-perl-layer-publisher) cicd-codebuild-perl-layer-publisher - Called by the AWS CodeBuild facility to promote a new perl layer into each lambda function and then remove the old layer
 * [cicd-zips-puller](https://github.com/everything2/everything2/tree/master/lambda/cicd-zips-puller) Zips puller asynchronously invoked from the GitHub webook lambda
 * [everything2-zipfile-processor](https://github.com/everything2/everything2/tree/master/lambda/everything2-zipfile-processor) Asynchronous lambda from the zips puller to process the zipfile for the everything2 archive
 * [opsworks-deregistration](https://github.com/everything2/everything2/tree/master/lambda/opsworks-deregistration) Lambda function to handle downscaling events from EC2 autoscaling
 * [opsworks-reaper](https://github.com/everything2/everything2/tree/master/lambda/opsworks-reaper) Periodic execution script to clean up stalled OpsWorks instances
 * [webhooks-receiver](https://github.com/everything2/everything2/tree/master/lambda/webhooks-receiver) API gateway lambda to receive the GitHub webhook
