{ pkgs, ... }:
{
  virtualisation.libvirtd = {
	enable = true;
    qemu = {
      swtpm.enable = true;
      ovmf.packages = [ pkgs.OVMFFull.fd ];
    };
  };

  users.groups.libvirtd.members = [ "simon" ];
  users.groups.kvm.members = [ "simon" ];

  environment.systemPackages = with pkgs; [
	virt-manager
	virt-viewer
  ];
}
