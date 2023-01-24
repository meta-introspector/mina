(* zkapp_command_logic.ml *)
open Core_kernel
open Mina_base
open Transaction_logic_intf
module Local_state = Local_state

module Eff = struct
  type (_, _) t =
    | Check_valid_while_precondition :
        'valid_while_precondition * 'global_state
        -> ( 'bool
           , < bool : 'bool
             ; valid_while_precondition : 'valid_while_precondition
             ; global_state : 'global_state
             ; .. > )
           t
    | Check_account_precondition :
        (* the bool input is a new_account flag *)
        'account_update
        * 'account
        * 'bool
        * 'local_state
        -> ( 'local_state
           , < bool : 'bool
             ; account_update : 'account_update
             ; account : 'account
             ; local_state : 'local_state
             ; .. > )
           t
    | Check_protocol_state_precondition :
        'protocol_state_pred * 'global_state
        -> ( 'bool
           , < bool : 'bool
             ; global_state : 'global_state
             ; protocol_state_precondition : 'protocol_state_pred
             ; .. > )
           t
    | Init_account :
        { account_update : 'account_update; account : 'account }
        -> ( 'account
           , < account_update : 'account_update ; account : 'account ; .. > )
           t
end

type 'e handler = { perform : 'r. ('r, 'e) Eff.t -> 'r }

