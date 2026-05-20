{ exec, ... }:
{
  importEncrypted = identities: path:
    exec (
      [ "age" "--decrypt" ]
      ++ builtins.concatMap (id: [ "--identity" (builtins.toString id) ]) identities
      ++ [ (builtins.toString path) ]
    );
}
