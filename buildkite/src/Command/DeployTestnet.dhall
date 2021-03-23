let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall


let DeploySpec = {
  Type = {
    testnetLabel: Text,
    deployEnvFile : Text,
    workspace: Text,
    artifactPath: Text,
    preDeploy: Text,
    postDeploy: Text,
    testnetDir: Text,
    deps : List Command.TaggedKey.Type,
    varFile: Text,
    deployCondition: Text
  },
  default = {
    testnetLabel = "ci-net",
    deployEnvFile = "DOCKER_DEPLOY_ENV",
    workspace = "\\\${BUILDKITE_BRANCH//[_\\/]/-}",
    artifactPath = "/tmp/artifacts",
    preDeploy = "echo Deploying network...",
    postDeploy = "echo Deployment successfull!",
    testnetDir = "automation/terraform/testnets/ci-net",
    deps = [] : List Command.TaggedKey.Type,
    varFile = "ci-net.tfvars",
    deployCondition = ""
  }
}

in

{ 
  step = \(spec : DeploySpec.Type) ->
    Command.build
      Command.Config::{
        commands = [
          Cmd.run "cd ${spec.testnetDir}",
          Cmd.run "terraform init",
          -- create separate workspace to isolate infrastructure states
          Cmd.run "terraform workspace select ${spec.workspace} || terraform workspace new ${spec.workspace}",
          -- download deployment dependencies and ensure artifact DIR exists
          Cmd.run "mkdir -p ${spec.artifactPath}",
          Cmd.run "artifact-cache-helper.sh ${spec.deployEnvFile}",
          -- launch testnet based on deploy ENV and ensure auto-cleanup on `apply` failures
          Cmd.run "source ${spec.deployEnvFile}",
          -- execute post-deploy operation
          Cmd.run "${spec.preDeploy}",
          Cmd.run (
            "terraform apply -auto-approve -var-file=${spec.varFile}" ++
              " -var coda_image=gcr.io/o1labs-192920/coda-daemon:\\\$CODA_VERSION-\\\$CODA_GIT_HASH" ++
              " -var coda_archive_image=gcr.io/o1labs-192920/coda-archive:\\\$CODA_VERSION-\\\$CODA_GIT_HASH" ++
              " -var artifact_path=${spec.artifactPath} " ++
              " || (terraform destroy -auto-approve && exit 1)"
          ),
          -- upload/cache testnet genesis_ledger
          Cmd.run "artifact-cache-helper.sh ${spec.artifactPath}/genesis_ledger.json --upload",
          -- execute post-deploy operation
          Cmd.run "${spec.postDeploy}"
        ],
        label = "${spec.testnetLabel}",
        key = "deploy-${spec.testnetLabel}",
        target = Size.Large,
        depends_on = spec.deps,
        if = Some "${spec.deployCondition}"
      },
  DeploySpec = DeploySpec
}