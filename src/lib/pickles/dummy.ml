open Core_kernel
open Pickles_types
open Backend
open Composition_types
open Common

let _wrap_domains = Common.wrap_domains

let evals ~num_wrap_chunks =
  let open Plonk_types in
  let e =
    Evals.map
      (Evaluation_lengths.create ~num_chunks:num_wrap_chunks ~of_int:Fn.id)
      ~f:(fun n ->
        let a () = Array.create ~len:n (Ro.tock ()) in
        (a (), a ()) )
  in
  let ex =
    { All_evals.With_public_input.evals = e
    ; public_input = (Ro.tock (), Ro.tock ())
    }
  in
  { All_evals.ft_eval1 = Ro.tock (); evals = ex }

let evals_combined =
  Plonk_types.All_evals.map (evals ~num_wrap_chunks:1) ~f1:Fn.id
    ~f2:(Array.reduce_exn ~f:Backend.Tock.Field.( + ))

module Ipa = struct
  module Wrap = struct
    let challenges =
      Vector.init Tock.Rounds.n ~f:(fun _ ->
          let prechallenge = Ro.scalar_chal () in
          { Bulletproof_challenge.prechallenge } )

    let challenges_computed =
      Vector.map challenges ~f:(fun { prechallenge } : Tock.Field.t ->
          Ipa.Wrap.compute_challenge prechallenge )

    let sg =
      lazy (time "dummy wrap sg" (fun () -> Ipa.Wrap.compute_sg challenges))
  end

  module Step = struct
    let challenges =
      Vector.init Tick.Rounds.n ~f:(fun _ ->
          let prechallenge = Ro.scalar_chal () in
          { Bulletproof_challenge.prechallenge } )

    let challenges_computed =
      Vector.map challenges ~f:(fun { prechallenge } : Tick.Field.t ->
          Ipa.Step.compute_challenge prechallenge )

    let sg =
      lazy (time "dummy wrap sg" (fun () -> Ipa.Step.compute_sg challenges))
  end
end
