let S = ../../Lib/SelectFiles.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Command = ../../Command/Base.dhall

let Size = ../../Command/Size.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let DebianPackage = ../../Constants/DebianPackage.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PromotePackage = ../../Command/PromotePackage.dhall

let promote_packages =
     PromotePackage.PromotePackagesSpec::{
      , debians = [ DebianPackage.Type.Daemon, DebianPackage.Type.LogProc ]
      , dockers = [ Artifacts.Type.Daemon ]
      , version = "\\\$MINA_DEB_VERSION"
      , architecture = "amd64"
      , new_version = "\\\$MINA_DEB_VERSION"
      , profile = Profiles.Type.Standard
      , network = Network.Type.Devnet
      , codenames = [ DebianVersions.DebVersion.Bullseye, DebianVersions.DebVersion.Focal, DebianVersions.DebVersion.Buster]
      , from_channel = DebianChannel.Type.Unstable
      , to_channel = DebianChannel.Type.Nightly
      , tag = "nightly"
      , remove_profile_from_name = True
      , publish = False
      }

let promote_debians_spec =
      PromotePackage.promotePackagesToDebianSpec promote_packages

let promote_dockers_spec =
      PromotePackage.promotePackagesToDockerSpec promote_packages

let verify_debians_spec =
      PromotePackage.verifyPackagesToDebianSpec promote_packages

let verify_dockers_spec =
      PromotePackage.verifyPackagesToDockerSpec promote_packages

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Test"
        , tags = [ Pipeline.Type.AutoPromoteNightly ]
        , name = "AutoPromoteNightly"
        }
      , steps =
            promoteSteps promote_debians_spec promote_dockers_spec
          # verificationSteps verify_debians_spec verify_dockers_spec
      }
