let B = ../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

let Prelude = ../External/Prelude.dhall

let Optional/toList = Prelude.Optional.toList

let Optional/map = Prelude.Optional.map

let List/map = Prelude.List.map

let Package = ../Constants/DebianPackage.dhall

let Network = ../Constants/Network.dhall

let PipelineMode = ../Pipeline/Mode.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let DebianChannel = ../Constants/DebianChannel.dhall

let Profiles = ../Constants/Profiles.dhall

let Artifact = ../Constants/Artifacts.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let Toolchain = ../Constants/Toolchain.dhall

let Command = ./Base.dhall

let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let PromoteDebianSpec =
      { Type =
          { deps : List Command.TaggedKey.Type
          , package : Package.Type
          , version : Text
          , new_version : Text
          , architecture : Text
          , network : Network.Type
          , codename : DebianVersions.DebVersion
          , from_channel : DebianChannel.Type
          , to_channel : DebianChannel.Type
          , profile : Profiles.Type
          , remove_profile_from_name : Bool
          , step_key : Text
          , if : Optional B/If
          }
      , default =
          { deps = [] : List Command.TaggedKey.Type
          , package = Package.Type.LogProc
          , version = ""
          , new_version = ""
          , architecture = "amd64"
          , network = Network.Type.Berkeley
          , codename = DebianVersions.DebVersion.Bullseye
          , from_channel = DebianChannel.Type.Unstable
          , to_channel = DebianChannel.Type.Nightly
          , profile = Profiles.Type.Standard
          , remove_profile_from_name = False
          , step_key = "promote-debian-package"
          , if = None B/If
          }
      }

let PromoteDockerSpec =
      { Type =
          { deps : List Command.TaggedKey.Type
          , name : Artifact.Type
          , version : Text
          , profile : Profiles.Type
          , codename : DebianVersions.DebVersion
          , new_tag : Text
          , network : Network.Type
          , step_key : Text
          , if : Optional B/If
          , publish : Bool
          , remove_profile_from_name : Bool
          }
      , default =
          { deps = [] : List Command.TaggedKey.Type
          , name = Artifact.Type.Daemon
          , version = ""
          , new_tag = ""
          , step_key = "promote-docker"
          , profile = Profiles.Type.Standard
          , network = Network.Type.Berkeley
          , codename = DebianVersions.DebVersion.Bullseye
          , if = None B/If
          , publish = False
          , remove_profile_from_name = False
          }
      }

let PromotePackagesSpec =
      { Type =
          { debians : List Package.Type
          , dockers : List Artifact.Type
          , version : Text
          , new_version : Text
          , architecture : Text
          , profile : Profiles.Type
          , network : Network.Type
          , codenames : List DebianVersions.DebVersion
          , from_channel : DebianChannel.Type
          , to_channel : DebianChannel.Type
          , tag : Text
          , remove_profile_from_name : Bool
          , publish : Bool
          }
      , default =
          { debians = [] : List Package.Type
          , dockers = [] : List Artifact.Type
          , version = ""
          , new_version = ""
          , architecture = "amd64"
          , profile = Profiles.Type.Standard
          , network = Network.Type.Mainnet
          , codenames = [] : List DebianVersions.DebVersion
          , from_channel = DebianChannel.Type.Unstable
          , to_channel = DebianChannel.Type.Nightly
          , tag = ""
          , remove_profile_from_name = False
          , publish = False
          }
      }

let VerifyPackagesSpec =
      { Type =
          { promote_step_name : Optional Text
          , debians : List Package.Type
          , dockers : List Artifact.Type
          , new_version : Text
          , profile : Profiles.Type
          , network : Network.Type
          , codenames : List DebianVersions.DebVersion
          , channel : DebianChannel.Type
          , tag : Text
          , remove_profile_from_name : Bool
          , published : Bool
          }
      , default =
          { promote_step_name = None
          , debians = [] : List Package.Type
          , dockers = [] : List Artifact.Type
          , new_version = ""
          , profile = Profiles.Type.Standard
          , network = Network.Type.Mainnet
          , codenames = [] : List DebianVersions.DebVersion
          , channel = DebianChannel.Type.Nightly
          , tag = ""
          , remove_profile_from_name = False
          , published = False
          }
      }

