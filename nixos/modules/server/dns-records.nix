{ domain ? "sccl.cc" }:

{
  records = [
    { name = "@"; type = "SOA"; content = "ns1.${domain}. hostmaster.${domain}. 2026090301 3600 900 604800 300"; }
    { name = "@"; type = "NS"; content = "ns1.${domain}."; }
    { name = "@"; type = "A"; content = "192.168.0.239"; }
    { name = "ns1"; type = "A"; content = "192.168.0.239"; }
    { name = "www"; type = "CNAME"; content = "${domain}."; }
    { name = "mail"; type = "A"; content = "192.168.0.239"; }
    { name = "@"; type = "MX"; content = "10 mail.${domain}."; }
    { name = "@"; type = "TXT"; content = "v=spf1 mx -all"; }
    { name = "_dmarc"; type = "TXT"; content = "v=DMARC1; p=quarantine; rua=mailto:dmarc@${domain}"; }
  ];
}
