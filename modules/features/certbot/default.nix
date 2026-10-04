{moduleWithSystem, ...}: {
  flake.nixosModules.certbot = moduleWithSystem ({pkgs, ...}: {
    security.acme.acceptTerms = true;
    security.acme.defaults.email = "admin@voidarc.co.uk";

    security.acme.certs."mail.voidarc.co.uk" = {
      domain = "mail.voidarc.co.uk";
      dnsProvider = "cloudflare";
			credentialFiles = {
			  "RFC2136_TSIG_SECRET_FILE" = "/run/secrets/tsig-secret-example.org";
			}
			;
    };
  });
}
