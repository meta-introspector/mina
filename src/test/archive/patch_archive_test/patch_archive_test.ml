(* patch_archive_test.ml *)

(* test patching of archive databases

   test structure:
    - import reference database for comparision (for example with 100 blocks)
    - create new schema and export blocks from reference db with some missing ones
    - patch the database with missing precomputed blocks
    - compare original and copy
*)

module Network_Data = struct
  
  type t = { init_script: String.t 
    ; precomputed_blocks_zip: String.t
    ; genesis_ledger_file: String.t
    ; folder: String.t
  }

  let create folder = 
    {
      init_script = "archive_db.sql"
      ; genesis_ledger_file = "input.json"
      ; precomputed_blocks_zip = "precomputed_blocks.zip"
      ; folder 
    }

end 

open Core_kernel
open Async
open Mina_automation

let main ~db_uri ~network_data_folder () =
  let open Deferred.Let_syntax in
  let logger = Logger.create () in
  let archive_uri = db_uri in
  
  let network_data = Network_Data.create network_data_folder in 

  let%bind (_) = Integration_test_lib.Util.run_cmd_exn 
    "." "unzip" [
      "-oqq";
      Printf.sprintf "%s/%s" network_data_folder network_data.precomputed_blocks_zip ; 
      "-d";
      Printf.sprintf "%s" network_data_folder ] () 
  in
  
  let%bind precomputed_blocks = Precomputed_block.list_directory ~network:"mainnet" ~path:network_data_folder in

  [%log info] "precomputed blocks" ~metadata:[("count", `Int (Set.length precomputed_blocks))];

  let blocks = precomputed_blocks |> Set.to_list |> List.map ~f:(fun id ->
    Printf.sprintf "%s/%s" network_data_folder (Precomputed_block.Id.filename ~network:"mainnet" id)
  )
  
  in
  let archive_blocks = Archive_blocks.of_context Executor.AutoDetect in
  let%bind (_) = Archive_blocks.run archive_blocks ~blocks ~archive_uri in
  Deferred.unit
  

let () =
  Command.(
    run
      (let open Let_syntax in
      async ~summary:"Test patching of blocks in an archive database"
        (let%map db_uri =
           Param.flag "--source-uri"
             ~doc:
               "URI URI for connecting to the database (e.g., \
                postgres://$USER@localhost:5432)"
             Param.(required string)
        and network_data_folder =
           Param.(
             flag "--network-data-folder" ~aliases:[ "network-data-folder" ]
               Param.(required string))
             ~doc:
               "Path Path to folder containing network data. Usually it's sql for db import, \
               genesis ledger and zipped precomputed blocks archive"
         in
         main ~db_uri ~network_data_folder
        )
      )
    )
