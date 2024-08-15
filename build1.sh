
for x in    -no-alias-deps    -dunique-ids  -dlocations    -dsource    -dparsetree   -dtypedtree   -dshape    -drawlambda   -dlambda   -dinstr    -dcamlprimc    -verbose -labels -keep-locs -keep-docs  -dtypes -bin-annot;
do echo $x;
   /nix/store/12025gwcvnhg66dh6v6974viyq1b28ki-ocaml-base-compiler-4.14.0/bin/ocamlc.opt src/lib/snarky/h_list/h_list.ml $x
done
# -annot
# -i
