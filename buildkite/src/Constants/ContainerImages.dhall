-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBuster =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:c967eb61f1d262e8a1c9f5ecbc7a6881aa953b579bb41984c50bf302489687b3"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:d4d55914e230fd92973c50d1fc17c2402b56e3dec1ee5755e96b406d6116aa3f"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:d4d55914e230fd92973c50d1fc17c2402b56e3dec1ee5755e96b406d6116aa3f"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:d4d55914e230fd92973c50d1fc17c2402b56e3dec1ee5755e96b406d6116aa3f"
, delegationBackendToolchain =
    "gcr.io/o1labs-192920/delegation-backend-production@sha256:12ffd0a9016819c720687f440c7a46b8815f8d3ad06d306d342ee5f8dd4375f5"
, elixirToolchain = "elixir:1.10-alpine"
, nodeToolchain = "node:14.13.1-stretch-slim"
, ubuntu2004 = "ubuntu:20.04"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
