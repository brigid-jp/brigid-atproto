package = "csn7"
version = "1.0-1"
source = {
  url = "https://github.com/brigid-jp/csn7/archive/v1.0.tar.gz";
  file = "csn7-1.0.tar.gz";
}
description = {
  summary = "";
  license = "MIT";
  homepage = "https://github.com/brigid-jp/csn7/";
  maintainer = "dev@brigid.jp";
}
build = {
  type = "builtin";
  install = {
    bin = {
      csn7 = "csn7";
    };
  };
}
