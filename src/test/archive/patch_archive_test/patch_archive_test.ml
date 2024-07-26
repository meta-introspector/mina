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
    ; replayer_input_file: String.t
    ; folder: String.t
  }

  let create folder = 
    {
      init_script = "archive_db.sql"
      ; genesis_ledger_file = "input.json"
      ; precomputed_blocks_zip = "precomputed_blocks.zip"
      ; replayer_input_file = "replayer_input_file.json"
      ; folder 
    }

end 

open Core_kernel
open Async
open Mina_automation

let main ~db_uri ~network_data_folder () =
  let open Deferred.Let_syntax in
  let _logger = Logger.create () in

  
  let network_data = Network_Data.create network_data_folder in 

  (**let%bind (_) = Integration_test_lib.Util.run_cmd_exn 
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
  )**)
  
  let output_folder = Filename.temp_dir_name ^ "/output" in

  let%bind output_folder = Unix.mkdtemp output_folder in

  let extract_blocks = Extract_blocks.of_context Executor.AutoDetect in
  let config = {
    Extract_blocks.Config.archive_uri= db_uri;
    range = Extract_blocks.Config.AllBlocks;
    output_folder = Some output_folder;
    network = Some "dummy";
    include_block_height_in_name = true

  }
  in
  let%bind (_) = Extract_blocks.run extract_blocks ~config in 
  
  let archive_blocks = Archive_blocks.of_context Executor.AutoDetect in
   
  let%bind extensional_files = Sys.ls_dir output_folder >>= Deferred.List.map ~f:(fun e -> Deferred.return (output_folder ^ "/" ^ e) ) in

  let n = List.range 0 3 |> List.map ~f:(fun _ -> 
    Random.int (List.length extensional_files)
  ) in
  
  let unpatched_extensional_files = List.filteri extensional_files ~f:(fun i _ ->
      not (List.mem n i ~equal:Int.equal)
  ) |> List.dedup_and_sort ~compare:(fun left right -> 

      let scan_height = fun item -> 
        let item = Filename.basename item |> Str.global_replace  (Str.regexp "-") " " in
        Scanf.sscanf item "%s %d %s" (fun _ height _ -> height) in 

        let left_height = scan_height left in
        let right_height = scan_height right in

      Int.compare left_height right_height
    ) in

  let broken_db = "postgres://postgres:postgres@localhost:5432" in
  let connection = Psql.Conn_str broken_db in

  let%bind (_) = Psql.create_mainnet_db ~connection ~name:"sample_db_new" ~working_dir:"." in

  let broken_db = "postgres://postgres:postgres@localhost:5432/sample_db_new" in
  
  let%bind (_) = Archive_blocks.run archive_blocks ~blocks:unpatched_extensional_files ~archive_uri:broken_db ~format:Extensional in

  let%bind missing_blocks_auditor_path =  Missing_blocks_auditor.of_context Executor.AutoDetect |> Missing_blocks_auditor.path in
  
  let%bind archive_blocks_path =  Archive_blocks.path archive_blocks in

  let config = {
    Missing_blocks_guardian.Config.archive_uri = Uri.of_string broken_db
    ; precomputed_blocks = Uri.make ~scheme:"file" ~path:output_folder ()
    ; network= "dummy"
    ; run_mode = Run
    ; missing_blocks_auditor = missing_blocks_auditor_path
    ; archive_blocks= archive_blocks_path
    ; block_format = Extensional
  } in

  let missing_blocks_guardian = Missing_blocks_guardian.of_context Executor.AutoDetect in

  let%bind (_) = Missing_blocks_guardian.run missing_blocks_guardian ~config in

  let replayer = Replayer.of_context Executor.AutoDetect in 
  
  let%bind (_) = Replayer.run  replayer ~archive_uri:broken_db ~input_config:(network_data.folder ^ "/" ^ network_data.replayer_input_file)
  ~interval_checkpoint:10 ~output_ledger:"./output_ledger" () in


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
