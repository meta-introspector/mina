(* state_hash.mli *)

open Core_kernel
open Snark_params.Tick

include Data_hash.Full_size

include Codable.Base58_check_intf with type t := t

val raw_hash_bytes : t -> string

val to_bytes : [ `Use_to_base58_check_or_raw_hash_bytes ]

(* value of type t, not a valid hash *)
val dummy : t

val zero : Field.t

val to_decimal_string : t -> string

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V1 : sig
    type t = Field.t [@@deriving sexp, compare, hash, yojson]

    val to_latest : t -> t

    include Comparable.S with type t := t

    include Hashable_binable with type t := t
  end
end]

val deriver :
     (< contramap : (t -> Yojson.Safe.t) ref
      ; graphql_fields :
          Yojson.Safe.t Fields_derivers_graphql.Graphql_fields.Input.T.t ref
      ; map : (Yojson.Safe.t -> t) ref
      ; nullable_graphql_fields :
          Yojson.Safe.t option Fields_derivers_graphql.Graphql_fields.Input.T.t
          ref
      ; of_json : (Yojson.Safe.t -> Yojson.Safe.t) ref
      ; to_json : (Yojson.Safe.t -> Yojson.Safe.t) ref
      ; .. >
      as
      'a)
  -> 'a
