{ lib, ... }: {
  options.exts.testMode = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable test mode to disable partition configurations";
  };
}
