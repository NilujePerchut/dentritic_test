{
  self,
  moduleWithSystem,
  ...
}: {
  # Global sops configuration: where each host finds its age decryption key.
  # The key is derived from the SSH host key via ssh-to-age
  # and stored at /var/lib/sops-nix/key.txt.
  flake.nixosModules.sops = moduleWithSystem ({...}: {
    sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  });
}
