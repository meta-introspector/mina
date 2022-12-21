open Mina_base
open Core_kernel
open Bit_catchup_state

include module type of Verifying_generic_types

module Make : functor (F : F) -> sig
  (** Collect transitions that are either in [Substate.Processing Substate.Dependent]
      or in [Substate.Failed] statuses and set [baton] to [true] for the next
      ancestor in [Substate.Processing (Substate.In_progress _)] status.
      
      Traversal starts with a transition represented by its state and the state is also
      included into result (or has [baton] set to [true]) if it satisfies the conditions.
        
      Function does nothing and returns [[]] if [F.to_data] returns [Nothing] on provided state.
      *)
  val collect_dependent_and_pass_the_baton :
       logger:Logger.t
    -> transition_states:Transition_states.t
    -> dsu:Processed_skipping.Dsu.t
    -> Transition_state.t
    -> Transition_state.t list

  (** Collect transitions that are either in [Substate.Processing Substate.Dependent]
      or in [Substate.Failed] statuses and set [baton] to [true] for the next
      ancestor in [Substate.Processing (Substate.In_progress _)] status.
      
      Traversal starts with a transition represented by its state hash and the state is also
      included into result (or has [baton] set to [true]) if it satisfies the conditions.
        
      Function does nothing and returns [[]] if [F.to_data] returns [Nothing] on provided state.
      *)
  val collect_dependent_and_pass_the_baton_by_hash :
       logger:Logger.t
    -> dsu:Processed_skipping.Dsu.t
    -> transition_states:Transition_states.t
    -> State_hash.t
    -> Transition_state.t list

  (** Update status to [Substate.Processing (Substate.Done _)]. 
      
      If [reuse_ctx] is [true], if there is an [Substate.In_progress] context and
      there is an unprocessed ancestor covered by this active progress, action won't
      be interrupted and it will be assigned to the first unprocessed ancestor.

      If [baton] is set to [true] in the transition being updated the baton will be
      passed to the next transition with [Substate.Processing (Substate.In_progress _)]
      and transitions in between will get restarted.  *)
  val update_to_processing_done :
       logger:Logger.t
    -> transition_states:Transition_states.t
    -> state_hash:State_hash.t
    -> dsu:Processed_skipping.Dsu.t
    -> ?reuse_ctx:bool
    -> F.processing_result
    -> Transition_state.t list option

  (** Update status to [Substate.Failed].

      If [baton] is set to [true] in the transition being updated the baton
      will be passed to the next transition with
      [Substate.Processing (Substate.In_progress _)] and transitions in between will
      get restarted.  *)
  val update_to_failed :
       logger:Logger.t
    -> transition_states:Transition_states.t
    -> state_hash:State_hash.t
    -> dsu:Processed_skipping.Dsu.t
    -> Error.t
    -> Transition_state.t list option

  val start :
       context:(module Context.CONTEXT)
    -> actions:Misc.actions Async_kernel.Deferred.t
    -> transition_states:Transition_states.t
    -> Transition_state.t list
    -> unit

  val launch_in_progress :
       context:(module Context.CONTEXT)
    -> actions:Misc.actions Async_kernel.Deferred.t
    -> transition_states:Transition_states.t
    -> Transition_state.t Mina_stdlib.Nonempty_list.t
    -> F.processing_result Substate.processing_context
end