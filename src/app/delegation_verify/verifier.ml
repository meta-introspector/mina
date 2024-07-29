let verify_functions ~constraint_constants ~proof_level ~logger () =
  let module T = Transaction_snark.Make (struct
    let constraint_constants = constraint_constants

    let proof_level = proof_level

    let logger = logger
  end) in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = constraint_constants

    let proof_level = proof_level

    let logger = logger
  end) in
  (B.Proof.verify ~logger, T.verify)
