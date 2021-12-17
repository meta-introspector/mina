module Poly_comm0 = Poly_comm
open Unsigned.Size_t

module type Stable_v1 = sig
  module Stable : sig
    module V1 : sig
      type t [@@deriving version, bin_io, sexp, compare, yojson, hash, equal]
    end

    module Latest = V1
  end

  type t = Stable.V1.t [@@deriving sexp, compare, yojson]
end

module type Inputs_intf = sig
  open Intf

  val name : string

  module Rounds : Pickles_types.Nat.Intf

  module Gate_vector : sig
    open Unsigned

    type t

    val wrap : t -> Kimchi.Protocol.wire -> Kimchi.Protocol.wire -> unit
  end

  module Urs : sig
    type t

    val read : int option -> string -> t option

    val write : bool option -> t -> string -> unit

    val create : int -> t
  end

  module Scalar_field : sig
    include Stable_v1

    val one : t
  end

  module Constraint_system : sig
    type t = (Gate_vector.t, Scalar_field.t) Plonk_constraint_system.t

    val finalize_and_get_gates : t -> Gate_vector.t
  end

  module Index : sig
    type t

    val create : Gate_vector.t -> int -> Urs.t -> t
  end

  module Curve : sig
    module Affine : sig
      type t
    end

    module Base_field : sig
      type t
    end
  end

  module Poly_comm : sig
    module Backend : sig
      type t
    end

    type t = Curve.Base_field.t Poly_comm0.t

    val of_backend_without_degree_bound : Backend.t -> t
  end

  module Verifier_index : sig
    type t =
      ( Scalar_field.t
      , Urs.t
      , Poly_comm.Backend.t )
      Kimchi.Protocol.VerifierIndex.verifier_index

    val create : Index.t -> t
  end
end

module Make (Inputs : Inputs_intf) = struct
  open Core_kernel

  type t =
    { index : Inputs.Index.t
    ; cs :
        (Inputs.Gate_vector.t, Inputs.Scalar_field.t) Plonk_constraint_system.t
    }

  let name =
    sprintf "%s_%d_v4" Inputs.name (Pickles_types.Nat.to_int Inputs.Rounds.n)

  let set_urs_info, load_urs =
    let urs_info = Set_once.create () in
    let urs = ref None in
    let degree = 1 lsl Pickles_types.Nat.to_int Inputs.Rounds.n in
    let set_urs_info specs = Set_once.set_exn urs_info Lexing.dummy_pos specs in
    let load () =
      match !urs with
      | Some urs ->
          urs
      | None ->
          let specs =
            match Set_once.get urs_info with
            | None ->
                failwith "Dlog_based.urs: Info not set"
            | Some t ->
                t
          in
          let store =
            Key_cache.Sync.Disk_storable.simple
              (fun () -> name)
              (fun () ~path ->
                Or_error.try_with_join (fun () ->
                    match Inputs.Urs.read None path with
                    | Some urs ->
                        Ok urs
                    | None ->
                        Or_error.errorf
                          "Could not read the URS from disk; its format did \
                           not match the expected format"))
              (fun _ urs path ->
                Or_error.try_with (fun () -> Inputs.Urs.write None urs path))
          in
          let u =
            match Key_cache.Sync.read specs store () with
            | Ok (u, _) ->
                u
            | Error _e ->
                let urs = Inputs.Urs.create degree in
                let (_ : (unit, Error.t) Result.t) =
                  Key_cache.Sync.write
                    (List.filter specs ~f:(function
                      | On_disk _ ->
                          true
                      | S3 _ ->
                          false))
                    store () urs
                in
                urs
          in
          urs := Some u ;
          u
    in
    (set_urs_info, load)

  let create cs =
    let gates = Inputs.Constraint_system.finalize_and_get_gates cs in
    let public_input_size = Set_once.get_exn cs.public_input_size [%here] in
    let index = Inputs.Index.create gates public_input_size (load_urs ()) in
    { index; cs }

  let vk t = Inputs.Verifier_index.create t.index

  let pk t = t

  let array_to_vector a = Pickles_types.Vector.of_list (Array.to_list a)

  (** does this convert a backend.verifier_index to a pickles_types.verifier_index? *)
  let vk_commitments (t : Inputs.Verifier_index.t) :
      Inputs.Curve.Affine.t
      Pickles_types.Dlog_plonk_types.Poly_comm.Without_degree_bound.t
      Pickles_types.Plonk_verification_key_evals.t =
    failwith "unimplemented"
end
