{ domain ? "sccl.cc", serverIp ? "192.168.0.10" }:

{
  records = [
    { name = "@"; type = "SOA"; content = "ns1.${domain}. hostmaster.${domain}. 2026090301 3600 900 604800 300"; }
    { name = "@"; type = "NS"; content = "ns1.${domain}."; }
    { name = "@"; type = "A"; content = serverIp; }
    { name = "ns1"; type = "A"; content = serverIp; }
    { name = "www"; type = "CNAME"; content = "${domain}."; }
    { name = "mail"; type = "A"; content = serverIp; }
    { name = "@"; type = "MX"; content = "10 mail.${domain}."; }
    { name = "@"; type = "TXT"; content = "v=spf1 mx -all"; }
    { name = "_dmarc"; type = "TXT"; content = "v=DMARC1; p=quarantine; rua=mailto:dmarc@${domain}"; }
    { name = "prometheus"; type = "A"; content = serverIp; }
    { name = "loki"; type = "A"; content = serverIp; }
    { name = "alertmanager"; type = "A"; content = serverIp; }
    { name = "grafana"; type = "A"; content = serverIp; }
    # local zone mirrors: lan directly instead of cf
    { name = "files"; type = "A"; content = serverIp; }
    { name = "files-lan"; type = "A"; content = serverIp; }
    { name = "status"; type = "A"; content = serverIp; }
    #{ name = "git"; type = "A"; content = serverIp; }
    #{ name = "pass"; type = "A"; content = serverIp; }
  ];

  cfRecords = [
    { name = "status"; type = "A"; content = "$PUBLIC_IP"; proxied = true; }
    { name = "git"; type = "A"; content = "$PUBLIC_IP"; proxied = true; }
    { name = "prometheus"; type = "A"; content = "$PUBLIC_IP"; proxied = true; }
    { name = "loki"; type = "A"; content = "$PUBLIC_IP"; proxied = true; }
    { name = "alertmanager"; type = "A"; content = "$PUBLIC_IP"; proxied = true; }
    { name = "grafana"; type = "A"; content = "$PUBLIC_IP"; proxied = true; }
    { name = "files"; type = "A"; content = "$PUBLIC_IP"; proxied = true; }
  ];
}