module type Inputs_intf = sig
  val with_label : label:string -> (unit -> 'a) -> 'a

  module Bool : Bool_intf

  module Field : Iffable with type bool := Bool.t

  module Amount : Amount_intf with type bool := Bool.t

  module Balance :
    Balance_intf
      with type bool := Bool.t
       and type amount := Amount.t
       and type signed_amount := Amount.Signed.t

  module Public_key : Iffable with type bool := Bool.t

  module Token_id : Token_id_intf with type bool := Bool.t

  module Account_id :
    Account_id_intf
      with type bool := Bool.t
       and type public_key := Public_key.t
       and type token_id := Token_id.t

  module Set_or_keep : Set_or_keep_intf with type bool := Bool.t

  module Protocol_state_precondition : Protocol_state_precondition_intf

  module Valid_while_precondition : Valid_while_precondition_intf

  module Controller : Controller_intf with type bool := Bool.t

  module Global_slot : Global_slot_intf with type bool := Bool.t

  module Nonce : sig
    include Iffable with type bool := Bool.t

    val succ : t -> t
  end

  module State_hash : Iffable with type bool := Bool.t

  module Timing :
    Timing_intf with type bool := Bool.t and type global_slot := Global_slot.t

  module Zkapp_uri : Iffable with type bool := Bool.t

  module Token_symbol : Iffable with type bool := Bool.t

  module Opt : Opt_intf with type bool := Bool.t

  module rec Receipt_chain_hash :
    (Receipt_chain_hash_intf
      with type bool := Bool.t
       and type transaction_commitment := Transaction_commitment.t
       and type index := Index.t)

  and Verification_key : (Iffable with type bool := Bool.t)
  and Verification_key_hash :
    (Verification_key_hash_intf with type bool := Bool.t)

  and Account :
    (Account_intf
      with type Permissions.controller := Controller.t
       and type timing := Timing.t
       and type balance := Balance.t
       and type receipt_chain_hash := Receipt_chain_hash.t
       and type bool := Bool.t
       and type global_slot := Global_slot.t
       and type field := Field.t
       and type verification_key := Verification_key.t
       and type verification_key_hash := Verification_key_hash.t
       and type zkapp_uri := Zkapp_uri.t
       and type token_symbol := Token_symbol.t
       and type public_key := Public_key.t
       and type nonce := Nonce.t
       and type state_hash := State_hash.t
       and type token_id := Token_id.t
       and type account_id := Account_id.t)

  and Actions :
    (Actions_intf with type bool := Bool.t and type field := Field.t)

  and Account_update :
    (Account_update_intf
      with type signed_amount := Amount.Signed.t
       and type protocol_state_precondition := Protocol_state_precondition.t
       and type valid_while_precondition := Valid_while_precondition.t
       and type token_id := Token_id.t
       and type bool := Bool.t
       and type account := Account.t
       and type public_key := Public_key.t
       and type nonce := Nonce.t
       and type account_id := Account_id.t
       and type verification_key_hash := Verification_key_hash.t
       and type Update.timing := Timing.t
       and type 'a Update.set_or_keep := 'a Set_or_keep.t
       and type Update.field := Field.t
       and type Update.verification_key := Verification_key.t
       and type Update.actions := Actions.t
       and type Update.zkapp_uri := Zkapp_uri.t
       and type Update.token_symbol := Token_symbol.t
       and type Update.state_hash := State_hash.t
       and type Update.permissions := Account.Permissions.t)

  and Nonce_precondition : sig
    val is_constant :
         Nonce.t Zkapp_precondition.Closed_interval.t Account_update.or_ignore
      -> Bool.t
  end

  and Ledger :
    (Ledger_intf
      with type bool := Bool.t
       and type account := Account.t
       and type account_update := Account_update.t
       and type token_id := Token_id.t
       and type public_key := Public_key.t)

  and Call_forest :
    (Call_forest_intf
      with type t = Account_update.call_forest
       and type bool := Bool.t
       and type account_update := Account_update.t
       and module Opt := Opt)

  and Stack_frame :
    (Stack_frame_intf
      with type bool := Bool.t
       and type call_forest := Call_forest.t
       and type caller := Token_id.t)

  and Call_stack :
    (Call_stack_intf
      with type stack_frame := Stack_frame.t
       and type bool := Bool.t
       and module Opt := Opt)

  and Transaction_commitment : sig
    include
      Iffable
        with type bool := Bool.t
         and type t = Account_update.transaction_commitment

    val empty : t

    val commitment : account_updates:Call_forest.t -> t

    val full_commitment :
      account_update:Account_update.t -> memo_hash:Field.t -> commitment:t -> t
  end

  and Index : sig
    include Iffable with type bool := Bool.t

    val zero : t

    val succ : t -> t
  end

  module Local_state : sig
    type t =
      ( Stack_frame.t
      , Call_stack.t
      , Token_id.t
      , Amount.Signed.t
      , Ledger.t
      , Bool.t
      , Transaction_commitment.t
      , Index.t
      , Bool.failure_status_tbl )
      Local_state.t

    val add_check : t -> Transaction_status.Failure.t -> Bool.t -> t

    val update_failure_status_tbl : t -> Bool.failure_status -> Bool.t -> t

    val add_new_failure_status_bucket : t -> t
  end

  module Global_state : sig
    type t

    val ledger : t -> Ledger.t

    val set_ledger : should_update:Bool.t -> t -> Ledger.t -> t

    val fee_excess : t -> Amount.Signed.t

    val set_fee_excess : t -> Amount.Signed.t -> t

    val supply_increase : t -> Amount.Signed.t

    val set_supply_increase : t -> Amount.Signed.t -> t

    val block_global_slot : t -> Global_slot.t
  end
end

module Start_data = struct
  open Core_kernel

  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('zkapp_command, 'field, 'bool) t =
        { zkapp_command : 'zkapp_command
        ; memo_hash : 'field
        ; will_succeed : 'bool
        }
      [@@deriving sexp, yojson]
    end
  end]
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs

  let default_caller = Token_id.default

  let stack_frame_default () =
    Stack_frame.make ~caller:default_caller ~caller_caller:default_caller
      ~calls:(Call_forest.empty ())

  let assert_ ~pos b = Bool.Assert.is_true ~pos b

  (* Pop from the call stack, returning dummy values if the stack is empty. *)
  let pop_call_stack (s : Call_stack.t) : Stack_frame.t * Call_stack.t =
    let res = Call_stack.pop s in
    (* Split out the option returned by Call_stack.pop into two options *)
    let next_frame, next_call_stack =
      (Opt.map ~f:fst res, Opt.map ~f:snd res)
    in
    (* Handle the None cases *)
    ( Opt.or_default ~if_:Stack_frame.if_ ~default:(stack_frame_default ())
        next_frame
    , Opt.or_default ~if_:Call_stack.if_ ~default:(Call_stack.empty ())
        next_call_stack )

  type get_next_account_update_result =
    { account_update : Account_update.t
    ; caller_id : Token_id.t
    ; account_update_forest : Call_forest.t
    ; new_call_stack : Call_stack.t
    ; new_frame : Stack_frame.t
    }

  let get_next_account_update (current_forest : Stack_frame.t)
      (* The stack for the most recent zkApp *)
        (call_stack : Call_stack.t) (* The partially-completed parent stacks *)
      : get_next_account_update_result =
    (* If the current stack is complete, 'return' to the previous
       partially-completed one.
    *)
    let current_forest, call_stack =
      let next_forest, next_call_stack =
        (* Invariant: call_stack contains only non-empty forests. *)
        pop_call_stack call_stack
      in
      (* TODO: I believe current should only be empty for the first account_update in
         a transaction. *)
      let current_is_empty =
        Call_forest.is_empty (Stack_frame.calls current_forest)
      in
      ( Stack_frame.if_ current_is_empty ~then_:next_forest ~else_:current_forest
      , Call_stack.if_ current_is_empty ~then_:next_call_stack ~else_:call_stack
      )
    in
    let (account_update, account_update_forest), remainder_of_current_forest =
      Call_forest.pop_exn (Stack_frame.calls current_forest)
    in
    let may_use_parents_own_token =
      Account_update.may_use_parents_own_token account_update
    in
    let may_use_token_inherited_from_parent =
      Account_update.may_use_token_inherited_from_parent account_update
    in
    let caller_id =
      Token_id.if_ may_use_token_inherited_from_parent
        ~then_:(Stack_frame.caller_caller current_forest)
        ~else_:
          (Token_id.if_ may_use_parents_own_token
             ~then_:(Stack_frame.caller current_forest)
             ~else_:Token_id.default )
    in
    (* Cases:
       - [account_update_forest] is empty, [remainder_of_current_forest] is empty.
       Pop from the call stack to get another forest, which is guaranteed to be non-empty.
       The result of popping becomes the "current forest".
       - [account_update_forest] is empty, [remainder_of_current_forest] is non-empty.
       Push nothing to the stack. [remainder_of_current_forest] becomes new "current forest"
       - [account_update_forest] is non-empty, [remainder_of_current_forest] is empty.
       Push nothing to the stack. [account_update_forest] becomes new "current forest"
       - [account_update_forest] is non-empty, [remainder_of_current_forest] is non-empty:
       Push [remainder_of_current_forest] to the stack. [account_update_forest] becomes new "current forest".
    *)
    let account_update_forest_empty =
      Call_forest.is_empty account_update_forest
    in
    let remainder_of_current_forest_empty =
      Call_forest.is_empty remainder_of_current_forest
    in
    let newly_popped_frame, popped_call_stack = pop_call_stack call_stack in
    let remainder_of_current_forest_frame : Stack_frame.t =
      Stack_frame.make
        ~caller:(Stack_frame.caller current_forest)
        ~caller_caller:(Stack_frame.caller_caller current_forest)
        ~calls:remainder_of_current_forest
    in
    let new_call_stack =
      Call_stack.if_ account_update_forest_empty
        ~then_:
          (Call_stack.if_ remainder_of_current_forest_empty
             ~then_:
               (* Don't actually need the or_default used in this case. *)
               popped_call_stack ~else_:call_stack )
        ~else_:
          (Call_stack.if_ remainder_of_current_forest_empty ~then_:call_stack
             ~else_:
               (Call_stack.push remainder_of_current_forest_frame
                  ~onto:call_stack ) )
    in
    let new_frame =
      Stack_frame.if_ account_update_forest_empty
        ~then_:
          (Stack_frame.if_ remainder_of_current_forest_empty
             ~then_:newly_popped_frame ~else_:remainder_of_current_forest_frame )
        ~else_:
          (let caller =
             Account_id.derive_token_id
               ~owner:(Account_update.account_id account_update)
           and caller_caller = caller_id in
           Stack_frame.make ~calls:account_update_forest ~caller ~caller_caller
          )
    in
    { account_update
    ; caller_id
    ; account_update_forest
    ; new_frame
    ; new_call_stack
    }

  let update_sequence_state (sequence_state : _ Pickles_types.Vector.t) actions
      ~txn_global_slot ~last_sequence_slot =
    (* Push events to s1. *)
    let [ s1'; s2'; s3'; s4'; s5' ] = sequence_state in
    let is_empty = Actions.is_empty actions in
    let s1_updated = Actions.push_events s1' actions in
    let s1 = Field.if_ is_empty ~then_:s1' ~else_:s1_updated in
    (* Shift along if not empty and last update wasn't this slot *)
    let is_this_slot = Global_slot.equal txn_global_slot last_sequence_slot in
    let is_empty_or_this_slot = Bool.(is_empty ||| is_this_slot) in
    let s5 = Field.if_ is_empty_or_this_slot ~then_:s5' ~else_:s4' in
    let s4 = Field.if_ is_empty_or_this_slot ~then_:s4' ~else_:s3' in
    let s3 = Field.if_ is_empty_or_this_slot ~then_:s3' ~else_:s2' in
    let s2 = Field.if_ is_empty_or_this_slot ~then_:s2' ~else_:s1' in
    let last_sequence_slot =
      Global_slot.if_ is_empty ~then_:last_sequence_slot ~else_:txn_global_slot
    in
    (([ s1; s2; s3; s4; s5 ] : _ Pickles_types.Vector.t), last_sequence_slot)

  let apply ~(constraint_constants : Genesis_constants.Constraint_constants.t)
      ~(is_start : [ `Yes of _ Start_data.t | `No | `Compute of _ Start_data.t ])
      (h :
        (< global_state : Global_state.t
         ; transaction_commitment : Transaction_commitment.t
         ; full_transaction_commitment : Transaction_commitment.t
         ; amount : Amount.t
         ; bool : Bool.t
         ; failure : Bool.failure_status
         ; .. >
         as
         'env )
        handler )
      ((global_state : Global_state.t), (local_state : Local_state.t)) =
    let open Inputs in
    let is_start' =
      let is_start' =
        Call_forest.is_empty (Stack_frame.calls local_state.stack_frame)
      in
      ( match is_start with
      | `Compute _ ->
          ()
      | `Yes _ ->
          assert_ ~pos:__POS__ is_start'
      | `No ->
          assert_ ~pos:__POS__ (Bool.not is_start') ) ;
      match is_start with
      | `Yes _ ->
          Bool.true_
      | `No ->
          Bool.false_
      | `Compute _ ->
          is_start'
    in
    let will_succeed =
      match is_start with
      | `Compute start_data ->
          Bool.if_ is_start' ~then_:start_data.will_succeed
            ~else_:local_state.will_succeed
      | `Yes start_data ->
          start_data.will_succeed
      | `No ->
          local_state.will_succeed
    in
    let local_state =
      { local_state with
        ledger =
          Inputs.Ledger.if_ is_start'
            ~then_:(Inputs.Global_state.ledger global_state)
            ~else_:local_state.ledger
      ; will_succeed
      }
    in
    let ( (account_update, remaining, call_stack)
        , account_update_forest
        , local_state
        , (a, inclusion_proof) ) =
      let to_pop, call_stack =
        match is_start with
        | `Compute start_data ->
            ( Stack_frame.if_ is_start'
                ~then_:
                  (Stack_frame.make ~calls:start_data.zkapp_command
                     ~caller:default_caller ~caller_caller:default_caller )
                ~else_:local_state.stack_frame
            , Call_stack.if_ is_start' ~then_:(Call_stack.empty ())
                ~else_:local_state.call_stack )
        | `Yes start_data ->
            ( Stack_frame.make ~calls:start_data.zkapp_command
                ~caller:default_caller ~caller_caller:default_caller
            , Call_stack.empty () )
        | `No ->
            (local_state.stack_frame, local_state.call_stack)
      in
      let { account_update
          ; caller_id
          ; account_update_forest
          ; new_frame = remaining
          ; new_call_stack = call_stack
          } =
        with_label ~label:"get next account update" (fun () ->
            (* TODO: Make the stack frame hashed inside of the local state *)
            get_next_account_update to_pop call_stack )
      in
      let local_state =
        with_label ~label:"token owner not caller" (fun () ->
            let default_token_or_token_owner_was_caller =
              (* Check that the token owner was consulted if using a non-default
                 token *)
              let account_update_token_id =
                Account_update.token_id account_update
              in
              Bool.( ||| )
                (Token_id.equal account_update_token_id Token_id.default)
                (Token_id.equal account_update_token_id caller_id)
            in
            Local_state.add_check local_state Token_owner_not_caller
              default_token_or_token_owner_was_caller )
      in
      let ((a, inclusion_proof) as acct) =
        with_label ~label:"get account" (fun () ->
            Inputs.Ledger.get_account account_update local_state.ledger )
      in
      Inputs.Ledger.check_inclusion local_state.ledger (a, inclusion_proof) ;
      let transaction_commitment, full_transaction_commitment =
        match is_start with
        | `No ->
            ( local_state.transaction_commitment
            , local_state.full_transaction_commitment )
        | `Yes start_data | `Compute start_data ->
            let tx_commitment_on_start =
              Transaction_commitment.commitment
                ~account_updates:(Stack_frame.calls remaining)
            in
            let full_tx_commitment_on_start =
              Transaction_commitment.full_commitment ~account_update
                ~memo_hash:start_data.memo_hash
                ~commitment:tx_commitment_on_start
            in
            let tx_commitment =
              Transaction_commitment.if_ is_start' ~then_:tx_commitment_on_start
                ~else_:local_state.transaction_commitment
            in
            let full_tx_commitment =
              Transaction_commitment.if_ is_start'
                ~then_:full_tx_commitment_on_start
                ~else_:local_state.full_transaction_commitment
            in
            (tx_commitment, full_tx_commitment)
      in
      let local_state =
        { local_state with
          transaction_commitment
        ; full_transaction_commitment
        ; token_id =
            Token_id.if_ is_start' ~then_:Token_id.default
              ~else_:local_state.token_id
        }
      in
      ( (account_update, remaining, call_stack)
      , account_update_forest
      , local_state
      , acct )
    in
    let local_state =
      { local_state with stack_frame = remaining; call_stack }
    in
    let local_state = Local_state.add_new_failure_status_bucket local_state in
    Inputs.Ledger.check_inclusion local_state.ledger (a, inclusion_proof) ;
    (* Register verification key, in case it needs to be 'side-loaded' to
       verify a zkapp proof.
    *)
    Account.register_verification_key a ;
    let (`Is_new account_is_new) =
      Inputs.Ledger.check_account
        (Account_update.public_key account_update)
        (Account_update.token_id account_update)
        (a, inclusion_proof)
    in
    let matching_verification_key_hashes =
      Inputs.Bool.(
        (not (Account_update.is_proved account_update))
        ||| Verification_key_hash.equal
              (Account.verification_key_hash a)
              (Account_update.verification_key_hash account_update))
    in
    let local_state =
      Local_state.add_check local_state Unexpected_verification_key_hash
        matching_verification_key_hashes
    in
    let local_state =
      h.perform
        (Check_account_precondition
           (account_update, a, account_is_new, local_state) )
    in
    let protocol_state_predicate_satisfied =
      h.perform
        (Check_protocol_state_precondition
           ( Account_update.protocol_state_precondition account_update
           , global_state ) )
    in
    let local_state =
      Local_state.add_check local_state Protocol_state_precondition_unsatisfied
        protocol_state_predicate_satisfied
    in
    let local_state =
      let valid_while_satisfied =
        h.perform
          (Check_valid_while_precondition
             ( Account_update.valid_while_precondition account_update
             , global_state ) )
      in
      Local_state.add_check local_state Valid_while_precondition_unsatisfied
        valid_while_satisfied
    in
    let `Proof_verifies proof_verifies, `Signature_verifies signature_verifies =
      let commitment =
        Inputs.Transaction_commitment.if_
          (Inputs.Account_update.use_full_commitment account_update)
          ~then_:local_state.full_transaction_commitment
          ~else_:local_state.transaction_commitment
      in
      Inputs.Account_update.check_authorization
        ~will_succeed:local_state.will_succeed ~commitment
        ~calls:account_update_forest account_update
    in
    assert_ ~pos:__POS__
      (Bool.equal proof_verifies (Account_update.is_proved account_update)) ;
    assert_ ~pos:__POS__
      (Bool.equal signature_verifies (Account_update.is_signed account_update)) ;
    (* The fee-payer must increment their nonce. *)
    let local_state =
      Local_state.add_check local_state Fee_payer_nonce_must_increase
        Inputs.Bool.(
          Inputs.Account_update.increment_nonce account_update ||| not is_start')
    in
    let local_state =
      Local_state.add_check local_state Fee_payer_must_be_signed
        Inputs.Bool.(signature_verifies ||| not is_start')
    in
    let local_state =
      let precondition_has_constant_nonce =
        Inputs.Account_update.Account_precondition.nonce account_update
        |> Inputs.Nonce_precondition.is_constant
      in
      let increments_nonce_and_constrains_its_old_value =
        Inputs.Bool.(
          Inputs.Account_update.increment_nonce account_update
          &&& precondition_has_constant_nonce)
      in
      let depends_on_the_fee_payers_nonce_and_isnt_the_fee_payer =
        Inputs.Bool.(
          Inputs.Account_update.use_full_commitment account_update
          &&& not is_start')
      in
      let does_not_use_a_signature = Inputs.Bool.not signature_verifies in
      Local_state.add_check local_state Zkapp_command_replay_check_failed
        Inputs.Bool.(
          increments_nonce_and_constrains_its_old_value
          ||| depends_on_the_fee_payers_nonce_and_isnt_the_fee_payer
          ||| does_not_use_a_signature)
    in
    let a = Account.set_token_id a (Account_update.token_id account_update) in
    let account_update_token = Account_update.token_id account_update in
    let account_update_token_is_default =
      Token_id.(equal default) account_update_token
    in
    let account_is_untimed = Bool.not (Account.is_timed a) in
    (* Set account timing. *)
    let a, local_state =
      let timing = Account_update.Update.timing account_update in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_timing a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_timing
          Bool.(
            Set_or_keep.is_keep timing
            ||| (account_is_untimed &&& has_permission))
      in
      let timing =
        Set_or_keep.set_or_keep ~if_:Timing.if_ timing (Account.timing a)
      in
      let vesting_period = Timing.vesting_period timing in
      (* Assert that timing is valid, otherwise we may have a division by 0. *)
      assert_ ~pos:__POS__ Global_slot.(vesting_period > zero) ;
      let a = Account.set_timing a timing in
      (a, local_state)
    in
    let account_creation_fee =
      Amount.of_constant_fee constraint_constants.account_creation_fee
    in
    let implicit_account_creation_fee =
      Account_update.implicit_account_creation_fee account_update
    in
    (* Check the token for implicit account creation fee payment. *)
    let local_state =
      Local_state.add_check local_state Cannot_pay_creation_fee_in_token
        Bool.(
          (not implicit_account_creation_fee)
          ||| account_update_token_is_default)
    in
    (* Compute the change to the account balance. *)
    let local_state, actual_balance_change =
      let balance_change = Account_update.balance_change account_update in
      let neg_creation_fee =
        let open Amount.Signed in
        negate (of_unsigned account_creation_fee)
      in
      let balance_change_for_creation, `Overflow creation_overflow =
        let open Amount.Signed in
        add_flagged balance_change neg_creation_fee
      in
      let pay_creation_fee =
        Bool.(account_is_new &&& implicit_account_creation_fee)
      in
      let creation_overflow = Bool.(pay_creation_fee &&& creation_overflow) in
      let balance_change =
        Amount.Signed.if_ pay_creation_fee ~then_:balance_change_for_creation
          ~else_:balance_change
      in
      let local_state =
        Local_state.add_check local_state Amount_insufficient_to_create_account
          Bool.(
            not
              ( pay_creation_fee
              &&& (creation_overflow ||| Amount.Signed.is_neg balance_change) ))
      in
      (local_state, balance_change)
    in
    (* Apply balance change. *)
    let a, local_state =
      let pay_creation_fee_from_excess =
        Bool.(account_is_new &&& not implicit_account_creation_fee)
      in
      let balance, `Overflow failed1 =
        Balance.add_signed_amount_flagged (Account.balance a)
          actual_balance_change
      in
      (* TODO: Should this report 'insufficient balance'? *)
      let local_state =
        Local_state.add_check local_state Overflow (Bool.not failed1)
      in
      let account_creation_fee =
        Amount.of_constant_fee constraint_constants.account_creation_fee
      in
      let local_state =
        (* Conditionally subtract account creation fee from fee excess *)
        let excess_minus_creation_fee, `Overflow excess_update_failed =
          Amount.Signed.add_flagged local_state.excess
            Amount.Signed.(negate (of_unsigned account_creation_fee))
        in
        let local_state =
          Local_state.add_check local_state Local_excess_overflow
            Bool.(not (pay_creation_fee_from_excess &&& excess_update_failed))
        in
        { local_state with
          excess =
            Amount.Signed.if_ pay_creation_fee_from_excess
              ~then_:excess_minus_creation_fee ~else_:local_state.excess
        }
      in
      let local_state =
        (* Conditionally subtract account creation fee from supply increase *)
        let ( supply_increase_minus_creation_fee
            , `Overflow supply_increase_update_failed ) =
          Amount.Signed.add_flagged local_state.supply_increase
            Amount.Signed.(negate (of_unsigned account_creation_fee))
        in
        let local_state =
          Local_state.add_check local_state Local_supply_increase_overflow
            Bool.(not (account_is_new &&& supply_increase_update_failed))
        in
        { local_state with
          supply_increase =
            Amount.Signed.if_ account_is_new
              ~then_:supply_increase_minus_creation_fee
              ~else_:local_state.supply_increase
        }
      in
      let is_receiver = Amount.Signed.is_pos actual_balance_change in
      let local_state =
        let controller =
          Controller.if_ is_receiver
            ~then_:(Account.Permissions.receive a)
            ~else_:(Account.Permissions.send a)
        in
        let has_permission =
          Controller.check ~proof_verifies ~signature_verifies controller
        in
        Local_state.add_check local_state Update_not_permitted_balance
          Bool.(
            has_permission
            ||| Amount.Signed.(
                  equal (of_unsigned Amount.zero) actual_balance_change))
      in
      let a = Account.set_balance balance a in
      (a, local_state)
    in
    let txn_global_slot = Global_state.block_global_slot global_state in
    (* Check timing with current balance *)
    let a, local_state =
      let `Invalid_timing invalid_timing, timing =
        match Account.check_timing ~txn_global_slot a with
        | `Insufficient_balance _, _ ->
            failwith "Did not propose a balance change at this timing check!"
        | `Invalid_timing invalid_timing, timing ->
            (* NB: Have to destructure to remove the possibility of
               [`Insufficient_balance _] in the type.
            *)
            (`Invalid_timing invalid_timing, timing)
      in
      let local_state =
        Local_state.add_check local_state Source_minimum_balance_violation
          (Bool.not invalid_timing)
      in
      let a = Account.set_timing a timing in
      (a, local_state)
    in
    (* Transform into a zkApp account.
       This must be done before updating zkApp fields!
    *)
    let a = Account.make_zkapp a in
    (* Check that the account can be accessed with the given authorization. *)
    let local_state =
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.access a)
      in
      Local_state.add_check local_state Update_not_permitted_access
        has_permission
    in
    (* Update app state. *)
    let a, local_state =
      let app_state = Account_update.Update.app_state account_update in
      let keeping_app_state =
        Bool.all
          (List.map ~f:Set_or_keep.is_keep
             (Pickles_types.Vector.to_list app_state) )
      in
      let changing_entire_app_state =
        Bool.all
          (List.map ~f:Set_or_keep.is_set
             (Pickles_types.Vector.to_list app_state) )
      in
      let proved_state =
        (* The [proved_state] tracks whether the app state has been entirely
           determined by proofs ([true] if so), to allow zkApp authors to be
           confident that their initialization logic has been run, rather than
           some malicious deployer instantiating the zkApp in an account with
           some fake non-initial state.
           The logic here is:
           * if the state is unchanged, keep the previous value;
           * if the state has been entirely replaced, and the authentication
             was a proof, the state has been 'proved' and [proved_state] is set
             to [true];
           * if the state has been partially updated by a proof, the
             [proved_state] is unchanged;
           * if the state has been changed by some authentication other than a
             proof, the state is considered to have been tampered with, and
             [proved_state] is reset to [false].
        *)
        Bool.if_ keeping_app_state ~then_:(Account.proved_state a)
          ~else_:
            (Bool.if_ proof_verifies
               ~then_:
                 (Bool.if_ changing_entire_app_state ~then_:Bool.true_
                    ~else_:(Account.proved_state a) )
               ~else_:Bool.false_ )
      in
      let a = Account.set_proved_state proved_state a in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.edit_state a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_app_state
          Bool.(keeping_app_state ||| has_permission)
      in
      let app_state =
        Pickles_types.Vector.map2 app_state (Account.app_state a)
          ~f:(Set_or_keep.set_or_keep ~if_:Field.if_)
      in
      let a = Account.set_app_state app_state a in
      (a, local_state)
    in
    (* Set verification key. *)
    let a, local_state =
      let verification_key =
        Account_update.Update.verification_key account_update
      in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_verification_key a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_verification_key
          Bool.(Set_or_keep.is_keep verification_key ||| has_permission)
      in
      let verification_key =
        Set_or_keep.set_or_keep ~if_:Verification_key.if_ verification_key
          (Account.verification_key a)
      in
      let a = Account.set_verification_key verification_key a in
      (a, local_state)
    in
    (* Update sequence state. *)
    let a, local_state =
      let actions = Account_update.Update.actions account_update in
      let last_sequence_slot = Account.last_sequence_slot a in
      let sequence_state, last_sequence_slot =
        update_sequence_state (Account.sequence_state a) actions
          ~txn_global_slot ~last_sequence_slot
      in
      let is_empty =
        (* also computed in update_sequence_state, but messy to return it *)
        Actions.is_empty actions
      in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.edit_sequence_state a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_sequence_state
          Bool.(is_empty ||| has_permission)
      in
      let a =
        a
        |> Account.set_sequence_state sequence_state
        |> Account.set_last_sequence_slot last_sequence_slot
      in
      (a, local_state)
    in
    (* Reset zkApp state to [None] if it is unmodified. *)
    let a = Account.unmake_zkapp a in
    (* Update zkApp URI. *)
    let a, local_state =
      let zkapp_uri = Account_update.Update.zkapp_uri account_update in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_zkapp_uri a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_zkapp_uri
          Bool.(Set_or_keep.is_keep zkapp_uri ||| has_permission)
      in
      let zkapp_uri =
        Set_or_keep.set_or_keep ~if_:Zkapp_uri.if_ zkapp_uri
          (Account.zkapp_uri a)
      in
      let a = Account.set_zkapp_uri zkapp_uri a in
      (a, local_state)
    in
    (* Update token symbol. *)
    let a, local_state =
      let token_symbol = Account_update.Update.token_symbol account_update in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_token_symbol a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_token_symbol
          Bool.(Set_or_keep.is_keep token_symbol ||| has_permission)
      in
      let token_symbol =
        Set_or_keep.set_or_keep ~if_:Token_symbol.if_ token_symbol
          (Account.token_symbol a)
      in
      let a = Account.set_token_symbol token_symbol a in
      (a, local_state)
    in
    (* Update delegate. *)
    let a, local_state =
      let delegate = Account_update.Update.delegate account_update in
      let base_delegate =
        let should_set_new_account_delegate =
          (* Only accounts for the default token may delegate. *)
          Bool.(account_is_new &&& account_update_token_is_default)
        in
        (* New accounts should have the delegate equal to the public key of the
           account.
        *)
        Public_key.if_ should_set_new_account_delegate
          ~then_:(Account_update.public_key account_update)
          ~else_:(Account.delegate a)
      in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_delegate a)
      in
      let local_state =
        (* Note: only accounts for the default token can delegate. *)
        Local_state.add_check local_state Update_not_permitted_delegate
          Bool.(
            Set_or_keep.is_keep delegate
            ||| (has_permission &&& account_update_token_is_default))
      in
      let delegate =
        Set_or_keep.set_or_keep ~if_:Public_key.if_ delegate base_delegate
      in
      let a = Account.set_delegate delegate a in
      (a, local_state)
    in
    (* Update nonce. *)
    let a, local_state =
      let nonce = Account.nonce a in
      let increment_nonce = Account_update.increment_nonce account_update in
      let nonce =
        Nonce.if_ increment_nonce ~then_:(Nonce.succ nonce) ~else_:nonce
      in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.increment_nonce a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_nonce
          Bool.((not increment_nonce) ||| has_permission)
      in
      let a = Account.set_nonce nonce a in
      (a, local_state)
    in
    (* Update voting-for. *)
    let a, local_state =
      let voting_for = Account_update.Update.voting_for account_update in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_voting_for a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_voting_for
          Bool.(Set_or_keep.is_keep voting_for ||| has_permission)
      in
      let voting_for =
        Set_or_keep.set_or_keep ~if_:State_hash.if_ voting_for
          (Account.voting_for a)
      in
      let a = Account.set_voting_for voting_for a in
      (a, local_state)
    in
    (* Update receipt chain hash *)
    let a =
      let new_hash =
        let old_hash = Account.receipt_chain_hash a in
        Receipt_chain_hash.if_
          (let open Inputs.Bool in
          signature_verifies ||| proof_verifies)
          ~then_:
            (let elt =
               local_state.full_transaction_commitment
               |> Receipt_chain_hash.Elt.of_transaction_commitment
             in
             Receipt_chain_hash.cons_zkapp_command_commitment
               local_state.account_update_index elt old_hash )
          ~else_:old_hash
      in
      Account.set_receipt_chain_hash a new_hash
    in
    (* Finally, update permissions.
       This should be the last update applied, to ensure that any earlier
       updates use the account's existing permissions, and not permissions that
       are specified by the account_update!
    *)
    let a, local_state =
      let permissions = Account_update.Update.permissions account_update in
      let has_permission =
        Controller.check ~proof_verifies ~signature_verifies
          (Account.Permissions.set_permissions a)
      in
      let local_state =
        Local_state.add_check local_state Update_not_permitted_permissions
          Bool.(Set_or_keep.is_keep permissions ||| has_permission)
      in
      let permissions =
        Set_or_keep.set_or_keep ~if_:Account.Permissions.if_ permissions
          (Account.permissions a)
      in
      let a = Account.set_permissions permissions a in
      (a, local_state)
    in
    (* Initialize account's pk, in case it is new. *)
    let a = h.perform (Init_account { account_update; account = a }) in
    (* DO NOT ADD ANY UPDATES HERE. They must be earlier in the code.
       See comment above.
    *)
    let local_delta =
      (* NOTE: It is *not* correct to use the actual change in balance here.
         Indeed, if the account creation fee is paid, using that amount would
         be equivalent to paying it out to the block producer.
         In the case of a failure that prevents any updates from being applied,
         every other account_update in this transaction will also fail, and the
         excess will never be promoted to the global excess, so this amount is
         irrelevant.
      *)
      Amount.Signed.negate (Account_update.balance_change account_update)
    in
    let new_local_fee_excess, `Overflow overflowed =
      let curr_token : Token_id.t = local_state.token_id in
      let curr_is_default = Token_id.(equal default) curr_token in
      (* We only allow the default token for fees. *)
      assert_ ~pos:__POS__ curr_is_default ;
      Bool.(
        assert_ ~pos:__POS__
          ( (not is_start')
          ||| ( account_update_token_is_default
              &&& Amount.Signed.is_pos local_delta ) )) ;
      let new_local_fee_excess, `Overflow overflow =
        Amount.Signed.add_flagged local_state.excess local_delta
      in
      ( Amount.Signed.if_ account_update_token_is_default
          ~then_:new_local_fee_excess ~else_:local_state.excess
      , (* No overflow if we aren't using the result of the addition (which we don't in the case that account_update token is not default). *)
        `Overflow (Bool.( &&& ) account_update_token_is_default overflow) )
    in
    let local_state = { local_state with excess = new_local_fee_excess } in
    let local_state =
      Local_state.add_check local_state Local_excess_overflow
        (Bool.not overflowed)
    in
    (* If a's token ID differs from that in the local state, then
       the local state excess gets moved into the execution state's fee excess.

       If there are more zkapp_command to execute after this one, then the local delta gets
       accumulated in the local state.

       If there are no more zkapp_command to execute, then we do the same as if we switch tokens.
       The local state excess (plus the local delta) gets moved to the fee excess if it is default token.
    *)
    let new_ledger =
      Inputs.Ledger.set_account local_state.ledger (a, inclusion_proof)
    in
    let is_last_account_update =
      Call_forest.is_empty (Stack_frame.calls remaining)
    in
    let local_state =
      { local_state with
        ledger = new_ledger
      ; transaction_commitment =
          Transaction_commitment.if_ is_last_account_update
            ~then_:Transaction_commitment.empty
            ~else_:local_state.transaction_commitment
      ; full_transaction_commitment =
          Transaction_commitment.if_ is_last_account_update
            ~then_:Transaction_commitment.empty
            ~else_:local_state.full_transaction_commitment
      }
    in
    let valid_fee_excess =
      let delta_settled =
        Amount.Signed.equal local_state.excess Amount.(Signed.of_unsigned zero)
      in
      (* 1) ignore local excess if it is_start because it will be promoted to global
             excess and then set to zero later in the code
         2) ignore everything but last account update since the excess wouldn't have
            been settled
         3) Excess should be settled after the last account update has been applied.
      *)
      Bool.(is_start' ||| not is_last_account_update ||| delta_settled)
    in
    let local_state =
      Local_state.add_check local_state Invalid_fee_excess valid_fee_excess
    in
    let is_start_or_last = Bool.(is_start' ||| is_last_account_update) in
    let update_global_state = Bool.(is_start_or_last &&& local_state.success) in
    let global_state, global_excess_update_failed, update_global_state =
      let amt = Global_state.fee_excess global_state in
      let res, `Overflow overflow =
        Amount.Signed.add_flagged amt local_state.excess
      in
      let global_excess_update_failed =
        Bool.(update_global_state &&& overflow)
      in
      let update_global_state = Bool.(update_global_state &&& not overflow) in
      let new_amt =
        Amount.Signed.if_ update_global_state ~then_:res ~else_:amt
      in
      ( Global_state.set_fee_excess global_state new_amt
      , global_excess_update_failed
      , update_global_state )
    in
    let local_state =
      { local_state with
        excess =
          Amount.Signed.if_ is_start_or_last
            ~then_:Amount.(Signed.of_unsigned zero)
            ~else_:local_state.excess
      }
    in
    let local_state =
      Local_state.add_check local_state Global_excess_overflow
        Bool.(not global_excess_update_failed)
    in
    (* add local supply increase in global state *)
    let new_global_supply_increase, global_supply_increase_update_failed =
      let res, `Overflow overflow =
        Amount.Signed.add_flagged
          (Global_state.supply_increase global_state)
          local_state.supply_increase
      in
      (res, overflow)
    in
    let local_state =
      Local_state.add_check local_state Global_supply_increase_overflow
        Bool.(not global_supply_increase_update_failed)
    in
    let global_state =
      Global_state.set_supply_increase global_state
        (Amount.Signed.if_
           Bool.(is_last_account_update &&& local_state.success)
           ~then_:new_global_supply_increase
           ~else_:(Global_state.supply_increase global_state) )
    in
    (* The first account_update must succeed. *)
    Bool.(
      assert_with_failure_status_tbl ~pos:__POS__
        ((not is_start') ||| local_state.success)
        local_state.failure_status_tbl) ;
    (* If this is the last account update, and [will_succeed] is false, then
       [success] must also be false.
    *)
    Bool.(
      Assert.any ~pos:__POS__
        [ not is_last_account_update
        ; local_state.will_succeed
        ; not local_state.success
        ]) ;
    let global_state =
      Global_state.set_ledger ~should_update:update_global_state global_state
        local_state.ledger
    in
    let local_state =
      (* Make sure to reset the local_state at the end of a transaction.
         The following fields are already reset
         - zkapp_command
         - transaction_commitment
         - full_transaction_commitment
         - excess
         so we need to reset
         - token_id = Token_id.default
         - ledger = Frozen_ledger_hash.empty_hash
         - success = true
         - account_update_index = Index.zero
         - supply_increase = Amount.Signed.zero
      *)
      { local_state with
        token_id =
          Token_id.if_ is_last_account_update ~then_:Token_id.default
            ~else_:local_state.token_id
      ; ledger =
          Inputs.Ledger.if_ is_last_account_update
            ~then_:
              (Inputs.Ledger.empty ~depth:constraint_constants.ledger_depth ())
            ~else_:local_state.ledger
      ; success =
          Bool.if_ is_last_account_update ~then_:Bool.true_
            ~else_:local_state.success
      ; account_update_index =
          Inputs.Index.if_ is_last_account_update ~then_:Inputs.Index.zero
            ~else_:(Inputs.Index.succ local_state.account_update_index)
      ; supply_increase =
          Amount.Signed.if_ is_last_account_update
            ~then_:Amount.(Signed.of_unsigned zero)
            ~else_:local_state.supply_increase
      ; will_succeed =
          Bool.if_ is_last_account_update ~then_:Bool.true_
            ~else_:local_state.will_succeed
      }
    in
    (global_state, local_state)

  let step h state = apply ~is_start:`No h state

  let start start_data h state = apply ~is_start:(`Yes start_data) h state
end