let promoteDebianStep =
          \(spec : PromoteDebianSpec.Type)
      ->  let package_name
              : Text
              = Package.debianName spec.package spec.profile spec.network

          let new_name =
                      if spec.remove_profile_from_name

                then  "--new-name ${Package.debianName
                                      spec.package
                                      Profiles.Type.Standard
                                      spec.network}"

                else  ""

          in  Command.build
                Command.Config::{
                , commands =
                    Toolchain.runner
                      DebianVersions.DebVersion.Bullseye
                      [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY" ]
                      "./buildkite/scripts/promote-deb.sh --package ${package_name} --version ${spec.version}  --new-version ${spec.new_version}  --architecture ${spec.architecture}  --codename ${DebianVersions.lowerName
                                                                                                                                                                                                      spec.codename}  --from-component ${DebianChannel.lowerName
                                                                                                                                                                                                                                           spec.from_channel}  --to-component ${DebianChannel.lowerName
                                                                                                                                                                                                                                                                                  spec.to_channel} ${new_name}"
                , label = "Debian: ${spec.step_key}"
                , key = spec.step_key
                , target = Size.XLarge
                , depends_on = spec.deps
                , if = spec.if
                }

let promoteDebianVerificationStep =
          \(spec : PromoteDebianSpec.Type)
      ->  let name =
                      if spec.remove_profile_from_name

                then  "${Package.debianName
                           spec.package
                           Profiles.Type.Standard
                           spec.network}"

                else  Package.debianName spec.package spec.profile spec.network

          in  Command.build
                Command.Config::{
                , commands =
                  [ Cmd.run
                      "./scripts/debian/verify.sh --package ${name} --version ${spec.new_version} --codename ${DebianVersions.lowerName
                                                                                                                 spec.codename}  --channel ${DebianChannel.lowerName
                                                                                                                                               spec.to_channel}"
                  ]
                , label = "Debian: ${spec.step_key}"
                , key = spec.step_key
                , target = Size.Small
                , depends_on = spec.deps
                , if = spec.if
                }

let promoteDockerStep =
          \(spec : PromoteDockerSpec.Type)
      ->  let old_tag =
                Artifact.dockerTag
                  spec.name
                  spec.version
                  spec.codename
                  spec.profile
                  spec.network
                  False

          let new_tag =
                Artifact.dockerTag
                  spec.name
                  spec.new_tag
                  spec.codename
                  spec.profile
                  spec.network
                  spec.remove_profile_from_name

          let publish = if spec.publish then "-p" else ""

          in  Command.build
                Command.Config::{
                , commands =
                  [ Cmd.run
                      "./buildkite/scripts/promote-docker.sh --name ${Artifact.dockerName
                                                                        spec.name} --version ${old_tag} --tag ${new_tag} ${publish}"
                  ]
                , label = "Docker: ${spec.step_key}"
                , key = spec.step_key
                , target = Size.XLarge
                , depends_on = spec.deps
                , if = spec.if
                }

let promoteDockerVerificationStep =
          \(spec : PromoteDockerSpec.Type)
      ->  let new_tag =
                Artifact.dockerTag
                  spec.name
                  spec.new_tag
                  spec.codename
                  spec.profile
                  spec.network
                  spec.remove_profile_from_name

          let repo =
                      if spec.publish

                then  "docker.io/minaprotocol"

                else  "gcr.io/o1labs-192920"

          in  Command.build
                Command.Config::{
                , commands =
                  [ Cmd.run
                      "docker pull ${repo}/${Artifact.dockerName
                                               spec.name}:${new_tag}"
                  ]
                , label = "Docker: ${spec.step_key}"
                , key = spec.step_key
                , target = Size.Small
                , depends_on = spec.deps
                , if = spec.if
                }

let promoteSteps
    :     List PromoteDebianSpec.Type
      ->  List PromoteDockerSpec.Type
      ->  List Command.Type
    =     \(debians_spec : List PromoteDebianSpec.Type)
      ->  \(dockers_spec : List PromoteDockerSpec.Type)
      ->    List/map
              PromoteDebianSpec.Type
              Command.Type
              (\(spec : PromoteDebianSpec.Type) -> promoteDebianStep spec)
              debians_spec
          # List/map
              PromoteDockerSpec.Type
              Command.Type
              (\(spec : PromoteDockerSpec.Type) -> promoteDockerStep spec)
              dockers_spec

