let Prelude = ../External/Prelude.dhall

let List/map = Prelude.List.map

let PromotePackage = ../Command/PromotePackage.dhall

let Package = ../Constants/DebianPackage.dhall

let Profile = ../Constants/Profiles.dhall

let Artifact = ../Constants/Artifacts.dhall

let DebianChannel = ../Constants/DebianChannel.dhall

let Network = ../Constants/Network.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineMode = ../Pipeline/Mode.dhall

let promote_artifacts =
          \(debians : List Package.Type)
      ->  \(dockers : List Artifact.Type)
      ->  \(version : Text)
      ->  \(new_version : Text)
      ->  \(architecture : Text)
      ->  \(profile : Profile.Type)
      ->  \(network : Network.Type)
      ->  \(codenames : List DebianVersions.DebVersion)
      ->  \(from_channel : DebianChannel.Type)
      ->  \(to_channel : DebianChannel.Type)
      ->  \(tag : Text)
      ->  \(remove_profile_from_name : Bool)
      ->  \(publish : Bool)
      ->  let promote_packages =
                PromotePackage.PromotePackagesSpec::{
                , debians = debians
                , dockers = dockers
                , version = version
                , architecture = architecture
                , new_version = new_version
                , profile = profile
                , network = network
                , codenames = codenames
                , from_channel = from_channel
                , to_channel = to_channel
                , tag = tag
                , remove_profile_from_name = remove_profile_from_name
                , publish = publish
                }

          let debians_spec =
                PromotePackage.promotePackagesToDebianSpec promote_packages

          let dockers_spec =
                PromotePackage.promotePackagesToDockerSpec promote_packages

          let pipelineType =
                Pipeline.build
                  ( PromotePackage.promotePipeline
                      debians_spec
                      dockers_spec
                      DebianVersions.DebVersion.Bullseye
                      PipelineMode.Type.Stable
                  )

          in  pipelineType.pipeline

let verify_artifacts =
          \(debians : List Package.Type)
      ->  \(dockers : List Artifact.Type)
      ->  \(new_version : Text)
      ->  \(profile : Profile.Type)
      ->  \(network : Network.Type)
      ->  \(codenames : List DebianVersions.DebVersion)
      ->  \(to_channel : DebianChannel.Type)
      ->  \(tag : Text)
      ->  \(remove_profile_from_name : Bool)
      ->  \(publish : Bool)
      ->  let verify_packages =
                PromotePackage.VerifyPackagesSpec::{
                  promote_step_name = None Text
                  , debians = debians
                  , dockers = dockers
                  , new_version = new_version
                  , profile = profile
                  , network = network
                  , codenames = codenames
                  , channel = to_channel
                  , tag = tag
                  , remove_profile_from_name = remove_profile_from_name
                  , published = publish
                }

          let debians_spec =
                PromotePackage.verifyPackagesToDebianSpec verify_packages

          let dockers_spec =
                PromotePackage.verifyPackagesToDockerSpec verify_packages

          let pipelineType =
                Pipeline.build
                  ( PromotePackage.verifyPipeline
                      debians_spec
                      dockers_spec
                      DebianVersions.DebVersion.Bullseye
                      PipelineMode.Type.Stable
                  )

          in  pipelineType.pipeline

in  { promote_artifacts = promote_artifacts
    , verify_artifacts = verify_artifacts
    }
