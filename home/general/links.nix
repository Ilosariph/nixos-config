{ config, ... }:
{
  home.file = {
	data = {
      source = config.lib.file.mkOutOfStoreSymlink "/data";
	  target = "data";
	};
	nas = {
	  source = config.lib.file.mkOutOfStoreSymlink "/mnt/simon";
	  target = "nas";
	};
  };
}