let promote_packages_to_debian_spec
    : PromotePackagesSpec.Type -> List PromoteDebianSpec.Type
    =     \(promote_packages : PromotePackagesSpec.Type)
      ->  let debians_spec =
                List/map
                  Package.Type
                  (List PromoteDebianSpec.Type)
                  (     \(debian : Package.Type)
                    ->  List/map
                          DebianVersions.DebVersion
                          PromoteDebianSpec.Type
                          (     \(codename : DebianVersions.DebVersion)
                            ->  PromoteDebianSpec::{
                                 profile = promote_packages.profile
                                , package = debian
                                , version = promote_packages.version
                                , new_version = promote_packages.new_version
                                , architecture = promote_packages.architecture
                                , network = promote_packages.network
                                , codename = codename
                                , from_channel = promote_packages.from_channel
                                , to_channel = promote_packages.to_channel
                                , remove_profile_from_name =
                                    promote_packages.remove_profile_from_name
                                , step_key =
                                    "promote-debian-${Package.lowerName
                                                        debian}-${DebianVersions.lowerName
                                                                    codename}-from-${DebianChannel.lowerName
                                                                                       promote_packages.from_channel}-to-${DebianChannel.lowerName
                                                                                                            promote_packages.to_channel}"
                                }
                          )
                          promote_packages.codenames
                  )
                  promote_packages.debians

          in  Prelude.List.fold
                (List PromoteDebianSpec.Type)
                debians_spec
                (List PromoteDebianSpec.Type)
                (     \(a : List PromoteDebianSpec.Type)
                  ->  \(b : List PromoteDebianSpec.Type)
                  ->  a # b
                )
                ([] : List PromoteDebianSpec.Type)

let promote_packages_to_docker_spec
    : PromotePackagesSpec.Type -> List PromoteDockerSpec.Type
    =     \(promote_artifacts : PromotePackagesSpec.Type)
      ->  let dockers_spec =
                List/map
                  Artifact.Type
                  (List PromoteDockerSpec.Type)
                  (     \(docker : Artifact.Type)
                    ->  List/map
                          DebianVersions.DebVersion
                          PromoteDockerSpec.Type
                          (     \(codename : DebianVersions.DebVersion)
                            ->  PromoteDockerSpec::{
                                , profile = promote_artifacts.profile
                                , name = docker
                                , version = promote_artifacts.version
                                , codename = codename
                                , new_tag = promote_artifacts.new_version
                                , network = promote_artifacts.network
                                , publish = promote_artifacts.publish
                                , remove_profile_from_name =
                                    promote_artifacts.remove_profile_from_name
                                , step_key =
                                    "add-tag-to-${Artifact.lowerName
                                                    docker}-${DebianVersions.lowerName
                                                                codename}-docker"
                                }
                          )
                          promote_artifacts.codenames
                  )
                  promote_artifacts.dockers

          in  Prelude.List.fold
                (List PromoteDockerSpec.Type)
                dockers_spec
                (List PromoteDockerSpec.Type)
                (     \(a : List PromoteDockerSpec.Type)
                  ->  \(b : List PromoteDockerSpec.Type)
                  ->  a # b
                )
                ([] : List PromoteDockerSpec.Type)

let verify_packages_to_debian_spec
    : VerifyPackagesSpec.Type -> List PromoteDebianSpec.Type
    =     \(verify_packages : VerifyPackagesSpec.Type)
      ->  let debians_spec =
                List/map
                  Package.Type
                  (List PromoteDebianSpec.Type)
                  (     \(debian : Package.Type)
                    ->  List/map
                          DebianVersions.DebVersion
                          PromoteDebianSpec.Type
                          (     \(codename : DebianVersions.DebVersion)
                            ->  PromoteDebianSpec::{
                                , profile = verify_packages.profile
                                , package = debian
                                , new_version = verify_packages.new_version
                                , network = verify_packages.network
                                , codename = codename
                                , to_channel = verify_packages.channel
                                , remove_profile_from_name =
                                    verify_packages.remove_profile_from_name
                                , deps =
                                    Optional/toList
                                      Command.TaggedKey.Type
                                      ( Optional/map
                                          Text
                                          Command.TaggedKey.Type
                                          (     \(name : Text)
                                            ->  { name = name
                                                , key =
                                                    "promote-debian-${Package.lowerName
                                                                        debian}-${DebianVersions.lowerName
                                                                                    codename}-${DebianChannel.lowerName
                                                                                                  verify_packages.channel}"
                                                }
                                          )
                                          verify_packages.promote_step_name
                                      )
                                , step_key =
                                    "verify-promote-debian-${Package.lowerName
                                                               debian}-${DebianVersions.lowerName
                                                                           codename}-${DebianChannel.lowerName
                                                                                         verify_packages.channel}"
                                }
                          )
                          verify_packages.codenames
                  )
                  verify_packages.debians

          in  Prelude.List.fold
                (List PromoteDebianSpec.Type)
                debians_spec
                (List PromoteDebianSpec.Type)
                (     \(a : List PromoteDebianSpec.Type)
                  ->  \(b : List PromoteDebianSpec.Type)
                  ->  a # b
                )
                ([] : List PromoteDebianSpec.Type)

