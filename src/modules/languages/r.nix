{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.languages.r;
  inherit (builtins)
    concatMap
    filter
    head
    isNull
    isString
    match
    readFile
    replaceStrings
    split
    toPath
    ;
  # matches :: string -> string -> bool
  matches = pattern: text: !isNull (match "(${pattern})" text);
  # extractWithRegex :: string -> string -> string
  extractWithRegex =
    regex: string:
    let
      matched = match regex string;
    in
    if isNull matched then "" else head matched;
  # splitWithRegex :: string -> string -> [string]
  splitWithRegex = regex: string: filter isString (split regex string);

  getSection =
    section: descriptionFile:
    extractWithRegex ".*${section}:\n +([a-zA-Z0-9., (>=)\n]*)\n[A-Z].*" descriptionFile;
  filterPackages = packages: filter (matches "^[a-zA-Z0-9.]+") packages;
  extractSectionPackages = section: filterPackages (splitWithRegex "[\n, ]+" section);
  normalizePackageName = pkg: replaceStrings [ "." ] [ "_" ] pkg;
  descriptionPackages =
    descriptionFile:
    concatMap (section: extractSectionPackages (getSection section descriptionFile)) [
      "Imports"
      "Depends"
      "Suggests"
    ];
  getRPackages =
    pkgs: descriptionFile:
    map (pkg: pkgs.rPackages.${normalizePackageName pkg}) (descriptionPackages descriptionFile);
in
{
  options.languages.r = {
    enable = lib.mkEnableOption "tools for R development";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.R;
      defaultText = lib.literalExpression "pkgs.R";
      description = "The R package to use.";
    };
    radian = {
      enable = lib.mkEnableOption "a 21 century R console";
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.radianWrapper;
        defaultText = lib.literalExpression "pkgs.radianWrapper";
        description = "The radian package to use.";
      };
    };
    descriptionFile = {
      path = lib.mkOption { type = lib.types.pathInStore; };
      installPackages = {
        enable = lib.mkEnableOption "installation of R packages listed in DESCRIPTION file";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    packages =
      [ cfg.package ]
      ++ lib.lists.optional cfg.radian.enable cfg.radian.package
      ++ lib.lists.optionals cfg.descriptionFile.installPackages.enable (
        getRPackages pkgs (readFile cfg.descriptionFile.path)
      );
  };
}
