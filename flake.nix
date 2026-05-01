{
  description = "Dot Exts";

  outputs = { self }:
    let
      # 这里的 pkgs = { } 仅用于获取静态的模块定义。
      # 因为模块内部使用的是评估时注入的 pkgs，所以此处传入空对象是安全的。
      exts = import ./default.nix { pkgs = { }; };
    in
    {
      inherit (exts) nixosModules;

      # 暴露一个库函数，允许外部用户显式注入特定的 pkgs
      lib = {
        withPkgs = pkgs: import ./default.nix { inherit pkgs; };
      };
    };
}
