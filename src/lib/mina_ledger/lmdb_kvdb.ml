(* open Merkle_ledger *)
open Core_kernel

module Kvdb = struct
      type t =
        { mutable lmdb : ((Bigstring.t,Bigstring.t,[ `Uni ]) Lmdb.Map.t [@sexp.opaque])
        ; path : string
        ; uuid : Uuid.t
        }
      [@@deriving sexp]

      let trivial_conv : Bigstring.t Lmdb.Conv.t = Lmdb.Conv.make ~serialise:(Fn.const Fn.id) ~deserialise:Fn.id ()
      (* TODO is this good enough? what other data can I use to make it more trustably unique? *)
      let name_to_uuid name = String.to_array name
                  |> Array.map ~f:Char.to_int
                  |> Random.State.make
                  |> Uuid.create_random


      let create (conf : string) = let
        lmdb =
        Lmdb.Map.create
        Nodup
        (Lmdb.Env.create Rw conf)
        ~key:trivial_conv
        ~value:trivial_conv
      in { lmdb
         ; path = conf
         ; uuid = name_to_uuid conf
         }

      let close t = Lmdb.Env.close (Lmdb.Map.env t.lmdb)

      let create_checkpoint t name =
      let env = Lmdb.Map.env t.lmdb in
        close t;
        (* TODO coppy the file here *)
        t.lmdb <- Lmdb.Map.open_existing Nodup ~key:trivial_conv ~value:trivial_conv env;
        let new_db = Lmdb.Map.open_existing Nodup ~key:trivial_conv ~value:trivial_conv (Lmdb.Env.create Ro name) in
        { lmdb = new_db
        ; path = name
        ; uuid = name_to_uuid name
          (* Can this be the same, if not what can I use instead of the path? *)
        }

      (* AFAICT this can be a no-op because it doesn't return a handle so why copy? *)
      let make_checkpoint _t _name = ()

      let get t ~key = try Some(Lmdb.Map.get t.lmdb key) with
          | Not_found_s _ -> None
          (* | Not_found -> None *)
          (* TODO does Not_found_s subsume Not_found ? if not how do I get the compiler to let me do this? *)


      let set t ~key ~data = Lmdb.Map.set t.lmdb key data

      let get_batch t ~keys = List.map keys ~f:(fun key -> get t ~key)

      let remove t ~key = Lmdb.Map.remove t.lmdb key
      (* TODO LMDB raises Not_found here if the keys doesn't exist,
         make sure that's the same as rocksdb *)

      let set_batch t ?(remove_keys = []) ~key_data_pairs =
        List.iter remove_keys ~f:(fun key -> remove t ~key);
        List.iter key_data_pairs ~f:(fun (key , data) ->  set t ~key ~data )

      let to_alist t =
        Lmdb.Cursor.fold_left ~f:(fun xs k v -> List.cons (k,v) xs ) [] t.lmdb
        (* TODO this feels like a bad idea performance wise *)

      let foldi t ~init ~f = snd @@
        Lmdb.Cursor.fold_left
        ~f:(fun (i,a) key value -> (i+1,f i a ~key ~data:value))
        (0,init)
        t.lmdb

      let fold_until t ~init ~f ~finish =
        Lmdb.Cursor.go Ro t.lmdb
            Lmdb.Cursor.(fun cursor ->
              let entry : Bigstring.t * Bigstring.t = first cursor in
              let rec handle acc (k,v) = match f acc ~key:k ~data:v with
                | Continue_or_stop.Continue acc_new ->
                   begin match next cursor with
                      | exception Not_found_s _ -> finish acc_new
                      | ent -> handle acc_new ent
                   end
                | Continue_or_stop.Stop res -> res
              in
              handle init entry
            )

      let get_uuid t = t.uuid
end
