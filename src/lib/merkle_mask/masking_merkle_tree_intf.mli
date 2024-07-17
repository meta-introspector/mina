(* masking_merkle_tree_intf.ml *)
(* the type of a Merkle tree mask associated with a parent Merkle tree *)
module type S = sig
  type t

  type unattached = t

  type parent

  type account

  type location

  type hash

  type key

  type token_id

  type token_id_set

  type account_id

  type account_id_set

  module Location : Merkle_ledger.Location_intf.S

  module Addr = Location.Addr

  (** create a mask with no parent *)
  val create : depth:int -> unit -> t

  val get_uuid : t -> Uuid.t

  type accumulated_t

  module Attached : sig
    include
      Base_merkle_tree_intf.S
        with module Addr = Addr
        with module Location = Location
        with type account := account
         and type root_hash := hash
         and type hash := hash
         and type key := key
         and type token_id := token_id
         and type token_id_set := token_id_set
         and type account_id := account_id
         and type account_id_set := account_id_set

    exception
      Dangling_parent_reference of
        Uuid.t * (* Location where null was set*) string

    (** get hash from mask, if present, else from its parent *)
    val get_hash : t -> Addr.t -> hash option

    (** commit all state to the parent, flush state locally *)
    val commit : t -> unit

    (** [unset_parent ?trigger_signal ~loc:__LOC__ t] detaches the parent from
        [t]. The [loc] argument is shown in the [Dangling_parent_reference]
        exception, which will be raised if [t] is used while no parent is
        registered.

        If the [trigger_signal] optional argument is [true] or omitted,
        [detached_signal] for [t] will be resolved. This should only be set to
        [false] when the mask will be reparented.
    *)
    val unset_parent : ?trigger_signal:bool -> loc:string -> t -> unattached

    (** get mask parent *)
    val get_parent : t -> parent

    (** called when parent sets an account; update local state *)
    val parent_set_notify : t -> account -> unit

    (* makes new mask instance with copied tables, re-use parent *)
    val copy : t -> t

    (* Adds specified accounts to the mask by laoding them from parent ledger.

       Could be useful for transaction processing when to pre-populate mask with the
       accounts used in processing a transaction (or a block) to ensure there are not loaded
       from parent on each lookup. I.e. these accounts will be cached in mask and accessing
       them during processing of a transaction won't use disk I/O.
    *)
    val unsafe_preload_accounts_from_parent : t -> account_id list -> unit

    val to_accumulated : t -> accumulated_t

    (** Drop accumulated structure, a method used in safeguard against
        unwanted modification of ancestor's mask *)
    val drop_accumulated : t -> unit

    val is_committing : t -> bool

    (** already have module For_testing from include above *)
    module For_testing : sig
      val location_in_mask : t -> location -> bool

      val address_in_mask : t -> Addr.t -> bool

      (* The rightmost filled loction *)
      val fill_frontier : t -> Location.t option
    end
  end

  (** tell mask about parent *)
  val set_parent :
    ?accumulated:accumulated_t -> unattached -> parent -> Attached.t
end
