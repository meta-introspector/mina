let S = ../../Lib/SelectFiles.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let DebianPackage = ../../Constants/DebianPackage.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PromotePackages = ../../Command/Promotion/PromotePackages.dhall

let VerifyPackages = ../../Command/Promotion/VerifyPackages.dhall

let promotePackages =
      PromotePackages.PromotePackagesSpec::{
      , debians = [ DebianPackage.Type.Daemon, DebianPackage.Type.LogProc ]
      , dockers = [ Artifacts.Type.Daemon ]
      , version = "\\\$MINA_DEB_VERSION"
      , architecture = "amd64"
      , new_version = "\\\$MINA_DEB_VERSION"
      , profile = Profiles.Type.Standard
      , network = Network.Type.Devnet
      , codenames =
        [ DebianVersions.DebVersion.Bullseye
        , DebianVersions.DebVersion.Focal
        , DebianVersions.DebVersion.Buster
        ]
      , from_channel = DebianChannel.Type.Unstable
      , to_channel = DebianChannel.Type.Nightly
      , tag = "nightly"
      , remove_profile_from_name = True
      , publish = False
      }

let verfiyPackages =
      VerifyPackages.VerifyPackagesSpec::{
      , promote_step_name = Some "AutoPromoteNightly"
      , debians = [] : List DebianPackage.Type
      , dockers = [] : List Artifacts.Type
      , new_version = ""
      , profile = Profiles.Type.Standard
      , network = Network.Type.Mainnet
      , codenames = [] : List DebianVersions.DebVersion
      , channel = DebianChannel.Type.Nightly
      , tag = ""
      , remove_profile_from_name = False
      , published = False
      }

let promoteDebiansSpecs =
      PromotePackages.promotePackagesToDebianSpecs promotePackages

let promoteDockersSpecs =
      PromotePackages.promotePackagesToDockerSpecs promotePackages

let verifyDebiansSpecs =
      VerifyPackages.verifyPackagesToDebianSpecs verfiyPackages

let verifyDockersSpecs =
      VerifyPackages.verifyPackagesToDockerSpecs verfiyPackages

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Test"
        , tags = [ PipelineTag.Type.TearDown ]
        , name = "AutoPromoteNightly"
        }
      , steps =
            PromotePackages.promoteSteps promoteDebiansSpecs promoteDockersSpecs
          # VerifyPackages.verificationSteps
              verifyDebiansSpecs
              verifyDockersSpecs
      }
