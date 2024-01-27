(** Batch of Polynomial Commitment Scheme *)

type ('a, 'n, 'm) t

val pow : one:'f -> mul:('f -> 'f -> 'f) -> 'f -> int -> 'f

val num_bits : int -> int

val create : without_degree_bound:'n Nat.t -> ('a, 'n, 'm) t

val combine_commitments :
     (int, 'n, 'm) t
  -> scale:('g -> 'f -> 'g)
  -> add:('g -> 'g -> 'g)
  -> xi:'f
  -> ('g, 'n) Vector.t
  -> 'g

val combine_evaluations' :
     ('a, 'n, 'm) t
  -> mul:('f -> 'f -> 'f)
  -> add:('f -> 'f -> 'f)
  -> one:'f
  -> xi:'f
  -> ('f, 'n) Vector.t
  -> 'f

val combine_evaluations :
     (int, 'n, 'm) t
  -> mul:('f -> 'f -> 'f)
  -> add:('f -> 'f -> 'f)
  -> one:'f
  -> xi:'f
  -> ('f, 'n) Vector.t
  -> 'f

val combine_split_commitments :
     (_, 'n, 'm) t
  -> scale_and_add:(acc:'g_acc -> xi:'f -> 'g -> 'g_acc)
  -> init:('g -> 'g_acc option)
  -> xi:'f
  -> reduce_without_degree_bound:('without_degree_bound -> 'g list)
  -> ('without_degree_bound, 'n) Vector.t
  -> 'g_acc

val combine_split_evaluations :
     mul_and_add:(acc:'f_ -> xi:'f_ -> 'f -> 'f_)
  -> init:('f -> 'f_)
  -> xi:'f_
  -> 'f array list
  -> 'f_