let verify_packages_to_docker_spec
    : VerifyPackagesSpec.Type -> List PromoteDockerSpec.Type
    =     \(verify_packages : VerifyPackagesSpec.Type)
      ->  let dockers_spec =
                List/map
                  Artifact.Type
                  (List PromoteDockerSpec.Type)
                  (     \(docker : Artifact.Type)
                    ->  List/map
                          DebianVersions.DebVersion
                          PromoteDockerSpec.Type
                          (     \(codename : DebianVersions.DebVersion)
                            ->  PromoteDockerSpec::{
                                , profile = verify_packages.profile
                                , name = docker
                                , codename = codename
                                , new_tag = verify_packages.new_version
                                , network = verify_packages.network
                                , publish = verify_packages.published
                                , remove_profile_from_name =
                                    verify_packages.remove_profile_from_name
                                , deps =  Optional/toList
                                      Command.TaggedKey.Type
                                      ( Optional/map
                                          Text
                                          Command.TaggedKey.Type
                                          (     \(name : Text)
                                            ->  { name = name
                                                , key =
                                                    "add-tag-${Artifact.lowerName
                                                                 docker}-${DebianVersions.lowerName
                                                                             codename}-docker"
                                                }
                                          )
                                          verify_packages.promote_step_name
                                      )
                                , step_key =
                                    "verify-tag-${Artifact.lowerName
                                                    docker}-${DebianVersions.lowerName
                                                                codename}-docker"
                                }
                          )
                          verify_packages.codenames
                  )
                  verify_packages.dockers

          in  Prelude.List.fold
                (List PromoteDockerSpec.Type)
                dockers_spec
                (List PromoteDockerSpec.Type)
                (     \(a : List PromoteDockerSpec.Type)
                  ->  \(b : List PromoteDockerSpec.Type)
                  ->  a # b
                )
                ([] : List PromoteDockerSpec.Type)

let verificationSteps
    :     List PromoteDebianSpec.Type
      ->  List PromoteDockerSpec.Type
      ->  List Command.Type
    =     \(debians_spec : List PromoteDebianSpec.Type)
      ->  \(dockers_spec : List PromoteDockerSpec.Type)
      ->    List/map
              PromoteDebianSpec.Type
              Command.Type
              (     \(spec : PromoteDebianSpec.Type)
                ->  promoteDebianVerificationStep spec
              )
              debians_spec
          # List/map
              PromoteDockerSpec.Type
              Command.Type
              (     \(spec : PromoteDockerSpec.Type)
                ->  promoteDockerVerificationStep spec
              )
              dockers_spec

let promotePipeline
    :     List PromoteDebianSpec.Type
      ->  List PromoteDockerSpec.Type
      ->  DebianVersions.DebVersion
      ->  PipelineMode.Type
      ->  Pipeline.Config.Type
    =     \(debians_spec : List PromoteDebianSpec.Type)
      ->  \(dockers_spec : List PromoteDockerSpec.Type)
      ->  \(debVersion : DebianVersions.DebVersion)
      ->  \(mode : PipelineMode.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen = DebianVersions.dirtyWhen debVersion
            , path = "Release"
            , name = "PromotePackage"
            , tags = [] : List PipelineTag.Type
            , mode = mode
            }
          , steps = promoteSteps debians_spec dockers_spec
          }

let verifyPipeline
    :     List PromoteDebianSpec.Type
      ->  List PromoteDockerSpec.Type
      ->  DebianVersions.DebVersion
      ->  PipelineMode.Type
      ->  Pipeline.Config.Type
    =     \(debians_spec : List PromoteDebianSpec.Type)
      ->  \(dockers_spec : List PromoteDockerSpec.Type)
      ->  \(debVersion : DebianVersions.DebVersion)
      ->  \(mode : PipelineMode.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen = DebianVersions.dirtyWhen debVersion
            , path = "Release"
            , name = "VerifyPackage"
            , tags = [] : List PipelineTag.Type
            , mode = mode
            }
          , steps = verificationSteps debians_spec dockers_spec
          }

in  { PromoteDebianSpec = PromoteDebianSpec
    , PromoteDockerSpec = PromoteDockerSpec
    , VerifyPackagesSpec = VerifyPackagesSpec
    , PromotePackagesSpec = PromotePackagesSpec
    , promoteDebianStep = promoteDebianStep
    , promoteDockerStep = promoteDockerStep
    , verifyPackagesToDockerSpec = verify_packages_to_docker_spec
    , promotePackagesToDockerSpec = promote_packages_to_docker_spec
    , verifyPackagesToDebianSpec = verify_packages_to_debian_spec
    , promotePackagesToDebianSpec = promote_packages_to_debian_spec
    , promoteDebianVerificationStep = promoteDebianVerificationStep
    , promoteDockerVerificationStep = promoteDockerVerificationStep
    , promoteSteps = promoteSteps
    , promotePipeline = promotePipeline
    , verificationSteps = verificationSteps
    , verifyPipeline = verifyPipeline
    }
