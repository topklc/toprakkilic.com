# toprakkilic.com

This is my personal website, along with the server that runs it and an authoritative DNS server. Currently, it is fully static HTML/CSS but as it grows, who knows? 

## Setup

Paste this into a terminal to setup the domain:
```
wget https://raw.githubusercontent.com/topklc/toprakkilic.com/main/config/setup.sh && setup.sh
```

The script will...
1. Prompt for SSH key to add
2. Add the user "admin"
3. Update and install required dependencies
4. Configure the firewall
5. Harden the SSH config and disable password based login
6. Initalize website and start the server
7. Initalize DNS and prompt to update DNSSEC records and nameservers
8. Verify SSH login before locking root

## Updating DNS

To update the DNS, edit `config/toprakkilic.com.zone`, then on the server:
```
kzonecheck -o toprakkilic.com config/toprakkilic.com.zone
sudo install -m 640 -o knot -g knot config/toprakkilic.com.zone /var/lib/knot/zones/toprakkilic.com.zone
sudo knotc zone-reload toprakkilic.com
```

## Updating Server

When a new git commit is pushed, in `/srv/www/toprakkilic.com`. run:
```
sudo git pull
cp config/Caddyfile /etc/caddy/Caddyfile
sudo systemctl reload cadddy
```
## Key Rollovers

ZSKs roll automatically every 30 days, the KSK never rolls on its own (`ksk-lifetime: 0`) and is generated during `setup.sh`. Rolling it is manual and needs a new DS record at the registrar.

## Using for your own site

Fork it, replace the HTML, and search-and-replace the domain and IPs in `config/`. Then delete or replace what is specific to me such as the Proton MX/SPF/DKIM/DMARC records, the verification TXT records, `security.txt`, and the `.well-known/openpgpkey/` tree (regenerate it with your own key using `gpg-wks-client` or similar).

## License

All code is under the [MIT License](LICENSE). The written content of the pages and any images are not covered by it: © 2026 Toprak Kilic, all rights reserved.