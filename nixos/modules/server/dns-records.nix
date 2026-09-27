{ domain ? "sccl.cc", serverIp ? "192.168.0.10" }:

{
  # local powerdns
  records = [
    { name = "@"; type = "SOA"; content = "ns1.${domain}. hostmaster.${domain}. 2026090301 3600 900 604800 300"; }
    { name = "@"; type = "NS"; content = "ns1.${domain}."; }
    { name = "@"; type = "A"; content = serverIp; }
    { name = "ns1"; type = "A"; content = serverIp; }
    { name = "www"; type = "CNAME"; content = "${domain}."; }
    { name = "mail"; type = "A"; content = serverIp; }
    { name = "webmail"; type = "A"; content = serverIp; }
    { name = "@"; type = "MX"; content = "1 mail.${domain}."; }
    { name = "prometheus"; type = "A"; content = serverIp; }
    { name = "loki"; type = "A"; content = serverIp; }
    { name = "alertmanager"; type = "A"; content = serverIp; }
    { name = "grafana"; type = "A"; content = serverIp; }
    { name = "files"; type = "A"; content = serverIp; }
    { name = "files-lan"; type = "A"; content = serverIp; }
    { name = "status"; type = "A"; content = serverIp; }
    { name = "xkb"; type = "A"; content = serverIp; }
    { name = "otp-migrate"; type = "A"; content = serverIp; }
    { name = "gif"; type = "A"; content = serverIp; }
    { name = "murmur"; type = "A"; content = serverIp; }
    { name = "valheim"; type = "A"; content = serverIp; }
    { name = "pass"; type = "A"; content = serverIp; }
    #{ name = "git"; type = "A"; content = serverIp; }
  ];

  # cloudflare dns
  cfRecords = [
    { name = "status"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "git"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "prometheus"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "loki"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "alertmanager"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "grafana"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "files"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "pass"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "@"; type = "A"; content = "$PUBLIC_IP"; proxied = true; }
    { name = "www"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "xkb"; type = "A"; content = "$PUBLIC_IP"; proxied = true; }
    { name = "otp-migrate"; type = "A"; content = "$PUBLIC_IP"; proxied = true; }
    { name = "gif"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "murmur"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "valheim"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "mail"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "webmail"; type = "A"; content = "$PUBLIC_IP"; proxied = false; }
    { name = "@"; type = "MX"; content = "1 mail.${domain}"; proxied = false; }
    { name = "@"; type = "TXT"; content = "v=spf1 mx -all"; proxied = false; }
    { name = "_dmarc"; type = "TXT"; content = "v=DMARC1; p=quarantine; rua=mailto:dmarc@${domain}"; proxied = false; }
  ];
}
