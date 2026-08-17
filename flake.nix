{
  description = "Dot Exts";

  outputs = { self }:
    let
      exts = import ./default.nix { };
    in
    {
      inherit (exts) nixosModules;

      # 暴露一个库函数，允许外部用户显式注入特定的 pkgs
      lib = {
        withPkgs = pkgs: import ./default.nix { inherit pkgs; };
      };
    };
}
