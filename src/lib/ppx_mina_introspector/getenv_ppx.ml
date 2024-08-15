open Ppxlib

let transform_all_items item =
  (* Your transformation logic here *)
  print_endline "DEBUG ITEM transform_all_items";
  item

let () =
  Driver.register_transformation 
    ~impl:transform_all_items
    ~intf:transform_all_items
    "my_transformation"

